local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local REMOTES_FOLDER_NAME = "Remotes"
local INSUFFICIENT_PARTS_REMOTE_NAME = "ShowInsufficientPartsFeedback"
local COLLECT_PAD_TAG = "CollectPad"
local COLLECTOR_TAG = "Collector"
local PART_CLICK_SOURCE_TAG = "PartClickSource"
local COLLECT_TEXT = "Collect Parts"
local CLICK_TEXT = "Click"
local TOTAL_SECONDS = 7
local FADE_SECONDS = 1.25
local HOLD_SECONDS = TOTAL_SECONDS - (FADE_SECONDS * 2)
local ARROW_COLOR = Color3.fromRGB(88, 255, 130)
local ARROW_FLOAT_OFFSET = Vector3.new(0, 0.2, 0)
local ARROW_FLOW_STUDS_PER_SECOND = 2
local ARROW_SCREEN_ROTATION_OFFSET = 180
local MIN_ARROW_COUNT = 3
local MAX_ARROW_COUNT = 12
local STUDS_PER_ARROW = 7
local START_OFFSET = 4
local TARGET_CLEARANCE = 5
local END_FADE_DISTANCE = 8
local START_FADE_DISTANCE = 7

local warnedMissingCollectPad = false
local warnedMissingCarPile = false

local function findRemoteEvent(parent, remoteName)
	for _, child in parent:GetChildren() do
		if child.Name == remoteName and child:IsA("RemoteEvent") then
			return child
		end
	end

	return nil
end

local function waitForFeedbackRemote()
	while true do
		local remotesFolder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
		if remotesFolder and remotesFolder:IsA("Folder") then
			local remote = findRemoteEvent(remotesFolder, INSUFFICIENT_PARTS_REMOTE_NAME)
			if remote then
				return remote
			end
		end

		local remote = findRemoteEvent(ReplicatedStorage, INSUFFICIENT_PARTS_REMOTE_NAME)
		if remote then
			return remote
		end

		task.wait(0.25)
	end
end

local insufficientPartsRemote = waitForFeedbackRemote()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InsufficientPartsFeedback"
screenGui.DisplayOrder = 25
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local activeToken = 0
local activeTweens = {}
local activeObjects = {}
local activeConnections = {}
local activeBreadcrumbs = {}

local function disconnectActive()
	for _, tween in activeTweens do
		tween:Cancel()
	end
	table.clear(activeTweens)

	for _, connection in activeConnections do
		connection:Disconnect()
	end
	table.clear(activeConnections)

	for _, object in activeObjects do
		object:Destroy()
	end
	table.clear(activeObjects)
	table.clear(activeBreadcrumbs)
end

local function stopGuide()
	activeToken += 1
	disconnectActive()
end

local function trackObject(object)
	table.insert(activeObjects, object)
	return object
end

local function tween(instance, tweenInfo, properties)
	local createdTween = TweenService:Create(instance, tweenInfo, properties)
	table.insert(activeTweens, createdTween)
	createdTween:Play()
	return createdTween
end

local function connect(connection)
	table.insert(activeConnections, connection)
	return connection
end

local function getCharacterRoot()
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getPartsValue()
	local leaderstats = player:FindFirstChild("leaderstats")
	local parts = leaderstats and leaderstats:FindFirstChild(CurrencyConfig.PartsName)
	if parts and parts:IsA("ValueBase") and typeof(parts.Value) == "number" then
		return parts
	end

	return nil
end

local function getTargetPart(instance)
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	local clickHitbox = instance:FindFirstChild("ClickHitbox", true)
	if clickHitbox and clickHitbox:IsA("BasePart") then
		return clickHitbox
	end

	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
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

local function findClosestCollectPad(startPosition)
	local closestPad = nil
	local closestDistance = math.huge

	for _, taggedPad in CollectionService:GetTagged(COLLECT_PAD_TAG) do
		if taggedPad:IsA("BasePart") then
			local distance = (taggedPad.Position - startPosition).Magnitude
			if distance < closestDistance then
				closestPad = taggedPad
				closestDistance = distance
			end
		end
	end

	if not closestPad and not warnedMissingCollectPad then
		warn(string.format("[InsufficientPartsFeedback] No BasePart tagged %s found for guide target", COLLECT_PAD_TAG))
		warnedMissingCollectPad = true
	end

	return closestPad
end

local function findCarPileTarget()
	for _, taggedObject in CollectionService:GetTagged(PART_CLICK_SOURCE_TAG) do
		local carPile = findAncestorByName(taggedObject, "CarPile_Clickable") or taggedObject
		local targetPart = getTargetPart(carPile)
		if targetPart then
			return targetPart
		end
	end

	local starterArea = Workspace:FindFirstChild("StarterArea")
	local clickables = starterArea and starterArea:FindFirstChild("Clickables")
	local carPile = clickables and clickables:FindFirstChild("CarPile_Clickable")
	local targetPart = getTargetPart(carPile)
	if targetPart then
		return targetPart
	end

	if not warnedMissingCarPile then
		warn(string.format("[InsufficientPartsFeedback] No tagged %s or named CarPile_Clickable found for guide target", PART_CLICK_SOURCE_TAG))
		warnedMissingCarPile = true
	end

	return nil
end

local function hasStoredPartsAvailable()
	for _, collector in CollectionService:GetTagged(COLLECTOR_TAG) do
		local storedParts = collector:GetAttribute("StoredParts")
		if typeof(storedParts) == "number" and storedParts > 0 then
			return true
		end
	end

	return false
end

local function hasPassivePartsIncome()
	local incomeRate = player:GetAttribute(CurrencyConfig.PartsIncomeRateAttribute)
	return typeof(incomeRate) == "number" and incomeRate > 0
end

local function selectGuideTarget(startPosition)
	local shouldCollect = hasStoredPartsAvailable() or hasPassivePartsIncome()
	if shouldCollect then
		local collectPad = findClosestCollectPad(startPosition)
		if collectPad then
			return collectPad, COLLECT_TEXT
		end
	end

	local carPile = findCarPileTarget()
	if carPile then
		return carPile, CLICK_TEXT
	end

	local collectPad = findClosestCollectPad(startPosition)
	if collectPad then
		return collectPad, COLLECT_TEXT
	end

	return nil, COLLECT_TEXT
end

local function createFallbackMessage(text)
	local label = trackObject(Instance.new("TextLabel"))
	label.Name = "FallbackMessage"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 86)
	label.Size = UDim2.fromOffset(190, 42)
	label.BackgroundColor3 = Color3.fromRGB(24, 28, 34)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(235, 255, 240)
	label.TextSize = 17
	label.TextTransparency = 1
	label.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return label
end

local function createTargetPanel(target, text)
	local billboard = trackObject(Instance.new("BillboardGui"))
	billboard.Name = "GuideTargetPanel"
	billboard.Adornee = target
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 450
	billboard.Size = UDim2.fromOffset(text == CLICK_TEXT and 92 or 150, 34)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, text == CLICK_TEXT and 3.2 or 4, 0)
	billboard.Parent = playerGui

	local label = trackObject(Instance.new("TextLabel"))
	label.Name = "Message"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(23, 28, 34)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = text == CLICK_TEXT and Color3.fromRGB(255, 230, 126) or Color3.fromRGB(235, 255, 240)
	label.TextSize = 16
	label.TextTransparency = 1
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	local stroke = trackObject(Instance.new("UIStroke"))
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(255, 224, 120)
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.Parent = label

	return label, stroke
end

local function createArrowAnchor(parent)
	local part = trackObject(Instance.new("Part"))
	part.Name = "ArrowBreadcrumbAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function createBreadcrumb(parent)
	local anchor = createArrowAnchor(parent)
	local billboard = trackObject(Instance.new("BillboardGui"))
	billboard.Name = "CollectPartsBreadcrumb"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 500
	billboard.Size = UDim2.fromOffset(46, 46)
	billboard.Parent = playerGui

	local label = trackObject(Instance.new("TextLabel"))
	label.Name = "Arrow"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = "<"
	label.TextColor3 = ARROW_COLOR
	label.TextSize = 42
	label.TextStrokeColor3 = Color3.fromRGB(0, 64, 24)
	label.TextStrokeTransparency = 1
	label.TextTransparency = 1
	label.Parent = billboard

	local scale = Instance.new("UIScale")
	scale.Scale = 1.1
	scale.Parent = label

	return {
		anchor = anchor,
		billboard = billboard,
		label = label,
	}
end

local function destroyBreadcrumb(index)
	local breadcrumb = activeBreadcrumbs[index]
	if not breadcrumb then
		return
	end

	breadcrumb.anchor:Destroy()
	breadcrumb.label:Destroy()
	if breadcrumb.billboard then
		breadcrumb.billboard:Destroy()
	end
	table.remove(activeBreadcrumbs, index)
end

local function fadeRemoveBreadcrumb(index, fadeOut)
	local breadcrumb = activeBreadcrumbs[index]
	if not breadcrumb then
		return
	end

	table.remove(activeBreadcrumbs, index)
	tween(breadcrumb.label, fadeOut, {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	task.delay(fadeOut.Time, function()
		if breadcrumb.anchor then
			breadcrumb.anchor:Destroy()
		end
		if breadcrumb.label then
			breadcrumb.label:Destroy()
		end
		if breadcrumb.billboard then
			breadcrumb.billboard:Destroy()
		end
	end)
end

local function getEndpointFade(distanceAlongPath, usableDistance)
	local startFade = math.clamp((distanceAlongPath - START_OFFSET) / START_FADE_DISTANCE, 0, 1)
	local endFade = math.clamp((usableDistance - distanceAlongPath) / END_FADE_DISTANCE, 0, 1)
	return math.min(startFade, endFade)
end

local function applyBreadcrumbFade(breadcrumb, distanceAlongPath, usableDistance)
	if distanceAlongPath > usableDistance then
		breadcrumb.label.TextTransparency = 1
		breadcrumb.label.TextStrokeTransparency = 1
		return
	end

	local fade = getEndpointFade(distanceAlongPath, usableDistance)
	local textTransparency = 1 - (0.82 * fade)
	local strokeTransparency = 1 - (0.38 * fade)
	breadcrumb.label.TextTransparency = textTransparency
	breadcrumb.label.TextStrokeTransparency = strokeTransparency
end

local function setBreadcrumbCount(folder, count, fadeIn, fadeOut)
	while #activeBreadcrumbs < count do
		local breadcrumb = createBreadcrumb(folder)
		table.insert(activeBreadcrumbs, breadcrumb)
	end

	while #activeBreadcrumbs > count do
		fadeRemoveBreadcrumb(#activeBreadcrumbs, fadeOut)
	end
end

local function fadeOutAndCleanup(token, fadeOut)
	task.delay(FADE_SECONDS + HOLD_SECONDS, function()
		if token ~= activeToken then
			return
		end

		for _, object in activeObjects do
			if object.Parent and object:IsA("TextLabel") then
				tween(object, fadeOut, {
					BackgroundTransparency = 1,
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				})
			elseif object.Parent and object:IsA("UIStroke") then
				tween(object, fadeOut, { Transparency = 1 })
			end
		end
	end)

	task.delay(TOTAL_SECONDS, function()
		if token ~= activeToken then
			return
		end

		stopGuide()
	end)
end

local function bindPartsStopRules(token, failedCost, startingParts)
	local parts = getPartsValue()
	if not parts then
		return
	end

	connect(parts:GetPropertyChangedSignal("Value"):Connect(function()
		if token ~= activeToken then
			return
		end

		if parts.Value > startingParts then
			stopGuide()
			return
		end

		if typeof(failedCost) == "number" and parts.Value >= failedCost then
			stopGuide()
		end
	end))
end

local function playFeedback(failedCost)
	activeToken += 1
	local token = activeToken
	disconnectActive()

	local fadeIn = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fadeOut = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local root = getCharacterRoot()
	local parts = getPartsValue()
	local startingParts = parts and parts.Value or 0

	bindPartsStopRules(token, failedCost, startingParts)

	if not root then
		local label = createFallbackMessage(COLLECT_TEXT)
		tween(label, fadeIn, { BackgroundTransparency = 0.15, TextTransparency = 0 })
		fadeOutAndCleanup(token, fadeOut)
		return
	end

	local target, targetText = selectGuideTarget(root.Position)
	if not target then
		local label = createFallbackMessage(COLLECT_TEXT)
		tween(label, fadeIn, { BackgroundTransparency = 0.15, TextTransparency = 0 })
		fadeOutAndCleanup(token, fadeOut)
		return
	end

	local trailFolder = trackObject(Instance.new("Folder"))
	trailFolder.Name = "LocalInsufficientPartsGuide"
	trailFolder.Parent = Workspace

	if targetText == CLICK_TEXT then
		local panelLabel, panelStroke = createTargetPanel(target, targetText)
		tween(panelLabel, fadeIn, { BackgroundTransparency = 0.12, TextTransparency = 0 })
		tween(panelStroke, fadeIn, { Transparency = 0.25 })
	end

	local startedAt = os.clock()
	connect(RunService.RenderStepped:Connect(function()
		if token ~= activeToken then
			return
		end

		local currentRoot = getCharacterRoot()
		local camera = Workspace.CurrentCamera
		if not currentRoot or not target.Parent or not camera then
			stopGuide()
			return
		end

		local startPosition = currentRoot.Position + ARROW_FLOAT_OFFSET
		local targetPosition = target.Position + Vector3.new(0, 1.8, 0)
		local pathOffset = targetPosition - startPosition
		local distance = pathOffset.Magnitude
		local usableDistance = distance - TARGET_CLEARANCE
		if usableDistance < START_OFFSET then
			setBreadcrumbCount(trailFolder, 0, fadeIn, fadeOut)
			return
		end

		local desiredCount = math.clamp(math.floor((usableDistance - START_OFFSET) / STUDS_PER_ARROW) + 2, 1, MAX_ARROW_COUNT)
		if desiredCount < MIN_ARROW_COUNT and usableDistance >= START_OFFSET + (STUDS_PER_ARROW * (MIN_ARROW_COUNT - 1)) then
			desiredCount = MIN_ARROW_COUNT
		end
		setBreadcrumbCount(trailFolder, desiredCount, fadeIn, fadeOut)

		local direction = pathOffset.Unit
		local flowOffset = ((os.clock() - startedAt) * ARROW_FLOW_STUDS_PER_SECOND) % STUDS_PER_ARROW
		for index, breadcrumb in activeBreadcrumbs do
			local distanceAlongPath = START_OFFSET + flowOffset + (STUDS_PER_ARROW * (index - 1))

			local clampedDistance = math.min(distanceAlongPath, usableDistance)
			local position = startPosition + (direction * clampedDistance)
			breadcrumb.anchor.CFrame = CFrame.new(position)
			applyBreadcrumbFade(breadcrumb, distanceAlongPath, usableDistance)

			local screenPosition = camera:WorldToViewportPoint(position)
			local targetScreenPosition = camera:WorldToViewportPoint(targetPosition)
			local screenDirection = Vector2.new(
				targetScreenPosition.X - screenPosition.X,
				targetScreenPosition.Y - screenPosition.Y
			)

			if screenDirection.Magnitude > 0.01 then
				breadcrumb.label.Rotation = math.deg(math.atan2(screenDirection.Y, screenDirection.X)) - ARROW_SCREEN_ROTATION_OFFSET
			end
		end
	end))

	fadeOutAndCleanup(token, fadeOut)
end

insufficientPartsRemote.OnClientEvent:Connect(playFeedback)
