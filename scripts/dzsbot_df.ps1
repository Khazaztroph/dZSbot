param(
    [string] $SectionsFile = 'C:\ioFTPD\scripts\dzsbot-df-sections.tsv',
    [string] $OutputFile = 'C:\ioFTPD\logs\dzsbot-df.tsv'
)

$ErrorActionPreference = 'Stop'

function Clean-Field {
    param([string] $Value)
    if ($null -eq $Value) {
        return ''
    }
    return ($Value -replace "`t", ' ' -replace "`r", ' ' -replace "`n", ' ')
}

$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$outDir = Split-Path -Parent $OutputFile
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$tmp = "$OutputFile.tmp"
$rows = New-Object System.Collections.Generic.List[string]
$rows.Add("# dZSbot-df-v1`t$now")
$fso = New-Object -ComObject Scripting.FileSystemObject

if (-not (Test-Path -LiteralPath $SectionsFile)) {
    $rows.Add("$now`tCONFIG`t$SectionsFile`t0`t0`t0`tsections file not found")
    Set-Content -LiteralPath $tmp -Value $rows -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $OutputFile -Force
    exit 1
}

foreach ($line in Get-Content -LiteralPath $SectionsFile -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
        continue
    }

    $parts = $line -split "`t", 2
    if ($parts.Count -lt 2) {
        continue
    }

    $name = $parts[0].Trim()
    $path = $parts[1].Trim()
    $windowsPath = $path -replace '/', '\'
    if (-not $name -or -not $path) {
        continue
    }

    try {
        $null = Get-Item -LiteralPath $windowsPath -ErrorAction Stop
        $driveName = $fso.GetDriveName($windowsPath)
        $drive = $fso.GetDrive($driveName)
        $free = [int64]($drive.AvailableSpace / 1MB)
        $total = [int64]($drive.TotalSize / 1MB)
        $used = [int64](($drive.TotalSize - $drive.AvailableSpace) / 1MB)
        $rows.Add("$now`t$(Clean-Field $name)`t$(Clean-Field $path)`t$free`t$used`t$total`t")
    } catch {
        $rows.Add("$now`t$(Clean-Field $name)`t$(Clean-Field $path)`t0`t0`t0`t$(Clean-Field $_.Exception.Message)")
    }
}

Set-Content -LiteralPath $tmp -Value $rows -Encoding UTF8
Move-Item -LiteralPath $tmp -Destination $OutputFile -Force
