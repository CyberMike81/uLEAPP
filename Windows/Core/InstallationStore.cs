// SPDX-License-Identifier: MIT
using Microsoft.Win32;
using System.Text.Json;

namespace uLEAPP;

public sealed class InstallationStore
{
    private readonly string statePath;
    private readonly Dictionary<string, Installation> installed = new(StringComparer.OrdinalIgnoreCase);
    private bool settingsWriteBlocked;
    public string Root { get; private set; }
    internal string DataDirectory => Path.GetDirectoryName(statePath)!;
    public string? RecoveryMessage { get; private set; }
    public string? RecoveryBackupPath { get; private set; }
    public InstallationStore(string? dataDirectory = null)
    {
        string data = dataDirectory ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "uLEAPP");
        statePath = Path.Combine(data, "settings.json");
        IReadOnlyList<Installation> recovered = [];
        try { recovered = InPlaceUpdate.Recover(data); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException or ArgumentException) {
            settingsWriteBlocked = true;
            RecoveryMessage = "An interrupted app update needs attention: " + error.Message + " Rollback copies were kept. Restore folder access and reopen uLEAPP before updating.";
        }
        Root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "LEAPPs");
        try
        {
            var state = JsonSerializer.Deserialize<State>(File.ReadAllText(statePath))
                ?? throw new InvalidDataException("The saved settings are empty.");
            ValidateRoot(state.Root ?? "");
            var entries = new Dictionary<string, Installation>(StringComparer.OrdinalIgnoreCase);
            foreach (var item in state.Installed ?? [])
            {
                if (item == null) throw new InvalidDataException("An installed app record is empty.");
                if (!Catalog.All.Any(t => t.Id == item.Id)) continue;
                if (string.IsNullOrWhiteSpace(item.Version) || string.IsNullOrWhiteSpace(item.Path) || !Path.IsPathFullyQualified(item.Path))
                    throw new InvalidDataException("An installed app record is incomplete.");
                entries[item.Id] = item;
            }
            Root = Path.GetFullPath(state.Root!);
            foreach (var item in entries) installed[item.Key] = item.Value;
        }
        catch (FileNotFoundException) { }
        catch (DirectoryNotFoundException) { }
        catch (Exception error) when (error is JsonException or InvalidDataException or IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException)
        { RecoverSettings(); }
        if (!settingsWriteBlocked) foreach (var item in recovered) {
            try { Record(item); File.Delete(Path.Combine(data,"pending-location-" + item.Id + ".json")); } catch (Exception error) when (error is IOException or UnauthorizedAccessException) {
                settingsWriteBlocked = true; RecoveryMessage = "Recovered app files, but could not save their selection: " + error.Message;
            }
        }
    }
    private sealed record State(string? Root, Installation?[]? Installed);
    private void RecoverSettings()
    {
        string backup = statePath + ".unreadable-" + DateTime.UtcNow.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N") + ".bak";
        try
        {
            File.Move(statePath, backup);
            RecoveryBackupPath = backup;
            RecoveryMessage = "Saved settings could not be read. Defaults are in use; the original file was kept as " + Path.GetFileName(backup) + ". Installed apps and case files were left in place. Choose folder to restore a custom portable-app location.";
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            settingsWriteBlocked = true;
            RecoveryMessage = "Saved settings could not be read or backed up. Temporary defaults are in use and the original file is unchanged. Restore access to " + statePath + " and reopen uLEAPP before installing apps or saving changes.";
        }
    }
    public void ChangeRoot(string root)
    {
        ValidateRoot(root);
        string previous = Root; Root = Path.GetFullPath(root);
        try { Save(); } catch { Root = previous; throw; }
    }
    public static void ValidateRoot(string root)
    {
        if (string.IsNullOrWhiteSpace(root) || !Path.IsPathFullyQualified(root) || root.StartsWith(@"\\") ||
            Path.GetFullPath(root).Equals(Path.GetPathRoot(root), StringComparison.OrdinalIgnoreCase))
            throw new IOException("Choose a folder on a Windows drive, such as C:\\Users\\YourName\\LEAPPs.");
        string path = Path.GetFullPath(root);
        string[] protectedRoots = [Environment.GetFolderPath(Environment.SpecialFolder.Windows), Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86)];
        if (protectedRoots.Any(p => !string.IsNullOrEmpty(p) && (path.Equals(p, StringComparison.OrdinalIgnoreCase) || path.StartsWith(p + "\\", StringComparison.OrdinalIgnoreCase))))
            throw new IOException("Choose a folder in your own account for portable LEAPP apps.");
    }
    public void Record(Installation installation)
    {
        installed.TryGetValue(installation.Id, out var previous);
        installed[installation.Id] = installation;
        try { Save(); }
        catch
        {
            if (previous == null) installed.Remove(installation.Id); else installed[installation.Id] = previous;
            throw;
        }
    }
    public void EnsureSettingsWritable()
    {
        if (settingsWriteBlocked) throw new IOException(RecoveryMessage);
    }
    private void Save()
    {
        EnsureSettingsWritable();
        Directory.CreateDirectory(Path.GetDirectoryName(statePath)!);
        string temporary = statePath + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            File.WriteAllText(temporary, JsonSerializer.Serialize(new State(Root, installed.Values.ToArray()), new JsonSerializerOptions { WriteIndented = true }));
            File.Move(temporary, statePath, true);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
    public Installation? Find(Tool tool)
    {
        if (installed.TryGetValue(tool.Id, out var known) && File.Exists(known.Path)) {
            try {
                string marker = Path.Combine(Path.GetDirectoryName(known.Path)!,".uleapp-release.json");
                var selected = JsonSerializer.Deserialize<Installation>(File.ReadAllText(marker));
                if (selected?.Id == tool.Id && selected.Path.Equals(known.Path,StringComparison.OrdinalIgnoreCase) && !string.IsNullOrWhiteSpace(selected.Version)) return selected;
            } catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException) { }
            return known;
        }
        // Recover a completed installation if recording its state was interrupted.
        string managed = Path.Combine(Root, tool.Name);
        if (Directory.Exists(managed))
        {
            var markers = Directory.EnumerateFiles(managed, ".uleapp-release.json", SearchOption.TopDirectoryOnly)
                .Concat(Directory.EnumerateDirectories(managed).Where(p => (File.GetAttributes(p) & FileAttributes.ReparsePoint) == 0)
                .SelectMany(p => Directory.EnumerateFiles(p, ".uleapp-release.json", SearchOption.TopDirectoryOnly)));
            foreach (var marker in markers.OrderByDescending(File.GetLastWriteTimeUtc))
            {
                try
                {
                    var item = JsonSerializer.Deserialize<Installation>(File.ReadAllText(marker));
                    if (item?.Id == tool.Id && File.Exists(item.Path) && Path.GetFullPath(item.Path).StartsWith(Path.GetDirectoryName(marker)! + "\\", StringComparison.OrdinalIgnoreCase)) return item;
                }
                catch (JsonException) { }
            }
        }
        var registered = FindRegistered(tool);
        if (registered != null) return registered;
        foreach (var candidate in new[] { Path.Combine(Root,tool.Name), Root }.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            string? executable = PortablePackage.FindExecutable(candidate,tool);
            if (executable == null) continue;
            string version = System.Diagnostics.FileVersionInfo.GetVersionInfo(executable).ProductVersion ?? "unknown";
            if (string.IsNullOrWhiteSpace(version)) version = "unknown";
            return new(tool.Id,version,executable,Catalog.Architecture);
        }
        return null;
    }
    public static Installation? FindRegistered(Tool tool)
    {
        foreach (var hive in new[] { RegistryHive.CurrentUser, RegistryHive.LocalMachine })
        foreach (var view in new[] { RegistryView.Registry64, RegistryView.Registry32 })
        {
            using var root = RegistryKey.OpenBaseKey(hive, view);
            using var uninstall = root.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall");
            if (uninstall == null) continue;
            foreach (string keyName in uninstall.GetSubKeyNames())
            {
                using var key = uninstall.OpenSubKey(keyName);
                string name = key?.GetValue("DisplayName") as string ?? "";
                if (!name.Equals(tool.Name, StringComparison.OrdinalIgnoreCase) && !name.StartsWith(tool.Name + " ", StringComparison.OrdinalIgnoreCase)) continue;
                string version = key?.GetValue("DisplayVersion") as string ?? "unknown";
                string directory = key?.GetValue("InstallLocation") as string ?? "";
                string? executable = !string.IsNullOrEmpty(directory) ? PortablePackage.FindExecutable(directory, tool) : null;
                if (executable == null && key?.GetValue("DisplayIcon") is string icon)
                {
                    string candidate = icon.Split(',')[0].Trim('"');
                    if (candidate.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) && File.Exists(candidate) &&
                        Path.GetFileNameWithoutExtension(candidate).Equals(tool.Name, StringComparison.OrdinalIgnoreCase)) executable = candidate;
                }
                if (executable != null) return new(tool.Id, version, executable, Catalog.Architecture, true);
            }
        }
        return null;
    }
}
