import QtQuick 2.12

Item {
    id: sidebar

    property var folders: []
    property string selectedFolderId: "all"
    property real hoverZoom: 1.015
    property string fallbackIcon: "folder-icons/default.png"

    signal folderSelected(string folderId)

    function resolveImage(path) {
        var value = path ? String(path).replace(/^\s+|\s+$/g, "") : ""

        if (!value)
            return "../" + fallbackIcon

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

    Column {
        id: folderColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 8

        Repeater {
            model: sidebar.folders ? sidebar.folders.length : 0

            Rectangle {
                id: folderButton

                property var folder: sidebar.folders[index]
                property bool selected: folder && folder.id === sidebar.selectedFolderId
                property bool hovered: folderMouse.containsMouse
                property string preferredIcon: sidebar.resolveImage(folder && folder.icon ? folder.icon : sidebar.fallbackIcon)
                property string currentIcon: preferredIcon

                width: folderColumn.width
                height: 42
                radius: 7
                color: selected ? "#1FDDF6FF" : (hovered ? "#12FFFFFF" : "transparent")
                border.width: selected ? 1 : 0
                border.color: "#4FDDF6FF"
                scale: hovered && !selected ? sidebar.hoverZoom : 1

                onPreferredIconChanged: currentIcon = preferredIcon

                Behavior on color {
                    ColorAnimation { duration: 110 }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 110
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: selected ? 24 : 0
                    radius: 1
                    color: "#B8F2FDFF"

                    Behavior on height {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Item {
                    id: iconBox

                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22

                    Image {
                        id: folderIcon

                        anchors.fill: parent
                        source: folderButton.currentIcon
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        opacity: status === Image.Ready ? 1 : 0

                        onStatusChanged: {
                            if (status === Image.Error && folderButton.currentIcon !== sidebar.resolveImage(sidebar.fallbackIcon))
                                folderButton.currentIcon = sidebar.resolveImage(sidebar.fallbackIcon)
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        visible: folderIcon.status !== Image.Ready
                        color: folderButton.selected ? "#28F2FDFF" : "#18FFFFFF"
                        border.width: 1
                        border.color: folderButton.selected ? "#8AF2FDFF" : "#35FFFFFF"
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 5
                        height: 2
                        visible: folderIcon.status !== Image.Ready
                        radius: 1
                        color: folderButton.selected ? "#9AF2FDFF" : "#55FFFFFF"
                    }
                }

                Text {
                    anchors.left: iconBox.right
                    anchors.leftMargin: 9
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: folder && folder.displayName ? folder.displayName : "FOLDER"
                    color: folderButton.selected ? "#FFFFFFFF" : "#A8D7E6F0"
                    font.pixelSize: 10
                    font.bold: folderButton.selected
                    font.letterSpacing: 1.0
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: folderMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !!folderButton.folder
                    onClicked: sidebar.folderSelected(folderButton.folder.id)
                }
            }
        }
    }
}
