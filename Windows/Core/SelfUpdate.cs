// SPDX-License-Identifier: MIT
using System.Net.Http;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace uLEAPP;

public sealed record AppUpdate(string Version, Uri Download, Uri Page);
public static class SelfUpdate
{
    private const string Repository = "CyberMike81/uLEAPP";
    public static AppUpdate? Select(JsonElement json, string current, string architecture)
    {
        string tag = json.GetProperty("tag_name").GetString() ?? "";
        if (json.GetProperty("draft").GetBoolean() || json.GetProperty("prerelease").GetBoolean() ||
            !Regex.IsMatch(tag, @"^v?\d+\.\d+\.\d+$") || architecture is not ("x64" or "arm64")) return null;
        string version = tag.TrimStart('v');
        if (!Installer.NeedsUpdate(current, version)) return null;
        string page = $"https://github.com/{Repository}/releases/tag/{tag}";
        string name = $"uLEAPP-{version}-Windows-{(architecture == "arm64" ? "ARM64" : "x64")}.zip";
        string download = $"https://github.com/{Repository}/releases/download/{tag}/{name}";
        var matches = json.GetProperty("assets").EnumerateArray().Where(a =>
            a.GetProperty("name").GetString() == name && a.GetProperty("browser_download_url").GetString() == download).ToArray();
        if (matches.Length != 1 || json.GetProperty("html_url").GetString() != page) return null;
        return new(version, new Uri(download), new Uri(page));
    }
    public static async Task<AppUpdate?> CheckAsync()
    {
        using var client = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false })
            { Timeout = TimeSpan.FromSeconds(15), MaxResponseContentBufferSize = 1024 * 1024 };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("uLEAPP/" + Catalog.Version);
        using var json = JsonDocument.Parse(await GitHubMetadata.FetchAsync(client,$"https://api.github.com/repos/{Repository}/releases/latest",CancellationToken.None).ConfigureAwait(false));
        return Select(json.RootElement, Catalog.Version, Catalog.Architecture);
    }
}
