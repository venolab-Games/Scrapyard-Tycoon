local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)
local WorkspaceExclusions = require(ReplicatedStorage.Shared.WorkspaceExclusions)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local REMOTES_FOLDER_NAME = "Remotes"
local INSUFFICIENT_PARTS_REMOTE_NAME = "ShowInsufficientPartsFeedback"
local COLLECT_PAD_TAG = "CollectPad"
local COLLECTOR_TAG = "Collector"
local PART_CLICK_SOURCE_TAG = "PartClickSource"
local COLLECT_TEXT = "Collect Parts"
local TOTAL_SECONDS = 7
local FADE_SECONDS = 1.25
local HOLD_SECONDS = TOTAL_SECONDS - (FADE_SECONDS * 2)
local ARROW_IMAGE = "rbxassetid://97625287185566"
local ARROW_FLOAT_OFFSET = Vector3.new(0, 0.2, 0)
local ARROW_FLOW_STUDS_PER_SECOND = 3
local ARROW_VISUAL_SIZE_PIXELS = 80.5
local ARROW_MARKER_SIZE_STUDS = 4
local MIN_ARROW_COUNT = 3
local MAX_ARROW_COUNT = 12
local STUDS_PER_ARROW = 7
local START_OFFSET = 0
local TARGET_CLEARANCE = 5

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
	if not instance or WorkspaceExclusions.IsExcluded(instance) then
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
	if WorkspaceExclusions.IsExcluded(instance) then
		return nil
	end

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
		if taggedPad:IsA("BasePart") and not WorkspaceExclusions.IsExcluded(taggedPad) then
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
		if not WorkspaceExclusions.IsExcluded(taggedObject) then
			local carPile = findAncestorByName(taggedObject, "CarPile_Clickable") or taggedObject
			local targetPart = getTargetPart(carPile)
			if targetPart then
				return targetPart
			end
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
		if not WorkspaceExclusions.IsExcluded(collector) then
			local storedParts = collector:GetAttribute("StoredParts")
			if typeof(storedParts) == "number" and storedParts > 0 then
				return true
			end
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
			return collectPad
		end
	end

	local carPile = findCarPileTarget()
	if carPile then
		return carPile
	end

	local collectPad = findClosestCollectPad(startPosition)
	if collectPad then
		return collectPad
	end

	return nil
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

local function createArrowAnchor(parent)
	local part = trackObject(Instance.new("Part"))
	part.Name = "ArrowBreadcrumbAnchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Size = Vector3.new(ARROW_MARKER_SIZE_STUDS, 0.05, ARROW_MARKER_SIZE_STUDS)
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function createBreadcrumb(parent)
	local anchor = createArrowAnchor(parent)
	local surfaceGui = trackObject(Instance.new("SurfaceGui"))
	surfaceGui.Name = "CollectPartsBreadcrumb"
	surfaceGui.Adornee = anchor
	surfaceGui.AlwaysOnTop = false
	surfaceGui.CanvasSize = Vector2.new(ARROW_VISUAL_SIZE_PIXELS, ARROW_VISUAL_SIZE_PIXELS)
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.LightInfluence = 0
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.Parent = playerGui

	local image = trackObject(Instance.new("ImageLabel"))
	image.Name = "Arrow"
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.Image = ARROW_IMAGE
	image.ImageTransparency = 0
	image.Rotation = 90
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = surfaceGui

	return {
		anchor = anchor,
		surfaceGui = surfaceGui,
		image = image,
	}
end

local function destroyBreadcrumb(index)
	local breadcrumb = activeBreadcrumbs[index]
	if not breadcrumb then
		return
	end

	breadcrumb.anchor:Destroy()
	breadcrumb.image:Destroy()
	if breadcrumb.surfaceGui then
		breadcrumb.surfaceGui:Destroy()
	end
	table.remove(activeBreadcrumbs, index)
end

local function setBreadcrumbCount(folder, count)
	while #activeBreadcrumbs < count do
		local breadcrumb = createBreadcrumb(folder)
		table.insert(activeBreadcrumbs, breadcrumb)
	end

	while #activeBreadcrumbs > count do
		destroyBreadcrumb(#activeBreadcrumbs)
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

	local target = selectGuideTarget(root.Position)
	if not target then
		local label = createFallbackMessage(COLLECT_TEXT)
		tween(label, fadeIn, { BackgroundTransparency = 0.15, TextTransparency = 0 })
		fadeOutAndCleanup(token, fadeOut)
		return
	end

	local trailFolder = trackObject(Instance.new("Folder"))
	trailFolder.Name = "LocalInsufficientPartsGuide"
	trailFolder.Parent = Workspace

	local startedAt = os.clock()
	connect(RunService.RenderStepped:Connect(function()
		if token ~= activeToken then
			return
		end

		local currentRoot = getCharacterRoot()
		if not currentRoot or not target.Parent then
			stopGuide()
			return
		end

		local startPosition = currentRoot.Position + ARROW_FLOAT_OFFSET
		local targetPosition = target.Position + Vector3.new(0, 1.8, 0)
		local pathOffset = targetPosition - startPosition
		local distance = pathOffset.Magnitude
		local usableDistance = distance - TARGET_CLEARANCE
		if usableDistance < START_OFFSET then
			setBreadcrumbCount(trailFolder, 0)
			return
		end

		local desiredCount = math.clamp(math.floor((usableDistance - START_OFFSET) / STUDS_PER_ARROW) + 1, 1, MAX_ARROW_COUNT)
		if desiredCount < MIN_ARROW_COUNT and usableDistance >= START_OFFSET + (STUDS_PER_ARROW * (MIN_ARROW_COUNT - 1)) then
			desiredCount = MIN_ARROW_COUNT
		end
		setBreadcrumbCount(trailFolder, desiredCount)

		local direction = pathOffset.Unit
		local horizontalDirection = Vector3.new(direction.X, 0, direction.Z)
		if horizontalDirection.Magnitude > 0.001 then
			horizontalDirection = horizontalDirection.Unit
		else
			horizontalDirection = Vector3.new(1, 0, 0)
		end
		local markerBack = horizontalDirection:Cross(Vector3.yAxis)
		local flowOffset = ((os.clock() - startedAt) * ARROW_FLOW_STUDS_PER_SECOND) % STUDS_PER_ARROW
		for index, breadcrumb in activeBreadcrumbs do
			local distanceAlongPath = START_OFFSET + flowOffset + (STUDS_PER_ARROW * (index - 1))

			local clampedDistance = math.min(distanceAlongPath, usableDistance)
			local position = startPosition + (direction * clampedDistance)
			breadcrumb.anchor.CFrame = CFrame.fromMatrix(position, horizontalDirection, Vector3.yAxis, markerBack)
			breadcrumb.surfaceGui.Enabled = distanceAlongPath <= usableDistance
			breadcrumb.image.ImageTransparency = 0
		end
	end))

	fadeOutAndCleanup(token, fadeOut)
end

insufficientPartsRemote.OnClientEvent:Connect(playFeedback)
