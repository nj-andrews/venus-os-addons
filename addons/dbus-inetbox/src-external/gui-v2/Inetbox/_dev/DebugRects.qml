import QtQuick
import QtQuick.Controls.impl as CP
import QtQuick.Templates as T
import QtQuick.Shapes
import QtQuick.Layouts
import QtQuick.Controls as QCTL

Rectangle {
    id: root
    color: "black"
    anchors.fill: parent
    focus: true // Necessary to capture keyboard events

    // --- KEYBOARD FILTER TOGGLES ---
    // Press '1' to toggle layout containers (RowLayout / ColumnLayout)
    // Press '2' to toggle leaf visual items (Labels, Images, Rectangles)
    property bool showLayoutBorders: true
    property bool showItemBorders: true

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_1) {
            showLayoutBorders = !showLayoutBorders;
            console.log("Layout containers visibility:", showLayoutBorders);
        } else if (event.key === Qt.Key_2) {
            showItemBorders = !showItemBorders;
            console.log("Individual items visibility:", showItemBorders);
        }
    }

    RowLayout {
        id: mainRow
        width: parent.width
        height: parent.height
        spacing: 20

        //Temperatures
        ColumnLayout {
            id: tempsColumnLayout
            Layout.leftMargin: 20
            Layout.preferredWidth: tempValue.implicitWidth

            Label {
                id: tempValue
                font.pixelSize: 48
                text: "23°"
            }

            Label {
                font.pixelSize: 24
                color: "grey"
                visible: true
                text: 36 + "°"
            }
        }

        //Tanks
        Rectangle { Layout.preferredWidth: 350; Layout.fillHeight: true; color: '#1b1b1b' }

        // Input
        ColumnLayout {
            RowLayout {
                Image {
                    source: "qrc:/images/solaryield.svg"
                    fillMode: Image.PreserveAspectFit
                    sourceSize.height: 32
                }
                Label {
                    text: "240w"
                    font.pixelSize: 32
                }
            }

            RowLayout {
                Image {
                    source: "qrc:/images/alternator.svg"
                    fillMode: Image.PreserveAspectFit
                    sourceSize.height: 28
                }
                Label {
                    text: "124w"
                    font.pixelSize: 28
                }
            }
        }

        // Battery/charging info
        ColumnLayout {
            Layout.leftMargin: 40
            Layout.rightMargin: 40
            RowLayout {
                Image {
                    source: "qrc:/images/icon_battery_charging_24.svg"
                    fillMode: Image.PreserveAspectFit
                    sourceSize.height: 44
                }
                RowLayout {
                    Label {
                        id: batteryPecent
                        text: "56%"
                        font.pixelSize: 44
                        Layout.alignment: Qt.AlignBaseline
                    }
                    Label {
                        text: "812 w"
                        Layout.alignment: Qt.AlignBaseline
                    }
                }
            }

            Label {
                text: "1h 23m Remaining"
            }
        }

        // Loads
        ColumnLayout {
            RowLayout {
                Label {
                    text: "240w"
                    font.pixelSize: 32
                }
                Image {
                    source: "qrc:/images/acloads.svg"
                    fillMode: Image.PreserveAspectFit
                    sourceSize.height: 32
                }
            }
            RowLayout {
                Label {
                    text: "140w"
                    font.pixelSize: 32
                }
                Image {
                    source: "qrc:/images/dcloads.svg"
                    fillMode: Image.PreserveAspectFit
                    sourceSize.height: 32
                }
            }
        }
    }

		Component.onCompleted: {
			root.debugAllLayouts(root)
		}

    function debugAllLayouts(parentItem) {
        if (!parentItem || !parentItem.children) return;

        for (var i = 0; i < parentItem.children.length; ++i) {
            var child = parentItem.children[i];

            // Ignore overlays we already created
            if (child.objectName === "debug_overlay") continue;

            if (child.hasOwnProperty("visible") && child.visible) {
                // Determine item type string name to separate layouts from controls
                var typeStr = child.toString();
                var isLayoutContainer = (typeStr.indexOf("Layout") !== -1 || typeStr.indexOf("Grid") !== -1 || typeStr.indexOf("Row") !== -1 || typeStr.indexOf("Column") !== -1);

                // Color configuration: Green for Layout systems, Cyan for actual components
                var borderColor = isLayoutContainer ? "#00FF00" : "#00FFFF";
                var visibilityBinding = isLayoutContainer ? "root.showLayoutBorders" : "root.showItemBorders";

                // Generate clean, bulletproof QML code dynamically
                var qmlString =
                    "import QtQuick; " +
                    "Rectangle { " +
                    "    objectName: 'debug_overlay'; " +
                    "    color: 'transparent'; " +
                    "    border.color: '" + borderColor + "'; " +
                    "    border.width: 1; " +
                    "    z: 999999; " +
                    "    visible: " + visibilityBinding + "; " +
                    "    property var targetItem: null; " +
                    "    x: targetItem ? targetItem.mapToItem(parent, 0, 0).x : 0; " +
                    "    y: targetItem ? targetItem.mapToItem(parent, 0, 0).y : 0; " +
                    "    width: targetItem ? (targetItem.width > 0 ? targetItem.width : targetItem.implicitWidth) : 0; " +
                    "    height: targetItem ? (targetItem.height > 0 ? targetItem.height : targetItem.implicitHeight) : 0; " +
                    "}";

                try {
                    // Create the object safely under the root container scale
                    var overlay = Qt.createQmlObject(qmlString, root, "dynamicDebugOverlay");
                    if (overlay) {
                        overlay.targetItem = child;
                    }
                } catch(e) {
                    console.log("Overlay instantiation error: ", e);
                }
            }

            // Dig into nested layouts
            debugAllLayouts(child);
        }
    }

    component Label: Text { color: "white" }
}
