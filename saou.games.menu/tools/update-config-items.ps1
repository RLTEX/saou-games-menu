param(
    [string] $ConfigPath,
    [string] $StatePath,
    [string] $UpdateOutputPath,
    [int] $UpdateRequestId,
    [string] $ItemsEncoded
)

$ErrorActionPreference = "Stop"

function Decode-Value {
    param(
        [string] $Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    return [System.Uri]::UnescapeDataString($Value).Trim()
}

function Decode-DiscoveredItems {
    param(
        [string] $EncodedValue
    )

    $result = New-Object "System.Collections.Generic.List[object]"

    if ([string]::IsNullOrWhiteSpace($EncodedValue)) {
        return $result.ToArray()
    }

    foreach ($entry in $EncodedValue.Split("|")) {
        if ([string]::IsNullOrWhiteSpace($entry)) {
            continue
        }

        $parts = @($entry -split ",", 4)

        if ($parts.Length -lt 2) {
            continue
        }

        $baseName = Decode-Value -Value $parts[0]
        $launchKey = Decode-Value -Value $parts[1]

        if ($baseName -and $launchKey) {
            $filePath = if ($parts.Length -gt 2) { Decode-Value -Value $parts[2] } else { "" }

            $result.Add([PSCustomObject]@{
                baseName = $baseName
                launchKey = $launchKey
                filePath = $filePath
                fileName = if ($filePath) { [System.IO.Path]::GetFileName($filePath) } else { "" }
                extension = if ($parts.Length -gt 3) { Decode-Value -Value $parts[3] } else { "" }
            })
        }
    }

    return $result.ToArray()
}

function Read-State {
    param(
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [PSCustomObject]@{
            nextId = 1
            items = @()
        }
    }

    try {
        $state = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        $state = $null
    }

    if ($null -eq $state) {
        return [PSCustomObject]@{
            nextId = 1
            items = @()
        }
    }

    $items = @()

    if ($state.items) {
        $items = @($state.items | Where-Object {
            $_.id -and $_.launchKey
        } | ForEach-Object {
            [PSCustomObject]@{
                id = [int] $_.id
                launchKey = [string] $_.launchKey
                title = [string] $_.title
            }
        })
    }

    $maxId = 0

    foreach ($item in $items) {
        if ($item.id -gt $maxId) {
            $maxId = $item.id
        }
    }

    $nextId = [int] $state.nextId

    if ($nextId -le $maxId) {
        $nextId = $maxId + 1
    }

    if ($nextId -lt 1) {
        $nextId = 1
    }

    return [PSCustomObject]@{
        nextId = $nextId
        items = @($items)
    }
}

function Write-State {
    param(
        [string] $Path,
        [object] $State
    )

    $directory = [System.IO.Path]::GetDirectoryName($Path)

    if ($directory -and -not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $json = $State | ConvertTo-Json -Depth 5
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

function Resolve-Identities {
    param(
        [object[]] $DiscoveredItems,
        [object] $State
    )

    $stateChanged = $false
    $byLaunchKey = @{}
    $stateByLaunchKey = @{}
    $stateItems = New-Object "System.Collections.Generic.List[object]"

    foreach ($item in @($State.items)) {
        $launchKeyLookup = ([string] $item.launchKey).ToLowerInvariant()

        if (-not $byLaunchKey.ContainsKey($launchKeyLookup)) {
            $byLaunchKey[$launchKeyLookup] = [int] $item.id
            $stateByLaunchKey[$launchKeyLookup] = $item
            $stateItems.Add($item)
        }
    }

    $resolved = New-Object "System.Collections.Generic.List[object]"

    foreach ($item in $DiscoveredItems) {
        $launchKey = [string] $item.launchKey
        $launchKeyLookup = $launchKey.ToLowerInvariant()

        if (-not $byLaunchKey.ContainsKey($launchKeyLookup)) {
            $id = [int] $State.nextId
            $State.nextId = $id + 1
            $stateItem = [PSCustomObject]@{
                id = $id
                launchKey = $launchKey
                title = [string] $item.baseName
            }
            $stateItems.Add($stateItem)
            $byLaunchKey[$launchKeyLookup] = $id
            $stateByLaunchKey[$launchKeyLookup] = $stateItem
            $stateChanged = $true
        }

        $stateItemForKey = $stateByLaunchKey[$launchKeyLookup]

        $resolved.Add([PSCustomObject]@{
            id = [int] $byLaunchKey[$launchKeyLookup]
            title = [string] $item.baseName
            baseName = [string] $item.baseName
            launchKey = $launchKey
            previousTitle = [string] $stateItemForKey.title
            stateTitle = [string] $item.baseName
            filePath = [string] $item.filePath
            fileName = [string] $item.fileName
            extension = [string] $item.extension
        })
    }

    $State.items = @($stateItems.ToArray())

    return [PSCustomObject]@{
        stateChanged = $stateChanged
        items = @($resolved.ToArray())
    }
}

function Parse-ConfigLine {
    param(
        [string] $Line
    )

    $trimmed = $Line.Trim()

    if (-not $trimmed -or $trimmed.StartsWith("#")) {
        return $null
    }

    $separator = $trimmed.IndexOf("=")

    if ($separator -lt 0) {
        return $null
    }

    return [PSCustomObject]@{
        key = $trimmed.Substring(0, $separator).Trim().ToLowerInvariant()
        value = Remove-GeneratedFolderHint -Value $trimmed.Substring($separator + 1).Trim()
    }
}

function Remove-GeneratedFolderHint {
    param(
        [string] $Value
    )

    return ([string] $Value) -replace "\s+#\s*IN\s*:\s*.*$", ""
}

function Parse-ConfigVersion {
    param(
        [string[]] $Lines
    )

    foreach ($line in $Lines) {
        $parsed = Parse-ConfigLine -Line $line

        if ($parsed -and $parsed.key -eq "configversion") {
            $version = 0

            if ([int]::TryParse($parsed.value, [ref] $version)) {
                return $version
            }
        }
    }

    return 2
}

function Split-ConfigValue {
    param(
        [string] $Value
    )

    $text = [string] $Value
    return ,@($text -split "\|", -1)
}

function Add-Range {
    param(
        [object] $Target,
        [object[]] $Values
    )

    foreach ($value in @($Values)) {
        $Target.Add($value)
    }
}

function Join-ConfigLines {
    param(
        [object] $Lines,
        [string] $NewLine
    )

    return (@($Lines.ToArray()) -join $NewLine) + $NewLine
}

function ItemIdFromLine {
    param(
        [string] $Line
    )

    $parsed = Parse-ConfigLine -Line $Line

    if (-not $parsed -or $parsed.key -ne "item") {
        return 0
    }

    $parts = Split-ConfigValue -Value $parsed.value
    $id = 0

    if ($parts.Length -gt 0 -and [int]::TryParse($parts[0].Trim(), [ref] $id)) {
        return $id
    }

    return 0
}

function Escape-CommentLine {
    param(
        [string] $Line,
        [string] $Reason
    )

    return "# Unmigrated v2 ${Reason}: " + $Line.Trim()
}

function Get-FolderDisplayName {
    param(
        [string] $Value
    )

    $parts = Split-ConfigValue -Value $Value

    if ($parts.Length -lt 1) {
        return $null
    }

    $folderId = $parts[0].Trim().ToLowerInvariant()

    if (-not $folderId -or $folderId -eq "all") {
        return $null
    }

    $displayParts = @()

    if ($parts.Length -gt 1) {
        $displayParts = @($parts[1..($parts.Length - 1)])
    }

    if ($displayParts.Count -gt 1) {
        $lastPart = $displayParts[$displayParts.Count - 1].Trim()
        $parsedMaxColumns = 0

        if ([int]::TryParse($lastPart, [ref] $parsedMaxColumns) -and $parsedMaxColumns -gt 0 -and ([string] $parsedMaxColumns) -eq $lastPart) {
            $displayParts = @($displayParts[0..($displayParts.Count - 2)])
        }
    }

    $displayName = ($displayParts -join "|").Trim()

    if (-not $displayName) {
        $displayName = $folderId.ToUpperInvariant()
    }

    return $displayName
}

function Get-FolderHintMap {
    param(
        [object] $Lines
    )

    $result = @{}
    $currentFolderName = ""

    foreach ($line in @($Lines.ToArray())) {
        $parsed = Parse-ConfigLine -Line $line

        if (-not $parsed) {
            continue
        }

        if ($parsed.key -eq "folder") {
            $currentFolderName = [string] (Get-FolderDisplayName -Value $parsed.value)
            continue
        }

        if ($parsed.key -ne "game" -or -not $currentFolderName) {
            continue
        }

        $parts = Split-ConfigValue -Value $parsed.value
        $id = 0

        if ($parts.Length -lt 1 -or -not [int]::TryParse($parts[0].Trim(), [ref] $id)) {
            continue
        }

        $idKey = [string] $id

        if (-not $result.ContainsKey($idKey)) {
            $result[$idKey] = New-Object "System.Collections.Generic.List[string]"
        }

        if (-not $result[$idKey].Contains($currentFolderName)) {
            $result[$idKey].Add($currentFolderName)
        }
    }

    return $result
}

function Format-FolderHintLine {
    param(
        [string] $Line,
        [string] $Hint
    )

    $targetColumn = 40
    $comment = "# IN: " + $Hint

    if ($Line.Length -lt $targetColumn) {
        return $Line + (" " * ($targetColumn - $Line.Length)) + $comment
    }

    return $Line + "  " + $comment
}

function Update-FolderHints {
    param(
        [object] $Lines
    )

    $changed = $false
    $hintMap = Get-FolderHintMap -Lines $Lines

    for ($i = 0; $i -lt $Lines.Count; ++$i) {
        $line = [string] $Lines[$i]
        $parsed = Parse-ConfigLine -Line $line

        if (-not $parsed -or $parsed.key -ne "item") {
            continue
        }

        $parts = Split-ConfigValue -Value $parsed.value
        $id = 0

        if ($parts.Length -lt 1 -or -not [int]::TryParse($parts[0].Trim(), [ref] $id)) {
            continue
        }

        $baseLine = (Remove-GeneratedFolderHint -Value $line).TrimEnd()
        $idKey = [string] $id
        $hint = ""

        if ($hintMap.ContainsKey($idKey) -and $hintMap[$idKey].Count -gt 0) {
            $hint = ($hintMap[$idKey].ToArray() -join ", ")
        }

        $updatedLine = if ($hint) { Format-FolderHintLine -Line $baseLine -Hint $hint } else { $baseLine }

        if ($line -ne $updatedLine) {
            $Lines[$i] = $updatedLine
            $changed = $true
        }
    }

    return $changed
}

function Rename-ShortcutForTitle {
    param(
        [object] $Item,
        [string] $Title
    )

    $result = [PSCustomObject]@{
        renamed = $false
        ready = $false
        warning = ""
        baseName = [string] $Item.baseName
        fileName = [string] $Item.fileName
        filePath = [string] $Item.filePath
    }

    $sourcePath = [string] $Item.filePath

    if ([string]::IsNullOrWhiteSpace($sourcePath) -or -not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        $result.warning = "Could not rename shortcut for ID $($Item.id): source file is missing"
        return $result
    }

    $cleanTitle = [string] $Title

    foreach ($invalidChar in [System.IO.Path]::GetInvalidFileNameChars()) {
        if ($cleanTitle.IndexOf($invalidChar) -ge 0) {
            $result.warning = "Could not rename shortcut for ID $($Item.id): title contains an invalid file-name character"
            return $result
        }
    }

    $extension = [string] $Item.extension

    if (-not $extension) {
        $extension = [System.IO.Path]::GetExtension($sourcePath).TrimStart(".")
    }

    if (-not $extension) {
        $result.warning = "Could not rename shortcut for ID $($Item.id): shortcut extension is missing"
        return $result
    }

    $directory = [System.IO.Path]::GetDirectoryName($sourcePath)
    $targetFileName = $cleanTitle + "." + $extension.TrimStart(".")
    $targetPath = [System.IO.Path]::Combine($directory, $targetFileName)
    $sourceFullPath = [System.IO.Path]::GetFullPath($sourcePath)
    $targetFullPath = [System.IO.Path]::GetFullPath($targetPath)

    if ([string]::Equals($sourceFullPath, $targetFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $result.ready = $true
        $result.baseName = $cleanTitle
        $result.fileName = [System.IO.Path]::GetFileName($sourceFullPath)
        $result.filePath = $sourceFullPath
        return $result
    }

    if (Test-Path -LiteralPath $targetFullPath -PathType Leaf) {
        $result.warning = "Could not rename shortcut for ID $($Item.id): target already exists: $targetFullPath"
        return $result
    }

    Move-Item -LiteralPath $sourceFullPath -Destination $targetFullPath

    $result.renamed = $true
    $result.ready = $true
    $result.baseName = $cleanTitle
    $result.fileName = $targetFileName
    $result.filePath = $targetFullPath
    return $result
}

function Sync-StateTitles {
    param(
        [object] $State,
        [object[]] $ResolvedItems
    )

    $changed = $false
    $titleByLaunchKey = @{}

    foreach ($item in @($ResolvedItems)) {
        $launchKey = ([string] $item.launchKey).ToLowerInvariant()
        $stateTitle = [string] $item.stateTitle

        if ($launchKey -and $stateTitle) {
            $titleByLaunchKey[$launchKey] = $stateTitle
        }
    }

    foreach ($stateItem in @($State.items)) {
        $launchKey = ([string] $stateItem.launchKey).ToLowerInvariant()

        if (-not $titleByLaunchKey.ContainsKey($launchKey)) {
            continue
        }

        $nextTitle = $titleByLaunchKey[$launchKey]

        if ([string] $stateItem.title -ne $nextTitle) {
            $stateItem.title = $nextTitle
            $changed = $true
        }
    }

    return $changed
}

function Update-Config {
    param(
        [string] $Path,
        [object[]] $ResolvedItems
    )

    $result = [PSCustomObject]@{
        configChanged = $false
        configAddedItems = @()
        warnings = @()
    }

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $result
    }

    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $newLine = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $rawLines = $content -split "`r?`n"

    if ($rawLines.Length -gt 0 -and $rawLines[$rawLines.Length - 1] -eq "") {
        if ($rawLines.Length -eq 1) {
            $rawLines = @()
        } else {
            $rawLines = $rawLines[0..($rawLines.Length - 2)]
        }
    }

    $version = Parse-ConfigVersion -Lines $rawLines
    $isV3 = $version -ge 3
    $byId = @{}
    $byTitle = @{}
    $titleCounts = @{}

    foreach ($item in $ResolvedItems) {
        $idKey = [string] $item.id
        $titleKey = ([string] $item.title).ToLowerInvariant()

        $byId[$idKey] = $item
        $byTitle[$titleKey] = $item

        if (-not $titleCounts.ContainsKey($titleKey)) {
            $titleCounts[$titleKey] = 0
        }

        $titleCounts[$titleKey] += 1
    }

    $updatedLines = New-Object "System.Collections.Generic.List[string]"
    $lastItemLineById = @{}
    $configTitleById = @{}
    $existingItemIds = @{}
    $firstFolderIndex = -1
    $sectionIndex = -1
    $currentFolder = $false
    $versionFound = $false

    for ($i = 0; $i -lt $rawLines.Length; ++$i) {
        $line = $rawLines[$i]
        $parsed = Parse-ConfigLine -Line $line

        if ($parsed -and $parsed.key -eq "configversion") {
            $versionFound = $true

            if ($parsed.value -ne "3") {
                $updatedLines.Add("configVersion=3")
                $result.configChanged = $true
            } else {
                $updatedLines.Add($line)
            }

            continue
        }

        if ($parsed -and $parsed.key -eq "folder") {
            $currentFolder = $true

            if ($firstFolderIndex -lt 0) {
                $firstFolderIndex = $updatedLines.Count
            }
        }

        if ($line.Trim().Equals("# Auto-discovered game metadata", [System.StringComparison]::OrdinalIgnoreCase) -or
            $line.Trim().Equals("# Game metadata:", [System.StringComparison]::OrdinalIgnoreCase)) {
            $sectionIndex = $updatedLines.Count
        }

        if ($parsed -and $parsed.key -eq "item") {
            $parts = Split-ConfigValue -Value $parsed.value
            $id = 0

            if ($isV3 -and $parts.Length -ge 2 -and [int]::TryParse($parts[0].Trim(), [ref] $id)) {
                $existingItemIds[[string] $id] = $true
                $lastItemLineById[[string] $id] = $updatedLines.Count
                $configTitleById[[string] $id] = $parts[1].Trim()
                $updatedLines.Add($line)
                continue
            }

            if (-not $isV3 -and $parts.Length -ge 1) {
                $oldTitle = $parts[0].Trim()
                $oldSubtitle = if ($parts.Length -gt 1) { ($parts[1..($parts.Length - 1)] -join "|").Trim() } else { "" }
                $titleKey = $oldTitle.ToLowerInvariant()

                if ($byTitle.ContainsKey($titleKey) -and $titleCounts[$titleKey] -eq 1) {
                    $item = $byTitle[$titleKey]
                    $existingItemIds[[string] $item.id] = $true
                    $lastItemLineById[[string] $item.id] = $updatedLines.Count
                    $configTitleById[[string] $item.id] = $item.title
                    $updatedLines.Add("item=$($item.id)|$($item.title)|$oldSubtitle")
                    $result.configChanged = $true
                } else {
                    $updatedLines.Add((Escape-CommentLine -Line $line -Reason "item"))
                    $result.warnings += "Could not migrate v2 item: $oldTitle"
                    $result.configChanged = $true
                }

                continue
            }
        }

        if ($parsed -and $parsed.key -eq "game" -and $currentFolder) {
            $parts = Split-ConfigValue -Value $parsed.value
            $gameId = 0

            if ($isV3 -and $parts.Length -ge 1 -and [int]::TryParse($parts[0].Trim(), [ref] $gameId)) {
                $updatedLines.Add($line)
                continue
            }

            if (-not $isV3 -and $parts.Length -ge 1) {
                $oldTitle = $parts[0].Trim()
                $titleKey = $oldTitle.ToLowerInvariant()

                if ($byTitle.ContainsKey($titleKey) -and $titleCounts[$titleKey] -eq 1) {
                    $item = $byTitle[$titleKey]
                    $linePrefix = $line.Substring(0, $line.IndexOf("game=", [System.StringComparison]::OrdinalIgnoreCase))
                    $updatedLines.Add($linePrefix + "game=$($item.id)")
                    $result.configChanged = $true
                } else {
                    $updatedLines.Add((Escape-CommentLine -Line $line -Reason "folder game"))
                    $result.warnings += "Could not migrate v2 folder game: $oldTitle"
                    $result.configChanged = $true
                }

                continue
            }
        }

        $updatedLines.Add($line)
    }

    if (-not $versionFound) {
        $updatedLines.Insert(0, "configVersion=3")
        $result.configChanged = $true
    }

    foreach ($item in $ResolvedItems) {
        $id = [int] $item.id
        $idKey = [string] $id
        $discoveredTitle = [string] $item.baseName

        if (-not $discoveredTitle) {
            $discoveredTitle = [string] $item.title
        }

        if ($lastItemLineById.ContainsKey($idKey)) {
            $lineIndex = $lastItemLineById[$idKey]
            $line = $updatedLines[$lineIndex]
            $parsed = Parse-ConfigLine -Line $line
            $parts = Split-ConfigValue -Value $parsed.value
            $configTitle = if ($configTitleById.ContainsKey($idKey)) { [string] $configTitleById[$idKey] } else { "" }
            $previousTitle = [string] $item.previousTitle
            $configTitleChanged = $false

            if ($configTitle) {
                if ($previousTitle) {
                    $configTitleChanged = $configTitle -ne $previousTitle
                } else {
                    $configTitleChanged = $configTitle -ne $discoveredTitle
                }
            }

            if ($configTitleChanged) {
                $renameResult = Rename-ShortcutForTitle -Item $item -Title $configTitle

                if ($renameResult.warning) {
                    $result.warnings += $renameResult.warning
                }

                $item.title = $configTitle

                if ($renameResult.ready) {
                    $item.baseName = $renameResult.baseName
                    $item.fileName = $renameResult.fileName
                    $item.filePath = $renameResult.filePath
                    $item.stateTitle = $configTitle
                } elseif ($previousTitle) {
                    $item.stateTitle = $previousTitle
                } else {
                    $item.stateTitle = $discoveredTitle
                }
            } else {
                $item.title = $discoveredTitle
                $item.stateTitle = $discoveredTitle
            }

            $subtitle = if ($parts.Length -gt 2) { ($parts[2..($parts.Length - 1)] -join "|").Trim() } else { "" }
            $replacement = "item=$id|$($item.title)|$subtitle"

            if ($line -ne $replacement) {
                $updatedLines[$lineIndex] = $replacement
                $result.configChanged = $true
            }
        } elseif (-not $existingItemIds.ContainsKey($idKey)) {
            $item.title = $discoveredTitle
            $item.stateTitle = $discoveredTitle
            $result.configAddedItems += [string] $id
        }
    }

    if ($result.configAddedItems.Count -gt 0) {
        $newItemLines = New-Object "System.Collections.Generic.List[string]"

        foreach ($idText in $result.configAddedItems) {
            $item = $byId[$idText]
            $newItemLines.Add("item=$($item.id)|$($item.title)|Game Subtitle")
        }

        if ($sectionIndex -ge 0) {
            $insertIndex = $sectionIndex + 1

            while ($insertIndex -lt $updatedLines.Count -and (ItemIdFromLine -Line $updatedLines[$insertIndex]) -gt 0) {
                $insertIndex += 1
            }

            for ($i = 0; $i -lt $newItemLines.Count; ++$i) {
                $updatedLines.Insert($insertIndex + $i, $newItemLines[$i])
            }
        } elseif ($firstFolderIndex -ge 0) {
            $insertIndex = $firstFolderIndex

            if ($insertIndex -gt 0 -and $updatedLines[$insertIndex - 1].Trim() -ne "") {
                $updatedLines.Insert($insertIndex, "")
                $insertIndex += 1
            }

            $updatedLines.Insert($insertIndex, "# Game metadata:")
            $insertIndex += 1

            for ($i = 0; $i -lt $newItemLines.Count; ++$i) {
                $updatedLines.Insert($insertIndex + $i, $newItemLines[$i])
            }

            $updatedLines.Insert($insertIndex + $newItemLines.Count, "")
        } else {
            if ($updatedLines.Count -gt 0 -and $updatedLines[$updatedLines.Count - 1].Trim() -ne "") {
                $updatedLines.Add("")
            }

            $updatedLines.Add("# Game metadata:")
            Add-Range -Target $updatedLines -Values $newItemLines.ToArray()
        }

        $result.configChanged = $true
    }

    if (Update-FolderHints -Lines $updatedLines) {
        $result.configChanged = $true
    }

    if ($result.configChanged) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($Path, (Join-ConfigLines -Lines $updatedLines -NewLine $newLine), $utf8NoBom)
    }

    return $result
}

$configChanged = $false
$stateChanged = $false
$configAddedItems = @()
$identityItems = @()
$configUpdateError = ""
$warnings = @()

try {
    $discoveredItems = Decode-DiscoveredItems -EncodedValue $ItemsEncoded
    $state = Read-State -Path $StatePath
    $identityResult = Resolve-Identities -DiscoveredItems $discoveredItems -State $state
    $stateChanged = $identityResult.stateChanged -eq $true
    $identityItems = @($identityResult.items)

    $configResult = Update-Config -Path $ConfigPath -ResolvedItems $identityItems
    $configChanged = $configResult.configChanged -eq $true
    $configAddedItems = @($configResult.configAddedItems)
    $warnings = @($configResult.warnings)

    $stateTitleChanged = Sync-StateTitles -State $state -ResolvedItems $identityItems
    $stateChanged = $stateChanged -or $stateTitleChanged

    if ($stateChanged) {
        Write-State -Path $StatePath -State $state
    }
} catch {
    $configUpdateError = $_.Exception.Message
}

$result = [PSCustomObject]@{
    requestId = $UpdateRequestId
    configChanged = $configChanged
    stateChanged = $stateChanged
    configAddedItems = @($configAddedItems)
    configUpdateError = $configUpdateError
    warnings = @($warnings)
    items = @($identityItems)
}

$outputDirectory = [System.IO.Path]::GetDirectoryName($UpdateOutputPath)

if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$json = $result | ConvertTo-Json -Depth 8 -Compress
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($UpdateOutputPath, $json, $utf8NoBom)
