// SPDX-License-Identifier: MIT
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace uLEAPP;

public sealed record OldInstall(string ToolId, string Label, string Folder);

public static class OldInstalls
{
    private const string Inventory = ".uleapp-files.json";
    private sealed record Manifest(int Schema, string ToolId, string Version, Dictionary<string,string> Files);
    private static Dictionary<string,string> Snapshot(string folder, CancellationToken cancellation)
    {
        var entries = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
        void Visit(string directory)
        {
            cancellation.ThrowIfCancellationRequested();
            foreach (string path in Directory.EnumerateFileSystemEntries(directory))
            {
                cancellation.ThrowIfCancellationRequested();
                string relative = Path.GetRelativePath(folder,path).Replace('\\','/');
                if (relative == Inventory) continue;
                var attributes = File.GetAttributes(path);
                if ((attributes & FileAttributes.ReparsePoint) != 0) throw new IOException("A linked app folder was preserved.");
                if ((attributes & FileAttributes.Directory) != 0) { entries.Add(relative,"directory"); Visit(path); }
                else { using var stream = File.OpenRead(path); entries.Add(relative,Convert.ToHexString(SHA256.HashData(stream))); }
            }
        }
        Visit(folder);
        return entries;
    }
    public static void RecordFiles(string folder, Tool tool, string version, CancellationToken cancellation)
    {
        var manifest = new Manifest(1,tool.Id,version,Snapshot(folder,cancellation));
        using var stream = new FileStream(Path.Combine(folder,Inventory),FileMode.CreateNew,FileAccess.Write);
        JsonSerializer.Serialize(stream,manifest);
    }
    private static void CheckParents(string path)
    {
        for (var directory = new DirectoryInfo(path); directory != null; directory = directory.Parent)
            if ((directory.Attributes & FileAttributes.ReparsePoint) != 0) throw new IOException("Linked installation folders cannot be cleaned up.");
    }
    private static bool Unchanged(string folder, Tool tool, string version, CancellationToken cancellation)
    {
        try {
            string file = Path.Combine(folder,Inventory);
            if ((File.GetAttributes(file) & FileAttributes.ReparsePoint) != 0) return false;
            var manifest = JsonSerializer.Deserialize<Manifest>(File.ReadAllText(file));
            if (manifest == null || manifest.Schema != 1 || manifest.ToolId != tool.Id || manifest.Version != version || manifest.Files == null || manifest.Files.Count == 0) return false;
            var actual = Snapshot(folder,cancellation);
            return actual.Count == manifest.Files.Count && manifest.Files.All(item => actual.TryGetValue(item.Key,out var hash) && hash == item.Value);
        } catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException or ArgumentException) { return false; }
    }
    public static IReadOnlyList<OldInstall> Scan(InstallationStore store, CancellationToken cancellation)
    {
        var result = new List<OldInstall>();
        if (!Directory.Exists(store.Root)) return result;
        CheckParents(store.Root);
        foreach (var tool in Catalog.All)
        {
            cancellation.ThrowIfCancellationRequested();
            var current = store.Find(tool);
            if (current == null || current.InstallerManaged) continue;
            string root = Path.Combine(store.Root,tool.Name);
            if (!Directory.Exists(root)) continue;
            CheckParents(root);
            var versions = new List<(string Folder, Installation Record)>();
            foreach (string folder in Directory.EnumerateDirectories(root))
            {
                cancellation.ThrowIfCancellationRequested();
                if ((File.GetAttributes(folder) & FileAttributes.ReparsePoint) != 0 ||
                    !Regex.IsMatch(Path.GetFileName(folder),@"^[0-9]+(?:\.[0-9]+){1,3}-(?:x64|arm64)$")) continue;
                try {
                    string marker = Path.Combine(folder,".uleapp-release.json");
                    if ((File.GetAttributes(marker) & FileAttributes.ReparsePoint) != 0) continue;
                    var record = JsonSerializer.Deserialize<Installation>(File.ReadAllText(marker));
                    if (record == null || record.Id != tool.Id || record.InstallerManaged ||
                        record.Architecture is not ("x64" or "arm64") ||
                        Path.GetFileName(folder) != record.Version + "-" + record.Architecture ||
                        !Path.IsPathFullyQualified(record.Path) ||
                        !Path.GetFullPath(record.Path).StartsWith(Path.GetFullPath(folder) + Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase) ||
                        !File.Exists(record.Path) || !Version.TryParse(record.Version,out _)) continue;
                    versions.Add((folder,record));
                } catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException or ArgumentException) { }
            }
            var selected = versions.FirstOrDefault(item => item.Record.Path.Equals(current.Path,StringComparison.OrdinalIgnoreCase));
            if (selected.Record == null) continue;
            var ordered = versions.OrderByDescending(item => Version.Parse(item.Record.Version)).ThenByDescending(item => Directory.GetLastWriteTimeUtc(item.Folder)).ToArray();
            string? previous = ordered.FirstOrDefault(item => !item.Folder.Equals(selected.Folder,StringComparison.OrdinalIgnoreCase)).Folder;
            foreach (var item in ordered)
            {
                if (item.Folder.Equals(selected.Folder,StringComparison.OrdinalIgnoreCase) || item.Folder.Equals(previous,StringComparison.OrdinalIgnoreCase)) continue;
                if (Unchanged(item.Folder,tool,item.Record.Version,cancellation)) result.Add(new OldInstall(tool.Id,tool.Name + " " + item.Record.Version,item.Folder));
            }
        }
        return result;
    }
    public static bool Recycle(InstallationStore store, OldInstall reviewed, CancellationToken cancellation)
    {
        // Fresh scan protects a newer selection, changed contents, or changed root.
        if (!Scan(store,cancellation).Any(item => item == reviewed)) return false;
        cancellation.ThrowIfCancellationRequested();
        WindowsTrash.Move(reviewed.Folder);
        return true;
    }
}
