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

    // Visual tuning kept local so users can tweak the widget without touching logic.
    property int cardSpacing: 18
    property real hoverZoom: 1.015
    property int openOffset: 72
    property int openDuration: 230
    property int launchCloseDelay: 520
    property int failureVisibleDuration: 1700
    property int cardMinWidth: 160
    property int cardMaxHeight: 240

    property var appConfig: ConfigLoader.load()
    property string shortcutsDir: appConfig.shortcutsDir
    property bool startHidden: appConfig.startHidden
    property int maxColumns: appConfig.maxColumns
    property var games: appConfig.games

    property bool closing: false
    property bool launching: false
    property bool launchFailed: false
    property bool closeActionAfterAnimation: false
    property string launchingTitle: ""

    property int gameCount: games && games.length ? games.length : 0
    property int gridColumns: calculateGridColumns()
    property real cardWidth: calculateCardWidth()
    property real cardHeight: Math.max(118, Math.min(widget.cardMaxHeight, Math.round(widget.cardWidth * 0.62)))

    function calculateGridColumns() {
        var configured = Math.max(1, widget.maxColumns)
        var count = Math.max(1, widget.gameCount)
        var availableWidth = gameFlickable ? gameFlickable.width : 0
        var byWidth = Math.max(1, Math.floor((availableWidth + widget.cardSpacing) / (widget.cardMinWidth + widget.cardSpacing)))

        return Math.max(1, Math.min(configured, count, byWidth))
    }

    function calculateCardWidth() {
        var availableWidth = gameFlickable ? gameFlickable.width : 0
        var columns = Math.max(1, widget.gridColumns)
        var spacing = widget.cardSpacing * (columns - 1)

        return Math.max(1, Math.floor((availableWidth - spacing) / columns))
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

        if (widget.startHidden)
            Qt.callLater(widget.requestClose)
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

        Rectangle {
            x: 0
            y: parent.height / 2 - 18
            width: 4
            height: 36
            radius: 2
            color: "#A8DDF6FF"
        }

        Rectangle {
            x: 2
            y: parent.height / 2 - 7
            width: 14
            height: 14
            rotation: 45
            color: "#5ADDF6FF"
            border.width: 1
            border.color: "#96EAF9FF"
        }

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
                    text: "SELECT APPLICATION  //  " + (widget.gameCount < 10 ? "0" + widget.gameCount : widget.gameCount)
                    color: "#8ED7E6F0"
                    font.pixelSize: 8
                    font.letterSpacing: 1.0
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

        Flickable {
            id: gameFlickable

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: titleRow.bottom
            anchors.topMargin: 12
            anchors.leftMargin: 17
            anchors.rightMargin: 17
            anchors.bottomMargin: 17
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
                        game: widget.games[index]
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
                    text: "NO GAMES CONFIGURED"
                    color: "#E9FFFFFF"
                    font.pixelSize: 14
                    font.bold: true
                    font.letterSpacing: 1.8
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "ADD GAME IN CONFIG"
                    color: "#8ED7E6F0"
                    font.pixelSize: 8
                    font.letterSpacing: 1.0
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
