import QtQuick 2.12
import QtQuick.Controls 2.12
import NERvGear 1.0 as NVG
import NERvGear.Dialogs 1.0 as D
import NERvGear.Templates 1.0 as T
import "ConfigLoader.js" as ConfigLoader

T.Widget {
    id: widget

    title: qsTr("Games Menu")
    solid: true
    resizable: true
    implicitWidth: 720
    implicitHeight: 420

    // Visual tuning kept local so users can tweak the widget without touching logic.
    property int cardSpacing: 18
    property real hoverZoom: 1.015
    property int openOffset: 72
    property int openDuration: 230
    property int launchCloseDelay: 520
    property int failureVisibleDuration: 1700
    property int cardMinWidth: 160
    property int cardMaxHeight: 240
    property int sidebarWidth: Math.min(138, Math.max(108, Math.floor(widget.width * 0.24)))

    property var appConfig: ConfigLoader.load()
    property string shortcutsDir: appConfig.shortcutsDir
    property bool startHidden: appConfig.startHidden
    property int maxColumns: appConfig.maxColumns
    property bool syncSubtitle: appConfig.syncSubtitle
    property var configuredFolders: appConfig.folders
    property var subtitleModel: appConfig.subtitleModel
    property var legacyGames: appConfig.legacyGames
    property var discoveredGames: shortcutDiscovery.items
    property string selectedFolderId: "all"
    property var allGames: buildAllGames()
    property var folders: buildFolderList()
    property var activeGames: selectGamesForFolder()

    property bool closing: false
    property bool launching: false
    property bool launchFailed: false
    property bool closeActionAfterAnimation: false
    property bool reloadPending: false
    property bool initialDiscoveryRequested: false
    property bool startupVisibilityApplied: false
    property int startupVisibilityAttempts: 0
    property string launchingTitle: ""

    property int gameCount: activeGames && activeGames.length ? activeGames.length : 0
    property int gridColumns: calculateGridColumns()
    property real cardWidth: calculateCardWidth()
    property real cardHeight: Math.max(118, Math.min(widget.cardMaxHeight, Math.round(widget.cardWidth * 0.62)))

    function calculateGridColumns() {
        var configured = Math.max(1, maxColumnsForSelectedFolder())
        var count = Math.max(1, widget.gameCount)
        var availableWidth = gameFlickable ? gameFlickable.width : 0
        var byWidth = Math.max(1, Math.floor((availableWidth + widget.cardSpacing) / (widget.cardMinWidth + widget.cardSpacing)))

        return Math.max(1, Math.min(configured, count, byWidth))
    }

    function maxColumnsForSelectedFolder() {
        if (widget.selectedFolderId !== "all") {
            var folder = findConfiguredFolder(widget.selectedFolderId)
            var folderMaxColumns = parseInt(folder && folder.maxColumns, 10)

            if (!isNaN(folderMaxColumns) && folderMaxColumns > 0)
                return folderMaxColumns
        }

        return widget.maxColumns
    }

    function calculateCardWidth() {
        var availableWidth = gameFlickable ? gameFlickable.width : 0
        var columns = Math.max(1, widget.gridColumns)
        var spacing = widget.cardSpacing * (columns - 1)

        return Math.max(1, Math.floor((availableWidth - spacing) / columns))
    }

    function reloadConfig() {
        appConfig = ConfigLoader.load()
    }

    function requestManualReload() {
        if (reloadPending || shortcutDiscovery.refreshing || shortcutDiscovery.cardDataUpdating)
            return

        reloadPending = true
        reloadConfig()

        Qt.callLater(function() {
            reloadPending = false
            shortcutDiscovery.refresh()
        })
    }

    function requestInitialRefresh() {
        if (initialDiscoveryRequested || shortcutDiscovery.refreshing)
            return

        initialDiscoveryRequested = true
        shortcutDiscovery.refresh()
    }

    function requestStartupVisibility() {
        if (startupVisibilityApplied)
            return

        startupVisibilityAttempts = 0
        startupVisibilityRetry.restart()
    }

    function startupHostView() {
        try {
            return widget.NVG.View.view
        } catch (error) {
        }

        return null
    }

    function tryStartupVisibility() {
        if (startupVisibilityApplied)
            return

        if (startHidden) {
            if (closeActionSource.status) {
                startupVisibilityApplied = true
                startupVisibilityRetry.stop()
                closeActionSource.trigger()
                return
            }
        } else {
            var hostView = startupHostView()

            if (hostView) {
                startupVisibilityApplied = true
                startupVisibilityRetry.stop()
                hostView.visible = true
                resetPanel()
                return
            }
        }

        startupVisibilityAttempts += 1

        if (startupVisibilityAttempts < 20)
            startupVisibilityRetry.restart()
        else
            console.log("Games Menu startup visibility could not be applied")
    }

    function requestOpenShortcutsFolder() {
        shortcutDiscovery.openShortcutsFolder()
    }

    function handleDiscoveryRefreshed(result) {
        if (result && result.configUpdateError)
            console.log("Games Menu config item update failed: " + result.configUpdateError)

        for (var i = 0; result && result.warnings && i < result.warnings.length; ++i)
            console.log("Games Menu config update warning: " + result.warnings[i])

        if (result && result.configChanged)
            reloadConfig()
    }

    function cardIdForGame(game) {
        var explicitCardId = ConfigLoader.normalizeString(game && game.cardId, "")

        if (explicitCardId)
            return explicitCardId

        return ConfigLoader.normalizeString(game && game.id, "")
    }

    function getCardUserData(cardId) {
        return shortcutDiscovery.getCardUserData(cardId)
    }

    function updateCardUserData(cardId, changes) {
        var current = getCardUserData(cardId)
        var next = {
            customTitle: current.customTitle,
            description: current.description,
            customImage: current.customImage,
            folderId: current.folderId,
            order: current.hasOrder ? current.order : null
        }

        if (changes && typeof changes === "object") {
            for (var key in changes) {
                if (changes.hasOwnProperty(key))
                    next[key] = changes[key]
            }
        }

        var requestedFolderId = ConfigLoader.normalizeString(next.folderId, "")

        if (requestedFolderId) {
            requestedFolderId = ConfigLoader.normalizeFolderId(requestedFolderId)

            if (!requestedFolderId || requestedFolderId === "all" || !findConfiguredFolder(requestedFolderId)) {
                console.log("Games Menu card data update skipped: unknown folder " + next.folderId)
                return false
            }

            next.folderId = requestedFolderId
        }

        return shortcutDiscovery.updateCardUserData(cardId, next)
    }

    function removeCardUserOverride(cardId) {
        return shortcutDiscovery.removeCardUserOverride(cardId)
    }

    function getEffectiveCardTitle(game) {
        var userData = getCardUserData(cardIdForGame(game))
        var automaticTitle = ConfigLoader.normalizeString(game && game.automaticTitle, ConfigLoader.normalizeString(game && game.title, "GAME"))

        return userData.customTitle || automaticTitle
    }

    function getEffectiveCardImage(game) {
        var userData = getCardUserData(cardIdForGame(game))
        var automaticImage = ConfigLoader.normalizeString(game && game.automaticImage, ConfigLoader.normalizeString(game && game.image, "assets/placeholder.png"))

        return userData.customImage || automaticImage
    }

    function withCardUserData(game) {
        if (!game)
            return game

        var result = {}

        for (var key in game) {
            if (game.hasOwnProperty(key))
                result[key] = game[key]
        }

        var cardId = cardIdForGame(game)
        var userData = getCardUserData(cardId)

        result.cardId = cardId
        result.automaticTitle = ConfigLoader.normalizeString(game.title, "GAME")
        result.automaticImage = ConfigLoader.normalizeString(game.image, "assets/placeholder.png")
        result.customImage = userData.customImage
        result.customFolderId = userData.folderId
        result.customOrder = userData.order
        result.hasCustomOrder = userData.hasOrder
        result.title = getEffectiveCardTitle(result)
        result.image = getEffectiveCardImage(result)

        if (userData.description)
            result.subtitle = userData.description

        return result
    }

    function customFolderForGame(game) {
        var folderId = ConfigLoader.normalizeString(game && game.customFolderId, "")

        return folderId && findConfiguredFolder(folderId) ? folderId : ""
    }

    function sortGamesByCustomOrder(games) {
        var indexed = []

        for (var i = 0; games && i < games.length; ++i) {
            indexed.push({
                game: games[i],
                index: i
            })
        }

        indexed.sort(function(left, right) {
            var leftHasOrder = left.game && left.game.hasCustomOrder === true
            var rightHasOrder = right.game && right.game.hasCustomOrder === true

            if (leftHasOrder && rightHasOrder && left.game.customOrder !== right.game.customOrder)
                return left.game.customOrder - right.game.customOrder

            if (leftHasOrder !== rightHasOrder)
                return leftHasOrder ? -1 : 1

            return left.index - right.index
        })

        var result = []

        for (var index = 0; index < indexed.length; ++index)
            result.push(indexed[index].game)

        return result
    }

    function withCustomDescription(game) {
        var userData = getCardUserData(cardIdForGame(game))

        if (!userData.description)
            return game

        var result = {}

        for (var key in game) {
            if (game.hasOwnProperty(key))
                result[key] = game[key]
        }

        result.subtitle = userData.description
        return result
    }

    function buildAllGames() {
        var result = []
        var i

        for (i = 0; widget.discoveredGames && i < widget.discoveredGames.length; ++i)
            result.push(withCardUserData(ConfigLoader.withResolvedSubtitle(widget.discoveredGames[i], null, widget.subtitleModel, widget.syncSubtitle)))

        for (i = 0; widget.legacyGames && i < widget.legacyGames.length; ++i)
            result.push(withCardUserData(widget.legacyGames[i]))

        return result
    }

    function buildFolderList() {
        var result = [{
            id: "all",
            displayName: "ALL",
            icon: "folder-icons/default.png",
            fallbackIcon: "folder-icons/default.png",
            system: true
        }]

        for (var i = 0; widget.configuredFolders && i < widget.configuredFolders.length; ++i)
            result.push(widget.configuredFolders[i])

        return result
    }

    function findConfiguredFolder(folderId) {
        for (var i = 0; widget.configuredFolders && i < widget.configuredFolders.length; ++i) {
            if (widget.configuredFolders[i].id === folderId)
                return widget.configuredFolders[i]
        }

        return null
    }

    function selectedFolderTitle() {
        for (var i = 0; widget.folders && i < widget.folders.length; ++i) {
            if (widget.folders[i].id === widget.selectedFolderId)
                return widget.folders[i].displayName
        }

        return "ALL"
    }

    function buildPreferredGameLookup() {
        var lookup = {}

        for (var i = 0; widget.allGames && i < widget.allGames.length; ++i) {
            var game = widget.allGames[i]
            var key = ConfigLoader.normalizeNumericId(game && game.id)

            if (key && !lookup[key])
                lookup[key] = game
        }

        return lookup
    }

    function selectGamesForFolder() {
        if (widget.selectedFolderId === "all")
            return widget.allGames

        var folder = findConfiguredFolder(widget.selectedFolderId)

        if (!folder)
            return widget.allGames

        var lookup = buildPreferredGameLookup()
        var seen = {}
        var result = []

        for (var i = 0; folder.games && i < folder.games.length; ++i) {
            var folderGame = folder.games[i]
            var key = ConfigLoader.normalizeNumericId(folderGame && folderGame.id ? folderGame.id : folderGame)
            var game = lookup[key]

            var cardId = cardIdForGame(game)

            if (game && !customFolderForGame(game) && !seen[cardId]) {
                seen[cardId] = true
                result.push(withCustomDescription(ConfigLoader.withResolvedSubtitle(game, folderGame, widget.subtitleModel, widget.syncSubtitle)))
            }
        }

        for (var gameIndex = 0; widget.allGames && gameIndex < widget.allGames.length; ++gameIndex) {
            var customFolderGame = widget.allGames[gameIndex]

            var customCardId = cardIdForGame(customFolderGame)

            if (customFolderForGame(customFolderGame) === widget.selectedFolderId && !seen[customCardId]) {
                seen[customCardId] = true
                result.push(customFolderGame)
            }
        }

        return sortGamesByCustomOrder(result)
    }

    function resetPanel() {
        closeActionAfterAnimation = false
        closeDelay.stop()
        failedResetDelay.stop()
        hideAnimation.stop()
        showAnimation.stop()

        closing = false
        launching = false
        launchFailed = false
        launchingTitle = ""

        panel.visible = true
        panel.opacity = 1
        panel.scale = 1
        panel.x = 0
    }

    function animateIn() {
        resetPanel()

        panel.opacity = 0
        panel.scale = 0.965
        panel.x = -widget.openOffset

        showAnimation.restart()
    }

    function closeWithAction() {
        closeDelay.stop()
        failedResetDelay.stop()
        showAnimation.stop()

        closing = true
        closeActionAfterAnimation = true

        hideAnimation.restart()
    }

    function triggerCloseAction() {
        if (closeActionSource.status)
            closeActionSource.trigger()
        else
            console.log("Games Menu close action is not configured")

        resetPanel()
    }

    function requestClose() {
        if (closing)
            return

        launching = false
        launchFailed = false
        launchingTitle = ""

        closeWithAction()
    }

    function clearLaunchFailure() {
        failedResetDelay.stop()
        launchFailed = false
        launchingTitle = ""
    }

    function failLaunch(displayName) {
        closeDelay.stop()

        launching = false
        launchFailed = true
        launchingTitle = displayName

        failedResetDelay.restart()
    }

    function hasWindowsRoot(path) {
        return /^[A-Za-z]:[\/\\]/.test(path) || path.indexOf("\\\\") === 0
    }

    function isLaunchUri(value) {
        return /^[A-Za-z][A-Za-z0-9+.-]*:\/\//.test(value)
    }

    function shortcutFileName(shortcutName) {
        var name = shortcutName ? String(shortcutName).replace(/^\s+|\s+$/g, "") : ""

        if (!name)
            return ""

        if (isLaunchUri(name))
            return name

        var lowerName = name.toLowerCase()

        if (lowerName.slice(-4) !== ".lnk" && lowerName.slice(-4) !== ".url")
            name += ".lnk"

        return name
    }

    function shortcutPath(shortcutName) {
        var name = shortcutFileName(shortcutName)

        if (!name)
            return ""

        if (isLaunchUri(name) || hasWindowsRoot(name))
            return name

        var dir = shortcutsDir ? String(shortcutsDir).replace(/^\s+|\s+$/g, "") : ""

        if (!dir)
            return ""

        var last = dir.charAt(dir.length - 1)
        var separator = last === "/" || last === "\\" ? "" : (dir.indexOf("/") >= 0 ? "/" : "\\")

        return dir + separator + name
    }

    function launchShortcut(game) {
        if (closing || launching)
            return

        var displayName = game && game.title ? game.title : "GAME"
        var shortcut = shortcutPath(game && game.shortcut ? game.shortcut : "")

        launchFailed = false
        launching = true
        launchingTitle = displayName

        if (!shortcut) {
            failLaunch(displayName)
            return
        }

        var args = '/c start "" "' + shortcut + '"'

        try {
            NVG.SystemCall.execute("C:\\Windows\\System32\\cmd.exe", args)
        } catch (error) {
            console.log("Games Menu launch failed: " + error)
            failLaunch(displayName)
            return
        }

        closeDelay.restart()
    }

    ShortcutDiscovery {
        id: shortcutDiscovery

        shortcutsDir: widget.shortcutsDir
        onRefreshSucceeded: widget.handleDiscoveryRefreshed(result)
    }

    menu: Menu {
        MenuItem {
            text: qsTr("Close Action...")
            onTriggered: closeActionDialog.open()
        }
    }

    D.ActionDialog {
        id: closeActionDialog

        transientParent: widget.NVG.View.window
        configuration: widget.settings.closeAction

        onAccepted: widget.settings.closeAction = configuration
    }

    NVG.ActionSource {
        id: closeActionSource

        configuration: widget.settings.closeAction
    }

    Component.onCompleted: {
        resetPanel()
        Qt.callLater(widget.requestInitialRefresh)

        Qt.callLater(widget.requestStartupVisibility)
    }

    Timer {
        id: startupVisibilityRetry
        interval: 250
        repeat: false
        onTriggered: widget.tryStartupVisibility()
    }

    Timer {
        id: closeDelay
        interval: widget.launchCloseDelay
        repeat: false
        onTriggered: {
            widget.closeWithAction()
        }
    }

    Timer {
        id: failedResetDelay
        interval: widget.failureVisibleDuration
        repeat: false
        onTriggered: widget.clearLaunchFailure()
    }

    ParallelAnimation {
        id: showAnimation

        NumberAnimation {
            target: panel
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: panel
            property: "scale"
            from: 0.965
            to: 1
            duration: widget.openDuration
            easing.type: Easing.OutBack
        }

        NumberAnimation {
            target: panel
            property: "x"
            from: -widget.openOffset
            to: 0
            duration: widget.openDuration
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: hideAnimation

        NumberAnimation {
            target: panel
            property: "opacity"
            to: 0
            duration: 145
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: panel
            property: "scale"
            to: 0.975
            duration: 165
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: panel
            property: "x"
            to: -widget.openOffset
            duration: 165
            easing.type: Easing.InCubic
        }

        onStopped: {
            if (widget.closeActionAfterAnimation) {
                widget.closeActionAfterAnimation = false
                widget.triggerCloseAction()
            }
        }
    }

    Rectangle {
        id: panel

        x: 0
        y: 0
        width: parent.width
        height: parent.height
        radius: 12
        color: "#EC141922"
        transformOrigin: Item.Left

        Repeater {
            model: Math.max(1, Math.floor(panel.height / 18))

            Rectangle {
                x: 5
                y: index * 18
                width: Math.max(0, panel.width - 5)
                height: 1
                color: "#09FFFFFF"
            }
        }

        Row {
            id: titleRow
            x: 18
            y: 14
            spacing: 10

            Rectangle {
                width: 4
                height: 31
                radius: 2
                color: "#EFFFFFFF"
            }

            Column {
                spacing: 0

                Text {
                    text: "GAMES"
                    color: "#FFFFFFFF"
                    font.pixelSize: 21
                    font.bold: true
                    font.letterSpacing: 2.1
                }

                Text {
                    text: widget.selectedFolderTitle() + "  //  " + (widget.gameCount < 10 ? "0" + widget.gameCount : widget.gameCount)
                    color: "#8ED7E6F0"
                    font.pixelSize: 8
                    font.letterSpacing: 1.0
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            id: closeButton

            anchors.right: parent.right
            anchors.rightMargin: 13
            y: 12
            width: 28
            height: 28
            radius: 4
            color: closeMouse.containsMouse ? "#22FFFFFF" : "#08FFFFFF"
            border.width: closeMouse.containsMouse ? 1 : 0
            border.color: "#99FFFFFF"

            Text {
                anchors.centerIn: parent
                text: "\u00d7"
                color: "#EFFFFFFF"
                font.pixelSize: 22
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: widget.requestClose()
            }
        }

        Text {
            anchors.left: titleRow.right
            anchors.leftMargin: 14
            anchors.right: closeButton.left
            anchors.rightMargin: 10
            y: 19
            text: widget.launchFailed ? "LAUNCH FAILED // " + widget.launchingTitle
                                      : (widget.launching ? "LAUNCHING // " + widget.launchingTitle : "READY")
            color: widget.launchFailed ? "#FFFFB4B4" : (widget.launching ? "#E9FFFFFF" : "#6FFFFFFF")
            font.pixelSize: 8
            font.letterSpacing: 1.0
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        Item {
            id: contentArea

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: titleRow.bottom
            anchors.topMargin: 12
            anchors.leftMargin: 17
            anchors.rightMargin: 17
            anchors.bottomMargin: 17

            FolderSidebar {
                id: folderSidebar

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: widget.sidebarWidth
                folders: widget.folders
                selectedFolderId: widget.selectedFolderId
                hoverZoom: widget.hoverZoom
                refreshRunning: widget.reloadPending || shortcutDiscovery.refreshing
                onFolderSelected: widget.selectedFolderId = folderId
                onOpenShortcutsRequested: widget.requestOpenShortcutsFolder()
                onReloadRequested: widget.requestManualReload()
            }

            Rectangle {
                id: sidebarSeparator

                anchors.left: folderSidebar.right
                anchors.leftMargin: 12
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: "#18FFFFFF"
            }

            Flickable {
                id: gameFlickable

                anchors.left: sidebarSeparator.right
                anchors.leftMargin: 15
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: parent.top
                clip: true
                contentWidth: width
                contentHeight: gameGrid.height
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                interactive: contentHeight > height

                Grid {
                    id: gameGrid

                    width: gameFlickable.width
                    columns: widget.gridColumns
                    spacing: widget.cardSpacing

                    Repeater {
                        model: widget.gameCount

                        GameCard {
                            width: widget.cardWidth
                            height: widget.cardHeight
                            game: widget.activeGames[index]
                            gameNumber: index + 1
                            hoverZoom: widget.hoverZoom
                            enabled: !widget.launching && !widget.closing
                            onLaunchRequested: widget.launchShortcut(game)
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: gameFlickable.contentHeight > gameFlickable.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }
            }

            Item {
                anchors.fill: gameFlickable
                visible: widget.gameCount === 0

                Column {
                    anchors.centerIn: parent
                    spacing: 7

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: widget.selectedFolderId === "all" ? "NO SHORTCUTS FOUND" : "NO GAMES IN FOLDER"
                        color: "#E9FFFFFF"
                        font.pixelSize: 14
                        font.bold: true
                        font.letterSpacing: 1.8
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: widget.selectedFolderId === "all" ? "ADD .LNK OR .URL FILES TO SHORTCUTSDIR" : "CHECK FOLDER GAME NAMES IN CONFIG"
                        color: "#8ED7E6F0"
                        font.pixelSize: 8
                        font.letterSpacing: 1.0
                    }
                }
            }
        }

        Rectangle {
            id: launchOverlay
            anchors.fill: parent
            radius: panel.radius
            visible: opacity > 0.001
            opacity: widget.launching || widget.launchFailed ? 1 : 0
            color: widget.launchFailed ? "#B2161010" : "#9B10151D"

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            MouseArea {
                anchors.fill: parent
                enabled: widget.launching || widget.launchFailed
                onClicked: {
                    if (widget.launchFailed)
                        widget.clearLaunchFailure()
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 9

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: widget.launchFailed ? "LAUNCH FAILED" : "LAUNCHING"
                    color: "#FFFFFFFF"
                    font.pixelSize: 18
                    font.bold: true
                    font.letterSpacing: 3.0
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: widget.launchingTitle
                    color: widget.launchFailed ? "#FFD9BABA" : "#BDE6F5FF"
                    font.pixelSize: 10
                    font.letterSpacing: 1.6
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 190
                    height: 2
                    color: "#29FFFFFF"

                    Rectangle {
                        width: widget.launching ? parent.width : 0
                        height: parent.height
                        color: widget.launchFailed ? "#FFFFB4B4" : "#E9FFFFFF"

                        Behavior on width {
                            NumberAnimation {
                                duration: Math.max(1, widget.launchCloseDelay - 60)
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
