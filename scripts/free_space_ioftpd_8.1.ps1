#requires -Version 5.1

<#
.SYNOPSIS
  Frees space in one ioFTPD section by removing its oldest release folders.

.DESCRIPTION
  Windows/ioFTPD replacement for free_space_v1.2.2.sh. The script is safe by
  default: without -Delete it only reports what it would remove. It supports
  local paths and UNC paths used by ioFTPD 8.1.0.

.EXAMPLE
  .\free_space_ioftpd_8.1.ps1 -IncomingPath 'D:\ioFTPD\FTP-ROOT-DIR\ISO' `
    -MinimumFreeMB 1000 -SectionName ISO -IoFtpdLog 'C:\ioFTPD\logs\ioFTPD.log'

.EXAMPLE
  .\free_space_ioftpd_8.1.ps1 -IncomingPath '\\nas\site\TV' `
    -MinimumFreeMB 50000 -VipGroups GRP1,GRP2 -VipDirectories PRE,TEMP `
    -NukedPrefix '[NUKED]-' -Delete -Announce
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $IncomingPath,

    [Parameter(Mandatory = $true)]
    [ValidateRange(0, [long]::MaxValue)]
    [long] $MinimumFreeMB,

    [ValidateRange(0, [long]::MaxValue)]
    [long] $MaximumSpaceAllowedMB = 0,

    [string[]] $VipDirectories = @(),
    [string[]] $VipGroups = @(),
    [string] $NukedPrefix = '[NUKED]-',

    [ValidateRange(0, [int]::MaxValue)]
    [int] $DeleteNukesAfterHours = 0,

    [ValidateRange(0, [int]::MaxValue)]
    [int] $NapSeconds = 0,

    [string] $SectionName = 'SECTION',
    [string] $IoFtpdLog = 'C:\ioFTPD\logs\ioFTPD.log',
    [string] $ErrorLog = 'C:\ioFTPD\logs\Error.log',
    [switch] $Announce,
    [switch] $Delete
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if (-not ('FreeSpace.NativeMethods' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace FreeSpace {
    public static class NativeMethods {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetDiskFreeSpaceEx(
            string directoryName,
            out ulong freeBytesAvailable,
            out ulong totalNumberOfBytes,
            out ulong totalNumberOfFreeBytes);
    }
}
'@
}

function Write-ErrorLog {
    param([string] $Message)
    $line = '{0} [free_space] ERROR: {1}' -f (Get-Date -Format 'MM-dd-yyyy HH:mm:ss'), $Message
    try {
        $parent = Split-Path -Parent $ErrorLog
        if ($parent -and (Test-Path -LiteralPath $parent -PathType Container)) {
            Add-Content -LiteralPath $ErrorLog -Value $line -Encoding ASCII
        }
    } catch {
        Write-Warning "Could not write to error log: $($_.Exception.Message)"
    }
    Write-Error $Message
}

function Get-FreeBytes {
    param([string] $Path)
    [UInt64] $available = 0
    [UInt64] $total = 0
    [UInt64] $totalFree = 0
    if (-not [FreeSpace.NativeMethods]::GetDiskFreeSpaceEx($Path, [ref] $available, [ref] $total, [ref] $totalFree)) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "GetDiskFreeSpaceEx failed for '$Path' (Win32 error $code)."
    }
    return [long] $available
}

function Get-DirectoryBytes {
    param([string] $Path)
    [long] $sum = 0
    Get-ChildItem -LiteralPath $Path -File -Force -Recurse -ErrorAction Stop |
        ForEach-Object { $sum += $_.Length }
    return $sum
}

function Get-EffectiveFreeMB {
    if ($MaximumSpaceAllowedMB -eq 0) {
        return [long] [math]::Floor((Get-FreeBytes -Path $script:SectionPath) / 1MB)
    }
    $usedMB = [long] [math]::Ceiling((Get-DirectoryBytes -Path $script:SectionPath) / 1MB)
    return $MaximumSpaceAllowedMB - $usedMB
}

function Test-IsVipRelease {
    param([System.IO.DirectoryInfo] $Directory)
    if ($VipDirectories -contains $Directory.Name) { return $true }
    foreach ($group in $VipGroups) {
        if ([string]::IsNullOrWhiteSpace($group)) { continue }
        if ($Directory.Name -match ('[-_.]{0}$' -f [regex]::Escape($group))) { return $true }
    }
    return $false
}

function Write-Announcement {
    param([long] $SizeMB, [string] $DirectoryName)
    if (-not $Announce) { return }
    $parent = Split-Path -Parent $IoFtpdLog
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "ioFTPD log directory does not exist: '$parent'."
    }
    $line = '{0} AUTODEL: "{1}" "{2}" "{3}"' -f `
        (Get-Date -Format 'MM-dd-yyyy HH:mm:ss'), $SizeMB, $SectionName, $DirectoryName
    Add-Content -LiteralPath $IoFtpdLog -Value $line -Encoding ASCII
}

try {
    $script:SectionPath = (Resolve-Path -LiteralPath $IncomingPath).ProviderPath.TrimEnd('\')
    if (-not (Test-Path -LiteralPath $script:SectionPath -PathType Container)) {
        throw "Incoming path is not a directory: '$IncomingPath'."
    }

    $root = [System.IO.Directory]::GetDirectoryRoot($script:SectionPath).TrimEnd('\')
    if ($script:SectionPath.TrimEnd('\') -eq $root) {
        throw 'IncomingPath must not be the root of a drive or network share.'
    }
    if ($MaximumSpaceAllowedMB -gt 0 -and $MinimumFreeMB -ge $MaximumSpaceAllowedMB) {
        throw 'MinimumFreeMB must be smaller than MaximumSpaceAllowedMB.'
    }

    $initialFreeMB = Get-EffectiveFreeMB
    Write-Host "Section: $SectionName ($script:SectionPath)"
    Write-Host "Effective free space: $initialFreeMB MB; target: $MinimumFreeMB MB"

    while ((Get-EffectiveFreeMB) -lt $MinimumFreeMB) {
        $directories = @(Get-ChildItem -LiteralPath $script:SectionPath -Directory -Force |
            Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) })

        $oldNukes = @($directories |
            Where-Object {
                $_.Name.StartsWith($NukedPrefix, [StringComparison]::OrdinalIgnoreCase) -and
                ((Get-Date) - $_.LastWriteTime).TotalHours -ge $DeleteNukesAfterHours
            } |
            Sort-Object LastWriteTime, Name)

        if ($oldNukes.Count -gt 0) {
            $candidate = $oldNukes[0]
        } else {
            $normal = @($directories |
                Where-Object {
                    -not $_.Name.StartsWith($NukedPrefix, [StringComparison]::OrdinalIgnoreCase) -and
                    -not (Test-IsVipRelease -Directory $_)
                } |
                Sort-Object LastWriteTime, Name)
            if ($normal.Count -eq 0) {
                throw 'No eligible directory remains; target free space cannot be reached.'
            }
            $candidate = $normal[0]
        }

        $sizeMB = [long] [math]::Ceiling((Get-DirectoryBytes -Path $candidate.FullName) / 1MB)
        if (-not $Delete) {
            Write-Host "DRY RUN: would delete '$($candidate.FullName)' ($sizeMB MB)."
            Write-Host 'Use -Delete to perform deletions.'
            break
        }

        if ($PSCmdlet.ShouldProcess($candidate.FullName, "Delete release directory ($sizeMB MB)")) {
            Remove-Item -LiteralPath $candidate.FullName -Recurse -Force
            Write-Host "Deleted '$($candidate.Name)' ($sizeMB MB)."
            Write-Announcement -SizeMB $sizeMB -DirectoryName $candidate.Name
        } else {
            # -WhatIf declines ShouldProcess; without this guard the unchanged
            # free-space value would make the loop select the same folder forever.
            break
        }

        if ($NapSeconds -gt 0) { Start-Sleep -Seconds $NapSeconds }
    }

    $finalFreeMB = Get-EffectiveFreeMB
    Write-Host "Finished. Effective free space: $finalFreeMB MB."
    exit 0
} catch {
    Write-ErrorLog -Message $_.Exception.Message
    exit 1
}
