# Host only: Windows PowerShell 5.1 and .NET 4.5+.
param([string]$OutputDirectory='')
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
if (!$OutputDirectory) { $OutputDirectory=Join-Path $root ('dist\release-'+(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)) }
$OutputDirectory=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Use a new package directory; existing releases are preserved.' }
if (!(Test-Path -LiteralPath (Join-Path $root 'build\vmtool.exe'))) { throw 'Build the executable before packaging.' }
$stage=Join-Path $OutputDirectory 'Windows7-VM-Research'
New-Item -ItemType Directory -Path $stage | Out-Null
foreach ($name in @('src','include','scripts','host','config','docs','tests','licenses')) { Copy-Item -LiteralPath (Join-Path $root $name) -Destination $stage -Recurse }
foreach ($name in @('README.md','BUILD.md','THIRD_PARTY.md','run.bat')) { Copy-Item -LiteralPath (Join-Path $root $name) -Destination $stage }
foreach ($name in @('build','reports','logs','backups')) { New-Item -ItemType Directory -Path (Join-Path $stage $name) | Out-Null }
foreach ($name in @('vmtool.exe','pe-audit.txt','compiler.txt')) { Copy-Item -LiteralPath (Join-Path $root ('build\'+$name)) -Destination (Join-Path $stage 'build') }
$hashes=foreach ($f in (Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName)) {
    (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+$f.FullName.Substring($stage.Length+1).Replace('\','/')
}
$hashes | Out-File -FilePath (Join-Path $stage 'SHA256SUMS.txt') -Encoding ascii
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=Join-Path $OutputDirectory 'Windows7-VM-Research.zip'
[IO.Compression.ZipFile]::CreateFromDirectory($stage,$zip,[IO.Compression.CompressionLevel]::Optimal,$true)
(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()+'  Windows7-VM-Research.zip' | Out-File -FilePath (Join-Path $OutputDirectory 'SHA256SUMS.txt') -Encoding ascii
Write-Host ('Release: '+$zip)
