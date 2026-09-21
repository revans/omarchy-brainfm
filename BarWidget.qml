import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons

BarWidget {
  id: root

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("rre.brainfm")
  readonly property var activePlayer: mediaService ? mediaService.activePlayer : null
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []

  readonly property bool hasMedia: activePlayer !== null && (activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""

  property bool popupOpen: false
  function close() { popupOpen = false }

  IpcHandler {
    target: "rre.brainfm"
    function open() { root.popupOpen = true }
    function close() { root.popupOpen = false }
    function toggle() { root.popupOpen = !root.popupOpen }
  }

  // Focuses the brain.fm app window if one's already open (any window with
  // "brain.fm" in its title), otherwise launches it. No external script —
  // omarchy-launch-or-focus-webapp ships with Omarchy itself, so this plugin
  // has no dependency outside its own folder.
  readonly property string openBrainFmCmd: "omarchy-launch-or-focus-webapp \"brain\\.fm\" \"https://my.brain.fm/\""

  // Icon-only in the bar, same footprint every other icon widget uses.
  // Track name / artist / controls only appear in the popup on click.
  visible: true
  implicitWidth: barSize
  implicitHeight: barSize

  Text {
    anchors.centerIn: parent
    textFormat: Text.PlainText
    text: "🧠"
    color: root.bar.barForeground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.body
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        if (root.bar) root.bar.run(root.openBrainFmCmd)
      } else {
        root.popupOpen = !root.popupOpen
      }
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.hasMedia ? (root.title + (root.artist ? " — " + root.artist : "")) : "brain.fm")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Row {
        spacing: Style.space(10)
        width: parent.width

        BorderSurface {
          id: artBox
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

          // brain.fm's web player sets Media Session artwork with an empty
          // `sizes` field, which Chromium's MPRIS integration rejects —
          // trackArtUrl resolves to Chromium's own logo, not the track's
          // cover art. In place of a wrong picture, animate a dot-matrix
          // level meter off the real system output level (PipeWire peak),
          // same mechanism the audio panel uses for its mic meter.
          PwNodePeakMonitor {
            id: peakMonitor
            node: Pipewire.defaultAudioSink
            enabled: root.popupOpen
          }

          // Brain.fm's audio is deliberately steady (no jarring dynamics),
          // so raw peak barely moves. Use peak as a slow-changing envelope
          // (how loud overall) and layer a continuous per-column wave on
          // top of it (how lively it looks) so the meter keeps rippling
          // instead of sitting frozen — silent when nothing's playing,
          // since the wave is scaled by the envelope.
          property real animPhase: 0
          Timer {
            interval: 50
            running: root.popupOpen
            repeat: true
            onTriggered: artBox.animPhase += 0.22
          }

          Row {
            anchors.centerIn: parent
            spacing: Style.space(2)

            Repeater {
              model: 5
              delegate: Column {
                id: barColumn
                required property int index
                spacing: Style.space(2)

                readonly property real gain: [0.5, 0.8, 1.15, 0.8, 0.5][index]
                readonly property real waveSpeed: [0.9, 1.3, 1.0, 1.4, 1.1][index]
                readonly property real wavePhase: index * 1.3

                readonly property real envelope: Math.max(0, Math.min(1, peakMonitor.peak * gain * 1.6))
                readonly property real wave: 0.3 + 0.7 * (0.5 + 0.5 * Math.sin(artBox.animPhase * waveSpeed + wavePhase))
                readonly property real target: envelope * wave
                property real level: 0
                onTargetChanged: level = target
                Behavior on level { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }

                Repeater {
                  model: 6
                  delegate: Rectangle {
                    required property int index
                    readonly property int rowFromBottom: 5 - index
                    width: Style.space(6)
                    height: Style.space(6)
                    radius: width / 2
                    color: Color.accent
                    opacity: (barColumn.level * 6) > rowFromBottom ? 1.0 : 0.15
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                  }
                }
              }
            }
          }
        }

        Column {
          spacing: Style.space(4)
          width: parent.width - Style.space(74)

          Text {
            textFormat: Text.PlainText
            text: root.title || "Nothing playing"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            textFormat: Text.PlainText
            text: root.activePlayer && root.activePlayer.trackAlbum ? root.activePlayer.trackAlbum : ""
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Button {
          iconText: "󰒮"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("previous", false, root.mediaService.playerKey(root.activePlayer))
        }

        Button {
          iconText: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: root.activePlayer && (root.activePlayer.canTogglePlaying || root.activePlayer.canPlay || root.activePlayer.canPause)
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("playPause", false, root.mediaService.playerKey(root.activePlayer))
        }

        Button {
          iconText: "󰒭"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: root.activePlayer && root.activePlayer.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: if (root.mediaService) root.mediaService.runAction("next", false, root.mediaService.playerKey(root.activePlayer))
        }
      }

      PanelSeparator {
        foreground: root.bar.foreground
      }

      Button {
        width: parent.width
        leftAlign: true
        iconText: "🧠"
        text: "Open brain.fm"
        foreground: root.bar.foreground
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        onClicked: {
          if (root.bar) root.bar.run(root.openBrainFmCmd)
          root.popupOpen = false
        }
      }

      PanelSeparator {
        visible: root.sourcePlayers.length > 1
        foreground: root.bar.foreground
      }

      Column {
        id: sourceList
        visible: root.sourcePlayers.length > 1
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.sourcePlayers

          BorderSurface {
            id: sourceRow
            required property var modelData

            readonly property var player: modelData
            readonly property bool selected: root.activePlayer && player
              && root.mediaService.playerKey(root.activePlayer) === root.mediaService.playerKey(player)
            readonly property string sourceTitle: player ? (player.trackTitle || player.identity || player.desktopEntry || "Media source") : "Media source"
            readonly property string sourceDetail: player && player.trackArtist ? player.trackArtist : (player && player.identity ? player.identity : "")

            width: sourceList.width
            height: sourceInner.implicitHeight + Style.space(10)
            radius: Style.spacing.labelGap
            color: selected ? Style.selectedFillFor(root.bar.foreground, Color.accent) : "transparent"
            borderSpec: selected ? Border.controlSpec("normal", root.bar.foreground, Color.accent) : Border.none()

            Row {
              id: sourceInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: sourceRow.borderLeft + Style.space(8)
              anchors.rightMargin: sourceRow.borderRight + Style.space(8)
              spacing: Style.space(8)

              Text {
                textFormat: Text.PlainText
                text: sourceRow.player && sourceRow.player.isPlaying ? "󰏤" : "󰐊"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                width: Style.space(18)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(26)
                spacing: Style.space(1)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  textFormat: Text.PlainText
                  text: sourceRow.sourceTitle
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: sourceRow.selected
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  textFormat: Text.PlainText
                  text: sourceRow.sourceDetail
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                  visible: text !== ""
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.mediaService) root.mediaService.selectPlayer(root.mediaService.playerKey(sourceRow.player))
            }
          }
        }
      }
    }
  }
}
