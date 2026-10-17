import QtQuick 2
import com.victron.velib 1.0
import "utils.js" as Utils

MbPage {
	id: root
	title: qsTrId("vespera_device_properties")

	property string sid
	property string bindPrefix
	property string serviceBindPrefix
	property bool canShow: false

	property VeQuickItem connectedItem: VeQuickItem {
			uid: root.serviceBindPrefix + "/Connected"
			onValueChanged: root.setVisibility()
	}

	Component.onCompleted: root.setVisibility()

	function setVisibility() {
		if (connectedItem.value == 1)
			canShow = true
	}

	property VeQuickItem productName: VeQuickItem {uid : root.bindPrefix + "/ProductName"}
	property VeQuickItem customName: VeQuickItem {uid : root.bindPrefix + "/CustomName"}
	property VeQuickItem deviceInstanceItem: VeQuickItem {uid : root.serviceBindPrefix + "/DeviceInstance"}

	property bool connected: connectedItem.value !== undefined && connectedItem.value == 1

	property string description: customName?.value
		? customName.value
		: productName?.value
			? productName.value + (deviceInstanceItem.value === undefined ? "" : " (" + deviceInstanceItem.value + ")")
			: "Unknown Device"

	function onRemoveDevice(removeDeviceCallback) {
		return false
	}
qsTrEx
	model: VisibleItemModel {
		MbSubMenu {
			id: device
			description: qsTranslate("PageAcCharger", "Device")
			subpage: Component {
				PageDeviceInfo {
					title: device.description
					bindPrefix: serviceBindPrefix.substring(5)
				}
			}
		}
	}

}
