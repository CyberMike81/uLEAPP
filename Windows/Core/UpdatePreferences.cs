// SPDX-License-Identifier: MIT
using System.Text.Json;
namespace uLEAPP;
public static class UpdatePreferences
{
    private static string FileName => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"uLEAPP","preferences.json");
    public static bool Load()
    {
        try { using var json = JsonDocument.Parse(File.ReadAllText(FileName)); return json.RootElement.GetProperty("AutomaticUpdateChecks").GetBoolean(); }
        catch (FileNotFoundException) { return true; }
        catch (DirectoryNotFoundException) { return true; }
        catch { return false; }
    }
    public static void Save(bool enabled)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(FileName)!);
        string temporary = FileName + "." + Guid.NewGuid().ToString("N");
        try { File.WriteAllText(temporary,JsonSerializer.Serialize(new { AutomaticUpdateChecks=enabled })); File.Move(temporary,FileName,true); }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}
