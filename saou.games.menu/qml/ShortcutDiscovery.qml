import QtQuick 2.12
import NERvGear 1.0 as NVG
import "ConfigLoader.js" as ConfigLoader

Item {
    id: discovery

    property string shortcutsDir: ""
    property var items: []
    property var cardData: ({})
    property var folderOverrides: ({})
    property url defaultFolderUrl: Qt.resolvedUrl("../shortcuts")
    property url packageRootUrl: Qt.resolvedUrl("..")
    property url helperScriptUrl: Qt.resolvedUrl("../tools/discover-shortcuts.ps1")
    property url updateScriptUrl: Qt.resolvedUrl("../tools/update-config-items.ps1")
    property url hiddenLauncherUrl: Qt.resolvedUrl("../tools/run-hidden.vbs")
    property url outputFileUrl: Qt.resolvedUrl("../runtime/discovery.json")
    property url updateOutputFileUrl: Qt.resolvedUrl("../runtime/config-update.json")
    property url cardDataOutputFileUrl: Qt.resolvedUrl("../runtime/card-data-update.json")
    property url configFileUrl: Qt.resolvedUrl("../config.txt")
    property url stateFileUrl: Qt.resolvedUrl("../state/items.json")
    property string effectiveShortcutPath: effectiveShortcutDirectoryPath()
    property bool refreshing: false
    property bool cardDataUpdating: false
    property int refreshSerial: 0
    property int activeRequestId: 0
    property int readAttempts: 0
    property int cardDataReadAttempts: 0
    property int maxReadAttempts: 12
    property int cardDataUpdateSerial: 0
    property int activeCardDataRequestId: 0
    property string activeCardDataCardId: ""
    property var lastDiscoveryResult: null
    property string refreshPhase: ""

    signal refreshSucceeded(var result)
    signal cardDataUpdated(string cardId, var data)
    signal cardDataUpdateFinished(string cardId, bool success, string error)
    signal manualCardPrepared(var draft, string error)

    function fileUrlToPath(url) {
        var value = String(url || "")

        if (value.indexOf("file:///") === 0)
            return decodeURIComponent(value.slice(8)).replace(/\//g, "\\")

        if (value.indexOf("file://") === 0)
            return "\\\\" + decodeURIComponent(value.slice(7)).replace(/\//g, "\\")

        return decodeURIComponent(value)
    }

    function pathFromConfig(path) {
        var value = ConfigLoader.normalizeString(path, "")

        if (!value)
            return ""

        if (value.indexOf("file:") === 0)
            return fileUrlToPath(value)

        return value
    }

    function effectiveShortcutDirectoryPath() {
        var external = pathFromConfig(shortcutsDir)

        if (external)
            return external

        return fileUrlToPath(defaultFolderUrl)
    }

    function quoteArgument(value) {
        return "\"" + String(value || "").replace(/"/g, "\\\"") + "\""
    }

    function quotedArguments(values) {
        var result = []

        for (var i = 0; values && i < values.length; ++i)
            result.push(quoteArgument(values[i]))

        return result.join(" ")
    }

    function hasOwn(object, name) {
        return object && Object.prototype.hasOwnProperty.call(object, name)
    }

    function normalizeCardId(cardId) {
        return ConfigLoader.normalizeString(cardId, "")
    }

    function normalizeFolderOrderKey(folderId) {
        return ConfigLoader.normalizeString(folderId, "").toLowerCase()
    }

    function normalizeAdditionalFolderIds(source) {
        var result = []
        var seen = {}

        if (typeof source === "string")
            source = [source]

        for (var i = 0; source && i < source.length; ++i) {
            var folderId = normalizeFolderOrderKey(source[i])
            if (folderId && folderId !== "all" && !seen[folderId]) {
                seen[folderId] = true
                result.push(folderId)
            }
        }

        return result
    }

    function normalizeFolderOrders(source) {
        var result = {}

        if (!source || typeof source !== "object")
            return result

        for (var key in source) {
            if (!hasOwn(source, key))
                continue

            var normalizedKey = normalizeFolderOrderKey(key)
            var order = parseInt(source[key], 10)

            if (normalizedKey && !isNaN(order) && order >= 0)
                result[normalizedKey] = order
        }

        return result
    }

    function normalizeCardData(source) {
        var result = {
            customTitle: "",
            description: "",
            customImage: "",
            folderId: "",
            additionalFolderIds: [],
            excludedFolderIds: [],
            order: 0,
            hasOrder: false,
            folderOrders: {},
            isHidden: false,
            sourcePath: "",
            targetPath: "",
            launchPath: "",
            sourceType: "",
            automaticTitle: ""
        }

        if (!source || typeof source !== "object")
            return result

        result.customTitle = ConfigLoader.normalizeString(source.customTitle, "")
        result.description = ConfigLoader.normalizeString(source.description, "")
        result.customImage = ConfigLoader.normalizeString(source.customImage, "")
        result.folderId = ConfigLoader.normalizeString(source.folderId, "")
        result.additionalFolderIds = normalizeAdditionalFolderIds(source.additionalFolderIds)
        result.excludedFolderIds = normalizeAdditionalFolderIds(source.excludedFolderIds)
        result.folderOrders = normalizeFolderOrders(source.folderOrders)
        result.isHidden = source.isHidden === true || String(source.isHidden || "").toLowerCase() === "true"
        result.sourcePath = ConfigLoader.normalizeString(source.sourcePath, "")
        result.targetPath = ConfigLoader.normalizeString(source.targetPath, "")
        result.launchPath = ConfigLoader.normalizeString(source.launchPath, "")
        result.sourceType = ConfigLoader.lookupKey(source.sourceType)
        result.automaticTitle = ConfigLoader.normalizeString(source.automaticTitle, "")

        if (hasOwn(source, "order")) {
            var order = parseInt(source.order, 10)

            if (!isNaN(order) && order >= 0) {
                result.order = order
                result.hasOrder = true
            }
        }

        return result
    }

    function normalizedCardDataForStore(source) {
        var normalized = normalizeCardData(source)
        var result = {}

        if (normalized.customTitle)
            result.customTitle = normalized.customTitle

        if (normalized.description)
            result.description = normalized.description

        if (normalized.customImage)
            result.customImage = normalized.customImage

        if (normalized.folderId)
            result.folderId = normalized.folderId

        if (normalized.additionalFolderIds.length)
            result.additionalFolderIds = normalized.additionalFolderIds

        if (normalized.excludedFolderIds.length)
            result.excludedFolderIds = normalized.excludedFolderIds

        if (normalized.hasOrder)
            result.order = normalized.order

        var hasFolderOrders = false
        var folderOrders = normalizeFolderOrders(source && source.folderOrders)
        for (var folderId in folderOrders) {
            if (hasOwn(folderOrders, folderId)) {
                if (!hasFolderOrders) {
                    result.folderOrders = {}
                    hasFolderOrders = true
                }
                result.folderOrders[folderId] = folderOrders[folderId]
            }
        }

        if (normalized.isHidden)
            result.isHidden = true

        for (var manualFieldIndex = 0; manualFieldIndex < ["sourcePath", "targetPath", "launchPath", "sourceType", "automaticTitle"].length; ++manualFieldIndex) {
            var manualField = ["sourcePath", "targetPath", "launchPath", "sourceType", "automaticTitle"][manualFieldIndex]
            var manualValue = ConfigLoader.normalizeString(source && source[manualField], "")

            if (manualValue)
                result[manualField] = manualValue
        }

        var customImageSource = ConfigLoader.normalizeString(source && source.customImageSource, "")

        if (customImageSource)
            result.customImageSource = customImageSource

        return result
    }

    function getCardUserData(cardId) {
        var key = normalizeCardId(cardId)
        var result = normalizeCardData(key && cardData ? cardData[key] : null)

        result.cardId = key
        return result
    }

    function applyCardData(source) {
        cardData = source && typeof source === "object" ? source : ({})

        // Reassign so dependent QML bindings refresh after an editor save.
        if (items && typeof items.length === "number")
            items = items.slice(0)
    }

    function applyFolderOverrides(source) {
        folderOverrides = source && typeof source === "object" ? source : ({})
    }

    function encodedDiscoveryItems(items) {
        var result = []

        for (var i = 0; items && i < items.length; ++i) {
            var baseName = ConfigLoader.normalizeString(items[i] && items[i].baseName, "")
            var launchKey = ConfigLoader.normalizeString(items[i] && items[i].launchKey, "")

            if (!baseName || !launchKey)
                continue

            result.push(encodeURIComponent(baseName)
                        + "," + encodeURIComponent(launchKey)
                        + "," + encodeURIComponent(ConfigLoader.normalizeString(items[i] && items[i].filePath, ""))
                        + "," + encodeURIComponent(ConfigLoader.lookupKey(items[i] && items[i].extension)))
        }

        return result.join("|")
    }

    function extensionPriority(extension) {
        var normalized = ConfigLoader.lookupKey(extension)

        if (normalized === "lnk")
            return 0

        if (normalized === "url")
            return 1

        return 2
    }

    function compareEntries(left, right) {
        var leftBase = ConfigLoader.lookupKey(left.baseName)
        var rightBase = ConfigLoader.lookupKey(right.baseName)

        if (leftBase < rightBase)
            return -1

        if (leftBase > rightBase)
            return 1

        var leftPriority = extensionPriority(left.extension)
        var rightPriority = extensionPriority(right.extension)

        if (leftPriority !== rightPriority)
            return leftPriority - rightPriority

        var leftName = ConfigLoader.lookupKey(left.fileName)
        var rightName = ConfigLoader.lookupKey(right.fileName)

        if (leftName < rightName)
            return -1

        if (leftName > rightName)
            return 1

        return 0
    }

    function identityLookup(identityItems) {
        var result = {}

        for (var i = 0; identityItems && i < identityItems.length; ++i) {
            var item = identityItems[i]
            var launchKey = ConfigLoader.normalizeString(item && item.launchKey, "")
            var id = parseInt(item && item.id, 10)

            if (launchKey && !isNaN(id)) {
                result[launchKey] = {
                    id: id,
                    title: ConfigLoader.normalizeString(item && item.title, ""),
                    baseName: ConfigLoader.normalizeString(item && item.baseName, ""),
                    fileName: ConfigLoader.normalizeString(item && item.fileName, ""),
                    filePath: ConfigLoader.normalizeString(item && item.filePath, "")
                }
            }
        }

        return result
    }

    function normalizeDiscoveredItems(sourceItems, identityItems) {
        var rawItems = []
        var duplicateCounts = {}
        var identities = identityLookup(identityItems)

        for (var i = 0; sourceItems && i < sourceItems.length; ++i) {
            var source = sourceItems[i]
            var fileName = ConfigLoader.normalizeString(source && source.fileName, "")
            var filePath = ConfigLoader.normalizeString(source && source.filePath, "")
            var baseName = ConfigLoader.normalizeString(source && source.baseName, "")
            var extension = ConfigLoader.lookupKey(source && source.extension)
            var launchKey = ConfigLoader.normalizeString(source && source.launchKey, "")
            var identity = identities[launchKey]
            var identityId = identity && identity.id
            var resolvedBaseName = ConfigLoader.normalizeString(identity && identity.baseName, baseName)
            var resolvedTitle = ConfigLoader.normalizeString(identity && identity.title, resolvedBaseName)
            var resolvedFileName = ConfigLoader.normalizeString(identity && identity.fileName, fileName)
            var resolvedFilePath = ConfigLoader.normalizeString(identity && identity.filePath, filePath)

            if (!fileName || !filePath || !baseName || !launchKey || !identityId)
                continue

            if (extension !== "lnk" && extension !== "url")
                continue

            var baseKey = ConfigLoader.lookupKey(resolvedBaseName)

            if (!duplicateCounts[baseKey])
                duplicateCounts[baseKey] = 0

            duplicateCounts[baseKey] += 1

            rawItems.push({
                fileName: resolvedFileName,
                filePath: resolvedFilePath,
                baseName: resolvedBaseName,
                title: resolvedTitle,
                baseKey: baseKey,
                extension: extension,
                launchKey: launchKey,
                launchTarget: ConfigLoader.normalizeString(source && source.launchTarget, ""),
                launchArguments: ConfigLoader.normalizeString(source && source.launchArguments, ""),
                workingDirectory: ConfigLoader.normalizeString(source && source.workingDirectory, ""),
                identityId: identityId
            })
        }

        rawItems.sort(compareEntries)

        var result = []
        var warned = {}

        for (var itemIndex = 0; itemIndex < rawItems.length; ++itemIndex) {
            var entry = rawItems[itemIndex]
            var duplicateBase = duplicateCounts[entry.baseKey] > 1

            if (duplicateBase && !warned[entry.baseKey]) {
                console.log("Games Menu duplicate shortcut basename: " + entry.baseName + " (.lnk is preferred for folder membership)")
                warned[entry.baseKey] = true
            }

            result.push({
                id: entry.identityId,
                title: entry.title,
                subtitle: "",
                shortcut: entry.filePath,
                image: "user-assets/" + entry.baseName + ".png",
                imageReloadKey: "" + refreshSerial,
                accent: "#DDF7FF",
                baseName: entry.baseName,
                baseKey: entry.baseKey,
                extension: entry.extension,
                fileName: entry.fileName,
                filePath: entry.filePath,
                launchKey: entry.launchKey,
                launchTarget: entry.launchTarget,
                launchArguments: entry.launchArguments,
                workingDirectory: entry.workingDirectory,
                sourceKind: "shortcut",
                duplicateBase: duplicateBase
            })
        }

        return result
    }

    function readJsonFile(url) {
        var request = new XMLHttpRequest()

        try {
            request.open("GET", url, false)
            request.send()
        } catch (error) {
            return null
        }

        if (!((request.status === 0 && request.responseText !== "") || (request.status >= 200 && request.status < 300)))
            return null

        try {
            return JSON.parse(request.responseText)
        } catch (error) {
            console.log("Games Menu JSON result parse failed: " + error)
        }

        return null
    }

    function readDiscoveryOutputFile() {
        var data = readJsonFile(outputFileUrl)

        if (!data)
            return false

        if (data.requestId !== activeRequestId)
            return false

        if (data.error)
            console.log("Games Menu discovery helper failed: " + data.error)

        lastDiscoveryResult = data
        return true
    }

    function readConfigUpdateFile() {
        var data = readJsonFile(updateOutputFileUrl)

        if (!data)
            return null

        if (data.requestId !== activeRequestId)
            return null

        return data
    }

    function readCardDataUpdateFile() {
        var data = readJsonFile(cardDataOutputFileUrl)

        if (!data)
            return null

        if (data.requestId !== activeCardDataRequestId)
            return null

        return data
    }

    function finishRefresh(result) {
        readResultDelay.stop()
        configUpdateDelay.stop()
        refreshing = false
        refreshPhase = ""

        if (result)
            refreshSucceeded(result)
    }

    function finishCardDataUpdate(cardId, data, error) {
        cardDataUpdateDelay.stop()
        cardDataUpdating = false

        if (data)
            cardDataUpdated(cardId, getCardUserData(cardId))

        cardDataUpdateFinished(cardId, !!data, error || "")
        activeCardDataCardId = ""
    }

    function tryReadDiscoveryOutput() {
        if (readDiscoveryOutputFile()) {
            readResultDelay.stop()
            startConfigUpdate(lastDiscoveryResult)
            return
        }

        readAttempts += 1

        if (readAttempts >= maxReadAttempts) {
            console.log("Games Menu discovery result was not ready")
            finishRefresh({
                requestId: activeRequestId,
                configChanged: false,
                configAddedItems: [],
                configUpdateError: "Discovery result timeout"
            })
        }
    }

    function tryReadConfigUpdate() {
        var data = readConfigUpdateFile()

        if (data) {
            if (data.configUpdateError)
                console.log("Games Menu config item update failed: " + data.configUpdateError)

            if (data.cardData !== undefined && data.cardData !== null)
                applyCardData(data.cardData)
            if (data.folderOverrides !== undefined && data.folderOverrides !== null)
                applyFolderOverrides(data.folderOverrides)
            items = normalizeDiscoveredItems(lastDiscoveryResult && lastDiscoveryResult.items, data.items)
            finishRefresh(data)
            return
        }

        readAttempts += 1

        if (readAttempts >= maxReadAttempts) {
            console.log("Games Menu config item update result was not ready")
            finishRefresh({
                requestId: activeRequestId,
                configChanged: false,
                configAddedItems: [],
                configUpdateError: "Config item update timeout"
            })
        }
    }

    function startConfigUpdate(discoveryResult) {
        var encodedItems = encodedDiscoveryItems(discoveryResult && discoveryResult.items)

        refreshPhase = "config"
        readAttempts = 0

        var hiddenLauncher = "C:\\Windows\\System32\\wscript.exe"
        var powerShell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
        var args = quotedArguments([
            fileUrlToPath(hiddenLauncherUrl),
            powerShell,
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-WindowStyle",
            "Hidden",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            fileUrlToPath(updateScriptUrl),
            "-ConfigPath",
            fileUrlToPath(configFileUrl),
            "-StatePath",
            fileUrlToPath(stateFileUrl),
            "-UpdateOutputPath",
            fileUrlToPath(updateOutputFileUrl),
            "-UpdateRequestId",
            "" + activeRequestId,
            "-ItemsEncoded",
            encodedItems
        ])

        try {
            NVG.SystemCall.execute(hiddenLauncher, args)
        } catch (error) {
            console.log("Games Menu config item update launch failed: " + error)
            items = []
            finishRefresh({
                requestId: activeRequestId,
                configChanged: false,
                configAddedItems: [],
                configUpdateError: "" + error
            })
            return
        }

        configUpdateDelay.restart()
    }

    function startCardDataUpdate(operation, cardId, data) {
        if (refreshing || cardDataUpdating) {
            console.log("Games Menu card data update is already blocked by another operation")
            return false
        }

        var key = normalizeCardId(cardId)

        if (!key) {
            console.log("Games Menu card data update skipped: missing card ID")
            return false
        }

        cardDataUpdating = true
        cardDataUpdateSerial += 1
        activeCardDataRequestId = cardDataUpdateSerial
        activeCardDataCardId = key
        cardDataReadAttempts = 0

        var encodedCardData = ""
        if (operation !== "remove-card-data") {
            var dataForStore = operation === "update-card-orders" || operation === "move-card" || operation === "copy-card-to-folder"
                    || operation === "update-folder-overrides" || operation === "save-widget-settings" || operation === "create-folder" || operation === "remove-folder" ? data : normalizedCardDataForStore(data)
            encodedCardData = encodeURIComponent(JSON.stringify(dataForStore))
        }

        var hiddenLauncher = "C:\\Windows\\System32\\wscript.exe"
        var powerShell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
        var args = quotedArguments([
            fileUrlToPath(hiddenLauncherUrl),
            powerShell,
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-WindowStyle",
            "Hidden",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            fileUrlToPath(updateScriptUrl),
            "-ConfigPath",
            fileUrlToPath(configFileUrl),
            "-StatePath",
            fileUrlToPath(stateFileUrl),
            "-UpdateOutputPath",
            fileUrlToPath(cardDataOutputFileUrl),
            "-UpdateRequestId",
            "" + activeCardDataRequestId,
            "-Operation",
            operation,
            "-CardId",
            key,
            "-CardDataEncoded",
            encodedCardData
        ])

        try {
            NVG.SystemCall.execute(hiddenLauncher, args)
        } catch (error) {
            console.log("Games Menu card data update launch failed: " + error)
            finishCardDataUpdate(key, null, "" + error)
            return false
        }

        cardDataUpdateDelay.restart()
        return true
    }

    function updateCardUserData(cardId, data) {
        return startCardDataUpdate("update-card-data", cardId, data)
    }

    function removeCardUserOverride(cardId) {
        return startCardDataUpdate("remove-card-data", cardId, null)
    }

    function prepareManualCard(data) {
        return startCardDataUpdate("prepare-manual-card", "draft", data)
    }

    function createManualCard(cardId, data) {
        return startCardDataUpdate("create-manual-card", cardId, data)
    }

    function updateCardOrders(data) {
        return startCardDataUpdate("update-card-orders", "orders", data)
    }

    function moveCard(cardId, data) {
        return startCardDataUpdate("move-card", cardId, data)
    }

    function copyCardToFolder(cardId, data) {
        return startCardDataUpdate("copy-card-to-folder", cardId, data)
    }

    function updateFolderOverrides(data) {
        return startCardDataUpdate("update-folder-overrides", "folders", data)
    }

    function saveWidgetSettings(data) {
        return startCardDataUpdate("save-widget-settings", "settings", data)
    }

    function createFolder(data) {
        return startCardDataUpdate("create-folder", "folder", data)
    }

    function removeFolder(folderId) {
        return startCardDataUpdate("remove-folder", "folder", { folderId: folderId })
    }

    function tryReadCardDataUpdate() {
        var data = readCardDataUpdateFile()

        if (data) {
            if (data.operation === "prepare-manual-card") {
                cardDataUpdateDelay.stop()
                cardDataUpdating = false
                activeCardDataCardId = ""
                manualCardPrepared(data.manualCardDraft || null, data.cardDataUpdateError || "")
                return
            }

            if (data.cardDataUpdateError)
                console.log("Games Menu card data update failed: " + data.cardDataUpdateError)
            else {
                applyCardData(data.cardData)
                if (data.folderOverrides !== undefined && data.folderOverrides !== null)
                    applyFolderOverrides(data.folderOverrides)
            }

            finishCardDataUpdate(normalizeCardId(data.cardId), data.cardDataUpdateError ? null : data, data.cardDataUpdateError || "")
            return
        }

        cardDataReadAttempts += 1

        if (cardDataReadAttempts >= maxReadAttempts) {
            console.log("Games Menu card data update result was not ready")
            if (activeCardDataCardId === "draft") {
                cardDataUpdateDelay.stop()
                cardDataUpdating = false
                activeCardDataCardId = ""
                manualCardPrepared(null, "Could not prepare new card")
                return
            }
            finishCardDataUpdate(activeCardDataCardId, null, "Card data update timeout")
        }
    }

    function refresh() {
        if (refreshing || cardDataUpdating) {
            console.log("Games Menu discovery refresh is already blocked by another operation")
            return false
        }

        refreshing = true
        refreshSerial += 1
        activeRequestId = refreshSerial
        readAttempts = 0
        refreshPhase = "discovery"

        var hiddenLauncher = "C:\\Windows\\System32\\wscript.exe"
        var powerShell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
        var args = quotedArguments([
            fileUrlToPath(hiddenLauncherUrl),
            powerShell,
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-WindowStyle",
            "Hidden",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            fileUrlToPath(helperScriptUrl),
            "-ShortcutDir",
            effectiveShortcutDirectoryPath(),
            "-DiscoveryOutputPath",
            fileUrlToPath(outputFileUrl),
            "-DiscoveryRequestId",
            "" + activeRequestId
        ])

        try {
            NVG.SystemCall.execute(hiddenLauncher, args)
        } catch (error) {
            console.log("Games Menu discovery launch failed: " + error)
            finishRefresh({
                requestId: activeRequestId,
                configChanged: false,
                configAddedItems: [],
                configUpdateError: "" + error
            })
            return false
        }

        readResultDelay.restart()
        return true
    }

    function openShortcutsFolder() {
        var explorer = "C:\\Windows\\explorer.exe"

        try {
            NVG.SystemCall.execute(explorer, quoteArgument(effectiveShortcutDirectoryPath()))
        } catch (error) {
            console.log("Games Menu shortcuts folder open failed: " + error)
        }
    }

    Timer {
        id: readResultDelay

        interval: 250
        repeat: true
        onTriggered: discovery.tryReadDiscoveryOutput()
    }

    Timer {
        id: configUpdateDelay

        interval: 250
        repeat: true
        onTriggered: discovery.tryReadConfigUpdate()
    }

    function openPackageFolder() {
        var explorer = "C:\\Windows\\explorer.exe"

        try {
            NVG.SystemCall.execute(explorer, quoteArgument(fileUrlToPath(packageRootUrl)))
        } catch (error) {
            console.log("Games Menu package folder open failed: " + error)
        }
    }

    Timer {
        id: cardDataUpdateDelay

        interval: 250
        repeat: true
        onTriggered: discovery.tryReadCardDataUpdate()
    }
}
