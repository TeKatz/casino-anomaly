using System.Diagnostics;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;
using System.Windows.Forms;

namespace CasinoAnomaly.Updater;

internal sealed class UpdateManifest
{
    public int SchemaVersion { get; set; }
    public string Version { get; set; } = "";
    public long VersionCode { get; set; }
    public string Channel { get; set; } = "";
    public UpdatePackage Package { get; set; } = new();
}

internal sealed class UpdatePackage
{
    public string Url { get; set; } = "";
    public string Sha256 { get; set; } = "";
    public long SizeBytes { get; set; }
}

internal static class Program
{
    private const string ManifestUrl =
        "https://github.com/TeKatz/casino-anomaly/releases/download/development/update-manifest.json";
    private const string PackagePrefix =
        "https://github.com/TeKatz/casino-anomaly/releases/download/development/casino-anomaly-win-x64.zip";
    private static readonly string LogDirectory = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "CasinoAnomaly", "Updater");
    private static string LogPath => Path.Combine(LogDirectory, "updater.log");

    [STAThread]
    private static int Main(string[] args)
    {
        if (args.Length == 1 && args[0] == "--self-test")
            return SelfTest();
        if (args.Length == 2 && args[0] == "--self-test-inherited-cwd")
            return SelfTestInheritedWorkingDirectory(args[1]);

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        var window = new Form
        {
            Text = "Casino Anomaly – Update",
            Width = 430,
            Height = 145,
            StartPosition = FormStartPosition.CenterScreen,
            MaximizeBox = false,
            MinimizeBox = false,
            FormBorderStyle = FormBorderStyle.FixedDialog,
            ControlBox = false
        };
        var status = new Label
        {
            Text = "Update wird vorbereitet ...",
            AutoSize = false,
            Left = 20,
            Top = 18,
            Width = 380,
            Height = 38
        };
        var progress = new ProgressBar
        {
            Style = ProgressBarStyle.Marquee,
            Left = 20,
            Top = 65,
            Width = 380,
            Height = 18,
            MarqueeAnimationSpeed = 28
        };
        window.Controls.Add(status);
        window.Controls.Add(progress);
        var exit = 0;
        window.Shown += async (_, _) =>
        {
            try
            {
                await RunUpdateAsync(args, message =>
                {
                    status.Text = message;
                    Log(message);
                });
            }
            catch (Exception exception)
            {
                exit = 1;
                Log(exception.ToString());
                MessageBox.Show(window,
                    "Das Update konnte nicht installiert werden. Die bisherige Version bleibt erhalten oder wurde wiederhergestellt.\n\nDetails: " + LogPath,
                    "Casino Anomaly – Updatefehler", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            finally
            {
                window.Close();
            }
        };
        Application.Run(window);
        return exit;
    }

    private static async Task RunUpdateAsync(string[] args, Action<string> report)
    {
        var options = args.Select(arg => arg.Split('=', 2))
            .Where(parts => parts.Length == 2 && parts[0].StartsWith("--", StringComparison.Ordinal))
            .ToDictionary(parts => parts[0], parts => parts[1], StringComparer.Ordinal);
        if (!options.TryGetValue("--manifest", out var url) || url != ManifestUrl ||
            !options.TryGetValue("--install-dir", out var requestedInstall) ||
            !options.TryGetValue("--wait-pid", out var pidText) ||
            !options.TryGetValue("--current-version-code", out var versionText) ||
            !int.TryParse(pidText, out var pid) || pid <= 0 ||
            !long.TryParse(versionText, out var currentVersionCode) || currentVersionCode < 0)
            throw new InvalidOperationException("Missing or invalid updater arguments.");

        var installDirectory = Path.GetFullPath(requestedInstall);
        if (!File.Exists(Path.Combine(installDirectory, "CasinoAnomaly.exe")))
            throw new InvalidOperationException("Casino Anomaly is not installed at the requested location.");
        var parent = Directory.GetParent(installDirectory)?.FullName
            ?? throw new InvalidOperationException("The install location has no parent.");
        var name = Path.GetFileName(installDirectory);
        if (string.IsNullOrWhiteSpace(name) || Path.GetPathRoot(installDirectory) == installDirectory)
            throw new InvalidOperationException("Refusing to modify a filesystem root.");

        // Godot starts the helper with the game's working directory by default.
        // On Windows, our own process holding that directory open can make
        // Directory.Move(installDirectory, backup) fail with ERROR_SHARING_VIOLATION.
        // Move *this updater's* working directory outside the installation
        // before downloading files, waiting for the game, or renaming folders.
        LeaveInstallationWorkingDirectory(installDirectory);

        using var client = new HttpClient { Timeout = TimeSpan.FromMinutes(8) };
        report("Updateinformationen werden geladen ...");
        using var response = await client.GetAsync(ManifestUrl + "?revision=" + DateTimeOffset.UtcNow.ToUnixTimeSeconds());
        response.EnsureSuccessStatusCode();
        var data = await response.Content.ReadAsStringAsync();
        var manifest = JsonSerializer.Deserialize<UpdateManifest>(data,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? throw new InvalidDataException("Empty update manifest.");
        ValidateManifest(manifest, currentVersionCode);

        var token = Guid.NewGuid().ToString("N");
        var staging = Path.Combine(parent, "." + name + "-stage-" + token);
        var backup = Path.Combine(parent, "." + name + "-backup-" + token);
        var downloadDir = Path.Combine(LogDirectory, "downloads");
        Directory.CreateDirectory(downloadDir);
        var archive = Path.Combine(downloadDir, "update-" + token + ".zip");
        var activated = false;
        var originalMoved = false;
        try
        {
            report("Update " + manifest.Version + " wird heruntergeladen ...");
            using (var packageResponse = await client.GetAsync(manifest.Package.Url, HttpCompletionOption.ResponseHeadersRead))
            {
                packageResponse.EnsureSuccessStatusCode();
                await using var input = await packageResponse.Content.ReadAsStreamAsync();
                await using var output = File.Create(archive);
                await input.CopyToAsync(output);
            }
            var actualSize = new FileInfo(archive).Length;
            if (actualSize != manifest.Package.SizeBytes)
                throw new InvalidDataException("Package size does not match the signed release metadata.");
            await using (var input = File.OpenRead(archive))
            {
                var digest = Convert.ToHexString(await SHA256.HashDataAsync(input));
                if (!digest.Equals(manifest.Package.Sha256, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException("SHA-256 checksum mismatch.");
            }

            report("Dateien werden vorbereitet ...");
            Directory.CreateDirectory(staging);
            using (var zip = ZipFile.OpenRead(archive))
            {
                var root = Path.GetFullPath(staging) + Path.DirectorySeparatorChar;
                foreach (var entry in zip.Entries)
                {
                    var destination = Path.GetFullPath(Path.Combine(staging, entry.FullName));
                    if (!destination.StartsWith(root, StringComparison.OrdinalIgnoreCase))
                        throw new InvalidDataException("Unsafe archive entry: " + entry.FullName);
                    if (string.IsNullOrEmpty(entry.Name))
                    {
                        Directory.CreateDirectory(destination);
                        continue;
                    }
                    Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
                    entry.ExtractToFile(destination, false);
                }
            }
            foreach (var required in new[]
                     { "CasinoAnomaly.exe", "CasinoAnomaly.pck", "tools/updater/CasinoAnomaly.Updater.exe" })
                if (!File.Exists(Path.Combine(staging, required)))
                    throw new InvalidDataException("Update package is incomplete: " + required);

            report("Warte auf das Beenden des Spiels ...");
            try
            {
                using var gameProcess = Process.GetProcessById(pid);
                if (!await WaitUntilExitedAsync(gameProcess, TimeSpan.FromSeconds(90)))
                    throw new TimeoutException("The game did not terminate.");
            }
            catch (ArgumentException)
            {
                // The game has already exited.
            }

            report("Neue Version wird installiert ...");
            Log("Activating update. Install=" + installDirectory + "; staging=" + staging);
            MoveDirectoryWithRetry(installDirectory, backup);
            originalMoved = true;
            MoveDirectoryWithRetry(staging, installDirectory);
            activated = true;

            report("Update abgeschlossen – Spiel startet ...");
            var start = new ProcessStartInfo(Path.Combine(installDirectory, "CasinoAnomaly.exe"))
            {
                UseShellExecute = true,
                WorkingDirectory = installDirectory
            };
            if (Process.Start(start) == null)
                throw new InvalidOperationException("Updated game could not be started.");
            try { Directory.Delete(backup, true); }
            catch (Exception cleanupError) { Log("Backup cleanup deferred: " + cleanupError.Message); }
        }
        catch
        {
            if (originalMoved)
            {
                try
                {
                    if (activated && Directory.Exists(installDirectory))
                        MoveDirectoryWithRetry(installDirectory, staging);
                    if (Directory.Exists(backup))
                        MoveDirectoryWithRetry(backup, installDirectory);
                    Log("Previous installation restored.");
                }
                catch (Exception rollbackError)
                {
                    Log("CRITICAL: automatic rollback failed: " + rollbackError);
                    throw new IOException("Update and rollback failed; old files are in " + backup, rollbackError);
                }
            }
            throw;
        }
        finally
        {
            try { if (File.Exists(archive)) File.Delete(archive); } catch { /* Cleanup only. */ }
            try { if (Directory.Exists(staging)) Directory.Delete(staging, true); } catch { /* Cleanup only. */ }
        }
    }

    private static async Task<bool> WaitUntilExitedAsync(Process process, TimeSpan timeout)
    {
        using var cancel = new CancellationTokenSource(timeout);
        try
        {
            await process.WaitForExitAsync(cancel.Token);
            return true;
        }
        catch (OperationCanceledException) { return false; }
        catch (InvalidOperationException) { return true; }
    }

    private static void LeaveInstallationWorkingDirectory(string installDirectory)
    {
        var previous = Environment.CurrentDirectory;
        var candidates = new[]
        {
            LogDirectory,
            Path.Combine(Path.GetTempPath(), "CasinoAnomalyUpdater"),
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile)
        };

        foreach (var candidate in candidates)
        {
            if (string.IsNullOrWhiteSpace(candidate) || IsWithinDirectory(candidate, installDirectory))
                continue;

            try
            {
                Directory.CreateDirectory(candidate);
                Environment.CurrentDirectory = candidate;
                if (IsWithinDirectory(Environment.CurrentDirectory, installDirectory))
                    continue;
                Log("Updater working directory moved from '" + previous
                    + "' to '" + Environment.CurrentDirectory + "'.");
                return;
            }
            catch (IOException) { /* Try another separate location. */ }
            catch (UnauthorizedAccessException) { /* Try another separate location. */ }
        }

        throw new IOException("Cannot relocate the updater working directory outside the game installation.");
    }

    private static bool IsWithinDirectory(string candidate, string parent)
    {
        var fullParent = Path.GetFullPath(parent).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var fullCandidate = Path.GetFullPath(candidate).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        return fullCandidate.Equals(fullParent, StringComparison.OrdinalIgnoreCase)
            || fullCandidate.StartsWith(fullParent + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);
    }

    private static void MoveDirectoryWithRetry(string source, string destination)
    {
        for (var attempt = 0; attempt < 12; attempt++)
        {
            try
            {
                Directory.Move(source, destination);
                return;
            }
            catch (IOException exception) when (attempt < 11)
            {
                if (attempt == 0)
                    Log("Directory move is temporarily blocked: " + source + " -> " + destination
                        + "; CWD=" + Environment.CurrentDirectory + "; " + exception.Message);
                Thread.Sleep(500);
            }
            catch (UnauthorizedAccessException exception) when (attempt < 11)
            {
                if (attempt == 0)
                    Log("Directory move was denied: " + source + " -> " + destination
                        + "; CWD=" + Environment.CurrentDirectory + "; " + exception.Message);
                Thread.Sleep(500);
            }
        }
        throw new IOException("Failed to move directory " + source + " to " + destination
            + "; updater CWD=" + Environment.CurrentDirectory);
    }

    private static void ValidateManifest(UpdateManifest manifest, long installedVersion)
    {
        if (manifest.SchemaVersion != 1 || manifest.Channel != "development" ||
            manifest.VersionCode <= installedVersion || manifest.VersionCode < 1 ||
            string.IsNullOrWhiteSpace(manifest.Version))
            throw new InvalidDataException("Invalid or outdated Development manifest.");
        if (!manifest.Package.Url.StartsWith(PackagePrefix + "?revision=", StringComparison.Ordinal) ||
            manifest.Package.SizeBytes < 1_000_000 || manifest.Package.SizeBytes > 1_000_000_000 ||
            manifest.Package.Sha256.Length != 64 ||
            !manifest.Package.Sha256.All(Uri.IsHexDigit))
            throw new InvalidDataException("Invalid Development package metadata.");
    }

    private static int SelfTest()
    {
        try
        {
            var manifest = new UpdateManifest
            {
                SchemaVersion = 1,
                Channel = "development",
                Version = "0.1.0-dev.2",
                VersionCode = 2,
                Package = new UpdatePackage
                {
                    Url = PackagePrefix + "?revision=0.1.0-dev.2",
                    SizeBytes = 2_000_000,
                    Sha256 = new string('a', 64)
                }
            };
            ValidateManifest(manifest, 1);
            var outdatedRejected = false;
            try { ValidateManifest(manifest, 2); }
            catch (InvalidDataException) { outdatedRejected = true; }
            if (!outdatedRejected) throw new InvalidOperationException("Outdated update was accepted.");
            manifest.Package.Url = "https://example.com/malicious.zip";
            var foreignRejected = false;
            try { ValidateManifest(manifest, 1); }
            catch (InvalidDataException) { foreignRejected = true; }
            if (!foreignRejected) throw new InvalidOperationException("Foreign package URL was accepted.");
            VerifyUpdaterDoesNotLockInstallDirectory();
            Console.WriteLine("Casino Anomaly updater contract PASS");
            return 0;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(error);
            return 1;
        }
    }

    // Real Windows regression: a child updater starts with the fake game
    // installation as its inherited CWD, exactly as Godot launches it.
    // The child must be able to rename and restore that directory while alive.
    private static void VerifyUpdaterDoesNotLockInstallDirectory()
    {
        var testRoot = Path.Combine(Path.GetTempPath(), "CasinoAnomaly-CwdRegression-" + Guid.NewGuid().ToString("N"));
        var install = Path.Combine(testRoot, "Casino Anomaly");
        Directory.CreateDirectory(install);
        var marker = Path.Combine(install, "old-version.txt");
        File.WriteAllText(marker, "preserve old installation");
        try
        {
            var updater = Environment.ProcessPath
                ?? throw new InvalidOperationException("Cannot find the updater executable for the regression test.");
            var start = new ProcessStartInfo(updater)
            {
                UseShellExecute = false,
                WorkingDirectory = install,
                CreateNoWindow = true
            };
            start.ArgumentList.Add("--self-test-inherited-cwd");
            start.ArgumentList.Add(install);
            using var child = Process.Start(start)
                ?? throw new InvalidOperationException("Could not launch directory-lock regression test.");
            if (!child.WaitForExit(30000))
            {
                child.Kill(entireProcessTree: true);
                throw new TimeoutException("Updater directory-lock regression test timed out.");
            }
            if (child.ExitCode != 0 || !File.Exists(marker))
                throw new IOException("Updater could not rename and restore the original install directory.");
        }
        finally
        {
            if (Directory.Exists(testRoot))
                Directory.Delete(testRoot, true);
        }
    }

    private static int SelfTestInheritedWorkingDirectory(string install)
    {
        try
        {
            if (!IsWithinDirectory(Environment.CurrentDirectory, install))
                throw new InvalidOperationException("Regression test did not inherit the game installation CWD.");
            LeaveInstallationWorkingDirectory(install);
            var moved = install + "-backup";
            MoveDirectoryWithRetry(install, moved);
            MoveDirectoryWithRetry(moved, install);
            return 0;
        }
        catch (Exception error)
        {
            Log("Directory-lock regression failed: " + error);
            return 1;
        }
    }

    private static void Log(string message)
    {
        try
        {
            Directory.CreateDirectory(LogDirectory);
            File.AppendAllText(LogPath, DateTimeOffset.Now.ToString("O") + " " + message + Environment.NewLine);
        }
        catch { /* Logging must not prevent rollback. */ }
    }
}
