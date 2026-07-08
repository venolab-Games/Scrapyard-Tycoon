local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)

local DEBUG_PREFIX = "[PartsCollector]"
local ENABLE_DEBUG_LOGS = false
local BROKEN_CAR_GENERATE_INTERVAL_SECONDS = 1
local BROKEN_CAR_BASE_PARTS_PER_TICK = 1
local MAX_STORED_PARTS = 999999
local COLLECT_DEBOUNCE_SECONDS = 0.75
local COLLECT_FLASH_SECONDS = 0.18
local COLLECT_POPUP_SECONDS = 0.8
local BROKEN_CAR_PRODUCTION = {
	{ name = "BrokenCar_01", partsPerTick = 1 },
	{ name = "BrokenCar_02", partsPerTick = 1 },
	{ name = "BrokenCar_03", partsPerTick = 1 },
	{ name = "BrokenCar_04", partsPerTick = 2 },
	{ name = "BrokenCar_05", partsPerTick = 2 },
	{ name = "BrokenCar_06", partsPerTick = 2 },
	{ name = "BrokenCar_07", partsPerTick = 2 },
	{ name = "BrokenCar_08", partsPerTick = 3 },
	{ name = "BrokenCar_09", partsPerTick = 3 },
	{ name = "BrokenCar_10", partsPerTick = 3 },
	{ name = "BrokenCar_11", partsPerTick = 3 },
}
local BROKEN_CAR_PARTS_PER_TICK = {}

for _, config in BROKEN_CAR_PRODUCTION do
	BROKEN_CAR_PARTS_PER_TICK[config.name] = config.partsPerTick
end

local collectDebounces = {}
local counterValueLabels = {}
local activeBrokenCarLoops = {}
local brokenCarRemainders = {}
local incomeMultiplierConnection = nil

local function formatWholeNumber(value)
	return string.format("%d", math.floor(value))
end

local function log(message)
	if ENABLE_DEBUG_LOGS then
		print(string.format("%s %s", DEBUG_PREFIX, message))
	end
end

local function warnCollector(message)
	warn(string.format("%s %s", DEBUG_PREFIX, message))
end

local function getParts(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	return leaderstats:FindFirstChild(CurrencyConfig.PartsName)
end

local function getPlayerFromTouchedPart(touchedPart)
	local character = touchedPart and touchedPart:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function getTaggedCollectPad(collector)
	for _, taggedPad in CollectionService:GetTagged("CollectPad") do
		if taggedPad:IsA("BasePart") and taggedPad:IsDescendantOf(collector) then
			return taggedPad
		end
	end

	return nil
end

local function findCollectPad(collector)
	local taggedPad = getTaggedCollectPad(collector)
	if taggedPad then
		return taggedPad
	end

	local namedPad = collector:FindFirstChild("CollectPad", true)
	if namedPad and namedPad:IsA("BasePart") then
		warnCollector(string.format("%s CollectPad found by name but is missing exact CollectPad tag", collector:GetFullName()))
		return namedPad
	end

	return nil
end

local function getStoredParts(collector)
	local storedParts = collector:GetAttribute("StoredParts")
	if typeof(storedParts) ~= "number" then
		warnCollector(string.format("%s missing numeric StoredParts attribute; setting to 0", collector:GetFullName()))
		collector:SetAttribute("StoredParts", 0)
		return 0
	end

	return storedParts
end

local function getWholeStoredParts(collector)
	return math.floor(getStoredParts(collector))
end

local function setStoredParts(collector, value)
	local clampedValue = math.clamp(value, 0, MAX_STORED_PARTS)
	collector:SetAttribute("StoredParts", clampedValue)
	log(string.format("%s StoredParts changed to %s", collector.Name, formatWholeNumber(clampedValue)))
end

local function findPartsCounter(collector)
	return collector:FindFirstChild("PartsCounter", true)
end

local function getOrCreateSurfaceGui(partsCounter)
	local existingSurfaceGui = partsCounter:FindFirstChildWhichIsA("SurfaceGui", true)
	if existingSurfaceGui then
		return existingSurfaceGui
	end

	local counterPart = partsCounter:IsA("BasePart") and partsCounter or partsCounter:FindFirstChildWhichIsA("BasePart", true)
	if not counterPart then
		warnCollector(string.format("%s has no BasePart for fallback SurfaceGui", partsCounter:GetFullName()))
		return nil
	end

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "StoredPartsSurfaceGui"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 50
	surfaceGui.Parent = counterPart
	warnCollector(string.format("%s missing SurfaceGui; created fallback StoredPartsSurfaceGui", partsCounter:GetFullName()))

	return surfaceGui
end

local function findTextLabel(surfaceGui, primaryName, fallbackName)
	local primaryLabel = surfaceGui:FindFirstChild(primaryName, true)
	if primaryLabel and primaryLabel:IsA("TextLabel") then
		return primaryLabel
	end

	local fallbackLabel = surfaceGui:FindFirstChild(fallbackName, true)
	if fallbackLabel and fallbackLabel:IsA("TextLabel") then
		fallbackLabel.Name = primaryName
		return fallbackLabel
	end

	return nil
end

local function createFallbackTextLabel(surfaceGui, name, position, size)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Position = position
	label.Size = size
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.Parent = surfaceGui

	return label
end

local function setupCounterText(collector)
	local partsCounter = findPartsCounter(collector)
	if not partsCounter then
		warnCollector(string.format("%s has no PartsCounter; StoredParts counter text will not update", collector:GetFullName()))
		return
	end

	local surfaceGui = getOrCreateSurfaceGui(partsCounter)
	if not surfaceGui then
		return
	end

	local titleLabel = findTextLabel(surfaceGui, "TitleLabel", "StoredPartsText")
	if not titleLabel then
		titleLabel = createFallbackTextLabel(surfaceGui, "TitleLabel", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.45))
		warnCollector(string.format("%s missing TitleLabel; created fallback", surfaceGui:GetFullName()))
	end

	local valueLabel = findTextLabel(surfaceGui, "ValueLabel", "StoredPartsNumber")
	if not valueLabel then
		valueLabel = createFallbackTextLabel(surfaceGui, "ValueLabel", UDim2.fromScale(0, 0.45), UDim2.fromScale(1, 0.55))
		warnCollector(string.format("%s missing ValueLabel; created fallback", surfaceGui:GetFullName()))
	end

	titleLabel.Text = "Stored Parts"
	valueLabel.Text = formatWholeNumber(getWholeStoredParts(collector))
	counterValueLabels[collector] = valueLabel
	log(string.format("counter text connected for %s using %s", collector.Name, valueLabel:GetFullName()))
end

local function updateCounterValue(collector)
	local valueLabel = counterValueLabels[collector]
	if valueLabel and valueLabel.Parent then
		valueLabel.Text = formatWholeNumber(getWholeStoredParts(collector))
	end
end

local function showCollectPopup(collectPad, amount)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CollectPartsFeedback"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(160, 48)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, math.max(collectPad.Size.Y * 0.5 + 2, 2.5), 0)
	billboard.Adornee = collectPad
	billboard.Parent = collectPad

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = string.format("+%s Parts", formatWholeNumber(amount))
	label.TextColor3 = Color3.fromRGB(255, 239, 156)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.25
	label.Parent = billboard

	local targetOffset = billboard.StudsOffsetWorldSpace + Vector3.new(0, 1.5, 0)
	local moveTween = TweenService:Create(billboard, TweenInfo.new(COLLECT_POPUP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = targetOffset,
	})
	local fadeTween = TweenService:Create(label, TweenInfo.new(COLLECT_POPUP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	moveTween:Play()
	fadeTween:Play()
	fadeTween.Completed:Once(function()
		billboard:Destroy()
	end)
end

local function flashCollectPad(collectPad)
	if collectPad:GetAttribute("CollectFeedbackActive") then
		return
	end

	collectPad:SetAttribute("CollectFeedbackActive", true)
	local originalColor = collectPad.Color
	local originalMaterial = collectPad.Material
	collectPad.Material = Enum.Material.Neon

	local flashTween = TweenService:Create(collectPad, TweenInfo.new(COLLECT_FLASH_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Color = Color3.fromRGB(255, 239, 156),
	})
	local restoreTween = TweenService:Create(collectPad, TweenInfo.new(COLLECT_FLASH_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Color = originalColor,
	})

	flashTween:Play()
	flashTween.Completed:Once(function()
		if collectPad.Parent then
			restoreTween:Play()
		end
	end)
	restoreTween.Completed:Once(function()
		if collectPad.Parent then
			collectPad.Color = originalColor
			collectPad.Material = originalMaterial
			collectPad:SetAttribute("CollectFeedbackActive", false)
		end
	end)
end

local function showCollectFeedback(collectPad, amount)
	showCollectPopup(collectPad, amount)
	flashCollectPad(collectPad)
end

local function getBrokenCarsFolder()
	local scrapyard = Workspace:FindFirstChild("Scrapyard")
	local unlockObjects = scrapyard and scrapyard:FindFirstChild("UnlockObjects")
	return unlockObjects and unlockObjects:FindFirstChild("BrokenCars")
end

local function getScrapyardIncomeMultiplier()
	local scrapyard = Workspace:FindFirstChild("Scrapyard")
	local multiplier = scrapyard and scrapyard:GetAttribute(CurrencyConfig.PartsIncomeMultiplierAttribute)
	if typeof(multiplier) == "number" and multiplier > 0 then
		return multiplier
	end

	return 1
end

local function getBrokenCarBasePartsPerTick(brokenCar)
	local configuredPartsPerTick = BROKEN_CAR_PARTS_PER_TICK[brokenCar.Name]
	if typeof(configuredPartsPerTick) == "number" and configuredPartsPerTick > 0 then
		return configuredPartsPerTick
	end

	return BROKEN_CAR_BASE_PARTS_PER_TICK
end

local function getEffectivePartsIncomeRate()
	local rawRate = 0
	for brokenCar, active in activeBrokenCarLoops do
		if active then
			rawRate += getBrokenCarBasePartsPerTick(brokenCar)
		end
	end

	return math.floor(rawRate * getScrapyardIncomeMultiplier())
end

local function getBrokenCarPartsForTick(brokenCar)
	local rawParts = (brokenCarRemainders[brokenCar] or 0) + (getBrokenCarBasePartsPerTick(brokenCar) * getScrapyardIncomeMultiplier())
	local wholeParts = math.floor(rawParts)
	brokenCarRemainders[brokenCar] = rawParts - wholeParts

	return wholeParts
end

local function updatePlayerIncomeRates()
	local rate = getEffectivePartsIncomeRate()
	for _, player in Players:GetPlayers() do
		player:SetAttribute(CurrencyConfig.PartsIncomeRateAttribute, rate)
	end
end

local function watchIncomeMultiplier()
	if incomeMultiplierConnection then
		return
	end

	local scrapyard = Workspace:FindFirstChild("Scrapyard")
	if not scrapyard then
		warnCollector("Workspace.Scrapyard not found; Parts income multiplier updates are paused")
		return
	end

	if scrapyard:GetAttribute(CurrencyConfig.PartsIncomeMultiplierAttribute) == nil then
		scrapyard:SetAttribute(CurrencyConfig.PartsIncomeMultiplierAttribute, 1)
	end

	incomeMultiplierConnection = scrapyard:GetAttributeChangedSignal(CurrencyConfig.PartsIncomeMultiplierAttribute):Connect(updatePlayerIncomeRates)
	updatePlayerIncomeRates()
end

local function startBrokenCarIncomeLoop(collector, brokenCar)
	if activeBrokenCarLoops[brokenCar] then
		return
	end

	activeBrokenCarLoops[brokenCar] = true
	log(string.format("%s started +%s/sec StoredParts loop for %s", collector.Name, formatWholeNumber(getBrokenCarBasePartsPerTick(brokenCar)), brokenCar.Name))
	updatePlayerIncomeRates()

	task.spawn(function()
		while collector.Parent and brokenCar.Parent and activeBrokenCarLoops[brokenCar] do
			task.wait(BROKEN_CAR_GENERATE_INTERVAL_SECONDS)

			if not collector.Parent or not brokenCar.Parent or not activeBrokenCarLoops[brokenCar] then
				break
			end

			local partsToStore = getBrokenCarPartsForTick(brokenCar)
			if partsToStore > 0 then
				setStoredParts(collector, getStoredParts(collector) + partsToStore)
			end
		end

		if activeBrokenCarLoops[brokenCar] then
			activeBrokenCarLoops[brokenCar] = nil
			brokenCarRemainders[brokenCar] = nil
			updatePlayerIncomeRates()
		end
	end)
end

local function stopBrokenCarIncomeLoop(brokenCar)
	if activeBrokenCarLoops[brokenCar] then
		activeBrokenCarLoops[brokenCar] = nil
		brokenCarRemainders[brokenCar] = nil
		updatePlayerIncomeRates()
	end
end

local function watchBrokenCarIncome(collector, brokenCar)
	if not brokenCar then
		return
	end

	if brokenCar:GetAttribute("CollectorActive") == true then
		startBrokenCarIncomeLoop(collector, brokenCar)
	end

	brokenCar:GetAttributeChangedSignal("CollectorActive"):Connect(function()
		if brokenCar:GetAttribute("CollectorActive") == true then
			startBrokenCarIncomeLoop(collector, brokenCar)
		else
			stopBrokenCarIncomeLoop(brokenCar)
		end
	end)
end

local function watchBrokenCars(collector)
	local brokenCarsFolder = getBrokenCarsFolder()
	if not brokenCarsFolder then
		warnCollector("Workspace.Scrapyard.UnlockObjects.BrokenCars not found; StoredParts generation is paused")
		return
	end

	for _, config in BROKEN_CAR_PRODUCTION do
		local brokenCar = brokenCarsFolder:FindFirstChild(config.name)
		if brokenCar then
			watchBrokenCarIncome(collector, brokenCar)
		else
			warnCollector(string.format("Missing expected broken car for collector income: %s", config.name))
		end
	end
end

local function collectStoredParts(player, collector)
	local parts = getParts(player)
	if not parts then
		return 0
	end

	local storedParts = getWholeStoredParts(collector)
	if storedParts <= 0 then
		log(string.format("%s attempted collect from %s while empty", player.Name, collector.Name))
		return 0
	end

	parts.Value += storedParts
	setStoredParts(collector, getStoredParts(collector) - storedParts)
	log(string.format("%s collected %s Parts from %s", player.Name, formatWholeNumber(storedParts), collector.Name))
	return storedParts
end

local function connectCollectPad(collector, collectPad)
	collectPad.Anchored = true
	collectPad.CanCollide = true
	collectPad.CanTouch = true
	collectPad.CanQuery = true

	collectPad.Touched:Connect(function(touchedPart)
		local player = getPlayerFromTouchedPart(touchedPart)
		if not player then
			return
		end

		local debounceKey = string.format("%s:%d", collector:GetFullName(), player.UserId)
		local now = os.clock()
		if now - (collectDebounces[debounceKey] or 0) < COLLECT_DEBOUNCE_SECONDS then
			return
		end
		collectDebounces[debounceKey] = now

		local collectedAmount = collectStoredParts(player, collector)
		if collectedAmount > 0 then
			showCollectFeedback(collectPad, collectedAmount)
		end
	end)
end

local function setupCollector(collector)
	log(string.format("collector found: %s", collector:GetFullName()))

	local collectPad = findCollectPad(collector)
	if not collectPad then
		warnCollector(string.format("%s has no tagged or named CollectPad BasePart", collector:GetFullName()))
		return
	end

	log(string.format("collect pad found for %s: %s", collector.Name, collectPad:GetFullName()))
	getStoredParts(collector)
	setupCounterText(collector)
	updateCounterValue(collector)
	collector:GetAttributeChangedSignal("StoredParts"):Connect(function()
		updateCounterValue(collector)
	end)
	connectCollectPad(collector, collectPad)
	watchIncomeMultiplier()
	watchBrokenCars(collector)
end

for _, collector in CollectionService:GetTagged("Collector") do
	setupCollector(collector)
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute(CurrencyConfig.PartsIncomeRateAttribute, getEffectivePartsIncomeRate())
end)
