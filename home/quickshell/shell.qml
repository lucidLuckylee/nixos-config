// One menu controller and bar per screen.

import Quickshell
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: shell
            property var modelData

            MenuController {
                id: menus
                shapeHovered: bar.shapeHovered
                pointerPressed: bar.pointerPressed
                plainPillHovered: bar.plainPillHovered
                pinned: Pinentry.pending && Pinentry.screen === shell.modelData.name
                    ? "pinentry" : ""
            }

            EdgeGlow { modelData: shell.modelData }
            LauncherDismiss {
                modelData: shell.modelData
                hole: bar.launcherRect
            }

            Bar {
                id: bar
                modelData: shell.modelData

                openMenu: menus.openMenu
                shown: menus.shown
                onPillHover: (name, hovered) => menus.hover(name, hovered)
                onPillActivated: name => menus.toggle(name)
            }
        }
    }
}
