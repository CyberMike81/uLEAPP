// SPDX-License-Identifier: MIT
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
namespace uLEAPP;
public static class GitHubMetadata
{
    private sealed record Cache(string Url,string? ETag,string Body);
    public static async Task<string> FetchAsync(HttpClient client,string url,CancellationToken cancellation,string? cacheRoot = null)
    {
        string root = cacheRoot ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"uLEAPP","metadata-cache");
        string file = Path.Combine(root,Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(url))) + ".json");
        Cache? cache = null;
        try { cache = JsonSerializer.Deserialize<Cache>(File.ReadAllText(file)); } catch { }
        if (cache?.Url != url || cache?.Body == null || cache.Body.Length > 8 * 1024 * 1024) cache = null;
        using var request = new HttpRequestMessage(HttpMethod.Get,url);
        if (EntityTagHeaderValue.TryParse(cache?.ETag,out var tag)) request.Headers.IfNoneMatch.Add(tag);
        using var response = await client.SendAsync(request,cancellation).ConfigureAwait(false);
        if (response.StatusCode is HttpStatusCode.Forbidden or HttpStatusCode.TooManyRequests) {
            string Header(string name) => response.Headers.TryGetValues(name,out var values) ? string.Join(",",values) : "unknown";
            throw new IOException($"GitHub HTTP {(int)response.StatusCode}. Requests remaining: {Header("X-RateLimit-Remaining")}; reset (Unix time): {Header("X-RateLimit-Reset")}. Wait before checking again.");
        }
        if (response.StatusCode == HttpStatusCode.NotModified && cache != null) return cache.Body;
        response.EnsureSuccessStatusCode();
        string body = await response.Content.ReadAsStringAsync(cancellation).ConfigureAwait(false);
        if (body.Length > 8 * 1024 * 1024) throw new IOException("Release metadata is too large.");
        using var json = JsonDocument.Parse(body);
        if (json.RootElement.ValueKind != JsonValueKind.Object) throw new IOException("Invalid release metadata.");
        string temporary = file + "." + Guid.NewGuid().ToString("N");
        try { Directory.CreateDirectory(root); File.WriteAllText(temporary,JsonSerializer.Serialize(new Cache(url,response.Headers.ETag?.ToString(),body))); File.Move(temporary,file,true); }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException) { }
        finally { try { File.Delete(temporary); } catch { } }
        return body;
    }
}
