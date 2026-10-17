import QtQuick 2

MbPage {
	id: root;
	model: VesperaDeviceDelegateModel {}
	pageToolbarHandler: model.count > 0 ? customToolbar : undefined

	required property MbStyle mbStyle: MbStyle {}
	required property VesperaManager vesperaManager

	onActiveChanged: { dialog.close() }

	VesperaDialog {id: dialog}

	function removeDevicePrompt() {
		if (root.vesperaManager.running)
			return

		var itm = root.listview.currentItem
		dialog.buttonsModel = [{text: qsTrId("vespera_yes")}, {id:"y",text: qsTrId("vespera_no") }]
		dialog.show(qsTrId("vespera_remove_device") + " " + itm.description, "", function(id) {
			if (id == "y")
				vesperaManager.removeDevice(itm.sid);
		})
	}
	listview.visible: model.count > 0

	Text {
		text: qsTrId("vespera_no_devices_saved")
		font.pixelSize: root.mbStyle.fontPixelSize
		horizontalAlignment: Text.AlignHCenter
		color: root.mbStyle.textColor
		visible: model.count == 0
		anchors.centerIn: parent
	}

	ToolbarHandler {
		id: customToolbar
		leftText: !root.vesperaManager.running
				? model.count > 0
					? qsTrId("vespera_remove")
					: ""
				: qsTrId("vespera_removing")
		function leftAction() {
			root.removeDevicePrompt()
		}
	}
}
