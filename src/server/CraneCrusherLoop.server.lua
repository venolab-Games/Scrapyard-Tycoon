local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)
local WorkspaceExclusions = require(ReplicatedStorage.Shared.WorkspaceExclusions)

local DEBUG_PREFIX = "[CraneCrusherLoop]"
local LOOKUP_WAIT_SECONDS = 5
local EXTEND_SECONDS = 1.5
local LIFT_SECONDS = 1.25
local ROTATE_SECONDS = 1.5
local THROW_SECONDS = 0.9
local CRUSH_DURATION_SECONDS = 7
local CRUSHER_CLOSED_HOLD_SECONDS = 0.75
local CAR_SPIN_SPEED_DEGREES_PER_SECOND = 180
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
	if not root or WorkspaceExclusions.IsExcluded(root) then
		return nil
	end

	if root.Name == name and not WorkspaceExclusions.IsExcluded(root) then
		return root
	end

	for _, descendant in root:GetDescendants() do
		if descendant.Name == name and not WorkspaceExclusions.IsExcluded(descendant) then
			return descendant
		end
	end

	return nil
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
	if WorkspaceExclusions.IsExcluded(object) then
		return nil
	end

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
	if WorkspaceExclusions.IsExcluded(object) then
		return false, "object is excluded from gameplay"
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
local craneBase = crane and crane:FindFirstChild("CraneBase")
local mainCraneBasePart = craneBase and craneBase:FindFirstChild("MainCraneBasePart")
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
local crusherSquasher = findDescendantByName(crusher, "CrusherSquasher")

local requiredObjects = {
	{ name = "Crane", object = crane },
	{ name = "Crane.CraneBase", object = craneBase },
	{ name = "Crane.CraneBase.MainCraneBasePart", object = mainCraneBasePart },
	{ name = "Crusher", object = crusher },
	{ name = "CrushableCar", object = crushableCar },
	{ name = "CraneExtension", object = extension },
	{ name = "CraneChain", object = chain },
	{ name = "CraneMagnet", object = magnet },
	{ name = "CranePromptPoint", object = cranePromptPoint },
	{ name = "CrusherDropPoint", object = dropPoint },
	{ name = "CrusherCollector", object = collector },
	{ name = "CrusherSquasher", object = crusherSquasher },
}

for _, requiredObject in requiredObjects do
	if not requiredObject.object then
		warnLoop(string.format("Missing expected object: %s", requiredObject.name))
		return
	end
end

if not crane:IsA("Model") then
	warnLoop("UnlockObjects.Crane must be a Model")
	return
end

if not mainCraneBasePart:IsA("BasePart") then
	warnLoop("Workspace.Scrapyard.UnlockObjects.Crane.CraneBase.MainCraneBasePart must be a BasePart")
	return
end

if not extension:IsA("BasePart") then
	warnLoop("CraneExtension must be a BasePart so its placed local-axis Size can animate")
	return
end

if not crusherSquasher:IsA("Model") or not getFirstBasePart(crusherSquasher) then
	warnLoop("CrusherSquasher must be a Model containing at least one BasePart")
	return
end

local cranePromptPart = getFirstBasePart(cranePromptPoint)
local magnetPart = getFirstBasePart(magnet)
local carPart = getFirstBasePart(crushableCar)
local collectorPart = getFirstBasePart(collector)
if not cranePromptPart or not magnetPart or not carPart or not collectorPart then
	warnLoop("Crane prompt point, magnet, crushable car, or crusher collector is missing a usable BasePart")
	return
end

diagnostic(string.format("resolved CranePromptPoint=%s; prompt part=%s", cranePromptPoint:GetFullName(), cranePromptPart:GetFullName()))
diagnostic(string.format("resolved MainCraneBasePart=%s", mainCraneBasePart:GetFullName()))

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

local function addBaseParts(object, parts)
	if WorkspaceExclusions.IsExcluded(object) then
		return
	end

	if object:IsA("BasePart") then
		parts[object] = true
	end
	for _, descendant in object:GetDescendants() do
		if descendant:IsA("BasePart") and not WorkspaceExclusions.IsExcluded(descendant) then
			parts[descendant] = true
		end
	end
end

local function captureCraneRestState(extensionDimension)
	local baseCFrame = mainCraneBasePart.CFrame
	local relativeCFrames = {}
	for _, descendant in crane:GetDescendants() do
		if descendant:IsA("BasePart") then
			relativeCFrames[descendant] = baseCFrame:ToObjectSpace(descendant.CFrame)
		end
	end

	local followerParts = {}
	addBaseParts(chain, followerParts)
	addBaseParts(magnet, followerParts)

	return {
		baseCFrame = baseCFrame,
		relativeCFrames = relativeCFrames,
		followerParts = followerParts,
		extensionDimension = extensionDimension,
		extensionSize = extension.Size,
		extensionLength = getSizeDimension(extension.Size, extensionDimension),
	}
end

local function applyCranePose(restState, yaw, extensionDistance, outwardAxisLocal, attachmentTransform)
	local rotatedBase = restState.baseCFrame * CFrame.Angles(0, yaw, 0)
	local followerOffset = outwardAxisLocal * extensionDistance
	for part, relativeCFrame in restState.relativeCFrames do
		if part.Parent and part ~= mainCraneBasePart then
			local offset = Vector3.zero
			if part == extension then
				offset = followerOffset * 0.5
			elseif restState.followerParts[part] then
				offset = followerOffset
			end
			part.CFrame = rotatedBase * CFrame.new(offset) * relativeCFrame
		end
	end

	if extension.Parent then
		extension.Size = withExtendedDimension(
			restState.extensionSize,
			restState.extensionDimension,
			restState.extensionLength + extensionDistance
		)
	end
	mainCraneBasePart.CFrame = restState.baseCFrame

	if attachmentTransform and crushableCar and crushableCar.Parent and magnetPart.Parent then
		pivotTo(crushableCar, magnetPart.CFrame * attachmentTransform)
	end
end

local function animateCranePose(restState, startYaw, targetYaw, startExtension, targetExtension, outwardAxisLocal, duration, attachmentTransform)
	local alpha = Instance.new("NumberValue")
	local connection = alpha:GetPropertyChangedSignal("Value"):Connect(function()
		local progress = alpha.Value
		applyCranePose(
			restState,
			startYaw + ((targetYaw - startYaw) * progress),
			startExtension + ((targetExtension - startExtension) * progress),
			outwardAxisLocal,
			attachmentTransform
		)
	end)
	local movement = TweenService:Create(alpha, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Value = 1 })
	movement:Play()
	movement.Completed:Wait()
	connection:Disconnect()
	alpha:Destroy()
	applyCranePose(restState, targetYaw, targetExtension, outwardAxisLocal, attachmentTransform)
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

local function captureCrusherRestState()
	local boundsCFrame = getBounds(crusherSquasher)
	local center = boundsCFrame.Position
	local pivot = crusherSquasher:GetPivot()
	local horizontalAxes = { pivot.RightVector, pivot.LookVector }
	local parts = {}
	local leftParts = {}
	local rightParts = {}
	local bestAxis = horizontalAxes[1]
	local lengthAxis = horizontalAxes[2]
	local bestSpan = -math.huge

	for axisIndex, axis in horizontalAxes do
		local minimum = math.huge
		local maximum = -math.huge
		for _, descendant in crusherSquasher:GetDescendants() do
			if descendant:IsA("BasePart") then
				local projection = (descendant.Position - center):Dot(axis)
				minimum = math.min(minimum, projection)
				maximum = math.max(maximum, projection)
			end
		end

		local span = maximum - minimum
		if span > bestSpan then
			bestSpan = span
			bestAxis = axis
			lengthAxis = horizontalAxes[axisIndex == 1 and 2 or 1]
		end
	end

	local function projectedHalfExtent(part, axis)
		return 0.5
			* ((math.abs(axis:Dot(part.CFrame.RightVector)) * part.Size.X)
				+ (math.abs(axis:Dot(part.CFrame.UpVector)) * part.Size.Y)
				+ (math.abs(axis:Dot(part.CFrame.LookVector)) * part.Size.Z))
	end

	for _, descendant in crusherSquasher:GetDescendants() do
		if descendant:IsA("BasePart") then
			local relativePosition = descendant.Position - center
			local projection = relativePosition:Dot(bestAxis)
			local partState = {
				part = descendant,
				startCFrame = descendant.CFrame,
				startAnchored = descendant.Anchored,
				relativePosition = relativePosition,
				projection = projection,
				halfExtent = projectedHalfExtent(descendant, bestAxis),
				height = relativePosition:Dot(pivot.UpVector),
				heightHalfExtent = projectedHalfExtent(descendant, pivot.UpVector),
				length = relativePosition:Dot(lengthAxis),
				lengthHalfExtent = projectedHalfExtent(descendant, lengthAxis),
				side = projection < 0 and -1 or (projection > 0 and 1 or 0),
				maxTravel = 0,
				moves = false,
			}
			table.insert(parts, partState)
			if projection < -0.001 then
				table.insert(leftParts, partState)
			elseif projection > 0.001 then
				table.insert(rightParts, partState)
			end
		end
	end

	local function findClosestMirrored(source, candidates)
		local mirroredPosition = source.relativePosition - (bestAxis * (2 * source.projection))
		local closest = nil
		local closestDistance = math.huge
		local secondClosestDistance = math.huge
		for _, candidate in candidates do
			local distance = (candidate.relativePosition - mirroredPosition).Magnitude
			if distance < closestDistance then
				secondClosestDistance = closestDistance
				closest = candidate
				closestDistance = distance
			elseif distance < secondClosestDistance then
				secondClosestDistance = distance
			end
		end
		return closest, closestDistance, secondClosestDistance
	end

	local function getGap(leftState, rightState)
		local leftInwardEdge = leftState.projection + leftState.halfExtent
		local rightInwardEdge = rightState.projection - rightState.halfExtent
		return rightInwardEdge - leftInwardEdge
	end

	local function travelStaysSafe(partState, travel)
		return travel >= 0 and travel <= math.abs(partState.projection) + 0.001
	end

	for _, leftState in leftParts do
		local rightState, mirrorDistance, nextRightDistance = findClosestMirrored(leftState, rightParts)
		if rightState and not rightState.moves then
			local reverseMatch, _, nextLeftDistance = findClosestMirrored(rightState, leftParts)
			local mirrorTolerance = math.max(
				0.25,
				math.min(leftState.part.Size.Magnitude, rightState.part.Size.Magnitude) * 0.15
			)
			local matchIsUnambiguous = nextRightDistance - mirrorDistance > 0.001
				and nextLeftDistance - mirrorDistance > 0.001
			local gap = getGap(leftState, rightState)
			local travel = gap * 0.5

			if reverseMatch == leftState
				and matchIsUnambiguous
				and mirrorDistance <= mirrorTolerance
				and gap >= 0
				and travelStaysSafe(leftState, travel)
				and travelStaysSafe(rightState, travel)
			then
				leftState.maxTravel = travel
				leftState.moves = true
				rightState.maxTravel = travel
				rightState.moves = true
			end
		end
	end

	local function findFallbackOpponent(sourceState, candidates)
		local bestCandidate = nil
		local bestSourceTravel = nil
		local bestCandidateTravel = nil
		local bestScore = math.huge
		local mirroredPosition = sourceState.relativePosition - (bestAxis * (2 * sourceState.projection))

		for _, candidateState in candidates do
			local heightDifference = math.abs(sourceState.height - candidateState.height)
			local lengthDifference = math.abs(sourceState.length - candidateState.length)
			local heightTolerance = sourceState.heightHalfExtent + candidateState.heightHalfExtent + 0.25
			local lengthTolerance = sourceState.lengthHalfExtent + candidateState.lengthHalfExtent + 0.25
			local smallerExtent = math.min(sourceState.halfExtent, candidateState.halfExtent)
			local largerExtent = math.max(sourceState.halfExtent, candidateState.halfExtent)
			local extentRatio = largerExtent > 0 and smallerExtent / largerExtent or 0
			local leftState = sourceState.side < 0 and sourceState or candidateState
			local rightState = sourceState.side > 0 and sourceState or candidateState
			local gap = getGap(leftState, rightState)
			local candidateTravel = candidateState.moves and candidateState.maxTravel or gap * 0.5
			local sourceTravel = gap - candidateTravel

			if heightDifference <= heightTolerance
				and lengthDifference <= lengthTolerance
				and extentRatio >= 0.2
				and gap >= 0
				and travelStaysSafe(sourceState, sourceTravel)
				and travelStaysSafe(candidateState, candidateTravel)
			then
				local mirrorDistance = (candidateState.relativePosition - mirroredPosition).Magnitude
				local extentDifference = math.abs(sourceState.halfExtent - candidateState.halfExtent)
				local score = mirrorDistance + heightDifference + lengthDifference + (extentDifference * 0.25)
				if score < bestScore then
					bestCandidate = candidateState
					bestSourceTravel = sourceTravel
					bestCandidateTravel = candidateTravel
					bestScore = score
				end
			end
		end

		return bestCandidate, bestSourceTravel, bestCandidateTravel
	end

	for _, partState in parts do
		if not partState.moves and partState.side ~= 0 then
			local candidates = partState.side < 0 and rightParts or leftParts
			local opponentState, partTravel, opponentTravel = findFallbackOpponent(partState, candidates)
			if opponentState then
				partState.maxTravel = partTravel
				partState.moves = true
				if not opponentState.moves then
					opponentState.maxTravel = opponentTravel
					opponentState.moves = true
				end
			end
		end
	end

	local requestedTravel = {}
	for _, partState in parts do
		requestedTravel[partState] = partState.maxTravel
	end

	for _, partState in parts do
		if partState.moves then
			local candidates = partState.side < 0 and rightParts or leftParts
			local safeTravel = math.min(partState.maxTravel, math.abs(partState.projection))
			for _, opponentState in candidates do
				local heightRangesOverlap = math.abs(partState.height - opponentState.height)
					<= partState.heightHalfExtent + opponentState.heightHalfExtent + 0.001
				local lengthRangesOverlap = math.abs(partState.length - opponentState.length)
					<= partState.lengthHalfExtent + opponentState.lengthHalfExtent + 0.001
				if heightRangesOverlap and lengthRangesOverlap then
					local leftState = partState.side < 0 and partState or opponentState
					local rightState = partState.side > 0 and partState or opponentState
					local opponentTravel = opponentState.moves and requestedTravel[opponentState] or 0
					safeTravel = math.min(safeTravel, getGap(leftState, rightState) - opponentTravel)
				end
			end
			partState.maxTravel = math.max(0, safeTravel)
			partState.moves = partState.maxTravel > 0.001
		end
	end

	for _, partState in parts do
		if not partState.moves then
			warnLoop(string.format(
				"CrusherSquasher part excluded from animation; no safe opposite-side travel exists: %s",
				partState.part:GetFullName()
			))
		end
	end

	return {
		center = center,
		axis = bestAxis,
		parts = parts,
	}
end

local function applyCrusherClosure(restState, progress)
	local clampedProgress = math.clamp(progress, 0, 1)
	for _, partState in restState.parts do
		if partState.part.Parent then
			partState.part.CFrame = partState.startCFrame
		end
	end

	for _, partState in restState.parts do
		if partState.moves and partState.part.Parent then
			local inwardOffset = restState.axis * (-partState.side * partState.maxTravel * clampedProgress)
			partState.part.CFrame = partState.startCFrame + inwardOffset
		end
	end
end

local crusherStudioRestState = captureCrusherRestState()

local function getVerticalSizeDimension(part)
	local axes = {
		{ dimension = "X", alignment = math.abs(part.CFrame.RightVector:Dot(Vector3.yAxis)) },
		{ dimension = "Y", alignment = math.abs(part.CFrame.UpVector:Dot(Vector3.yAxis)) },
		{ dimension = "Z", alignment = math.abs(part.CFrame.LookVector:Dot(Vector3.yAxis)) },
	}
	local best = axes[1]
	for index = 2, #axes do
		if axes[index].alignment > best.alignment then
			best = axes[index]
		end
	end
	return best.dimension
end

local function captureCarCrushState(centerPosition)
	local carPivot = getPivot(crushableCar)
	local centeredPivot = CFrame.new(centerPosition) * (carPivot - carPivot.Position)
	pivotTo(crushableCar, centeredPivot)

	local parts = {}
	local carParts = {}
	addBaseParts(crushableCar, carParts)
	for part in carParts do
		table.insert(parts, {
			part = part,
			relativeCFrame = centeredPivot:ToObjectSpace(part.CFrame),
			startSize = part.Size,
			verticalDimension = getVerticalSizeDimension(part),
		})
	end

	return {
		centerPosition = centerPosition,
		startRotation = centeredPivot - centeredPivot.Position,
		parts = parts,
	}
end

local function applyCarCrushPose(carState, elapsedSeconds, closureProgress)
	local spinRadians = math.rad(CAR_SPIN_SPEED_DEGREES_PER_SECOND) * elapsedSeconds
	local spinningPivot = CFrame.new(carState.centerPosition)
		* CFrame.Angles(0, spinRadians, 0)
		* carState.startRotation
	local flattenProgress = math.clamp((closureProgress - 0.7) / 0.3, 0, 1)
	flattenProgress = TweenService:GetValue(flattenProgress, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local verticalScale = 1 - (flattenProgress * 0.8)

	for _, partState in carState.parts do
		local part = partState.part
		if part.Parent then
			local targetCFrame = spinningPivot * partState.relativeCFrame
			local targetPosition = targetCFrame.Position
			local verticalOffset = targetPosition.Y - carState.centerPosition.Y
			local compressedPosition = targetPosition + Vector3.new(0, verticalOffset * (verticalScale - 1), 0)
			part.CFrame = CFrame.new(compressedPosition) * targetCFrame.Rotation

			local compressedLength = math.max(
				0.05,
				getSizeDimension(partState.startSize, partState.verticalDimension) * verticalScale
			)
			part.Size = withExtendedDimension(partState.startSize, partState.verticalDimension, compressedLength)
		end
	end
end

local function animateCrusher(restState, carState, startProgress, targetProgress, duration)
	local alpha = Instance.new("NumberValue")
	local connection = alpha:GetPropertyChangedSignal("Value"):Connect(function()
		local linearProgress = alpha.Value
		local easedProgress = TweenService:GetValue(linearProgress, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		local closureProgress = startProgress + ((targetProgress - startProgress) * easedProgress)
		applyCrusherClosure(restState, closureProgress)
		if carState and crushableCar and crushableCar.Parent then
			applyCarCrushPose(carState, linearProgress * duration, closureProgress)
		end
	end)
	local movement = TweenService:Create(alpha, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Value = 1 })
	movement:Play()
	movement.Completed:Wait()
	connection:Disconnect()
	alpha:Destroy()
	applyCrusherClosure(restState, targetProgress)
end

local function crushCarInCrusher()
	for _, partState in crusherStudioRestState.parts do
		partState.part.Anchored = true
	end
	applyCrusherClosure(crusherStudioRestState, 0)

	local dropPosition = getPivot(dropPoint).Position
	local centeredPosition = dropPosition
		+ crusherStudioRestState.axis * ((crusherStudioRestState.center - dropPosition):Dot(crusherStudioRestState.axis))
	local carCrushState = captureCarCrushState(centeredPosition)
	animateCrusher(crusherStudioRestState, carCrushState, 0, 1, CRUSH_DURATION_SECONDS)
	task.wait(CRUSHER_CLOSED_HOLD_SECONDS)

	if crushableCar and crushableCar.Parent then
		crushableCar:Destroy()
	end
	crushableCar = nil
	carPart = nil

	animateCrusher(crusherStudioRestState, nil, 1, 0, CRUSH_DURATION_SECONDS * 0.35)
	for _, partState in crusherStudioRestState.parts do
		if partState.part.Parent then
			partState.part.CFrame = partState.startCFrame
			partState.part.Anchored = partState.startAnchored
		end
	end
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
	collectorPrompt.Enabled = false
	setCarAnimationState(crushableCar)

	local magnetBounds = getBounds(magnet)
	local carBounds = getBounds(crushableCar)
	local extensionDimension, extensionAxis = getExtensionAxis(extension, carBounds.Position)
	local restState = captureCraneRestState(extensionDimension)
	local outwardAxisLocal = restState.baseCFrame:VectorToObjectSpace(extensionAxis)
	diagnostic(string.format("rotation center=%s", tostring(restState.baseCFrame.Position)))
	local extensionDistance = math.max(0, (carBounds.Position - magnetBounds.Position):Dot(extensionAxis))
	animateCranePose(restState, 0, 0, 0, extensionDistance, outwardAxisLocal, EXTEND_SECONDS, nil)

	local magnetSize
	local carSize
	magnetBounds, magnetSize = getBounds(magnet)
	carBounds, carSize = getBounds(crushableCar)
	local magnetBottom = magnetBounds.Position - (magnetBounds.UpVector * magnetSize.Y * 0.5)
	local carRoof = carBounds.Position + (carBounds.UpVector * carSize.Y * 0.5)
	local liftOffset = magnetBottom - carRoof
	tweenPivot(crushableCar, getPivot(crushableCar) + liftOffset, TweenInfo.new(LIFT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut))

	local attachmentTransform = magnetPart.CFrame:ToObjectSpace(getPivot(crushableCar))
	carBounds = getBounds(crushableCar)
	local dropPosition = getPivot(dropPoint).Position
	local currentDirection = restState.baseCFrame:PointToObjectSpace(carBounds.Position)
	local desiredDirection = restState.baseCFrame:PointToObjectSpace(dropPosition)
	currentDirection = Vector3.new(currentDirection.X, 0, currentDirection.Z)
	desiredDirection = Vector3.new(desiredDirection.X, 0, desiredDirection.Z)
	local yaw = 0
	if currentDirection.Magnitude >= 0.001 and desiredDirection.Magnitude >= 0.001 then
		currentDirection = currentDirection.Unit
		desiredDirection = desiredDirection.Unit
		yaw = math.atan2(currentDirection:Cross(desiredDirection).Y, currentDirection:Dot(desiredDirection))
	end

	local rotatedBase = restState.baseCFrame * CFrame.Angles(0, yaw, 0)
	local carCenterLocal = restState.baseCFrame:PointToObjectSpace(carBounds.Position)
	local rotatedCarCenter = rotatedBase:PointToWorldSpace(carCenterLocal)
	local rotatedOutwardAxis = rotatedBase:VectorToWorldSpace(outwardAxisLocal)
	local horizontalOutwardAxis = Vector3.new(rotatedOutwardAxis.X, 0, rotatedOutwardAxis.Z)
	local extensionAdjustment = 0
	if horizontalOutwardAxis.Magnitude >= 0.001 then
		horizontalOutwardAxis = horizontalOutwardAxis.Unit
		local horizontalTargetOffset = Vector3.new(
			dropPosition.X - rotatedCarCenter.X,
			0,
			dropPosition.Z - rotatedCarCenter.Z
		)
		extensionAdjustment = horizontalTargetOffset:Dot(horizontalOutwardAxis)
	end
	local targetExtensionDistance = math.max(
		-restState.extensionLength + 0.05,
		extensionDistance + extensionAdjustment
	)

	animateCranePose(
		restState,
		0,
		yaw,
		extensionDistance,
		targetExtensionDistance,
		outwardAxisLocal,
		ROTATE_SECONDS,
		attachmentTransform
	)
	magnetBounds = getBounds(magnet)
	carBounds = getBounds(crushableCar)
	local assemblyPosition = (magnetBounds.Position + carBounds.Position) * 0.5
	local finalHorizontalDistance = (Vector3.new(assemblyPosition.X, 0, assemblyPosition.Z) - Vector3.new(dropPosition.X, 0, dropPosition.Z)).Magnitude
	diagnostic(string.format("magnet position=%s; attached car position=%s", tostring(magnetBounds.Position), tostring(carBounds.Position)))
	diagnostic(string.format("final horizontal assembly distance to CrusherDropPoint=%.3f", finalHorizontalDistance))

	throwCarIntoCrusher()
	crushCarInCrusher()

	collectorPrompt.Enabled = false
	animateCranePose(restState, yaw, 0, targetExtensionDistance, 0, outwardAxisLocal, ROTATE_SECONDS, nil)

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
