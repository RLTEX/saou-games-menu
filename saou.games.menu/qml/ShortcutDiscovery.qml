import QtQuick 2.12
import NERvGear 1.0 as NVG
import "ConfigLoader.js" as ConfigLoader

Item {
    id: discovery

    property string shortcutsDir: ""
    property var items: []
    property url defaultFolderUrl: Qt.resolvedUrl("../shortcuts")
    property url helperScriptUrl: Qt.resolvedUrl("../tools/discover-shortcuts.ps1")
    property url outputFileUrl: Qt.resolvedUrl("../runtime/discovery.json")
    property string effectiveShortcutPath: effectiveShortcutDirectoryPath()
    property int refreshSerial: 0
    property int readAttempts: 0
    property int maxReadAttempts: 12

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

    function shortcutId(entry, index) {
        var id = ConfigLoader.slugify(entry.baseName + "-" + entry.extension, index + 1)

        if (!id)
            id = "shortcut-" + (index + 1)

        return "shortcut-" + id
    }

    function normalizeDiscoveredItems(sourceItems) {
        var rawItems = []
        var duplicateCounts = {}

        for (var i = 0; sourceItems && i < sourceItems.length; ++i) {
            var source = sourceItems[i]
            var fileName = ConfigLoader.normalizeString(source && source.fileName, "")
            var filePath = ConfigLoader.normalizeString(source && source.filePath, "")
            var baseName = ConfigLoader.normalizeString(source && source.baseName, "")
            var extension = ConfigLoader.lookupKey(source && source.extension)

            if (!fileName || !filePath || !baseName)
                continue

            if (extension !== "lnk" && extension !== "url")
                continue

            var baseKey = ConfigLoader.lookupKey(baseName)

            if (!duplicateCounts[baseKey])
                duplicateCounts[baseKey] = 0

            duplicateCounts[baseKey] += 1

            rawItems.push({
                fileName: fileName,
                filePath: filePath,
                baseName: baseName,
                baseKey: baseKey,
                extension: extension
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
                id: shortcutId(entry, itemIndex),
                title: entry.baseName,
                subtitle: entry.extension.toUpperCase() + " SHORTCUT",
                shortcut: entry.filePath,
                image: "user-assets/" + entry.baseName + ".png",
                accent: "#DDF7FF",
                baseName: entry.baseName,
                baseKey: entry.baseKey,
                extension: entry.extension,
                fileName: entry.fileName,
                filePath: entry.filePath,
                sourceKind: "shortcut",
                duplicateBase: duplicateBase
            })
        }

        return result
    }

    function readOutputFile() {
        var request = new XMLHttpRequest()

        try {
            request.open("GET", outputFileUrl, false)
            request.send()
        } catch (error) {
            return false
        }

        if (!((request.status === 0 && request.responseText !== "") || (request.status >= 200 && request.status < 300)))
            return false

        try {
            var data = JSON.parse(request.responseText)

            if (!data || data.requestId !== refreshSerial)
                return false

            items = normalizeDiscoveredItems(data.items)
            return true
        } catch (error) {
            console.log("Games Menu discovery result parse failed: " + error)
        }

        return false
    }

    function tryReadOutput() {
        if (readOutputFile()) {
            readResultDelay.stop()
            return
        }

        readAttempts += 1

        if (readAttempts >= maxReadAttempts) {
            readResultDelay.stop()
            console.log("Games Menu discovery result was not ready")
        }
    }

    function refresh() {
        refreshSerial += 1
        readAttempts = 0

        var powerShell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
        var args = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass"
                + " -File " + quoteArgument(fileUrlToPath(helperScriptUrl))
                + " -ShortcutDir " + quoteArgument(effectiveShortcutDirectoryPath())
                + " -DiscoveryOutputPath " + quoteArgument(fileUrlToPath(outputFileUrl))
                + " -DiscoveryRequestId " + refreshSerial

        try {
            NVG.SystemCall.execute(powerShell, args)
        } catch (error) {
            console.log("Games Menu discovery launch failed: " + error)
            return
        }

        readResultDelay.restart()
    }

    onShortcutsDirChanged: Qt.callLater(refresh)

    Component.onCompleted: refresh()

    Timer {
        id: readResultDelay

        interval: 250
        repeat: true
        onTriggered: discovery.tryReadOutput()
    }
}
