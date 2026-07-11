local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)

local DEBUG_PREFIX = "[CraneCrusherLoop]"
local LOOKUP_WAIT_SECONDS = 5
local EXTEND_SECONDS = 1.5
local LIFT_SECONDS = 1.25
local ROTATE_SECONDS = 1.5
local THROW_SECONDS = 0.9
local COLLECTOR_DELAY_SECONDS = 2
local CRUSHER_REWARD_PARTS = 500
local CAR_RESPAWN_SECONDS = 10
local ENABLE_PROMPT_DIAGNOSTICS = false -- TEMPORARY: disable after Studio prompt verification.

local REQUIRED_BUTTON_NAMES = {
	"BuildButton_CrushableCar",
	"BuildButton_Crane",
	"BuildButton_Crusher",
}

local function warnLoop(message)
	warn(string.format("%s %s", DEBUG_PREFIX, message))
end

local function diagnostic(message)
	if ENABLE_PROMPT_DIAGNOSTICS then
		warnLoop(string.format("DIAGNOSTIC: %s", message))
	end
end

diagnostic("script startup")

local function findDescendantByName(root, name)
	if not root then
		return nil
	end

	if root.Name == name then
		return root
	end

	return root:FindFirstChild(name, true)
end

local function getPivot(object)
	if object:IsA("Model") then
		return object:GetPivot()
	elseif object:IsA("BasePart") then
		return object.CFrame
	end

	error(string.format("%s cannot pivot %s (%s)", DEBUG_PREFIX, object:GetFullName(), object.ClassName))
end

local function pivotTo(object, cframe)
	if object:IsA("Model") then
		object:PivotTo(cframe)
	elseif object:IsA("BasePart") then
		object.CFrame = cframe
	end
end

local function getBounds(object)
	if object:IsA("Model") then
		return object:GetBoundingBox()
	elseif object:IsA("BasePart") then
		return object.CFrame, object.Size
	end

	error(string.format("%s cannot get bounds for %s (%s)", DEBUG_PREFIX, object:GetFullName(), object.ClassName))
end

local function getFirstBasePart(object)
	if object:IsA("BasePart") then
		return object
	end
	if object:IsA("Model") and object.PrimaryPart then
		return object.PrimaryPart
	end

	return object:FindFirstChildWhichIsA("BasePart", true)
end

local function tweenPivot(object, targetCFrame, tweenInfo)
	local value = Instance.new("CFrameValue")
	value.Value = getPivot(object)
	local connection = value:GetPropertyChangedSignal("Value"):Connect(function()
		if object.Parent then
			pivotTo(object, value.Value)
		end
	end)
	local movement = TweenService:Create(value, tweenInfo, { Value = targetCFrame })
	movement:Play()
	movement.Completed:Wait()
	connection:Disconnect()
	value:Destroy()
end

local function getIndependentMovingRoots(candidates)
	local roots = {}
	for _, object in candidates do
		local nested = false
		for _, other in candidates do
			if object ~= other and object:IsDescendantOf(other) then
				nested = true
				break
			end
		end
		if not nested then
			table.insert(roots, object)
		end
	end

	return roots
end

local function tweenExtensionAndFollowers(extensionPart, targetSize, targetCFrame, followerTargets, tweenInfo)
	local startSize = extensionPart.Size
	local startCFrame = extensionPart.CFrame
	local followerStarts = {}
	for object in followerTargets do
		followerStarts[object] = getPivot(object)
	end

	local alpha = Instance.new("NumberValue")
	local connection = alpha:GetPropertyChangedSignal("Value"):Connect(function()
		local progress = alpha.Value
		if extensionPart.Parent then
			extensionPart.Size = startSize:Lerp(targetSize, progress)
			extensionPart.CFrame = startCFrame:Lerp(targetCFrame, progress)
		end
		for object, target in followerTargets do
			if object.Parent then
				pivotTo(object, followerStarts[object]:Lerp(target, progress))
			end
		end
	end)
	local movement = TweenService:Create(alpha, tweenInfo, { Value = 1 })
	movement:Play()
	movement.Completed:Wait()
	connection:Disconnect()
	alpha:Destroy()
end

local function getExtensionAxis(extensionPart, targetPosition)
	local towardTarget = targetPosition - extensionPart.Position
	towardTarget = Vector3.new(towardTarget.X, 0, towardTarget.Z)
	if towardTarget.Magnitude < 0.001 then
		return "X", extensionPart.CFrame.RightVector
	end
	towardTarget = towardTarget.Unit

	local candidates = {
		{ dimension = "X", vector = extensionPart.CFrame.RightVector },
		{ dimension = "Y", vector = extensionPart.CFrame.UpVector },
		{ dimension = "Z", vector = extensionPart.CFrame.LookVector },
	}
	local best = candidates[1]
	local bestDot = towardTarget:Dot(best.vector)
	for index = 2, #candidates do
		local candidate = candidates[index]
		local dot = towardTarget:Dot(candidate.vector)
		if math.abs(dot) > math.abs(bestDot) then
			best = candidate
			bestDot = dot
		end
	end

	return best.dimension, best.vector * (bestDot >= 0 and 1 or -1)
end

local function withExtendedDimension(size, dimension, length)
	if dimension == "X" then
		return Vector3.new(length, size.Y, size.Z)
	elseif dimension == "Y" then
		return Vector3.new(size.X, length, size.Z)
	end

	return Vector3.new(size.X, size.Y, length)
end

local function getSizeDimension(size, dimension)
	if dimension == "X" then
		return size.X
	elseif dimension == "Y" then
		return size.Y
	end

	return size.Z
end

local function setCarAnimationState(car)
	for _, descendant in car:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end

	if car:IsA("BasePart") then
		car.Anchored = true
		car.CanCollide = false
		car.CanTouch = false
		car.CanQuery = false
	end
end

local function createPrompt(parent, name, actionText, objectText)
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Enabled = false
	prompt.Parent = parent
	return prompt
end

local function getVisibilityDiagnostic(object)
	if not object then
		return false, "object is absent"
	end

	local firstPart = nil
	local partCount = 0
	for _, descendant in object:GetDescendants() do
		if descendant:IsA("BasePart") then
			firstPart = firstPart or descendant
			partCount += 1
			if descendant:IsDescendantOf(Workspace) and descendant.Transparency < 1 and descendant.LocalTransparencyModifier < 1 then
				return true, string.format("visible part=%s", descendant:GetFullName())
			end
		end
	end

	if object:IsA("BasePart") then
		firstPart = object
		partCount = 1
		if object:IsDescendantOf(Workspace) and object.Transparency < 1 and object.LocalTransparencyModifier < 1 then
			return true, string.format("visible part=%s", object:GetFullName())
		end
	end

	if firstPart then
		return false, string.format(
			"no visible parts (parts=%d, first=%s, Transparency=%s, LocalTransparencyModifier=%s, OriginalTransparency=%s)",
			partCount,
			firstPart:GetFullName(),
			tostring(firstPart.Transparency),
			tostring(firstPart.LocalTransparencyModifier),
			tostring(firstPart:GetAttribute("OriginalTransparency"))
		)
	end

	return false, "no descendant BasePart"
end

local scrapyard = Workspace:FindFirstChild("Scrapyard") or Workspace:WaitForChild("Scrapyard", LOOKUP_WAIT_SECONDS)
local unlockObjects = scrapyard and (scrapyard:FindFirstChild("UnlockObjects") or scrapyard:WaitForChild("UnlockObjects", LOOKUP_WAIT_SECONDS))
if not scrapyard or not unlockObjects then
	warnLoop("Workspace.Scrapyard.UnlockObjects is missing; crane/crusher loop was not initialized")
	return
end

local crane = unlockObjects:FindFirstChild("Crane")
local crusher = unlockObjects:FindFirstChild("Crusher")
local brokenCars = unlockObjects:FindFirstChild("BrokenCars")
local crushableCar = brokenCars and brokenCars:FindFirstChild("CrushableCar")
local extension = findDescendantByName(crane, "CraneExtension")
local chain = findDescendantByName(crane, "CraneChain")
local magnet = findDescendantByName(crane, "CraneMagnet")
local cranePromptPoint = scrapyard:FindFirstChild("CranePromptPoint")
	or findDescendantByName(crane, "CranePromptPoint")
	or findDescendantByName(unlockObjects, "CranePromptPoint")
local dropPoint = findDescendantByName(crusher, "CrusherDropPoint")
local collector = findDescendantByName(crusher, "CrusherCollector")

local requiredObjects = {
	{ name = "Crane", object = crane },
	{ name = "Crusher", object = crusher },
	{ name = "CrushableCar", object = crushableCar },
	{ name = "CraneExtension", object = extension },
	{ name = "CraneChain", object = chain },
	{ name = "CraneMagnet", object = magnet },
	{ name = "CranePromptPoint", object = cranePromptPoint },
	{ name = "CrusherDropPoint", object = dropPoint },
	{ name = "CrusherCollector", object = collector },
}

for _, requiredObject in requiredObjects do
	if not requiredObject.object then
		warnLoop(string.format("Missing expected object: %s", requiredObject.name))
		return
	end
end

if not crane:IsA("Model") then
	warnLoop("UnlockObjects.Crane must be a Model so it can rotate around its existing pivot")
	return
end

if not extension:IsA("BasePart") then
	warnLoop("CraneExtension must be a BasePart so its placed local-axis Size can animate")
	return
end

local followerRoots = getIndependentMovingRoots({ chain, magnet })
local cranePromptPart = getFirstBasePart(cranePromptPoint)
local magnetPart = getFirstBasePart(magnet)
local carPart = getFirstBasePart(crushableCar)
local collectorPart = getFirstBasePart(collector)
if not cranePromptPart or not magnetPart or not carPart or not collectorPart then
	warnLoop("Crane prompt point, magnet, crushable car, or crusher collector is missing a usable BasePart")
	return
end

diagnostic(string.format("resolved CranePromptPoint=%s; prompt part=%s", cranePromptPoint:GetFullName(), cranePromptPart:GetFullName()))

local buttons = {}
for _, buttonName in REQUIRED_BUTTON_NAMES do
	local button = findDescendantByName(scrapyard, buttonName)
	if not button then
		warnLoop(string.format("Missing expected build button: %s", buttonName))
		return
	end
	buttons[buttonName] = button
end

local cranePrompt = createPrompt(cranePromptPart, "OperateCranePrompt", "Operate Crane", "Crane")
local collectorPrompt = createPrompt(collectorPart, "CrusherCollectorPrompt", "Collect 500 Parts", "Crusher")
diagnostic(string.format("created %s under %s with Enabled=%s", cranePrompt:GetFullName(), cranePrompt.Parent:GetFullName(), tostring(cranePrompt.Enabled)))
local sequenceRunning = false
local carReady = true
local rewardPending = false
local rewardClaimedThisCycle = false
local cycleId = 0
local carTemplate = nil
local carSpawnParent = nil
local carSpawnPivot = nil
local countdownPosition = nil
local promptRefreshGeneration = 0
local lastPromptDiagnostic = nil

local function purchasesComplete()
	for _, buttonName in REQUIRED_BUTTON_NAMES do
		if buttons[buttonName]:GetAttribute("Purchased") ~= true then
			return false
		end
	end

	return true
end

local function refreshCranePrompt()
	local purchasesReady = purchasesComplete()
	local crushableCarVisible, crushableCarVisibility = getVisibilityDiagnostic(crushableCar)
	local craneVisible, craneVisibility = getVisibilityDiagnostic(crane)
	local crusherVisible, crusherVisibility = getVisibilityDiagnostic(crusher)
	local shouldEnable = not sequenceRunning
		and carReady
		and not rewardPending
		and purchasesReady
		and crushableCarVisible
		and craneVisible
		and crusherVisible
	cranePrompt.Enabled = shouldEnable

	local purchaseSummary = {}
	for _, buttonName in REQUIRED_BUTTON_NAMES do
		table.insert(purchaseSummary, string.format("%s=%s", buttonName, tostring(buttons[buttonName]:GetAttribute("Purchased") == true)))
	end
	local failedCondition = sequenceRunning and "sequence running"
		or (not carReady and "fresh CrushableCar not ready")
		or (rewardPending and "collector reward pending")
		or (not purchasesReady and "required purchase false")
		or (not crushableCarVisible and "CrushableCar not visible")
		or (not craneVisible and "Crane not visible")
		or (not crusherVisible and "Crusher not visible")
		or "none"
	local summary = string.format(
		"purchases[%s]; visibility[CrushableCar=%s (%s), Crane=%s (%s), Crusher=%s (%s)]; Enabled=%s; failed=%s",
		table.concat(purchaseSummary, ", "),
		tostring(crushableCarVisible),
		crushableCarVisibility,
		tostring(craneVisible),
		craneVisibility,
		tostring(crusherVisible),
		crusherVisibility,
		tostring(shouldEnable),
		failedCondition
	)
	if summary ~= lastPromptDiagnostic then
		lastPromptDiagnostic = summary
		diagnostic(summary)
	end
end

local function scheduleCranePromptRefresh()
	promptRefreshGeneration += 1
	local generation = promptRefreshGeneration
	task.spawn(function()
		for _ = 1, 20 do
			if generation ~= promptRefreshGeneration or sequenceRunning then
				return
			end

			refreshCranePrompt()
			if cranePrompt.Enabled or not purchasesComplete() then
				return
			end
			task.wait(0.1)
		end
	end)
end

for _, buttonName in REQUIRED_BUTTON_NAMES do
	buttons[buttonName]:GetAttributeChangedSignal("Purchased"):Connect(function()
		scheduleCranePromptRefresh()
	end)
end
scheduleCranePromptRefresh()

local function rotateCraneTowardDropPoint()
	local cranePivot = crane:GetPivot()
	local pivotPosition = cranePivot.Position
	local currentDirection = getPivot(magnet).Position - pivotPosition
	local desiredDirection = getPivot(dropPoint).Position - pivotPosition
	currentDirection = Vector3.new(currentDirection.X, 0, currentDirection.Z)
	desiredDirection = Vector3.new(desiredDirection.X, 0, desiredDirection.Z)
	if currentDirection.Magnitude < 0.001 or desiredDirection.Magnitude < 0.001 then
		return
	end

	currentDirection = currentDirection.Unit
	desiredDirection = desiredDirection.Unit
	local yaw = math.atan2(currentDirection:Cross(desiredDirection).Y, currentDirection:Dot(desiredDirection))
	local rotation = CFrame.new(pivotPosition) * CFrame.Angles(0, yaw, 0) * CFrame.new(-pivotPosition)
	tweenPivot(crane, rotation * cranePivot, TweenInfo.new(ROTATE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut))
end

local function throwCarIntoCrusher()
	local startCFrame = getPivot(crushableCar)
	local targetPosition = getPivot(dropPoint).Position
	local startPosition = startCFrame.Position
	local controlPosition = (startPosition + targetPosition) * 0.5 + Vector3.new(0, 8, 0)
	local startRotation = startCFrame - startPosition
	local alpha = Instance.new("NumberValue")
	local connection = alpha:GetPropertyChangedSignal("Value"):Connect(function()
		if not crushableCar.Parent then
			return
		end

		local t = alpha.Value
		local inverse = 1 - t
		local position = (inverse * inverse * startPosition) + (2 * inverse * t * controlPosition) + (t * t * targetPosition)
		local playfulRotation = CFrame.Angles(t * math.rad(35), t * math.rad(210), t * math.rad(20))
		pivotTo(crushableCar, CFrame.new(position) * startRotation * playfulRotation)
	end)
	local movement = TweenService:Create(alpha, TweenInfo.new(THROW_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 })
	movement:Play()
	movement.Completed:Wait()
	connection:Disconnect()
	alpha:Destroy()
end

local function captureCarTemplate()
	if carTemplate then
		return
	end

	local originalArchivable = crushableCar.Archivable
	crushableCar.Archivable = true
	carTemplate = crushableCar:Clone()
	crushableCar.Archivable = originalArchivable
	carTemplate.Parent = nil
	carSpawnParent = crushableCar.Parent
	carSpawnPivot = getPivot(crushableCar)
	local spawnBounds, spawnSize = getBounds(crushableCar)
	countdownPosition = spawnBounds.Position + Vector3.new(0, (spawnSize.Y * 0.5) + 2, 0)
end

local function createRespawnCountdown()
	local anchor = Instance.new("Part")
	anchor.Name = "CrushableCarRespawnCountdownAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Massless = true
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(countdownPosition)
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CrushableCarRespawnCountdown"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = 250
	billboard.Size = UDim2.fromOffset(64, 28)
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "Countdown"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.45
	label.Parent = billboard

	return anchor, label
end

local function respawnCarAfterCountdown(completedCycleId)
	task.spawn(function()
		local countdownAnchor, countdownLabel = createRespawnCountdown()
		for seconds = CAR_RESPAWN_SECONDS, 1, -1 do
			if completedCycleId ~= cycleId then
				countdownAnchor:Destroy()
				return
			end
			countdownLabel.Text = string.format("%ds", seconds)
			task.wait(1)
		end

		if completedCycleId ~= cycleId then
			countdownAnchor:Destroy()
			return
		end

		local freshCar = carTemplate:Clone()
		freshCar.Name = "CrushableCar"
		freshCar.Parent = carSpawnParent
		pivotTo(freshCar, carSpawnPivot)
		crushableCar = freshCar
		carPart = getFirstBasePart(freshCar)
		carReady = carPart ~= nil
		countdownAnchor:Destroy()
		refreshCranePrompt()
	end)
end

local function runSequence()
	local restState = {
		cranePivot = crane:GetPivot(),
		extensionSize = extension.Size,
		extensionCFrame = extension.CFrame,
		chainPivot = getPivot(chain),
		magnetPivot = getPivot(magnet),
		followerPivots = {},
	}
	for _, object in followerRoots do
		restState.followerPivots[object] = getPivot(object)
	end
	collectorPrompt.Enabled = false
	setCarAnimationState(crushableCar)

	local magnetBounds = getBounds(magnet)
	local carBounds = getBounds(crushableCar)
	local extensionDimension, extensionAxis = getExtensionAxis(extension, carBounds.Position)
	local extensionDistance = math.max(0, (carBounds.Position - magnetBounds.Position):Dot(extensionAxis))
	local originalLength = getSizeDimension(restState.extensionSize, extensionDimension)
	local extendedSize = withExtendedDimension(restState.extensionSize, extensionDimension, originalLength + extensionDistance)
	local extendedCFrame = restState.extensionCFrame + (extensionAxis * extensionDistance * 0.5)
	local extendedFollowerTargets = {}
	for _, object in followerRoots do
		extendedFollowerTargets[object] = restState.followerPivots[object] + (extensionAxis * extensionDistance)
	end
	tweenExtensionAndFollowers(
		extension,
		extendedSize,
		extendedCFrame,
		extendedFollowerTargets,
		TweenInfo.new(EXTEND_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	)

	local magnetSize
	local carSize
	magnetBounds, magnetSize = getBounds(magnet)
	carBounds, carSize = getBounds(crushableCar)
	local magnetBottom = magnetBounds.Position - (magnetBounds.UpVector * magnetSize.Y * 0.5)
	local carRoof = carBounds.Position + (carBounds.UpVector * carSize.Y * 0.5)
	local liftOffset = Vector3.new(0, magnetBottom.Y - carRoof.Y, 0)
	tweenPivot(crushableCar, getPivot(crushableCar) + liftOffset, TweenInfo.new(LIFT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut))

	local originalParent = crushableCar.Parent
	crushableCar.Parent = crane
	local attachment = Instance.new("WeldConstraint")
	attachment.Name = "TemporaryCraneMagnetAttachment"
	attachment.Part0 = magnetPart
	attachment.Part1 = carPart
	attachment.Parent = magnetPart

	rotateCraneTowardDropPoint()

	attachment:Destroy()
	crushableCar.Parent = originalParent
	throwCarIntoCrusher()
	crushableCar:Destroy()
	crushableCar = nil
	carPart = nil

	collectorPrompt.Enabled = false
	tweenPivot(crane, restState.cranePivot, TweenInfo.new(ROTATE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut))
	tweenExtensionAndFollowers(
		extension,
		restState.extensionSize,
		restState.extensionCFrame,
		restState.followerPivots,
		TweenInfo.new(EXTEND_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	)
	extension.Size = restState.extensionSize
	extension.CFrame = restState.extensionCFrame
	pivotTo(chain, restState.chainPivot)
	pivotTo(magnet, restState.magnetPivot)

	sequenceRunning = false
	rewardPending = true
	rewardClaimedThisCycle = false
	local completedCycleId = cycleId
	respawnCarAfterCountdown(completedCycleId)
	task.wait(COLLECTOR_DELAY_SECONDS)
	if completedCycleId == cycleId and rewardPending and not rewardClaimedThisCycle and collectorPrompt.Parent then
		collectorPrompt.Enabled = true
	end
end

cranePrompt.Triggered:Connect(function()
	if sequenceRunning or not carReady or rewardPending or not crushableCar or not purchasesComplete() then
		return
	end

	captureCarTemplate()
	cycleId += 1
	sequenceRunning = true
	carReady = false
	cranePrompt.Enabled = false
	task.spawn(function()
		local ok, failure = xpcall(runSequence, debug.traceback)
		if not ok then
			warnLoop(string.format("Crane sequence failed: %s", failure))
		end
	end)
end)

collectorPrompt.Triggered:Connect(function(player)
	if rewardClaimedThisCycle or not rewardPending or not collectorPrompt.Enabled then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local parts = leaderstats and leaderstats:FindFirstChild(CurrencyConfig.PartsName)
	if not parts or not parts:IsA("IntValue") then
		warnLoop(string.format("Cannot award Crusher reward to %s because leaderstats.%s is missing", player.Name, CurrencyConfig.PartsName))
		return
	end

	rewardClaimedThisCycle = true
	rewardPending = false
	collectorPrompt.Enabled = false
	parts.Value += CRUSHER_REWARD_PARTS
	refreshCranePrompt()
end)
