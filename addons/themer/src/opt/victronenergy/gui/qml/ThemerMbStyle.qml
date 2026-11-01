import QtQuick 2
import Theming 1.0

QtObject {

 	Component.onCompleted: {

		if (Themer == undefined || !Themer.enabled)
			return

		if (textColor) {
			textColor = Qt.binding(function() { return Themer.textColor})
		}
		if (borderColor) {
			borderColor = Qt.binding(function() { return Themer.borderColor})
		}
		if (backgroundColor) {
			backgroundColor = Qt.binding(function() { return isCurrentItem ? Themer.backgroundColorSelected : Themer.backgroundColor })
		}
		if (backgroundColorService) {
			backgroundColorService = Qt.binding(function() { return isCurrentItem ? Themer.serviceBackgroundColorSelected : Themer.serviceBackgroundColor })
		}

		themer = Themer
	}

}
