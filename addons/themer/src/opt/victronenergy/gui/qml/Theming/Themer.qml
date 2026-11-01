pragma Singleton
import QtQuick 2
import ".."
import "../utils.js" as Utils

QtObject {

	property string bindThemerPrefix: "com.victronenergy.settings/Settings/Themer"

	property VBusItem darkModeItem: VBusItem { bind: "com.victronenergy.settings/Settings/GuiMods/DarkMode" }
	property VBusItem themeItem: VBusItem {
		bind: Utils.path(bindThemerPrefix, "/CurrentTheme")
		onValueChanged: updateBindings()
	}
	property VBusItem enabledItem: VBusItem {
		bind: "com.victronenergy.settings/Settings/Vespera/Packages/Themer/Enabled"
		onValueChanged: updateBindings()
	}
	property bool enabled: enabledItem.value !== undefined && enabledItem.value != 0

	property VBusItem textColorItem: VBusItem {}
	property VBusItem backgroundColorItem: VBusItem {}
  property VBusItem backgroundColorSelectedItem: VBusItem {}
	property VBusItem background2ColorItem: VBusItem {}

	property VBusItem iconSuffixNormalItem: VBusItem {}
 	property VBusItem iconSuffixSelectedItem: VBusItem {}
 	property VBusItem borderColoItem: VBusItem {}
  property VBusItem serviceBackgroundColorItem: VBusItem {}
  property VBusItem serviceBackgroundColorSelectedItem: VBusItem {}
  property VBusItem tankBackgroundColorItem: VBusItem {}

	property VBusItem color2Item: VBusItem {}

	Component.onCompleted: {

		updateBindings()
	}

  function updateBindings() {
		if (!enabled) return

		var themePath = Utils.path(bindThemerPrefix, "/Themes/", themeItem.valid ? themeItem.value : "")

		textColorItem.bind = Utils.path(themePath, "/TextColor")
		backgroundColorItem.bind = Utils.path(themePath, "/BackgroundColor")
		backgroundColorSelectedItem.bind = Utils.path(themePath, "/BackgroundColorSelected")
		background2ColorItem.bind = Utils.path(themePath, "/BackgroundColor2")

		tankBackgroundColorItem.bind = Utils.path(themePath, "/TankBackgroundColor")
		serviceBackgroundColorItem.bind = Utils.path(themePath, "/ServiceBackgroundColor")
    serviceBackgroundColorSelectedItem.bind = Utils.path(themePath, "/ServiceBackgroundColorSelected")

		iconSuffixNormalItem.bind = Utils.path(themePath, "/IconSuffixNormal")
		iconSuffixSelectedItem.bind = Utils.path(themePath, "/IconSuffixSelected")
		borderColoItem.bind = Utils.path(themePath, "/BorderColor")
		color2Item.bind = Utils.path(themePath, "/Color2")
	}

	property string textColor: resolveColor(textColorItem, "#000000", "#FFFFFF" )

	property string windowBackgroundColor : resolveColor(backgroundColorItem, "#FFFFFF", "#202020")

	property string backgroundColor: resolveColor(backgroundColorItem, "transparent", "transparent")
	property string backgroundColorSelected: resolveColor(backgroundColorSelectedItem, "#4790d0", "#4790d0")
	property string backgroundColor2: resolveColor(background2ColorItem, "transparent", "#303030" )

	property string serviceBackgroundColor: resolveColor(serviceBackgroundColorItem, "#ffe9b7", "#7d960f" )
	property string serviceBackgroundColorSelected: resolveColor(serviceBackgroundColorSelectedItem, "#2969a1", "#2969a1" )

	property string tankBackgroundColor: resolveColor(tankBackgroundColorItem, "white", "#929292" )

	property string iconSuffixNormal: resolveIconSuffix(iconSuffixNormalItem, "", "-active")

	property string iconSuffixSelected: resolveIconSuffix(iconSuffixSelectedItem, "-active","")
	property string borderColor: resolveColor(borderColoItem, "#ddd", "#505050")
	property string color2: resolveColor(color2Item, "#333333", "#c4c4c4")


	function subMenuIconBinding(isCurrentItem, icon, iconId) {
		if (!enabled) return
		if (!iconId)
			return ""
		!isCurrentItem && iconSuffixNormal
				? icon.opacity = 0.5
				: icon.opacity = 1
		return iconId + (isCurrentItem ? iconSuffixSelected : iconSuffixNormal)
	}

	function resolveIconSuffix(item, defaultLight, defaultDark) {
		if (!enabled) return ""
		var useDefaults = !item?.valid
		var darkMode = false
		var iconSuffix

		if (useDefaults) 	{
				var darkMode = darkModeItem.valid && darkModeItem.value == 1

				if (darkMode) {
					iconSuffix = defaultDark
				} else {
					iconSuffix = defaultLight
				}
		} else {
			iconSuffix = item.value
		}

		if (iconSuffix === undefined)
			iconSuffix = ""
		return iconSuffix
	}

  function resolveColor(item, defaultLight, defaultDark) {
		if (!enabled) return ""
		var useDefaults = !item?.valid
		var darkMode = false
		var clr

		if (useDefaults) {
			darkMode = darkModeItem.valid && darkModeItem.value == 1
			clr = darkMode ? defaultDark : defaultLight
		} else {
			clr = item.value
		}
		if (clr === undefined)
			clr = ""
		return clr
	}

}
