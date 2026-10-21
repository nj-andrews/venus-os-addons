import QtQuick
import Victron.VenusOS
import Victron.Gauges
import QtQuick.Controls 2.12
import "./components" as IC

SwipeViewPage {
	id: root

	//% "Motorhome"
	title: qsTrId("inetbox_motorhome")
	iconSource: "qrc:/Inetbox/images/motorhome.svg"
	url: "qrc:/Inetbox/MotorhomePage.qml"

	fullScreenWhenIdle: true
	topLeftButton: VenusOS.StatusBar_LeftButton_ControlsInactive

	Component.onCompleted: {

		inetbox.device = devices.firstObject

		console.log("Inetbox: onCompleted:",
			"page=", url,
			"version=", inetbox.version,
			"device.firstObject=", devices.firstObject)
	}
	Component.onDestruction: {
		console.log("Inetbox: onDestruction:", "page=", url, "version=", inetbox.version)
	}

	FilteredDeviceModel {
		id: devices
		serviceTypes: ["inetbox"]
		onFirstObjectChanged: {
			inetbox.device = devices.firstObject
		}

	}

	GaugeModel { id: tankGauges } // aka storage tanks

	Loader {
		id: pageLoader

		anchors.fill: parent
		sourceComponent: Theme.screenSize === Theme.Portrait ? portraitComponent : landscapeComponent
		focus: true

		Component {
			id: landscapeComponent

			MotorhomePage_Landscape {

				title: root.title
				inetboxModel: inetbox
				gaugeModel: tankGauges
				animationEnabled: root.animationEnabled
			}
		}

		Component {
			id: portraitComponent

			MotorhomePage_Portrait {
				title: root.title
				inetboxModel: inetbox
				gaugeModel: tankGauges
				animationEnabled: root.animationEnabled
			}
		}
	}

	////////////////////////////////////////////
	// Components
	////////////////////////////////////////////
	component VeQuickItemTemperature: VeQuickItem {
			sourceUnit: Units.unitToVeUnit(VenusOS.Units_Temperature_Celsius)
			displayUnit: Units.unitToVeUnit(Global.systemSettings.temperatureUnit)
	}

////////////////////////////////////////////
// Data
////////////////////////////////////////////

	InetboxModel {
		id: inetbox
		serviceUid: device?.serviceUid ?? ""
		page: root

		property var seenError
		property var device : null
		property bool showAircon : showAirconItem.valid && showAirconItem.value == 1
		function bindPrefix(name) { return device ? device.serviceUid + "/Values" + name : ""}
		function bindSettingsPrefix(name) { return settingsPrefix ? settingsPrefix + name : ""}

		property string version: GuiPluginLoader.plugin("Inetbox").version

		property bool heatingOn: heatingModeItem.valid && heatingModeItem.value != "off"
		property bool airconOn: showAircon && airconModeItem.valid && airconModeItem.value != "off"
		readonly property real targetTemperature: (heatingOn ? heatingTargetTempItem.value : airconTargetTemperatureItem.value) ?? NaN

		property VeQuickItemTemperature currentTemperatureItem: VeQuickItemTemperature {uid: inetbox.bindPrefix("/CurrentRoomTemp")}
		property VeQuickItemTemperature waterCurrentTemperatureItem: VeQuickItemTemperature {uid: inetbox.bindPrefix("/WaterCurrentTemp")}
		property VeQuickItem waterTargetTemperatureItem: VeQuickItem { uid: inetbox.bindPrefix("/WaterTargetTemp")}
		property VeQuickItem heatingModeItem: VeQuickItem { uid: inetbox.bindPrefix("/HeatingMode")}
		property VeQuickItemTemperature heatingTargetTempItem: VeQuickItemTemperature {uid: inetbox.bindPrefix("/HeatingTargetTemp")}
		property VeQuickItem airconModeItem: VeQuickItem {uid: inetbox.bindPrefix("/AirconMode")}
		property VeQuickItemTemperature airconTargetTemperatureItem: VeQuickItemTemperature { uid: inetbox.bindPrefix("/AirconTargetTemp")}
		property VeQuickItem airconFanSpeedItem: VeQuickItem {uid: inetbox.bindPrefix("/AirconFanSpeed")}
		property VeQuickItem energyMixItem: VeQuickItem {uid: inetbox.bindPrefix("/EnergyMixCombined")}
		property VeQuickItem showAirconItem: VeQuickItem {uid: inetbox.bindSettingsPrefix("/ShowAircon")}
		property VeQuickItem errorCodeItem: VeQuickItem {uid: inetbox.bindPrefix("/Error")}
 		property VeQuickItem errorDescriptionItem: VeQuickItem {uid: inetbox.bindPrefix("/ErrorDescription")}
		property VeQuickItem schedulesStateItem: VeQuickItem {uid:  inetbox.bindSettingsPrefix("/Schedules/State") }

	  property bool hasError: errorCodeItem.valid && errorCodeItem.value != 0

		// Component.onCompleted: {
		// 	console.log("InetboxModel:",
		// 	"showAirconItem.uid =", showAirconItem.uid,
		// 	"showAirconItem.valid =", showAirconItem.valid,
		// 	"showAirconItem.value =", showAirconItem.value,
		// 	"errorCodeItem.valid =", errorCodeItem.valid,
		// 	"errorCodeItem.value =", errorCodeItem.value,
		// 	)
		// }

		onHeatingOnChanged: exclusiveHeating(airconModeItem)
		onAirconOnChanged: exclusiveHeating(heatingModeItem)

		function exclusiveHeating(itemToTurnOff) {
			if (heatingOn === true && airconOn === true)
				itemToTurnOff.setValue("off")
		}

		function updateTargetTemperature(value) {
			if (heatingOn) {
				heatingTargetTempItem.setValue(value)
			} else if (airconOn) {
				airconTargetTemperatureItem.setValue(value)
			}
		}


	}

}
