// SPDX-License-Identifier: MIT
using System.Windows.Media.Imaging;

namespace uLEAPP;

public static class ToolIcons
{
    public static BitmapSource Load(string id)
    {
        if (!Catalog.All.Any(tool => tool.Id == id)) throw new InvalidDataException("Unsupported tool icon.");
        using var source = typeof(ToolIcons).Assembly.GetManifestResourceStream("uLEAPP.tool-icons." + id + ".png")
            ?? throw new InvalidDataException("A packaged LEAPP icon is missing: " + id);
        var image = new BitmapImage();
        image.BeginInit(); image.CacheOption = BitmapCacheOption.OnLoad; image.StreamSource = source; image.EndInit();
        image.Freeze();
        return image;
    }
}
