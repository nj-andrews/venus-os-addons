import QtQuick
import Victron.VenusOS

QtObject {
	id: root

	property var page
	property string serviceUid
	property string settingsPrefix: _sidItem.valid ? Global.systemSettings.serviceUid + "/Settings/Devices/" + _sidItem.value : ""

	property VeQuickItem _sidItem: VeQuickItem {
		uid: root.serviceUid ? root.serviceUid + "/Sid" : ""
	}

	property var waterModeModel: [{
			"value": "0",
			//% "Off"
			"display": qsTrId("inetbox_off"),
			"color": "grey"
		}, {
			"value": "40.0",
			//% "Eco"
			"display": qsTrId("inetbox_eco"),
		}, {
			"value": "60.0",
			//% "Hot"
			"display": qsTrId("inetbox_hot"),
		}, {
			"value": "200.0",
			//% "Boost"
			"display": qsTrId("inetbox_boost"),
		}]

	property var heatingModeModel: [{
			"value": "off",
			//% "Off"
			"display": qsTrId("inetbox_off"),
			"color": "grey"
		}, {
			"value": "eco",
			//% "Eco"
			"display": qsTrId("inetbox_eco"),
		}, {
			"value": "high",
			//% "High"
			"display": qsTrId("inetbox_high"),
		}]

	property var airconModeModel: [{
			"value": "off",
			//% "Off"
			"display": qsTrId("inetbox_off"),
			"color": "grey"
		}, {
			"value": "cool",
			//% "Cool"
			"display": qsTrId("inetbox_cool"),
		}, {
			"value": "vent",
			//% "Vent"
			"display": qsTrId("inetbox_vent"),
		}, {
			"value": "Vent",
			"display": qsTrId("inetbox_hot"),
		}, {
			"value": "auto",
			//% "Auto"
			"display": qsTrId("inetbox_auto"),
		}]

	property var airconFanSpeedModel: [{
			"value": "low",
			//% "Low"
			"display": qsTrId("inetbox_low"),
		}, {
			"value": "mid",
			//% "Mid"
			"display": qsTrId("inetbox_mid"),
		}, {
			"value": "high",
			//% "High"
			"display": qsTrId("inetbox_high"),
		}, {
			"value": "night",
			//% "Night"
			"display": qsTrId("inetbox_night"),
		}, {
			"value": "auto",
			//% "Auto"
			"display": qsTrId("inetbox_auto"),
		}]

	property var energyMixModel: [{
			"value": "gas",
			//% "Gas"
			"display": qsTrId("inetbox_gas"),
			//"color": '#ffab03'
		}, {
			"value": "mix1",
			//% "Mix1"
			"display": qsTrId("inetbox_mix1"),
			//"color": "green"
		}, {
			"value": "mix2",
			//% "Mix2"
			"display": qsTrId("inetbox_mix2"),
			//"color": "green"
		}, {
			"value": "el1",
			//% "El1"
			"display": qsTrId("inetbox_el1"),
			//"color": "lightskyblue"
		}, {
			"value": "el2",
			//% "El2"
			"display": qsTrId("inetbox_el2"),
			//"color": "lightskyblue"
		}]
	function displayTextFromModelValue(model, value, name) {
		var idx = indexFromModelValue(model,value,name)
		return idx == -1 ? "--" : model[idx].display
	}
	function indexFromModelValue(model, value, name) {
		for (var i = 0; i < model.length; i++)
			if (value == model[i].value) {
				return i;
			}
		return -1;
	}
}
