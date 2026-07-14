import QtQuick 2.12

Item {
    id: sidebar

    property var folders: []
    property string selectedFolderId: "all"
    property real hoverZoom: 1.015
    property string fallbackIcon: "folder-icons/default.png"
    property bool refreshRunning: false
    property bool editMode: false
    property bool cardDragActive: false
    property string cardDragSourceFolderId: ""
    property string cardDragTargetFolderId: ""

    signal folderSelected(string folderId)
    signal openShortcutsRequested()
    signal settingsRequested()
    signal folderEditRequested(string folderId)
    signal folderRemoveRequested(string folderId)
    signal folderCreateRequested()
    signal reloadRequested()
    signal editModeRequested()

    function folderIdAtScenePosition(sceneX, sceneY) {
        if (!editMode || !cardDragActive)
            return ""

        var point = folderList.mapFromItem(null, sceneX, sceneY)
        var rowHeight = 42 + folderColumn.spacing
        var contentY = point.y + folderList.contentY
        var index = Math.floor((contentY - folderColumn.y) / rowHeight)

        if (point.x < 0 || point.x > folderList.width || point.y < 0 || point.y > folderList.height || index < 0 || !folders || index >= folders.length)
            return ""

        var withinRow = contentY - folderColumn.y - index * rowHeight
        var folder = folders[index]
        return withinRow >= 0 && withinRow <= 42 && folder && folder.id !== cardDragSourceFolderId ? String(folder.id) : ""
    }

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

    Flickable {
        id: folderList

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.bottom: toolRow.top
        anchors.bottomMargin: 10
        clip: true
        contentWidth: width
        contentHeight: folderColumn.height
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: folderColumn

            width: folderList.width
            height: implicitHeight
            spacing: 8

            Repeater {
                model: sidebar.folders ? sidebar.folders.length : 0

                Rectangle {
                id: folderButton

                property var folder: sidebar.folders[index]
                property bool selected: folder && folder.id === sidebar.selectedFolderId
                property bool hovered: folderMouse.containsMouse
                property bool dropTarget: sidebar.cardDragActive && sidebar.editMode && folder
                                          && folder.id === sidebar.cardDragTargetFolderId
                property string preferredIcon: sidebar.resolveImage(folder && folder.icon ? folder.icon : sidebar.fallbackIcon)
                property string currentIcon: preferredIcon

                width: folderColumn.width
                height: 42
                radius: 7
                color: dropTarget ? "#36DDF6FF" : (selected ? "#1FDDF6FF" : (hovered ? "#12FFFFFF" : "transparent"))
                border.width: dropTarget || selected ? 1 : 0
                border.color: dropTarget ? "#DDF7FFFF" : "#4FDDF6FF"
                scale: (hovered && !selected) || dropTarget ? sidebar.hoverZoom : 1

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
                    height: selected || dropTarget ? 24 : 0
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
                    anchors.rightMargin: sidebar.editMode && folder ? 57 : 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: folder && folder.displayName ? folder.displayName : "FOLDER"
                    color: folderButton.dropTarget || folderButton.selected ? "#FFFFFFFF" : "#A8D7E6F0"
                    font.pixelSize: 10
                    font.bold: folderButton.dropTarget || folderButton.selected
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

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 33
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    radius: 4
                    visible: sidebar.editMode && folder && !folder.system
                    color: folderRemoveMouse.containsMouse ? "#32FF7272" : "#0CFFFFFF"
                    border.width: folderRemoveMouse.containsMouse ? 1 : 0
                    border.color: folderRemoveMouse.containsMouse ? "#FFFFB4B4" : "#66DDF6FF"

                    Text { anchors.centerIn: parent; text: "−"; color: folderRemoveMouse.containsMouse ? "#FFFFD3D3" : "#B8F2FDFF"; font.pixelSize: 17; font.bold: true }

                    MouseArea {
                        id: folderRemoveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { mouse.accepted = true; sidebar.folderRemoveRequested(folderButton.folder.id) }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    radius: 4
                    visible: sidebar.editMode && folder
                    color: folderEditMouse.containsMouse ? "#22FFFFFF" : "#0CFFFFFF"
                    border.width: folderEditMouse.containsMouse ? 1 : 0
                    border.color: "#66DDF6FF"

                    Text { anchors.centerIn: parent; text: "\u270e"; color: "#B8F2FDFF"; font.pixelSize: 14; font.bold: true }

                    MouseArea {
                        id: folderEditMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { mouse.accepted = true; sidebar.folderEditRequested(folderButton.folder.id) }
                    }
                }
            }
        }
        }

    }

    Row {
        id: toolRow

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        height: 28
        spacing: 8

        Rectangle {
            id: openShortcutsButton

            width: 28
            height: 28
            radius: 6
            color: openShortcutsMouse.containsMouse ? "#18FFFFFF" : "#08FFFFFF"
            border.width: openShortcutsMouse.containsMouse ? 1 : 0
            border.color: "#66DDF6FF"

            Text {
                anchors.centerIn: parent
                text: "\u2699"
                color: "#B8F2FDFF"
                font.pixelSize: 17
            }

            MouseArea {
                id: openShortcutsMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sidebar.settingsRequested()
            }
        }

        Rectangle {
            id: reloadButton

            property bool visualHover: reloadMouse.containsMouse && !sidebar.refreshRunning
            property bool visualPressed: reloadMouse.pressed && !sidebar.refreshRunning

            width: 28
            height: 28
            radius: 6
            opacity: sidebar.refreshRunning ? 0.45 : 1
            color: visualPressed ? "#22FFFFFF" : (visualHover ? "#18FFFFFF" : "#08FFFFFF")
            border.width: visualHover || visualPressed ? 1 : 0
            border.color: "#66DDF6FF"

            Canvas {
                anchors.centerIn: parent
                width: 17
                height: 17

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = "#B8F2FDFF"
                    ctx.fillStyle = "#B8F2FDFF"
                    ctx.lineWidth = 1.6
                    ctx.beginPath()
                    ctx.arc(8.5, 8.5, 5.2, 0.45, 5.1, false)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.moveTo(12.8, 2.8)
                    ctx.lineTo(15.4, 3.1)
                    ctx.lineTo(14.1, 5.5)
                    ctx.closePath()
                    ctx.fill()
                }
            }

            MouseArea {
                id: reloadMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: sidebar.refreshRunning ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: {
                    if (!sidebar.refreshRunning)
                        sidebar.reloadRequested()
                }
            }
        }

        Rectangle {
            id: editModeButton

            property bool visualHover: editModeMouse.containsMouse
            property bool visualPressed: editModeMouse.pressed

            width: 28
            height: 28
            radius: 6
            color: sidebar.editMode ? "#24DDF6FF" : (visualPressed ? "#22FFFFFF" : (visualHover ? "#18FFFFFF" : "#08FFFFFF"))
            border.width: sidebar.editMode || visualHover || visualPressed ? 1 : 0
            border.color: sidebar.editMode ? "#B8F2FDFF" : "#66DDF6FF"

            Text {
                anchors.centerIn: parent
                text: "\u270e"
                color: sidebar.editMode ? "#FFFFFFFF" : "#B8F2FDFF"
                font.pixelSize: 17
                font.bold: true
            }

            MouseArea {
                id: editModeMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sidebar.editModeRequested()
            }
        }

        Rectangle {
            width: 28
            height: 28
            radius: 6
            visible: sidebar.editMode
            color: addFolderMouse.containsMouse ? "#18FFFFFF" : "#08FFFFFF"
            border.width: addFolderMouse.containsMouse ? 1 : 0
            border.color: "#66DDF6FF"

            Text { anchors.centerIn: parent; text: "+"; color: "#B8F2FDFF"; font.pixelSize: 19; font.bold: true }

            MouseArea {
                id: addFolderMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sidebar.folderCreateRequested()
            }
        }

    }
}
