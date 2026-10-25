// SPDX-License-Identifier: MIT
using System.Text.Json.Nodes;
namespace uLEAPP;
public static class UpdatePreferences
{
    private static string FileName => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"uLEAPP","preferences.json");
    public static bool Load() => LoadOption("AutomaticUpdateChecks");
    public static void Save(bool enabled) => SaveOption("AutomaticUpdateChecks", enabled);
    public static bool LoadOption(string option, string? path = null)
    {
        try { return JsonNode.Parse(File.ReadAllText(path ?? FileName))?[option]?.GetValue<bool>() ?? true; }
        catch (FileNotFoundException) { return true; }
        catch (DirectoryNotFoundException) { return true; }
        catch { return false; }
    }
    public static void SaveOption(string option, bool enabled, string? path = null)
    {
        string file = path ?? FileName;
        JsonObject preferences;
        try { preferences = JsonNode.Parse(File.ReadAllText(file)) as JsonObject ?? throw new IOException("Saved preferences could not be read."); }
        catch (FileNotFoundException) { preferences = new(); }
        catch (DirectoryNotFoundException) { preferences = new(); }
        preferences[option] = enabled;
        Directory.CreateDirectory(Path.GetDirectoryName(file)!);
        string temporary = file + "." + Guid.NewGuid().ToString("N");
        try { File.WriteAllText(temporary, preferences.ToJsonString()); File.Move(temporary,file,true); }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}
