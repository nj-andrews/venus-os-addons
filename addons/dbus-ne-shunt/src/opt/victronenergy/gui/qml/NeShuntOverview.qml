import QtQuick 2
import com.victron.velib 1.0
import "color-utils.js" as ColorUtils

VesperaCustomOverviewPage {
  id: root

  property string settingsPrefix: "com.victronenergy.settings/Settings/Devices/dbus_neshunt/"
  property MbStyle mbStyle: MbStyle {isCurrentItem: true}
  property string iconSuffix
  property string iconSuffixSelected

  VBusItem { id: customNameItem; bind: root.bindPrefix  ?  root.bindPrefix +"/CustomName" : undefined}
  VBusItem { id: internalLightItem; bind: root.bindPrefix  ?  root.bindPrefix +"/SwitchableOutput/InternalLights/State" : undefined }
  VBusItem { id: externalLightItem; bind: root.bindPrefix  ?  root.bindPrefix +"/SwitchableOutput/ExternalLights/State" : undefined }
  VBusItem { id: waterPumpItem; bind: root.bindPrefix  ?  root.bindPrefix +"/SwitchableOutput/WaterPump/State" : undefined }
  VBusItem { id: auxPowerItem; bind: root.bindPrefix  ?  root.bindPrefix +"/SwitchableOutput/Aux/State" : undefined }

  VBusItem { id: internalLightCustomNameItem; bind: root.bindPrefix  ?  root.bindPrefix +"/SwitchableOutput/InternalLights/Settings/CustomName" : undefined }
  VBusItem { id: externalLightCustomNameItem; bind: root.bindPrefix  ?  root.bindPrefix +"/SwitchableOutput/ExternalLights/Settings/CustomName" : undefined }
  VBusItem { id: waterPumpCustomNameItem; bind: root.bindPrefix  ?  root.bindPrefix +"/SwitchableOutput/WaterPump/Settings/CustomName" : undefined }
  VBusItem { id: auxPowerCustomNameItem; bind: root.bindPrefix  ?  root.bindPrefix +"/SwitchableOutput/Aux/Settings/CustomName" : undefined }
 
	function onAddService(uid) {
		if (root.bindPrefix) return false
		if (uid.startsWith("dbus/com.victronenergy.switch.neshunt_")) {
			var idx=uid.lastIndexOf("_sid_")
			if (idx == -1) return
			root.settingsPrefix="/Settings/Devices/" + uid.substring(idx+1)
			root.bindPrefix=uid
			return false
		}
	}

	function onRemoveService(uid) {
		if (root.bindPrefix === undefined) return false
		if (uid.startsWith("dbus/com.victronenergy.switch.neshunt_") && uid.lastIndexOf("_sid_") !== -1) {
			root.settingsPrefix=undefined
			root.bindPrefix=undefined
			return false
		}
	}

	Connections {
		target: mbStyle

    property color colorHelper

		function onTextColorChanged() {root.iconSuffix = getIconSuffix(mbStyle.textColor)}
    function onTextColorSelectedChanged() {root.iconSuffixSelected = getIconSuffix(mbStyle.textColorSelected)}
    function getIconSuffix(clr) {
      colorHelper = clr
      return ColorUtils.isDarkColor(colorHelper) ? "-dark" : "-light"
    }

    Component.onCompleted: {
      onTextColorChanged()
      onTextColorSelectedChanged()
    }
  }

  // Header
  Text {
      id: header
      text: customNameItem.value || qsTr("Ne-Shunt")
      color: mbStyle.textColor
      font.bold: true
      font.pixelSize: 14
      //font.bold: true
      anchors {
        top: parent.top
        left: parent.left
        topMargin: 4
        horizontalCenter: parent.horizontalCenter
      }
      horizontalAlignment: Text.AlignHCenter
  }

  // Centered row of 4 LargeRoundButton instances
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    spacing: 20

    LargeRoundButton {
			visible: root.bindPrefix
      text: internalLightCustomNameItem.value && internalLightCustomNameItem.length > 0 || qsTr("Indoor Lights")
      checked: internalLightItem.valid && internalLightItem.value != 0
      onCheckedChanged: { internalLightItem.setValue(checked ? 1 : 0)}
      iconId: root.iconSuffix ? "ne-shunt-inside-light" + (checked ? root.iconSuffixSelected : root.iconSuffix) : ""
    }
    LargeRoundButton {
			visible: root.bindPrefix
      text: externalLightCustomNameItem.value && externalLightCustomNameItem.length > 0 || qsTr("Outdoor Light")
      checked: externalLightItem.valid && externalLightItem.value != 0
      onCheckedChanged: { externalLightItem.setValue(checked ? 1 : 0)}
      iconId: root.iconSuffix ? "ne-shunt-outside-light" + (checked ? root.iconSuffixSelected : root.iconSuffix) : ""
    }
    LargeRoundButton {
			visible: root.bindPrefix
      text: waterPumpCustomNameItem.value && waterPumpCustomNameItem.length > 0 || qsTr("Water Pump")
      checked: waterPumpItem.valid && waterPumpItem.value != 0

      onCheckedChanged: { waterPumpItem.setValue(checked ? 1 : 0)}
      iconId: root.iconSuffix ? "ne-shunt-water-pump" + (checked ? root.iconSuffixSelected : root.iconSuffix) : ""
    }
    LargeRoundButton {
			visible: root.bindPrefix
      text: auxPowerCustomNameItem.value && auxPowerCustomNameItem.length > 0 || qsTr("Aux Power")
      checked: auxPowerItem.valid && auxPowerItem.value != 0
      onCheckedChanged: { auxPowerItem.setValue(checked ? 1 : 0)}
      iconId: root.iconSuffix ? "ne-shunt-aux-power" + (checked ? root.iconSuffixSelected : root.iconSuffix) : ""
      longPressDuration: 3000
    }
  }

}