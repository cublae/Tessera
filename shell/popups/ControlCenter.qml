import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.services
import qs.components
import "cc"

// Quick settings: tiles, sliders, what is playing, and the pages behind them.
//
// Tiles for hardware the machine does not have -- no Wi-Fi card, no
// power-profiles-daemon, no gpu-screen-recorder -- are left out rather than
// shown dead, and the grid closes up behind them.
PopupLayer {
    id: root

    name: "control-center"
    align: "end"
    keyboard: true
    panelWidth: 352

    readonly property string page: Shell.ccPage

    function show(name: string): void {
        Shell.ccPage = name
    }

    // Escape on a page steps back to the main one before it closes anything.
    onEscape: () => {
        if (Shell.ccPage === "main") return false
        Shell.ccPage = "main"
        return true
    }

    readonly property var profiles: [PowerProfile.PowerSaver, PowerProfile.Balanced].concat(
        PowerProfiles.hasPerformanceProfile ? [PowerProfile.Performance] : [])

    function profileName(profile: int): string {
        switch (profile) {
        case PowerProfile.PowerSaver: return I18n.tr("power saver")
        case PowerProfile.Performance: return I18n.tr("performance")
        default: return I18n.tr("balanced")
        }
    }

    function profileIcon(profile: int): string {
        switch (profile) {
        case PowerProfile.PowerSaver: return "power-profile-power-saver-symbolic"
        case PowerProfile.Performance: return "power-profile-performance-symbolic"
        default: return "power-profile-balanced-symbolic"
        }
    }

    Item {
        width: root.panelWidth - root.padding * 2
        implicitHeight: pages.children[pages.currentIndex]?.implicitHeight ?? 0

        StackLayout {
            id: pages

            anchors.fill: parent
            currentIndex: ["main", "wifi", "bluetooth", "mixer", "mixer-input", "record", "session"].indexOf(root.page)

            // -- main ----------------------------------------------------------

            ColumnLayout {
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        visible: Battery.available
                        implicitWidth: chip.implicitWidth + 20
                        implicitHeight: 30
                        radius: 15
                        color: Theme.alpha(Theme.fg, 0.08)

                        RowLayout {
                            id: chip

                            anchors.centerIn: parent
                            spacing: 6

                            Icon {
                                name: Battery.iconName
                            }

                            Txt {
                                text: `${Math.round(Battery.percentage * 100)}%`
                            }
                        }

                        Tip {
                            text: Battery.tooltip()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    IconButton {
                        icon: "system-shutdown-symbolic"
                        radius: 15
                        color: hovered ? Theme.alpha(Theme.fg, 0.14) : Theme.alpha(Theme.fg, 0.08)
                        tooltip: I18n.tr("Session")
                        onClicked: root.show("session")
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8

                    QuickTile {
                        visible: Network.wifi !== null || Network.wired !== null
                        icon: Network.primary === "wired" ? "network-wired-symbolic" : Network.icon
                        label: I18n.tr("Internet")
                        subtitle: {
                            if (Network.primary === "wired") return I18n.tr("Wired")
                            if (!Network.wifi) return I18n.tr("Offline")
                            if (!Network.wifiEnabled) return I18n.tr("Off")
                            return Network.ssid || I18n.tr("Not connected")
                        }
                        active: Network.primary === "wired" || (Network.wifi !== null && Network.wifiEnabled)
                        expandable: Network.wifi !== null
                        onToggled: if (Network.wifi) Network.setWifiEnabled(!Network.wifiEnabled)
                        onExpand: root.show("wifi")
                    }

                    QuickTile {
                        visible: BluetoothState.available
                        icon: BluetoothState.powered ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
                        label: I18n.tr("Bluetooth")
                        subtitle: !BluetoothState.powered ? I18n.tr("Off")
                                  : BluetoothState.connectedDevice ? BluetoothState.name(BluetoothState.connectedDevice) || BluetoothState.connectedDevice.address
                                  : I18n.tr("On")
                        active: BluetoothState.powered
                        expandable: true
                        onToggled: BluetoothState.toggle()
                        onExpand: root.show("bluetooth")
                    }

                    // Cycles through what power-profiles-daemon offers; the
                    // performance profile exists only on hardware that has one.
                    QuickTile {
                        visible: Battery.profilesAvailable
                        icon: Icons.first([root.profileIcon(PowerProfiles.profile), "power-profile-balanced-symbolic"])
                        label: I18n.tr("Power")
                        subtitle: root.profileName(PowerProfiles.profile)
                        active: PowerProfiles.profile === PowerProfile.Performance
                        onToggled: {
                            const at = root.profiles.indexOf(PowerProfiles.profile)
                            PowerProfiles.profile = root.profiles[(at + 1) % root.profiles.length]
                        }
                    }

                    QuickTile {
                        visible: Recorder.available
                        icon: Recorder.recording ? "media-record-symbolic" : "camera-video-symbolic"
                        label: I18n.tr("Screen Record")
                        subtitle: Recorder.recording ? Recorder.clock(Recorder.elapsed) : I18n.tr("Off")
                        active: Recorder.recording
                        expandable: true
                        onToggled: Recorder.toggle()
                        onExpand: root.show("record")
                    }

                    QuickTile {
                        icon: "camera-photo-symbolic"
                        label: I18n.tr("Screenshot")
                        subtitle: I18n.tr("Region")
                        onToggled: {
                            Shell.close()
                            Compositor.screenshot()
                        }
                    }

                    QuickTile {
                        icon: Icons.first(["color-select-symbolic", "gtk-color-picker", "applications-graphics-symbolic"])
                        label: I18n.tr("Pick colour")
                        subtitle: I18n.tr("To clipboard")
                        onToggled: {
                            Shell.close()
                            Picker.pick()
                        }
                    }

                    QuickTile {
                        visible: Config.c.desktop.enabled
                        icon: Icons.first(["view-grid-symbolic", "preferences-desktop-symbolic", "video-display-symbolic"])
                        label: I18n.tr("Desktop")
                        subtitle: DesktopLayout.editing ? I18n.tr("Arranging") : I18n.tr("Arrange")
                        active: DesktopLayout.editing
                        onToggled: {
                            DesktopLayout.editing = !DesktopLayout.editing
                            if (DesktopLayout.editing) Shell.close()
                        }
                    }

                    QuickTile {
                        visible: Config.c.modules.notifications
                        icon: Icons.bell(Notifs.dnd)
                        label: I18n.tr("Notifications")
                        subtitle: Notifs.dnd ? I18n.tr("Silenced") : Notifs.count > 0 ? String(Notifs.count) : I18n.tr("None")
                        active: !Notifs.dnd && Notifs.count > 0
                        expandable: true
                        onToggled: Notifs.setDnd(!Notifs.dnd)
                        onExpand: Shell.toggle("notification-center", Shell.screen)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        visible: Audio.speaker !== null
                        Layout.fillWidth: true
                        spacing: 6

                        FatSlider {
                            Layout.fillWidth: true
                            value: Audio.speaker?.audio?.volume ?? 0
                            icon: Audio.volumeIcon(Audio.speaker?.audio?.volume ?? 0, Audio.speaker?.audio?.muted ?? false)
                            tooltip: I18n.tr("Volume")
                            onMoved: v => Audio.setVolume(Audio.speaker, v)
                        }

                        IconButton {
                            icon: "go-next-symbolic"
                            tooltip: I18n.tr("Volume mixer")
                            onClicked: root.show("mixer")
                        }
                    }

                    RowLayout {
                        visible: Audio.microphone !== null
                        Layout.fillWidth: true
                        spacing: 6

                        FatSlider {
                            Layout.fillWidth: true
                            value: Audio.microphone?.audio?.volume ?? 0
                            icon: Audio.micIcon(Audio.microphone?.audio?.volume ?? 0, Audio.microphone?.audio?.muted ?? false)
                            tooltip: I18n.tr("Microphone")
                            onMoved: v => Audio.setVolume(Audio.microphone, v)
                        }

                        IconButton {
                            icon: "go-next-symbolic"
                            tooltip: I18n.tr("Input devices")
                            onClicked: root.show("mixer-input")
                        }
                    }

                    FatSlider {
                        visible: Brightness.available
                        Layout.fillWidth: true
                        Layout.rightMargin: 36
                        value: Brightness.brightness
                        icon: "display-brightness-symbolic"
                        tooltip: I18n.tr("Brightness")
                        onMoved: v => Brightness.set(v)
                    }
                }

                MediaCard {}
            }

            // -- pages ---------------------------------------------------------

            NetworkPage {
                active: root.page === "wifi" && root.shown
                onBack: root.show("main")
            }

            BluetoothPage {
                active: root.page === "bluetooth" && root.shown
                onBack: root.show("main")
            }

            MixerPage {
                output: true
                onBack: root.show("main")
            }

            MixerPage {
                output: false
                onBack: root.show("main")
            }

            RecordPage {
                onBack: root.show("main")
            }

            SessionPage {
                onBack: root.show("main")
            }
        }
    }
}
