import QtQuick 2
import com.victron.velib 1.0

MbSubMenu {
	id: root

	property string sid
	property string bindPrefix
	property string serviceBindPrefix: "dbus/" + serviceName.value
	property bool hasDynamicSubpage: root.dynamicSubpage !== null
	property bool dynamicConnected: root.dynamicSubpage ? root.dynamicSubpage.connected : false
	property bool dynamicCanShow: root.dynamicSubpage ? root.dynamicSubpage.canShow : false
	property string dynamicDescription: root.dynamicSubpage && root.dynamicSubpage.description !== undefined && root.dynamicSubpage.description !== null ? root.dynamicSubpage.description : ""
	property string dynamicSummary: root.dynamicSubpage && root.dynamicSubpage.summary !== undefined && root.dynamicSubpage.summary !== null ? root.dynamicSubpage.summary : ""

	property VeQuickItem serviceName: VeQuickItem {uid: root.bindPrefix + "/ServiceName"}

	property VeQuickItem deviceKey: VeQuickItem {
		uid : root.bindPrefix + "/DeviceKey"
		onValueChanged: root.updateDynamicSubpage()
	}

	property VesperaPageDeviceDetails dynamicSubpage

	hasSubpage: dynamicCanShow
	//cornerMark: userHasWriteAccess && editable
	iconId: hasSubpage ? "icon-toolbar-enter" : ""
	description: dynamicDescription
	item.value: dynamicSummary

	Item {
		// provide extra padding when submenu is not visible we everything aligns
		height: 1
		width: dynamicCanShow ? 0 : 8

	}

	Component.onCompleted: {
		updateDynamicSubpage()
	}
	Component.onDestruction: {
		var page = root.dynamicSubpage
		root.dynamicSubpage = null
		root.subpage = null
		if (page)
			page.destroy()
	}


	function setDynamicSubpage(path) {
		var component = Qt.createComponent(path)
		if (component.status !== Component.Ready) {
			console.log("setDynamicSubpage:" + component.errorString())
			return false
		}

		var previousPage = root.dynamicSubpage
		root.dynamicSubpage = null
		root.subpage = null
		if (previousPage)
			previousPage.destroy()

		root.dynamicSubpage = component.createObject(null, {
			sid: sid,
			bindPrefix: root.bindPrefix,
			serviceBindPrefix: serviceBindPrefix})

		if (!root.dynamicSubpage)
			return false

		root.subpage = root.dynamicSubpage
		return true
	}

	function updateDynamicSubpage() {

		var key = (root.deviceKey.value || "").toString().trim().toLowerCase()
		if (key.length > 0 && setDynamicSubpage("VesperaPageDeviceDetails_%1.qml".arg(key)))
			return

		setDynamicSubpage("VesperaPageDeviceDetails.qml")
	}



}
