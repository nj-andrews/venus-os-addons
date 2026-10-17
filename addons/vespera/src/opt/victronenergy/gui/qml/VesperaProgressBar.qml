import QtQuick 2

Item {
	id: root

	property MbStyle mbStyle: MbStyle {}
	property alias text: label.text

	property real progress: -1

	readonly property color textColor: mbStyle ? mbStyle.textColor : "#000000"
	readonly property color trackColor: mbStyle && mbStyle.themer
			? (mbStyle.themer.backgroundColor2 || "#cecece")
			: "#cecece"
	readonly property color fillColor: mbStyle && mbStyle.themer
			? (mbStyle.themer.borderColor || "#2f6db6")
			: "#2f6db6"
	readonly property real effectiveProgress: Math.max(0, Math.min(1, root.progress))
	readonly property bool indeterminate: root.progress < 0

	Item {
		anchors.centerIn: parent
		width: Math.min(parent.width, 520)
		height: label.implicitHeight + 10 + progressTrack.height

		Label {
			id: label
			anchors.top: parent.top
			anchors.horizontalCenter: parent.horizontalCenter
			color: root.textColor
		}

		Rectangle {
			id: progressTrack
			anchors.top: label.bottom
			anchors.topMargin: 10
			anchors.left: parent.left
			anchors.right: parent.right
			height: 8
			radius: 8
			color: root.trackColor
			clip: true

			Rectangle {
				id: progressFill
				height: parent.height
				radius: parent.radius
				color: root.fillColor
				width: root.indeterminate
						? Math.max(48, progressTrack.width * 0.25)
						: Math.round(progressTrack.width * root.effectiveProgress)
				x: root.indeterminate ? -width : 0

				SequentialAnimation on x {
					running: root.indeterminate && progressTrack.width > 0
					loops: Animation.Infinite
					NumberAnimation {
						from: -progressFill.width
						to: progressTrack.width
						duration: 1000
						easing.type: Easing.InOutQuad
					}
				}
			}
		}
	}
}