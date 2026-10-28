// SPDX-License-Identifier: MIT
using System.ComponentModel;
using System.Diagnostics;
using System.Security.Principal;

namespace uLEAPP;

public static class AdministratorRestart
{
    public static bool IsAdministrator {
        get { using var identity = WindowsIdentity.GetCurrent(); return new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator); }
    }
    internal static ProcessStartInfo StartInfo(string executable, string readyEvent, int parentPid, string userSid, bool noUpdateCheck)
    {
        var info = new ProcessStartInfo(executable) { UseShellExecute = true, Verb = "runas", WorkingDirectory = Path.GetDirectoryName(executable)! };
        foreach (string argument in new[] { "--elevation-ready", readyEvent, "--elevation-parent", parentPid.ToString(), "--elevation-user", userSid }) info.ArgumentList.Add(argument);
        if (noUpdateCheck) info.ArgumentList.Add("--no-update-check");
        return info;
    }
    public static async Task<bool> RequestAsync(bool noUpdateCheck)
    {
        if (IsAdministrator) return false;
        string executable = Environment.ProcessPath ?? throw new IOException("The uLEAPP executable could not be found.");
        using var identity = WindowsIdentity.GetCurrent();
        string sid = identity.User?.Value ?? throw new IOException("Your Windows account could not be identified.");
        string name = @"Local\uLEAPP-elevate-" + Guid.NewGuid().ToString("N");
        using var ready = new EventWaitHandle(false,EventResetMode.ManualReset,name);
        try {
            using var child = Process.Start(StartInfo(executable,name,Environment.ProcessId,sid,noUpdateCheck))
                ?? throw new IOException("Windows did not start the administrator window.");
            // Keep the normal window until the elevated copy confirms it uses the
            // same account. A cancelled UAC dialog never closes the working app.
            if (!await Task.Run(() => ready.WaitOne(TimeSpan.FromSeconds(20))))
                throw new IOException("The administrator restart was not confirmed. This window is still open; no update was retried. Windows must use the same account to keep your selected apps and shortcuts.");
            return true;
        } catch (Win32Exception error) when (IsCancellation(error)) { return false; }
    }
    internal static bool HasRestartArguments(string[] args) => args.Any(a => a.StartsWith("--elevation-",StringComparison.Ordinal));
    internal static void AcceptRestart(string[] args)
    {
        string Value(string flag) {
            int index = Array.IndexOf(args,flag);
            return index >= 0 && index + 1 < args.Length ? args[index+1] : throw new IOException("The administrator restart request is incomplete.");
        }
        using var identity = WindowsIdentity.GetCurrent();
        if (!IsAdministrator || Value("--elevation-user") != identity.User?.Value)
            throw new IOException("The administrator restart must use the same Windows account. Your original uLEAPP window is still open.");
        string eventName = Value("--elevation-ready");
        if (!System.Text.RegularExpressions.Regex.IsMatch(eventName,@"^Local\\uLEAPP-elevate-[a-f0-9]{32}$") ||
            !int.TryParse(Value("--elevation-parent"),out int pid) || pid <= 0 || pid == Environment.ProcessId)
            throw new IOException("The administrator restart request is invalid.");
        using var parent = Process.GetProcessById(pid);
        if (!string.Equals(parent.MainModule?.FileName,Environment.ProcessPath,StringComparison.OrdinalIgnoreCase))
            throw new IOException("The original uLEAPP window could not be verified.");
        using var ready = EventWaitHandle.OpenExisting(eventName);
        ready.Set();
        // The parent closes only after the above acknowledgement. Wait before
        // acquiring its single-instance mutex; never retry an install on startup.
        if (!parent.WaitForExit(30000)) throw new IOException("The original uLEAPP window did not close. Close this administrator copy and try again.");
    }
    internal static bool IsCancellation(Win32Exception error) => error.NativeErrorCode == 1223;
    public static bool IsPermissionFailure(Exception error) => error is Win32Exception native ? native.NativeErrorCode == 5 :
        error is UnauthorizedAccessException || (error.HResult & 0xffff) == 5 || (error.InnerException != null && IsPermissionFailure(error.InnerException));
}
