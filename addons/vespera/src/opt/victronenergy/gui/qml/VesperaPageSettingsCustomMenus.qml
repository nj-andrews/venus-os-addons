import QtQuick 2
import com.victron.velib 1.0
import "vespera-utils.js" as VesperaUtils

QtObject {

	property Connections connections: Connections{
		target: root
		function on_SubpageInstanceChanged() { _onSubpageInstanceChanged()}
	}

 	readonly property string baseDbusCustomMenusPath: "dbus/com.victronenergy.settings/Settings/Vespera/CustomMenuPages/"

	property VeQuickItem customItems: VeQuickItem {
		onValueChanged: _addItems()
	}

  function _addItems() {
    if (customItems.value === undefined)
      return

    VesperaUtils.addRemoveCustomItemsQuick(customItems, _subpageInstance.model,
			function (componentName) {
				return {
					component: Qt.createComponent(componentName),
				 	parent: _subpageInstance.listview.contentItem,
				 	args: {}
				 	}
			},
			indexFromDescription
		)

    customItems.uid = null
  }

	function indexFromDescription(model, description) {
		var translatedDescription = qsTr(description) //use qsTr so we translate to UI text

		//TODO var translatedDescription = qsTranslate([pagename], description) //use qsTr so we translate to UI text
		//TODO change to a straight index?
		
		for (var i = 0; i < model.count; i++)
			if (model.get(i).description === translatedDescription)
				return i
		return -1
	}

  function _onSubpageInstanceChanged()  {
    if (!_subpageInstance)
      return

    var pageName = _subpageInstance.toString()
    pageName = pageName.split("_")[0]
		if (pageName) customItems.uid = baseDbusCustomMenusPath + pageName
  }

}
