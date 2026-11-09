import QtQuick 2
import com.victron.velib 1.0

MbOK {
	description: qsTr("Vespera example 01 custom menu")
	value: qsTr("Press me")
	cornerMark: false
	onClicked: {
		toast.createToast(qsTr("Hello world"), 3000);
	}
	x: -2000
}