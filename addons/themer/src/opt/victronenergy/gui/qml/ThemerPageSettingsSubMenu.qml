import QtQuick 2
import "utils.js" as Utils

MbItemOptions {
  id: root
  description: qsTr("Current Theme")
  unknownOptionText: "System"
  bind:  Utils.path(bindPrefix, "/CurrentTheme")
  writeAccessLevel: User.AccessUser

  property string bindPrefix: "com.victronenergy.settings/Settings/Themer"
  property VBusItem availableThemesItem: VBusItem {
    bind:Utils.path(bindPrefix, "/AvailableThemes")
    onValueChanged: root.possibleValues=getAvailableThemes(availableThemesItem.value)
  }

  Component {
    id: mbOptionFactory
    MbOption {}
  }

	function getAvailableThemes(availableThemesString) {
    var availableThemes = Utils.stringToArray(availableThemesString)
		if (!availableThemes)
			return [];

		var options = [];

    options.push(mbOptionFactory.createObject(root, {"description": "System", "value": ""}))

		for (var i = 0; i < availableThemes.length; i++) {
			var params = {
				"description": availableThemes[i],
				"value": availableThemes[i]
      }
			options.push(mbOptionFactory.createObject(root, params));
		}

		return options;
	}

}
