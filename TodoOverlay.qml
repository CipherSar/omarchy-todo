import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "TodoModel.js" as TodoModel

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool animatingClose: false
  property string currentTab: "todo" // "todo" or "history"
  property var items: []

  readonly property int todoCount: TodoModel.countActive(root.items)
  readonly property int historyCount: TodoModel.countCompleted(root.items)

  property string storagePath: Quickshell.env("HOME") + "/.local/state/omarchy/todo-items.json"

  // Theme-aware palette matching the Omarchy shell
  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Commons.Color.menu.scrim
  property color accent: Commons.Color.accent
  property color urgent: Commons.Color.urgent
  property color selectedBackground: Commons.Color.menu.selectedBackground
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.family

  // Card Dimensions (Quake Console style)
  property int cardWidth: Math.min(Style.space(660), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(520), Math.round(panel.height * 0.58))
  property int contentMargin: Style.spacing.panelPadding

  function open(payloadJson) {
    root.opened = true
    root.animatingClose = false
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    if (payload.tab) root.currentTab = payload.tab
    root.rebuildDisplay()
    Qt.callLater(function() {
      inputField.forceActiveFocus()
    })
  }

  function close() {
    root.animatingClose = false
    root.opened = false
  }

  function dismiss() {
    if (root.animatingClose || !root.opened) return
    root.animatingClose = true
    closeTimer.restart()
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function switchTab(tab) {
    if (root.currentTab === tab) return
    root.currentTab = tab
    root.rebuildDisplay()
  }

  function loadData(raw) {
    root.items = TodoModel.parseItems(raw)
    root.rebuildDisplay()
  }

  function saveData() {
    dataFile.setText(JSON.stringify(root.items, null, 2) + "\n")
  }

  function addCurrentActivity() {
    var text = inputField.text.trim()
    if (!text) return
    root.items = TodoModel.addItem(root.items, text)
    root.saveData()
    inputField.text = ""
    if (root.currentTab !== "todo") {
      root.currentTab = "todo"
    }
    root.rebuildDisplay()
    Qt.callLater(function() {
      inputField.forceActiveFocus()
    })
  }

  function toggleActivity(id) {
    root.items = TodoModel.toggleItem(root.items, id)
    root.saveData()
    root.rebuildDisplay()
  }

  function deleteActivity(id) {
    root.items = TodoModel.deleteItem(root.items, id)
    root.saveData()
    root.rebuildDisplay()
  }

  function clearCompletedHistory() {
    root.items = TodoModel.clearHistory(root.items)
    root.saveData()
    root.rebuildDisplay()
  }

  function rebuildDisplay() {
    var rows = TodoModel.organizeByDate(root.items, root.currentTab)
    displayModel.clear()
    for (var i = 0; i < rows.length; i++) {
      displayModel.append(rows[i])
    }
  }

  Timer {
    id: closeTimer
    interval: Style.duration(160)
    repeat: false
    onTriggered: {
      root.animatingClose = false
      root.opened = false
      if (root.shell && typeof root.shell.hide === "function") {
        root.shell.hide((root.manifest && root.manifest.id) || "ciphersar.todo")
      }
    }
  }

  ListModel {
    id: displayModel
  }

  FileView {
    id: dataFile
    path: root.storagePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadData(text())
    onLoadFailed: root.loadData("[]")
    onFileChanged: reload()
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "omarchy-todo"

    // Dimmed scrim background
    Rectangle {
      anchors.fill: parent
      color: root.scrim
      opacity: card.droppedDown ? 1 : 0
      Behavior on opacity {
        NumberAnimation {
          duration: Style.duration(180)
        }
      }
    }

    // Clicking scrim dismisses console
    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    // Quake Console Surface
    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.horizontalCenter: parent.horizontalCenter
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      readonly property bool droppedDown: panel.contentRevealed && !root.animatingClose

      // Quake drop-down slide animation: starts above the top screen edge and drops down
      y: droppedDown ? (Style.gapsOut > 0 ? Style.gapsOut : 0) : -height - Style.space(40)
      Behavior on y {
        NumberAnimation {
          duration: card.droppedDown ? Style.duration(240) : Style.duration(160)
          easing.type: card.droppedDown ? Easing.OutCubic : Easing.InCubic
        }
      }

      opacity: droppedDown ? 1 : 0
      Behavior on opacity {
        NumberAnimation {
          duration: Style.duration(180)
        }
      }

      // Absorb clicks inside console
      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      // Root content column inside card
      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.spacing.md

        // ------------------------------------------------ Tab Bar Header
        Row {
          id: tabHeader
          width: parent.width
          spacing: Style.spacing.sm

          // To-Do Tab on the left
          Button {
            text: "To-Do" + (root.todoCount > 0 ? " (" + root.todoCount + ")" : "")
            iconText: "󰄬"
            selected: root.currentTab === "todo"
            bordered: true
            accent: root.accent
            onClicked: root.switchTab("todo")
          }

          // History Tab to the right of To-Do tab
          Button {
            text: "History" + (root.historyCount > 0 ? " (" + root.historyCount + ")" : "")
            iconText: "󰋚"
            selected: root.currentTab === "history"
            bordered: true
            accent: root.accent
            onClicked: root.switchTab("history")
          }

          Item {
            // Spacer
            width: tabHeader.width - (tabHeader.children[0].width + tabHeader.children[1].width + (clearHistBtn.visible ? clearHistBtn.width + Style.spacing.sm : 0) + escBtn.width + Style.spacing.sm * 3)
            height: 1
          }

          // Clear history button (only when viewing history with entries)
          Button {
            id: clearHistBtn
            visible: root.currentTab === "history" && root.historyCount > 0
            text: "Clear"
            iconText: "󰩹"
            tooltipText: "Clear completed history"
            bordered: false
            accent: root.urgent
            onClicked: root.clearCompletedHistory()
          }

          // Dismiss button
          Button {
            id: escBtn
            text: "Esc"
            iconText: "󰅖"
            tooltipText: "Close (Escape)"
            bordered: false
            onClicked: root.dismiss()
          }
        }

        // -------------------------------- Typing space and Add button
        Row {
          id: inputRow
          width: parent.width
          height: Math.max(Style.space(34), Style.font.body + Style.spacing.inputPaddingY * 2)
          spacing: Style.spacing.controlGap

          TextField {
            id: inputField
            width: parent.width - addBtn.width - parent.spacing
            height: parent.height
            placeholderText: root.currentTab === "todo"
              ? "Add a task... (Press Enter to add)"
              : "Add a task to To-Do... (Press Enter)"
            foreground: root.foreground
            accent: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.body

            onAccepted: root.addCurrentActivity()
            Keys.onReturnPressed: root.addCurrentActivity()
            Keys.onEnterPressed: root.addCurrentActivity()
            Keys.onEscapePressed: function(event) {
              root.dismiss()
              event.accepted = true
            }
            Keys.onPressed: function(event) {
              if ((event.modifiers & Qt.ControlModifier) || (event.modifiers & Qt.AltModifier)) {
                if (event.key === Qt.Key_1) {
                  root.switchTab("todo")
                  event.accepted = true
                } else if (event.key === Qt.Key_2) {
                  root.switchTab("history")
                  event.accepted = true
                }
              }
            }
          }

          Button {
            id: addBtn
            height: parent.height
            text: "Add"
            iconText: "󰐕"
            bordered: true
            accent: root.accent
            tooltipText: "Add task (Enter)"
            onClicked: root.addCurrentActivity()
          }
        }

        // -------------------------------- List of activities beneath
        Item {
          id: listContainer
          width: parent.width
          height: card.height - card.contentTopInset - card.contentBottomInset - tabHeader.height - inputRow.height - parent.spacing * 2

          // Empty state message
          Column {
            anchors.centerIn: parent
            visible: displayModel.count === 0
            spacing: Style.spacing.sm

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              textFormat: Text.PlainText
              text: root.currentTab === "todo" ? "󰄬" : "󰋚"
              color: Qt.darker(root.foreground, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              textFormat: Text.PlainText
              text: root.currentTab === "todo" ? "All caught up!" : "No history yet"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              textFormat: Text.PlainText
              text: root.currentTab === "todo"
                ? "Type a task in the box above and click Add."
                : "Completed tasks will be saved here."
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          // Activity ListView
          ListView {
            id: activityListView
            anchors.fill: parent
            clip: true
            model: displayModel
            boundsBehavior: Flickable.StopAtBounds
            spacing: Style.spacing.xs

            ScrollBar.vertical: ScrollBar {
              policy: ScrollBar.AsNeeded
            }

            delegate: Item {
              id: delegateItem
              width: activityListView.width
              height: model.isHeader ? Style.space(30) : Style.space(42)

              // ---------------- Date Header Section
              Item {
                anchors.fill: parent
                visible: model.isHeader

                Row {
                  id: headerContent
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.spacing.sm

                  Text {
                    textFormat: Text.PlainText
                    text: model.headerTitle
                    color: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: "· " + model.headerCount
                    color: Qt.darker(root.foreground, 1.5)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                Rectangle {
                  anchors.left: headerContent.right
                  anchors.leftMargin: Style.spacing.md
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  height: 1
                  color: root.border
                  opacity: 0.35
                }
              }

              // ---------------- Activity Row
              BorderSurface {
                anchors.fill: parent
                visible: !model.isHeader
                radius: Math.max(2, Style.cornerRadius / 2)
                color: rowMouse.containsMouse
                  ? Style.hoverFillFor(root.foreground, root.accent)
                  : "transparent"

                Behavior on color {
                  ColorAnimation { duration: Style.duration(100) }
                }

                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: {}
                }

                Row {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.spacing.controlPaddingX
                  anchors.rightMargin: Style.spacing.controlPaddingX
                  spacing: Style.spacing.md

                  // Checkbox on the left
                  BorderSurface {
                    id: checkbox
                    width: Style.space(18)
                    height: Style.space(18)
                    radius: Math.max(2, Style.cornerRadius / 3)
                    anchors.verticalCenter: parent.verticalCenter
                    color: model.completed ? Style.selectedFillFor(root.foreground, root.accent) : "transparent"
                    borderSpec: model.completed
                      ? Border.controlSpec("selected", root.foreground, root.accent)
                      : Border.controlSpec("normal", root.foreground, root.accent)

                    Text {
                      anchors.centerIn: parent
                      visible: model.completed
                      text: "✓"
                      color: Style.selectedStateColor(root.foreground, root.accent)
                      font.family: root.fontFamily
                      font.pixelSize: Math.round(checkbox.height * 0.85)
                      font.bold: true
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.toggleActivity(model.itemId)
                    }
                  }

                  // Activity Text & Time in center
                  Column {
                    width: parent.width - checkbox.width - deleteBtn.width - parent.spacing * 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.spacing.xxs

                    Text {
                      textFormat: Text.PlainText
                      text: model.itemText
                      color: root.foreground
                      opacity: model.completed ? 0.55 : 1.0
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.strikeout: model.completed
                      elide: Text.ElideRight
                      width: parent.width
                    }

                    Text {
                      textFormat: Text.PlainText
                      visible: model.timeLabel !== ""
                      text: model.timeLabel
                      color: Qt.darker(root.foreground, 1.5)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  // Delete button (bin icon) on the right
                  BorderSurface {
                    id: deleteBtn
                    width: Style.space(28)
                    height: Style.space(28)
                    radius: Math.max(2, Style.cornerRadius / 3)
                    anchors.verticalCenter: parent.verticalCenter
                    color: delMouse.containsMouse
                      ? Style.hoverFillFor(root.urgent, root.urgent)
                      : "transparent"

                    Behavior on color {
                      ColorAnimation { duration: Style.duration(100) }
                    }

                    Text {
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: "󰩹"
                      color: delMouse.containsMouse ? root.urgent : Qt.darker(root.foreground, 1.4)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.subtitle
                    }

                    MouseArea {
                      id: delMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.deleteActivity(model.itemId)
                    }

                    ToolTip {
                      visible: delMouse.containsMouse
                      text: "Delete activity"
                      delay: 300
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
