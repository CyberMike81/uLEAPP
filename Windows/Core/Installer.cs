// SPDX-License-Identifier: MIT
using System.Diagnostics;
using System.Text.Json;

namespace uLEAPP;

public sealed class Installer(ReleaseClient releases, InstallationStore store)
{
    public static bool IsCurrent(string? installed, string latest) =>
        string.Equals(installed?.TrimStart('v'), latest.TrimStart('v'), StringComparison.OrdinalIgnoreCase);
    public static bool NeedsUpdate(string installed, string latest)
    {
        if (IsCurrent(installed, latest)) return false;
        static Version? Parse(string value)
        {
            if (!Version.TryParse(value.TrimStart('v').Split('-','+')[0], out var version)) return null;
            return new Version(version.Major, version.Minor, Math.Max(0,version.Build), Math.Max(0,version.Revision));
        }
        var current = Parse(installed); var target = Parse(latest);
        return current == null || target == null || current < target;
    }

    public async Task<Installation> InstallAsync(Tool tool, Release release, Installation? existing,
        Action<string> status, Action<double> progress, CancellationToken cancellation, string? newFolder = null)
    {
        store.EnsureSettingsWritable();
        if (!release.Asset.IsInstaller) {
            if (existing == null && newFolder == null) {
                existing = store.Find(tool);
                newFolder = Path.Combine(store.Root,tool.Name);
            }
            InPlaceUpdate.ValidateFolder(existing == null ? newFolder! : Path.GetDirectoryName(existing.Path)!);
        }
        if (existing != null && !NeedsUpdate(existing.Version,release.Version)) return existing;
        if (existing != null) EnsureClosed(existing.Path);
        string temporary = Path.Combine(Path.GetTempPath(), "uLEAPP", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(temporary);
        try
        {
            string package = Path.Combine(temporary, release.Asset.Name);
            status($"Downloading {tool.Name}" + (release.Asset.Architecture != Catalog.Architecture ? " · x64 emulation" : ""));
            await releases.DownloadAsync(release.Asset, package, progress, cancellation).ConfigureAwait(false);
            status("Checksum verified");
            cancellation.ThrowIfCancellationRequested();
            Installation result;
            if (release.Asset.IsInstaller)
            {
                status($"Complete {tool.Name} setup to continue");
                using var setup = Process.Start(new ProcessStartInfo(package) { UseShellExecute = true }) ?? throw new IOException("The official installer did not start.");
                // Do not cancel or kill an installer mid-operation. The next app waits.
                await setup.WaitForExitAsync().ConfigureAwait(false);
                if (setup.ExitCode is not (0 or 3010)) throw new IOException($"{tool.Name} setup ended with code {setup.ExitCode}.");
                result = InstallationStore.FindRegistered(tool) ?? throw new IOException($"Setup finished, but {tool.Name}.exe was not found in its registered location. The installation is incomplete. Review the publisher's installer result, then try again.");
                if (!IsCurrent(result.Version, release.Version)) throw new IOException("The installer did not register the expected new version. Refresh after completing setup.");
                result = result with { Architecture = release.Asset.Architecture };
            }
            else
            {
                status($"Preparing {tool.Name}");
                string extracted = Path.Combine(temporary,"extracted");
                await Task.Run(() => PortablePackage.Extract(package,extracted),cancellation).ConfigureAwait(false);
                status("Preparing update in the existing app location");
                return await Task.Run(() => InPlaceUpdate.Apply(tool,release,existing,extracted,newFolder ?? "",store,cancellation),cancellation).ConfigureAwait(false);
            }
            store.Record(result);
            status("Ready");
            return result;
        }
        finally { try { Directory.Delete(temporary, true); } catch (IOException) { } catch (UnauthorizedAccessException) { } }
    }

    private static void EnsureClosed(string executable)
    {
        foreach (var process in Process.GetProcessesByName(Path.GetFileNameWithoutExtension(executable)))
        {
            using (process)
            {
                try
                {
                    if (process.MainModule?.FileName is string path && path.Equals(executable, StringComparison.OrdinalIgnoreCase))
                        throw new IOException("Close the app before updating it, then try again.");
                }
                catch (System.ComponentModel.Win32Exception) { throw new IOException("The app may be running with different permissions. Close it before updating."); }
            }
        }
    }
}
