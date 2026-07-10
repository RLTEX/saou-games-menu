var DEFAULT_CONFIG = {
    configVersion: 3,
    shortcutsDir: "",
    startHidden: false,
    maxColumns: 3,
    syncSubtitle: true,
    folders: [],
    items: [],
    legacyGames: []
}

var registeredGames = []

function load() {
    registeredGames = []

    var source = loadLocalConfig()

    if (registeredGames.length === 0)
        loadLegacyGames()

    return normalizeConfig(source, registeredGames)
}

function addGame(title, shortcut, image, options) {
    var gameTitle = normalizeString(title, "")
    var gameShortcut = normalizeString(shortcut, "")
    var gameImage = normalizeString(image, "")
    var gameOptions = options && typeof options === "object" ? options : {}

    if (!gameTitle || !gameShortcut || !gameImage) {
        console.log("Games Menu addGame skipped: title, shortcut and image are required")
        return
    }

    registeredGames.push({
        id: normalizeString(gameOptions.id, ""),
        title: gameTitle,
        subtitle: normalizeDescription(gameOptions),
        shortcut: gameShortcut,
        image: userAssetImagePath(gameImage),
        accent: normalizeString(gameOptions.accent, "")
    })
}

function loadLocalConfig() {
    try {
        config = undefined
        userConfig = undefined
    } catch (error) {
    }

    var textConfig = loadTextConfig()

    if (textConfig)
        return textConfig

    includeOptional("../config.local.js", "config.local.js")

    if (typeof config === "object" && config !== null)
        return config

    if (typeof userConfig === "object" && userConfig !== null)
        return userConfig

    includeOptional("../config.example.js", "config.example.js")

    if (typeof config === "object" && config !== null)
        return config

    if (typeof userConfig === "object" && userConfig !== null)
        return userConfig

    return {}
}

function loadTextConfig() {
    var localText = readTextFile("../config.local.txt")

    if (localText !== null)
        return parseTextConfig(localText, "config.local.txt")

    var text = readTextFile("../config.txt")

    if (text !== null)
        return parseTextConfig(text, "config.txt")

    var exampleText = readTextFile("../config.example.txt")

    if (exampleText !== null)
        return parseTextConfig(exampleText, "config.example.txt")

    return null
}

function readTextFile(path) {
    try {
        var request = new XMLHttpRequest()
        request.open("GET", path, false)
        request.send()

        if ((request.status === 0 && request.responseText !== "") || (request.status >= 200 && request.status < 300))
            return request.responseText
    } catch (error) {
    }

    return null
}

function parseTextConfig(text, label) {
    var source = {
        configVersion: DEFAULT_CONFIG.configVersion,
        shortcutsDir: DEFAULT_CONFIG.shortcutsDir,
        startHidden: DEFAULT_CONFIG.startHidden,
        maxColumns: DEFAULT_CONFIG.maxColumns,
        syncSubtitle: DEFAULT_CONFIG.syncSubtitle,
        folders: [],
        items: [],
        legacyGames: []
    }
    var currentFolder = null
    var lines = String(text || "").split(/\r?\n/)

    for (var i = 0; i < lines.length; ++i) {
        var line = trim(lines[i])

        if (!line || line.charAt(0) === "#")
            continue

        var separator = line.indexOf("=")

        if (separator < 0) {
            console.log("Games Menu " + label + " skipped line " + (i + 1) + ": missing =")
            continue
        }

        var key = trim(line.slice(0, separator)).toLowerCase()
        var value = stripGeneratedFolderHint(trim(line.slice(separator + 1)))

        if (key === "configversion") {
            source.configVersion = parseInt(value, 10)
        } else if (key === "shortcutsdir") {
            source.shortcutsDir = value
        } else if (key === "starthidden") {
            source.startHidden = parseBool(value)
        } else if (key === "maxcolumns") {
            source.maxColumns = parseInt(value, 10)
        } else if (key === "syncsubtitle") {
            source.syncSubtitle = parseBool(value)
        } else if (key === "folder") {
            currentFolder = parseTextFolder(value)

            if (currentFolder)
                source.folders.push(currentFolder)
            else
                console.log("Games Menu " + label + " skipped folder line " + (i + 1))
        } else if (key === "item") {
            var item = parseTextItem(value, source.configVersion)

            if (item)
                source.items.push(item)
            else
                console.log("Games Menu " + label + " skipped item line " + (i + 1))
        } else if (key === "game") {
            if (currentFolder && source.configVersion >= 2) {
                addFolderGame(currentFolder, value, source.configVersion, label, i + 1)
            } else {
                var legacyGame = parseTextGame(value)

                if (legacyGame)
                    source.legacyGames.push(legacyGame)
                else
                    console.log("Games Menu " + label + " skipped game line " + (i + 1))
            }
        } else {
            console.log("Games Menu " + label + " skipped unknown key: " + key)
        }
    }

    return source
}

function stripGeneratedFolderHint(value) {
    return String(value || "").replace(/\s+#\s*IN\s*:\s*.*$/i, "")
}

function parseTextFolder(value) {
    var parts = String(value || "").split("|")
    var id = normalizeFolderId(parts.length > 0 ? parts[0] : "")
    var displayParts = parts.length > 1 ? parts.slice(1) : []
    var maxColumns = 0

    if (displayParts.length > 1) {
        var lastPart = normalizeString(displayParts[displayParts.length - 1], "")
        var parsedMaxColumns = parseInt(lastPart, 10)

        if (!isNaN(parsedMaxColumns) && parsedMaxColumns > 0 && String(parsedMaxColumns) === lastPart) {
            maxColumns = parsedMaxColumns
            displayParts = displayParts.slice(0, displayParts.length - 1)
        }
    }

    var displayName = normalizeString(displayParts.join("|"), "")

    if (!id)
        return null

    if (!displayName)
        displayName = id.toUpperCase()

    return {
        id: id,
        displayName: displayName,
        maxColumns: maxColumns,
        games: []
    }
}

function parseTextItem(value, configVersion) {
    var parts = String(value || "").split("|")

    if (configVersion >= 3) {
        var id = normalizeNumericId(parts.length > 0 ? parts[0] : "")
        var title = normalizeString(parts.length > 1 ? parts[1] : "", "")

        if (!id || !title)
            return null

        return {
            id: id,
            title: title,
            description: normalizeItemSubtitle(parts.length > 2 ? parts.slice(2).join("|") : "")
        }
    }

    var baseName = normalizeString(parts.length > 0 ? parts[0] : "", "")

    if (!baseName)
        return null

    return {
        baseName: baseName,
        description: normalizeString(parts.length > 1 ? parts.slice(1).join("|") : "", "")
    }
}

function addFolderGame(folder, value, configVersion, label, lineNumber) {
    var folderGame = parseTextFolderGame(value, configVersion)

    if (!folderGame) {
        console.log("Games Menu " + label + " skipped folder game line " + lineNumber)
        return
    }

    folder.games.push(folderGame)
}

function parseTextFolderGame(value, configVersion) {
    var parts = String(value || "").split("|")

    if (configVersion >= 3) {
        var id = normalizeNumericId(parts.length > 0 ? parts[0] : "")

        if (!id)
            return null

        return {
            id: id,
            subtitle: normalizeString(parts.length > 1 ? parts.slice(1).join("|") : "", "")
        }
    }

    var baseName = normalizeString(parts.length > 0 ? parts[0] : "", "")

    if (!baseName)
        return null

    return {
        baseName: baseName,
        subtitle: normalizeString(parts.length > 1 ? parts.slice(1).join("|") : "", "")
    }
}

function parseTextGame(value) {
    var parts = String(value || "").split("|")

    if (parts.length < 3)
        return null

    var game = {
        title: trim(parts[0]),
        shortcut: trim(parts[1]),
        image: trim(parts[2]),
        description: parts.length > 3 ? trim(parts[3]) : "",
        accent: parts.length > 4 ? trim(parts[4]) : "",
        id: parts.length > 5 ? trim(parts[5]) : ""
    }

    if (!game.title || !game.shortcut || !game.image)
        return null

    return game
}

function parseBool(value) {
    var normalized = trim(value).toLowerCase()

    return normalized === "true" || normalized === "1" || normalized === "yes" || normalized === "on"
}

function normalizeBool(value, fallback) {
    if (value === undefined || value === null)
        return fallback

    if (value === true || value === false)
        return value

    return parseBool(value)
}

function loadLegacyGames() {
    includeOptional("../games.local.js", "games.local.js")
}

function includeOptional(path, label) {
    try {
        var result = Qt.include(path)

        if (result && result.exception) {
            console.log("Games Menu " + label + " error: " + result.exception)
            return false
        }

        if (result && result.status !== undefined && result.status !== 0)
            return false

        return true
    } catch (error) {
        console.log("Games Menu " + label + " error: " + error)
    }

    return false
}

function normalizeConfig(source, localGames) {
    if (!source || typeof source !== "object")
        source = {}

    var usedIds = {}
    var legacyGames = normalizeGames(source.legacyGames || source.games, usedIds)
    var addedGames = normalizeGames(localGames, usedIds)

    for (var i = 0; i < addedGames.length; ++i)
        legacyGames.push(addedGames[i])

    var configVersion = normalizeInt(source.configVersion, DEFAULT_CONFIG.configVersion, 1, 3)
    var folders = normalizeFolders(source.folders, configVersion)
    var itemMetadata = normalizeItemMetadata(source.items)
    var syncSubtitle = normalizeBool(source.syncSubtitle, DEFAULT_CONFIG.syncSubtitle)

    return {
        configVersion: configVersion,
        shortcutsDir: normalizeString(source.shortcutsDir, DEFAULT_CONFIG.shortcutsDir),
        startHidden: source.startHidden === true,
        maxColumns: normalizeInt(source.maxColumns, DEFAULT_CONFIG.maxColumns, 1, 8),
        syncSubtitle: syncSubtitle,
        folders: folders,
        itemMetadata: itemMetadata,
        subtitleModel: buildSubtitleModel(itemMetadata, folders, syncSubtitle),
        legacyGames: legacyGames
    }
}

function normalizeFolders(folders, configVersion) {
    var result = []
    var usedIds = {}

    if (!folders || typeof folders.length !== "number")
        return result

    for (var i = 0; i < folders.length; ++i) {
        var folder = folders[i]

        if (!folder || typeof folder !== "object")
            continue

        var id = normalizeFolderId(folder.id)

        if (!id || id === "all")
            continue

        id = uniqueId(id, usedIds)

        result.push({
            id: id,
            displayName: normalizeString(folder.displayName || folder.title || folder.name, id.toUpperCase()),
            maxColumns: normalizeOptionalMaxColumns(folder.maxColumns),
            icon: "folder-icons/" + id + ".png",
            fallbackIcon: "folder-icons/default.png",
            games: normalizeFolderGames(folder.games, configVersion)
        })
    }

    return result
}

function normalizeFolderGames(games, configVersion) {
    var result = []

    if (!games || typeof games.length !== "number")
        return result

    for (var i = 0; i < games.length; ++i) {
        var source = games[i]
        var folderGame = null

        if (typeof source === "string") {
            folderGame = parseTextFolderGame(source, configVersion)
        } else if (source && typeof source === "object") {
            if (source.id !== undefined && source.id !== null) {
                folderGame = {
                    id: normalizeNumericId(source.id),
                    subtitle: normalizeString(source.subtitle || source.description, "")
                }
            } else {
                folderGame = {
                    baseName: normalizeString(source.baseName || source.title, ""),
                    subtitle: normalizeString(source.subtitle || source.description, "")
                }
            }
        }

        if (!folderGame || (!folderGame.id && !folderGame.baseName))
            continue

        if (folderGame.id) {
            result.push({
                id: folderGame.id,
                subtitle: folderGame.subtitle,
                hasSubtitle: folderGame.subtitle !== ""
            })
        } else {
            result.push({
                baseName: folderGame.baseName,
                baseKey: lookupKey(folderGame.baseName),
                subtitle: folderGame.subtitle,
                hasSubtitle: folderGame.subtitle !== ""
            })
        }
    }

    return result
}

function normalizeItemMetadata(items) {
    var result = {}

    if (!items || typeof items.length !== "number")
        return result

    for (var i = 0; i < items.length; ++i) {
        var item = items[i]

        if (!item || typeof item !== "object")
            continue

        var id = normalizeNumericId(item.id)

        if (id) {
            if (result[id])
                console.log("Games Menu duplicate item metadata for ID " + id + ": last entry wins")

            result[id] = {
                id: id,
                title: normalizeString(item.title || item.name, "GAME " + id),
                subtitle: normalizeString(item.description || item.subtitle, "")
            }
            continue
        }

        var baseName = normalizeString(item.baseName || item.title, "")
        var baseKey = lookupKey(baseName)

        if (!baseKey)
            continue

        result[baseKey] = {
            baseName: baseName,
            title: baseName,
            subtitle: normalizeString(item.description || item.subtitle, "")
        }
    }

    return result
}

function buildSubtitleModel(itemMetadata, folders, syncSubtitle) {
    var result = {}
    var key

    if (itemMetadata) {
        for (key in itemMetadata) {
            if (!itemMetadata.hasOwnProperty(key))
                continue

            var item = itemMetadata[key]
            var itemState = ensureSubtitleState(result, key, item && (item.id || item.baseName))
            var itemSubtitle = normalizeString(item && item.subtitle, "")

            if (!itemState)
                continue

            itemState.globalSubtitle = itemSubtitle

            if (itemSubtitle)
                itemState.explicitValues[itemSubtitle] = true
        }
    }

    for (var folderIndex = 0; folders && folderIndex < folders.length; ++folderIndex) {
        var folder = folders[folderIndex]

        for (var gameIndex = 0; folder && folder.games && gameIndex < folder.games.length; ++gameIndex) {
            var folderGame = folder.games[gameIndex]
            var folderKey = folderGame && folderGame.id ? normalizeNumericId(folderGame.id) : lookupKey(folderGame && folderGame.baseName)
            var folderState = ensureSubtitleState(result, folderKey, folderGame && (folderGame.id || folderGame.baseName))
            var folderSubtitle = normalizeString(folderGame && folderGame.subtitle, "")

            if (!folderState)
                continue

            if (folderSubtitle)
                folderState.explicitValues[folderSubtitle] = true
        }
    }

    for (key in result) {
        if (!result.hasOwnProperty(key))
            continue

        var state = result[key]
        var values = sortedObjectKeys(state.explicitValues)

        state.syncSubtitle = syncSubtitle === true
        state.conflicting = values.length > 1
        state.syncedSubtitle = values.length === 1 ? values[0] : ""
    }

    return result
}

function ensureSubtitleState(states, baseKey, baseName) {
    var key = normalizeNumericId(baseKey)

    if (!key)
        key = lookupKey(baseKey)

    if (!key)
        return null

    if (!states[key]) {
        states[key] = {
            baseName: normalizeString(baseName, ""),
            id: normalizeNumericId(baseName),
            globalSubtitle: "",
            explicitValues: {},
            syncedSubtitle: "",
            conflicting: false,
            syncSubtitle: true
        }
    }

    if (!states[key].baseName)
        states[key].baseName = normalizeString(baseName, "")

    return states[key]
}

function sortedObjectKeys(object) {
    var result = []

    for (var key in object) {
        if (object.hasOwnProperty(key))
            result.push(key)
    }

    result.sort()
    return result
}

function resolvedSubtitleForGame(game, folderGame, subtitleModel, syncSubtitle) {
    if (!game || game.sourceKind !== "shortcut")
        return normalizeString(game && game.subtitle, "")

    var idKey = normalizeNumericId(game.id)
    var state = subtitleModel && subtitleModel[idKey] ? subtitleModel[idKey] : null
    var globalSubtitle = normalizeString(state && state.globalSubtitle, "")
    var folderSubtitle = normalizeString(folderGame && folderGame.subtitle, "")

    if (syncSubtitle !== true) {
        if (folderGame)
            return folderSubtitle

        return globalSubtitle
    }

    if (state && !state.conflicting && state.syncedSubtitle)
        return state.syncedSubtitle

    if (folderGame) {
        if (folderSubtitle)
            return folderSubtitle

        return globalSubtitle
    }

    return globalSubtitle
}

function withResolvedSubtitle(game, folderGame, subtitleModel, syncSubtitle) {
    if (!game)
        return game

    var subtitle = resolvedSubtitleForGame(game, folderGame, subtitleModel, syncSubtitle)

    if (normalizeString(game.subtitle, "") === subtitle)
        return game

    var result = {}

    for (var key in game) {
        if (game.hasOwnProperty(key))
            result[key] = game[key]
    }

    result.subtitle = subtitle
    return result
}

function normalizeGames(games, usedIds) {
    var result = []

    if (!usedIds)
        usedIds = {}

    if (!games || typeof games.length !== "number")
        return result

    for (var i = 0; i < games.length; ++i) {
        var game = games[i]

        if (!game || typeof game !== "object")
            continue

        var title = normalizeString(game.title, "")

        if (!title)
            title = "GAME " + (result.length + 1)

        var rawId = normalizeString(game.id, "")

        if (!rawId)
            rawId = title

        var id = uniqueId(slugify(rawId, result.length + 1), usedIds)
        var image = normalizeString(game.image, "assets/placeholder.png")

        if (!hasKnownPathPrefix(image))
            image = userAssetImagePath(image)

        result.push({
            id: id,
            title: title,
            subtitle: normalizeDescription(game),
            shortcut: normalizeString(game.shortcut, ""),
            image: image,
            accent: normalizeAccent(game.accent),
            baseName: title,
            baseKey: lookupKey(title),
            sourceKind: "legacy"
        })
    }

    return result
}

function normalizeString(value, fallback) {
    if (value === undefined || value === null)
        return fallback

    return trim(String(value))
}

function trim(value) {
    return String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
}

function normalizeInt(value, fallback, min, max) {
    var number = parseInt(value, 10)

    if (isNaN(number))
        return fallback

    return Math.max(min, Math.min(max, number))
}

function normalizeOptionalMaxColumns(value) {
    var number = parseInt(value, 10)

    if (isNaN(number) || number < 1)
        return 0

    return Math.max(1, Math.min(8, number))
}

function normalizeNumericId(value) {
    var text = normalizeString(value, "")

    if (!/^[0-9]+$/.test(text))
        return ""

    var number = parseInt(text, 10)

    if (isNaN(number) || number < 1)
        return ""

    return "" + number
}

function normalizeAccent(value) {
    var accent = normalizeString(value, "")

    if (/^#[0-9a-fA-F]{6}$/.test(accent) || /^#[0-9a-fA-F]{8}$/.test(accent))
        return accent

    return "#DDF7FF"
}

function normalizeDescription(options) {
    var subtitle = normalizeString(options && options.subtitle, "")

    if (subtitle)
        return subtitle

    return normalizeString(options && options.description, "")
}

function normalizeItemSubtitle(value) {
    var subtitle = normalizeString(value, "")

    if (subtitle === "Game Subtitle")
        return ""

    return subtitle
}

function userAssetImagePath(image) {
    var value = normalizeString(image, "")

    if (!value)
        return "assets/placeholder.png"

    if (hasKnownPathPrefix(value))
        return value

    return "user-assets/" + value
}

function hasKnownPathPrefix(path) {
    return /^[A-Za-z]:[\/\\]/.test(path)
            || path.indexOf("/") === 0
            || path.indexOf("\\\\") === 0
            || path.indexOf("../") === 0
            || path.indexOf("assets/") === 0
            || path.indexOf("user-assets/") === 0
            || path.indexOf("folder-icons/") === 0
            || path.indexOf("file:") === 0
            || path.indexOf("qrc:") === 0
            || path.indexOf("http://") === 0
            || path.indexOf("https://") === 0
}

function normalizeFolderId(value) {
    var id = normalizeString(value, "").toLowerCase()

    id = id.replace(/[^a-z0-9_-]+/g, "-")
    id = id.replace(/^-+|-+$/g, "")

    return id
}

function lookupKey(value) {
    return normalizeString(value, "").toLowerCase()
}

function slugify(value, index) {
    var slug = normalizeString(value, "").toLowerCase()

    slug = slug.replace(/[^a-z0-9]+/g, "-")
    slug = slug.replace(/^-+|-+$/g, "")

    if (!slug)
        slug = "item-" + index

    return slug
}

function uniqueId(id, usedIds) {
    var base = id
    var next = id
    var counter = 2

    while (usedIds[next]) {
        next = base + "-" + counter
        counter += 1
    }

    usedIds[next] = true
    return next
}
