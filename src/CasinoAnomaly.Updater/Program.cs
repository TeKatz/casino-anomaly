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
        if (args.Length == 3 && args[0] == "--monitor-crash")
            return CrashMonitor.Run(args[1], args[2]);
        if (args.Length == 2 && args[0] == "--crash-test-exit" && int.TryParse(args[1], out var testExit))
        {
            Thread.Sleep(1500);
            return testExit;
        }
        if (args.Length == 1 && args[0] == "--self-test")
            return SelfTest();
        if (args.Length == 2 && args[0] == "--self-test-inherited-cwd")
            return SelfTestInheritedWorkingDirectory(args[1]);
        if (args.Length == 3 && args[0] == "--self-test-hold-cwd")
            return SelfTestHoldWorkingDirectory(args[1], args[2]);

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
        using var brandIcon = System.Drawing.Icon.ExtractAssociatedIcon(Environment.ProcessPath!);
        if (brandIcon is not null)
            window.Icon = brandIcon;
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
        var inPlace = new InPlaceUpdateState();
        try
        {
            report("Update " + manifest.Version + " wird heruntergeladen ...");
            await DownloadPackageWithRetryAsync(client, manifest.Package.Url, archive, report);
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
            try
            {
                MoveDirectoryWithRetry(installDirectory, backup);
                originalMoved = true;
                MoveDirectoryWithRetry(staging, installDirectory);
                activated = true;
            }
            catch (IOException error) when (!originalMoved && Directory.Exists(installDirectory))
            {
                // Windows can lock a folder when Explorer, a command prompt,
                // antivirus or a tool still has its working directory inside.
                // A directory rename may fail even though *files* are free.
                // Back up the original files BEFORE changing any of them,
                // then update each file atomically without renaming the folder.
                Log("Whole-directory replacement blocked; using transactional file replacement: " + error.Message);
                report("Installationsordner ist gesperrt – installiere Dateien einzeln ...");
                ApplyInPlaceUpdate(installDirectory, staging, backup, inPlace);
                activated = true;
            }

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
            else if (inPlace.ModificationsStarted)
            {
                try
                {
                    RestoreInPlaceUpdate(installDirectory, backup, inPlace);
                    Log("Previous installation restored after failed file replacement.");
                }
                catch (Exception rollbackError)
                {
                    Log("CRITICAL: in-place rollback failed: " + rollbackError);
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

    // The backup is deliberately outside the install directory so a process
    // with its CWD inside the game does not prevent the recovery copy.
    private sealed class InPlaceUpdateState
    {
        public bool ModificationsStarted { get; set; }
        public HashSet<string> OriginalFiles { get; } = new(StringComparer.OrdinalIgnoreCase);
        public HashSet<string> CandidateFiles { get; } = new(StringComparer.OrdinalIgnoreCase);
    }

    private static void ApplyInPlaceUpdate(
        string install, string staging, string backup, InPlaceUpdateState state)
    {
        if (!Directory.Exists(install) || !Directory.Exists(staging) || Directory.Exists(backup))
            throw new IOException("Unsafe in-place activation paths.");
        // A complete backup is prepared before touching any existing file.
        // This also preserves unexpected user-created files on rollback.
        Directory.CreateDirectory(backup);
        foreach (var oldFile in Directory.EnumerateFiles(install, "*", SearchOption.AllDirectories))
        {
            var relative = Path.GetRelativePath(install, oldFile);
            var target = Path.Combine(backup, relative);
            Directory.CreateDirectory(Path.GetDirectoryName(target)!);
            CopyFileWithRetry(oldFile, target);
            state.OriginalFiles.Add(relative);
        }

        var newFiles = Directory.GetFiles(staging, "*", SearchOption.AllDirectories);
        foreach (var newFile in newFiles)
            state.CandidateFiles.Add(Path.GetRelativePath(staging, newFile));
        if (!state.CandidateFiles.Contains("CasinoAnomaly.exe") ||
            !state.CandidateFiles.Contains("CasinoAnomaly.pck") ||
            !state.CandidateFiles.Contains(Path.Combine("tools", "updater", "CasinoAnomaly.Updater.exe")))
            throw new InvalidDataException("In-place update package is incomplete.");

        // All files in a validated release replace their corresponding
        // installed counterparts; avoid touching unrelated local files.
        foreach (var newFile in newFiles)
        {
            var relative = Path.GetRelativePath(staging, newFile);
            var target = Path.Combine(install, relative);
            Directory.CreateDirectory(Path.GetDirectoryName(target)!);
            state.ModificationsStarted = true;
            ReplaceFileWithRetry(newFile, target);
        }
        Log("In-place update committed after directory rename was blocked.");
    }

    private static void RestoreInPlaceUpdate(
        string install, string backup, InPlaceUpdateState state)
    {
        // Backup construction finishes BEFORE ModificationsStarted is set.
        // Restore every original file, and remove newly introduced files.
        foreach (var relative in state.OriginalFiles)
        {
            var original = Path.Combine(backup, relative);
            var target = Path.Combine(install, relative);
            Directory.CreateDirectory(Path.GetDirectoryName(target)!);
            ReplaceFileWithRetry(original, target);
        }
        foreach (var relative in state.CandidateFiles)
        {
            if (state.OriginalFiles.Contains(relative))
                continue;
            var target = Path.Combine(install, relative);
            if (File.Exists(target))
                DeleteFileWithRetry(target);
        }
    }

    private static void CopyFileWithRetry(string source, string destination)
    {
        for (var attempt = 0; ; attempt++)
        {
            try
            {
                File.Copy(source, destination, overwrite: true);
                return;
            }
            catch (IOException) when (attempt < 19) { Thread.Sleep(500); }
            catch (UnauthorizedAccessException) when (attempt < 19) { Thread.Sleep(500); }
        }
    }

    private static void DeleteFileWithRetry(string path)
    {
        for (var attempt = 0; ; attempt++)
        {
            try { File.Delete(path); return; }
            catch (IOException) when (attempt < 19) { Thread.Sleep(500); }
            catch (UnauthorizedAccessException) when (attempt < 19) { Thread.Sleep(500); }
        }
    }

    private static void ReplaceFileWithRetry(string source, string destination)
    {
        // Stage to the target volume first. File.Move(overwrite:true) is an
        // atomic same-volume rename; no half-written executable can be used.
        var temporary = destination + ".incoming-" + Guid.NewGuid().ToString("N");
        try
        {
            CopyFileWithRetry(source, temporary);
            for (var attempt = 0; ; attempt++)
            {
                try
                {
                    File.Move(temporary, destination, overwrite: true);
                    return;
                }
                catch (IOException) when (attempt < 19) { Thread.Sleep(500); }
                catch (UnauthorizedAccessException) when (attempt < 19) { Thread.Sleep(500); }
            }
        }
        finally
        {
            try { if (File.Exists(temporary)) File.Delete(temporary); }
            catch (IOException error) { Log("Temporary file cleanup deferred: " + error.Message); }
        }
    }

    // During a GitHub Release replacement, its manifest may propagate before
    // the large Windows ZIP has become available through the download CDN.
    // Retrying a short-lived 404 is safe: the release is SHA-256 and size
    // verified before the existing game installation is ever modified.
    private static async Task DownloadPackageWithRetryAsync(
        HttpClient client, string url, string archive, Action<string> report)
    {
        const int maxAttempts = 8;
        for (var attempt = 1; attempt <= maxAttempts; attempt++)
        {
            string reason;
            try
            {
                using var response = await client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
                if (IsRetryablePackageStatus(response.StatusCode) && attempt < maxAttempts)
                {
                    reason = "HTTP " + (int)response.StatusCode;
                    Log("Development package temporarily unavailable (" + reason
                        + "), download attempt " + attempt + "/" + maxAttempts + ".");
                }
                else
                {
                    response.EnsureSuccessStatusCode();
                    await using var input = await response.Content.ReadAsStreamAsync();
                    await using var output = File.Create(archive);
                    await input.CopyToAsync(output);
                    return;
                }
            }
            catch (HttpRequestException error) when (attempt < maxAttempts)
            {
                reason = "Netzwerkfehler";
                Log("Temporary package network error, attempt " + attempt
                    + "/" + maxAttempts + ": " + error.Message);
            }

            report("Download vorübergehend nicht verfügbar (" + reason
                + "). Neuer Versuch " + (attempt + 1) + "/" + maxAttempts + " ...");
            await Task.Delay(TimeSpan.FromSeconds(Math.Min(5 * attempt, 30)));
        }

        throw new IOException("The Development package could not be downloaded after retries.");
    }

    private static bool IsRetryablePackageStatus(System.Net.HttpStatusCode status) =>
        status == System.Net.HttpStatusCode.NotFound ||
        status == System.Net.HttpStatusCode.RequestTimeout ||
        status == (System.Net.HttpStatusCode)429 ||
        status == System.Net.HttpStatusCode.BadGateway ||
        status == System.Net.HttpStatusCode.ServiceUnavailable ||
        status == System.Net.HttpStatusCode.GatewayTimeout;

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
            if (!IsRetryablePackageStatus(System.Net.HttpStatusCode.NotFound) ||
                !IsRetryablePackageStatus(System.Net.HttpStatusCode.ServiceUnavailable) ||
                !IsRetryablePackageStatus((System.Net.HttpStatusCode)429) ||
                IsRetryablePackageStatus(System.Net.HttpStatusCode.Unauthorized) ||
                IsRetryablePackageStatus(System.Net.HttpStatusCode.Forbidden))
                throw new InvalidOperationException("Temporary download error retry contract changed.");
            VerifyUpdaterDoesNotLockInstallDirectory();
            VerifyInPlaceUpdateWithLockedDirectory();
            CrashMonitor.SelfTest();
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

    // Regression: another process retains CWD inside the installation.
    // The original directory cannot reliably be renamed on Windows, but
    // the fallback must still install every release file and keep extras.
    private static void VerifyInPlaceUpdateWithLockedDirectory()
    {
        var root = Path.Combine(Path.GetTempPath(), "CasinoAnomaly-LockedFolder-" + Guid.NewGuid().ToString("N"));
        var install = Path.Combine(root, "game");
        var staging = Path.Combine(root, "staging");
        var backup = Path.Combine(root, "backup");
        var ready = Path.Combine(root, "locker-ready");
        Directory.CreateDirectory(install);
        Directory.CreateDirectory(staging);
        File.WriteAllText(Path.Combine(install, "CasinoAnomaly.exe"), "old executable");
        File.WriteAllText(Path.Combine(install, "CasinoAnomaly.pck"), "old package");
        File.WriteAllText(Path.Combine(install, "user-note.txt"), "preserve local extras");
        File.WriteAllText(Path.Combine(staging, "CasinoAnomaly.exe"), "new executable");
        File.WriteAllText(Path.Combine(staging, "CasinoAnomaly.pck"), "new package");
        Directory.CreateDirectory(Path.Combine(staging, "tools", "updater"));
        File.WriteAllText(Path.Combine(staging, "tools", "updater", "CasinoAnomaly.Updater.exe"), "new updater");
        using var locker = Process.Start(new ProcessStartInfo(Environment.ProcessPath!)
        {
            UseShellExecute = false,
            WorkingDirectory = install,
            CreateNoWindow = true,
            ArgumentList = { "--self-test-hold-cwd", install, ready }
        }) ?? throw new InvalidOperationException("Could not start locked-folder regression helper.");
        try
        {
            if (!SpinWait.SpinUntil(() => File.Exists(ready), TimeSpan.FromSeconds(10)))
                throw new TimeoutException("The directory-lock test helper did not initialize.");

            var state = new InPlaceUpdateState();
            ApplyInPlaceUpdate(install, staging, backup, state);
            if (File.ReadAllText(Path.Combine(install, "CasinoAnomaly.exe")) != "new executable" ||
                File.ReadAllText(Path.Combine(install, "CasinoAnomaly.pck")) != "new package" ||
                !File.Exists(Path.Combine(install, "tools", "updater", "CasinoAnomaly.Updater.exe")) ||
                File.ReadAllText(Path.Combine(install, "user-note.txt")) != "preserve local extras")
                throw new InvalidOperationException("In-place update failed while another process retained the directory.");

            // Exercise rollback after partial activation as well.
            RestoreInPlaceUpdate(install, backup, state);
            if (File.ReadAllText(Path.Combine(install, "CasinoAnomaly.exe")) != "old executable" ||
                File.ReadAllText(Path.Combine(install, "CasinoAnomaly.pck")) != "old package" ||
                File.Exists(Path.Combine(install, "tools", "updater", "CasinoAnomaly.Updater.exe")))
                throw new InvalidOperationException("In-place update rollback did not restore the old files.");
        }
        finally
        {
            if (!locker.HasExited)
                locker.Kill(entireProcessTree: true);
            locker.WaitForExit(10000);
            if (Directory.Exists(root))
                Directory.Delete(root, true);
        }
    }

    private static int SelfTestHoldWorkingDirectory(string install, string ready)
    {
        if (!IsWithinDirectory(Environment.CurrentDirectory, install))
            return 1;
        File.WriteAllText(ready, "ready");
        while (true)
            Thread.Sleep(250);
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
