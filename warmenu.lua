-- Modified version of WarMenu by Ali Exacute#2588
-- Unmodified version : https://github.com/warxander/warmenu
WarMenu = { }
WarMenu.__index = WarMenu

local menus = { }
local keys = { down = 187, up = 188, left = 189, right = 190, select = 191, back = 194 }
local optionCount = 0

local currentKey = nil
local currentMenu = nil

local toolTipWidth = 0.153

local spriteWidth = 0.027
local spriteHeight = spriteWidth * GetAspectRatio()

local titleHeight = 0.101
local titleYOffset = 0.021
local titleFont = 1
local titleScale = 1.0

local buttonHeight = 0.038
local buttonFont = 0
local buttonScale = 0.365
local buttonTextXOffset = 0.005
local buttonTextYOffset = 0.005
local buttonSpriteXOffset = 0.002
local buttonSpriteYOffset = 0.005

local defaultStyle = {
	x = 0.0175,
	y = 0.025,
	width = 0.23,
	maxOptionCountOnScreen = 10,
	titleColor = { 255, 255, 255, 255 },
	titleBackgroundColor = { 33, 81, 156, 255 },
	titleBackgroundSprite = nil,
	subTitleColor = { 27, 98, 191, 255 },
	textColor = { 255, 255, 255, 255 },
	subTextColor = { 189, 189, 189, 255 },
	focusTextColor = { 0, 0, 0, 255 },
	focusColor = { 245, 245, 245, 255 },
	backgroundColor = { 0, 0, 0, 160 },
	subTitleBackgroundColor = { 0, 0, 0, 255 },
	buttonPressedSound = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' }, --https://pastebin.com/0neZdsZ5
}

local scrolled = 0
local lastScrollTimes = {}
for _, key in pairs({ keys.up, keys.down, keys.left, keys.right }) do
	lastScrollTimes[key] = GetGameTimer()
end
local scrollIntervalDefault = 200

scrollInterval = scrollIntervalDefault

local function setMenuProperty(id, property, value)
	if not id then
		return
	end

	local menu = menus[id]
	if menu then
		menu[property] = value
	end
end

local function setStyleProperty(id, property, value)
	if not id then
		return
	end

	local menu = menus[id]

	if menu then
		if not menu.overrideStyle then
			menu.overrideStyle = { }
		end

		menu.overrideStyle[property] = value
	end
end

local function getStyleProperty(property, menu)
	menu = menu or currentMenu

	if menu.overrideStyle then
		local value = menu.overrideStyle[property]
		if value then
			return value
		end
	end

	return menu.style and menu.style[property] or defaultStyle[property]
end

local function copyTable(t)
	if type(t) ~= 'table' then
		return t
	end

	local result = { }
	for k, v in pairs(t) do
		result[k] = copyTable(v)
	end

	return result
end

local function setMenuVisible(id, visible, holdCurrentOption)
	if currentMenu then
		if visible then
			if currentMenu.id == id then
				return
			end
		else
			if currentMenu.id ~= id then
				return
			end
		end
	end

	if visible then
		local menu = menus[id]

		if not currentMenu then
			menu.currentOption = 1
		else
			if not holdCurrentOption then
				menus[currentMenu.id].currentOption = 1
			end
		end

		currentMenu = menu
	else
		currentMenu = nil
	end
end

local function setTextParams(font, color, scale, center, shadow, alignRight, wrapFrom, wrapTo)
	SetTextFont(font)
	SetTextColour(color[1], color[2], color[3], color[4] or 255)
	SetTextScale(scale, scale)

	if shadow then
		SetTextDropShadow()
	end

	if center then
		SetTextCentre(true)
	elseif alignRight then
		SetTextRightJustify(true)
	end

	if not wrapFrom or not wrapTo then
		wrapFrom = wrapFrom or getStyleProperty('x')
		wrapTo = wrapTo or getStyleProperty('x') + getStyleProperty('width') - buttonTextXOffset
	end

	SetTextWrap(wrapFrom, wrapTo)
end

-- TODO maybe change how it is handled and make it find first space/enter and add from there
local function addLongString(text)
    for i = 100, string.len(text), 99 do
        local subStr = string.sub(text, i, i + 99)
        AddTextComponentSubstringPlayerName(subStr)
    end
end

function getLinesCount(text, x, y)
	BeginTextCommandLineCount('TWOSTRINGS')
	AddTextComponentSubstringPlayerName(text)
	if string.len(text) > 99 then
		addLongString(text)
	end
	return EndTextCommandGetLineCount(x, y)
end

local function drawText(text, x, y)
	BeginTextCommandDisplayText('TWOSTRINGS')
	AddTextComponentSubstringPlayerName(text)
	if string.len(text) > 99 then
		addLongString(text)
	end
	EndTextCommandDisplayText(x, y)
end

local function drawRect(x, y, width, height, color)
	DrawRect(x, y, width, height, color[1], color[2], color[3], color[4] or 255)
end

local function getCurrentIndex()
	if currentMenu.currentOption <= getStyleProperty('maxOptionCountOnScreen') and optionCount <= getStyleProperty('maxOptionCountOnScreen') then
		return optionCount
	elseif optionCount > currentMenu.currentOption - getStyleProperty('maxOptionCountOnScreen') and optionCount <= currentMenu.currentOption then
		return optionCount - (currentMenu.currentOption - getStyleProperty('maxOptionCountOnScreen'))
	end

	return nil
end

local function drawTitle()
	local x = getStyleProperty('x') + getStyleProperty('width') / 2
	local y = getStyleProperty('y') + titleHeight / 2

	if getStyleProperty('titleBackgroundSprite') then
		DrawSprite(getStyleProperty('titleBackgroundSprite').dict, getStyleProperty('titleBackgroundSprite').name, x, y, getStyleProperty('width'), titleHeight, 0., 255, 255, 255, 255)
	else
		drawRect(x, y, getStyleProperty('width'), titleHeight, getStyleProperty('titleBackgroundColor'))
	end

	if currentMenu.title then
		setTextParams(titleFont, getStyleProperty('titleColor'), titleScale, true)
		drawText(currentMenu.title, x, y - titleHeight / 2 + titleYOffset)
	end
end

local function drawSubTitle()
	local x = getStyleProperty('x') + getStyleProperty('width') / 2
	local y = getStyleProperty('y') + titleHeight + buttonHeight / 2

	drawRect(x, y, getStyleProperty('width'), buttonHeight, getStyleProperty('subTitleBackgroundColor'))

	setTextParams(buttonFont, getStyleProperty('subTitleColor'), buttonScale, false)
	drawText(currentMenu.subTitle, getStyleProperty('x') + buttonTextXOffset, y - buttonHeight / 2 + buttonTextYOffset)

	if optionCount > getStyleProperty('maxOptionCountOnScreen') then
		setTextParams(buttonFont, getStyleProperty('subTitleColor'), buttonScale, false, false, true)
		drawText(tostring(currentMenu.currentOption)..' / '..tostring(optionCount), getStyleProperty('x') + getStyleProperty('width'), y - buttonHeight / 2 + buttonTextYOffset)
	end
end

local function drawButton(text, subText)
	local currentIndex = getCurrentIndex()
	if not currentIndex then
		return
	end

	local backgroundColor = nil
	local textColor = nil
	local subTextColor = nil
	local shadow = false

	if currentMenu.currentOption == optionCount then
		backgroundColor = getStyleProperty('focusColor')
		textColor = getStyleProperty('focusTextColor')
		subTextColor = getStyleProperty('focusTextColor')
	else
		backgroundColor = getStyleProperty('backgroundColor')
		textColor = getStyleProperty('textColor')
		subTextColor = getStyleProperty('subTextColor')
		shadow = true
	end

	local x = getStyleProperty('x') + getStyleProperty('width') / 2
	local y = getStyleProperty('y') + titleHeight + buttonHeight + (buttonHeight * currentIndex) - buttonHeight / 2

	drawRect(x, y, getStyleProperty('width'), buttonHeight, backgroundColor)

	setTextParams(buttonFont, textColor, buttonScale, false, shadow)
	drawText(text, getStyleProperty('x') + buttonTextXOffset, y - (buttonHeight / 2) + buttonTextYOffset)

	if subText then
		setTextParams(buttonFont, subTextColor, buttonScale, false, shadow, true)
		drawText(subText, getStyleProperty('x') + buttonTextXOffset, y - buttonHeight / 2 + buttonTextYOffset)
	end
end

function WarMenu.CreateMenu(id, title, subTitle, style)
	-- Default settings
	local menu = { }

	-- Members
	menu.id = id
	menu.previousMenu = nil
	menu.aboutToBeClosed = false
	menu.currentOption = 1
	menu.title = title
	menu.subTitle = subTitle and string.upper(subTitle) or 'INTERACTION MENU'

	-- Style
	if style then
		menu.style = style
	end

	menus[id] = menu
end

function WarMenu.CreateSubMenu(id, parent, title, subTitle, style)
	local parentMenu = menus[parent]
	if not parentMenu then
		return
	end

	WarMenu.CreateMenu(id, title, subTitle and string.upper(subTitle) or title and string.upper(title))

	local menu = menus[id]

	menu.previousMenu = parent

	if parentMenu.overrideStyle then
		menu.overrideStyle = copyTable(parentMenu.overrideStyle)
	end

	if style then
		menu.style = style
	elseif parentMenu.style then
		menu.style = copyTable(parentMenu.style)
	end
end

function WarMenu.CurrentMenu()
	return currentMenu and currentMenu.id or nil
end

function WarMenu.OpenMenu(id, noSound)
	if id and menus[id] then
		if not noSound then
			PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		end
		setMenuVisible(id, true)
	end
end

function WarMenu.IsMenuOpened(id)
	return currentMenu and currentMenu.id == id
end
WarMenu.Begin = WarMenu.IsMenuOpened

function WarMenu.IsAnyMenuOpened()
	return currentMenu ~= nil
end

function WarMenu.IsMenuAboutToBeClosed()
	return currentMenu and currentMenu.aboutToBeClosed
end

function WarMenu.CloseMenu()
	if not currentMenu then
		return
	end

	if currentMenu.aboutToBeClosed then
		currentMenu.aboutToBeClosed = false
		setMenuVisible(currentMenu.id, false)
		optionCount = 0
		currentKey = nil
		PlaySoundFrontend(-1, 'QUIT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
	else
		currentMenu.aboutToBeClosed = true
	end
end

function WarMenu.GoBack()
	if not currentMenu then
		return
	end
	
	setMenuVisible(currentMenu.previousMenu, true)
	PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

function WarMenu.ToolTip(text, width, heightOffset, flipHorizontal)
	if not currentMenu then
		return
	end

	local currentIndex = getCurrentIndex()
	if not currentIndex then
		return
	end

	width = width or toolTipWidth

	local x = nil
	if not flipHorizontal then
		x = getStyleProperty('x') + getStyleProperty('width') + width / 2 + buttonTextXOffset
	else
		x = getStyleProperty('x') - width / 2 - buttonTextXOffset
	end

	local textX = x - (width / 2) + buttonTextXOffset
	setTextParams(buttonFont, getStyleProperty('textColor'), buttonScale, false, true, false, textX, textX + width - (buttonTextYOffset * 2))
	local linesCount = getLinesCount(text, textX, getStyleProperty('y'))
	local height = GetTextScaleHeight(buttonScale, buttonFont) * (linesCount + 1) + buttonTextYOffset + (heightOffset and tonumber(heightOffset) and heightOffset or 0.0)
	local y = getStyleProperty('y') + titleHeight + (buttonHeight * currentIndex) + height / 2

	drawRect(x, y, width, height, getStyleProperty('backgroundColor'))

	y = y - (height / 2) + buttonTextYOffset
	drawText(text, textX, y)
end

function WarMenu.Button(text, subText)
	if not currentMenu then
		return
	end

	optionCount = optionCount + 1

	drawButton(text, subText)

	local pressed = false

	if currentMenu.currentOption == optionCount then
		if currentKey == keys.select then
			pressed = 'select'
			PlaySoundFrontend(-1, getStyleProperty('buttonPressedSound').name, getStyleProperty('buttonPressedSound').set, true)
		elseif currentKey == keys.left then
			pressed = 'left'
			PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		elseif currentKey == keys.right then
			pressed = 'right'
			PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
		end
	end

	return pressed
end

function WarMenu.SpriteButton(text, dict, name, r, g, b, a)
	if not currentMenu then
		return
	end

	local pressed = WarMenu.Button(text)

	local currentIndex = getCurrentIndex()
	if not currentIndex then
		return
	end

	if not HasStreamedTextureDictLoaded(dict) then
		RequestStreamedTextureDict(dict)
	end
	DrawSprite(dict, name, getStyleProperty('x') + getStyleProperty('width') - spriteWidth / 2 - buttonSpriteXOffset, getStyleProperty('y') + titleHeight + buttonHeight + (buttonHeight * currentIndex) - spriteHeight / 2 + buttonSpriteYOffset, spriteWidth, spriteHeight, 0., r or 255, g or 255, b or 255, a or 255)

	return pressed
end

function WarMenu.InputButton(text, windowTitleEntry, defaultText, maxLength, minLength, subText)
	if not currentMenu then
		return
	end

	local pressed = WarMenu.Button(text, subText)
	local inputText = nil

	if pressed == 'select' or pressed == 'right' then
		DisplayOnscreenKeyboard(1, windowTitleEntry or 'FMMC_MPM_NA', '', defaultText or '', '', '', '', maxLength or 255)

		while true do
			DisableAllControlActions(0)

			local status = UpdateOnscreenKeyboard()
			if status == 2 then
				break
			elseif status == 1 then
				local result = GetOnscreenKeyboardResult()
				if result:len() >= (minLength and minLength or 0) then
					inputText = result
					break
				else
					showNotification('You have to atleast enter '..minLength..' characters')
					DisplayOnscreenKeyboard(1, windowTitleEntry or 'FMMC_MPM_NA', '', result, '', '', '', maxLength or 255)
				end
			end

			Citizen.Wait(0)
		end
	end

	return pressed, inputText
end

function WarMenu.MenuButton(text, id, subText)
	if not currentMenu then
		return
	end

	local pressed = WarMenu.Button(text, subText)

	if pressed == 'select' or pressed == 'right' then
		currentMenu.currentOption = optionCount
		setMenuVisible(currentMenu.id, false)
		setMenuVisible(id, true, true)
	elseif pressed == 'left' then
		WarMenu.CloseMenu()
	end

	return pressed
end

function WarMenu.CheckBox(text, checked, callback)
	if not currentMenu then
		return
	end

	local name = nil
	if currentMenu.currentOption == optionCount + 1 then
		name = checked and 'shop_box_tickb' or 'shop_box_blankb'
	else
		name = checked and 'shop_box_tick' or 'shop_box_blank'
	end

	local pressed = WarMenu.SpriteButton(text, 'commonmenu', name)

	if pressed then
		checked = not checked
		if callback then callback(checked) end
	end

	return pressed
end

function WarMenu.ComboBox(text, items, currentIndex, selectedIndex, callback)
	if not currentMenu then
		return
	end

	local itemsCount = #items
	local selectedItem = items[currentIndex]
	local isCurrent = currentMenu.currentOption == optionCount + 1
	selectedIndex = selectedIndex or currentIndex

	if itemsCount > 1 and isCurrent then
		selectedItem = '← '..tostring(selectedItem)..' →'
	end

	local pressed = WarMenu.Button(text, selectedItem)

	if pressed then
		selectedIndex = currentIndex
	elseif isCurrent then
		if currentKey == keys.left then
			if currentIndex > 1 then currentIndex = currentIndex - 1 else currentIndex = itemsCount end
		elseif currentKey == keys.right then
			if currentIndex < itemsCount then currentIndex = currentIndex + 1 else currentIndex = 1 end
		end
	end

	if callback then callback(currentIndex, selectedIndex) end
	return pressed, currentIndex
end

function WarMenu.Display()
	if currentMenu then
		DisableControlAction(0, keys.left, true)
		DisableControlAction(0, keys.up, true)
		DisableControlAction(0, keys.down, true)
		DisableControlAction(0, keys.right, true)
		DisableControlAction(0, keys.back, true)

		if currentMenu.aboutToBeClosed then
			WarMenu.CloseMenu()
		else
			ClearAllHelpMessages()

			drawTitle()
			drawSubTitle()

			currentKey = nil
			local currentTime = GetGameTimer()

			if scrolled > 35 then
				scrollInterval = 50
			elseif scrolled > 10 then
				scrollInterval = 100
			end

			if IsDisabledControlPressed(0, keys.down) then
				if (currentTime - lastScrollTimes[keys.down]) > scrollInterval then
					PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

					if currentMenu.currentOption < optionCount then
						currentMenu.currentOption = currentMenu.currentOption + 1
					else
						currentMenu.currentOption = 1
					end

					lastScrollTimes[keys.down] = currentTime
					scrolled = scrolled + 1
				end
			elseif IsDisabledControlPressed(0, keys.up) then
				if (currentTime - lastScrollTimes[keys.up]) > scrollInterval then

					PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

					if currentMenu.currentOption > 1 then
						currentMenu.currentOption = currentMenu.currentOption - 1
					else
						currentMenu.currentOption = optionCount
					end

					lastScrollTimes[keys.up] = currentTime
					scrolled = scrolled + 1
				end
			elseif IsDisabledControlPressed(0, keys.left) then
				if (currentTime - lastScrollTimes[keys.left]) > scrollInterval then
					currentKey = keys.left
					lastScrollTimes[keys.left] = currentTime
					scrolled = scrolled + 1
				end
			elseif IsDisabledControlPressed(0, keys.right) then
				if (currentTime - lastScrollTimes[keys.right]) > scrollInterval then
					currentKey = keys.right
					lastScrollTimes[keys.right] = currentTime
					scrolled = scrolled + 1
				end
			elseif IsControlJustPressed(0, keys.select) then
				currentKey = keys.select
			elseif IsDisabledControlJustPressed(0, keys.back) then
				if menus[currentMenu.previousMenu] then
					setMenuVisible(currentMenu.previousMenu, true)
					PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
				else
					WarMenu.CloseMenu()
				end
			end

			if IsDisabledControlJustReleased(0, keys.down) then
				lastScrollTimes[keys.down] = 0
				scrolled = 0
				scrollInterval = scrollIntervalDefault
			elseif IsDisabledControlJustReleased(0, keys.up) then
				lastScrollTimes[keys.up] = 0
				scrolled = 0
				scrollInterval = scrollIntervalDefault
			elseif IsDisabledControlJustReleased(0, keys.left) then
				lastScrollTimes[keys.left] = 0
				scrolled = 0
				scrollInterval = scrollIntervalDefault
			elseif IsDisabledControlJustReleased(0, keys.right) then
				lastScrollTimes[keys.right] = 0
				scrolled = 0
				scrollInterval = scrollIntervalDefault
			end



			optionCount = 0
		end
	end
end
WarMenu.End = WarMenu.Display

function WarMenu.CurrentOption()
	if currentMenu and optionCount ~= 0 then
		return currentMenu.currentOption
	end

	return nil
end

function WarMenu.resetSelectedOption()
	if not currentMenu then
		return
	end

	currentMenu.currentOption = 1
end

function WarMenu.IsItemHovered()
	if not currentMenu or optionCount == 0 then
		return false
	end

	return currentMenu.currentOption == optionCount
end

function WarMenu.IsItemSelected()
	return currentKey == keys.select and WarMenu.IsItemHovered()
end

function WarMenu.SetTitle(id, title)
	setMenuProperty(id, 'title', title)
end
WarMenu.SetMenuTitle = WarMenu.SetTitle

function WarMenu.SetSubTitle(id, text)
	setMenuProperty(id, 'subTitle', string.upper(text))
end
WarMenu.SetMenuSubTitle = WarMenu.SetSubTitle

function WarMenu.SetMenuStyle(id, style)
	setMenuProperty(id, 'style', style)
end

function WarMenu.SetMenuX(id, x)
	setStyleProperty(id, 'x', x)
end

function WarMenu.SetMenuY(id, y)
	setStyleProperty(id, 'y', y)
end

function WarMenu.SetMenuWidth(id, width)
	setStyleProperty(id, 'width', width)
end

function WarMenu.SetMenuMaxOptionCountOnScreen(id, count)
	setStyleProperty(id, 'maxOptionCountOnScreen', count)
end

function WarMenu.SetTitleColor(id, r, g, b, a)
	setStyleProperty(id, 'titleColor', { r, g, b, a })
end
WarMenu.SetMenuTitleColor = WarMenu.SetTitleColor

function WarMenu.SetMenuSubTitleColor(id, r, g, b, a)
	setStyleProperty(id, 'subTitleColor', { r, g, b, a })
end

function WarMenu.SetTitleBackgroundColor(id, r, g, b, a)
	setStyleProperty(id, 'titleBackgroundColor', { r, g, b, a })
end
WarMenu.SetMenuTitleBackgroundColor = WarMenu.SetTitleBackgroundColor

function WarMenu.SetTitleBackgroundSprite(id, dict, name)
	RequestStreamedTextureDict(dict)
	setStyleProperty(id, 'titleBackgroundSprite', { dict = dict, name = name })
end
WarMenu.SetMenuTitleBackgroundSprite = WarMenu.SetTitleBackgroundSprite

function WarMenu.SetMenuBackgroundColor(id, r, g, b, a)
	setStyleProperty(id, 'backgroundColor', { r, g, b, a })
end

function WarMenu.SetMenuTextColor(id, r, g, b, a)
	setStyleProperty(id, 'textColor', { r, g, b, a })
end

function WarMenu.SetMenuSubTextColor(id, r, g, b, a)
	setStyleProperty(id, 'subTextColor', { r, g, b, a })
end

function WarMenu.SetMenuFocusColor(id, r, g, b, a)
	setStyleProperty(id, 'focusColor', { r, g, b, a })
end

function WarMenu.SetMenuFocusTextColor(id, r, g, b, a)
	setStyleProperty(id, 'focusTextColor', { r, g, b, a })
end

function WarMenu.SetMenuButtonPressedSound(id, name, set)
	setStyleProperty(id, 'buttonPressedSound', { name = name, set = set })
end
