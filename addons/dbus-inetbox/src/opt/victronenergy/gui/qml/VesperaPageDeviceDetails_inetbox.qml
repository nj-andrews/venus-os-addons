import QtQuick 2
import com.victron.velib 1.0

VesperaPageDeviceDetails {
	id: root

	property string summary: root.connected ? "Ok" : "Not Connected"

}

