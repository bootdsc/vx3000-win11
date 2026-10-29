<#
.SYNOPSIS
Installs the Microsoft LifeCam VX-3000 driver on Windows 10 and 11.

.DESCRIPTION
Rebuilds the package layout the INF expects, checks the catalog signature,
then adds and binds the driver with pnputil. Staging happens in TEMP and is
removed afterwards. Run from an elevated prompt.

.PARAMETER Path
Folder holding the driver files. Subfolders are searched for VX3000.inf.

.PARAMETER Language
LCID of the resource DLLs to install. 1033 is English (United States).

.PARAMETER CheckOnly
Verify the package and report device state without installing.

.PARAMETER KeepStage
Leave the staging folder in place and print its path.
#>

[CmdletBinding()]
param(
    [string]$Path = ".\driver",
    [int]$Language = 1033,
    [switch]$CheckOnly,
    [switch]$KeepStage
)

$ErrorActionPreference = "Stop"

$DEVICE_ID = "USB\VID_045E&PID_00F5"
$REQUIRED = @("VX3000.inf", "VX3000.sys", "VX3000.cat")

function Say($text) { Write-Host $text }

function Fail($text) {
    Write-Host "ERROR  $text"
    exit 1
}

function Get-PackageFile($dir) {
    # The package root plus any numeric language subfolder. Anything else in
    # the tree is somebody's extracted resources, not part of the driver.
    $files = @(Get-ChildItem $dir -File -EA SilentlyContinue)
    foreach ($sub in Get-ChildItem $dir -Directory -EA SilentlyContinue) {
        if ($sub.Name -match '^\d+$') {
            $files += @(Get-ChildItem $sub.FullName -File -EA SilentlyContinue)
        }
    }
    return $files
}

function Get-CultureName($lcid) {
    try { return [System.Globalization.CultureInfo]::GetCultureInfo($lcid).DisplayName }
    catch { return $null }
}

# --- locate the package ----------------------------------------------------

if (-not (Test-Path $Path)) { Fail "no such folder: $Path" }
$root = (Resolve-Path $Path).Path

$inf = Get-ChildItem $root -Recurse -Filter "VX3000.inf" -File -EA SilentlyContinue |
       Select-Object -First 1
if (-not $inf) { Fail "VX3000.inf not found under $Path" }
$pkg = $inf.Directory.FullName

foreach ($name in $REQUIRED) {
    if (-not (Test-Path (Join-Path $pkg $name))) { Fail "missing $name in $pkg" }
}

Say "package:   $pkg"

# --- catalog signature -----------------------------------------------------

$sig = Get-AuthenticodeSignature (Join-Path $pkg "VX3000.cat")
Say "catalog:   $($sig.Status)"
if ($sig.SignerCertificate) {
    $cn = ($sig.SignerCertificate.Subject -split ",")[0] -replace "^CN=", ""
    Say "signer:    $cn"
}
if ($sig.Status -ne "Valid") {
    Say "The catalog does not verify. Installing it is unlikely to work and the files"
    Say "may not be the ones this repo was tested against. Check them before going on."
}

# --- known hashes ----------------------------------------------------------

$known = Join-Path $PSScriptRoot "checksums\sha256-known.txt"
if (Test-Path $known) {
    $map = @{}
    foreach ($line in Get-Content $known) {
        if ($line -match '^\s*([0-9a-f]{64})\s+(\S.*?)\s*$') {
            $map[$matches[1]] = $matches[2]
        }
    }
    $seen = 0
    $unknown = @()
    foreach ($f in Get-PackageFile $pkg) {
        $h = (Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLower()
        if ($map.ContainsKey($h)) { $seen++ } else { $unknown += $f.Name }
    }
    Say "hashes:    $seen known, $($unknown.Count) unrecognized"
    if ($unknown.Count -gt 0) {
        $show = $unknown | Select-Object -First 8
        Say "unrecognized: $($show -join ', ')"
        if ($unknown.Count -gt 8) { Say "              and $($unknown.Count - 8) more" }
    }
}

# --- stage -----------------------------------------------------------------

$culture = Get-CultureName $Language
if (-not $culture) { Fail "unknown LCID $Language" }

$stageRoot = $PSScriptRoot
if (-not $stageRoot) { $stageRoot = (Get-Location).Path }
$stage = Join-Path $stageRoot (".stage-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $stage -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stage $Language) -Force | Out-Null

# Flat files, skipping the resource DLLs and the duplicates a flattened
# download leaves behind ("VX3000 (6).dll" and friends).
foreach ($f in Get-ChildItem $pkg -File) {
    if ($f.Length -eq 0) { continue }
    if ($f.Name -like "VX3000 (*" -or $f.Name -like "VX3x64 (*") { continue }
    if ($f.Name -eq "VX3000.dll" -or $f.Name -eq "VX3x64.dll") { continue }
    Copy-Item $f.FullName -Destination $stage -Force
}

function Find-Resource($prefix, $culture) {
    $candidates = Get-PackageFile $pkg | Where-Object { $_.Name -like "$prefix*.dll" }
    foreach ($c in $candidates) {
        if ((Get-Item $c.FullName).VersionInfo.Language -eq $culture) { return $c.FullName }
    }
    return $null
}

$res32 = Find-Resource "VX3000" $culture
$res64 = Find-Resource "VX3x64" $culture
if (-not $res32 -or -not $res64) {
    Remove-Item $stage -Recurse -Force -EA SilentlyContinue
    Fail "no $culture resource DLLs in the package. Try another -Language."
}
Copy-Item $res32 (Join-Path $stage "$Language\VX3000.dll") -Force
Copy-Item $res64 (Join-Path $stage "$Language\VX3x64.dll") -Force
Say "language:  $culture ($Language)"

# --- install ---------------------------------------------------------------

$admin = ([Security.Principal.WindowsPrincipal] `
          [Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($CheckOnly) {
    Say "check only, nothing installed"
} elseif (-not $admin) {
    Remove-Item $stage -Recurse -Force -EA SilentlyContinue
    Fail "run this from an elevated prompt"
} else {
    $pnputil = Join-Path $env:SystemRoot "System32\pnputil.exe"
    if (-not (Test-Path $pnputil)) { $pnputil = "pnputil.exe" }
    & $pnputil /add-driver (Join-Path $stage "VX3000.inf") /install
    if ($LASTEXITCODE -ne 0) {
        Say "pnputil returned $LASTEXITCODE"
    }
}

# --- report ----------------------------------------------------------------

Say ""
$devs = Get-PnpDevice -PresentOnly -EA SilentlyContinue |
        Where-Object { $_.InstanceId -like "*VID_045E&PID_00F5*" }
if (-not $devs) {
    Say "no VX-3000 on any port right now"
} else {
    foreach ($d in $devs) {
        $code = ""
        try {
            $code = (Get-PnpDeviceProperty -InstanceId $d.InstanceId `
                     -KeyName DEVPKEY_Device_ProblemCode -EA Stop).Data
        } catch { $code = "?" }
        Say ("{0,-8} {1,-7} code {2,-3} {3}" -f $d.Status, $d.Class, $code, $d.FriendlyName)
    }
    Say ""
    Say "The video interface reads Image class and OK with code 0 once this works."
    Say "It lands under Imaging devices in Device Manager, not Cameras."
}

if ($KeepStage) {
    Say "stage:     $stage"
} else {
    Remove-Item $stage -Recurse -Force -EA SilentlyContinue
}
