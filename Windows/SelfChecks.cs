// SPDX-License-Identifier: MIT
using System.IO.Compression;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace uLEAPP;

public static class SelfChecks
{
    private static int checks;
    private static void Check(bool condition, string description)
    {
        if (!condition) throw new Exception("Self-check failed: " + description);
        checks++; Console.WriteLine("ok - " + description);
    }
    private static void Reject(Action action, string description)
    {
        try { action(); } catch (InvalidDataException) { Check(true, description); return; }
        throw new Exception("Self-check failed: " + description);
    }
    public static async Task RunAsync(string? fixtures = null)
    {
        Console.WriteLine("uLEAPP " + Catalog.Version + " self-check");
        Check(Catalog.All.Length == 7 && Catalog.All.Select(t => t.Id).Distinct().Count() == 7, "seven supported tools; no extra applications");
        foreach (var tool in Catalog.All)
        {
            var icon = ToolIcons.Load(tool.Id);
            Check(icon.IsFrozen && icon.PixelWidth == 256 && icon.PixelHeight == 256,tool.Name + " actual catalog icon is embedded and decodes without an installed app");
        }
        var confirmation = new WindowsTrash.RecycleConfirmation();
        confirmation.PostDeleteItem(0,IntPtr.Zero,0,IntPtr.Zero);
        Check(!confirmation.Recycled,"a missing Recycle Bin destination is never confirmed as recycled");
        confirmation.PostDeleteItem(0,IntPtr.Zero,unchecked((int)0x80004005),new IntPtr(1));
        Check(!confirmation.Recycled,"a failed delete callback is never confirmed as recycled");
        confirmation.PostDeleteItem(0,IntPtr.Zero,0,new IntPtr(1));
        Check(confirmation.Recycled,"the shell must report a successful Recycle Bin destination");
        Check(!WindowsTrash.IsSupportedDrive(DriveType.Removable) && !WindowsTrash.IsSupportedDrive(DriveType.Network),"cleanup refuses removable and network drives");
        string cacheTest = Path.Combine(Path.GetTempPath(),"uleapp-metadata-" + Guid.NewGuid().ToString("N"));
        try {
            using var handler = new MetadataHandler();
            using var http = new HttpClient(handler);
            string first = await GitHubMetadata.FetchAsync(http,"https://api.github.com/test",CancellationToken.None,cacheTest);
            string second = await GitHubMetadata.FetchAsync(http,"https://api.github.com/test",CancellationToken.None,cacheTest);
            Check(first == second && handler.Conditional == "\"one\"","ETag conditional response reuses only server-confirmed cached metadata");
            try { await GitHubMetadata.FetchAsync(http,"https://api.github.com/test",CancellationToken.None,cacheTest); throw new Exception("Rate limit ignored"); }
            catch (IOException error) { Check(error.Message.Contains("remaining: 0") && error.Message.Contains("12345"),"rate-limit errors include remaining quota and reset details instead of stale success"); }
        } finally { if (Directory.Exists(cacheTest)) Directory.Delete(cacheTest,true); }
        var actionRow = new ToolRow(Catalog.All[0]);
        Check(actionRow.ActionLabel == "Install" && actionRow.ActionVisibility == System.Windows.Visibility.Visible,"missing apps keep their Install button");
        bool visibilityChanged = false;
        actionRow.PropertyChanged += (_, args) => { if (args.PropertyName == nameof(ToolRow.ActionVisibility)) visibilityChanged = true; };
        actionRow.Version = "0.15.0"; actionRow.Status = "Up to date";
        Check(visibilityChanged && actionRow.ActionVisibility == System.Windows.Visibility.Collapsed,"an up-to-date app hides Update and notifies the interface");
        actionRow.Status = "Update available";
        Check(actionRow.ActionVisibility == System.Windows.Visibility.Visible,"an available update restores the Update button");
        Check(!Installer.NeedsUpdate("2026.4.4", "2026.4.3"), "newer installed releases are never downgraded");
        Check(!Installer.NeedsUpdate("v2026.4.4", "2026.4.4"), "matching versions are left alone");
        Check(Installer.NeedsUpdate("2026.4.3", "2026.4.4"), "an older version can be updated");
        foreach (string name in new[] { "LICENSE", "THIRD-PARTY-NOTICES.md", "licenses/Swift.txt", "licenses/LAVA-EULA.txt", "runtime-notices" })
            Check(File.Exists(Path.Combine(AppContext.BaseDirectory,name)) || Directory.Exists(Path.Combine(AppContext.BaseDirectory,name)), "packaged notice: " + name);
        Check(Directory.GetFiles(Path.Combine(AppContext.BaseDirectory,"runtime-notices"), "*", SearchOption.AllDirectories).Length >= 4, "exact runtime licenses and third-party notices are present");
        if (fixtures != null)
        {
            foreach (var tool in Catalog.All)
            {
                using var releaseFixture = JsonDocument.Parse(File.ReadAllText(Path.Combine(fixtures,tool.Id + ".json")));
                foreach (string architecture in new[] { "arm64", "x64" })
                {
                    var selected = ReleaseClient.Select(tool,releaseFixture.RootElement,architecture);
                    Check(selected.Asset.Architecture == architecture || architecture == "arm64" && selected.Asset.Architecture == "x64" &&
                          (tool.Id == "gleapp" || tool.Id == "lava" && selected.Version == "0.15.0"), tool.Name + " official asset for " + architecture);
                    Check(ReleaseClient.Select(tool,releaseFixture.RootElement,architecture,true).Asset.IsInstaller,tool.Name + " official setup for existing installer-managed copies");
                    if (tool.Id is "aleapp" or "ileapp")
                    {
                        using var currentFixture = JsonDocument.Parse(File.ReadAllText(Path.Combine(fixtures,tool.Id + "-portable-only.json")));
                        var currentRelease = ReleaseClient.Select(tool,currentFixture.RootElement,architecture,true);
                        Check(!currentRelease.Asset.IsInstaller && currentRelease.Asset.Architecture == architecture,
                            tool.Name + " October 24 portable-only release updates registered copies on " + architecture);
                    }
                }
            }
        }

        foreach (string arch in new[] { "x64", "arm64" })
        {
            string package = $"uLEAPP-0.3.2-Windows-{(arch == "arm64" ? "ARM64" : "x64")}.zip";
            string url = "https://github.com/CyberMike81/uLEAPP/releases/download/v0.3.2/" + package;
            string json = JsonSerializer.Serialize(new { tag_name="v0.3.2", draft=false, prerelease=false,
                html_url="https://github.com/CyberMike81/uLEAPP/releases/tag/v0.3.2",
                assets=new[] { new { name=package, browser_download_url=url } } });
            using var selfMetadata = JsonDocument.Parse(json);
            Check(SelfUpdate.Select(selfMetadata.RootElement,"0.3.1",arch)?.Download.AbsoluteUri == url,"self-update chooses the official " + arch + " package");
            Check(SelfUpdate.Select(selfMetadata.RootElement,"0.3.2",arch) == null,"self-update hides the installed version");
            Check(SelfUpdate.Select(selfMetadata.RootElement,"0.4.0",arch) == null,"self-update never offers a downgrade");
            using var unsafeMetadata = JsonDocument.Parse(json.Replace(url,"https://example.org/update.zip"));
            Check(SelfUpdate.Select(unsafeMetadata.RootElement,"0.3.1",arch) == null,"self-update rejects an unofficial package URL");
            using var previewMetadata = JsonDocument.Parse(json.Replace("\"prerelease\":false","\"prerelease\":true"));
            Check(SelfUpdate.Select(previewMetadata.RootElement,"0.3.1",arch) == null,"self-update skips preview-flagged releases");
        }
        var ileapp = Catalog.All.Single(t => t.Id == "ileapp");
        var gleapp = Catalog.All.Single(t => t.Id == "gleapp");
        var lava = Catalog.All.Single(t => t.Id == "lava");
        using var metadata = JsonDocument.Parse(Metadata(ileapp, "arm64"));
        Check(ReleaseClient.Select(ileapp, metadata.RootElement, "arm64").Asset.Architecture == "arm64", "native Windows ARM package selection");
        foreach (string id in new[] { "aleapp", "ileapp" })
        foreach (string arch in new[] { "x64", "arm64" })
        {
            var tool = Catalog.All.Single(t => t.Id == id);
            using var portableOnly = JsonDocument.Parse(Metadata(tool, arch));
            var fallback = ReleaseClient.Select(tool, portableOnly.RootElement, arch, true);
            Check(!fallback.Asset.IsInstaller && fallback.Asset.Architecture == arch,
                tool.Name + " installer-managed copy falls back to official " + arch + " portable ZIP");
            using var setup = JsonDocument.Parse(Metadata(tool, arch, true));
            using var both = JsonDocument.Parse(JsonSerializer.Serialize(new { tag_name="v1.2.3", assets=new[] {
                setup.RootElement.GetProperty("assets")[0], portableOnly.RootElement.GetProperty("assets")[0] } }));
            Check(ReleaseClient.Select(tool, both.RootElement, arch, true).Asset.IsInstaller,
                tool.Name + " still prefers setup when the publisher offers it");
        }
        using var x64metadata = JsonDocument.Parse(Metadata(gleapp,"x64"));
        Check(ReleaseClient.Select(gleapp,x64metadata.RootElement,"arm64").Asset.Architecture == "x64", "GLEAPP explicitly uses its published x64 fallback");
        using var lavaMetadata = JsonDocument.Parse(Metadata(lava,"arm64",true));
        Check(ReleaseClient.Select(lava,lavaMetadata.RootElement,"arm64").Asset.IsInstaller,"LAVA uses its official interactive installer");
        Check(ReleaseClient.Select(lava,lavaMetadata.RootElement,"arm64").Asset.Architecture == "arm64","newer LAVA releases prefer their native ARM package");
        using var lavaArmCompatibility = JsonDocument.Parse(Metadata(lava,"arm64",true).Replace("1.2.3","0.15.0"));
        using var lavaX64Compatibility = JsonDocument.Parse(Metadata(lava,"x64",true).Replace("1.2.3","0.15.0"));
        using var lavaCompatibility = JsonDocument.Parse(JsonSerializer.Serialize(new {
            tag_name="v0.15.0", assets=new[] {
                lavaArmCompatibility.RootElement.GetProperty("assets")[0],
                lavaX64Compatibility.RootElement.GetProperty("assets")[0]
            }
        }));
        var compatibleLava = ReleaseClient.Select(lava,lavaCompatibility.RootElement,"arm64");
        Check(compatibleLava.Asset.Architecture == "x64" && compatibleLava.Asset.IsInstaller,"LAVA 0.15.0 on ARM uses the working official x64 installer");
        Check(ReleaseClient.Select(lava,lavaCompatibility.RootElement,"x64").Asset.Architecture == "x64","LAVA x64 selection remains native on Intel and AMD Windows");
        try { ReleaseClient.Select(lava,lavaArmCompatibility.RootElement,"arm64"); throw new Exception("The incomplete ARM-only LAVA 0.15.0 package was selected"); }
        catch (IOException) { Check(true,"LAVA 0.15.0 refuses an incomplete ARM-only release if no x64 compatibility installer exists"); }
        using var missingHash = JsonDocument.Parse(Metadata(ileapp,"arm64").Replace("sha256:" + new string('a',64),""));
        Reject(() => ReleaseClient.Select(ileapp,missingHash.RootElement,"arm64"),"a release without a checksum is refused");
        using var wrongHost = JsonDocument.Parse(Metadata(ileapp,"arm64").Replace("github.com", "example.org"));
        Reject(() => ReleaseClient.Select(ileapp,wrongHost.RootElement,"arm64"),"packages outside the official repository are refused");
        using var duplicated = JsonDocument.Parse(JsonSerializer.Serialize(new { tag_name="v1.2.3", assets=new[] { metadata.RootElement.GetProperty("assets")[0], metadata.RootElement.GetProperty("assets")[0] } }));
        Reject(() => ReleaseClient.Select(ileapp,duplicated.RootElement,"arm64"),"duplicate matching release assets are refused with a publisher-specific message");
        using var duplicatedFallback = JsonDocument.Parse(JsonSerializer.Serialize(new { tag_name="v1.2.3", assets=new[] { x64metadata.RootElement.GetProperty("assets")[0], x64metadata.RootElement.GetProperty("assets")[0] } }));
        Reject(() => ReleaseClient.Select(gleapp,duplicatedFallback.RootElement,"arm64"),"ambiguous GLEAPP x64 fallback packages are refused");

        string scratch = Path.Combine(Path.GetTempPath(),"uLEAPP-selfcheck-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(scratch);
        string caseFile = Path.Combine(scratch,"case-evidence.txt"); File.WriteAllText(caseFile,"unchanged");
        try
        {
            CheckSettingsRecovery(scratch);
            foreach (string unsafeName in new[] { "../outside.exe", @"..\outside.exe", "/absolute.exe", "C:/absolute.exe", "CON.txt", "folder/trailing. ", "folder/file:stream" })
            {
                string zip = Path.Combine(scratch, Guid.NewGuid().ToString("N") + ".zip");
                MakeZip(zip, [unsafeName]);
                string destination = Path.Combine(scratch,Guid.NewGuid().ToString("N"));
                Reject(() => PortablePackage.Extract(zip,destination), "unsafe archive path is refused: " + unsafeName);
                Check(!Directory.Exists(destination),"unsafe archive is rejected before extraction");
            }
            string duplicates = Path.Combine(scratch,"duplicate.zip"); MakeZip(duplicates,["Tool.exe","tool.EXE"]);
            Reject(() => PortablePackage.Extract(duplicates,Path.Combine(scratch,"duplicates")),"case-insensitive duplicate files are refused");
            string valid = Path.Combine(scratch,"valid.zip"); MakeZip(valid,[@"vleapp.exe",@"_internal\support.dll","LICENSE.txt","THIRD-PARTY-NOTICES.txt"]);
            string app = Path.Combine(scratch,"app"); PortablePackage.Extract(valid,app);
            Check(File.Exists(Path.Combine(app,"_internal","support.dll")),"Windows archive separators and support files are preserved");
            Check(File.Exists(Path.Combine(app,"LICENSE.txt")) && File.Exists(Path.Combine(app,"THIRD-PARTY-NOTICES.txt")),"upstream license and notice files are preserved");
            Check(PortablePackage.FindExecutable(app,Catalog.All.Single(t => t.Id == "vleapp")) != null,"official portable executable is found");
            Check(File.ReadAllText(caseFile) == "unchanged","extraction stays inside its new app folder");
            byte[] data = Encoding.UTF8.GetBytes("verified package");
            var asset = new Asset("test.zip", new Uri("https://github.com/abrignoni/iLEAPP/releases/download/v1.0/test.zip"),Convert.ToHexString(SHA256.HashData(data)),data.Length,false,"arm64");
            using var client = new ReleaseClient(new FakeHandler(data));
            await client.DownloadAsync(asset,Path.Combine(scratch,"download.zip"), _ => { },CancellationToken.None);
            Check(File.ReadAllBytes(Path.Combine(scratch,"download.zip")).SequenceEqual(data),"downloaded bytes are checked against size and SHA-256");
            byte[] largeData = new byte[2 * 1024 * 1024];
            var largeAsset = asset with { Size = largeData.Length, Sha256 = Convert.ToHexString(SHA256.HashData(largeData)) };
            using (var largeClient = new ReleaseClient(new FakeHandler(largeData)))
            {
                int reports = 0;
                var clock = System.Diagnostics.Stopwatch.StartNew();
                await largeClient.DownloadAsync(largeAsset, Path.Combine(scratch,"large.zip"), _ => reports++, CancellationToken.None);
                Check(reports >= 1 && reports <= clock.ElapsedMilliseconds / 100 + 1, "large downloads throttle progress to ten reports per second plus completion");
            }
            using (var stalled = new ReleaseClient(new StalledHandler()) { ReadIdleTimeout = TimeSpan.FromMilliseconds(30) })
            {
                try {
                    await stalled.DownloadAsync(asset, Path.Combine(scratch,"stalled.zip"), _ => { }, CancellationToken.None);
                    throw new Exception("A stalled body was accepted");
                } catch (IOException) { Check(true,"a stalled response body times out after headers"); }
            }
            using (var stalled = new ReleaseClient(new StalledHandler()))
            using (var stop = new CancellationTokenSource(TimeSpan.FromMilliseconds(30)))
            {
                try {
                    await stalled.DownloadAsync(asset, Path.Combine(scratch,"stopped.zip"), _ => { }, stop.Token);
                    throw new Exception("A stopped body was accepted");
                } catch (OperationCanceledException) { Check(true,"Stop cancels a response body already being read"); }
            }

            try
            {
                await client.DownloadAsync(asset with { Sha256 = new string('0',64) },Path.Combine(scratch,"bad.zip"), _ => { },CancellationToken.None);
                throw new Exception("A checksum mismatch was accepted");
            }
            catch (InvalidDataException) { Check(true,"a checksum mismatch blocks installation"); }
            using var redirect = new ReleaseClient(new FakeHandler(data,true));
            try
            {
                await redirect.DownloadAsync(asset,Path.Combine(scratch,"redirect.zip"),_ => { },CancellationToken.None);
                throw new Exception("An unsafe download redirect was accepted");
            }
            catch (IOException) { Check(true,"download redirects outside GitHub are refused"); }

            string integrationRoot = Path.Combine(scratch,"integration");
            try
            {
                var store = new InstallationStore(Path.Combine(integrationRoot,"state"));
                store.ChangeRoot(Path.Combine(integrationRoot,"apps"));
                var tool = Catalog.All.Single(t => t.Id == "vleapp");
                string old = Path.Combine(store.Root,tool.Name,"older"); Directory.CreateDirectory(old);
                string evidence = Path.Combine(old,"case.txt"); File.WriteAllText(evidence,"keep this case");
                byte[] package = File.ReadAllBytes(valid);
                using var installClient = new ReleaseClient(new FakeHandler(package));
                var installer = new Installer(installClient,store);
                var release = new Release("1.2.3",new("VLEAPP-1.2.3-windows-arm64-portable.zip",new Uri("https://github.com/abrignoni/VLEAPP/releases/download/v1.2.3/test.zip"),Convert.ToHexString(SHA256.HashData(package)),package.Length,false,"arm64"),"https://github.com/abrignoni/VLEAPP/releases/tag/v1.2.3");
                var installed = await installer.InstallAsync(tool,release,null,_ => { },_ => { },CancellationToken.None);
                Check(File.Exists(installed.Path) && store.Find(tool)?.Version == "1.2.3","verified portable installation is recorded and discoverable");
                Check(File.ReadAllText(evidence) == "keep this case","installation preserves previous versions and case files");
                Check(File.Exists(Path.Combine(Path.GetDirectoryName(installed.Path)!,"LICENSE.txt")),"installed app retains upstream license files");
                bool failed = false;
                try { await installer.InstallAsync(tool,release with { Version="1.2.4", Asset=release.Asset with { Sha256=new string('0',64) } },installed,_ => { },_ => { },CancellationToken.None); }
                catch (InvalidDataException) { failed=true; }
                Check(failed && store.Find(tool)?.Version == "1.2.3" && File.Exists(installed.Path),"failed replacement keeps the working app and state");
                var second = await installer.InstallAsync(tool,release with { Version="1.2.4" },installed,_ => { },_ => { },CancellationToken.None);
                var third = await installer.InstallAsync(tool,release with { Version="1.2.5" },second,_ => { },_ => { },CancellationToken.None);
                var cleanup = OldInstalls.Scan(store,CancellationToken.None);
                Check(cleanup.Count == 1 && cleanup[0].Label == "VLEAPP 1.2.3","cleanup keeps the current and previous version and reviews only older installs");
                Check(File.Exists(installed.Path),"cleanup review does not remove anything");
                string extraCase = Path.Combine(cleanup[0].Folder,"case-notes.txt"); File.WriteAllText(extraCase,"keep this case");
                Check(OldInstalls.Scan(store,CancellationToken.None).Count == 0,"cleanup preserves an older app folder with added case data");
                Check(!OldInstalls.Recycle(store,cleanup[0],CancellationToken.None) && File.Exists(extraCase),"cleanup rechecks changed contents after review");
                File.Delete(extraCase);
                byte[] original = File.ReadAllBytes(installed.Path); File.WriteAllText(installed.Path,"modified app");
                Check(OldInstalls.Scan(store,CancellationToken.None).Count == 0,"cleanup preserves modified binaries");
                File.WriteAllBytes(installed.Path,original);
                store.Record(installed);
                Check(!OldInstalls.Recycle(store,cleanup[0],CancellationToken.None),"cleanup rechecks the current selection before recycling");
                store.Record(third);
                var cancelledCleanup = new CancellationTokenSource(); cancelledCleanup.Cancel();
                try { OldInstalls.Recycle(store,cleanup[0],cancelledCleanup.Token); throw new Exception("Cancelled cleanup ran"); }
                catch (OperationCanceledException) { Check(File.Exists(installed.Path),"cancelled cleanup leaves app folders in place"); }
                Check(!OldInstalls.Recycle(store,cleanup[0] with { Folder=old },CancellationToken.None) && File.Exists(evidence),"untracked folders and forged cleanup paths are preserved");
                Check(OldInstalls.Recycle(store,cleanup[0],CancellationToken.None) && !File.Exists(installed.Path),"eligible old app moves to the Windows Recycle Bin");
                Check(File.Exists(second.Path) && File.Exists(third.Path) && store.Find(tool)?.Version == "1.2.5" && File.Exists(evidence),"recycling keeps the current and previous app plus untracked case data");
            }
            finally { if (Directory.Exists(integrationRoot)) Directory.Delete(integrationRoot,true); }
        }
        finally { Directory.Delete(scratch,true); }
        Console.WriteLine($"uLEAPP self-check passed: {checks} checks. No installed apps were changed.");
    }
    private sealed class MetadataHandler : HttpMessageHandler
    {
        private int calls;
        public string? Conditional;
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken cancellation)
        {
            calls++; Conditional = request.Headers.IfNoneMatch.FirstOrDefault()?.ToString();
            var response = new HttpResponseMessage(calls == 1 ? HttpStatusCode.OK : calls == 2 ? HttpStatusCode.NotModified : HttpStatusCode.Forbidden);
            if (calls == 1) { response.Content = new StringContent("{\"tag_name\":\"v1.2.3\"}"); response.Headers.ETag = new System.Net.Http.Headers.EntityTagHeaderValue("\"one\""); }
            if (calls == 3) { response.Headers.Add("X-RateLimit-Remaining","0"); response.Headers.Add("X-RateLimit-Reset","12345"); }
            return Task.FromResult(response);
        }
    }
    private static void CheckSettingsRecovery(string scratch)
    {
        string validRoot = Path.Combine(Path.GetPathRoot(scratch)!, "uLEAPP-test-location-" + Guid.NewGuid().ToString("N"));
        string defaultRoot = new InstallationStore(Path.Combine(scratch,"new-state")).Root;
        foreach (var sample in new[] {
            (Name:"truncated", Text:"{ not json"),
            (Name:"relative-root", Text:JsonSerializer.Serialize(new { Root="relative", Installed=Array.Empty<object>() })),
            (Name:"network-root", Text:JsonSerializer.Serialize(new { Root=@"\\server\share\LEAPPs", Installed=Array.Empty<object>() })),
            (Name:"protected-root", Text:JsonSerializer.Serialize(new { Root=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"LEAPPs"), Installed=Array.Empty<object>() })),
            (Name:"null-state", Text:"null"),
            (Name:"missing-root", Text:"{\"Installed\":[]}"),
            (Name:"null-record", Text:JsonSerializer.Serialize(new { Root=validRoot, Installed=new object?[] { null } })),
            (Name:"invalid-record", Text:JsonSerializer.Serialize(new { Root=validRoot, Installed=new[] { new { Id="ileapp", Version="1.2.3", Path="relative.exe", Architecture="arm64" } } }))
        })
        {
            string data = Path.Combine(scratch,sample.Name); Directory.CreateDirectory(data);
            string settings = Path.Combine(data,"settings.json"); File.WriteAllText(settings,sample.Text);
            var recovered = new InstallationStore(data);
            Check(recovered.Root == defaultRoot && recovered.RecoveryMessage != null,"invalid " + sample.Name + " settings recover with a visible notice");
            Check(recovered.RecoveryBackupPath != null && File.ReadAllText(recovered.RecoveryBackupPath) == sample.Text && !File.Exists(settings),"original " + sample.Name + " settings are preserved without overwriting a backup");
            recovered.ChangeRoot(validRoot);
            Check(new InstallationStore(data).Root == validRoot && File.ReadAllText(recovered.RecoveryBackupPath!) == sample.Text,"settings can be saved after " + sample.Name + " recovery");
        }
        foreach (string array in new[] { "", ",\"Installed\":null" })
        {
            string data = Path.Combine(scratch,Guid.NewGuid().ToString("N")); Directory.CreateDirectory(data);
            File.WriteAllText(Path.Combine(data,"settings.json"),"{\"Root\":" + JsonSerializer.Serialize(validRoot) + array + "}");
            var store = new InstallationStore(data);
            Check(store.Root == validRoot && store.RecoveryMessage == null,"missing or null Installed arrays are accepted as an empty list");
        }
        string lockedData = Path.Combine(scratch,"locked-state"); Directory.CreateDirectory(lockedData);
        string lockedSettings = Path.Combine(lockedData,"settings.json"); File.WriteAllText(lockedSettings,"{ locked invalid settings");
        using (var locked = new FileStream(lockedSettings,FileMode.Open,FileAccess.Read,FileShare.None))
        {
            var store = new InstallationStore(lockedData);
            Check(store.RecoveryMessage != null && store.RecoveryBackupPath == null,"unreadable locked settings open with temporary defaults");
            try { store.ChangeRoot(validRoot); throw new Exception("Locked settings were overwritten"); }
            catch (IOException) { Check(store.Root == defaultRoot,"blocked settings saves preserve the original root"); }
            try { store.EnsureSettingsWritable(); throw new Exception("Installation was allowed without writable state"); }
            catch (IOException) { Check(true,"installation is refused when original settings cannot be backed up"); }
        }
        Check(File.ReadAllText(lockedSettings) == "{ locked invalid settings","inaccessible settings are left byte-for-byte unchanged");
    }
    private static string Metadata(Tool tool, string architecture, bool installer = false)
    {
        string name = $"{tool.Name}-1.2.3-windows-{architecture}-" + (installer ? "setup.exe" : "portable.zip");
        return JsonSerializer.Serialize(new { tag_name="v1.2.3", draft=false, prerelease=false, assets=new[] { new { name, browser_download_url=$"https://github.com/{tool.Repository}/releases/download/v1.2.3/{name}", digest="sha256:" + new string('a',64), size=1024 } } });
    }
    private static void MakeZip(string path, string[] names)
    {
        using var zip=ZipFile.Open(path,ZipArchiveMode.Create);
        foreach (string name in names) { using var writer=new StreamWriter(zip.CreateEntry(name).Open()); writer.Write("test content"); }
    }
    private sealed class StalledHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new StreamContent(new StalledStream()) });
    }
    private sealed class StalledStream : Stream
    {
        public override bool CanRead => true;
        public override bool CanSeek => false;
        public override bool CanWrite => false;
        public override long Length => throw new NotSupportedException();
        public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override async ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellationToken = default)
        {
            await Task.Delay(Timeout.Infinite, cancellationToken).ConfigureAwait(false);
            return 0;
        }
        public override int Read(byte[] buffer, int offset, int count) => throw new NotSupportedException();
        public override void Flush() => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
    }
    private sealed class FakeHandler(byte[] data, bool redirect = false) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var response = new HttpResponseMessage(redirect ? HttpStatusCode.Redirect : HttpStatusCode.OK) { Content = new ByteArrayContent(data) };
            if (redirect) response.Headers.Location = new Uri("https://example.org/untrusted.exe");
            return Task.FromResult(response);
        }
    }
}
