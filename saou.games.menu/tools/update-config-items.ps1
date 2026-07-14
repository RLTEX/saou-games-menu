param(
    [string] $ConfigPath,
    [string] $StatePath,
    [string] $UpdateOutputPath,
    [int] $UpdateRequestId,
    [string] $ItemsEncoded,
    [string] $Operation = "discover",
    [string] $CardId,
    [string] $CardDataEncoded,
    [string] $CustomImageDirectory,
    [string] $ManagedShortcutDirectory
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

function Get-ObjectPropertyValue {
    param(
        [object] $Object,
        [string] $Name
    )

    if ($null -eq $Object) {
        return $null
    }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return $Object[$Name]
        }

        return $null
    }

    $property = $Object.PSObject.Properties[$Name]

    if ($property) {
        return $property.Value
    }

    return $null
}

function Test-ObjectHasProperty {
    param(
        [object] $Object,
        [string] $Name
    )

    if ($null -eq $Object) {
        return $false
    }

    if ($Object -is [System.Collections.IDictionary]) {
        return $Object.Contains($Name)
    }

    return $null -ne $Object.PSObject.Properties[$Name]
}

function Normalize-CardId {
    param(
        [string] $Value
    )

    return ([string] $Value).Trim()
}

function Normalize-ManualSourcePath {
    param([string] $Value)

    $path = ([string] $Value).Trim()

    if (-not $path) { return "" }

    if ($path.StartsWith("file:", [System.StringComparison]::OrdinalIgnoreCase)) {
        try { $path = (New-Object System.Uri($path)).LocalPath } catch { throw "Source path is invalid" }
    }

    return [System.IO.Path]::GetFullPath($path)
}

function Get-ManualSourceType {
    param([string] $Path)

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -notin @(".lnk", ".url", ".exe")) { throw "Only .lnk, .url, and .exe files can be added" }
    return $extension.TrimStart(".")
}

function Normalize-FolderOrderKey {
    param([string] $Value)

    $key = ([string] $Value).Trim().ToLowerInvariant()

    if (-not $key) { throw "Folder ID is required for card ordering" }
    if ($key -notmatch "^[a-z0-9][a-z0-9_-]*$") { throw "Folder ID is invalid for card ordering" }

    return $key
}

function Normalize-FolderOrders {
    param([object] $Value)

    $result = [ordered]@{}

    if ($null -eq $Value) { return $result }

    if ($Value -is [System.Collections.IDictionary]) {
        $entries = @($Value.GetEnumerator())
        foreach ($entry in $entries) {
            $key = Normalize-FolderOrderKey -Value ([string] $entry.Key)
            $order = 0
            if ([int]::TryParse([string] $entry.Value, [ref] $order) -and $order -ge 0) { $result[$key] = $order }
        }
    } else {
        foreach ($property in @($Value.PSObject.Properties)) {
            $key = Normalize-FolderOrderKey -Value ([string] $property.Name)
            $order = 0
            if ([int]::TryParse([string] $property.Value, [ref] $order) -and $order -ge 0) { $result[$key] = $order }
        }
    }

    return $result
}

function Normalize-CardData {
    param(
        [object] $Data
    )

    $result = [ordered]@{}

    foreach ($name in @("customTitle", "description", "customImage", "folderId")) {
        $value = Get-ObjectPropertyValue -Object $Data -Name $name
        $normalized = ([string] $value).Trim()

        if ($normalized) {
            $result[$name] = $normalized
        }
    }

    if (Test-ObjectHasProperty -Object $Data -Name "order") {
        $parsedOrder = 0
        $orderValue = Get-ObjectPropertyValue -Object $Data -Name "order"

        if ([int]::TryParse([string] $orderValue, [ref] $parsedOrder) -and $parsedOrder -ge 0) {
            $result.order = $parsedOrder
        }
    }

    $folderOrders = Normalize-FolderOrders -Value (Get-ObjectPropertyValue -Object $Data -Name "folderOrders")
    if ($folderOrders.Count -gt 0) {
        $result.folderOrders = [PSCustomObject] $folderOrders
    }

    $hiddenValue = Get-ObjectPropertyValue -Object $Data -Name "isHidden"

    if ($hiddenValue -eq $true -or ([string] $hiddenValue).Trim().ToLowerInvariant() -eq "true") {
        $result.isHidden = $true
    }

    $sourcePath = Get-ObjectPropertyValue -Object $Data -Name "sourcePath"

    if (([string] $sourcePath).Trim()) {
        $normalizedSourcePath = Normalize-ManualSourcePath -Value $sourcePath
        $result.sourcePath = $normalizedSourcePath
        $result.sourceType = Get-ManualSourceType -Path $normalizedSourcePath

        $automaticTitle = ([string] (Get-ObjectPropertyValue -Object $Data -Name "automaticTitle")).Trim()
        $result.automaticTitle = if ($automaticTitle) { $automaticTitle } else { [System.IO.Path]::GetFileNameWithoutExtension($normalizedSourcePath) }

        $targetPath = ([string] (Get-ObjectPropertyValue -Object $Data -Name "targetPath")).Trim()
        if ($targetPath) { $result.targetPath = $targetPath }

        $launchPath = ([string] (Get-ObjectPropertyValue -Object $Data -Name "launchPath")).Trim()
        if ($launchPath) { $result.launchPath = $launchPath }
    }

    if ($result.Count -eq 0) {
        return $null
    }

    return [PSCustomObject] $result
}

function Decode-CardData {
    param(
        [string] $EncodedValue
    )

    $json = Decode-Value -Value $EncodedValue

    if (-not $json) {
        return [PSCustomObject]@{}
    }

    try {
        return $json | ConvertFrom-Json
    } catch {
        throw "Card data JSON is invalid"
    }
}

function Get-ManagedImageDirectory {
    if ($CustomImageDirectory) {
        return [System.IO.Path]::GetFullPath($CustomImageDirectory)
    }

    $localAppData = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)

    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        throw "Local application data directory is unavailable"
    }

    return Join-Path $localAppData "SAO Utils\Games Menu\custom-images"
}

function Get-ManagedShortcutDirectory {
    if ($ManagedShortcutDirectory) { return [System.IO.Path]::GetFullPath($ManagedShortcutDirectory) }
    $localAppData = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)
    if ([string]::IsNullOrWhiteSpace($localAppData)) { throw "Local application data directory is unavailable" }
    return Join-Path $localAppData "SAO Utils\Games Menu\shortcuts"
}

function Import-CardShortcut {
    param([string] $CardId, [string] $SourceFile)

    $sourcePath = Normalize-ManualSourcePath -Value $SourceFile
    $sourceType = Get-ManualSourceType -Path $sourcePath
    if ($sourceType -eq "exe") { return $sourcePath }
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Selected shortcut file was not found" }

    $directory = Get-ManagedShortcutDirectory
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $fileName = (Get-SafeCardFileStem -CardId $CardId) + "-" + [System.Guid]::NewGuid().ToString("N") + "." + $sourceType
    $destination = Join-Path $directory $fileName
    Copy-Item -LiteralPath $sourcePath -Destination $destination -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) { throw "Shortcut copy could not be verified" }
    return [System.IO.Path]::GetFullPath($destination)
}

function Get-SafeCardFileStem {
    param(
        [string] $CardId
    )

    $safe = (Normalize-CardId -Value $CardId) -replace "[^A-Za-z0-9_-]", "_"

    if (-not $safe) {
        throw "Card ID is invalid for an image file name"
    }

    return $safe
}

function Resolve-ImageSourcePath {
    param(
        [string] $Value
    )

    $source = ([string] $Value).Trim()

    if (-not $source) {
        throw "Image source is required"
    }

    if ($source.StartsWith("file:", [System.StringComparison]::OrdinalIgnoreCase)) {
        try {
            $uri = New-Object System.Uri($source)

            if (-not $uri.IsFile) {
                throw "Only local image files are supported"
            }

            return $uri.LocalPath
        } catch {
            throw "Image source path is invalid"
        }
    }

    return [System.IO.Path]::GetFullPath($source)
}

function Test-SupportedImageContent {
    param(
        [string] $Path,
        [string] $Extension
    )

    $buffer = New-Object byte[] 12
    $stream = $null

    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $read = $stream.Read($buffer, 0, $buffer.Length)
    } finally {
        if ($stream) {
            $stream.Dispose()
        }
    }

    $extension = $Extension.ToLowerInvariant()

    if ($extension -eq ".png") {
        return $read -ge 8 -and $buffer[0] -eq 137 -and $buffer[1] -eq 80 -and $buffer[2] -eq 78 -and $buffer[3] -eq 71 -and $buffer[4] -eq 13 -and $buffer[5] -eq 10 -and $buffer[6] -eq 26 -and $buffer[7] -eq 10
    }

    if ($extension -eq ".jpg" -or $extension -eq ".jpeg") {
        return $read -ge 3 -and $buffer[0] -eq 255 -and $buffer[1] -eq 216 -and $buffer[2] -eq 255
    }

    if ($extension -eq ".webp") {
        return $read -ge 12 -and [System.Text.Encoding]::ASCII.GetString($buffer, 0, 4) -eq "RIFF" -and [System.Text.Encoding]::ASCII.GetString($buffer, 8, 4) -eq "WEBP"
    }

    return $false
}

function Import-CardImage {
    param(
        [string] $CardId,
        [string] $SourceFile
    )

    $sourcePath = Resolve-ImageSourcePath -Value $SourceFile

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Selected image file was not found"
    }

    $sourceExtension = [System.IO.Path]::GetExtension($sourcePath).ToLowerInvariant()

    if ($sourceExtension -notin @(".png", ".jpg", ".jpeg", ".webp")) {
        throw "Only PNG, JPG, JPEG, and WebP images are supported"
    }

    if (-not (Test-SupportedImageContent -Path $sourcePath -Extension $sourceExtension)) {
        throw "Selected file does not contain a supported image"
    }

    $destinationExtension = if ($sourceExtension -eq ".jpeg") { ".jpg" } else { $sourceExtension }
    $directory = Get-ManagedImageDirectory

    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $fileName = (Get-SafeCardFileStem -CardId $CardId) + "-" + [System.Guid]::NewGuid().ToString("N") + $destinationExtension
    $destination = Join-Path $directory $fileName

    try {
        Copy-Item -LiteralPath $sourcePath -Destination $destination -ErrorAction Stop

        if (-not (Test-Path -LiteralPath $destination -PathType Leaf) -or (Get-Item -LiteralPath $destination).Length -le 0) {
            throw "Image copy could not be verified"
        }
    } catch {
        if (Test-Path -LiteralPath $destination -PathType Leaf) {
            Remove-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue
        }

        throw
    }

    return [System.IO.Path]::GetFullPath($destination)
}

function Test-ManagedImagePath {
    param(
        [string] $Path,
        [string] $CardId
    )

    if (-not $Path) {
        return $false
    }

    try {
        $directory = [System.IO.Path]::GetFullPath((Get-ManagedImageDirectory))
        $candidate = [System.IO.Path]::GetFullPath((Resolve-ImageSourcePath -Value $Path))
    } catch {
        return $false
    }

    $separator = [string] [System.IO.Path]::DirectorySeparatorChar

    if (-not $directory.EndsWith($separator)) {
        $directory += [System.IO.Path]::DirectorySeparatorChar
    }

    if (-not $candidate.StartsWith($directory, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }

    $pattern = "^" + [System.Text.RegularExpressions.Regex]::Escape((Get-SafeCardFileStem -CardId $CardId)) + "-[0-9a-f]{32}\.(png|jpg|webp)$"
    return [System.IO.Path]::GetFileName($candidate) -match $pattern
}

function Test-ImagePathReferenced {
    param(
        [object] $State,
        [string] $Path
    )

    if (-not $State -or -not $State.cardData -or -not $Path) {
        return $false
    }

    try {
        $target = [System.IO.Path]::GetFullPath((Resolve-ImageSourcePath -Value $Path))
    } catch {
        return $false
    }

    foreach ($entry in $State.cardData.GetEnumerator()) {
        $candidate = [string] (Get-ObjectPropertyValue -Object $entry.Value -Name "customImage")

        if (-not $candidate) {
            continue
        }

        try {
            if ([System.IO.Path]::GetFullPath((Resolve-ImageSourcePath -Value $candidate)).Equals($target, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        } catch {
        }
    }

    return $false
}

function Remove-ManagedImageIfUnused {
    param(
        [object] $State,
        [string] $CardId,
        [string] $Path
    )

    if (-not (Test-ManagedImagePath -Path $Path -CardId $CardId) -or (Test-ImagePathReferenced -State $State -Path $Path)) {
        return
    }

    try {
        Remove-Item -LiteralPath (Resolve-ImageSourcePath -Value $Path) -Force -ErrorAction Stop
    } catch {
        Write-Warning "Games Menu could not remove managed image '$Path': $($_.Exception.Message)"
    }
}

function Read-State {
    param(
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [PSCustomObject]@{
            stateVersion = 3
            nextId = 1
            items = @()
            cardData = [ordered]@{}
            schemaChanged = $true
        }
    }

    try {
        $state = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        $state = $null
    }

    if ($null -eq $state) {
        return [PSCustomObject]@{
            stateVersion = 3
            nextId = 1
            items = @()
            cardData = [ordered]@{}
            schemaChanged = $true
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

    $cardData = [ordered]@{}

    if ($state.cardData) {
        foreach ($property in $state.cardData.PSObject.Properties) {
            $cardId = Normalize-CardId -Value $property.Name
            $normalized = Normalize-CardData -Data $property.Value

            if ($cardId -and $normalized) {
                $cardData[$cardId] = $normalized
            }
        }
    }

    $stateVersion = 0

    if ($state.PSObject.Properties["stateVersion"]) {
        [void] [int]::TryParse([string] $state.stateVersion, [ref] $stateVersion)
    }

    return [PSCustomObject]@{
        stateVersion = 3
        nextId = $nextId
        items = @($items)
        cardData = $cardData
        schemaChanged = $stateVersion -lt 3 -or -not $state.PSObject.Properties["cardData"]
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

    $stateForWrite = [PSCustomObject]@{
        stateVersion = 3
        nextId = [int] $State.nextId
        items = @($State.items)
        cardData = $State.cardData
    }
    $json = $stateForWrite | ConvertTo-Json -Depth 8
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

function Get-CardData {
    param(
        [object] $State,
        [string] $Id
    )

    $cardId = Normalize-CardId -Value $Id

    if (-not $cardId -or -not $State.cardData.Contains($cardId)) {
        return $null
    }

    return $State.cardData[$cardId]
}

function Set-CardData {
    param(
        [object] $State,
        [string] $Id,
        [object] $Data
    )

    $cardId = Normalize-CardId -Value $Id
    $normalized = Normalize-CardData -Data $Data

    if (-not $cardId) {
        throw "Card ID is required"
    }

    if ($normalized) {
        $State.cardData[$cardId] = $normalized
    } elseif ($State.cardData.Contains($cardId)) {
        $State.cardData.Remove($cardId)
    }

    return $normalized
}

function Find-CardIdByManualSource {
    param([object] $State, [string] $SourcePath)

    $key = (Normalize-ManualSourcePath -Value $SourcePath).ToLowerInvariant()
    foreach ($entry in $State.cardData.GetEnumerator()) {
        $candidate = [string] (Get-ObjectPropertyValue -Object $entry.Value -Name "sourcePath")
        if ($candidate -and (Normalize-ManualSourcePath -Value $candidate).ToLowerInvariant() -eq $key) {
            return [string] $entry.Key
        }
    }
    return ""
}

function Add-ManualIdentity {
    param([object] $State, [string] $CardId, [string] $SourcePath, [string] $Title)

    $id = [int] $CardId
    $launchKey = "manual:" + (Normalize-ManualSourcePath -Value $SourcePath).ToLowerInvariant()
    foreach ($item in @($State.items)) {
        if ([int] $item.id -eq $id -and [string] $item.launchKey -ne $launchKey) { throw "Card ID is already in use" }
        if ([string] $item.launchKey -eq $launchKey) { throw "This game is already added" }
    }

    $State.items = @($State.items) + @([PSCustomObject]@{ id = $id; launchKey = $launchKey; title = $Title })
    if ($State.nextId -le $id) { $State.nextId = $id + 1 }
}

function Preserve-ConfigTitleAsCustomTitle {
    param(
        [object] $State,
        [string] $Id,
        [string] $Title
    )

    $cleanTitle = ([string] $Title).Trim()

    if (-not $cleanTitle) {
        return $false
    }

    $existing = Get-CardData -State $State -Id $Id

    if ($existing -and ([string] $existing.customTitle).Trim()) {
        return $false
    }

    $merged = [ordered]@{
        customTitle = $cleanTitle
    }

    foreach ($name in @("description", "customImage", "folderId", "isHidden")) {
        $value = Get-ObjectPropertyValue -Object $existing -Name $name

        if (([string] $value).Trim()) {
            $merged[$name] = ([string] $value).Trim()
        }
    }

    if (Test-ObjectHasProperty -Object $existing -Name "order") {
        $merged.order = Get-ObjectPropertyValue -Object $existing -Name "order"
    }

    [void] (Set-CardData -State $State -Id $Id -Data ([PSCustomObject] $merged))
    return $true
}

function Write-OutputJson {
    param(
        [string] $Path,
        [object] $Value
    )

    $outputDirectory = [System.IO.Path]::GetDirectoryName($Path)

    if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }

    $json = $Value | ConvertTo-Json -Depth 8 -Compress
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
        value = $trimmed.Substring($separator + 1).Trim()
    }
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
        [object[]] $ResolvedItems,
        [object] $State
    )

    $result = [PSCustomObject]@{
        configChanged = $false
        stateChanged = $false
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
                $folderSubtitle = if ($parts.Length -gt 1) { ($parts[1..($parts.Length - 1)] -join "|").Trim() } else { "" }
                $titleKey = $oldTitle.ToLowerInvariant()

                if ($byTitle.ContainsKey($titleKey) -and $titleCounts[$titleKey] -eq 1) {
                    $item = $byTitle[$titleKey]
                    $linePrefix = $line.Substring(0, $line.IndexOf("game=", [System.StringComparison]::OrdinalIgnoreCase))
                    $newValue = if ($folderSubtitle) { "game=$($item.id)|$folderSubtitle" } else { "game=$($item.id)" }
                    $updatedLines.Add($linePrefix + $newValue)
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

            if ($configTitleChanged -and (Preserve-ConfigTitleAsCustomTitle -State $State -Id $idKey -Title $configTitle)) {
                $result.stateChanged = $true
                $result.warnings += "Migrated configured title for ID $id to local card data; shortcut files are not renamed"
            }

            # Shortcut basenames remain the automatic title source. Display overrides live in state\items.json.
            $item.title = $discoveredTitle
            $item.stateTitle = $discoveredTitle

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

    if ($result.configChanged) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($Path, (Join-ConfigLines -Lines $updatedLines -NewLine $newLine), $utf8NoBom)
    }

    return $result
}

if ($Operation -eq "prepare-manual-card") {
    $cardDataUpdateError = ""
    $draft = $null

    try {
        $state = Read-State -Path $StatePath
        $data = Decode-CardData -EncodedValue $CardDataEncoded
        $sourcePath = Normalize-ManualSourcePath -Value ([string] (Get-ObjectPropertyValue -Object $data -Name "sourcePath"))
        $sourceType = Get-ManualSourceType -Path $sourcePath

        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Selected file was not found" }
        if (Find-CardIdByManualSource -State $state -SourcePath $sourcePath) { throw "This game is already added" }

        $folderId = ([string] (Get-ObjectPropertyValue -Object $data -Name "folderId")).Trim()
        $order = 0
        [void] [int]::TryParse([string] (Get-ObjectPropertyValue -Object $data -Name "order"), [ref] $order)
        $draft = [PSCustomObject]@{
            cardId = "" + [int] $state.nextId
            sourcePath = $sourcePath
            targetPath = if ($sourceType -eq "exe") { $sourcePath } else { "" }
            sourceType = $sourceType
            automaticTitle = [System.IO.Path]::GetFileNameWithoutExtension($sourcePath)
            folderId = $folderId
            order = [Math]::Max(0, $order)
        }
    } catch {
        $cardDataUpdateError = $_.Exception.Message
    }

    Write-OutputJson -Path $UpdateOutputPath -Value ([PSCustomObject]@{
        requestId = $UpdateRequestId; operation = $Operation; cardId = ""; cardDataUpdateError = $cardDataUpdateError; manualCardDraft = $draft
    })
    exit 0
}

if ($Operation -eq "update-card-orders") {
    $cardDataUpdateError = ""
    $cardDataChanged = $false
    $updatedCardData = [ordered]@{}

    try {
        $state = Read-State -Path $StatePath
        $payload = Decode-CardData -EncodedValue $CardDataEncoded
        $folderId = Normalize-FolderOrderKey -Value ([string] (Get-ObjectPropertyValue -Object $payload -Name "folderId"))
        $entries = @(Get-ObjectPropertyValue -Object $payload -Name "orders")

        if ($entries.Count -eq 0) { throw "Card order list is empty" }

        $seenCardIds = @{}
        $seenOrders = @{}
        $normalizedEntries = @()

        foreach ($entry in $entries) {
            $entryCardId = Normalize-CardId -Value ([string] (Get-ObjectPropertyValue -Object $entry -Name "cardId"))
            $entryOrder = 0

            if (-not $entryCardId) { throw "Card ID is required for ordering" }
            if (-not [int]::TryParse([string] (Get-ObjectPropertyValue -Object $entry -Name "order"), [ref] $entryOrder) -or $entryOrder -lt 0) { throw "Card order is invalid" }
            if ($seenCardIds.ContainsKey($entryCardId)) { throw "Duplicate card ID in order update" }
            if ($seenOrders.ContainsKey($entryOrder)) { throw "Duplicate order in order update" }

            $seenCardIds[$entryCardId] = $true
            $seenOrders[$entryOrder] = $true
            $normalizedEntries += [PSCustomObject]@{ cardId = $entryCardId; order = $entryOrder }
        }

        for ($expectedOrder = 0; $expectedOrder -lt $normalizedEntries.Count; ++$expectedOrder) {
            if (-not $seenOrders.ContainsKey($expectedOrder)) { throw "Card order must be sequential" }
        }

        foreach ($entry in $normalizedEntries) {
            $nextCardData = Normalize-CardData -Data (Get-CardData -State $state -Id $entry.cardId)
            if (-not $nextCardData) { $nextCardData = [PSCustomObject]@{} }

            $folderOrders = Normalize-FolderOrders -Value (Get-ObjectPropertyValue -Object $nextCardData -Name "folderOrders")
            $folderOrders[$folderId] = [int] $entry.order

            if (Test-ObjectHasProperty -Object $nextCardData -Name "folderOrders") {
                $nextCardData.folderOrders = [PSCustomObject] $folderOrders
            } else {
                $nextCardData | Add-Member -NotePropertyName folderOrders -NotePropertyValue ([PSCustomObject] $folderOrders)
            }

            [void] (Set-CardData -State $state -Id $entry.cardId -Data $nextCardData)
        }

        Write-State -Path $StatePath -State $state
        $cardDataChanged = $true
        $updatedCardData = $state.cardData
    } catch {
        $cardDataUpdateError = $_.Exception.Message
    }

    Write-OutputJson -Path $UpdateOutputPath -Value ([PSCustomObject]@{
        requestId = $UpdateRequestId
        operation = $Operation
        cardId = $CardId
        stateChanged = $cardDataChanged
        cardDataUpdateError = $cardDataUpdateError
        cardData = $updatedCardData
    })
    exit 0
}

if ($Operation -eq "update-card-data" -or $Operation -eq "remove-card-data" -or $Operation -eq "create-manual-card") {
    $cardDataUpdateError = ""
    $cardDataChanged = $false
    $updatedCardData = [ordered]@{}
    $newManagedImage = ""
    $newManagedShortcut = ""
    $previousCustomImage = ""

    try {
        $state = Read-State -Path $StatePath
        $normalizedCardId = Normalize-CardId -Value $CardId

        if (-not $normalizedCardId) {
            throw "Card ID is required"
        }

        $previousCardData = Get-CardData -State $state -Id $normalizedCardId
        $previousCustomImage = [string] (Get-ObjectPropertyValue -Object $previousCardData -Name "customImage")

        if ($Operation -eq "update-card-data" -or $Operation -eq "create-manual-card") {
            $decodedCardData = Decode-CardData -EncodedValue $CardDataEncoded
            $customImageSource = [string] (Get-ObjectPropertyValue -Object $decodedCardData -Name "customImageSource")

            if ($Operation -eq "create-manual-card") {
                $sourcePath = Normalize-ManualSourcePath -Value ([string] (Get-ObjectPropertyValue -Object $decodedCardData -Name "sourcePath"))
                $sourceType = Get-ManualSourceType -Path $sourcePath
                if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Selected file was not found" }
                if (Find-CardIdByManualSource -State $state -SourcePath $sourcePath) { throw "This game is already added" }
                if ([int] $normalizedCardId -ne [int] $state.nextId) { throw "Card ID is no longer available; drop the file again" }

                # Keep portable shortcuts under the widget's local data.  The original
                # sourcePath remains untouched and is retained only for duplicate checks.
                $newManagedShortcut = Import-CardShortcut -CardId $normalizedCardId -SourceFile $sourcePath
                if (Test-ObjectHasProperty -Object $decodedCardData -Name "launchPath") {
                    $decodedCardData.launchPath = $newManagedShortcut
                } else {
                    $decodedCardData | Add-Member -NotePropertyName launchPath -NotePropertyValue $newManagedShortcut
                }
            }

            if ($customImageSource.Trim()) {
                $newManagedImage = Import-CardImage -CardId $normalizedCardId -SourceFile $customImageSource

                if (Test-ObjectHasProperty -Object $decodedCardData -Name "customImage") {
                    $decodedCardData.customImage = $newManagedImage
                } else {
                    $decodedCardData | Add-Member -NotePropertyName customImage -NotePropertyValue $newManagedImage
                }
            }

            [void] (Set-CardData -State $state -Id $normalizedCardId -Data $decodedCardData)

            if ($Operation -eq "create-manual-card") {
                Add-ManualIdentity -State $state -CardId $normalizedCardId -SourcePath $sourcePath -Title ([string] (Get-ObjectPropertyValue -Object $decodedCardData -Name "automaticTitle"))
            }
            $cardDataChanged = $true
        } elseif ($state.cardData.Contains($normalizedCardId)) {
            $state.cardData.Remove($normalizedCardId)
            $cardDataChanged = $true
        }

        if ($state.schemaChanged -or $cardDataChanged) {
            Write-State -Path $StatePath -State $state
        }

        if ($cardDataChanged -and $previousCustomImage) {
            Remove-ManagedImageIfUnused -State $state -CardId $normalizedCardId -Path $previousCustomImage
        }

        $updatedCardData = $state.cardData
    } catch {
        if ($newManagedImage -and (Test-Path -LiteralPath $newManagedImage -PathType Leaf)) {
            Remove-Item -LiteralPath $newManagedImage -Force -ErrorAction SilentlyContinue
        }

        # Import-CardShortcut returns the source itself for .exe files, so clean up
        # only copied .lnk/.url files on a failed transaction.
        if ($newManagedShortcut -and $sourceType -ne "exe" -and (Test-Path -LiteralPath $newManagedShortcut -PathType Leaf)) {
            Remove-Item -LiteralPath $newManagedShortcut -Force -ErrorAction SilentlyContinue
        }

        $cardDataUpdateError = $_.Exception.Message
    }

    Write-OutputJson -Path $UpdateOutputPath -Value ([PSCustomObject]@{
        requestId = $UpdateRequestId
        operation = $Operation
        cardId = $CardId
        stateChanged = $cardDataChanged
        cardDataUpdateError = $cardDataUpdateError
        cardData = $updatedCardData
    })
    exit 0
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
    $stateChanged = $identityResult.stateChanged -eq $true -or $state.schemaChanged -eq $true
    $identityItems = @($identityResult.items)

    $configResult = Update-Config -Path $ConfigPath -ResolvedItems $identityItems -State $state
    $configChanged = $configResult.configChanged -eq $true
    $configAddedItems = @($configResult.configAddedItems)
    $warnings = @($configResult.warnings)
    $stateChanged = $stateChanged -or $configResult.stateChanged -eq $true

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
    cardData = if ($state) { $state.cardData } else { [ordered]@{} }
}

Write-OutputJson -Path $UpdateOutputPath -Value $result
