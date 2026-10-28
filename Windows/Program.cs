// SPDX-License-Identifier: MIT
using System.Windows;

namespace uLEAPP;

public static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        try
        {
            if (args.Contains("--version")) { Console.WriteLine("uLEAPP " + Catalog.Version); return 0; }
            int diagnostic = Array.IndexOf(args,"--diagnose-app");
            if (diagnostic >= 0)
            {
                var tool = diagnostic + 1 < args.Length ? Catalog.All.FirstOrDefault(t => t.Id == args[diagnostic + 1]) : null;
                if (tool == null) { Console.Error.WriteLine("Use --diagnose-app followed by a supported tool ID."); return 2; }
                var installed = InstallationStore.FindRegistered(tool);
                Console.WriteLine(System.Text.Json.JsonSerializer.Serialize(new { Tool=tool.Name, Installed=installed != null, installed?.Version, installed?.Path }));
                return installed == null ? 1 : 0;
            }
            if (args.Contains("--help"))
            {
                Console.WriteLine("uLEAPP for Windows\n--no-update-check Disable automatic update requests for this run\n--version       Report the app version\n--selfcheck     Check packaging and updater behavior without changing apps\n--diagnose-app ID Report the registered executable for a supported app, without changes\n--demo          Preview a clean Windows installation\n--demo-installed Preview installed apps"); return 0;
            }
            if (args.Contains("--selfcheck"))
            {
                int fixtureFlag = Array.IndexOf(args,"--release-fixtures");
                SelfChecks.RunAsync(fixtureFlag >= 0 && fixtureFlag + 1 < args.Length ? args[fixtureFlag+1] : null).GetAwaiter().GetResult(); return 0;
            }
            if (AdministratorRestart.HasRestartArguments(args)) AdministratorRestart.AcceptRestart(args);
            using var singleInstance = new Mutex(true, @"Local\uLEAPP-" + Environment.UserName, out bool first);
            if (!first) { MessageBox.Show("uLEAPP is already open in this Windows session.", "uLEAPP"); return 0; }
            var application = new Application();
            return application.Run(new MainWindow(args.Contains("--demo") || args.Contains("--demo-installed"), args.Contains("--demo-installed")));
        }
        catch (Exception error)
        {
            Console.Error.WriteLine(error);
            if (!args.Contains("--selfcheck") && !args.Contains("--version") && !args.Contains("--diagnose-app")) MessageBox.Show(error.Message, "uLEAPP needs attention");
            return 1;
        }
    }
}
