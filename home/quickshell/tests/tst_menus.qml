import QtQuick
import QtTest
import ".." as Shell

TestCase {
    id: test
    name: "BarMenus"
    width: 640
    height: 480
    when: windowShown
    visible: true

    property var scene
    Component {
        id: fixture
        Item {
            width: 640
            height: 480
            property alias menus: menus
            property alias surface: surface
            property alias slider: slider
            property int clicks: 0

            Shell.MenuController {
                id: menus
                shapeHovered: surface.hovered
                pointerPressed: surface.pressed
            }
            Shell.MenuSurface {
                id: surface
                width: 600
                height: 300
                Repeater {
                    model: ["volume", "clock"]
                    Item {
                        required property string modelData
                        required property int index
                        x: 380 + index * 110
                        width: 100
                        height: 28
                        HoverHandler {
                            onHoveredChanged: menus.hover(parent.modelData, hovered)
                        }
                        TapHandler { onTapped: menus.toggle(parent.modelData) }
                    }
                }
                Item {
                    x: 300; y: 40; width: 280; height: 50
                    HoverHandler {}
                    Item {
                        x: 200; width: 40; height: 30
                        HoverHandler {}
                        TapHandler { onTapped: test.scene.clicks++ }
                    }
                }
                MouseArea {
                    id: slider
                    x: 300; y: 100; width: 280; height: 30
                    hoverEnabled: true
                    property real value: 0
                    onPressed: event => value = event.x
                    onPositionChanged: event => { if (pressed) value = event.x; }
                }
            }
        }
    }

    function init() {
        scene = createTemporaryObject(fixture, test)
        verify(scene)
        verify(waitForRendering(scene))
        mouseMove(scene, 620, 450)
    }

    function openVolume() {
        mouseMove(scene, 430, 14)
        tryCompare(scene.menus, "openMenu", "volume")
    }

    function test_stationaryPillStaysOpen() {
        openVolume()
        verify(scene.surface.hovered)
        wait(scene.menus.closeDelay * 2)
        compare(scene.menus.openMenu, "volume")
    }

    function test_nestedControlsAndEmptyStripKeepMenuOpen() {
        openVolume()
        mouseMove(scene, 520, 55)
        verify(scene.surface.hovered)
        wait(scene.menus.closeDelay + 50)
        compare(scene.menus.openMenu, "volume")
        mouseClick(scene, 520, 55)
        compare(scene.clicks, 1, "Surface observation must not consume clicks")
        mouseMove(scene, 250, 14)
        wait(scene.menus.closeDelay + 50)
        compare(scene.menus.openMenu, "volume")
    }

    function test_sliderHoverAndDragOutside() {
        openVolume()
        mouseMove(scene, 400, 115)
        verify(scene.surface.hovered)
        wait(scene.menus.closeDelay + 50)
        compare(scene.menus.openMenu, "volume")
        mousePress(scene, 400, 115)
        verify(scene.surface.pressed)
        verify(scene.slider.pressed)
        mouseMove(scene, 620, 400)
        wait(scene.menus.closeDelay + 50)
        compare(scene.menus.openMenu, "volume")
        verify(scene.slider.value > scene.slider.width)
        mouseRelease(scene, 620, 400)
        verify(!scene.surface.pressed)
        tryCompare(scene.menus, "openMenu", "")
    }

    function test_leaveAndReenterDuringGracePeriod() {
        openVolume()
        mouseMove(scene, 620, 450)
        wait(100)
        compare(scene.menus.openMenu, "volume")
        mouseMove(scene, 400, 200)
        wait(scene.menus.closeDelay + 50)
        compare(scene.menus.openMenu, "volume")
        mouseMove(scene, 620, 450)
        tryCompare(scene.menus, "openMenu", "")
        compare(scene.menus.shown, "volume", "Closing animation retains its page")
    }

    function test_crossingAnotherPillDoesNotSwitch() {
        openVolume()
        mouseMove(scene, 540, 14)
        wait(30)
        compare(scene.menus.openMenu, "volume")
        mouseMove(scene, 400, 200)
        wait(scene.menus.switchDelay + 50)
        compare(scene.menus.openMenu, "volume")
        mouseMove(scene, 540, 14)
        tryCompare(scene.menus, "openMenu", "clock")
    }

    function test_briefHoverDoesNotOpen() {
        mouseMove(scene, 430, 14)
        wait(30)
        compare(scene.menus.openMenu, "")
        mouseMove(scene, 620, 450)
        wait(scene.menus.openDelay + 50)
        compare(scene.menus.openMenu, "")
    }

    function test_clickImmediatelyOpensAndDismisses() {
        mouseMove(scene, 430, 14)
        mouseClick(scene, 430, 14)
        compare(scene.menus.openMenu, "volume")
        mouseClick(scene, 430, 14)
        compare(scene.menus.openMenu, "")
        wait(scene.menus.openDelay + 50)
        compare(scene.menus.openMenu, "", "Click dismissal lasts until the pill is left")
        mouseMove(scene, 250, 14)
        openVolume()
    }

    function test_oldLeaveCannotCancelNewPill() {
        scene.menus.hover("volume", true)
        scene.menus.hover("clock", true)
        scene.menus.hover("volume", false)
        tryCompare(scene.menus, "openMenu", "clock")
    }
}
