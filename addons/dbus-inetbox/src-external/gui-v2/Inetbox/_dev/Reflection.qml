import QtQuick
import Qt5Compat.GraphicalEffects

Rectangle {
	id: root
	color: "black"
	anchors.fill: parent

Rectangle {
        id: original

        width: 100
        height: 100
        radius: 50

        color: "red"
        border.width: 1
        border.color: "yellow"
    }

		Item {
        id: reflection
        y: original.height
        width: original.width
        height: original.height

        Rectangle {
            id: reflectionMask
            anchors.fill: parent
            visible: false

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: '#87ffffff'
                }
                GradientStop {
                    position: 0.8
                    color: "#00ffffff"
                }
            }
        }

        OpacityMask {
            anchors.fill: parent

            source: ShaderEffectSource {
                sourceItem: original

                transform: Scale {
                    origin.x: width / 2
                    origin.y: height / 2
                    yScale: -1
                }
            }

            maskSource: reflectionMask
        }
    }
}