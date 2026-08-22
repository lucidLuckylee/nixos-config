// Quickshell entry point.
//
// Quickshell loads this file and keeps it loaded; everything on screen is a
// window declared from here. The palette and the store paths of generated
// helpers arrive as the Theme, Paths and Session singletons, which
// ../quickshell.nix writes into this same directory at build time — that is the
// only reason this directory is assembled rather than symlinked wholesale.
//
// One Scope per monitor, holding one window and the one object that decides
// what it shows. The bar and its menus are a single layer surface (see
// Bar.qml), drawn as a single shape (see Chrome.qml), so there are no two
// surfaces here that have to be kept in agreement — which is most of what this
// file used to be for.

import Quickshell
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: shell
            property var modelData

            // Every pill and every page is addressed by name, so all the state
            // between the pointer and the drawing is the handful of strings and
            // flags in here. See MenuController.qml for the hover rules.
            MenuController {
                id: menus
                shapeHovered: bar.shapeHovered
            }

            Bar {
                id: bar
                modelData: shell.modelData

                openMenu: menus.openMenu
                shown: menus.shown
                onPillHover: (name, hovered) => menus.hover(name, hovered)
            }
        }
    }
}
