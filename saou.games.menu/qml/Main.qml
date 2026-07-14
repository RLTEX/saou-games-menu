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
    property var cardReorderOriginalGames: []
    property string cardReorderError: ""
    property bool cardRemovalConfirmOpen: false
    property bool cardRemovalSaving: false
    property string cardRemovalCardId: ""
    property string cardRemovalTitle: ""
    property string cardRemovalError: ""

    property int gameCount: displayedGames && displayedGames.length ? displayedGames.length : 0
    property int gridColumns: calculateGridColumns()
    property real cardWidth: calculateCardWidth()
    property real cardHeight: Math.max(118, Math.min(widget.cardMaxHeight, Math.round(widget.cardWidth * 0.62)))

    onSelectedFolderIdChanged: cancelCardReorder()
    onEditModeChanged: {
        if (!editMode)
            cancelCardReorder()
    }

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

    function toggleEditMode() {
        if (closing || launching || cardEditorOpen || cardRemovalConfirmOpen)
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
        cardReorderOriginalGames = []
    }

    function beginCardReorder(cardId) {
        var key = ConfigLoader.normalizeString(cardId, "")

        if (!editMode || cardEditorOpen || cardRemovalConfirmOpen || cardReorderSaving || !key || (activeGames && activeGames.length < 2))
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

        reorderPreviewGames = cardReorderOriginalGames.slice(0)
        cardReorderTargetId = ""
        cardReorderInsertAfter = false
    }

    function previewCardReorderAt(sourceCardId, gridX, gridY) {
        if (!cardReorderActive || sourceCardId !== cardReorderSourceId)
            return

        var columnWidth = cardWidth + cardSpacing
        var rowHeight = cardHeight + cardSpacing
        var column = Math.floor(gridX / columnWidth)
        var row = Math.floor(gridY / rowHeight)
        var localX = gridX - column * columnWidth
        var localY = gridY - row * rowHeight

        if (gridX < 0 || gridY < 0 || column < 0 || column >= gridColumns || row < 0
                || localX > cardWidth || localY > cardHeight) {
            clearCardReorderPreview(sourceCardId)
            return
        }

        var targetIndex = row * gridColumns + column
        if (!displayedGames || targetIndex < 0 || targetIndex >= displayedGames.length) {
            clearCardReorderPreview(sourceCardId)
            return
        }

        var targetCardId = cardIdForGame(displayedGames[targetIndex])
        if (targetCardId === sourceCardId) {
            clearCardReorderPreview(sourceCardId)
            return
        }

        previewCardReorder(sourceCardId, targetCardId, localY >= cardHeight * 0.5)
    }

    function cancelCardReorder() {
        if (!cardReorderActive || cardReorderSaving)
            return

        resetCardReorder()
    }

    function finishCardReorderGesture(cardId) {
        Qt.callLater(function() {
            if (cardReorderActive && !cardReorderSaving && cardReorderSourceId === cardId)
                cancelCardReorder()
        })
    }

    function commitCardReorderFromPointer(sourceCardId) {
        if (!cardReorderActive || cardReorderSaving || sourceCardId !== cardReorderSourceId)
            return

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
            return sortGamesByCustomOrder(widget.allGames, "all")

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

        return sortGamesByCustomOrder(result, widget.selectedFolderId)
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
        if (editMode || cardEditorOpen || cardRemovalConfirmOpen || closing || launching)
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
                onFolderSelected: widget.selectedFolderId = folderId
                onOpenShortcutsRequested: widget.requestOpenShortcutsFolder()
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
                            game: widget.displayedGames[index]
                            cardId: widget.cardIdForGame(widget.displayedGames[index])
                            gameNumber: index + 1
                            hoverZoom: widget.hoverZoom
                            editMode: widget.editMode
                            reorderEnabled: !widget.cardEditorOpen && !widget.cardRemovalConfirmOpen && !widget.cardReorderSaving
                            reorderDragging: widget.cardReorderActive && widget.cardReorderSourceId === cardId
                            reorderInsertBefore: widget.cardReorderActive && widget.cardReorderTargetId === cardId && !widget.cardReorderInsertAfter
                            reorderInsertAfter: widget.cardReorderActive && widget.cardReorderTargetId === cardId && widget.cardReorderInsertAfter
                            enabled: !widget.launching && !widget.closing
                            onLaunchRequested: {
                                if (!widget.editMode)
                                    widget.launchShortcut(game)
                            }
                            onEditRequested: widget.openCardEditor(requestedCardId)
                            onRemoveRequested: widget.requestCardRemoval(requestedCardId)
                            onReorderStarted: widget.beginCardReorder(requestedCardId)
                            onReorderPointerMoved: widget.previewCardReorderAt(requestedCardId, gridX, gridY)
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
            enabled: !widget.cardEditorOpen && !widget.cardRemovalConfirmOpen && !widget.cardEditorSaving

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
                        source: widget.editorPreviewSource
                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        smooth: true

                        onStatusChanged: {
                            if (status === Image.Error)
                                widget.advanceEditorPreviewFallback()
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

        Item {
            id: cardRemovalOverlay

            anchors.fill: parent
            visible: widget.cardRemovalConfirmOpen
            focus: visible
            z: 11

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
