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
    property var folderOverrides: shortcutDiscovery.folderOverrides
    property var subtitleModel: appConfig.subtitleModel
    property var legacyGames: appConfig.legacyGames
    property var discoveredGames: shortcutDiscovery.items
    property string selectedFolderId: "all"
    property var allGames: buildAllGames()
    property var folders: buildFolderList()
    property var activeGames: selectGamesForFolder()
    property var reorderPreviewGames: null
    property var displayedGames: reorderPreviewGames !== null ? reorderPreviewGames : activeGames

    property bool closing: false
    property bool launching: false
    property bool launchFailed: false
    property bool editMode: false
    property bool closeActionAfterAnimation: false
    property bool reloadPending: false
    property bool initialDiscoveryRequested: false
    property bool startupVisibilityApplied: false
    property int startupVisibilityAttempts: 0
    property string launchingTitle: ""
    property string editorCardId: ""
    property bool cardEditorOpen: false
    property bool cardEditorSaving: false
    property string cardEditorSaveError: ""
    property string editorAutomaticTitle: ""
    property string editorAutomaticImage: ""
    property string editorExistingCustomImage: ""
    property string editorImageDraft: ""
    property string editorImagePendingSource: ""
    property bool editorImageResetRequested: false
    property bool editorImageDropActive: false
    property string editorPreviewSource: ""
    property string editorPreviewFallback: ""
    property bool editorIsNewCard: false
    property var editorNewCardDraft: null
    property string editorSourcePath: ""
    property bool fileDropActive: false
    property string fileDropStatus: ""
    property string cardDataAction: ""
    property bool cardReorderActive: false
    property bool cardReorderSaving: false
    property string cardReorderSourceId: ""
    property string cardReorderTargetId: ""
    property bool cardReorderInsertAfter: false
    property string cardMoveSourceFolderId: ""
    property string cardMoveTargetFolderId: ""
    property bool cardMoveChoiceOpen: false
    property string cardMoveChoiceCardId: ""
    property string cardMoveChoiceDestinationId: ""
    property var cardReorderOriginalGames: []
    property var cardReorderGame: null
    property real cardReorderPointerX: 0
    property real cardReorderPointerY: 0
    property bool cardReorderPointerValid: false
    property string cardReorderError: ""
    property bool cardRemovalConfirmOpen: false
    property bool cardRemovalSaving: false
    property string cardRemovalCardId: ""
    property string cardRemovalTitle: ""
    property string cardRemovalError: ""
    property bool settingsOpen: false
    property bool settingsSaving: false
    property string settingsError: ""
    property bool settingsStartHiddenDraft: false
    property bool settingsSyncSubtitleDraft: true
    property bool folderEditorOpen: false
    property string folderEditorId: ""
    property string folderEditorError: ""
    property bool folderEditorIconDropActive: false
    property bool folderCreating: false
    property bool recoveryOpen: false
    property bool folderCreateOpen: false
    property string folderCreateError: ""

    property int gameCount: displayedGames && displayedGames.length ? displayedGames.length : 0
    property int gridColumns: calculateGridColumns()
    property real cardWidth: calculateCardWidth()
    property real cardHeight: Math.max(118, Math.min(widget.cardMaxHeight, Math.round(widget.cardWidth * 0.62)))

    onSelectedFolderIdChanged: cancelCardReorder()
    onFolderEditorOpenChanged: {
        if (!folderEditorOpen) {
            folderCreating = false
            folderEditorIconDropActive = false
        }
    }
    onEditModeChanged: {
        if (!editMode) {
            cancelCardReorder()
            fileDropActive = false
            fileDropStatus = ""
        }
    }

    function calculateGridColumns() {
        var configured = Math.max(1, maxColumnsForSelectedFolder())
        var count = Math.max(1, widget.gameCount)
        var availableWidth = gameFlickable ? gameFlickable.width : 0
        var byWidth = Math.max(1, Math.floor((availableWidth + widget.cardSpacing) / (widget.cardMinWidth + widget.cardSpacing)))

        return Math.max(1, Math.min(configured, count, byWidth))
    }

    function maxColumnsForSelectedFolder() {
        var selectedOverride = folderOverrideFor(widget.selectedFolderId)
        if (selectedOverride.maxColumns > 0)
            return selectedOverride.maxColumns

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

    function requestOpenPackageFolder() {
        shortcutDiscovery.openPackageFolder()
    }

    function openSettings() {
        if (settingsOpen || settingsSaving || cardEditorOpen || folderEditorOpen)
            return
        settingsStartHiddenDraft = startHidden
        settingsSyncSubtitleDraft = syncSubtitle
        settingsError = ""
        settingsColumnsField.text = "" + maxColumns
        settingsOpen = true
    }

    function closeSettings() {
        if (!settingsSaving)
            settingsOpen = false
    }

    function saveSettings() {
        var columns = parseInt(settingsColumnsField.text, 10)
        if (!columns || columns < 1 || columns > 8 || String(columns) !== settingsColumnsField.text.trim()) {
            settingsError = "MAX COLUMNS: 1-8"
            return
        }
        settingsSaving = true
        settingsError = ""
        cardDataAction = "settings"
        if (!shortcutDiscovery.saveWidgetSettings({ startHidden: settingsStartHiddenDraft, maxColumns: columns, syncSubtitle: settingsSyncSubtitleDraft })) {
            settingsSaving = false; cardDataAction = ""; settingsError = "SAVE IS TEMPORARILY UNAVAILABLE"
        }
    }

    function openFolderEditor(folderId) {
        var folder = findConfiguredFolder(folderId)
        if (!editMode || (folderId !== "all" && !folder) || folderEditorOpen || settingsOpen)
            return
        var override = folderOverrideFor(folderId)
        folderEditorId = folderId === "all" ? "all" : folder.id
        folderEditorTitleField.text = override.customTitle
        folderEditorColumnsField.text = override.maxColumns ? "" + override.maxColumns : ""
        folderEditorIconPathField.text = override.customIcon
        folderEditorError = ""
        folderEditorIconDropActive = false
        folderEditorOpen = true
    }

    function chooseFolderEditorIcon(path) {
        var value = trimEditorText(path)

        if (!isSupportedImagePath(value)) {
            folderEditorError = "DROP ONE PNG, JPG, JPEG OR WEBP IMAGE"
            return false
        }

        folderEditorIconPathField.text = value
        folderEditorError = ""
        return true
    }

    function openFolderCreate() {
        if (!editMode || folderEditorOpen || settingsOpen || cardEditorOpen)
            return

        folderCreating = true
        folderEditorId = ""
        folderEditorTitleField.text = ""
        folderEditorColumnsField.text = ""
        folderEditorIconPathField.text = ""
        folderEditorError = ""
        folderEditorOpen = true
        folderEditorTitleField.forceActiveFocus()
    }

    function createFolder(titleText) {
        if (!folderCreating || shortcutDiscovery.cardDataUpdating)
            return

        var title = trimEditorText(titleText)
        if (!title) {
            folderEditorError = "ENTER A FOLDER NAME"
            return
        }
        if (title.length > 60 || title.indexOf("|") >= 0 || /[\r\n]/.test(title)) {
            folderEditorError = "USE UP TO 60 CHARACTERS WITHOUT |"
            return
        }

        var baseId = title.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "folder"
        var folderId = baseId
        var suffix = 2
        while (findConfiguredFolder(folderId)) {
            folderId = baseId + "-" + suffix
            suffix += 1
        }

        folderEditorError = ""
        cardDataAction = "create-folder"
        if (!shortcutDiscovery.createFolder({ folderId: folderId, displayName: title })) {
            cardDataAction = ""
            folderEditorError = "SAVE IS TEMPORARILY UNAVAILABLE"
        }
    }

    function saveFolderEditor() {
        if (folderCreating) {
            createFolder(folderEditorTitleField.text)
            return
        }

        var next = {}
        var override = folderOverrideFor(folderEditorId)
        for (var key in folderOverrides) if (folderOverrides.hasOwnProperty(key)) next[key] = folderOverrides[key]
        var entry = {}
        var title = folderEditorTitleField.text.trim()
        var columnsText = folderEditorColumnsField.text.trim()
        var iconPath = folderEditorIconPathField.text.trim()
        if (title) entry.customTitle = title
        if (iconPath) {
            if (iconPath === override.customIcon)
                entry.customIcon = iconPath
            else
                entry.customIconSource = iconPath
        }
        if (columnsText) {
            var columns = parseInt(columnsText, 10)
            if (!columns || columns < 1 || columns > 8 || String(columns) !== columnsText) { folderEditorError = "MAX COLUMNS: 1-8"; return }
            entry.maxColumns = columns
        }
        if (Object.keys(entry).length) next[folderEditorId] = entry; else delete next[folderEditorId]
        cardDataAction = "folder"
        if (!shortcutDiscovery.updateFolderOverrides({ folderOverrides: next })) folderEditorError = "SAVE IS TEMPORARILY UNAVAILABLE"
    }

    function hiddenCardIds() {
        var result = []
        var data = shortcutDiscovery.cardData || ({})
        for (var cardId in data) {
            if (data.hasOwnProperty(cardId) && getCardUserData(cardId).isHidden)
                result.push(cardId)
        }
        return result
    }

    function restoreCard(cardId) {
        if (!cardId || shortcutDiscovery.cardDataUpdating)
            return

        var current = getCardUserData(cardId)
        var folderId = customFolderForGame({ customFolderId: current.folderId }) || "all"
        var folderOrders = current.folderOrders || ({})
        folderOrders[folderId] = selectGamesForFolderId(folderId).length
        updateCardUserData(cardId, { isHidden: false, order: folderOrders[folderId], folderOrders: folderOrders })
    }

    function toggleEditMode() {
        if (closing || launching || cardEditorOpen || cardRemovalConfirmOpen || cardMoveChoiceOpen)
            return

        if (editMode)
            cancelCardReorder()
        editMode = !editMode
        editorCardId = ""
    }

    function openCardEditor(cardId) {
        var normalizedCardId = ConfigLoader.normalizeString(cardId, "")

        if (!editMode || cardEditorOpen || cardEditorSaving || !normalizedCardId)
            return

        var game = findGameByCardId(normalizedCardId)

        if (!game)
            return

        var userData = getCardUserData(normalizedCardId)
        editorCardId = normalizedCardId
        editorIsNewCard = false
        editorNewCardDraft = null
        editorSourcePath = ConfigLoader.normalizeString(game.sourcePath, "")
        editorAutomaticTitle = ConfigLoader.normalizeString(game.automaticTitle, ConfigLoader.normalizeString(game.title, "GAME"))
        editorAutomaticImage = ConfigLoader.normalizeString(game.automaticImage, ConfigLoader.normalizeString(game.image, "assets/placeholder.png"))
        editorExistingCustomImage = userData.customImage
        editorImageDraft = userData.customImage
        editorImagePendingSource = ""
        editorImageResetRequested = false
        editorImageDropActive = false
        editorImagePathField.text = userData.customImage
        editorTitleField.text = userData.customTitle
        editorDescriptionField.text = userData.description
        cardEditorSaveError = ""
        refreshEditorPreview()
        cardEditorOpen = true
        editorTitleField.forceActiveFocus()
    }

    function findGameByCardId(cardId) {
        for (var i = 0; allGames && i < allGames.length; ++i) {
            var game = allGames[i]

            if (cardIdForGame(game) === cardId)
                return game
        }

        return null
    }

    function normalizeSourcePath(path) {
        var value = trimEditorText(path)
        if (value.indexOf("file:///") === 0)
            value = decodeURIComponent(value.slice(8))
        else if (value.indexOf("file://") === 0)
            value = "\\\\" + decodeURIComponent(value.slice(7))

        return value.replace(/\//g, "\\").replace(/^\s+|\s+$/g, "").toLowerCase()
    }

    function sourcePathForGame(game) {
        return ConfigLoader.normalizeString(game && game.sourcePath, ConfigLoader.normalizeString(game && game.shortcut, ""))
    }

    function findGameBySourcePath(sourcePath) {
        var key = normalizeSourcePath(sourcePath)
        for (var i = 0; key && allGames && i < allGames.length; ++i) {
            if (normalizeSourcePath(sourcePathForGame(allGames[i])) === key)
                return allGames[i]
        }
        return null
    }

    function nextOrderForSelectedFolder() {
        var largest = -1
        for (var i = 0; activeGames && i < activeGames.length; ++i) {
            if (activeGames[i].hasCustomOrder)
                largest = Math.max(largest, activeGames[i].customOrder)
        }
        return largest + 1
    }

    function requestManualFileDrop(urls) {
        fileDropActive = false
        if (!urls || urls.length !== 1) {
            fileDropStatus = "DROP ONE .LNK, .URL OR .EXE FILE"
            return
        }
        if (!editMode || cardEditorOpen || cardRemovalConfirmOpen) {
            fileDropStatus = "ENABLE EDIT MODE TO ADD A GAME"
            return
        }

        var sourcePath = String(urls[0])
        var lower = sourcePath.split(/[?#]/)[0].toLowerCase()
        if (!/\.(lnk|url|exe)$/.test(lower)) {
            fileDropStatus = "ONLY .LNK, .URL OR .EXE FILES ARE SUPPORTED"
            return
        }
        if (findGameBySourcePath(sourcePath)) {
            fileDropStatus = "THIS GAME IS ALREADY ADDED"
            return
        }

        fileDropStatus = "PREPARING NEW CARD..."
        if (!shortcutDiscovery.prepareManualCard({
            sourcePath: sourcePath,
            folderId: selectedFolderId === "all" ? "" : selectedFolderId,
            order: nextOrderForSelectedFolder()
        }))
            fileDropStatus = "ADD IS TEMPORARILY UNAVAILABLE"
    }

    function handleManualCardPrepared(draft, error) {
        if (error || !draft) {
            fileDropStatus = error || "COULD NOT PREPARE NEW CARD"
            return
        }

        fileDropStatus = ""
        openNewCardEditor(draft)
    }

    function openNewCardEditor(draft) {
        if (!editMode || cardEditorOpen || !draft || !draft.cardId)
            return

        editorIsNewCard = true
        editorNewCardDraft = draft
        editorCardId = String(draft.cardId)
        editorSourcePath = ConfigLoader.normalizeString(draft.sourcePath, "")
        editorAutomaticTitle = ConfigLoader.normalizeString(draft.automaticTitle, "GAME")
        editorAutomaticImage = "assets/placeholder.png"
        editorExistingCustomImage = ""
        editorImageDraft = ""
        editorImagePendingSource = ""
        editorImageResetRequested = false
        editorImageDropActive = false
        editorImagePathField.text = ""
        editorTitleField.text = ""
        editorDescriptionField.text = ""
        cardEditorSaveError = ""
        refreshEditorPreview()
        cardEditorOpen = true
        editorTitleField.forceActiveFocus()
    }

    function trimEditorText(value) {
        return String(value === undefined || value === null ? "" : value).replace(/^\s+|\s+$/g, "")
    }

    function resolveEditorImage(path) {
        var value = trimEditorText(path)

        if (!value)
            return "../assets/placeholder.png"

        if (/^[A-Za-z]:[\/\\]/.test(value))
            return "file:///" + value.replace(/\\/g, "/")

        if (value.indexOf("\\\\") === 0)
            return "file:" + value.replace(/\\/g, "/")

        if (value.indexOf("/") === 0)
            return "file://" + value

        if (value.indexOf("file:") === 0 || value.indexOf("qrc:") === 0 || value.indexOf("http://") === 0 || value.indexOf("https://") === 0 || value.indexOf("../") === 0)
            return value

        return "../" + value
    }

    function refreshEditorPreview() {
        var automatic = resolveEditorImage(editorAutomaticImage)

        editorPreviewSource = resolveEditorImage(editorImageDraft || editorAutomaticImage)
        editorPreviewFallback = editorImageDraft ? automatic : resolveEditorImage("assets/placeholder.png")
    }

    function advanceEditorPreviewFallback() {
        var placeholder = resolveEditorImage("assets/placeholder.png")

        if (editorPreviewSource !== editorPreviewFallback) {
            editorPreviewSource = editorPreviewFallback
        } else if (editorPreviewSource !== placeholder) {
            editorPreviewSource = placeholder
        }
    }

    function isPlaceholderImagePath(path) {
        var value = trimEditorText(path).replace(/\\/g, "/").split(/[?#]/)[0].toLowerCase()
        return !value || value.indexOf("assets/placeholder.png") !== -1
    }

    function editorUsesPlaceholder() {
        return isPlaceholderImagePath(editorPreviewSource)
    }

    function isSupportedImagePath(path) {
        var value = trimEditorText(path).split(/[?#]/)[0].toLowerCase()

        return /\.(png|jpe?g|webp)$/.test(value)
    }

    function chooseEditorImage(path) {
        var value = trimEditorText(path)

        if (!isSupportedImagePath(value)) {
            cardEditorSaveError = "SELECT PNG, JPG, JPEG OR WEBP"
            return false
        }

        editorImagePendingSource = value
        editorImageDraft = value
        editorImageResetRequested = false
        editorImagePathField.text = value
        cardEditorSaveError = ""
        refreshEditorPreview()
        return true
    }

    function previewEditorImagePath() {
        if (!cardEditorOpen || cardEditorSaving)
            return

        chooseEditorImage(editorImagePathField.text)
    }

    function resetEditorImage() {
        if (cardEditorSaving)
            return

        editorImageDraft = ""
        editorImagePendingSource = ""
        editorImageResetRequested = true
        editorImageDropActive = false
        editorImagePathField.text = ""
        cardEditorSaveError = ""
        refreshEditorPreview()
    }

    function saveCardEditor() {
        if (!cardEditorOpen || cardEditorSaving || !editorCardId)
            return

        var description = trimEditorText(editorDescriptionField.text)
        var imagePath = trimEditorText(editorImagePathField.text)

        if (description.length > 600)
            description = description.slice(0, 600)

        if (!editorImageResetRequested && imagePath && imagePath !== editorExistingCustomImage && imagePath !== editorImagePendingSource
                && !chooseEditorImage(imagePath))
            return

        editorImageDropActive = false
        refreshEditorPreview()
        cardEditorSaveError = ""

        cardEditorSaving = true
        cardDataAction = editorIsNewCard ? "create" : "editor"

        var editorData = {
            customTitle: trimEditorText(editorTitleField.text),
            description: description,
            customImage: editorImageResetRequested ? "" : editorExistingCustomImage,
            customImageSource: editorImageResetRequested ? "" : editorImagePendingSource
        }

        if (editorIsNewCard && editorNewCardDraft) {
            editorData.sourcePath = editorNewCardDraft.sourcePath
            editorData.targetPath = editorNewCardDraft.targetPath
            editorData.sourceType = editorNewCardDraft.sourceType
            editorData.automaticTitle = editorNewCardDraft.automaticTitle
            editorData.folderId = editorNewCardDraft.folderId
            editorData.order = editorNewCardDraft.order
        }

        var saved = editorIsNewCard ? shortcutDiscovery.createManualCard(editorCardId, editorData)
                                     : updateCardUserData(editorCardId, editorData)
        if (!saved) {
            cardEditorSaving = false
            cardDataAction = ""
            cardEditorSaveError = "SAVE IS TEMPORARILY UNAVAILABLE"
            return
        }
    }

    function cancelCardEditor() {
        if (cardEditorSaving)
            return

        cardEditorOpen = false
        cardEditorSaveError = ""
        editorCardId = ""
        editorImagePendingSource = ""
        editorImageDropActive = false
        editorIsNewCard = false
        editorNewCardDraft = null
        editorSourcePath = ""
    }

    function handleCardDataUpdateFinished(cardId, success, error) {
        if (cardDataAction === "settings" && String(cardId) === "settings") {
            settingsSaving = false
            cardDataAction = ""
            if (success) { settingsOpen = false; reloadConfig() }
            else settingsError = error || "SAVE FAILED"
            return
        }

        if (cardDataAction === "folder" && String(cardId) === "folders") {
            cardDataAction = ""
            if (success) { folderEditorOpen = false; folderEditorId = "" }
            else folderEditorError = error || "SAVE FAILED"
            return
        }

        if (cardDataAction === "create-folder" && String(cardId) === "folder") {
            cardDataAction = ""
            if (success) {
                folderCreating = false
                folderEditorOpen = false
                folderEditorId = ""
                reloadConfig()
            } else {
                folderEditorError = error || "CREATE FAILED"
            }
            return
        }

        if ((cardDataAction === "editor" || cardDataAction === "create") && cardEditorSaving && String(cardId) === editorCardId) {
            cardEditorSaving = false
            cardDataAction = ""

            if (success) {
                cardEditorOpen = false
                cardEditorSaveError = ""
                editorCardId = ""
                editorImagePendingSource = ""
                editorImageDropActive = false
                editorIsNewCard = false
                editorNewCardDraft = null
                editorSourcePath = ""
            } else {
                cardEditorSaveError = error || "SAVE FAILED"
            }
            return
        }

        if (cardDataAction === "reorder" && cardReorderSaving && String(cardId) === "orders") {
            cardDataAction = ""

            if (success) {
                resetCardReorder()
            } else {
                cardReorderError = error || "ORDER SAVE FAILED"
                resetCardReorder()
            }
            return
        }

        if ((cardDataAction === "move" || cardDataAction === "copy") && cardReorderSaving && String(cardId) === cardReorderSourceId) {
            var completedCardAction = cardDataAction
            cardDataAction = ""

            if (success) {
                resetCardReorder()
            } else {
                cardReorderError = error || (completedCardAction === "copy" ? "COPY FAILED" : "MOVE FAILED")
                resetCardReorder()
            }
            return
        }

        if (cardDataAction === "remove" && cardRemovalSaving && String(cardId) === cardRemovalCardId) {
            cardRemovalSaving = false
            cardDataAction = ""

            if (success) {
                cardRemovalConfirmOpen = false
                cardRemovalCardId = ""
                cardRemovalTitle = ""
                cardRemovalError = ""
            } else {
                cardRemovalError = error || "REMOVE FAILED"
            }
        }
    }

    function requestCardRemoval(cardId) {
        var normalizedCardId = ConfigLoader.normalizeString(cardId, "")

        if (!editMode || cardEditorOpen || cardRemovalConfirmOpen || cardRemovalSaving || !normalizedCardId)
            return

        var game = findGameByCardId(normalizedCardId)

        if (!game)
            return

        cardRemovalCardId = normalizedCardId
        cardRemovalTitle = getEffectiveCardTitle(game)
        cardRemovalError = ""
        cardRemovalConfirmOpen = true
    }

    function cancelCardRemoval() {
        if (cardRemovalSaving)
            return

        cardRemovalConfirmOpen = false
        cardRemovalCardId = ""
        cardRemovalTitle = ""
        cardRemovalError = ""
    }

    function confirmCardRemoval() {
        if (!cardRemovalConfirmOpen || cardRemovalSaving || !cardRemovalCardId)
            return

        cardRemovalSaving = true
        cardDataAction = "remove"
        cardRemovalError = ""

        if (!updateCardUserData(cardRemovalCardId, {
            isHidden: true,
            customImage: ""
        })) {
            cardRemovalSaving = false
            cardDataAction = ""
            cardRemovalError = "REMOVE IS TEMPORARILY UNAVAILABLE"
        }
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
            additionalFolderIds: current.additionalFolderIds,
            excludedFolderIds: current.excludedFolderIds,
            order: current.hasOrder ? current.order : null,
            folderOrders: current.folderOrders,
            isHidden: current.isHidden,
            sourcePath: current.sourcePath,
            targetPath: current.targetPath,
            launchPath: current.launchPath,
            sourceType: current.sourceType,
            automaticTitle: current.automaticTitle
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

    function cardImagePreviewSource(game) {
        var value = ConfigLoader.normalizeString(getEffectiveCardImage(game), "assets/placeholder.png")

        if (/^[A-Za-z]:[\/\\]/.test(value))
            return "file:///" + value.replace(/\\/g, "/")
        if (value.indexOf("\\\\") === 0)
            return "file:" + value.replace(/\\/g, "/")
        if (value.indexOf("file:") === 0 || value.indexOf("qrc:") === 0 || value.indexOf("../") === 0)
            return value

        return "../" + value
    }

    function imagePathPreviewSource(path) {
        var value = ConfigLoader.normalizeString(path, "")
        if (/^[A-Za-z]:[\/\\]/.test(value)) return "file:///" + value.replace(/\\/g, "/")
        if (value.indexOf("file:") === 0 || value.indexOf("qrc:") === 0 || value.indexOf("../") === 0) return value
        return value ? "../" + value : "../folder-icons/default.png"
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
        result.additionalFolderIds = userData.additionalFolderIds
        result.excludedFolderIds = userData.excludedFolderIds
        result.customOrder = userData.order
        result.hasCustomOrder = userData.hasOrder
        result.folderOrders = userData.folderOrders
        result.isHidden = userData.isHidden
        result.sourcePath = userData.sourcePath
        result.targetPath = userData.targetPath
        result.launchPath = userData.launchPath
        result.sourceType = userData.sourceType
        result.automaticTitle = userData.automaticTitle || result.automaticTitle
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

    function additionalFoldersForGame(game) {
        var result = []
        var seen = {}
        var values = game && game.additionalFolderIds

        for (var i = 0; values && i < values.length; ++i) {
            var folderId = ConfigLoader.normalizeString(values[i], "").toLowerCase()
            if (folderId && folderId !== "all" && findConfiguredFolder(folderId) && !seen[folderId]) {
                seen[folderId] = true
                result.push(folderId)
            }
        }

        return result
    }

    function isGameInAdditionalFolder(game, folderId) {
        var key = ConfigLoader.normalizeString(folderId, "").toLowerCase()
        var additionalFolders = additionalFoldersForGame(game)

        for (var i = 0; i < additionalFolders.length; ++i) {
            if (additionalFolders[i] === key)
                return true
        }

        return false
    }

    function isGameExcludedFromFolder(game, folderId) {
        var key = ConfigLoader.normalizeString(folderId, "").toLowerCase()
        var values = game && game.excludedFolderIds

        for (var i = 0; values && i < values.length; ++i) {
            if (ConfigLoader.normalizeString(values[i], "").toLowerCase() === key)
                return true
        }

        return false
    }

    function isGameInFolder(game, folderId) {
        var key = ConfigLoader.normalizeString(folderId, "").toLowerCase()
        return key && (customFolderForGame(game) === key || isGameInAdditionalFolder(game, key))
    }

    function hasConfiguredFolderMembership(game) {
        var cardId = cardIdForGame(game)

        for (var folderIndex = 0; configuredFolders && folderIndex < configuredFolders.length; ++folderIndex) {
            var folder = configuredFolders[folderIndex]
            for (var gameIndex = 0; folder && folder.games && gameIndex < folder.games.length; ++gameIndex) {
                var configuredId = ConfigLoader.normalizeNumericId(folder.games[gameIndex] && folder.games[gameIndex].id
                                                                    ? folder.games[gameIndex].id : folder.games[gameIndex])
                if (configuredId && configuredId === cardId)
                    return true
            }
        }

        return false
    }

    function isGamePlacedInAnyFolder(game) {
        return !!customFolderForGame(game) || additionalFoldersForGame(game).length > 0 || hasConfiguredFolderMembership(game)
    }

    function orderForGameInFolder(game, folderId) {
        var key = ConfigLoader.normalizeString(folderId, "").toLowerCase()
        var folderOrders = game && game.folderOrders

        if (key && folderOrders && typeof folderOrders === "object" && folderOrders.hasOwnProperty(key)) {
            var scopedOrder = parseInt(folderOrders[key], 10)
            if (!isNaN(scopedOrder) && scopedOrder >= 0)
                return scopedOrder
        }

        // Existing single order values remain valid for their original custom
        // folder and are gradually complemented by scoped folderOrders on drop.
        if (game && game.hasCustomOrder && (key === "all" || customFolderForGame(game) === key))
            return game.customOrder

        return -1
    }

    function sortGamesByCustomOrder(games, folderId) {
        var indexed = []

        for (var i = 0; games && i < games.length; ++i) {
            indexed.push({
                game: games[i],
                index: i
            })
        }

        indexed.sort(function(left, right) {
            var leftOrder = orderForGameInFolder(left.game, folderId)
            var rightOrder = orderForGameInFolder(right.game, folderId)
            var leftHasOrder = leftOrder >= 0
            var rightHasOrder = rightOrder >= 0

            if (leftHasOrder && rightHasOrder && leftOrder !== rightOrder)
                return leftOrder - rightOrder

            if (leftHasOrder !== rightHasOrder)
                return leftHasOrder ? -1 : 1

            return left.index - right.index
        })

        var result = []

        for (var index = 0; index < indexed.length; ++index)
            result.push(indexed[index].game)

        return result
    }

    function indexOfCardId(games, cardId) {
        var key = ConfigLoader.normalizeString(cardId, "")

        for (var i = 0; games && i < games.length; ++i) {
            if (cardIdForGame(games[i]) === key)
                return i
        }

        return -1
    }

    function resetCardReorder() {
        reorderPreviewGames = null
        cardReorderActive = false
        cardReorderSaving = false
        cardReorderSourceId = ""
        cardReorderTargetId = ""
        cardReorderInsertAfter = false
        cardMoveSourceFolderId = ""
        cardMoveTargetFolderId = ""
        cardMoveChoiceOpen = false
        cardMoveChoiceCardId = ""
        cardMoveChoiceDestinationId = ""
        cardReorderOriginalGames = []
        cardReorderGame = null
        cardReorderPointerX = 0
        cardReorderPointerY = 0
        cardReorderPointerValid = false
    }

    function beginCardReorder(cardId) {
        var key = ConfigLoader.normalizeString(cardId, "")

        if (!editMode || cardEditorOpen || cardRemovalConfirmOpen || cardMoveChoiceOpen || cardReorderSaving || !key || !activeGames || !activeGames.length)
            return

        if (cardReorderActive)
            return

        var index = indexOfCardId(activeGames, key)
        if (index < 0)
            return

        cardReorderOriginalGames = activeGames.slice(0)
        reorderPreviewGames = activeGames.slice(0)
        cardReorderSourceId = key
        cardReorderTargetId = ""
        cardReorderInsertAfter = false
        var assignedFolderId = customFolderForGame(activeGames[index])
        cardMoveSourceFolderId = selectedFolderId === "all" && assignedFolderId ? assignedFolderId : selectedFolderId
        cardMoveTargetFolderId = ""
        cardReorderGame = activeGames[index]
        cardReorderPointerValid = false
        cardReorderError = ""
        cardReorderActive = true
    }

    function previewCardReorder(sourceCardId, targetCardId, insertAfter) {
        if (!cardReorderActive || sourceCardId !== cardReorderSourceId || !reorderPreviewGames)
            return

        if (sourceCardId === targetCardId)
            return

        var preview = reorderPreviewGames.slice(0)
        var fromIndex = indexOfCardId(preview, sourceCardId)
        var targetIndex = indexOfCardId(preview, targetCardId)
        if (fromIndex < 0 || targetIndex < 0)
            return

        var nextIndex = targetIndex + (insertAfter ? 1 : 0)
        var movingGame = preview.splice(fromIndex, 1)[0]
        if (fromIndex < nextIndex)
            nextIndex -= 1

        if (nextIndex === fromIndex) {
            cardReorderTargetId = targetCardId
            cardReorderInsertAfter = insertAfter
            return
        }

        preview.splice(nextIndex, 0, movingGame)
        reorderPreviewGames = preview
        cardReorderTargetId = targetCardId
        cardReorderInsertAfter = insertAfter
    }

    function clearCardReorderPreview(sourceCardId) {
        if (!cardReorderActive || sourceCardId !== cardReorderSourceId)
            return

        cardReorderTargetId = ""
        cardReorderInsertAfter = false
    }

    function selectCardReorderTarget(sourceCardId, targetCardId, insertAfter) {
        if (!cardReorderActive || sourceCardId !== cardReorderSourceId || sourceCardId === targetCardId) {
            clearCardReorderPreview(sourceCardId)
            return
        }

        cardReorderTargetId = targetCardId
        cardReorderInsertAfter = insertAfter
    }

    function previewCardReorderAt(sourceCardId, gridX, gridY) {
        if (!cardReorderActive || sourceCardId !== cardReorderSourceId)
            return

        cardReorderPointerX = gridX
        cardReorderPointerY = gridY
        cardReorderPointerValid = true

        if (!displayedGames || !displayedGames.length
                || gridX < -cardSpacing * 0.5 || gridX > gameGrid.width + cardSpacing * 0.5
                || gridY < -cardSpacing * 0.5 || gridY > gameGrid.height + cardSpacing * 0.5) {
            clearCardReorderPreview(sourceCardId)
            return
        }

        var sourceIndex = indexOfCardId(displayedGames, sourceCardId)
        if (sourceIndex >= 0) {
            var sourceColumn = sourceIndex % Math.max(1, gridColumns)
            var sourceRow = Math.floor(sourceIndex / Math.max(1, gridColumns))
            var sourceX = sourceColumn * (cardWidth + cardSpacing)
            var sourceY = sourceRow * (cardHeight + cardSpacing)

            if (gridX >= sourceX && gridX <= sourceX + cardWidth && gridY >= sourceY && gridY <= sourceY + cardHeight) {
                clearCardReorderPreview(sourceCardId)
                return
            }
        }

        var bestTargetCardId = ""
        var bestInsertAfter = false
        var bestDistance = -1
        var columnWidth = cardWidth + cardSpacing
        var rowHeight = cardHeight + cardSpacing

        for (var index = 0; index < displayedGames.length; ++index) {
            var candidateCardId = cardIdForGame(displayedGames[index])
            if (candidateCardId === sourceCardId)
                continue

            var column = index % Math.max(1, gridColumns)
            var row = Math.floor(index / Math.max(1, gridColumns))
            var cardX = column * columnWidth
            var cardCenterY = row * rowHeight + cardHeight * 0.5
            var beforeX = cardX - (column > 0 ? cardSpacing * 0.5 : 0)
            var afterX = cardX + cardWidth + (column < gridColumns - 1 ? cardSpacing * 0.5 : 0)
            var beforeDistance = Math.pow(gridX - beforeX, 2) + Math.pow(gridY - cardCenterY, 2)
            var afterDistance = Math.pow(gridX - afterX, 2) + Math.pow(gridY - cardCenterY, 2)

            if (bestDistance < 0 || beforeDistance < bestDistance) {
                bestDistance = beforeDistance
                bestTargetCardId = candidateCardId
                bestInsertAfter = false
            }
            if (afterDistance < bestDistance) {
                bestDistance = afterDistance
                bestTargetCardId = candidateCardId
                bestInsertAfter = true
            }
        }

        if (!bestTargetCardId) {
            clearCardReorderPreview(sourceCardId)
            return
        }

        selectCardReorderTarget(sourceCardId, bestTargetCardId, bestInsertAfter)
    }

    function handleCardReorderPointer(sourceCardId, gridX, gridY, sceneX, sceneY) {
        if (!cardReorderActive || sourceCardId !== cardReorderSourceId)
            return

        var folderId = folderSidebar.folderIdAtScenePosition(sceneX, sceneY)
        if (folderId) {
            cardMoveTargetFolderId = folderId
            cardReorderPointerValid = false
            clearCardReorderPreview(sourceCardId)
            return
        }

        cardMoveTargetFolderId = ""
        previewCardReorderAt(sourceCardId, gridX, gridY)
    }

    function cancelCardReorder() {
        if (!cardReorderActive || cardReorderSaving)
            return

        resetCardReorder()
    }

    function finishCardReorderGesture(cardId) {
        Qt.callLater(function() {
            if (cardReorderActive && !cardReorderSaving && !cardMoveChoiceOpen && cardReorderSourceId === cardId)
                cancelCardReorder()
        })
    }

    function commitCardReorderFromPointer(sourceCardId) {
        if (!cardReorderActive || cardReorderSaving || sourceCardId !== cardReorderSourceId)
            return

        if (cardMoveTargetFolderId) {
            var destinationId = cardMoveTargetFolderId
            var movedGame = findGameByCardId(sourceCardId)

            if (movedGame && destinationId !== "all" && !isGameInFolder(movedGame, destinationId)
                && isGamePlacedInAnyFolder(movedGame)) {
                cardMoveChoiceCardId = sourceCardId
                cardMoveChoiceDestinationId = destinationId
                cardMoveChoiceOpen = true
                cardMoveTargetFolderId = ""
                cardReorderPointerValid = false
                clearCardReorderPreview(sourceCardId)
            } else {
                commitCardMove(sourceCardId, destinationId)
            }
            return
        }

        if (!cardReorderTargetId) {
            cancelCardReorder()
            return
        }

        commitCardReorder(sourceCardId, cardReorderTargetId, cardReorderInsertAfter)
    }

    function commitCardReorder(sourceCardId, targetCardId, insertAfter) {
        if (!cardReorderActive || cardReorderSaving || sourceCardId !== cardReorderSourceId)
            return

        previewCardReorder(sourceCardId, targetCardId, insertAfter)

        if (!reorderPreviewGames || !cardReorderTargetId) {
            cancelCardReorder()
            return
        }

        var changed = false
        for (var originalIndex = 0; originalIndex < cardReorderOriginalGames.length; ++originalIndex) {
            if (cardIdForGame(cardReorderOriginalGames[originalIndex]) !== cardIdForGame(reorderPreviewGames[originalIndex])) {
                changed = true
                break
            }
        }
        if (!changed) {
            cancelCardReorder()
            return
        }

        var orders = []
        for (var i = 0; i < reorderPreviewGames.length; ++i) {
            orders.push({
                cardId: cardIdForGame(reorderPreviewGames[i]),
                order: i
            })
        }

        cardReorderTargetId = ""
        cardReorderPointerValid = false
        cardReorderSaving = true
        cardDataAction = "reorder"
        cardReorderError = ""

        if (!shortcutDiscovery.updateCardOrders({
            folderId: selectedFolderId,
            orders: orders
        })) {
            cardDataAction = ""
            cardReorderError = "ORDER SAVE IS TEMPORARILY UNAVAILABLE"
            resetCardReorder()
        }
    }

    function gamesWithoutCard(games, cardId) {
        var result = []

        for (var i = 0; games && i < games.length; ++i) {
            if (cardIdForGame(games[i]) !== cardId)
                result.push(games[i])
        }

        return result
    }

    function sequentialOrderEntries(games) {
        var result = []

        for (var i = 0; games && i < games.length; ++i)
            result.push({ cardId: cardIdForGame(games[i]), order: i })

        return result
    }

    function commitCardMove(sourceCardId, destinationFolderId) {
        var destinationId = ConfigLoader.normalizeString(destinationFolderId, "")
        var movedGame = findGameByCardId(sourceCardId)

        if (!movedGame || !destinationId || (destinationId !== "all" && !findConfiguredFolder(destinationId))) {
            cancelCardReorder()
            return
        }

        var configuredSourceId = customFolderForGame(movedGame)
        var sourceId = cardMoveSourceFolderId
        if (!sourceId)
            sourceId = "all"

        if (destinationId === sourceId || (destinationId === "all" && !configuredSourceId && selectedFolderId === "all")) {
            cancelCardReorder()
            return
        }

        var sourceGames = sourceId === selectedFolderId ? cardReorderOriginalGames.slice(0) : selectGamesForFolderId(sourceId)
        var destinationGames = gamesWithoutCard(selectGamesForFolderId(destinationId), sourceCardId)
        destinationGames.push(movedGame)

        // ALL is the system-wide aggregate: moving a card away does not remove
        // it from that view, but moving back to ALL places it at the end there.
        var sourceFinalGames = sourceId === "all" ? sourceGames : gamesWithoutCard(sourceGames, sourceCardId)

        cardReorderSaving = true
        cardDataAction = "move"
        cardReorderError = ""
        cardReorderPointerValid = false
        cardReorderTargetId = ""

        if (!shortcutDiscovery.moveCard(sourceCardId, {
            sourceFolderId: sourceId,
            destinationFolderId: destinationId,
            sourceOrders: sequentialOrderEntries(sourceFinalGames),
            destinationOrders: sequentialOrderEntries(destinationGames)
        })) {
            cardDataAction = ""
            cardReorderError = "MOVE IS TEMPORARILY UNAVAILABLE"
            resetCardReorder()
        }
    }

    function cancelCardMoveChoice() {
        if (cardReorderSaving)
            return

        cardMoveChoiceOpen = false
        cardMoveChoiceCardId = ""
        cardMoveChoiceDestinationId = ""
        resetCardReorder()
    }

    function confirmCardMoveChoice(copyCard) {
        if (!cardMoveChoiceOpen || cardReorderSaving || !cardMoveChoiceCardId || !cardMoveChoiceDestinationId)
            return

        var sourceCardId = cardMoveChoiceCardId
        var destinationId = cardMoveChoiceDestinationId
        cardMoveChoiceOpen = false
        cardMoveChoiceCardId = ""
        cardMoveChoiceDestinationId = ""

        if (copyCard)
            commitCardCopy(sourceCardId, destinationId)
        else
            commitCardMove(sourceCardId, destinationId)
    }

    function commitCardCopy(sourceCardId, destinationFolderId) {
        var destinationId = ConfigLoader.normalizeString(destinationFolderId, "")
        var copiedGame = findGameByCardId(sourceCardId)

        if (!copiedGame || !destinationId || destinationId === "all" || !findConfiguredFolder(destinationId)
                || isGameInFolder(copiedGame, destinationId)) {
            cancelCardReorder()
            return
        }

        var destinationGames = gamesWithoutCard(selectGamesForFolderId(destinationId), sourceCardId)
        destinationGames.push(copiedGame)

        cardReorderSaving = true
        cardDataAction = "copy"
        cardReorderError = ""
        cardReorderPointerValid = false
        cardReorderTargetId = ""

        if (!shortcutDiscovery.copyCardToFolder(sourceCardId, {
            destinationFolderId: destinationId,
            destinationOrders: sequentialOrderEntries(destinationGames)
        })) {
            cardDataAction = ""
            cardReorderError = "COPY IS TEMPORARILY UNAVAILABLE"
            resetCardReorder()
        }
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

        for (i = 0; widget.discoveredGames && i < widget.discoveredGames.length; ++i) {
            var discoveredGame = withCardUserData(ConfigLoader.withResolvedSubtitle(widget.discoveredGames[i], null, widget.subtitleModel, widget.syncSubtitle))

            if (!discoveredGame.isHidden)
                result.push(discoveredGame)
        }

        for (i = 0; widget.legacyGames && i < widget.legacyGames.length; ++i) {
            var legacyGame = withCardUserData(widget.legacyGames[i])

            if (!legacyGame.isHidden)
                result.push(legacyGame)
        }

        var storedCardData = shortcutDiscovery.cardData || ({})
        for (var storedCardId in storedCardData) {
            var storedData = getCardUserData(storedCardId)
            if (!storedData.sourcePath || storedData.isHidden)
                continue

            var alreadyPresent = false
            for (var resultIndex = 0; resultIndex < result.length; ++resultIndex) {
                if (normalizeSourcePath(sourcePathForGame(result[resultIndex])) === normalizeSourcePath(storedData.sourcePath)) {
                    alreadyPresent = true
                    break
                }
            }
            if (alreadyPresent)
                continue

            result.push(withCardUserData({
                id: storedCardId,
                cardId: storedCardId,
                title: storedData.automaticTitle || "GAME",
                shortcut: storedData.launchPath || storedData.sourcePath,
                sourcePath: storedData.sourcePath,
                targetPath: storedData.targetPath,
                launchPath: storedData.launchPath,
                sourceType: storedData.sourceType,
                image: "assets/placeholder.png",
                automaticImage: "assets/placeholder.png"
            }))
        }

        return result
    }

    function buildFolderList() {
        var result = [{
            id: "all",
            displayName: folderOverrideFor("all").customTitle || "ALL",
            icon: folderOverrideFor("all").customIcon || "folder-icons/default.png",
            fallbackIcon: "folder-icons/default.png",
            system: true
        }]

        for (var i = 0; widget.configuredFolders && i < widget.configuredFolders.length; ++i) {
            var folder = widget.configuredFolders[i]
            var override = folderOverrideFor(folder.id)
            var renderedFolder = {}
            for (var key in folder) {
                if (folder.hasOwnProperty(key))
                    renderedFolder[key] = folder[key]
            }
            renderedFolder.displayName = override.customTitle || folder.displayName
            renderedFolder.icon = override.customIcon || folder.icon
            renderedFolder.maxColumns = override.maxColumns || folder.maxColumns
            result.push(renderedFolder)
        }

        return result
    }

    function folderOverrideFor(folderId) {
        var key = ConfigLoader.normalizeString(folderId, "").toLowerCase()
        var source = key && folderOverrides ? folderOverrides[key] : null
        return {
            customTitle: ConfigLoader.normalizeString(source && source.customTitle, ""),
            customIcon: ConfigLoader.normalizeString(source && source.customIcon, ""),
            maxColumns: parseInt(source && source.maxColumns, 10) || 0
        }
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
        return selectGamesForFolderId(widget.selectedFolderId)
    }

    function selectGamesForFolderId(folderId) {
        var selectedId = ConfigLoader.normalizeString(folderId, "all") || "all"

        if (selectedId === "all")
            return sortGamesByCustomOrder(widget.allGames, "all")

        var folder = findConfiguredFolder(selectedId)

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

            if (game && !isGameExcludedFromFolder(game, selectedId)
                    && (!customFolderForGame(game) || customFolderForGame(game) === selectedId
                        || isGameInAdditionalFolder(game, selectedId)) && !seen[cardId]) {
                seen[cardId] = true
                result.push(withCustomDescription(ConfigLoader.withResolvedSubtitle(game, folderGame, widget.subtitleModel, widget.syncSubtitle)))
            }
        }

        for (var gameIndex = 0; widget.allGames && gameIndex < widget.allGames.length; ++gameIndex) {
            var customFolderGame = widget.allGames[gameIndex]

            var customCardId = cardIdForGame(customFolderGame)

            if ((customFolderForGame(customFolderGame) === selectedId
                 || isGameInAdditionalFolder(customFolderGame, selectedId)) && !seen[customCardId]) {
                seen[customCardId] = true
                result.push(customFolderGame)
            }
        }

        return sortGamesByCustomOrder(result, selectedId)
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
        cardEditorOpen = false
        cardEditorSaving = false
        cardEditorSaveError = ""
        editorImagePendingSource = ""
        editorImageDropActive = false
        editorIsNewCard = false
        editorNewCardDraft = null
        editorSourcePath = ""
        resetCardReorder()
        cardReorderError = ""
        cardDataAction = ""
        cardRemovalConfirmOpen = false
        cardRemovalSaving = false
        cardRemovalCardId = ""
        cardRemovalTitle = ""
        cardRemovalError = ""

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

        editMode = false
        editorCardId = ""
        cardEditorOpen = false
        cardEditorSaving = false
        cardEditorSaveError = ""
        editorImagePendingSource = ""
        editorImageDropActive = false
        resetCardReorder()
        cardReorderError = ""
        cardDataAction = ""
        cardRemovalConfirmOpen = false
        cardRemovalSaving = false
        cardRemovalCardId = ""
        cardRemovalTitle = ""
        cardRemovalError = ""
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
        if (editMode || cardEditorOpen || cardRemovalConfirmOpen || cardMoveChoiceOpen || closing || launching)
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
        onCardDataUpdateFinished: widget.handleCardDataUpdateFinished(cardId, success, error)
        onManualCardPrepared: widget.handleManualCardPrepared(draft, error)
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
        editMode = false
        editorCardId = ""
        cardEditorOpen = false
        cardEditorSaving = false
        cardRemovalConfirmOpen = false
        cardRemovalSaving = false
        cardRemovalCardId = ""
        cardDataAction = ""
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
        border.width: widget.editMode ? 1 : 0
        border.color: "#6EDDF7FF"
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
            text: widget.cardReorderError ? widget.cardReorderError
                                  : (widget.fileDropStatus ? widget.fileDropStatus
                                  : (widget.editMode ? (widget.editorCardId ? "EDIT CARD // " + widget.editorCardId : "EDIT MODE")
                                  : (widget.launchFailed ? "LAUNCH FAILED // " + widget.launchingTitle
                                                         : (widget.launching ? "LAUNCHING // " + widget.launchingTitle : "READY"))))
            color: widget.cardReorderError ? "#FFFFB4B4" : (widget.editMode ? "#DDF7FFFF" : (widget.launchFailed ? "#FFFFB4B4" : (widget.launching ? "#E9FFFFFF" : "#6FFFFFFF")))
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
                editMode: widget.editMode
                cardDragActive: widget.cardReorderActive && !widget.cardReorderSaving
                cardDragSourceFolderId: widget.cardMoveSourceFolderId
                cardDragTargetFolderId: widget.cardMoveTargetFolderId
                onFolderSelected: widget.selectedFolderId = folderId
                onOpenShortcutsRequested: widget.requestOpenShortcutsFolder()
                onSettingsRequested: widget.openSettings()
                onFolderEditRequested: widget.openFolderEditor(folderId)
                onFolderCreateRequested: widget.openFolderCreate()
                onReloadRequested: widget.requestManualReload()
                onEditModeRequested: widget.toggleEditMode()
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

                Item {
                    id: gameGrid

                    width: gameFlickable.width
                    height: widget.gameCount > 0
                            ? Math.ceil(widget.gameCount / Math.max(1, widget.gridColumns)) * widget.cardHeight
                              + Math.max(0, Math.ceil(widget.gameCount / Math.max(1, widget.gridColumns)) - 1) * widget.cardSpacing
                            : 0

                    Repeater {
                        // Keep one visual item per stable card ID.  Reordering then
                        // changes only x/y, so applying saved state cannot swap card
                        // contents back by index after the first animation.
                        model: widget.allGames && widget.allGames.length ? widget.allGames.length : 0

                        GameCard {
                            property string stableCardId: widget.cardIdForGame(widget.allGames[index])
                            property int layoutIndex: widget.indexOfCardId(widget.displayedGames, stableCardId)
                            property var renderedGame: layoutIndex >= 0 ? widget.displayedGames[layoutIndex] : widget.allGames[index]

                            width: widget.cardWidth
                            height: widget.cardHeight
                            x: layoutIndex >= 0 ? (layoutIndex % Math.max(1, widget.gridColumns)) * (widget.cardWidth + widget.cardSpacing) : 0
                            y: layoutIndex >= 0 ? Math.floor(layoutIndex / Math.max(1, widget.gridColumns)) * (widget.cardHeight + widget.cardSpacing) : 0
                            z: reorderDragging ? 2 : 1
                            visible: layoutIndex >= 0
                            game: renderedGame
                            cardId: stableCardId
                            gameNumber: layoutIndex + 1
                            hoverZoom: widget.hoverZoom
                            editMode: widget.editMode
                            reorderEnabled: !widget.cardEditorOpen && !widget.cardRemovalConfirmOpen && !widget.cardMoveChoiceOpen && !widget.cardReorderSaving
                            reorderDragging: widget.cardReorderActive && !widget.cardReorderSaving && widget.cardReorderSourceId === cardId
                            enabled: !widget.launching && !widget.closing
                            onLaunchRequested: {
                                if (!widget.editMode)
                                    widget.launchShortcut(game)
                            }
                            onEditRequested: widget.openCardEditor(requestedCardId)
                            onRemoveRequested: widget.requestCardRemoval(requestedCardId)
                            onReorderStarted: widget.beginCardReorder(requestedCardId)
                            onReorderPointerMoved: widget.handleCardReorderPointer(requestedCardId, gridX, gridY, sceneX, sceneY)
                            onReorderDropped: widget.commitCardReorderFromPointer(requestedCardId)
                            onReorderFinished: widget.finishCardReorderGesture(requestedCardId)
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: gameFlickable.contentHeight > gameFlickable.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }
            }

            Item {
                id: reorderGhostLayer

                anchors.left: gameFlickable.left
                anchors.right: gameFlickable.right
                anchors.top: gameFlickable.top
                anchors.bottom: gameFlickable.bottom
                clip: true
                z: 4
                visible: widget.cardReorderActive && widget.cardReorderPointerValid && widget.cardReorderGame

                property int insertionTargetIndex: widget.cardReorderTargetId
                                                   ? widget.indexOfCardId(widget.displayedGames, widget.cardReorderTargetId) : -1
                property int insertionColumn: insertionTargetIndex >= 0
                                              ? insertionTargetIndex % Math.max(1, widget.gridColumns) : 0
                property int insertionRow: insertionTargetIndex >= 0
                                           ? Math.floor(insertionTargetIndex / Math.max(1, widget.gridColumns)) : 0

                Rectangle {
                    visible: parent.insertionTargetIndex >= 0
                    x: parent.insertionColumn * (widget.cardWidth + widget.cardSpacing)
                       + (widget.cardReorderInsertAfter
                          ? widget.cardWidth + (parent.insertionColumn < widget.gridColumns - 1 ? widget.cardSpacing * 0.5 : 0)
                          : -(parent.insertionColumn > 0 ? widget.cardSpacing * 0.5 : 0))
                       - width * 0.5
                    y: parent.insertionRow * (widget.cardHeight + widget.cardSpacing) - gameFlickable.contentY + 9
                    width: 3
                    height: Math.max(26, widget.cardHeight - 26)
                    radius: 1.5
                    color: "#B8E8F7FF"
                    z: 3
                }

                Rectangle {
                    z: 1
                    width: widget.cardWidth
                    height: widget.cardHeight
                    x: widget.cardReorderPointerX - width * 0.5
                    y: widget.cardReorderPointerY - gameFlickable.contentY - height * 0.5
                    radius: 10
                    clip: true
                    color: "#D0142634"
                    border.width: 2
                    border.color: "#E6DDF7FF"
                    opacity: 0.88

                    Image {
                        anchors.fill: parent
                        source: widget.cardImagePreviewSource(widget.cardReorderGame)
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        smooth: true
                        opacity: 0.78
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Math.max(46, parent.height * 0.28)
                        color: "#C707111A"
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 13
                        anchors.right: parent.right
                        anchors.rightMargin: 13
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 18
                        text: widget.cardReorderGame && widget.cardReorderGame.title ? widget.cardReorderGame.title : "GAME"
                        color: "#FFFFFFFF"
                        font.pixelSize: 20
                        font.bold: true
                        font.letterSpacing: 1.2
                        elide: Text.ElideRight
                    }
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
                        text: widget.selectedFolderId === "all" ? "DROP .LNK, .URL OR .EXE IN EDIT MODE" : "CHECK FOLDER GAME NAMES IN CONFIG"
                        color: "#8ED7E6F0"
                        font.pixelSize: 8
                        font.letterSpacing: 1.0
                    }
                }
            }
        }

        DropArea {
            id: gameFileDropArea

            anchors.fill: parent
            z: 6
            enabled: !widget.cardEditorOpen && !widget.folderEditorOpen && !widget.cardRemovalConfirmOpen && !widget.cardMoveChoiceOpen && !widget.cardEditorSaving

            onEntered: {
                if (drag.hasUrls) {
                    widget.fileDropActive = true
                    drag.accepted = true
                }
            }

            onExited: widget.fileDropActive = false

            onDropped: {
                drop.accepted = true
                widget.requestManualFileDrop(drop.urls)
            }

            Rectangle {
                anchors.fill: parent
                visible: widget.fileDropActive
                radius: panel.radius
                color: "#A0142634"
                border.width: 1
                border.color: widget.editMode ? "#DDF7FFFF" : "#FFFFC0A0"
            }

            Text {
                anchors.centerIn: parent
                visible: widget.fileDropActive
                text: widget.editMode ? "DROP ONE .LNK, .URL OR .EXE TO ADD A GAME"
                                      : "ENABLE EDIT MODE TO ADD A GAME"
                color: "#FFFFFFFF"
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 1.0
            }
        }

        Item {
            id: cardEditorOverlay

            anchors.fill: parent
            visible: widget.cardEditorOpen
            focus: visible
            z: 10

            onVisibleChanged: {
                if (visible)
                    forceActiveFocus()
            }

            Keys.onEscapePressed: {
                widget.cancelCardEditor()
                event.accepted = true
            }

            Rectangle {
                anchors.fill: parent
                color: "#B7141A24"
            }

            MouseArea {
                anchors.fill: parent
                enabled: cardEditorOverlay.visible && !widget.cardEditorSaving
                onClicked: widget.cancelCardEditor()
            }

            Rectangle {
                id: cardEditorPanel

                anchors.centerIn: parent
                width: Math.min(parent.width - 56, 560)
                height: Math.min(parent.height - 44, 350)
                radius: 10
                color: "#F01A222E"
                border.width: 1
                border.color: "#8ADDF7FF"

                // Consume clicks inside the editor so they never reach a card.
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 38
                    radius: parent.radius
                    color: "#191F2A36"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: (widget.editorIsNewCard ? "ADD GAME // " : "CARD EDITOR // ") + widget.editorCardId
                        color: "#F4FFFFFF"
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.4
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        radius: 4
                        color: editorCloseMouse.containsMouse ? "#22FFFFFF" : "#08FFFFFF"
                        border.width: editorCloseMouse.containsMouse ? 1 : 0
                        border.color: "#99FFFFFF"

                        Text {
                            anchors.centerIn: parent
                            text: "\u00d7"
                            color: "#EFFFFFFF"
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: editorCloseMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !widget.cardEditorSaving
                            onClicked: widget.cancelCardEditor()
                        }
                    }
                }

                Text {
                    x: 18
                    y: 51
                    text: "IMAGE"
                    color: "#9ED7E6F0"
                    font.pixelSize: 8
                    font.bold: true
                    font.letterSpacing: 1.1
                }

                Rectangle {
                    id: editorImageDropTarget

                    x: 18
                    y: 65
                    width: 128
                    height: 104
                    radius: 5
                    clip: true
                    color: "#1CFFFFFF"
                    border.width: 1
                    border.color: widget.editorImageDropActive ? "#DDF7FFFF" : "#36FFFFFF"

                    Image {
                        anchors.fill: parent
                        visible: !widget.editorUsesPlaceholder()
                        source: widget.editorPreviewSource
                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        smooth: true

                        onStatusChanged: {
                            if (status === Image.Error)
                                widget.advanceEditorPreviewFallback()
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: widget.editorUsesPlaceholder() && !widget.editorImageDropActive
                        spacing: 3

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "DROP IMAGE"
                            color: "#CBEAF5FF"
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 0.9
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "16:9 RECOMMENDED"
                            color: "#88C8D8E8"
                            font.pixelSize: 6
                            font.letterSpacing: 0.45
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        enabled: widget.cardEditorOpen && !widget.cardEditorSaving

                        onEntered: {
                            if (drag.hasUrls) {
                                widget.editorImageDropActive = true
                                drag.accepted = true
                            }
                        }

                        onExited: widget.editorImageDropActive = false

                        onDropped: {
                            widget.editorImageDropActive = false
                            drop.accepted = true

                            if (!drop.hasUrls || drop.urls.length !== 1) {
                                widget.cardEditorSaveError = "DROP ONE PNG, JPG, JPEG OR WEBP IMAGE"
                                return
                            }

                            widget.chooseEditorImage(String(drop.urls[0]))
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: widget.editorImageDropActive
                            color: "#7A102534"
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: widget.editorImageDropActive
                            text: "DROP IMAGE"
                            color: "#FFFFFFFF"
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 1.0
                        }
                    }
                }

                Text {
                    x: 18
                    y: 176
                    width: 128
                    text: widget.editorImageDraft ? "CUSTOM IMAGE" : "AUTOMATIC IMAGE"
                    color: widget.editorImageDraft ? "#DDF7FFFF" : "#8ED7E6F0"
                    font.pixelSize: 7
                    font.letterSpacing: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                Text {
                    x: 18
                    y: 192
                    text: "IMAGE PATH"
                    color: "#9ED7E6F0"
                    font.pixelSize: 7
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                TextField {
                    id: editorImagePathField

                    x: 18
                    y: 204
                    width: 128
                    height: 27
                    placeholderText: "PNG / JPG / WEBP"
                    color: "#F4FFFFFF"
                    placeholderTextColor: "#AFC6D9E7"
                    font.pixelSize: 8
                    selectByMouse: true
                    enabled: !widget.cardEditorSaving
                    leftPadding: 8
                    rightPadding: 8
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    background: Rectangle {
                        radius: 4
                        color: "#4208121E"
                        border.width: 1
                        border.color: editorImagePathField.activeFocus ? "#B8DDF7FF" : "#668FA9BA"
                    }
                }

                Rectangle {
                    x: 18
                    y: 237
                    width: 60
                    height: 25
                    radius: 4
                    color: chooseImageMouse.containsMouse ? "#22FFFFFF" : "#08FFFFFF"
                    border.width: chooseImageMouse.containsMouse ? 1 : 0
                    border.color: "#99FFFFFF"
                    opacity: widget.cardEditorSaving ? 0.5 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "PREVIEW"
                        color: "#EFFFFFFF"
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 0.8
                    }

                    MouseArea {
                        id: chooseImageMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !widget.cardEditorSaving
                        onClicked: widget.previewEditorImagePath()
                    }
                }

                Rectangle {
                    x: 86
                    y: 237
                    width: 60
                    height: 25
                    radius: 4
                    color: resetImageMouse.containsMouse ? "#22FFFFFF" : "#08FFFFFF"
                    border.width: resetImageMouse.containsMouse ? 1 : 0
                    border.color: "#99FFFFFF"
                    opacity: widget.cardEditorSaving ? 0.5 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "RESET"
                        color: "#BDE6F5FF"
                        font.pixelSize: 8
                        font.letterSpacing: 0.8
                    }

                    MouseArea {
                        id: resetImageMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !widget.cardEditorSaving
                        onClicked: widget.resetEditorImage()
                    }
                }

                Text {
                    x: 166
                    y: 51
                    width: parent.width - x - 18
                    text: "DISPLAY NAME // EMPTY USES AUTOMATIC"
                    color: "#9ED7E6F0"
                    font.pixelSize: 8
                    font.bold: true
                    font.letterSpacing: 0.9
                    elide: Text.ElideRight
                }

                TextField {
                    id: editorTitleField

                    x: 166
                    y: 65
                    width: parent.width - x - 18
                    height: 32
                    maximumLength: 120
                    placeholderText: widget.editorAutomaticTitle
                    color: "#F4FFFFFF"
                    placeholderTextColor: "#C9D9E7F0"
                    font.pixelSize: 13
                    selectByMouse: true
                    enabled: !widget.cardEditorSaving
                    leftPadding: 10
                    rightPadding: 10
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    background: Rectangle {
                        radius: 4
                        color: "#4208121E"
                        border.width: 1
                        border.color: editorTitleField.activeFocus ? "#B8DDF7FF" : "#668FA9BA"
                    }
                }

                Text {
                    x: 166
                    y: 101
                    width: parent.width - x - 18
                    text: widget.editorIsNewCard ? "SOURCE // " + widget.editorSourcePath : "AUTO // " + widget.editorAutomaticTitle
                    color: "#6ED7E6F0"
                    font.pixelSize: 7
                    font.letterSpacing: 0.7
                    elide: Text.ElideRight
                }

                Text {
                    x: 166
                    y: 116
                    text: "DESCRIPTION // OPTIONAL"
                    color: "#9ED7E6F0"
                    font.pixelSize: 8
                    font.bold: true
                    font.letterSpacing: 0.9
                }

                TextArea {
                    id: editorDescriptionField

                    x: 166
                    y: 130
                    width: parent.width - x - 18
                    height: 119
                    clip: true
                    wrapMode: TextEdit.Wrap
                    placeholderText: "OPTIONAL DESCRIPTION"
                    color: "#F4FFFFFF"
                    placeholderTextColor: "#B9D1E1ED"
                    font.pixelSize: 12
                    selectByMouse: true
                    enabled: !widget.cardEditorSaving
                    padding: 8
                    background: Rectangle {
                        radius: 4
                        color: "#4208121E"
                        border.width: 1
                        border.color: editorDescriptionField.activeFocus ? "#B8DDF7FF" : "#668FA9BA"
                    }

                    onTextChanged: {
                        if (text.length > 600)
                            text = text.slice(0, 600)
                    }
                }

                Text {
                    x: 18
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 17
                    width: parent.width - 238
                    text: widget.cardEditorSaveError || (widget.cardEditorSaving ? "SAVING CARD DATA..." : "")
                    color: widget.cardEditorSaveError ? "#FFFFB4B4" : "#BDE6F5FF"
                    font.pixelSize: 8
                    font.letterSpacing: 0.8
                    elide: Text.ElideRight
                }

                Rectangle {
                    anchors.right: cancelEditorButton.left
                    anchors.rightMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    width: 82
                    height: 29
                    radius: 4
                    color: saveEditorMouse.containsMouse ? "#48DDF7FF" : "#28DDF7FF"
                    border.width: 1
                    border.color: "#BCEFFFFF"
                    opacity: widget.cardEditorSaving ? 0.65 : 1

                    Text {
                        anchors.centerIn: parent
                        text: widget.cardEditorSaving ? "SAVING" : (widget.editorIsNewCard ? "ADD" : "SAVE")
                        color: "#FFFFFFFF"
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 1.0
                    }

                    MouseArea {
                        id: saveEditorMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !widget.cardEditorSaving
                        onClicked: widget.saveCardEditor()
                    }
                }

                Rectangle {
                    id: cancelEditorButton

                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    width: 82
                    height: 29
                    radius: 4
                    color: cancelEditorMouse.containsMouse ? "#22FFFFFF" : "#08FFFFFF"
                    border.width: cancelEditorMouse.containsMouse ? 1 : 0
                    border.color: "#99FFFFFF"
                    opacity: widget.cardEditorSaving ? 0.5 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "CANCEL"
                        color: "#EFFFFFFF"
                        font.pixelSize: 8
                        font.letterSpacing: 1.0
                    }

                    MouseArea {
                        id: cancelEditorMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !widget.cardEditorSaving
                        onClicked: widget.cancelCardEditor()
                    }
                }
            }
        }

        /* Temporarily disabled settings, folder editor, and recovery overlays. */
        /*
        Item {
            id: settingsOverlay
            anchors.fill: parent
            visible: widget.settingsOpen
            z: 14
            focus: visible
            Keys.onEscapePressed: { widget.closeSettings(); event.accepted = true }
            Rectangle { anchors.fill: parent; color: "#B7141A24" }
            MouseArea {
                anchors.fill: parent
                enabled: !widget.settingsSaving
                hoverEnabled: true
                onClicked: widget.closeSettings()
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 56, 430)
                height: 298
                radius: 10
                color: "#F01A222E"
                border.width: 1
                border.color: "#9EDDF7FF"
                MouseArea { anchors.fill: parent; onClicked: {} }

                Text { x: 18; y: 18; text: "WIDGET SETTINGS"; color: "#E4E8F7FF"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.3 }
                Text { x: 18; y: 57; text: "START HIDDEN"; color: "#A8D7E6F0"; font.pixelSize: 9; font.bold: true }
                Rectangle {
                    x: 285; y: 49; width: 76; height: 24; radius: 4
                    color: widget.settingsStartHiddenDraft ? "#263E50" : "#101A2733"
                    border.width: 1; border.color: "#8DDDF7FF"
                    Text { anchors.centerIn: parent; text: widget.settingsStartHiddenDraft ? "ON" : "OFF"; color: "#EFFFFFFF"; font.pixelSize: 8; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: widget.settingsStartHiddenDraft = !widget.settingsStartHiddenDraft }
                }
                Text { x: 18; y: 96; text: "MAX COLUMNS"; color: "#A8D7E6F0"; font.pixelSize: 9; font.bold: true }
                TextField {
                    id: settingsColumnsField
                    x: 18; y: 111; width: 110; height: 31
                    color: "#F4FFFFFF"; font.pixelSize: 12
                    selectByMouse: true; inputMethodHints: Qt.ImhDigitsOnly
                    background: Rectangle { radius: 4; color: "#161F2B"; border.width: 1; border.color: "#8BAFC0" }
                }
                Text { x: 18; y: 157; text: "SYNC SUBTITLE"; color: "#A8D7E6F0"; font.pixelSize: 9; font.bold: true }
                Rectangle {
                    x: 285; y: 149; width: 76; height: 24; radius: 4
                    color: widget.settingsSyncSubtitleDraft ? "#263E50" : "#101A2733"
                    border.width: 1; border.color: "#8DDDF7FF"
                    Text { anchors.centerIn: parent; text: widget.settingsSyncSubtitleDraft ? "ON" : "OFF"; color: "#EFFFFFFF"; font.pixelSize: 8; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: widget.settingsSyncSubtitleDraft = !widget.settingsSyncSubtitleDraft }
                }
                Text { x: 18; y: 198; text: widget.settingsError; color: "#FFFFB4B4"; font.pixelSize: 8 }
                Rectangle { x: 18; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; width: 92; height: 29; radius: 4; color: shortcutsMouse.containsMouse ? "#22FFFFFF" : "#101A2733"; Text { anchors.centerIn: parent; text: "FOLDERS"; color: "#DDECF7FF"; font.pixelSize: 8; font.bold: true }; MouseArea { id: shortcutsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: widget.requestOpenShortcutsFolder() } }
                Rectangle { x: 118; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; width: 92; height: 29; radius: 4; color: recoveryMouse.containsMouse ? "#22FFFFFF" : "#101A2733"; Text { anchors.centerIn: parent; text: "RESTORE"; color: "#DDECF7FF"; font.pixelSize: 8; font.bold: true }; MouseArea { id: recoveryMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: widget.recoveryOpen = true } }
                Rectangle { anchors.right: saveSettingsButton.left; anchors.rightMargin: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; width: 82; height: 29; radius: 4; color: cancelSettingsMouse.containsMouse ? "#22FFFFFF" : "#101A2733"; Text { anchors.centerIn: parent; text: "CANCEL"; color: "#DDECF7FF"; font.pixelSize: 8; font.bold: true }; MouseArea { id: cancelSettingsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !widget.settingsSaving; onClicked: widget.closeSettings() } }
                Rectangle { id: saveSettingsButton; anchors.right: parent.right; anchors.rightMargin: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; width: 82; height: 29; radius: 4; color: "#263E50"; border.width: 1; border.color: "#B8F2FDFF"; Text { anchors.centerIn: parent; text: widget.settingsSaving ? "SAVING" : "SAVE"; color: "#FFFFFFFF"; font.pixelSize: 8; font.bold: true }; MouseArea { anchors.fill: parent; enabled: !widget.settingsSaving; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: widget.saveSettings() } }
            }
        }

        Item {
            id: folderEditorOverlay
            anchors.fill: parent
            visible: widget.folderEditorOpen
            z: 15
            focus: visible
            Keys.onEscapePressed: { widget.folderEditorOpen = false; event.accepted = true }
            Rectangle { anchors.fill: parent; color: "#B7141A24" }
            MouseArea { anchors.fill: parent; onClicked: widget.folderEditorOpen = false }
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 56, 430)
                height: 258
                radius: 10; color: "#F01A222E"; border.width: 1; border.color: "#9EDDF7FF"
                MouseArea { anchors.fill: parent; onClicked: {} }
                Text { x: 18; y: 18; text: "FOLDER EDITOR // " + widget.folderEditorId; color: "#E4E8F7FF"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.1 }
                Text { x: 18; y: 54; text: "DISPLAY NAME // EMPTY USES AUTOMATIC"; color: "#A8D7E6F0"; font.pixelSize: 8; font.bold: true }
                TextField { id: folderEditorTitleField; x: 18; y: 69; width: parent.width - 36; height: 31; color: "#F4FFFFFF"; font.pixelSize: 12; selectByMouse: true; background: Rectangle { radius: 4; color: "#161F2B"; border.width: 1; border.color: "#8BAFC0" } }
                Text { x: 18; y: 117; text: "MAX COLUMNS // EMPTY USES GLOBAL (" + widget.maxColumns + ")"; color: "#A8D7E6F0"; font.pixelSize: 8; font.bold: true }
                TextField { id: folderEditorColumnsField; x: 18; y: 132; width: 110; height: 31; color: "#F4FFFFFF"; font.pixelSize: 12; selectByMouse: true; inputMethodHints: Qt.ImhDigitsOnly; background: Rectangle { radius: 4; color: "#161F2B"; border.width: 1; border.color: "#8BAFC0" } }
                Text { x: 18; y: 180; text: widget.folderEditorError; color: "#FFFFB4B4"; font.pixelSize: 8 }
                Rectangle { anchors.right: folderSaveButton.left; anchors.rightMargin: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; width: 82; height: 29; radius: 4; color: "#101A2733"; Text { anchors.centerIn: parent; text: "CANCEL"; color: "#DDECF7FF"; font.pixelSize: 8; font.bold: true }; MouseArea { anchors.fill: parent; onClicked: widget.folderEditorOpen = false } }
                Rectangle { id: folderSaveButton; anchors.right: parent.right; anchors.rightMargin: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; width: 82; height: 29; radius: 4; color: "#263E50"; border.width: 1; border.color: "#B8F2FDFF"; Text { anchors.centerIn: parent; text: "SAVE"; color: "#FFFFFFFF"; font.pixelSize: 8; font.bold: true }; MouseArea { anchors.fill: parent; onClicked: widget.saveFolderEditor() } }
            }
        }

        Item {
            id: recoveryOverlay
            anchors.fill: parent
            visible: widget.recoveryOpen
            z: 16
            focus: visible
            Keys.onEscapePressed: { widget.recoveryOpen = false; event.accepted = true }
            Rectangle { anchors.fill: parent; color: "#B7141A24" }
            MouseArea { anchors.fill: parent; onClicked: widget.recoveryOpen = false }
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 56, 500)
                height: 300
                radius: 10; color: "#F01A222E"; border.width: 1; border.color: "#9EDDF7FF"
                MouseArea { anchors.fill: parent; onClicked: {} }
                Text { x: 18; y: 18; text: "RESTORE CARDS"; color: "#E4E8F7FF"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.3 }
                Text { x: 18; y: 39; text: "Hidden cards stay stored locally until restored."; color: "#A8D7E6F0"; font.pixelSize: 8 }
                Flickable {
                    x: 18; y: 60; width: parent.width - 36; height: 184; clip: true
                    contentHeight: restoreColumn.height
                    Column {
                        id: restoreColumn; width: parent.width; spacing: 6
                        Repeater {
                            model: widget.hiddenCardIds()
                            Rectangle {
                                width: restoreColumn.width; height: 40; radius: 4; color: "#121D28"; border.width: 1; border.color: "#294454"
                                property string restoredCardId: modelData
                                property var restoredData: widget.getCardUserData(restoredCardId)
                                Text { x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 115; text: (restoredData.customTitle || restoredData.automaticTitle || "GAME") + " // " + (restoredData.sourcePath || "SOURCE NOT AVAILABLE"); color: "#DDECF7FF"; font.pixelSize: 8; elide: Text.ElideRight }
                                Rectangle { anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; width: 82; height: 25; radius: 3; color: "#263E50"; border.width: 1; border.color: "#8DDDF7FF"; Text { anchors.centerIn: parent; text: "RESTORE"; color: "#FFFFFFFF"; font.pixelSize: 7; font.bold: true }; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: widget.restoreCard(parent.parent.restoredCardId) } }
                            }
                        }
                        Text { visible: !widget.hiddenCardIds().length; text: "NO HIDDEN CARDS"; color: "#A8D7E6F0"; font.pixelSize: 9 }
                    }
                }
                Rectangle { anchors.right: parent.right; anchors.rightMargin: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; width: 82; height: 29; radius: 4; color: "#101A2733"; Text { anchors.centerIn: parent; text: "CLOSE"; color: "#DDECF7FF"; font.pixelSize: 8; font.bold: true }; MouseArea { anchors.fill: parent; onClicked: widget.recoveryOpen = false } }
            }
        }

        */
        /* Replaced by the active folder editor in create mode. */
        /*
        Item {
            id: folderCreateOverlay
            anchors.fill: parent
            visible: widget.folderCreateOpen
            focus: visible
            z: 18
            onVisibleChanged: {
                if (visible) {
                    folderCreateNameField.text = ""
                    folderCreateNameField.forceActiveFocus()
                }
            }
            Keys.onEscapePressed: { widget.folderCreateOpen = false; event.accepted = true }
            Rectangle { anchors.fill: parent; color: "#B7141A24" }
            MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: widget.folderCreateOpen = false }
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 56, 400)
                height: 182
                radius: 10
                color: "#F01A222E"
                border.width: 1
                border.color: "#9EDDF7FF"
                MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: {} }
                Text { x: 18; y: 18; text: "ADD FOLDER"; color: "#E4E8F7FF"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.2 }
                Text { x: 18; y: 54; text: "DISPLAY NAME"; color: "#A8D7E6F0"; font.pixelSize: 8; font.bold: true }
                TextField {
                    id: folderCreateNameField
                    x: 18; y: 69; width: parent.width - 36; height: 31
                    color: "#F4FFFFFF"; font.pixelSize: 12
                    leftPadding: 9; rightPadding: 9; topPadding: 0; bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    background: Rectangle { radius: 4; color: "#161F2B"; border.width: 1; border.color: "#8BAFC0" }
                }
                Text { x: 18; y: 116; text: widget.folderCreateError; color: "#FFFFB4B4"; font.pixelSize: 8 }
                Rectangle { anchors.right: createFolderSaveButton.left; anchors.rightMargin: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; width: 82; height: 29; radius: 4; color: "#101A2733"; Text { anchors.centerIn: parent; text: "CANCEL"; color: "#DDECF7FF"; font.pixelSize: 8; font.bold: true }; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: widget.folderCreateOpen = false } }
                Rectangle { id: createFolderSaveButton; anchors.right: parent.right; anchors.rightMargin: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; width: 82; height: 29; radius: 4; color: "#263E50"; border.width: 1; border.color: "#B8F2FDFF"; Text { anchors.centerIn: parent; text: "CREATE"; color: "#FFFFFFFF"; font.pixelSize: 8; font.bold: true }; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: widget.createFolder(folderCreateNameField.text) } }
            }
        }
        */

        Item {
            id: activeSettingsOverlay

            anchors.fill: parent
            visible: widget.settingsOpen
            focus: visible
            z: 16

            Keys.onEscapePressed: {
                widget.closeSettings()
                event.accepted = true
            }

            Rectangle { anchors.fill: parent; color: "#B7141A24" }
            MouseArea { anchors.fill: parent; enabled: !widget.settingsSaving; onClicked: widget.closeSettings() }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 56, 420)
                height: 300
                radius: 10
                color: "#F01A222E"
                border.width: 1
                border.color: "#9EDDF7FF"

                MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: {} }

                Text {
                    x: 18
                    y: 18
                    text: "WIDGET SETTINGS"
                    color: "#E4E8F7FF"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.2
                }

                Text { x: 22; y: 58; text: "START HIDDEN"; color: "#A8D7E6F0"; font.pixelSize: 9; font.bold: true }
                Rectangle {
                    x: parent.width - 112; y: 50; width: 86; height: 24; radius: 4
                    color: widget.settingsStartHiddenDraft ? "#263E50" : "#101A2733"
                    border.width: 1; border.color: "#8DDDF7FF"
                    Text { anchors.centerIn: parent; text: widget.settingsStartHiddenDraft ? "ON" : "OFF"; color: "#EFFFFFFF"; font.pixelSize: 8; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !widget.settingsSaving; onClicked: widget.settingsStartHiddenDraft = !widget.settingsStartHiddenDraft }
                }

                Text { x: 22; y: 102; text: "MAX COLUMNS"; color: "#A8D7E6F0"; font.pixelSize: 9; font.bold: true }
                TextField {
                    id: settingsColumnsField
                    x: parent.width - 112; y: 94; width: 86; height: 31
                    color: "#F4FFFFFF"; font.pixelSize: 12
                    leftPadding: 9; rightPadding: 9; topPadding: 0; bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    inputMethodHints: Qt.ImhDigitsOnly
                    background: Rectangle { radius: 4; color: "#161F2B"; border.width: 1; border.color: "#8BAFC0" }
                }

                Text { x: 22; y: 146; text: "SYNC SUBTITLE"; color: "#A8D7E6F0"; font.pixelSize: 9; font.bold: true }
                Rectangle {
                    x: parent.width - 112; y: 138; width: 86; height: 24; radius: 4
                    color: widget.settingsSyncSubtitleDraft ? "#263E50" : "#101A2733"
                    border.width: 1; border.color: "#8DDDF7FF"
                    Text { anchors.centerIn: parent; text: widget.settingsSyncSubtitleDraft ? "ON" : "OFF"; color: "#EFFFFFFF"; font.pixelSize: 8; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !widget.settingsSaving; onClicked: widget.settingsSyncSubtitleDraft = !widget.settingsSyncSubtitleDraft }
                }

                Text { x: 22; y: 246; text: widget.settingsError; color: "#FFFFB4B4"; font.pixelSize: 8 }

                Text { x: 22; y: 190; text: "FOLDER"; color: "#A8D7E6F0"; font.pixelSize: 9; font.bold: true }

                Rectangle {
                    x: parent.width - 112
                    y: 182
                    width: 86
                    height: 24
                    radius: 4
                    color: settingsFoldersMouse.containsMouse ? "#22FFFFFF" : "#101A2733"
                    Text { anchors.centerIn: parent; text: "OPEN"; color: "#DDECF7FF"; font.pixelSize: 8; font.bold: true }
                    MouseArea { id: settingsFoldersMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: widget.requestOpenPackageFolder() }
                }

                Text { x: 22; y: 222; text: "RESTORE"; color: "#A8D7E6F0"; font.pixelSize: 9; font.bold: true }
                Rectangle {
                    x: parent.width - 112
                    y: 214
                    width: 86
                    height: 24
                    radius: 4
                    color: settingsRestoreMouse.containsMouse ? "#22FFFFFF" : "#101A2733"
                    Text { anchors.centerIn: parent; text: "OPEN"; color: "#DDECF7FF"; font.pixelSize: 8; font.bold: true }
                    MouseArea { id: settingsRestoreMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: widget.recoveryOpen = true }
                }

                Rectangle {
                    anchors.right: settingsSaveButton.left
                    anchors.rightMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    width: 82
                    height: 29
                    radius: 4
                    color: "#101A2733"
                    Text { anchors.centerIn: parent; text: "CANCEL"; color: "#DDECF7FF"; font.pixelSize: 8; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !widget.settingsSaving; onClicked: widget.closeSettings() }
                }

                Rectangle {
                    id: settingsSaveButton
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    width: 82
                    height: 29
                    radius: 4
                    color: "#263E50"
                    border.width: 1
                    border.color: "#B8F2FDFF"
                    Text { anchors.centerIn: parent; text: widget.settingsSaving ? "SAVING" : "SAVE"; color: "#FFFFFFFF"; font.pixelSize: 8; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !widget.settingsSaving; onClicked: widget.saveSettings() }
                }
            }
        }

        Item {
            id: activeRecoveryOverlay

            anchors.fill: parent
            visible: widget.recoveryOpen
            focus: visible
            z: 17

            Keys.onEscapePressed: {
                widget.recoveryOpen = false
                event.accepted = true
            }

            Rectangle { anchors.fill: parent; color: "#B7141A24" }
            MouseArea { anchors.fill: parent; onClicked: widget.recoveryOpen = false }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 56, 500)
                height: 300
                radius: 10
                color: "#F01A222E"
                border.width: 1
                border.color: "#9EDDF7FF"

                MouseArea { anchors.fill: parent; onClicked: {} }

                Text {
                    x: 18
                    y: 18
                    text: "RESTORE CARDS"
                    color: "#E4E8F7FF"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.2
                }

                Text {
                    x: 18
                    y: 38
                    text: "Restore only returns a card to the launcher. Files stay unchanged."
                    color: "#A8D7E6F0"
                    font.pixelSize: 8
                }

                Flickable {
                    x: 18
                    y: 61
                    width: parent.width - 36
                    height: 184
                    clip: true
                    contentHeight: recoveryList.height

                    Column {
                        id: recoveryList
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: widget.hiddenCardIds()

                            Rectangle {
                                property string restoredCardId: modelData
                                property var restoredData: widget.getCardUserData(restoredCardId)
                                width: recoveryList.width
                                height: 44
                                radius: 4
                                color: "#121D28"
                                border.width: 1
                                border.color: "#294454"

                                Text {
                                    x: 10
                                    y: 8
                                    width: parent.width - 108
                                    text: restoredData.customTitle || restoredData.automaticTitle || "GAME"
                                    color: "#EFFFFFFF"
                                    font.pixelSize: 10
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    x: 10
                                    y: 25
                                    width: parent.width - 108
                                    text: restoredData.sourcePath || "SOURCE PATH IS NOT AVAILABLE"
                                    color: restoredData.sourcePath ? "#8FB8C9D6" : "#FFFFC0A0"
                                    font.pixelSize: 7
                                    elide: Text.ElideMiddle
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 82
                                    height: 26
                                    radius: 3
                                    color: "#263E50"
                                    border.width: 1
                                    border.color: "#8DDDF7FF"
                                    Text { anchors.centerIn: parent; text: "RESTORE"; color: "#FFFFFFFF"; font.pixelSize: 7; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: widget.restoreCard(parent.parent.restoredCardId) }
                                }
                            }
                        }

                        Text {
                            visible: !widget.hiddenCardIds().length
                            text: "NO HIDDEN CARDS"
                            color: "#A8D7E6F0"
                            font.pixelSize: 9
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    width: 82
                    height: 29
                    radius: 4
                    color: "#101A2733"
                    Text { anchors.centerIn: parent; text: "CLOSE"; color: "#DDECF7FF"; font.pixelSize: 8; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: widget.recoveryOpen = false }
                }
            }
        }

        Item {
            id: activeFolderEditorOverlay

            anchors.fill: parent
            visible: widget.folderEditorOpen
            focus: visible
            z: 16

            Keys.onEscapePressed: {
                widget.folderEditorOpen = false
                event.accepted = true
            }

            Rectangle {
                anchors.fill: parent
                color: "#B7141A24"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: widget.folderEditorOpen = false
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 56, 420)
                height: 344
                radius: 10
                color: "#F01A222E"
                border.width: 1
                border.color: "#9EDDF7FF"

                MouseArea { anchors.fill: parent; onClicked: {} }

                Text {
                    x: 18
                    y: 18
                    text: widget.folderCreating ? "ADD FOLDER" : ("FOLDER EDITOR // " + widget.folderEditorId)
                    color: "#E4E8F7FF"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.1
                }

                Text {
                    x: 18
                    y: 55
                    text: widget.folderCreating ? "DISPLAY NAME // REQUIRED" : "DISPLAY NAME // EMPTY USES AUTOMATIC"
                    color: "#A8D7E6F0"
                    font.pixelSize: 8
                    font.bold: true
                }

                TextField {
                    id: folderEditorTitleField
                    x: 18
                    y: 70
                    width: parent.width - 36
                    height: 31
                    color: "#F4FFFFFF"
                    font.pixelSize: 12
                    leftPadding: 9
                    rightPadding: 9
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    background: Rectangle { radius: 4; color: "#161F2B"; border.width: 1; border.color: "#8BAFC0" }
                }

                Text {
                    x: 18
                    y: 119
                    visible: !widget.folderCreating
                    text: "MAX COLUMNS // EMPTY USES GLOBAL (" + widget.maxColumns + ")"
                    color: "#A8D7E6F0"
                    font.pixelSize: 8
                    font.bold: true
                }

                TextField {
                    id: folderEditorColumnsField
                    x: 18
                    y: 134
                    width: 110
                    height: 31
                    visible: !widget.folderCreating
                    color: "#F4FFFFFF"
                    font.pixelSize: 12
                    leftPadding: 9
                    rightPadding: 9
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    inputMethodHints: Qt.ImhDigitsOnly
                    background: Rectangle { radius: 4; color: "#161F2B"; border.width: 1; border.color: "#8BAFC0" }
                }

                Text {
                    x: 18
                    y: 182
                    visible: !widget.folderCreating
                    text: "CUSTOM ICON // PATH OR DROP IMAGE"
                    color: "#A8D7E6F0"
                    font.pixelSize: 8
                    font.bold: true
                }

                Rectangle {
                    x: 18
                    y: 198
                    width: 58
                    height: 58
                    radius: 4
                    visible: !widget.folderCreating
                    clip: true
                    color: "#101A2733"
                    border.width: 1
                    border.color: widget.folderEditorIconDropActive ? "#DDF7FFFF" : "#8BAFC0"

                    Image {
                        anchors.fill: parent
                        anchors.margins: 5
                        visible: folderEditorIconPathField.text.length > 0
                        source: widget.imagePathPreviewSource(folderEditorIconPathField.text)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: folderEditorIconPathField.text.length === 0 && !widget.folderEditorIconDropActive
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "DROP IMAGE"
                            color: "#CBEAF5FF"
                            font.pixelSize: 7
                            font.bold: true
                            font.letterSpacing: 0.55
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "512 x 512"
                            color: "#82C4D5E5"
                            font.pixelSize: 5
                            font.letterSpacing: 0.25
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        enabled: widget.folderEditorOpen

                        onEntered: {
                            if (drag.hasUrls) {
                                widget.folderEditorIconDropActive = true
                                drag.accepted = true
                            }
                        }

                        onExited: widget.folderEditorIconDropActive = false

                        onDropped: {
                            widget.folderEditorIconDropActive = false
                            drop.accepted = true

                            if (!drop.hasUrls || drop.urls.length !== 1) {
                                widget.folderEditorError = "DROP ONE PNG, JPG, JPEG OR WEBP IMAGE"
                                return
                            }

                            widget.chooseFolderEditorIcon(String(drop.urls[0]))
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: widget.folderEditorIconDropActive
                            color: "#5A102534"
                        }
                    }
                }

                TextField {
                    id: folderEditorIconPathField
                    x: 84
                    y: 198
                    width: parent.width - 102
                    height: 31
                    visible: !widget.folderCreating
                    color: "#F4FFFFFF"
                    font.pixelSize: 9
                    leftPadding: 9
                    rightPadding: 9
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    placeholderText: "PNG / JPG / WEBP"
                    placeholderTextColor: "#9AB9C9D9"
                    background: Rectangle { radius: 4; color: "#161F2B"; border.width: 1; border.color: "#8BAFC0" }
                }

                Rectangle {
                    x: 84
                    y: 232
                    width: 92
                    height: 24
                    radius: 3
                    visible: !widget.folderCreating
                    color: "#101A2733"
                    border.width: 1
                    border.color: "#567B8C"
                    Text { anchors.centerIn: parent; text: "RESET ICON"; color: "#DDECF7FF"; font.pixelSize: 7; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: folderEditorIconPathField.text = "" }
                }

                Text {
                    x: 18
                    y: 275
                    text: widget.folderEditorError
                    color: "#FFFFB4B4"
                    font.pixelSize: 8
                }

                Rectangle {
                    anchors.right: folderEditorSaveButton.left
                    anchors.rightMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    width: 82
                    height: 29
                    radius: 4
                    color: "#101A2733"
                    Text { anchors.centerIn: parent; text: "CANCEL"; color: "#DDECF7FF"; font.pixelSize: 8; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: widget.folderEditorOpen = false }
                }

                Rectangle {
                    id: folderEditorSaveButton
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    width: 82
                    height: 29
                    radius: 4
                    color: "#263E50"
                    border.width: 1
                    border.color: "#B8F2FDFF"
                    Text { anchors.centerIn: parent; text: widget.folderCreating ? "CREATE" : "SAVE"; color: "#FFFFFFFF"; font.pixelSize: 8; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: widget.saveFolderEditor() }
                }
            }

            // The folder editor owns external file drops while it is open.
            DropArea {
                anchors.fill: parent
                z: 2
                enabled: widget.folderEditorOpen

                onEntered: {
                    if (drag.hasUrls) {
                        widget.folderEditorIconDropActive = true
                        drag.accepted = true
                    }
                }

                onExited: widget.folderEditorIconDropActive = false

                onDropped: {
                    widget.folderEditorIconDropActive = false
                    drop.accepted = true

                    if (!drop.hasUrls || drop.urls.length !== 1) {
                        widget.folderEditorError = "DROP ONE PNG, JPG, JPEG OR WEBP IMAGE"
                        return
                    }

                    widget.chooseFolderEditorIcon(String(drop.urls[0]))
                }
            }
        }

        Item {
            id: cardMoveChoiceOverlay

            anchors.fill: parent
            visible: widget.cardMoveChoiceOpen
            focus: visible
            z: 11

            onVisibleChanged: {
                if (visible)
                    forceActiveFocus()
            }

            Keys.onEscapePressed: {
                widget.cancelCardMoveChoice()
                event.accepted = true
            }

            Rectangle {
                anchors.fill: parent
                color: "#B7141A24"
            }

            MouseArea {
                anchors.fill: parent
                enabled: cardMoveChoiceOverlay.visible && !widget.cardReorderSaving
                onClicked: widget.cancelCardMoveChoice()
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 56, 460)
                height: 214
                radius: 10
                color: "#F01A222E"
                border.width: 1
                border.color: "#9EDDF7FF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                    }
                }

                Text {
                    x: 18
                    y: 18
                    text: "CARD ALREADY IN A FOLDER"
                    color: "#E4E8F7FF"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.3
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.top: parent.top
                    anchors.topMargin: 9
                    width: 24
                    height: 24
                    radius: 4
                    color: moveChoiceCloseMouse.containsMouse ? "#32DDF7FF" : "#08FFFFFF"
                    border.width: moveChoiceCloseMouse.containsMouse ? 1 : 0
                    border.color: "#B9DDF7FF"

                    Text {
                        anchors.centerIn: parent
                        text: "\u00d7"
                        color: "#EFFFFFFF"
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: moveChoiceCloseMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !widget.cardReorderSaving
                        onClicked: widget.cancelCardMoveChoice()
                    }
                }

                Text {
                    x: 18
                    y: 56
                    width: parent.width - 36
                    text: "Add \"" + widget.getEffectiveCardTitle(widget.findGameByCardId(widget.cardMoveChoiceCardId))
                          + "\" to \"" + ((widget.findConfiguredFolder(widget.cardMoveChoiceDestinationId) || {}).displayName || widget.cardMoveChoiceDestinationId) + "\"?"
                    color: "#F4FFFFFF"
                    font.pixelSize: 14
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    x: 18
                    y: 105
                    width: parent.width - 36
                    text: "COPY keeps it in the current folder. MOVE changes its folder. The shortcut file is not copied or moved."
                    color: "#B9D1E1ED"
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }

                Rectangle {
                    anchors.right: moveChoiceMoveButton.left
                    anchors.rightMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    width: 90
                    height: 29
                    radius: 4
                    color: moveChoiceCopyMouse.containsMouse ? "#3B2F6172" : "#1626313F"
                    border.width: 1
                    border.color: "#9EDDF7FF"

                    Text {
                        anchors.centerIn: parent
                        text: "COPY"
                        color: "#FFFFFFFF"
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 0.9
                    }

                    MouseArea {
                        id: moveChoiceCopyMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !widget.cardReorderSaving
                        onClicked: widget.confirmCardMoveChoice(true)
                    }
                }

                Rectangle {
                    id: moveChoiceMoveButton

                    anchors.right: moveChoiceCancelButton.left
                    anchors.rightMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    width: 90
                    height: 29
                    radius: 4
                    color: moveChoiceMoveMouse.containsMouse ? "#3B2F6172" : "#1626313F"
                    border.width: 1
                    border.color: "#9EDDF7FF"

                    Text {
                        anchors.centerIn: parent
                        text: "MOVE"
                        color: "#FFFFFFFF"
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 0.9
                    }

                    MouseArea {
                        id: moveChoiceMoveMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !widget.cardReorderSaving
                        onClicked: widget.confirmCardMoveChoice(false)
                    }
                }

                Rectangle {
                    id: moveChoiceCancelButton

                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    width: 82
                    height: 29
                    radius: 4
                    color: moveChoiceCancelMouse.containsMouse ? "#2AFFFFFF" : "#101A2733"

                    Text {
                        anchors.centerIn: parent
                        text: "CANCEL"
                        color: "#DDECF7FF"
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 0.9
                    }

                    MouseArea {
                        id: moveChoiceCancelMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !widget.cardReorderSaving
                        onClicked: widget.cancelCardMoveChoice()
                    }
                }
            }
        }

        Item {
            id: cardRemovalOverlay

            anchors.fill: parent
            visible: widget.cardRemovalConfirmOpen
            focus: visible
            z: 12

            onVisibleChanged: {
                if (visible)
                    forceActiveFocus()
            }

            Keys.onEscapePressed: {
                widget.cancelCardRemoval()
                event.accepted = true
            }

            Rectangle {
                anchors.fill: parent
                color: "#B7141A24"
            }

            MouseArea {
                anchors.fill: parent
                enabled: cardRemovalOverlay.visible && !widget.cardRemovalSaving
                onClicked: widget.cancelCardRemoval()
            }

            Rectangle {
                id: cardRemovalPanel

                anchors.centerIn: parent
                width: Math.min(parent.width - 56, 450)
                height: 214
                radius: 10
                color: "#F01A222E"
                border.width: 1
                border.color: "#A5FF9C9C"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                    }
                }

                Text {
                    x: 18
                    y: 18
                    text: "REMOVE CARD"
                    color: "#FFFFD3D3"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 1.3
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.top: parent.top
                    anchors.topMargin: 9
                    width: 24
                    height: 24
                    radius: 4
                    color: removalCloseMouse.containsMouse ? "#32FF7272" : "#08FFFFFF"
                    border.width: removalCloseMouse.containsMouse ? 1 : 0
                    border.color: removalCloseMouse.containsMouse ? "#FFFFB4B4" : "#99FFFFFF"

                    Text {
                        anchors.centerIn: parent
                        text: "\u00d7"
                        color: "#EFFFFFFF"
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: removalCloseMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !widget.cardRemovalSaving
                        onClicked: widget.cancelCardRemoval()
                    }
                }

                Text {
                    x: 18
                    y: 55
                    width: parent.width - 36
                    text: "Remove \"" + widget.cardRemovalTitle + "\" from the launcher?"
                    color: "#F4FFFFFF"
                    font.pixelSize: 14
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Text {
                    x: 18
                    y: 102
                    width: parent.width - 36
                    text: "The shortcut, game files, and original image will stay on this computer."
                    color: "#B9D1E1ED"
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }

                Text {
                    x: 18
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 17
                    width: parent.width - 258
                    text: widget.cardRemovalError || (widget.cardRemovalSaving ? "REMOVING CARD..." : "")
                    color: widget.cardRemovalError ? "#FFFFB4B4" : "#BDE6F5FF"
                    font.pixelSize: 8
                    font.letterSpacing: 0.8
                    elide: Text.ElideRight
                }

                Rectangle {
                    anchors.right: cancelRemovalButton.left
                    anchors.rightMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    width: 130
                    height: 29
                    radius: 4
                    color: removalConfirmMouse.containsMouse ? "#B9444444" : "#823C2A2A"
                    border.width: 1
                    border.color: "#FFFFB4B4"
                    opacity: widget.cardRemovalSaving ? 0.65 : 1

                    Text {
                        anchors.centerIn: parent
                        text: widget.cardRemovalSaving ? "REMOVING" : "REMOVE"
                        color: "#FFFFFFFF"
                        font.pixelSize: 8
                        font.bold: true
                        font.letterSpacing: 0.9
                    }

                    MouseArea {
                        id: removalConfirmMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !widget.cardRemovalSaving
                        onClicked: widget.confirmCardRemoval()
                    }
                }

                Rectangle {
                    id: cancelRemovalButton

                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    width: 82
                    height: 29
                    radius: 4
                    color: cancelRemovalMouse.containsMouse ? "#22FFFFFF" : "#08FFFFFF"
                    border.width: cancelRemovalMouse.containsMouse ? 1 : 0
                    border.color: "#99FFFFFF"
                    opacity: widget.cardRemovalSaving ? 0.5 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "CANCEL"
                        color: "#EFFFFFFF"
                        font.pixelSize: 8
                        font.letterSpacing: 1.0
                    }

                    MouseArea {
                        id: cancelRemovalMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !widget.cardRemovalSaving
                        onClicked: widget.cancelCardRemoval()
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
