// SPDX-License-Identifier: MIT
using System.Diagnostics;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace uLEAPP;

public sealed class ReleaseClient : IDisposable
{
    private readonly HttpClient client;
    public TimeSpan ReadIdleTimeout { get; init; } = TimeSpan.FromSeconds(60);
    public ReleaseClient(HttpMessageHandler? handler = null)
    {
        client = new HttpClient(handler ?? new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromMinutes(15) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("uLEAPP/" + Catalog.Version);
        client.DefaultRequestHeaders.Accept.ParseAdd("application/vnd.github+json");
    }

    public async Task<Release> LatestAsync(Tool tool, string architecture, bool installerManaged, CancellationToken cancellation)
    {
        using var response = await client.GetAsync($"https://api.github.com/repos/{tool.Repository}/releases/latest", cancellation).ConfigureAwait(false);
        if (response.StatusCode == HttpStatusCode.Forbidden || (int)response.StatusCode == 429)
            throw new IOException("GitHub's download limit was reached. Please try again later.");
        response.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellation).ConfigureAwait(false));
        return Select(tool, json.RootElement, architecture, installerManaged);
    }

    public static Release Select(Tool tool, JsonElement json, string architecture, bool installerManaged = false)
    {
        if (architecture is not ("arm64" or "x64")) throw new InvalidDataException("Unsupported Windows architecture.");
        var tag = json.GetProperty("tag_name").GetString() ?? throw new InvalidDataException("Release version is missing.");
        if (!Regex.IsMatch(tag, @"^v?[0-9]+(?:\.[0-9]+){1,3}(?:[-+][0-9A-Za-z.-]+)?$"))
            throw new InvalidDataException("The publisher's release version is not supported.");
        if (json.TryGetProperty("draft", out var draft) && draft.GetBoolean() ||
            json.TryGetProperty("prerelease", out var preview) && preview.GetBoolean())
            throw new InvalidDataException("Only stable public releases are supported.");
        string wanted = tool.InstallerOnly || installerManaged ? "setup.exe" : "portable.zip";
        JsonElement[] assets = json.GetProperty("assets").EnumerateArray().ToArray();
        JsonElement? Find(string arch)
        {
            var matches = assets.Where(a =>
            {
                string name = a.GetProperty("name").GetString() ?? "";
                return name.StartsWith(tool.Name + "-", StringComparison.OrdinalIgnoreCase) &&
                       name.Contains("Windows", StringComparison.OrdinalIgnoreCase) &&
                       name.Contains(arch, StringComparison.OrdinalIgnoreCase) &&
                       name.EndsWith(wanted, StringComparison.OrdinalIgnoreCase);
            }).ToArray();
            if (matches.Length > 1)
                throw new InvalidDataException($"{tool.Name} published more than one matching {arch} Windows package. Nothing was selected; please check the publisher's release.");
            return matches.Length == 0 ? null : matches[0];
        }
        // LAVA 0.15.0's native ARM setup left the executable and DLLs missing
        // in the Windows 11 ARM test VM. Use its official x64 compatibility
        // installer for this release; future releases prefer native ARM.
        string actualArchitecture = architecture == "arm64" && tool.Id == "lava" && tag.TrimStart('v') == "0.15.0" ? "x64" : architecture;
        var match = Find(actualArchitecture);
        if (match == null && architecture == "arm64" && tool.Id == "gleapp")
        {
            match = Find("x64");
            actualArchitecture = "x64";
        }
        var selected = match ?? throw new IOException($"No {actualArchitecture} Windows package is published for {tool.Name}.");
        string name = selected.GetProperty("name").GetString()!;
        Uri url = new(selected.GetProperty("browser_download_url").GetString()!);
        ValidateAssetUrl(tool, tag, name, url);
        string digest = selected.TryGetProperty("digest", out var digestValue) ? digestValue.GetString() ?? "" : "";
        if (!Regex.IsMatch(digest, "^sha256:[0-9a-fA-F]{64}$"))
            throw new InvalidDataException("The official release asset has no SHA-256 digest. Installation is paused until the publisher provides one.");
        long size = selected.GetProperty("size").GetInt64();
        if (size <= 0 || size > 2L * 1024 * 1024 * 1024) throw new InvalidDataException("Unexpected release package size.");
        return new(tag.TrimStart('v'), new(name, url, digest[7..].ToLowerInvariant(), size, wanted == "setup.exe", actualArchitecture),
                   $"https://github.com/{tool.Repository}/releases/tag/{Uri.EscapeDataString(tag)}");
    }

    private static void ValidateAssetUrl(Tool tool, string tag, string name, Uri url)
    {
        if (Path.GetFileName(name) != name || name.Contains('\\') || name.Contains('/') ||
            url.Scheme != "https" || url.Host != "github.com" || !url.IsDefaultPort ||
            !string.IsNullOrEmpty(url.UserInfo) || !string.IsNullOrEmpty(url.Query) ||
            Uri.UnescapeDataString(url.AbsolutePath) != $"/{tool.Repository}/releases/download/{tag}/{name}")
            throw new InvalidDataException("The package does not point to the official release repository.");
    }

    public async Task DownloadAsync(Asset asset, string destination, Action<double> progress, CancellationToken cancellation)
    {
        Uri url = asset.Url;
        HttpResponseMessage? response = null;
        try
        {
            for (int hop = 0; hop < 6; hop++)
            {
                response = await client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cancellation).ConfigureAwait(false);
                if ((int)response.StatusCode is >= 300 and <= 399)
                {
                    var location = response.Headers.Location ?? throw new IOException("The download redirect is missing.");
                    var next = location.IsAbsoluteUri ? location : new Uri(url, location);
                    if (next.Scheme != "https" || !next.IsDefaultPort || !string.IsNullOrEmpty(next.UserInfo) ||
                        next.Host is not ("github.com" or "release-assets.githubusercontent.com" or "objects.githubusercontent.com"))
                        throw new IOException("The download redirected outside GitHub's official release hosts.");
                    response.Dispose(); response = null; url = next; continue;
                }
                response.EnsureSuccessStatusCode();
                break;
            }
            if (response == null || !response.IsSuccessStatusCode) throw new IOException("Too many download redirects.");
            if (response.Content.Headers.ContentLength is long expected && expected != asset.Size)
                throw new InvalidDataException("The package size differs from the publisher's metadata.");
            await using var input = await response.Content.ReadAsStreamAsync(cancellation).ConfigureAwait(false);
            await using var output = new FileStream(destination, FileMode.CreateNew, FileAccess.Write, FileShare.None, 131072, true);
            byte[] buffer = new byte[131072];
            long total = 0;
            using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
            var progressClock = Stopwatch.StartNew();
            int count;
            while (true)
            {
                using var idle = CancellationTokenSource.CreateLinkedTokenSource(cancellation);
                idle.CancelAfter(ReadIdleTimeout);
                try { count = await input.ReadAsync(buffer.AsMemory(), idle.Token).ConfigureAwait(false); }
                catch (OperationCanceledException) when (!cancellation.IsCancellationRequested)
                { throw new IOException("No download data arrived for 60 seconds. Please try again."); }
                if (count == 0) break;
                total += count;
                if (total > asset.Size) throw new InvalidDataException("The downloaded package is larger than expected.");
                hash.AppendData(buffer, 0, count);
                await output.WriteAsync(buffer.AsMemory(0, count), cancellation).ConfigureAwait(false);
                if (progressClock.ElapsedMilliseconds >= 100 || total == asset.Size)
                {
                    progress((double)total / asset.Size);
                    progressClock.Restart();
                }
            }
            if (total != asset.Size || !Convert.ToHexString(hash.GetHashAndReset()).Equals(asset.Sha256, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException("The package checksum did not match. Nothing will be installed.");
        }
        finally { response?.Dispose(); }
    }
    public void Dispose() => client.Dispose();
}
