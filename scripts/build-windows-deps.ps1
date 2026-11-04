# Builds the static libraries the Visual Studio project links from
# lib\windows64, for x64 with the static C runtime (/MT), with vcpkg pinned
# to a release (same FFmpeg and x264 as scripts/build-macos-deps.sh):
#   ffmpeg[avcodec,avdevice,avfilter,avformat,swresample,swscale,gpl,x264,zlib,bzip2,iconv]
# -> lib\windows64\*.lib, headers in include\ffmpeg\w.
# --enable-gpl and libx264 make the FFmpeg libraries GPL.
#
# usage: scripts\build-windows-deps.ps1 [output-dir]   (default: lib\windows64)
# WORK (default build\deps-win) holds vcpkg and its builds; a rerun reuses them.
# Needs: git, Visual Studio 2022 with the C++ tools (vcpkg fetches MSYS2, NASM...).

param([string]$Out = "")

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
if (-not $Out) { $Out = Join-Path $Root "lib\windows64" }
$Work = if ($env:WORK) { $env:WORK } else { Join-Path $Root "build\deps-win" }

$VCPKG_SHA = "9eec002df1cd109f8f104cd966a763daf9751489"   # vcpkg 2026.10.16: ffmpeg 9.0.2, x264 0.165.3222
$TRIPLET   = "x64-windows-static"
$FEATURES  = "avcodec,avdevice,avfilter,avformat,swresample,swscale,gpl,x264,zlib,bzip2,iconv"

function Invoke-Native {
  param([string]$Exe, [string[]]$Arguments)
  & $Exe @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Exe $($Arguments -join ' ') failed ($LASTEXITCODE)" }
}

$Vcpkg = Join-Path $Work "vcpkg"
$ok = $false
if (Test-Path (Join-Path $Vcpkg ".git")) {
  & git -C $Vcpkg rev-parse -q --verify HEAD *> $null
  $ok = ($LASTEXITCODE -eq 0)
}
if (-not $ok) {
  New-Item -ItemType Directory -Force -Path $Vcpkg | Out-Null
  Invoke-Native git @("-C", $Vcpkg, "init", "-q")
  for ($i = 1; $i -le 3; $i++) {
    & git -C $Vcpkg fetch -q --depth 1 "https://github.com/microsoft/vcpkg.git" $VCPKG_SHA
    if ($LASTEXITCODE -eq 0) { break }
    if ($i -eq 3) { throw "fetch vcpkg failed" }
    Start-Sleep -Seconds 10
  }
  Invoke-Native git @("-C", $Vcpkg, "checkout", "-q", "FETCH_HEAD")
}

$Exe = Join-Path $Vcpkg "vcpkg.exe"
if (-not (Test-Path $Exe)) {
  Invoke-Native (Join-Path $Vcpkg "bootstrap-vcpkg.bat") @("-disableMetrics")
}
Invoke-Native $Exe @("install", "ffmpeg[$FEATURES]:$TRIPLET", "--disable-metrics", "--clean-after-build")

$Installed = Join-Path $Vcpkg "installed\$TRIPLET"

New-Item -ItemType Directory -Force -Path $Out | Out-Null
Get-ChildItem (Join-Path $Installed "lib") -Filter *.lib | Copy-Item -Destination $Out -Force

$Headers = Join-Path $Root "include\ffmpeg\w"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $Headers
New-Item -ItemType Directory -Force -Path $Headers | Out-Null
foreach ($d in @("libavcodec", "libavdevice", "libavfilter", "libavformat", "libavutil", "libswresample", "libswscale")) {
  Copy-Item -Recurse -Force (Join-Path $Installed "include\$d") (Join-Path $Headers $d)
}

# the link line in ffmpeg.vcxproj names these; list everything else vcpkg built
Get-ChildItem $Out -Filter *.lib | ForEach-Object { $_.Name }
