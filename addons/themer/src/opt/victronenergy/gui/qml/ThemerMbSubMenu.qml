import QtQuick 2
import Theming 1.0

QtObject {


	Component.onCompleted: {

		if (!Themer.enabled) return

		if (icon && icon.iconId) {

		icon.iconId = Qt.binding(function() {
		  return Themer.subMenuIconBinding(root.ListView.isCurrentItem, icon, root.iconId)
		})

		}
	}
}
