// SPDX-License-Identifier: MIT
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace uLEAPP;

public sealed record Tool(string Id, string Name, string Description, string Repository, bool InstallerOnly = false, string? PackageName = null)
{
    public string AssetName => PackageName ?? Name;
}

public static class Catalog
{
    public static readonly Tool[] All = [
        new("lava", "LAVA", "Artifact viewer · separate freeware license", "leapps-org/LAVA-releases", true),
        new("aleapp", "ALEAPP", "Android artifacts", "abrignoni/ALEAPP"),
        new("ileapp", "iLEAPP", "iOS & iPadOS artifacts", "abrignoni/iLEAPP"),
        new("rleapp", "RLEAPP", "Provider returns", "abrignoni/RLEAPP"),
        new("vleapp", "VLEAPP", "Vehicle artifacts", "abrignoni/VLEAPP"),
        new("dleapp", "DLEAPP", "Desktop artifacts", "abrignoni/DLEAPP"),
        new("gleapp", "GLEAPP", "Image & video triage", "abrignoni/GLEAPP"),
        new("batch-leapp", "Batch LEAPP", "Run LEAPPs across multiple extractions", "abrignoni/batch-leapp", PackageName: "Batch-LEAPP"),
        new("mapdownloader", "Map Downloader", "Download offline maps for GLEAPP", "abrignoni/GLEAPP-MapDownloader", PackageName: "GLEAPP-MapDownloader")
    ];
    public static string Architecture => RuntimeInformation.OSArchitecture == System.Runtime.InteropServices.Architecture.Arm64 ? "arm64" : "x64";
    public static string Version => "0.3.14";
}

public sealed class ToolRow(Tool tool) : INotifyPropertyChanged
{
    public Tool Tool { get; } = tool;
    public string Name => Tool.Name;
    public System.Windows.Media.ImageSource Icon { get; } = ToolIcons.Load(tool.Id);
    public string Description => Tool.Description;
    public string Detail => Description + (IsInstalled ? (Installed?.InstallerManaged == true ? " · Installed in Windows" : " · Launch opens the selected copy") : "") + (Release != null && Release.Asset.Architecture != Catalog.Architecture ? " · x64 through Windows emulation" : "");
    public string PillLabel => Status switch {
        "Up to date" => "Up to date · " + Version,
        "Installed" => "Installed · " + Version,
        "Update available" when Release != null => IsInstalled ? "Update " + Version + " → " + Release.Version : "Available · " + Release.Version,
        "Available" when Release != null => "Available · " + Release.Version,
        _ => Status
    };
    private DateTimeOffset? checkedAt;
    public DateTimeOffset? CheckedAt { get => checkedAt; set { checkedAt = value; Changed(nameof(StatusHelp)); } }
    public string StatusHelp => CheckedAt is DateTimeOffset date ? (Status == "Needs attention" ? "Open Details for the error. Last successful GitHub check: " : "Checked against GitHub ") + (date.LocalDateTime.Date == DateTime.Today ? "today, " + date.ToLocalTime().ToString("t") : date.ToLocalTime().ToString("g")) : "Not checked against GitHub in this session.";
    private void PresentationChanged() { foreach (var property in new[] { nameof(PillLabel), nameof(Detail), nameof(StatusHelp) }) Changed(property); }
    private string version = "", status = "Not installed", latest = "";
    private bool working;
    public string Version { get => version; set { version = value; Changed(); Changed(nameof(ActionLabel)); Changed(nameof(IsInstalled)); Changed(nameof(ActionVisibility)); PresentationChanged(); } }
    public string Status { get => status; set { status = value; Changed(); Changed(nameof(StatusColor)); Changed(nameof(ActionVisibility)); PresentationChanged(); } }
    public string StatusColor => Status == "Needs attention" ? "#FA3B6A" : Status == "Update available" ? "#FF9C38" : Status == "Up to date" ? "#8EE563" : "#A7B4AB";
    public string Latest { get => latest; set { latest = value; Changed(); Changed(nameof(Detail)); } }
    public bool Working { get => working; set { working = value; Changed(); Changed(nameof(ActionEnabled)); } }
    public bool ActionEnabled => !Working;
    public bool IsInstalled => !string.IsNullOrWhiteSpace(Version);
    public string ActionLabel => IsInstalled ? "Update" : "Install";
    public System.Windows.Visibility ActionVisibility => IsInstalled && Status == "Up to date" ? System.Windows.Visibility.Collapsed : System.Windows.Visibility.Visible;
    private Release? release;
    public Release? Release { get => release; set { release = value; PresentationChanged(); } }
    private Installation? installed;
    public Installation? Installed { get => installed; set { installed = value; PresentationChanged(); } }
    public event PropertyChangedEventHandler? PropertyChanged;
    private void Changed([CallerMemberName] string? name = null) => PropertyChanged?.Invoke(this, new(name));
}

public sealed record Installation(string Id, string Version, string Path, string Architecture, bool InstallerManaged = false);
public sealed record Release(string Version, Asset Asset, string Page);
public sealed record Asset(string Name, Uri Url, string Sha256, long Size, bool IsInstaller, string Architecture);
