import QtQuick 2.12

Rectangle {
    id: card

    property var game
    property int gameNumber: 0
    property real hoverZoom: 1.015
    property string fallbackImage: "../assets/placeholder.png"
    property string preferredImage: resolveImage(game && game.image ? game.image : "", false)
    property string currentImage: preferredImage
    property color accentColor: game && game.accent ? game.accent : "#DDF7FF"
    property bool hovered: mouse.containsMouse && card.enabled

    signal launchRequested(var game)

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

    radius: 10
    clip: true
    color: "#1AFFFFFF"
    border.width: hovered ? 2 : 0
    border.color: hovered ? "#DDF1FDFF" : accentColor
    scale: hovered ? hoverZoom : 1

    onPreferredImageChanged: {
        currentImage = preferredImage
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
        fillMode: Image.PreserveAspectCrop
        smooth: true

        onStatusChanged: {
            if (status === Image.Error && card.currentImage !== card.fallbackImage)
                card.currentImage = card.fallbackImage
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
        width: card.hovered ? parent.width : 0
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
            text: card.hovered ? "LAUNCH  >" : (game && game.subtitle ? game.subtitle : "")
            color: card.hovered ? "#F4FFFFFF" : accentColor
            font.pixelSize: 8
            font.letterSpacing: 0.8
            elide: Text.ElideRight
        }
    }

    Text {
        id: numberText

        anchors.right: parent.right
        anchors.rightMargin: 12
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
        cursorShape: Qt.PointingHandCursor
        enabled: card.enabled
        onClicked: card.launchRequested(card.game)
    }
}
