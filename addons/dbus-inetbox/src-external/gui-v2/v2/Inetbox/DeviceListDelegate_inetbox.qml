import QtQuick
import Victron.VenusOS

DeviceListDelegate {
	id: root

	quantityModel: QuantityObjectModel {
		filterType: QuantityObjectModel.HasValue

		QuantityObject {
			object: temperature
			unit: Global.systemSettings.temperatureUnit
		}
	}

	onClicked: {
		Global.pageManager.pushPage("qrc:/Inetbox/InetboxDevicePage.qml",
				{ serviceUid : root.device.serviceUid })
	}

	VeQuickItem {
		id: temperature
		uid: root.device.serviceUid + "/Values/CurrentRoomTemp"
		sourceUnit: Units.unitToVeUnit(VenusOS.Units_Temperature_Celsius)
		displayUnit: Units.unitToVeUnit(Global.systemSettings.temperatureUnit)
	}


}
