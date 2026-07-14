import QtQuick 2.12

Rectangle {
    id: card

    property var game
    property string cardId: game && game.cardId ? String(game.cardId) : (game && game.id ? String(game.id) : "")
    property int gameNumber: 0
    property real hoverZoom: 1.015
    property bool editMode: false
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
    color: "#1AFFFFFF"
    border.width: hovered || editMode ? (editMode ? 1 : 2) : 0
    border.color: editMode ? "#92DDF7FF" : (hovered ? "#DDF1FDFF" : accentColor)
    scale: hovered ? hoverZoom : 1

    onPreferredImageChanged: {
        reloadImageSource()
    }

    onImageReloadKeyChanged: {
        reloadImageSource()
    }

    Behavior on scale {
        NumberAnimation {
            duration: 110
            easing.type: Easing.OutCubic
        }
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

        anchors.right: editButton.visible ? editButton.left : parent.right
        anchors.rightMargin: editButton.visible ? 8 : 12
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
        anchors.right: parent.right
        anchors.bottomMargin: 12
        anchors.rightMargin: 12
        width: 28
        height: 28
        radius: 4
        visible: card.editMode && card.enabled
        z: 2
        color: editMouse.containsMouse ? "#22FFFFFF" : "#08FFFFFF"
        border.width: editMouse.containsMouse ? 1 : 0
        border.color: "#99FFFFFF"

        Text {
            anchors.centerIn: parent
            text: "\u270e"
            color: "#FFFFFFFF"
            font.pixelSize: 17
            font.bold: true
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
}
