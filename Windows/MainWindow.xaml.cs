// SPDX-License-Identifier: MIT
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using Microsoft.Win32;

namespace uLEAPP;

public partial class MainWindow : Window, INotifyPropertyChanged
{
    public ObservableCollection<ToolRow> Rows { get; } = new(Catalog.All.Select(t => new ToolRow(t)));
    private readonly InstallationStore store;
    private readonly ReleaseClient releases = new();
    private readonly bool demo;
    private bool busy, stopping;
    private string title = "Your first LEAPP starts here", detail = "Install an app below, or install your missing apps together.", phase = "", log = "";
    private double progress;
    private StreamWriter? logWriter;
    public string PlatformLabel => demo ? "DEMO · NO APP CHANGES" : "WINDOWS · " + System.Runtime.InteropServices.RuntimeInformation.ProcessArchitecture.ToString().ToUpperInvariant() + " · " + Catalog.Version;
    public string StatusTitle { get => title; set { title = value; Changed(); } }
    public string StatusDetail { get => detail; set { detail = value; Changed(); } }
    public string Phase { get => phase; set { phase = value; Changed(); } }
    public string Log { get => log; set { log = value; Changed(); } }
    public double Progress { get => progress; set { progress = value; Changed(); } }
    public bool DetailsExpanded { get; set; }
    public bool ActionsEnabled => !busy;
    public bool StopEnabled => busy && !stopping;
    public string StopLabel => stopping ? "Stopping after this app…" : "Stop after this app";
    public Visibility ProgressVisibility => busy ? Visibility.Visible : Visibility.Collapsed;
    public int InstalledCount => Rows.Count(r => r.IsInstalled);
    public string InstalledSummary => $"{InstalledCount} of 7 installed";
    public string PrimaryLabel => InstalledCount == 0 ? "Install apps" : "Update apps";
    public Visibility PrimaryVisibility => !busy && InstalledCount > 0 && Rows.Where(r => r.IsInstalled).All(r => r.Status == "Up to date") ? Visibility.Collapsed : Visibility.Visible;
    public string MissingLabel => $"Install missing apps ({7 - InstalledCount})";
    public Visibility MissingVisibility => !busy && InstalledCount < 7 ? Visibility.Visible : Visibility.Collapsed;
    public bool InstallMissingEnabled => !busy && InstalledCount < 7;
    public string InstallFolder => "Portable apps: " + store.Root;
    public event PropertyChangedEventHandler? PropertyChanged;
    private void Changed([CallerMemberName] string? name = null) => PropertyChanged?.Invoke(this, new(name));
    private void RefreshControls()
    {
        foreach (string name in new[] { nameof(ActionsEnabled), nameof(StopEnabled), nameof(StopLabel), nameof(ProgressVisibility), nameof(InstalledSummary), nameof(PrimaryLabel), nameof(PrimaryVisibility), nameof(MissingLabel), nameof(MissingVisibility), nameof(InstallMissingEnabled), nameof(InstallFolder) }) Changed(name);
    }
    public MainWindow(bool demo = false, bool demoInstalled = false)
    {
        this.demo = demo;
        store = new InstallationStore(demo ? Path.Combine(Path.GetTempPath(), "uLEAPP-demo-" + Guid.NewGuid().ToString("N")) : null);
        InitializeComponent(); DataContext = this;
        Height = Math.Min(900, SystemParameters.WorkArea.Height - 30);
        Loaded += async (_, _) =>
        {
            if (demo)
            {
                if (demoInstalled) foreach (var row in Rows) { row.Version = row.Tool.Id == "lava" ? "0.15.0" : "2026.4.3"; row.Status = "Installed"; }
                StatusDetail = "Preview mode. No downloads or installed-app changes.";
            }
            else
            {
                try
                {
                    var found = await Task.Run(() => Rows.Select(r => (r, found: store.Find(r.Tool))).ToArray());
                    foreach (var (row, installed) in found) ApplyInstalled(row, installed);
                    if (InstalledCount > 0) { StatusTitle = "Ready for the next LEAPP"; StatusDetail = "Check your tools, then update them together."; }
                    if (store.RecoveryMessage != null) { StatusTitle = "Your settings need attention"; StatusDetail = store.RecoveryMessage; }
                }
                catch (Exception error) { StatusTitle = "Could not read your apps"; StatusDetail = error.Message; }
            }
            RefreshControls();
        };
    }
    private void ApplyInstalled(ToolRow row, Installation? installation)
    {
        row.Installed = installation; row.Version = installation?.Version ?? ""; row.Status = installation == null ? "Not installed" : "Installed";
    }
    private void WriteLog(string text)
    {
        Log += text + Environment.NewLine;
        if (Log.Length > 100000) Log = Log[^100000..];
        try { logWriter?.WriteLine(text); } catch (IOException) { }
    }
    private bool ConfirmLava(IEnumerable<ToolRow> targets)
    {
        if (demo || !targets.Any(r => r.Tool.Id == "lava" && !r.IsInstalled)) return true;
        var dialog = new Window { Owner = this, Title = "LAVA license", Width = 650, Height = 530, WindowStartupLocation = WindowStartupLocation.CenterOwner, Background = Brush("#111712"), Foreground = Brushes.White };
        var layout = new DockPanel { Margin = new Thickness(22) };
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(0,12,0,0) };
        var cancel = new Button { Content = "Cancel", Margin = new Thickness(0,0,10,0), Padding = new Thickness(14,8,14,8) };
        var install = new Button { Content = "Install LAVA", Padding = new Thickness(14,8,14,8), IsDefault = true };
        cancel.Click += (_,_) => dialog.DialogResult = false; install.Click += (_,_) => dialog.DialogResult = true;
        buttons.Children.Add(cancel); buttons.Children.Add(install); DockPanel.SetDock(buttons, Dock.Bottom); layout.Children.Add(buttons);
        var heading = new TextBlock { Text = "LAVA is freeware under LEAPPs' own license. Review the publisher's terms before installing. Its official setup will remain interactive.", TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0,0,0,12) };
        DockPanel.SetDock(heading, Dock.Top); layout.Children.Add(heading);
        string licenseFile = Path.Combine(AppContext.BaseDirectory, "licenses", "LAVA-EULA.txt");
        layout.Children.Add(new TextBox { Text = File.Exists(licenseFile) ? File.ReadAllText(licenseFile) : "Read the current terms at https://github.com/leapps-org/LAVA-releases/blob/main/LICENSE", IsReadOnly = true, TextWrapping = TextWrapping.Wrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Background = Brush("#1C241E"), Foreground = Brushes.White, BorderThickness = new Thickness(0), Padding = new Thickness(12) });
        dialog.Content = layout; return dialog.ShowDialog() == true;
    }
    private async Task RunAsync(bool check, IEnumerable<ToolRow> selected)
    {
        if (busy) return;
        var targets = selected.ToArray(); if (targets.Length == 0) return;
        if (!check && !ConfirmLava(targets)) return;
        busy = true; stopping = false; Log = ""; Progress = 0; RefreshControls();
        StatusTitle = check ? "Looking for the latest LEAPPs" : "Keeping your LEAPPs current";
        StatusDetail = check ? "Checking official releases for your Windows architecture." : "Keep your LEAPP apps closed. Official setup windows may ask you to finish installation.";
        int failures = 0, complete = 0, available = 0;
        try
        {
            if (!demo)
            {
                string directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "uLEAPP", "Logs");
                Directory.CreateDirectory(directory);
                logWriter = new StreamWriter(Path.Combine(directory, DateTime.Now.ToString("yyyy-MM-dd_HH-mm-ss") + "-" + Guid.NewGuid().ToString("N")[..6] + ".txt")) { AutoFlush = true };
            }
            var installer = new Installer(releases, store);
            foreach (var row in targets)
            {
                if (stopping) break;
                row.Working = true; row.Status = "Checking"; Phase = "Checking " + row.Name;
                try
                {
                    if (demo)
                    {
                        await Task.Delay(300);
                        if (!check && !row.IsInstalled) row.Version = row.Tool.Id == "lava" ? "0.15.0" : "2026.4.3";
                        row.Status = check && row.IsInstalled ? "Update available" : (row.IsInstalled ? "Up to date" : "Not installed");
                        WriteLog(row.Name + ": " + row.Status + " (demo)");
                    }
                    else
                    {
                        row.Release = await releases.LatestAsync(row.Tool, Catalog.Architecture, row.Installed?.InstallerManaged ?? false, CancellationToken.None);
                        var release = row.Release;
                        row.Latest = "Latest " + release.Version + (release.Asset.Architecture != Catalog.Architecture ? " · x64 through Windows emulation" : "");
                        if (row.IsInstalled && !Installer.NeedsUpdate(row.Version, release.Version)) row.Status = "Up to date";
                        else if (check)
                        {
                            row.Status = row.IsInstalled ? "Update available" : "Not installed";
                            if (row.IsInstalled) available++;
                        }
                        else
                        {
                            row.Status = row.IsInstalled ? "Updating" : "Installing";
                            WriteLog($"{row.Name}: official {release.Asset.Name}; SHA-256 {release.Asset.Sha256}");
                            var installed = await installer.InstallAsync(row.Tool, release, row.Installed,
                                text => { Phase = text; row.Status = text.StartsWith("Downloading") ? "Downloading" : text.StartsWith("Complete") ? "Finish setup" : "Installing"; },
                                fraction => { Progress = (complete + fraction * 0.7) / targets.Length; }, CancellationToken.None);
                            ApplyInstalled(row, installed); row.Status = "Up to date";
                        }
                        WriteLog(row.Name + ": " + row.Status);
                    }
                }
                catch (Exception error)
                {
                    row.Status = "Needs attention"; failures++; WriteLog(row.Name + ": " + error.Message);
                }
                finally { row.Working = false; complete++; Progress = (double)complete / targets.Length; RefreshControls(); }
            }
            if (stopping) { StatusTitle = "Stopped safely"; StatusDetail = "Completed work has been kept. Continue whenever you're ready."; }
            else if (failures > 0) { StatusTitle = "A few things need attention"; StatusDetail = "Open Details to see what happened, then try again."; DetailsExpanded = true; Changed(nameof(DetailsExpanded)); }
            else if (check) { StatusTitle = available > 0 ? $"{available} updates are ready" : "Your check is complete"; StatusDetail = InstalledCount == 0 ? "Choose Install beside an app, or install your missing apps together." : "Your installed tools have been checked. Missing tools are available to install."; }
            else { StatusTitle = "Your LEAPP apps are ready"; StatusDetail = "Installed apps are current. Older portable versions and your case files have been kept."; }
        }
        catch (Exception error) { StatusTitle = "Could not finish this operation"; StatusDetail = error.Message; WriteLog(error.Message); }
        finally { logWriter?.Dispose(); logWriter = null; busy = false; RefreshControls(); }
    }
    private async void CheckClicked(object sender, RoutedEventArgs e) => await RunAsync(true, Rows);
    private async void PrimaryClicked(object sender, RoutedEventArgs e) => await RunAsync(false, InstalledCount == 0 ? Rows.Where(r => !r.IsInstalled) : Rows.Where(r => r.IsInstalled));
    private async void InstallMissingClicked(object sender, RoutedEventArgs e) => await RunAsync(false, Rows.Where(r => !r.IsInstalled));
    private async void RowActionClicked(object sender, RoutedEventArgs e) { if ((sender as Button)?.Tag is ToolRow row) await RunAsync(false, [row]); }
    private void StopClicked(object sender, RoutedEventArgs e) { stopping = true; StatusDetail = "Will stop after this app finishes."; RefreshControls(); }
    private void CopyLogClicked(object sender, RoutedEventArgs e) { try { Clipboard.SetText(Log); } catch (System.Runtime.InteropServices.COMException) { StatusDetail = "The clipboard is busy. Try copying the log again."; } }
    private void ChooseFolderClicked(object sender, RoutedEventArgs e)
    {
        var picker = new OpenFolderDialog { Title = "Choose a Windows folder for portable LEAPP apps", InitialDirectory = store.Root };
        if (picker.ShowDialog(this) == true) { try { store.ChangeRoot(picker.FolderName); RefreshControls(); } catch (Exception error) { StatusDetail = error.Message; } }
    }
    private void LaunchClicked(object sender, RoutedEventArgs e)
    {
        if ((sender as Button)?.Tag is ToolRow { Installed: not null } row)
            try { Process.Start(new ProcessStartInfo(row.Installed.Path) { UseShellExecute = true, WorkingDirectory = Path.GetDirectoryName(row.Installed.Path) }); }
            catch (Exception error) { StatusDetail = error.Message; }
    }
    private void WindowClosing(object? sender, CancelEventArgs e)
    {
        if (busy) { e.Cancel = true; StatusDetail = "Keep uLEAPP open while this app finishes. Choose Stop after this app to finish the run early."; }
        else releases.Dispose();
    }
    public static SolidColorBrush Brush(string color) => (SolidColorBrush)new BrushConverter().ConvertFromString(color)!;
    private void AboutClicked(object sender, RoutedEventArgs e)
    {
        var about = new Window { Owner = this, Title = "About uLEAPP", Width = 610, Height = 570, WindowStartupLocation = WindowStartupLocation.CenterOwner, Background = Brush("#111712"), Foreground = Brushes.White };
        var content = new StackPanel { Margin = new Thickness(24) };
        content.Children.Add(new TextBlock { Text = "uLEAPP " + Catalog.Version, FontSize = 27, FontWeight = FontWeights.Bold, Foreground = Brush("#8EE563") });
        content.Children.Add(new TextBlock { Text = "Idea by", Margin = new Thickness(0,16,0,4) });
        var credit = new TextBlock(); var link = new Hyperlink(new Run("@CyberMike81")) { NavigateUri = new("https://github.com/CyberMike81"), Foreground = Brush("#FA3B6A") };
        link.RequestNavigate += (_,args) => { Process.Start(new ProcessStartInfo(args.Uri.AbsoluteUri) { UseShellExecute = true }); args.Handled = true; };
        credit.Inlines.Add(link); content.Children.Add(credit);
        content.Children.Add(new TextBlock { Text = "MIT licensed community updater. Each managed app keeps its own license.", TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0,14,0,12), Foreground = Brush("#A7B4AB") });
        string licensePath = Path.Combine(AppContext.BaseDirectory, "THIRD-PARTY-NOTICES.md");
        string ownPath = Path.Combine(AppContext.BaseDirectory, "LICENSE");
        string notices = (File.Exists(ownPath) ? File.ReadAllText(ownPath) : "License file missing.") + "\n\n" + (File.Exists(licensePath) ? File.ReadAllText(licensePath) : "Notices file missing.");
        content.Children.Add(new TextBox { Text = notices, Height = 315, IsReadOnly = true, TextWrapping = TextWrapping.Wrap, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Background = Brush("#1C241E"), Foreground = Brush("#A7B4AB"), BorderThickness = new Thickness(0), Padding = new Thickness(12), FontSize = 11 });
        about.Content = content; about.ShowDialog();
    }
}
