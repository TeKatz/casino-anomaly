using System.Diagnostics;
using System.Globalization;
using System.IO.Compression;
using System.Text.Json;
using System.Xml.Linq;

namespace CasinoAnomaly.Updater;

// Intentionally independent of the Godot process. No network, registry
// changes, debugger attachment, forced termination or automatic restart.
internal static class CrashMonitor
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    internal static int Run(string pidText, string directory)
    {
        if (!int.TryParse(pidText, out int pid) || pid <= 0) return 2;
        try
        {
            directory = Path.GetFullPath(directory);
            using var header = JsonDocument.Parse(File.ReadAllText(Path.Combine(directory, "session.json")));
            if (header.RootElement.GetProperty("pid").GetInt32() != pid) return 2;
            var started = DateTimeOffset.Parse(header.RootElement.GetProperty("started_utc").GetString()!,
                CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal);
            // Do not retain the inherited installation working directory.
            Environment.CurrentDirectory = directory;
            Process? process = null;
            try
            {
                process = Process.GetProcessById(pid);
                if (!process.ProcessName.Equals("CasinoAnomaly", StringComparison.OrdinalIgnoreCase) ||
                    process.StartTime.ToUniversalTime() > started.UtcDateTime.AddSeconds(2))
                {
                    WriteJson(directory, "monitor_error.json", new { reason = "process_identity_mismatch", pid });
                    return 2;
                }
                // Acquire a real process handle before waiting; it remains
                // valid even after the process has terminated.
                _ = process.Handle;
            }
            catch (Exception error) when (error is ArgumentException or InvalidOperationException or System.ComponentModel.Win32Exception)
            {
                process?.Dispose();
                WriteJson(directory, "monitor_error.json", new { reason = "could_not_attach", pid, error = error.Message });
                Complete(directory, pid, null, false);
                return 1;
            }
            using (process)
            {
                WriteJson(directory, "monitor_ready.json", new { pid, utc = DateTimeOffset.UtcNow });
                process.WaitForExit();
                Complete(directory, pid, process.ExitCode, true);
            }
            return 0;
        }
        catch (Exception error)
        {
            try { WriteJson(directory, "monitor_error.json", new { reason = "monitor_failure", error = error.ToString() }); }
            catch { }
            return 1;
        }
    }

    private static bool HasShutdownMarker(string directory, int pid)
    {
        try
        {
            using var marker = JsonDocument.Parse(File.ReadAllText(Path.Combine(directory, "shutdown.json")));
            return marker.RootElement.GetProperty("pid").GetInt32() == pid;
        }
        catch { return false; }
    }

    private static void Complete(string directory, int pid, int? exitCode, bool observed, bool collectWindowsEvent = true)
    {
        bool cleanMarker = HasShutdownMarker(directory, pid);
        bool clean = observed && exitCode == 0 && cleanMarker;
        string? hex = exitCode.HasValue ? "0x" + unchecked((uint)exitCode.Value).ToString("X8") : null;
        string classification = clean ? "normal_shutdown" : exitCode.HasValue && exitCode != 0
            ? "abnormal_exit" : observed ? "unexpected_exit_without_shutdown" : "unobserved_exit";
        var ended = DateTimeOffset.UtcNow;
        WriteJson(directory, "exit.json", new { pid, ended_utc = ended, observed, exit_code = exitCode, exit_hex = hex, clean_marker = cleanMarker, classification });
        if (clean) return;
        // Write the basic report first, even if Windows event collection
        // is unavailable, delayed or blocked by local policy.
        var report = new Dictionary<string, object?>
        {
            ["schema"] = 1, ["classification"] = classification, ["pid"] = pid,
            ["ended_utc"] = ended, ["observed"] = observed, ["exit_code"] = exitCode,
            ["exit_hex"] = hex, ["clean_marker"] = cleanMarker,
            ["exit_description"] = hex switch
            {
                "0xC0000005" => "Access violation",
                "0xC000001D" => "Illegal instruction",
                "0xC0000094" => "Integer divide by zero",
                "0xC00000FD" => "Stack overflow",
                "0xC0000017" => "No memory",
                "0xC0000409" => "Fail-fast / stack buffer overrun status",
                _ => "No specific native exception identified"
            },
            ["windows_application_error"] = null,
            ["note"] = "An abnormal exit is not proof of a specific crash cause. No memory dump is captured."
        };
        WriteJson(directory, "crash_report.json", report);
        if (collectWindowsEvent && observed)
        {
            // Windows Error Reporting may publish the matching event shortly
            // after termination. Never include unrelated application events.
            for (int attempt = 0; attempt < 3; attempt++)
            {
                Thread.Sleep(1000);
                var evt = FindWindowsError(pid, ended);
                if (evt is null) continue;
                report["windows_application_error"] = evt;
                WriteJson(directory, "crash_report.json", report);
                break;
            }
        }
        var zip = Path.Combine(directory, "crash_report.zip");
        var tmp = zip + ".tmp";
        try
        {
            using (var stream = new FileStream(tmp, FileMode.Create, FileAccess.Write, FileShare.None))
            using (var archive = new ZipArchive(stream, ZipArchiveMode.Create))
            {
                foreach (string name in new[] { "session.json", "events.previous.jsonl", "events.jsonl", "exit.json", "shutdown.json", "monitor_ready.json", "monitor_error.json", "crash_report.json" })
                {
                    var path = Path.Combine(directory, name);
                    if (File.Exists(path)) archive.CreateEntryFromFile(path, name, CompressionLevel.Optimal);
                }
            }
            File.Move(tmp, zip, true);
        }
        finally { if (File.Exists(tmp)) File.Delete(tmp); }
    }

    private static Dictionary<string, string>? FindWindowsError(int pid, DateTimeOffset ended)
    {
        try
        {
            var tool = Path.Combine(Environment.SystemDirectory, "wevtutil.exe");
            var info = new ProcessStartInfo(tool) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
            foreach (var arg in new[] { "qe", "Application", "/q:*[System[(EventID=1000) and TimeCreated[timediff(@SystemTime) <= 120000]]]", "/rd:true", "/c:30", "/f:xml", "/e:Events" })
                info.ArgumentList.Add(arg);
            using var child = Process.Start(info);
            if (child is null) return null;
            var output = child.StandardOutput.ReadToEndAsync();
            var errors = child.StandardError.ReadToEndAsync();
            if (!child.WaitForExit(3000))
            {
                child.Kill();
                return null;
            }
            if (!Task.WaitAll(new Task[] { output, errors }, 1000) || child.ExitCode != 0) return null;
            var xml = XDocument.Parse(output.Result);
            foreach (var evt in xml.Descendants().Where(x => x.Name.LocalName == "Event"))
            {
                var fields = evt.Descendants().Where(x => x.Name.LocalName == "Data" && x.Attribute("Name") != null)
                    .GroupBy(x => (string)x.Attribute("Name")!).ToDictionary(g => g.Key, g => g.First().Value);
                if (!fields.TryGetValue("AppName", out var app) || !app.Equals("CasinoAnomaly.exe", StringComparison.OrdinalIgnoreCase)
                    || !fields.TryGetValue("ProcessId", out var id)) continue;
                bool parsed = id.StartsWith("0x", StringComparison.OrdinalIgnoreCase)
                    ? int.TryParse(id.AsSpan(2), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var eventPid)
                    : int.TryParse(id, out eventPid);
                if (!parsed || eventPid != pid) continue;
                var timestamp = evt.Descendants().FirstOrDefault(x => x.Name.LocalName == "TimeCreated")?.Attribute("SystemTime")?.Value;
                if (!DateTimeOffset.TryParse(timestamp, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var eventTime)
                    || (eventTime - ended).Duration() > TimeSpan.FromSeconds(30)) continue;
                var result = new Dictionary<string, string> { ["utc"] = eventTime.ToString("O") };
                foreach (var key in new[] { "AppName", "AppVersion", "ModuleName", "ModuleVersion", "ExceptionCode", "FaultingOffset" })
                    if (fields.TryGetValue(key, out var value)) result[key] = value;
                return result;
            }
        }
        catch { /* Optional OS diagnostics must not prevent a crash report. */ }
        return null;
    }

    private static void WriteJson(string directory, string name, object value)
    {
        var path = Path.Combine(directory, name);
        var tmp = path + ".tmp";
        using (var stream = new FileStream(tmp, FileMode.Create, FileAccess.Write, FileShare.None))
        {
            JsonSerializer.Serialize(stream, value, JsonOptions);
            stream.Flush(flushToDisk: true);
        }
        File.Move(tmp, path, true);
    }

    internal static void SelfTest()
    {
        var root = Path.Combine(Path.GetTempPath(), "CasinoCrashTest-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        try
        {
            foreach (var (code, marker, expectCrash) in new[] { (17, false, true), (0, false, true), (0, true, false), (17, true, true) })
            {
                var dir = Path.Combine(root, Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(dir);
                var info = new ProcessStartInfo(Environment.ProcessPath!) { UseShellExecute = false, CreateNoWindow = true };
                info.ArgumentList.Add("--crash-test-exit");
                info.ArgumentList.Add(code.ToString(CultureInfo.InvariantCulture));
                using var process = Process.Start(info) ?? throw new InvalidOperationException("Crash test process could not start.");
                _ = process.Handle;
                WriteJson(dir, "session.json", new { pid = process.Id });
                File.WriteAllText(Path.Combine(dir, "events.jsonl"), "{\"event\":\"load_threaded_request_begin\"}\n");
                if (marker) WriteJson(dir, "shutdown.json", new { pid = process.Id });
                if (!process.WaitForExit(15000))
                {
                    process.Kill();
                    throw new TimeoutException("Crash test child timed out.");
                }
                Complete(dir, process.Id, process.ExitCode, true, false);
                if (process.ExitCode != code || File.Exists(Path.Combine(dir, "crash_report.zip")) != expectCrash)
                    throw new InvalidOperationException("Crash classification or report archive failed.");
                if (expectCrash)
                {
                    using var archive = ZipFile.OpenRead(Path.Combine(dir, "crash_report.zip"));
                    if (archive.GetEntry("events.jsonl") == null || archive.GetEntry("crash_report.json") == null)
                        throw new InvalidOperationException("Crash archive lacks durable breadcrumbs.");
                }
            }
            Console.WriteLine("Casino Anomaly external crash monitor contract PASS");
        }
        finally { Directory.Delete(root, true); }
    }
}
