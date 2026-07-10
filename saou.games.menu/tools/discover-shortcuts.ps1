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
    $shortcutData = Get-ShortcutData -File $File -Extension $extension

    if (-not $shortcutData.launchKey) {
        return $null
    }

    [PSCustomObject]@{
        fileName = $File.Name
        filePath = $File.FullName
        baseName = $File.BaseName
        extension = $extension
        launchKey = $shortcutData.launchKey
        launchTarget = $shortcutData.launchTarget
        launchArguments = $shortcutData.launchArguments
        workingDirectory = $shortcutData.workingDirectory
    }
}

function Normalize-LaunchText {
    param(
        [string] $Value
    )

    if ($null -eq $Value) {
        return ""
    }

    return $Value.Trim()
}

function Normalize-LaunchPath {
    param(
        [string] $Value
    )

    $text = Normalize-LaunchText -Value $Value

    if (-not $text) {
        return ""
    }

    return $text.Replace("/", "\").ToLowerInvariant()
}

function Normalize-LaunchUri {
    param(
        [string] $Value
    )

    $text = Normalize-LaunchText -Value $Value

    if (-not $text) {
        return ""
    }

    return $text.ToLowerInvariant()
}

function Get-InternetShortcutUrl {
    param(
        [string] $Path
    )

    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        $match = [System.Text.RegularExpressions.Regex]::Match($line, "^\s*URL\s*=(.*)$", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        if ($match.Success) {
            return (Normalize-LaunchText -Value $match.Groups[1].Value)
        }
    }

    return ""
}

function Get-ShortcutData {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo] $File,
        [string] $Extension
    )

    if ($Extension -eq "url") {
        $url = Get-InternetShortcutUrl -Path $File.FullName
        $normalizedUrl = Normalize-LaunchUri -Value $url

        return [PSCustomObject]@{
            launchKey = if ($normalizedUrl) { "url:$normalizedUrl" } else { "" }
            launchTarget = $url
            launchArguments = ""
            workingDirectory = ""
        }
    }

    if ($Extension -eq "lnk") {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($File.FullName)
        $targetPath = Normalize-LaunchText -Value $shortcut.TargetPath
        $arguments = Normalize-LaunchText -Value $shortcut.Arguments
        $workingDirectory = Normalize-LaunchText -Value $shortcut.WorkingDirectory
        $normalizedTarget = Normalize-LaunchPath -Value $targetPath
        $normalizedWorkingDirectory = Normalize-LaunchPath -Value $workingDirectory
        $normalizedArguments = $arguments.Trim()

        return [PSCustomObject]@{
            launchKey = if ($normalizedTarget) { "lnk:$normalizedTarget|$normalizedArguments|$normalizedWorkingDirectory" } else { "" }
            launchTarget = $targetPath
            launchArguments = $arguments
            workingDirectory = $workingDirectory
        }
    }

    return [PSCustomObject]@{
        launchKey = ""
        launchTarget = ""
        launchArguments = ""
        workingDirectory = ""
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
            } |
            Where-Object {
                $null -ne $_
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
