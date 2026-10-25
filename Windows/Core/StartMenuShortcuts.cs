// SPDX-License-Identifier: MIT
using System.Runtime.ExceptionServices;
using System.Runtime.InteropServices;

namespace uLEAPP;

public static class StartMenuShortcuts
{
    // A separate folder and an ownership marker keep publisher and user shortcuts untouched.
    private static string Marker(Tool tool) => "Created by uLEAPP for " + tool.Id;
    public static void Refresh(Tool tool, Installation installed, string? programsDirectory = null)
    {
        Exception? failure = null;
        var thread = new Thread(() => {
            try { RefreshOnSta(tool, installed, programsDirectory ?? Environment.GetFolderPath(Environment.SpecialFolder.Programs)); }
            catch (Exception error) { failure = error; }
        });
        thread.SetApartmentState(ApartmentState.STA); thread.Start(); thread.Join();
        if (failure != null) ExceptionDispatchInfo.Capture(failure).Throw();
    }
    private static void RequirePlainPath(string path)
    {
        for (string? part = Path.GetFullPath(path); part != null; part = Path.GetDirectoryName(part))
            if ((Directory.Exists(part) || File.Exists(part)) && (File.GetAttributes(part) & FileAttributes.ReparsePoint) != 0)
                throw new IOException("The Start menu shortcut location contains a symbolic link; it was left unchanged.");
    }
    private static void RefreshOnSta(Tool tool, Installation installed, string programs)
    {
        if (installed.Id != tool.Id || !Catalog.All.Any(t => t.Id == tool.Id && t.Name == tool.Name))
            throw new IOException("The installed app does not match the shortcut.");
        if (!Path.IsPathFullyQualified(installed.Path) || !File.Exists(installed.Path))
            throw new IOException("The installed executable was not found; the previous shortcut was kept.");
        if (string.IsNullOrWhiteSpace(programs) || !Path.IsPathFullyQualified(programs))
            throw new IOException("Your Start menu folder could not be found.");
        string folder = Path.Combine(programs, "uLEAPP");
        string destination = Path.Combine(folder, tool.Name + ".lnk");
        RequirePlainPath(destination);
        Directory.CreateDirectory(folder);
        string temporary = Path.Combine(folder, ".uleapp-" + Guid.NewGuid().ToString("N") + ".lnk");
        object? shell = null, previous = null, shortcut = null;
        try {
            shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell")!)!;
            if (File.Exists(destination)) {
                previous = ((dynamic)shell).CreateShortcut(destination);
                if ((string)((dynamic)previous).Description != Marker(tool))
                    throw new IOException("A shortcut with this name already exists and was not created by uLEAPP. Your shortcut was kept.");
            }
            shortcut = ((dynamic)shell).CreateShortcut(temporary);
            ((dynamic)shortcut).TargetPath = Path.GetFullPath(installed.Path);
            ((dynamic)shortcut).WorkingDirectory = Path.GetDirectoryName(Path.GetFullPath(installed.Path))!;
            ((dynamic)shortcut).IconLocation = Path.GetFullPath(installed.Path) + ",0";
            ((dynamic)shortcut).Description = Marker(tool);
            ((dynamic)shortcut).Save();
            RequirePlainPath(destination);
            // Stage first: a failed save cannot truncate the working shortcut.
            File.Move(temporary, destination, true);
        }
        finally {
            if (shortcut != null) Marshal.ReleaseComObject(shortcut);
            if (previous != null) Marshal.ReleaseComObject(previous);
            if (shell != null) Marshal.ReleaseComObject(shell);
            if (File.Exists(temporary)) File.Delete(temporary);
        }
    }

    // Read actual shell links for isolated native regression checks.
    internal static (string Target, string WorkingDirectory) ReadForCheck(string path)
    {
        (string, string) result = default;
        Exception? failure = null;
        var thread = new Thread(() => {
            object? shell = null, link = null;
            try {
                shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell")!)!;
                link = ((dynamic)shell).CreateShortcut(path);
                result = ((string)((dynamic)link).TargetPath, (string)((dynamic)link).WorkingDirectory);
            } catch (Exception error) { failure = error; }
            finally { if (link != null) Marshal.ReleaseComObject(link); if (shell != null) Marshal.ReleaseComObject(shell); }
        });
        thread.SetApartmentState(ApartmentState.STA); thread.Start(); thread.Join();
        if (failure != null) ExceptionDispatchInfo.Capture(failure).Throw();
        return result;
    }
}
