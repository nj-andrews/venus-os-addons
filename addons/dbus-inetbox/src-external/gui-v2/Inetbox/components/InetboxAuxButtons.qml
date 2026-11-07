import QtQuick
import QtQuick.Layouts
import Victron.VenusOS
import QtQuick.Controls.impl as CP

 Item {
	id: root

	property var inetboxModel
	property var hasScheduleColor: '#028a00'
	property var buttonOffset: 0
	readonly property bool portrait: Theme.screenSize === Theme.Portrait
	readonly property int buttonSpacing: 20

	implicitWidth: Math.max(scheduleButton.implicitWidth, errorButton.implicitWidth + buttonOffset)

	implicitHeight: scheduleButton.height + (errorButton.visible
		? (portrait ? 0 : buttonSpacing + errorButton.height)
		: 0)

	AuxButton {
		id: scheduleButton
		icon.source: "qrc:/images/icon_manualstart_timer_24.svg"
		mainColor: root.inetboxModel.schedulesStateItem.value == 0 ? '#387dc5' : root.hasScheduleColor
		visible: root.inetboxModel.device
		anchors.left: parent.left

		onClicked: {
			Global.pageManager.pushPage("qrc:/Inetbox/InetboxSchedules.qml",
					{ "inetboxModel": root.inetboxModel, indicatorColor: root.hasScheduleColor })
		}
	}
	AuxButton {
		id: errorButton
		icon.source: "qrc:/images/icon_alarm_32.svg"
		mainColor: Theme.color_warning
		secondaryColor: Theme.color_darkWarning
		visible: root.inetboxModel.hasError
		anchors {
			top: root.portrait ? parent.top : scheduleButton.bottom
			left: root.portrait ? parent.right : scheduleButton.left
			topMargin: root.portrait ? 0 : root.buttonSpacing
			leftMargin: root.portrait ? root.buttonSpacing : root.buttonOffset
		}

		onClicked: {
			if (root.inetboxModel.seenError === undefined) {
				root.inetboxModel.seenError = root.inetboxModel.errorCodeItem.value
				secondaryColor  = mainColor
			} else {
				root.inetboxModel.seenError = undefined
				secondaryColor  = Theme.color_darkWarning
			}
		}
	}
	// Label {
	// 	anchors {
	// 		top: parent.top
	// 		left: errorButton.right
	// 		topMargin: 0
	// 		leftMargin: root.buttonSpacing
	// 	}
	// 	text: auxButton.implicitHeight
	// }
}
