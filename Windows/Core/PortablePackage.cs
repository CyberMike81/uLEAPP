// SPDX-License-Identifier: MIT
using System.IO.Compression;
using System.Text.RegularExpressions;

namespace uLEAPP;

public static class PortablePackage
{
    public static void Extract(string archivePath, string destination)
    {
        if (Directory.Exists(destination)) throw new IOException("Extraction needs a new, empty staging folder.");
        using var archive = ZipFile.OpenRead(archivePath);
        if (archive.Entries.Count is 0 or > 50000) throw new InvalidDataException("Unexpected archive entry count.");
        string prefix = Path.GetFullPath(destination) + Path.DirectorySeparatorChar;
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var paths = new List<(ZipArchiveEntry Entry, string Path, bool Directory)>();
        long expanded = 0;
        foreach (var entry in archive.Entries)
        {
            string relative = entry.FullName.Replace('\\', '/');
            bool directory = relative.EndsWith('/');
            var segments = relative.TrimEnd('/').Split('/');
            if (relative.StartsWith('/') || segments.Any(part => part is "" or "." or ".." ||
                part.EndsWith('.') || part.EndsWith(' ') || part.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 ||
                Regex.IsMatch(part, @"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)", RegexOptions.IgnoreCase)))
                throw new InvalidDataException("The archive contains an unsafe Windows path.");
            if (((entry.ExternalAttributes >> 16) & 0xF000) == 0xA000 || (entry.ExternalAttributes & 0x400) != 0)
                throw new InvalidDataException("Symbolic links and reparse points are not supported in app archives.");
            string target = Path.GetFullPath(Path.Combine(destination, Path.Combine(segments)));
            if (!target.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) || !seen.Add(target))
                throw new InvalidDataException("The archive contains a duplicate or escaping path.");
            expanded = checked(expanded + entry.Length);
            if (entry.Length > 2L * 1024 * 1024 * 1024 || expanded > 8L * 1024 * 1024 * 1024)
                throw new InvalidDataException("The expanded app is larger than the supported limit.");
            paths.Add((entry, target, directory));
        }
        Directory.CreateDirectory(destination);
        foreach (var (entry, target, directory) in paths)
        {
            if (directory) { Directory.CreateDirectory(target); continue; }
            Directory.CreateDirectory(Path.GetDirectoryName(target)!);
            using var input = entry.Open();
            using var output = new FileStream(target, FileMode.CreateNew, FileAccess.Write, FileShare.None);
            byte[] buffer = new byte[131072];
            long written = 0;
            int count;
            while ((count = input.Read(buffer)) > 0)
            {
                written += count;
                if (written > entry.Length) throw new InvalidDataException("Archive entry size differs from its metadata.");
                output.Write(buffer, 0, count);
            }
            if (written != entry.Length) throw new InvalidDataException("An app archive entry was truncated.");
        }
    }

    public static string? FindExecutable(string directory, Tool tool)
    {
        string[] names = [tool.Name + ".exe", tool.AssetName + ".exe", tool.Id + "GUI.exe", tool.Id + ".exe"];
        return Find(directory, 0);
        string? Find(string path, int depth)
        {
            if (!Directory.Exists(path) || (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0) return null;
            foreach (var name in names)
                foreach (var file in Directory.EnumerateFiles(path, "*.exe"))
                    if (Path.GetFileName(file).Equals(name, StringComparison.OrdinalIgnoreCase)) return file;
            if (depth >= 2) return null;
            foreach (var child in Directory.EnumerateDirectories(path))
            {
                var found = Find(child, depth + 1);
                if (found != null) return found;
            }
            return null;
        }
    }
}
