var DEFAULT_CONFIG = {
    configVersion: 2,
    shortcutsDir: "",
    startHidden: false,
    maxColumns: 3,
    folders: [],
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
        folders: [],
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
        var value = trim(line.slice(separator + 1))

        if (key === "configversion") {
            source.configVersion = parseInt(value, 10)
        } else if (key === "shortcutsdir") {
            source.shortcutsDir = value
        } else if (key === "starthidden") {
            source.startHidden = parseBool(value)
        } else if (key === "maxcolumns") {
            source.maxColumns = parseInt(value, 10)
        } else if (key === "folder") {
            currentFolder = parseTextFolder(value)

            if (currentFolder)
                source.folders.push(currentFolder)
            else
                console.log("Games Menu " + label + " skipped folder line " + (i + 1))
        } else if (key === "game") {
            if (currentFolder && value.indexOf("|") < 0) {
                addFolderGame(currentFolder, value, label, i + 1)
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

function parseTextFolder(value) {
    var parts = String(value || "").split("|")
    var id = normalizeFolderId(parts.length > 0 ? parts[0] : "")
    var displayName = normalizeString(parts.length > 1 ? parts.slice(1).join("|") : "", "")

    if (!id)
        return null

    if (!displayName)
        displayName = id.toUpperCase()

    return {
        id: id,
        displayName: displayName,
        games: []
    }
}

function addFolderGame(folder, value, label, lineNumber) {
    var basename = normalizeString(value, "")

    if (!basename) {
        console.log("Games Menu " + label + " skipped folder game line " + lineNumber)
        return
    }

    folder.games.push(basename)
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

    return {
        configVersion: normalizeInt(source.configVersion, DEFAULT_CONFIG.configVersion, 1, 2),
        shortcutsDir: normalizeString(source.shortcutsDir, DEFAULT_CONFIG.shortcutsDir),
        startHidden: source.startHidden === true,
        maxColumns: normalizeInt(source.maxColumns, DEFAULT_CONFIG.maxColumns, 1, 8),
        folders: normalizeFolders(source.folders),
        legacyGames: legacyGames
    }
}

function normalizeFolders(folders) {
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
            icon: "folder-icons/" + id + ".png",
            fallbackIcon: "folder-icons/default.png",
            games: normalizeFolderGames(folder.games)
        })
    }

    return result
}

function normalizeFolderGames(games) {
    var result = []

    if (!games || typeof games.length !== "number")
        return result

    for (var i = 0; i < games.length; ++i) {
        var basename = normalizeString(games[i], "")

        if (basename)
            result.push(basename)
    }

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
