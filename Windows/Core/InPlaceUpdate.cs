// SPDX-License-Identifier: MIT
using System.Text.Json;

namespace uLEAPP;

// Stage a complete replacement beside the app, then swap folders. Unknown files
// are copied unchanged and the original folder is retained as a rollback copy.
public static class InPlaceUpdate
{
    private sealed record Journal(string ToolId, string Folder, string Staging, string Backup, Installation Result);
    internal static IReadOnlyList<Installation> Recover(string dataDirectory)
    {
        var recovered = new List<Installation>();
        if (!Directory.Exists(dataDirectory)) return recovered;
        foreach (string file in Directory.EnumerateFiles(dataDirectory,"pending-location-*.json")) {
            var journal = JsonSerializer.Deserialize<Journal>(File.ReadAllText(file)) ?? throw new IOException("An interrupted update record is unreadable.");
            if (journal.Result == null || !Catalog.All.Any(t => t.Id == journal.ToolId)) throw new IOException("An interrupted update names an unknown app.");
            ValidateFolder(journal.Folder);
            string parent = Path.GetDirectoryName(Path.GetFullPath(journal.Folder))!;
            foreach (string path in new[] {journal.Staging,journal.Backup}) {
                if (!Path.IsPathFullyQualified(path) || !Path.GetDirectoryName(Path.GetFullPath(path))!.Equals(parent,StringComparison.OrdinalIgnoreCase) ||
                    !System.Text.RegularExpressions.Regex.IsMatch(Path.GetFileName(path),@"^\.uleapp-(staging|previous)-" + System.Text.RegularExpressions.Regex.Escape(journal.ToolId) + @"-[a-f0-9]{32}$"))
                    throw new IOException("An interrupted update record has unsafe folder paths.");
                PlainParents(path);
            }
            if (!Directory.Exists(journal.Folder) && Directory.Exists(journal.Backup)) Directory.Move(journal.Backup,journal.Folder);
            string marker = Path.Combine(journal.Folder,".uleapp-release.json");
            if (File.Exists(marker)) {
                var record = JsonSerializer.Deserialize<Installation>(File.ReadAllText(marker));
                if (record == journal.Result && record.Id == journal.ToolId &&
                    Path.GetDirectoryName(Path.GetFullPath(record.Path))!.Equals(Path.GetFullPath(journal.Folder),StringComparison.OrdinalIgnoreCase) && File.Exists(record.Path)) recovered.Add(record);
            }
            // A present destination is a complete published tree. Its marker is
            // read by discovery, even if saving selected state was interrupted.
            File.Delete(file);
        }
        return recovered;
    }

    public static void ValidateFolder(string folder)
    {
        if (!Path.IsPathFullyQualified(folder) || folder.StartsWith(@"\\"))
            throw new IOException("Choose a dedicated app folder on a local Windows drive.");
        string full = Path.TrimEndingDirectorySeparator(Path.GetFullPath(folder));
        var forbidden = new[] { Path.GetPathRoot(full), Environment.GetFolderPath(Environment.SpecialFolder.Windows),
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
            Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), Path.GetTempPath(),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),"Downloads") };
        string windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        if (forbidden.Any(p => !string.IsNullOrEmpty(p) && full.Equals(Path.TrimEndingDirectorySeparator(p),StringComparison.OrdinalIgnoreCase)) ||
            (!string.IsNullOrEmpty(windows) && full.StartsWith(windows + Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)))
            throw new IOException("Choose a dedicated folder for this app, rather than a system or shared user folder.");
        if (Environment.ProcessPath is string own && own.StartsWith(full + Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))
            throw new IOException("The LEAPP app must have its own folder separate from uLEAPP.");
        PlainParents(full);
    }
    private static void PlainParents(string path)
    {
        for (string? part = Path.GetFullPath(path); part != null; part = Path.GetDirectoryName(part))
            if ((File.Exists(part) || Directory.Exists(part)) && (File.GetAttributes(part) & FileAttributes.ReparsePoint) != 0)
                throw new IOException("Linked installation folders are not replaced.");
    }
    private static void CopyTree(string source, string destination, CancellationToken cancellation)
    {
        PlainParents(source);
        Directory.CreateDirectory(destination);
        foreach (string path in Directory.EnumerateFileSystemEntries(source)) {
            cancellation.ThrowIfCancellationRequested();
            if ((File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0) throw new IOException("Linked files inside the app folder were preserved; this installation needs manual updating.");
            string target = Path.Combine(destination,Path.GetFileName(path));
            if (Directory.Exists(path)) CopyTree(path,target,cancellation);
            else { Directory.CreateDirectory(Path.GetDirectoryName(target)!); File.Copy(path,target,true); }
        }
    }
    private static Dictionary<string,string> Snapshot(string folder, CancellationToken cancellation)
    {
        var result = new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
        void Visit(string directory) {
            foreach (string path in Directory.EnumerateFileSystemEntries(directory)) {
                cancellation.ThrowIfCancellationRequested();
                PlainParents(path);
                string relative = Path.GetRelativePath(folder,path);
                if (Directory.Exists(path)) { result.Add(relative,"directory"); Visit(path); }
                else { using var stream = File.OpenRead(path); result.Add(relative,Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(stream))); }
            }
        }
        Visit(folder); return result;
    }
    public static Installation Apply(Tool tool, Release release, Installation? existing, string extracted, string chosenFolder,
        InstallationStore store, CancellationToken cancellation)
    {
        string folder = Path.GetFullPath(existing == null ? chosenFolder : Path.GetDirectoryName(existing.Path)!);
        ValidateFolder(folder);
        if (existing != null && existing.Id != tool.Id) throw new IOException("The selected installation does not match this tool.");
        if (existing == null && Directory.Exists(folder) && Directory.EnumerateFileSystemEntries(folder).Any())
            throw new IOException("That folder is not empty. Use 'Use existing installation' for an installed copy, or choose an empty app folder.");
        string executable = PortablePackage.FindExecutable(extracted,tool) ?? throw new InvalidDataException("The official archive has no recognized app executable.");
        string payload = Path.GetDirectoryName(executable)!;
        string parent = Path.GetDirectoryName(folder)!;
        Directory.CreateDirectory(parent);
        PlainParents(parent);
        string suffix = Guid.NewGuid().ToString("N");
        string staging = Path.Combine(parent,".uleapp-staging-" + tool.Id + "-" + suffix);
        string backup = Path.Combine(parent,".uleapp-previous-" + tool.Id + "-" + suffix);
        bool movedOriginal = false, published = false, wroteJournal = false;
        Dictionary<string,string>? originalSnapshot = null;
        string journal = Path.Combine(store.DataDirectory,"pending-location-" + tool.Id + ".json");
        try {
            if (existing != null) {
                if (!File.Exists(existing.Path)) throw new IOException("The existing executable was not found. Its location was not changed.");
                // Avoid replacing a shared folder holding another LEAPP tool.
                if (Catalog.All.Where(t => t.Id != tool.Id).Any(t => PortablePackage.FindExecutable(folder,t) != null))
                    throw new IOException("This folder contains other LEAPP tools. Move this app into its own folder before updating it.");
                store.Record(existing);
                originalSnapshot = Snapshot(folder,cancellation);
                CopyTree(folder,staging,cancellation);
            } else Directory.CreateDirectory(staging);
            CopyTree(payload,staging,cancellation);
            // Preserve legal/readme files outside a publisher's wrapper directory.
            int noticeLevel = 0;
            for (string? ancestor = Path.GetDirectoryName(payload); ancestor != null && (ancestor.Equals(extracted,StringComparison.OrdinalIgnoreCase) || ancestor.StartsWith(extracted + Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)); ancestor = Path.GetDirectoryName(ancestor)) {
                foreach (string notice in Directory.EnumerateFiles(ancestor)) {
                    string name = Path.GetFileName(notice);
                    if (!new[] {"LICENSE","COPYING","NOTICE","THIRD-PARTY","README"}.Any(prefix => name.StartsWith(prefix,StringComparison.OrdinalIgnoreCase))) continue;
                    string notices = Path.Combine(staging,".uleapp-publisher-notices",noticeLevel.ToString());
                    Directory.CreateDirectory(notices); File.Copy(notice,Path.Combine(notices,name),true);
                }
                noticeLevel++;
            }
            string executableName = existing == null ? Path.GetFileName(executable) : Path.GetFileName(existing.Path);
            if (!executableName.Equals(Path.GetFileName(executable),StringComparison.OrdinalIgnoreCase))
                File.Copy(executable,Path.Combine(staging,executableName),true);
            var result = new Installation(tool.Id,release.Version,Path.Combine(folder,executableName),release.Asset.Architecture);
            // Existing Windows uninstall records belong to the publisher's old
            // installer. uLEAPP tracks the replacement itself, without rewriting them.
            string marker = Path.Combine(staging,".uleapp-release.json");
            File.WriteAllText(marker,JsonSerializer.Serialize(result));
            cancellation.ThrowIfCancellationRequested();
            if (originalSnapshot != null) {
                var latest = Snapshot(folder,cancellation);
                if (latest.Count != originalSnapshot.Count || originalSnapshot.Any(item => !latest.TryGetValue(item.Key,out var hash) || hash != item.Value))
                    throw new IOException("Files in the app folder changed while preparing the update. Nothing was replaced; close the app and try again.");
            }
            if (existing == null && Directory.Exists(folder) && Directory.EnumerateFileSystemEntries(folder).Any())
                throw new IOException("The chosen folder is no longer empty. Nothing was replaced.");
            Directory.CreateDirectory(store.DataDirectory);
            using (var stream = new FileStream(journal,FileMode.CreateNew,FileAccess.Write,FileShare.None)) {
                wroteJournal = true;
                JsonSerializer.Serialize(stream,new Journal(tool.Id,folder,staging,backup,result)); stream.Flush(true);
            }
            PlainParents(folder);
            if (Directory.Exists(folder)) { Directory.Move(folder,backup); movedOriginal = true; }
            try {
                Directory.Move(staging,folder); published = true;
                store.Record(result);
            } catch {
                if (published) { Directory.Move(folder,staging); published = false; }
                if (movedOriginal) { Directory.Move(backup,folder); movedOriginal = false; }
                throw;
            }
            try { File.Delete(journal); } catch (IOException) { } catch (UnauthorizedAccessException) { }
            return result;
        }
        catch (UnauthorizedAccessException error) {
            throw new IOException("Windows did not allow updating " + folder + ". Reopen uLEAPP as administrator to update this location, or check the folder permissions. No separate AppData copy was installed.",error);
        }
        finally {
            // Never remove the original rollback copy, including after a failed
            // rollback. It can contain case files and manually installed content.
            if (wroteJournal && Directory.Exists(folder) && !published) { try { File.Delete(journal); } catch (IOException) { } catch (UnauthorizedAccessException) { } }
            if (Directory.Exists(staging)) { try { Directory.Delete(staging,true); } catch (IOException) { } catch (UnauthorizedAccessException) { } }
        }
    }
}
