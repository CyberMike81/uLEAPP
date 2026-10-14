# SPDX-License-Identifier: MIT
param(
    [string]$DotnetPath = 'dotnet',
    [ValidateSet('win-arm64','win-x64')][string[]]$RuntimeIdentifiers = @('win-arm64','win-x64')
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE = 'false'
$leappRepository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$leappSource = Join-Path $leappRepository 'Windows'
$leappCache = Join-Path $env:LOCALAPPDATA 'uLEAPP-Build'
$env:DOTNET_CLI_HOME = $leappCache
$env:NUGET_PACKAGES = Join-Path $leappCache 'packages'
$leappSdkVersion = (& $DotnetPath --version).Trim()
if ($LASTEXITCODE -ne 0) { throw 'The .NET SDK did not start.' }
$leappAppVersion = ([xml](Get-Content (Join-Path $leappSource 'uLEAPP.csproj') -Raw)).Project.PropertyGroup.Version

foreach ($leappRid in $RuntimeIdentifiers) {
    $leappPlatform = if ($leappRid -eq 'win-arm64') { 'Windows-ARM64' } else { 'Windows-x64' }
    $leappOutput = Join-Path $leappRepository $leappPlatform
    & $DotnetPath publish (Join-Path $leappSource 'uLEAPP.csproj') -c Release -r $leappRid --self-contained true -o $leappOutput -p:DebugType=None
    if ($LASTEXITCODE -ne 0) { throw ('Build failed: ' + $leappRid) }
    $leappDeps = Get-Content (Join-Path $leappSource ('bin/Release/net10.0-windows/' + $leappRid + '/uLEAPP.deps.json')) -Raw | ConvertFrom-Json
    $leappPacks = @($leappDeps.libraries.PSObject.Properties.Name | Where-Object { $_.StartsWith('runtimepack.') })
    if ($leappPacks.Count -ne 2) { throw 'Unexpected runtime pack inventory; inspect notices before packaging.' }
    foreach ($leappPack in $leappPacks) {
        $leappParts = $leappPack.Substring(12).Split('/')
        $leappName = $leappParts[0].ToLowerInvariant()
        $leappVersion = $leappParts[1]
        $leappPackage = Join-Path $env:NUGET_PACKAGES ($leappName + '/' + $leappVersion)
        $leappNotices = Join-Path $leappOutput ('runtime-notices/' + $leappName + '-' + $leappVersion)
        New-Item -ItemType Directory -Force $leappNotices | Out-Null
        $leappLicenseFiles = @(Get-ChildItem $leappPackage -File | Where-Object { $_.Name -like 'LICENSE*' -or $_.Name -like '*NOTICE*' })
        if (-not ($leappLicenseFiles | Where-Object { $_.Name -like 'LICENSE*' })) { throw ('Missing package license: ' + $leappPack) }
        $leappLicenseFiles | Copy-Item -Destination $leappNotices -Force
        if ($leappName.StartsWith('microsoft.windowsdesktop.')) {
            $leappWpf = Join-Path $leappRepository ('licenses/dotnet-wpf-thirdparty-' + $leappVersion + '.txt')
            if (-not (Test-Path $leappWpf)) {
                Invoke-WebRequest -UseBasicParsing ('https://raw.githubusercontent.com/dotnet/wpf/v' + $leappVersion + '/THIRD-PARTY-NOTICES.TXT') -OutFile $leappWpf
            }
            if ((Get-Item $leappWpf).Length -lt 100) { throw 'WPF third-party notices are missing or invalid.' }
            Copy-Item $leappWpf (Join-Path $leappNotices 'THIRD-PARTY-NOTICES.TXT') -Force
        }
    }
    Copy-Item (Join-Path $leappRepository 'LICENSE'),(Join-Path $leappRepository 'THIRD-PARTY-NOTICES.md') $leappOutput -Force
    Copy-Item (Join-Path $leappRepository 'licenses') $leappOutput -Recurse -Force
    Copy-Item (Join-Path $leappSource 'README.md') (Join-Path $leappOutput 'README.md') -Force
    $leappArtworkNotices = Join-Path $leappOutput 'artwork-notices'
    New-Item -ItemType Directory -Force $leappArtworkNotices | Out-Null
    Copy-Item (Join-Path $leappRepository 'assets/tool-icons/README.md'),(Join-Path $leappRepository 'assets/tool-icons/PROVENANCE.json') $leappArtworkNotices -Force
    @{ AppVersion=$leappAppVersion; Architecture=$leappRid; Sdk=$leappSdkVersion; RuntimePacks=$leappPacks } | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $leappOutput 'BUILD-INFO.json')

    $leappProcessInfo = New-Object Diagnostics.ProcessStartInfo
    $leappProcessInfo.FileName = Join-Path $leappOutput 'uLEAPP.exe'
    $leappProcessInfo.Arguments = '--selfcheck --release-fixtures "' + (Join-Path $leappSource 'tests/fixtures') + '"'
    $leappProcessInfo.UseShellExecute = $false
    $leappProcessInfo.RedirectStandardOutput = $true
    $leappProcessInfo.RedirectStandardError = $true
    $leappProcessInfo.CreateNoWindow = $true
    $leappProcess = [Diagnostics.Process]::Start($leappProcessInfo)
    $leappStdout = $leappProcess.StandardOutput.ReadToEndAsync()
    $leappStderr = $leappProcess.StandardError.ReadToEndAsync()
    if (-not $leappProcess.WaitForExit(90000)) { $leappProcess.Kill(); throw 'The isolated self-check timed out.' }
    $leappText = $leappStdout.Result + $leappStderr.Result
    $leappText | Set-Content (Join-Path $leappOutput 'SELF-CHECK.txt')
    if ($leappProcess.ExitCode -ne 0) { throw $leappText }
    Write-Output $leappText
    $leappProcess.Dispose()
}
