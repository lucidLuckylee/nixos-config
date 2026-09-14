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
