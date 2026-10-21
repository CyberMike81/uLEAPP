// SPDX-License-Identifier: MIT
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace uLEAPP;

public sealed record Tool(string Id, string Name, string Description, string Repository, bool InstallerOnly = false);

public static class Catalog
{
    public static readonly Tool[] All = [
        new("lava", "LAVA", "Artifact viewer · separate freeware license", "leapps-org/LAVA-releases", true),
        new("aleapp", "ALEAPP", "Android artifacts", "abrignoni/ALEAPP"),
        new("ileapp", "iLEAPP", "iOS & iPadOS artifacts", "abrignoni/iLEAPP"),
        new("rleapp", "RLEAPP", "Provider returns", "abrignoni/RLEAPP"),
        new("vleapp", "VLEAPP", "Vehicle artifacts", "abrignoni/VLEAPP"),
        new("dleapp", "DLEAPP", "Desktop artifacts", "abrignoni/DLEAPP"),
        new("gleapp", "GLEAPP", "Image & video triage", "abrignoni/GLEAPP")
    ];
    public static string Architecture => RuntimeInformation.OSArchitecture == System.Runtime.InteropServices.Architecture.Arm64 ? "arm64" : "x64";
    public static string Version => "0.3.1";
}

public sealed class ToolRow(Tool tool) : INotifyPropertyChanged
{
    public Tool Tool { get; } = tool;
    public string Name => Tool.Name;
    public System.Windows.Media.ImageSource Icon { get; } = ToolIcons.Load(tool.Id);
    public string Description => Tool.Description;
    private string version = "", status = "Not installed", latest = "";
    private bool working;
    public string Version { get => version; set { version = value; Changed(); Changed(nameof(ActionLabel)); Changed(nameof(IsInstalled)); Changed(nameof(ActionVisibility)); } }
    public string Status { get => status; set { status = value; Changed(); Changed(nameof(StatusColor)); Changed(nameof(ActionVisibility)); } }
    public string StatusColor => Status == "Needs attention" ? "#FA3B6A" : Status == "Update available" ? "#FF9C38" : Status == "Not installed" ? "#A7B4AB" : "#8EE563";
    public string Latest { get => latest; set { latest = value; Changed(); } }
    public bool Working { get => working; set { working = value; Changed(); Changed(nameof(ActionEnabled)); } }
    public bool ActionEnabled => !Working;
    public bool IsInstalled => !string.IsNullOrWhiteSpace(Version);
    public string ActionLabel => IsInstalled ? "Update" : "Install";
    public System.Windows.Visibility ActionVisibility => IsInstalled && Status == "Up to date" ? System.Windows.Visibility.Collapsed : System.Windows.Visibility.Visible;
    public Release? Release { get; set; }
    public Installation? Installed { get; set; }
    public event PropertyChangedEventHandler? PropertyChanged;
    private void Changed([CallerMemberName] string? name = null) => PropertyChanged?.Invoke(this, new(name));
}

public sealed record Installation(string Id, string Version, string Path, string Architecture, bool InstallerManaged = false);
public sealed record Release(string Version, Asset Asset, string Page);
public sealed record Asset(string Name, Uri Url, string Sha256, long Size, bool IsInstaller, string Architecture);
