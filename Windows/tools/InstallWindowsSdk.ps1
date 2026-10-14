param([ValidateSet('arm64','x64')][string]$Architecture = 'arm64')
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE = 'false'
$leappBuildRoot = Join-Path $env:LOCALAPPDATA 'uLEAPP-Build'
$leappSdkRoot = Join-Path $leappBuildRoot ('dotnet-' + $Architecture)
$leappDotnet = Join-Path $leappSdkRoot 'dotnet.exe'
if (Test-Path $leappDotnet) {
    & $leappDotnet --version
    if ($LASTEXITCODE -eq 0) { Write-Output ('DOTNET=' + $leappDotnet); exit 0 }
}
if ((Get-PSDrive -Name C).Free -lt 2GB) { throw 'At least 2 GB of free space is needed for the local build tools.' }
$leappMetadata = Invoke-RestMethod -Uri 'https://builds.dotnet.microsoft.com/dotnet/release-metadata/10.0/releases.json'
$leappEntries = @($leappMetadata.releases | ForEach-Object {
    if ($_.sdks) { $_.sdks } elseif ($_.sdk) { $_.sdk }
})
$leappSdk = $leappEntries | Where-Object { $_.version -eq $leappMetadata.'latest-sdk' } | Select-Object -First 1
$leappArchive = $leappSdk.files | Where-Object { $_.rid -eq ('win-' + $Architecture) -and $_.name.EndsWith('.zip') } | Select-Object -First 1
if (-not $leappArchive) { throw 'The official SDK metadata has no matching Windows archive.' }
$leappUri = [Uri]$leappArchive.url
if ($leappUri.Scheme -ne 'https' -or -not $leappUri.Host.EndsWith('.microsoft.com')) {
    throw 'The SDK archive must come from Microsoft over HTTPS.'
}
if ($leappArchive.hash -notmatch '^[0-9a-fA-F]{128}$') { throw 'The SDK archive has no SHA-512 checksum.' }
New-Item -ItemType Directory -Force -Path $leappBuildRoot | Out-Null
$leappZip = Join-Path $leappBuildRoot ('sdk-' + $Architecture + '.zip')
Write-Output ('Downloading official .NET SDK ' + $leappSdk.version + ' for ' + $Architecture)
Invoke-WebRequest -UseBasicParsing -Uri $leappUri.AbsoluteUri -OutFile $leappZip
$leappHash = (Get-FileHash -Algorithm SHA512 -Path $leappZip).Hash
if ($leappHash -ne $leappArchive.hash) { throw 'SDK checksum mismatch; the archive will not be used.' }
Write-Output 'SDK checksum verified. Expanding task-local build tools.'
New-Item -ItemType Directory -Force -Path $leappSdkRoot | Out-Null
Expand-Archive -Path $leappZip -DestinationPath $leappSdkRoot -Force
Remove-Item -LiteralPath $leappZip
& $leappDotnet --version
if ($LASTEXITCODE -ne 0) { throw 'The SDK did not start correctly.' }
Write-Output ('DOTNET=' + $leappDotnet)
