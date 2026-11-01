import QtQuick 2
import Theming 1.0

QtObject {
		Component.onCompleted: {
			titleList.countChanged.connect(function() {
				 updateTanksTheme()
				 updateTanksNavigationTheme()
			})

			tanks.rowCountChanged.connect(updateTanksTheme)
		}

		function updateTanksTheme() {
			if (!Themer.enabled) return

			if (tanksFlow.children.length > 0) {
				var children = tanksFlow.children
				for (var i = 0; i < children.length; ++i) {
					var tank = children[i]
					if (tank.children.length > 0) {
						var item = tank.children[0]
						if (item && item.hasOwnProperty("color"))
							item.color = Themer.tankBackgroundColor

						var item = tank.children[tank.children.length - 1]
						if (item && item.hasOwnProperty("color"))
							item.color = Themer.textColor

					}

				}
			}
		}

		function updateTanksNavigationTheme() {
			if (!Themer.enabled) return
			
			var children = titleList.children
			if (children.length > 3) {

				var item = children[children.length - 1]
				if (item && item.hasOwnProperty("iconId") && item.iconId == "icon-toolbar-enter")
					item.iconId += Themer.iconSuffixNormal

				var item = children[children.length - 2]
				if (item && item.hasOwnProperty("iconId") && item.iconId == "icon-toolbar-enter")
					item.iconId += Themer.iconSuffixNormal

				var item = children[children.length - 3]
				if (item && item.hasOwnProperty("gradient"))
					item.gradient.stops[0].color = Themer.backgroundColor

				var item = children[children.length - 4]
				if (item && item.hasOwnProperty("gradient"))
					item.gradient.stops[0].color = Themer.backgroundColor

			}

			if (!titleList.contentItem) {
				console.log("onUpdateTheme: titleList.contentItem is not ready")
				return
			}
			var children = titleList.contentItem.children
			for (var i = 0; i < children.length; ++i) {
				var item = children[i]
				if (item && item.hasOwnProperty("color"))
					item.color = Themer.textColor
			}
		}


	}