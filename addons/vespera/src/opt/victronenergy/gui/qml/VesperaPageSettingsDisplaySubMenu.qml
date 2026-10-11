import QtQuick 2

MbSwitch {
  bind: "com.victronenergy.settings/Settings/Vespera/CustomMenus/PageMain/PageHome"
  name: qsTr("Move settings to top")
  valueFalse: ""
  valueTrue: "^"
	x: -2000
}
