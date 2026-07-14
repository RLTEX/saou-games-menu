import QtQuick 2.12

Rectangle {
    id: card

    property var game
    property string cardId: game && game.cardId ? String(game.cardId) : (game && game.id ? String(game.id) : "")
    property int gameNumber: 0
    property real hoverZoom: 1.015
    property bool editMode: false
    property bool reorderEnabled: false
    property bool reorderDragging: false
    property string fallbackImage: "../assets/placeholder.png"
    property string automaticImage: resolveImage(game && game.automaticImage ? game.automaticImage : (game && game.image ? game.image : ""), false)
    property string customImage: resolveImage(game && game.customImage ? game.customImage : "", true)
    property string preferredImage: customImage || automaticImage
    property string secondaryImage: customImage && automaticImage !== customImage ? automaticImage : fallbackImage
    property string currentImage: preferredImage
    property string imageReloadKey: game && game.imageReloadKey ? game.imageReloadKey : ""
    property color accentColor: game && game.accent ? game.accent : "#DDF7FF"
    property bool hovered: mouse.containsMouse && card.enabled

    signal launchRequested(var game)
    signal editRequested(string requestedCardId)
    signal removeRequested(string requestedCardId)
    signal reorderStarted(string requestedCardId)
    signal reorderPointerMoved(string requestedCardId, real gridX, real gridY, real sceneX, real sceneY)
    signal reorderDropped(string requestedCardId)
    signal reorderFinished(string requestedCardId)

    function resolveImage(path, optional) {
        var value = path ? String(path).replace(/^\s+|\s+$/g, "") : ""

        if (!value)
            return optional ? "" : fallbackImage

        if (/^[A-Za-z]:[\/\\]/.test(value))
            return "file:///" + value.replace(/\\/g, "/")

        if (value.indexOf("\\\\") === 0)
            return "file:" + value.replace(/\\/g, "/")

        if (value.indexOf("/") === 0)
            return "file://" + value

        if (value.indexOf("file:") === 0 || value.indexOf("qrc:") === 0 || value.indexOf("http://") === 0 || value.indexOf("https://") === 0)
            return value

        if (value.indexOf("../") === 0)
            return value

        return "../" + value
    }

    function numberLabel() {
        if (gameNumber < 10)
            return "0" + gameNumber

        return "" + gameNumber
    }

    function reloadImageSource() {
        currentImage = ""
        Qt.callLater(function() {
            currentImage = preferredImage
        })
    }

    function nextImageFallback() {
        if (currentImage === preferredImage && secondaryImage && currentImage !== secondaryImage)
            return secondaryImage

        if (currentImage !== fallbackImage)
            return fallbackImage

        return ""
    }

    radius: 10
    clip: true
    opacity: reorderDragging ? 0.24 : 1
    color: "#1AFFFFFF"
    // The hover outline does not stay aligned with the zoomed image in the
    // SAO Utils renderer. Keep only the Edit Mode state indicator for now.
    border.width: editMode ? 1 : 0
    border.color: "#92DDF7FF"

    Behavior on opacity {
        NumberAnimation { duration: 100 }
    }

    Behavior on x {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Behavior on y {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    onPreferredImageChanged: {
        reloadImageSource()
    }

    onImageReloadKeyChanged: {
        reloadImageSource()
    }

    Image {
        id: art

        anchors.centerIn: parent
        width: parent.width * (card.hovered ? card.hoverZoom : 1)
        height: parent.height * (card.hovered ? card.hoverZoom : 1)
        source: card.currentImage
        cache: false
        fillMode: Image.PreserveAspectCrop
        smooth: true

        onStatusChanged: {
            if (status === Image.Error) {
                var fallback = card.nextImageFallback()

                if (fallback)
                    card.currentImage = fallback
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: card.hovered ? "#20030B10" : "#48030B10"

        Behavior on color {
            ColorAnimation { duration: 110 }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(46, parent.height * 0.28)
        color: "#A707111A"
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: card.hovered || card.editMode ? parent.width : 0
        height: 3
        color: accentColor

        Behavior on width {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 13
        anchors.right: numberText.left
        anchors.rightMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 9
        spacing: 1

        Text {
            width: parent.width
            text: game && game.title ? game.title : "GAME"
            color: "white"
            font.pixelSize: 24
            font.bold: true
            font.letterSpacing: 1.4
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: card.editMode ? "EDIT MODE  >" : (card.hovered ? "LAUNCH  >" : (game && game.subtitle ? game.subtitle : ""))
            color: card.editMode || card.hovered ? "#F4FFFFFF" : accentColor
            font.pixelSize: 8
            font.letterSpacing: 0.8
            elide: Text.ElideRight
        }
    }

    Text {
        id: numberText

        anchors.right: reorderButton.visible ? reorderButton.left : (editButton.visible ? editButton.left : parent.right)
        anchors.rightMargin: (reorderButton.visible || editButton.visible) ? 8 : 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 13
        text: card.numberLabel()
        color: "#70FFFFFF"
        font.pixelSize: 9
        font.letterSpacing: 1
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: card.editMode ? Qt.ArrowCursor : Qt.PointingHandCursor
        enabled: card.enabled
        onClicked: {
            if (!card.editMode)
                card.launchRequested(card.game)
        }
    }

    Rectangle {
        id: editButton

        anchors.bottom: parent.bottom
        anchors.right: removeButton.visible ? removeButton.left : parent.right
        anchors.bottomMargin: 12
        anchors.rightMargin: removeButton.visible ? 8 : 12
        width: 28
        height: 28
        radius: 4
        visible: card.editMode && card.enabled
        z: 2
        color: editMouse.containsMouse ? "#22FFFFFF" : "#08FFFFFF"
        border.width: editMouse.containsMouse ? 1 : 0
        border.color: "#99FFFFFF"

        LucideIcon {
            anchors.centerIn: parent
            width: 17
            height: 17
            name: "pencil"
            opacity: editMouse.containsMouse ? 1 : 0.8
        }

        MouseArea {
            id: editMouse

            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.editRequested(card.cardId)
        }
    }

    Rectangle {
        id: reorderButton

        anchors.bottom: parent.bottom
        anchors.right: editButton.left
        anchors.bottomMargin: 12
        anchors.rightMargin: 8
        width: 28
        height: 28
        radius: 4
        visible: card.editMode && card.reorderEnabled && card.enabled
        z: 2
        color: reorderMouse.containsMouse ? "#22FFFFFF" : "#08FFFFFF"
        border.width: reorderMouse.containsMouse ? 1 : 0
        border.color: "#99FFFFFF"

        LucideIcon {
            anchors.centerIn: parent
            width: 16
            height: 16
            name: "grip-vertical"
            opacity: reorderMouse.containsMouse ? 1 : 0.8
        }

        MouseArea {
            id: reorderMouse

            property real pressX: 0
            property real pressY: 0
            property bool moved: false

            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.SizeAllCursor
            onPressed: {
                pressX = mouseX
                pressY = mouseY
                moved = false
                card.reorderStarted(card.cardId)
            }
            onPositionChanged: {
                if (!pressed)
                    return

                if (!moved && Math.abs(mouseX - pressX) + Math.abs(mouseY - pressY) < 6)
                    return

                moved = true
                var gridPoint = reorderButton.mapToItem(card.parent, mouseX, mouseY)
                var scenePoint = reorderButton.mapToItem(null, mouseX, mouseY)
                card.reorderPointerMoved(card.cardId, gridPoint.x, gridPoint.y, scenePoint.x, scenePoint.y)
            }
            onReleased: {
                if (moved) {
                    var gridPoint = reorderButton.mapToItem(card.parent, mouseX, mouseY)
                    var scenePoint = reorderButton.mapToItem(null, mouseX, mouseY)
                    card.reorderPointerMoved(card.cardId, gridPoint.x, gridPoint.y, scenePoint.x, scenePoint.y)
                    card.reorderDropped(card.cardId)
                } else {
                    card.reorderFinished(card.cardId)
                }
                moved = false
            }
            onCanceled: card.reorderFinished(card.cardId)
        }
    }

    Rectangle {
        id: removeButton

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 12
        anchors.rightMargin: 12
        width: 28
        height: 28
        radius: 4
        visible: card.editMode && card.enabled
        z: 2
        color: removeMouse.containsMouse ? "#32FF7272" : "#08FFFFFF"
        border.width: removeMouse.containsMouse ? 1 : 0
        border.color: removeMouse.containsMouse ? "#FFFFB4B4" : "#99FFFFFF"

        LucideIcon {
            anchors.centerIn: parent
            width: 16
            height: 16
            name: "trash-2"
            opacity: removeMouse.containsMouse ? 1 : 0.8
        }

        MouseArea {
            id: removeMouse

            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.removeRequested(card.cardId)
        }
    }

}
