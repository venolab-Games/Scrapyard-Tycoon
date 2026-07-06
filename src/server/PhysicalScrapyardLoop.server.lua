local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)

local DEBUG_PREFIX = "[PhysicalScrapyardLoop]"
local PART_CLICK_REWARD = 1
local CLICK_DEBOUNCE_SECONDS = 0.08

local BUTTON_COLORS = {
	CannotAfford = Color3.fromRGB(220, 64, 64),
	CanAfford = Color3.fromRGB(67, 201, 112),
	Purchased = Color3.fromRGB(80, 80, 80),
}

local buildSteps = {
	{
		buttonName = "BuildButton_UnlockScrapyard",
		buttonFolder = "BuildButtons",
		cost = 10,
		revealObjects = { "ScrapyardGround", "Fence" },
		revealButtons = { "BuildButton_BrokenCar_01" },
	},
	{
		buttonName = "BuildButton_BrokenCar_01",
		buttonFolder = "HiddenButtons",
		cost = 15,
		revealObjects = { "BrokenCar_01" },
		revealButtons = { "BuildButton_BrokenCar_02" },
	},
	{
		buttonName = "BuildButton_BrokenCar_02",
		buttonFolder = "HiddenButtons",
		cost = 23,
		revealObjects = { "BrokenCar_02" },
		revealButtons = { "BuildButton_BrokenCar_03" },
	},
	{
		buttonName = "BuildButton_BrokenCar_03",
		buttonFolder = "HiddenButtons",
		cost = 34,
		revealObjects = { "BrokenCar_03" },
		revealButtons = {},
	},
}

local buttonsByName = {}
local purchasedButtons = {}
local unlockedButtons = {}
local touchDebounces = {}
local activePartsValue = nil
local lastClickByPlayer = {}
local taggedButtonsByName = {}

local scrapyard = Workspace:FindFirstChild("Scrapyard")
local buildButtons = scrapyard and scrapyard:FindFirstChild("BuildButtons")
local hiddenButtons = scrapyard and scrapyard:FindFirstChild("HiddenButtons")
local unlockObjects = scrapyard and scrapyard:FindFirstChild("UnlockObjects")
local brokenCars = unlockObjects and unlockObjects:FindFirstChild("BrokenCars")

local function debugLog(message)
	print(string.format("%s %s", DEBUG_PREFIX, message))
end

local function warnMissing(expectedPath)
	warn(string.format("%s Missing expected object: %s", DEBUG_PREFIX, expectedPath))
end

local function logFound(label, object, expectedPath)
	if object then
		debugLog(string.format("found %s: %s", label, object:GetFullName()))
	else
		warnMissing(expectedPath)
	end
end

debugLog("script initialized")
logFound("Scrapyard", scrapyard, "Workspace > Scrapyard")
logFound("BuildButtons", buildButtons, "Workspace > Scrapyard > BuildButtons")
logFound("HiddenButtons", hiddenButtons, "Workspace > Scrapyard > HiddenButtons")
logFound("UnlockObjects", unlockObjects, "Workspace > Scrapyard > UnlockObjects")
logFound("ScrapyardGround", unlockObjects and unlockObjects:FindFirstChild("ScrapyardGround"), "Workspace > Scrapyard > UnlockObjects > ScrapyardGround")
logFound("Fence", unlockObjects and unlockObjects:FindFirstChild("Fence"), "Workspace > Scrapyard > UnlockObjects > Fence")
logFound("Fence > Beams", unlockObjects and unlockObjects:FindFirstChild("Fence") and unlockObjects.Fence:FindFirstChild("Beams"), "Workspace > Scrapyard > UnlockObjects > Fence > Beams")
logFound("Fence > Posts", unlockObjects and unlockObjects:FindFirstChild("Fence") and unlockObjects.Fence:FindFirstChild("Posts"), "Workspace > Scrapyard > UnlockObjects > Fence > Posts")

local function isExpectedButtonContainer(instance)
	return instance == buildButtons or instance == hiddenButtons
end

local function getExpectedButton(buttonName)
	return (buildButtons and buildButtons:FindFirstChild(buttonName)) or (hiddenButtons and hiddenButtons:FindFirstChild(buttonName))
end

local function scanTaggedButtons()
	local taggedButtons = CollectionService:GetTagged("Button")
	debugLog(string.format("found %d tagged Button instances", #taggedButtons))

	for _, button in taggedButtons do
		if taggedButtonsByName[button.Name] then
			warn(string.format("%s Duplicate Button tag name '%s': %s and %s", DEBUG_PREFIX, button.Name, taggedButtonsByName[button.Name]:GetFullName(), button:GetFullName()))
		else
			taggedButtonsByName[button.Name] = button
		end

		if not isExpectedButtonContainer(button.Parent) then
			warn(string.format("%s Tagged Button outside expected folders: %s", DEBUG_PREFIX, button:GetFullName()))
		end

		if button:GetAttribute("BuildCost") == nil then
			warn(string.format("%s Tagged Button missing BuildCost attribute before script setup: %s", DEBUG_PREFIX, button:GetFullName()))
		end
	end

	for _, step in buildSteps do
		local expectedButton = getExpectedButton(step.buttonName)
		if not expectedButton then
			warnMissing(string.format("Workspace > Scrapyard > %s or HiddenButtons > %s", step.buttonFolder, step.buttonName))
		elseif not CollectionService:HasTag(expectedButton, "Button") then
			warn(string.format("%s Expected build button is missing exact Button tag: %s", DEBUG_PREFIX, expectedButton:GetFullName()))
		end
	end
end

local function getParts(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	return leaderstats:FindFirstChild(CurrencyConfig.PartsName)
end

local function findDescendantByName(root, name)
	if not root then
		return nil
	end

	if root.Name == name then
		return root
	end

	return root:FindFirstChild(name, true)
end

local function findAncestorByName(instance, name)
	local current = instance
	while current and current ~= Workspace do
		if current.Name == name then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function getBuildButton(buttonName, buttonFolder)
	local button = taggedButtonsByName[buttonName]
	if button then
		return button
	end

	warn(string.format("%s Cannot set up %s because it is not tagged with exact CollectionService tag Button", DEBUG_PREFIX, buttonName))
	return nil
end

local function getRevealObject(objectName)
	if objectName == "ScrapyardGround" or objectName == "Fence" then
		return unlockObjects and unlockObjects:FindFirstChild(objectName)
	end

	if objectName:match("^BrokenCar_") then
		return brokenCars and brokenCars:FindFirstChild(objectName)
	end

	return unlockObjects and unlockObjects:FindFirstChild(objectName)
end

local function eachSelfAndDescendant(instance, callback)
	callback(instance)

	for _, descendant in instance:GetDescendants() do
		callback(descendant)
	end
end

local function rememberOriginalState(instance)
	if instance:IsA("BasePart") then
		if instance:GetAttribute("OriginalTransparency") == nil then
			instance:SetAttribute("OriginalTransparency", instance.Transparency)
			instance:SetAttribute("OriginalCanCollide", instance.CanCollide)
			instance:SetAttribute("OriginalCanTouch", instance.CanTouch)
			instance:SetAttribute("OriginalCanQuery", instance.CanQuery)
		end
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		if instance:GetAttribute("OriginalTransparency") == nil then
			instance:SetAttribute("OriginalTransparency", instance.Transparency)
		end
	elseif instance:IsA("SurfaceGui") or instance:IsA("BillboardGui") then
		if instance:GetAttribute("OriginalEnabled") == nil then
			instance:SetAttribute("OriginalEnabled", instance.Enabled)
		end
	end
end

local function setObjectHidden(object, hidden, options)
	if not object then
		return 0
	end

	options = options or {}
	local processed = 0

	eachSelfAndDescendant(object, function(instance)
		processed += 1
		rememberOriginalState(instance)

		if instance:IsA("BasePart") then
			if hidden then
				instance.Transparency = 1
				instance.LocalTransparencyModifier = 1
				instance.CanCollide = false
				instance.CanTouch = false
				instance.CanQuery = false
			else
				instance.Transparency = 0
				instance.LocalTransparencyModifier = 0
				instance.CanCollide = true
				instance.CanTouch = true
				instance.CanQuery = true
			end
		elseif instance:IsA("Decal") or instance:IsA("Texture") then
			instance.Transparency = hidden and 1 or 0
		elseif instance:IsA("SurfaceGui") or instance:IsA("BillboardGui") then
			instance.Enabled = hidden and false or true
		elseif instance:IsA("ProximityPrompt") then
			instance.Enabled = false
		elseif instance:IsA("ClickDetector") then
			instance.MaxActivationDistance = hidden and 0 or 32
		end
	end)

	return processed
end

local function getTouchPart(button)
	local namedTouchPart = findDescendantByName(button, "ButtonPart")
	if namedTouchPart and namedTouchPart:IsA("BasePart") then
		return namedTouchPart
	end

	if button:IsA("BasePart") then
		return button
	end

	return button:FindFirstChildWhichIsA("BasePart", true)
end

local function setButtonColor(button, color)
	if not button then
		return
	end

	eachSelfAndDescendant(button, function(instance)
		if instance:IsA("BasePart") then
			instance.Color = color
			instance.Material = Enum.Material.Neon
		end
	end)
end

local function disableButtonPrompts(button)
	if not button then
		return
	end

	for _, descendant in button:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant.Enabled = false
		end
	end
end

local function configureTouchPart(button, touchPart)
	touchPart.Anchored = true
	touchPart.CanCollide = true
	touchPart.CanTouch = true
	touchPart.CanQuery = true
	debugLog(string.format("touch part for %s: %s", button.Name, touchPart:GetFullName()))
end

local function logVisibilitySample(objectName, object)
	task.delay(0.2, function()
		if not object or not object.Parent then
			warn(string.format("%s Cannot verify %s after reveal; object no longer exists", DEBUG_PREFIX, objectName))
			return
		end

		local sampled = 0
		local hiddenCount = 0

		for _, instance in object:GetDescendants() do
			if instance:IsA("BasePart") then
				sampled += 1
				if instance.Transparency >= 1 or instance.LocalTransparencyModifier >= 1 then
					hiddenCount += 1
				end

				if sampled <= 8 then
					debugLog(string.format(
						"verify %s sample %d: %s | %s | Transparency=%s | LocalTransparencyModifier=%s | CanCollide=%s | CanTouch=%s | CanQuery=%s",
						objectName,
						sampled,
						instance:GetFullName(),
						instance.ClassName,
						tostring(instance.Transparency),
						tostring(instance.LocalTransparencyModifier),
						tostring(instance.CanCollide),
						tostring(instance.CanTouch),
						tostring(instance.CanQuery)
					))
				end
			end
		end

		debugLog(string.format("verify %s total BaseParts=%d hidden-looking BaseParts=%d", objectName, sampled, hiddenCount))

		if sampled > 0 and hiddenCount == 0 then
			debugLog(string.format("verify %s passed normal visibility checks; if still invisible, inspect duplicate object copies, another script re-hiding, mesh/material setup, or geometry outside the expected hierarchy", objectName))
		end
	end)
end

local function updateButtonAffordability()
	local partsValue = activePartsValue and activePartsValue.Value or 0

	for _, step in buildSteps do
		local button = buttonsByName[step.buttonName]
		if button and not purchasedButtons[step.buttonName] then
			if partsValue >= step.cost then
				setButtonColor(button, BUTTON_COLORS.CanAfford)
			else
				setButtonColor(button, BUTTON_COLORS.CannotAfford)
			end
		end
	end
end

local function revealObject(objectName)
	debugLog(string.format("reveal called for %s", objectName))

	local object = getRevealObject(objectName)
	if not object then
		if objectName == "ScrapyardGround" or objectName == "Fence" then
			warnMissing(string.format("Workspace > Scrapyard > UnlockObjects > %s", objectName))
		elseif objectName:match("^BrokenCar_") then
			warnMissing(string.format("Workspace > Scrapyard > UnlockObjects > BrokenCars > %s", objectName))
		else
			warnMissing(string.format("Workspace > Scrapyard > UnlockObjects > %s", objectName))
		end
		return
	end

	local processed = setObjectHidden(object, false)
	debugLog(string.format("reveal processed %d descendants for %s", processed, objectName))

	if objectName:match("^BrokenCar_") then
		object:SetAttribute("CollectorActive", true)
		debugLog(string.format("%s marked CollectorActive for Parts collector income", objectName))
	end

	if objectName == "ScrapyardGround" or objectName == "Fence" then
		logVisibilitySample(objectName, object)
	end
end

local function revealButton(buttonName)
	local button = buttonsByName[buttonName]
	if not button then
		warnMissing(string.format("Workspace > Scrapyard > HiddenButtons > %s", buttonName))
		return
	end

	local processed = setObjectHidden(button, false)
	disableButtonPrompts(button)
	unlockedButtons[buttonName] = true
	debugLog(string.format("revealed button %s; processed %d descendants", buttonName, processed))
end

local function hidePurchasedButton(button, buttonName)
	purchasedButtons[buttonName] = true
	unlockedButtons[buttonName] = false
	button:SetAttribute("Purchased", true)
	disableButtonPrompts(button)
	setButtonColor(button, BUTTON_COLORS.Purchased)
	setObjectHidden(button, true)
end

local function purchaseBuildStep(player, step)
	debugLog(string.format("purchase attempt for %s by %s", step.buttonName, player.Name))

	local parts = getParts(player)
	local button = buttonsByName[step.buttonName]
	if not parts or not button or purchasedButtons[step.buttonName] or not unlockedButtons[step.buttonName] then
		return
	end

	local cost = button:GetAttribute("BuildCost") or step.cost
	if parts.Value < cost then
		debugLog(string.format("touch unaffordable: %s touched %s with %d Parts; needs %d", player.Name, step.buttonName, parts.Value, cost))
		updateButtonAffordability()
		return
	end

	debugLog(string.format("purchase success: %s bought %s for %d Parts", player.Name, step.buttonName, cost))
	parts.Value -= cost
	hidePurchasedButton(button, step.buttonName)

	for _, objectName in step.revealObjects do
		revealObject(objectName)
	end

	for _, buttonName in step.revealButtons do
		revealButton(buttonName)
	end

	updateButtonAffordability()
end

local function getPlayerFromTouchedPart(touchedPart)
	local character = touchedPart and touchedPart:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function connectButtonTouch(button, touchPart, step)
	touchPart.Touched:Connect(function(touchedPart)
		local player = getPlayerFromTouchedPart(touchedPart)
		if not player then
			return
		end

		if purchasedButtons[step.buttonName] or not unlockedButtons[step.buttonName] then
			return
		end

		local now = os.clock()
		local lastTouch = touchDebounces[step.buttonName] or 0
		if now - lastTouch < 0.5 then
			return
		end
		touchDebounces[step.buttonName] = now

		debugLog(string.format("touch detected: %s touched %s", player.Name, step.buttonName))
		purchaseBuildStep(player, step)
	end)
end

local function setupBuildButton(step)
	local button = getBuildButton(step.buttonName, step.buttonFolder)
	if not button then
		return
	end

	buttonsByName[step.buttonName] = button
	if button:GetAttribute("BuildCost") == nil then
		button:SetAttribute("BuildCost", step.cost)
	end
	debugLog(string.format("found build button %s: %s", step.buttonName, button:GetFullName()))
	debugLog(string.format("BuildCost for %s: %s", step.buttonName, tostring(button:GetAttribute("BuildCost"))))

	disableButtonPrompts(button)

	local touchPart = getTouchPart(button)
	if not touchPart then
		warn(string.format("%s Tagged Button has no BasePart touch part: %s", DEBUG_PREFIX, button:GetFullName()))
		return
	end

	configureTouchPart(button, touchPart)
	connectButtonTouch(button, touchPart, step)
end

local function findCarPile()
	local taggedObjects = CollectionService:GetTagged("PartClickSource")
	if taggedObjects[1] then
		return findAncestorByName(taggedObjects[1], "CarPile_Clickable") or taggedObjects[1]
	end

	local starterArea = Workspace:FindFirstChild("StarterArea")
	local clickables = starterArea and starterArea:FindFirstChild("Clickables")
	return clickables and clickables:FindFirstChild("CarPile_Clickable")
end

local function getClickablePart(carPile)
	if not carPile then
		return nil
	end

	local clickHitbox = findDescendantByName(carPile, "ClickHitbox")
	if clickHitbox and clickHitbox:IsA("BasePart") then
		return clickHitbox
	end

	if carPile:IsA("BasePart") then
		return carPile
	end

	return carPile:FindFirstChildWhichIsA("BasePart", true)
end

local function getBounceRoot(carPile)
	return findDescendantByName(carPile, "Visuals") or carPile
end

local function getPrimaryPart(object)
	if object:IsA("BasePart") then
		return object
	end

	if object:IsA("Model") then
		return object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

local function bounceCarPile(carPile)
	local bounceRoot = getBounceRoot(carPile)
	local primaryPart = getPrimaryPart(bounceRoot)
	if not primaryPart or primaryPart:GetAttribute("IsBouncing") then
		return
	end

	primaryPart:SetAttribute("IsBouncing", true)
	local originalCFrame = bounceRoot:IsA("Model") and bounceRoot:GetPivot() or primaryPart.CFrame
	local bounceValue = Instance.new("CFrameValue")
	bounceValue.Value = originalCFrame

	local connection = bounceValue:GetPropertyChangedSignal("Value"):Connect(function()
		if bounceRoot:IsA("Model") then
			bounceRoot:PivotTo(bounceValue.Value)
		else
			primaryPart.CFrame = bounceValue.Value
		end
	end)

	local upTween = TweenService:Create(bounceValue, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Value = originalCFrame + Vector3.new(0, 0.45, 0),
	})
	local downTween = TweenService:Create(bounceValue, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Value = originalCFrame,
	})

	upTween:Play()
	upTween.Completed:Once(function()
		downTween:Play()
	end)
	downTween.Completed:Once(function()
		if bounceRoot:IsA("Model") then
			bounceRoot:PivotTo(originalCFrame)
		else
			primaryPart.CFrame = originalCFrame
		end

		connection:Disconnect()
		bounceValue:Destroy()
		primaryPart:SetAttribute("IsBouncing", false)
	end)
end

local function showPartRewardText(carPile)
	local primaryPart = getPrimaryPart(getBounceRoot(carPile))
	if not primaryPart then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PartRewardText"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	billboard.Adornee = primaryPart
	billboard.Parent = primaryPart

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "+1 Part"
	label.TextColor3 = Color3.fromRGB(255, 239, 156)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.25
	label.Parent = billboard

	local moveTween = TweenService:Create(billboard, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0),
	})
	local fadeTween = TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	moveTween:Play()
	fadeTween:Play()
	fadeTween.Completed:Once(function()
		billboard:Destroy()
	end)
end

local function setupCarPileClick()
	local carPile = findCarPile()
	local clickPart = getClickablePart(carPile)
	if not carPile or not clickPart then
		warnMissing("Workspace > StarterArea > Clickables > CarPile_Clickable > ClickHitbox")
		return
	end

	debugLog(string.format("found CarPile_Clickable: %s", carPile:GetFullName()))
	debugLog(string.format("found car pile click part: %s", clickPart:GetFullName()))

	local clickDetector = clickPart:FindFirstChildWhichIsA("ClickDetector")
	if not clickDetector then
		clickDetector = Instance.new("ClickDetector")
		clickDetector.Name = "PartsClickDetector"
		clickDetector.Parent = clickPart
	end
	clickDetector.MaxActivationDistance = 32

	clickDetector.MouseClick:Connect(function(player)
		local now = os.clock()
		local lastClick = lastClickByPlayer[player] or 0
		if now - lastClick < CLICK_DEBOUNCE_SECONDS then
			return
		end
		lastClickByPlayer[player] = now

		local parts = getParts(player)
		if not parts then
			return
		end

		parts.Value += PART_CLICK_REWARD
		bounceCarPile(carPile)
		showPartRewardText(carPile)
		updateButtonAffordability()
	end)
end

local function hideInitialObject(objectName)
	local object = getRevealObject(objectName)
	if not object then
		if objectName == "ScrapyardGround" or objectName == "Fence" then
			warnMissing(string.format("Workspace > Scrapyard > UnlockObjects > %s", objectName))
		else
			warnMissing(string.format("Workspace > Scrapyard > UnlockObjects > BrokenCars > %s", objectName))
		end
		return
	end

	local processed = setObjectHidden(object, true)
	if objectName:match("^BrokenCar_") then
		object:SetAttribute("CollectorActive", false)
	end
	debugLog(string.format("initial hide processed %d descendants for %s", processed, objectName))
end

local function hideInitialButton(buttonName)
	local button = buttonsByName[buttonName]
	if not button then
		warnMissing(string.format("Workspace > Scrapyard > HiddenButtons > %s", buttonName))
		return
	end

	local processed = setObjectHidden(button, true)
	disableButtonPrompts(button)
	unlockedButtons[buttonName] = false
	debugLog(string.format("initial hide processed %d descendants for %s", processed, buttonName))
end

local function setupBuildButtons()
	for _, step in buildSteps do
		setupBuildButton(step)
	end

	for _, step in buildSteps do
		if step.buttonFolder == "HiddenButtons" then
			hideInitialButton(step.buttonName)
		end
	end

	local firstButton = buttonsByName.BuildButton_UnlockScrapyard
	if firstButton then
		setObjectHidden(firstButton, false)
		disableButtonPrompts(firstButton)
		unlockedButtons.BuildButton_UnlockScrapyard = true
	end
end

local function hideInitialScrapyardObjects()
	hideInitialObject("ScrapyardGround")
	hideInitialObject("Fence")
	hideInitialObject("BrokenCar_01")
	hideInitialObject("BrokenCar_02")
	hideInitialObject("BrokenCar_03")
end

local function watchPlayerParts(player)
	local leaderstats = player:WaitForChild("leaderstats", 10)
	local parts = leaderstats and leaderstats:WaitForChild(CurrencyConfig.PartsName, 10)
	if not parts then
		return
	end

	activePartsValue = parts
	updateButtonAffordability()
	parts:GetPropertyChangedSignal("Value"):Connect(updateButtonAffordability)
end

scanTaggedButtons()
hideInitialScrapyardObjects()
setupBuildButtons()
setupCarPileClick()

Players.PlayerAdded:Connect(function(player)
	task.defer(watchPlayerParts, player)
end)

Players.PlayerRemoving:Connect(function(player)
	lastClickByPlayer[player] = nil
	if activePartsValue and activePartsValue:IsDescendantOf(player) then
		activePartsValue = nil
	end
end)

for _, player in Players:GetPlayers() do
	task.defer(watchPlayerParts, player)
end
