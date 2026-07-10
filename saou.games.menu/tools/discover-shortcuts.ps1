param(
    [string] $ShortcutDir,
    [string] $DiscoveryOutputPath,
    [int] $DiscoveryRequestId
)

$ErrorActionPreference = "Stop"

function New-DiscoveryItem {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $File
    )

    $extension = $File.Extension.TrimStart(".").ToLowerInvariant()

    [PSCustomObject]@{
        fileName = $File.Name
        filePath = $File.FullName
        baseName = $File.BaseName
        extension = $extension
    }
}

try {
    $items = @()

    if (Test-Path -LiteralPath $ShortcutDir -PathType Container) {
        $items = Get-ChildItem -LiteralPath $ShortcutDir -Force |
            Where-Object {
                -not $_.PSIsContainer -and ($_.Extension -ieq ".lnk" -or $_.Extension -ieq ".url")
            } |
            Sort-Object `
                @{ Expression = { $_.BaseName.ToLowerInvariant() } }, `
                @{ Expression = { if ($_.Extension -ieq ".lnk") { 0 } elseif ($_.Extension -ieq ".url") { 1 } else { 2 } } }, `
                @{ Expression = { $_.Name.ToLowerInvariant() } } |
            ForEach-Object {
                New-DiscoveryItem -File $_
            }
    }

    $result = [PSCustomObject]@{
        requestId = $DiscoveryRequestId
        shortcutDir = $ShortcutDir
        items = @($items)
    }
} catch {
    $result = [PSCustomObject]@{
        requestId = $DiscoveryRequestId
        shortcutDir = $ShortcutDir
        items = @()
        error = $_.Exception.Message
    }
}

$outputDirectory = [System.IO.Path]::GetDirectoryName($DiscoveryOutputPath)

if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$json = $result | ConvertTo-Json -Depth 5 -Compress
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($DiscoveryOutputPath, $json, $utf8NoBom)
