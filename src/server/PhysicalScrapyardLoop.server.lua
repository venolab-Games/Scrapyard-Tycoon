local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BrokenCarProduction = require(ReplicatedStorage.Shared.BrokenCarProduction)
local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)
local WorkspaceExclusions = require(ReplicatedStorage.Shared.WorkspaceExclusions)

local DEBUG_PREFIX = "[PhysicalScrapyardLoop]"
local ENABLE_DEBUG_LOGS = false
local PART_CLICK_REWARD = 1
local CLICK_DEBOUNCE_SECONDS = 0.08
local FREE_BUILD_TESTING = true -- TEMPORARY: set false to restore normal Parts checks and deductions.
local BUTTON_COLORS = {
	CannotAfford = Color3.fromRGB(220, 64, 64),
	CanAfford = Color3.fromRGB(67, 201, 112),
	Purchased = Color3.fromRGB(80, 80, 80),
}

local BUTTON_LABEL_NAME = "BuildButtonLabel"
local BUTTON_LABEL_SIGN_NAME = "BuildButtonLabelSign"
local BUTTON_LABEL_SIGN_TAG = "BuildButtonLabelSign"
local LEGACY_BUTTON_LABEL_ANCHOR_NAME = "BuildButtonLabelAnchor"
local BUTTON_PANEL_NAME = "Panel"
local BUTTON_PANEL_BORDER_THICKNESS = 8.4375
local REMOTES_FOLDER_NAME = "Remotes"
local INSUFFICIENT_PARTS_REMOTE_NAME = "ShowInsufficientPartsFeedback"
local SCRAPYARD_LOOKUP_WAIT_SECONDS = 5
local PATHS_FOLDER_NAME = "Paths"
local FENCES_FOLDER_NAME = "Fences"
local BUILD_BUTTONS_FOLDER_NAME = "BuildButtons"
local HIDDEN_BUTTONS_FOLDER_NAME = "HiddenButtons"
local BROKEN_CAR_DISPLAY_NAME = "Broken Car"
local EXPANSION_DISPLAY_NAME = "Expand Scrapyard"
local buttonLabelConnections = {}

local FENCE_01_EXPANSION_OPENING_PIECES = {
	"FenceBeam_05",
	"FenceBeam_06",
	"FenceBeam_07",
	"FenceBeam_08",
	"FenceBeam_09",
	"FenceBeam_10",
	"FencePost_07",
	"FencePost_08",
	"FencePost_09",
	"FencePost_10",
	"FencePost_11",
}

local FENCE_02_EXPANSION_OPENING_PIECES = {
	"FenceBeam_17",
	"FenceBeam_18",
	"FenceBeam_19",
	"FenceBeam_20",
	"FenceBeam_21",
	"FenceBeam_22",
	"FencePost_19",
	"FencePost_20",
	"FencePost_21",
	"FencePost_22",
	"FencePost_23",
}

local FENCE_01_OPERATION_OPENING_PIECES = {
	"FenceBeam_11",
	"FenceBeam_12",
	"FenceBeam_13",
	"FenceBeam_14",
	"FenceBeam_15",
	"FenceBeam_16",
	"FencePost_12",
	"FencePost_13",
	"FencePost_14",
	"FencePost_15",
	"FencePost_16",
	"FencePost_17",
}

local function hiddenButtonStep(config)
	config.buttonFolder = HIDDEN_BUTTONS_FOLDER_NAME
	return config
end

local function expansionStep(index, config)
	config.buttonName = string.format("BuildButton_ExpandScrapyard_%02d", index)
	config.buttonFolder = HIDDEN_BUTTONS_FOLDER_NAME
	config.displayName = EXPANSION_DISPLAY_NAME
	config.clearProductionAttributes = true
	return config
end

local function brokenCarStep(index, cost, revealButtons)
	local brokenCarName = string.format("BrokenCar_%02d", index)

	return hiddenButtonStep({
		buttonName = string.format("BuildButton_BrokenCar_%02d", index),
		displayName = BROKEN_CAR_DISPLAY_NAME,
		cost = cost,
		producesPartsPerSecond = BrokenCarProduction.PartsPerSecondByName[brokenCarName],
		revealObjects = { brokenCarName },
		revealButtons = revealButtons or {},
	})
end

local buildSteps = {
	{
		buttonName = "BuildButton_UnlockScrapyard",
		buttonFolder = BUILD_BUTTONS_FOLDER_NAME,
		displayName = "Unlock Scrapyard",
		cost = 10,
		revealObjects = { "ScrapyardFence_01", "ScrapyardPath_01", "ScrapyardPath_02", "ScrapyardPath_03" },
		revealButtons = { "BuildButton_BrokenCar_01" },
	},
	hiddenButtonStep({
		buttonName = "BuildButton_UnlockOperation",
		revealObjects = { "ScrapyardSlab_04", "ScrapyardFence_04", "ScrapyardPath_09", "ScrapyardPath_10" },
		hideDescendants = {
			{
				objectName = "ScrapyardFence_01",
				parentFolderName = FENCES_FOLDER_NAME,
				expectedPath = "Workspace > Scrapyard > UnlockObjects > Fences > ScrapyardFence_01",
				descendantNames = FENCE_01_OPERATION_OPENING_PIECES,
			},
			{
				objectName = "ScrapyardFence_03",
				parentFolderName = FENCES_FOLDER_NAME,
				expectedPath = "Workspace > Scrapyard > UnlockObjects > Fences > ScrapyardFence_03",
				descendantNames = FENCE_02_EXPANSION_OPENING_PIECES,
			},
		},
		revealButtons = { "BuildButton_CrushableCar" },
	}),
	hiddenButtonStep({
		buttonName = "BuildButton_CrushableCar",
		revealObjects = { "CrushableCar" },
		revealButtons = { "BuildButton_Crane" },
	}),
	hiddenButtonStep({
		buttonName = "BuildButton_Crane",
		revealObjects = { "Crane" },
		revealButtons = { "BuildButton_Crusher" },
	}),
	hiddenButtonStep({
		buttonName = "BuildButton_Crusher",
		revealObjects = { "Crusher" },
		revealButtons = {},
	}),
	expansionStep(1, {
		buttonAliases = { "BuildButton_ExpandScrapyard", "BuildButton_Garden" },
		cost = 150,
		revealObjects = { "ScrapyardSlab_02", "ScrapyardFence_02", "ScrapyardPath_04", "ScrapyardPath_05", "ScrapyardPath_06" },
		hideDescendants = {
			{
				objectName = "ScrapyardFence_01",
				descendantNames = FENCE_01_EXPANSION_OPENING_PIECES,
			},
		},
		revealButtons = { "BuildButton_BrokenCar_04" },
	}),
	expansionStep(2, {
		cost = 500,
		revealObjects = { "ScrapyardSlab_03", "ScrapyardFence_03", "ScrapyardPath_07", "ScrapyardPath_08" },
		hideDescendants = {
			{
				objectName = "ScrapyardFence_02",
				parentFolderName = FENCES_FOLDER_NAME,
				expectedPath = "Workspace > Scrapyard > UnlockObjects > Fences > ScrapyardFence_02",
				descendantNames = FENCE_02_EXPANSION_OPENING_PIECES,
			},
		},
		revealButtons = { "BuildButton_BrokenCar_08" },
	}),
	hiddenButtonStep({
		buttonName = "BuildButton_Workbench",
		displayName = "Workbench",
		cost = 50,
		clearProductionAttributes = true,
		incomeMultiplier = 1.5,
		revealObjects = { "Workbench" },
		revealButtons = {},
	}),
	brokenCarStep(1, 15, { "BuildButton_BrokenCar_02", "BuildButton_Workbench" }),
	brokenCarStep(2, 23, { "BuildButton_BrokenCar_03" }),
	brokenCarStep(3, 34, { "BuildButton_ExpandScrapyard_01" }),
	brokenCarStep(4, 200, { "BuildButton_BrokenCar_05" }),
	brokenCarStep(5, 300, { "BuildButton_BrokenCar_06" }),
	brokenCarStep(6, 450, { "BuildButton_BrokenCar_07" }),
	brokenCarStep(7, 650, { "BuildButton_ExpandScrapyard_02" }),
	brokenCarStep(8, 950, { "BuildButton_BrokenCar_09" }),
	brokenCarStep(9, 1400, { "BuildButton_BrokenCar_10" }),
	brokenCarStep(10, 2100, { "BuildButton_BrokenCar_11" }),
	brokenCarStep(11, 3150, { "BuildButton_UnlockOperation" }),
}

local revealObjectAliases = {
	ScrapyardFence_01 = { "Fence" },
	ScrapyardSlab_02 = { "GardenSlab" },
}

local buttonsByName = {}
local purchasedButtons = {}
local unlockedButtons = {}
local touchDebounces = {}
local activePartsValue = nil
local lastClickByPlayer = {}
local taggedButtonsByName = {}
local updateButtonAffordability

local scrapyard = Workspace:FindFirstChild("Scrapyard") or Workspace:WaitForChild("Scrapyard", SCRAPYARD_LOOKUP_WAIT_SECONDS)
local buildButtons = scrapyard and (scrapyard:FindFirstChild(BUILD_BUTTONS_FOLDER_NAME) or scrapyard:WaitForChild(BUILD_BUTTONS_FOLDER_NAME, SCRAPYARD_LOOKUP_WAIT_SECONDS))
local hiddenButtons = scrapyard and (scrapyard:FindFirstChild(HIDDEN_BUTTONS_FOLDER_NAME) or scrapyard:WaitForChild(HIDDEN_BUTTONS_FOLDER_NAME, SCRAPYARD_LOOKUP_WAIT_SECONDS))
local unlockObjects = scrapyard and (scrapyard:FindFirstChild("UnlockObjects") or scrapyard:WaitForChild("UnlockObjects", SCRAPYARD_LOOKUP_WAIT_SECONDS))
local brokenCars = unlockObjects and (unlockObjects:FindFirstChild("BrokenCars") or unlockObjects:WaitForChild("BrokenCars", SCRAPYARD_LOOKUP_WAIT_SECONDS))
local remotesFolder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
if remotesFolder and not remotesFolder:IsA("Folder") then
	warn(string.format("%s ReplicatedStorage.%s exists but is not a Folder; insufficient Parts feedback remote will be created in ReplicatedStorage", DEBUG_PREFIX, REMOTES_FOLDER_NAME))
	remotesFolder = ReplicatedStorage
end
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = REMOTES_FOLDER_NAME
	remotesFolder.Parent = ReplicatedStorage
end

local function findRemoteEvent(parent, remoteName)
	for _, child in parent:GetChildren() do
		if child.Name == remoteName and child:IsA("RemoteEvent") then
			return child
		end
	end

	return nil
end

local insufficientPartsRemote = findRemoteEvent(remotesFolder, INSUFFICIENT_PARTS_REMOTE_NAME)
if remotesFolder:FindFirstChild(INSUFFICIENT_PARTS_REMOTE_NAME) and not insufficientPartsRemote then
	warn(string.format("%s %s.%s exists but is not a RemoteEvent; replacing feedback remote reference", DEBUG_PREFIX, remotesFolder:GetFullName(), INSUFFICIENT_PARTS_REMOTE_NAME))
end
if not insufficientPartsRemote then
	insufficientPartsRemote = Instance.new("RemoteEvent")
	insufficientPartsRemote.Name = INSUFFICIENT_PARTS_REMOTE_NAME
	insufficientPartsRemote.Parent = remotesFolder
end

if scrapyard and scrapyard:GetAttribute(CurrencyConfig.PartsIncomeMultiplierAttribute) == nil then
	scrapyard:SetAttribute(CurrencyConfig.PartsIncomeMultiplierAttribute, 1)
end

local function debugLog(message)
	if ENABLE_DEBUG_LOGS then
		print(string.format("%s %s", DEBUG_PREFIX, message))
	end
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

local function isExpectedButtonContainer(instance)
	return instance == buildButtons or instance == hiddenButtons
end

local function getExpectedButton(buttonName)
	return (buildButtons and buildButtons:FindFirstChild(buttonName)) or (hiddenButtons and hiddenButtons:FindFirstChild(buttonName))
end

local function findBuildStep(buttonName)
	for _, step in buildSteps do
		if step.buttonName == buttonName then
			return step
		end
	end

	return nil
end

local function getExpectedButtonForStep(step)
	local expectedButton = getExpectedButton(step.buttonName)
	if expectedButton then
		return expectedButton
	end

	for _, alias in step.buttonAliases or {} do
		local aliasButton = getExpectedButton(alias)
		if aliasButton then
			warn(string.format(
				"%s Found legacy button %s for %s. Rename it in Studio to %s when convenient.",
				DEBUG_PREFIX,
				aliasButton:GetFullName(),
				step.displayName or step.buttonName,
				step.buttonName
			))
			return aliasButton
		end
	end

	return nil
end

local function scanTaggedButtons()
	local taggedButtons = CollectionService:GetTagged("Button")
	debugLog(string.format("found %d tagged Button instances", #taggedButtons))

	for _, button in taggedButtons do
		if WorkspaceExclusions.IsExcluded(button) then
			continue
		end

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
		local expectedButton = getExpectedButtonForStep(step)
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
	if not root or WorkspaceExclusions.IsExcluded(root) then
		return nil
	end

	if root.Name == name then
		return root
	end

	for _, descendant in root:GetDescendants() do
		if descendant.Name == name and not WorkspaceExclusions.IsExcluded(descendant) then
			return descendant
		end
	end

	return nil
end

local function getDescendantsByName(root)
	local descendantsByName = {}
	if not root or WorkspaceExclusions.IsExcluded(root) then
		return descendantsByName
	end

	for _, descendant in root:GetDescendants() do
		if WorkspaceExclusions.IsExcluded(descendant) then
			continue
		end

		local matches = descendantsByName[descendant.Name]
		if not matches then
			matches = {}
			descendantsByName[descendant.Name] = matches
		end

		table.insert(matches, descendant)
	end

	return descendantsByName
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

local function refreshScrapyardReferences()
	if not scrapyard or not scrapyard.Parent then
		scrapyard = Workspace:FindFirstChild("Scrapyard") or Workspace:WaitForChild("Scrapyard", SCRAPYARD_LOOKUP_WAIT_SECONDS)
	end

	if scrapyard then
		if not buildButtons or not buildButtons.Parent then
			buildButtons = scrapyard:FindFirstChild(BUILD_BUTTONS_FOLDER_NAME) or scrapyard:WaitForChild(BUILD_BUTTONS_FOLDER_NAME, SCRAPYARD_LOOKUP_WAIT_SECONDS)
		end
		if not hiddenButtons or not hiddenButtons.Parent then
			hiddenButtons = scrapyard:FindFirstChild(HIDDEN_BUTTONS_FOLDER_NAME) or scrapyard:WaitForChild(HIDDEN_BUTTONS_FOLDER_NAME, SCRAPYARD_LOOKUP_WAIT_SECONDS)
		end
		if not unlockObjects or not unlockObjects.Parent then
			unlockObjects = scrapyard:FindFirstChild("UnlockObjects") or scrapyard:WaitForChild("UnlockObjects", SCRAPYARD_LOOKUP_WAIT_SECONDS)
		end
	end

	if unlockObjects and (not brokenCars or not brokenCars.Parent) then
		brokenCars = unlockObjects:FindFirstChild("BrokenCars") or unlockObjects:WaitForChild("BrokenCars", SCRAPYARD_LOOKUP_WAIT_SECONDS)
	end
end

local function getCurrentUnlockObjects()
	refreshScrapyardReferences()
	return unlockObjects
end

local function getPathsFolder()
	local currentUnlockObjects = getCurrentUnlockObjects()
	if not currentUnlockObjects then
		return nil
	end

	return currentUnlockObjects:FindFirstChild(PATHS_FOLDER_NAME) or currentUnlockObjects:WaitForChild(PATHS_FOLDER_NAME, SCRAPYARD_LOOKUP_WAIT_SECONDS)
end

local function getFencesFolder()
	local currentUnlockObjects = getCurrentUnlockObjects()
	if not currentUnlockObjects then
		return nil
	end

	return currentUnlockObjects:FindFirstChild(FENCES_FOLDER_NAME) or currentUnlockObjects:WaitForChild(FENCES_FOLDER_NAME, SCRAPYARD_LOOKUP_WAIT_SECONDS)
end

local function findUnlockObjectMatches(objectName)
	local matches = {}
	local currentUnlockObjects = getCurrentUnlockObjects()
	if not currentUnlockObjects then
		return matches
	end

	for _, descendant in currentUnlockObjects:GetDescendants() do
		if descendant.Name == objectName and not WorkspaceExclusions.IsExcluded(descendant) then
			table.insert(matches, descendant)
		end
	end

	return matches
end

local function getBuildButton(buttonName, buttonFolder)
	local button = taggedButtonsByName[buttonName]
	if button then
		return button
	end

	local step = findBuildStep(buttonName)
	for _, alias in (step and step.buttonAliases) or {} do
		local aliasButton = taggedButtonsByName[alias]
		if aliasButton then
			warn(string.format(
				"%s Using legacy tagged Button %s for %s. Rename it in Studio to %s when convenient.",
				DEBUG_PREFIX,
				aliasButton:GetFullName(),
				step.displayName or buttonName,
				buttonName
			))
			return aliasButton
		end
	end

	warn(string.format("%s Cannot set up %s because it is not tagged with exact CollectionService tag Button", DEBUG_PREFIX, buttonName))
	return nil
end

local function getRevealObject(objectName)
	refreshScrapyardReferences()

	if objectName == "Crane" or objectName == "Crusher" then
		return unlockObjects and unlockObjects:FindFirstChild(objectName)
	end

	if objectName:match("^BrokenCar_") then
		local brokenCar = brokenCars and brokenCars:FindFirstChild(objectName)
		if brokenCar then
			return brokenCar
		end

		local misplacedBrokenCar = unlockObjects and unlockObjects:FindFirstChild(objectName)
		if misplacedBrokenCar then
			warn(string.format(
				"%s Found %s directly under %s. Move it into Workspace > Scrapyard > UnlockObjects > BrokenCars in Studio so collector income can track it reliably.",
				DEBUG_PREFIX,
				objectName,
				unlockObjects:GetFullName()
			))
			return misplacedBrokenCar
		end

		return nil
	end

	local matches = findUnlockObjectMatches(objectName)

	if objectName:match("^ScrapyardPath_") then
		if #matches == 1 then
			return matches[1]
		elseif #matches == 0 then
			local pathsFolder = getPathsFolder()
			local childNames = {}
			if pathsFolder then
				for _, child in pathsFolder:GetChildren() do
					table.insert(childNames, string.format("%s (%s)", child.Name, child.ClassName))
				end
			end

			warn(string.format(
				"%s Missing expected ScrapyardPath %s under Workspace > Scrapyard > UnlockObjects. Children currently under Workspace > Scrapyard > UnlockObjects > Paths: %s",
				DEBUG_PREFIX,
				objectName,
				#childNames > 0 and table.concat(childNames, ", ") or "(none or Paths folder missing)"
			))
			return nil
		else
			local fullPaths = {}
			for _, match in matches do
				table.insert(fullPaths, match:GetFullName())
			end
			warn(string.format(
				"%s Expected unique ScrapyardPath %s but found %d matches under Workspace > Scrapyard > UnlockObjects; refusing to guess. Matches: %s",
				DEBUG_PREFIX,
				objectName,
				#matches,
				table.concat(fullPaths, " | ")
			))
			return nil
		end
	end

	if #matches == 1 then
		return matches[1]
	elseif #matches > 1 then
		warn(string.format(
			"%s Expected unique unlock object %s but found %d matches under %s; fix duplicates in Studio before progression can safely hide/reveal it",
			DEBUG_PREFIX,
			objectName,
			#matches,
			unlockObjects and unlockObjects:GetFullName() or "nil"
		))
		return nil
	end

	local misplacedMatches = {}
	if scrapyard then
		for _, descendant in scrapyard:GetDescendants() do
			if descendant.Name == objectName and (not unlockObjects or not descendant:IsDescendantOf(unlockObjects)) then
				table.insert(misplacedMatches, descendant)
			end
		end
	end

	if #misplacedMatches == 1 then
		warn(string.format(
			"%s Found %s outside Workspace > Scrapyard > UnlockObjects at %s; move it to %s when convenient",
			DEBUG_PREFIX,
			objectName,
			misplacedMatches[1]:GetFullName(),
			"Workspace > Scrapyard > UnlockObjects"
		))
		return misplacedMatches[1]
	elseif #misplacedMatches > 1 then
		warn(string.format(
			"%s Expected unique unlock object %s but found %d misplaced matches under Workspace.Scrapyard; fix duplicates in Studio before progression can safely hide/reveal it",
			DEBUG_PREFIX,
			objectName,
			#misplacedMatches
		))
		return nil
	end

	for _, alias in revealObjectAliases[objectName] or {} do
		local aliasObject = unlockObjects and unlockObjects:FindFirstChild(alias)
		if aliasObject then
			warn(string.format(
				"%s Found legacy unlock object %s for %s. Rename it in Studio to %s when convenient.",
				DEBUG_PREFIX,
				aliasObject:GetFullName(),
				objectName,
				objectName
			))
			return aliasObject
		end
	end

	return nil
end

local function getExpectedUnlockPath(objectName)
	if objectName:match("^BrokenCar_") then
		return string.format("Workspace > Scrapyard > UnlockObjects > BrokenCars > %s", objectName)
	end

	if objectName:match("^ScrapyardPath_") then
		return string.format("Workspace > Scrapyard > UnlockObjects > Paths > %s or Workspace > Scrapyard > UnlockObjects > %s", objectName, objectName)
	end

	if objectName:match("^ScrapyardFence_") then
		return string.format("Workspace > Scrapyard > UnlockObjects > Fences > %s or Workspace > Scrapyard > UnlockObjects > %s", objectName, objectName)
	end

	return string.format("Workspace > Scrapyard > UnlockObjects > %s", objectName)
end

local function countNamedDescendants(root, objectName)
	local count = 0
	if not root or WorkspaceExclusions.IsExcluded(root) then
		return count
	end

	for _, descendant in root:GetDescendants() do
		if descendant.Name == objectName and not WorkspaceExclusions.IsExcluded(descendant) then
			count += 1
		end
	end

	return count
end

local function getScrapyardPathChildrenSummary()
	local pathsFolder = getPathsFolder()
	if not pathsFolder then
		return "(Paths folder missing)"
	end

	local childNames = {}
	for _, child in pathsFolder:GetChildren() do
		table.insert(childNames, string.format("%s (%s)", child.Name, child.ClassName))
	end

	return #childNames > 0 and table.concat(childNames, ", ") or "(none)"
end

local function warnMissingScrapyardPath(pathName)
	warn(string.format(
		"%s Missing expected ScrapyardPath %s under Workspace > Scrapyard > UnlockObjects. Children currently under Workspace > Scrapyard > UnlockObjects > Paths: %s",
		DEBUG_PREFIX,
		pathName,
		getScrapyardPathChildrenSummary()
	))
end

local function warnDuplicateScrapyardPath(pathName, matches)
	local fullPaths = {}
	for _, match in matches do
		table.insert(fullPaths, match:GetFullName())
	end

	warn(string.format(
		"%s Expected unique ScrapyardPath %s but found %d matches under Workspace > Scrapyard > UnlockObjects; refusing to guess. Matches: %s",
		DEBUG_PREFIX,
		pathName,
		#matches,
		table.concat(fullPaths, " | ")
	))
end

local function warnDuplicateExpectedObjects()
	refreshScrapyardReferences()

	for _, step in buildSteps do
		local buttonCount = countNamedDescendants(scrapyard, step.buttonName)
		if buttonCount > 1 then
			warn(string.format("%s Expected unique button %s has %d matching descendants in Workspace.Scrapyard; fix duplicates in Studio", DEBUG_PREFIX, step.buttonName, buttonCount))
		end

		for _, objectName in step.revealObjects do
			if objectName:match("^ScrapyardPath_") then
				continue
			end

			local searchRoot = objectName:match("^BrokenCar_") and brokenCars or unlockObjects
			local objectCount = countNamedDescendants(searchRoot, objectName)
			if objectCount > 1 then
				warn(string.format("%s Expected unique unlock object %s has %d matching descendants under %s; fix duplicates in Studio", DEBUG_PREFIX, objectName, objectCount, searchRoot and searchRoot:GetFullName() or "nil"))
			end
		end
	end
end

local function validateUnlockObjectPlacement(objectName)
	if objectName:match("^ScrapyardPath_") then
		local pathMatches = findUnlockObjectMatches(objectName)
		if #pathMatches == 0 then
			warnMissingScrapyardPath(objectName)
		elseif #pathMatches > 1 then
			warnDuplicateScrapyardPath(objectName, pathMatches)
		end
		return
	end

	local objectCount = countNamedDescendants(unlockObjects, objectName)
	if objectCount == 0 then
		warnMissing(getExpectedUnlockPath(objectName))
	elseif objectCount > 1 then
		warn(string.format("%s Expected unique unlock object %s has %d matching descendants under %s; fix duplicates in Studio", DEBUG_PREFIX, objectName, objectCount, unlockObjects and unlockObjects:GetFullName() or "nil"))
	end

	if scrapyard then
		for _, descendant in scrapyard:GetDescendants() do
			if descendant.Name == objectName and unlockObjects and not descendant:IsDescendantOf(unlockObjects) then
				warn(string.format(
					"%s %s is outside Workspace > Scrapyard > UnlockObjects; move it there so progression visibility can manage it",
					DEBUG_PREFIX,
					descendant:GetFullName()
				))
			end
		end
	end
end

local function validateScrapyardLayoutObjectPlacement()
	for _, objectName in { "ScrapyardFence_01", "ScrapyardFence_02", "ScrapyardFence_03", "ScrapyardFence_04", "ScrapyardSlab_02", "ScrapyardSlab_03", "ScrapyardSlab_04" } do
		validateUnlockObjectPlacement(objectName)
	end

	for index = 1, 10 do
		validateUnlockObjectPlacement(string.format("ScrapyardPath_%02d", index))
	end
end

local function getOriginalBoolean(instance, attributeName, fallback)
	local originalValue = instance:GetAttribute(attributeName)
	if typeof(originalValue) == "boolean" then
		return originalValue
	end

	return fallback
end

local function getOriginalNumber(instance, attributeName, fallback)
	local originalValue = instance:GetAttribute(attributeName)
	if typeof(originalValue) == "number" then
		return originalValue
	end

	return fallback
end

local function validateExpansionBrokenCarButtonSetup()
	for index = 4, 11 do
		local buttonName = string.format("BuildButton_BrokenCar_%02d", index)
		local button = getExpectedButton(buttonName)
		if not button then
			warnMissing(string.format("Workspace > Scrapyard > HiddenButtons > %s", buttonName))
			continue
		end

		if not CollectionService:HasTag(button, "Button") then
			warn(string.format("%s %s must have exact CollectionService tag Button", DEBUG_PREFIX, button:GetFullName()))
		end

		local buttonPart = findDescendantByName(button, "ButtonPart")
		if not buttonPart or not buttonPart:IsA("BasePart") then
			warn(string.format("%s %s must contain a BasePart named ButtonPart for touch purchasing", DEBUG_PREFIX, button:GetFullName()))
		end

		local displayName = button:GetAttribute("DisplayName")
		if typeof(displayName) == "string" and displayName ~= "" and displayName ~= BROKEN_CAR_DISPLAY_NAME then
			warn(string.format(
				"%s %s has DisplayName=%s; expected Broken Car. If expansion buttons appear out of order, verify this Studio model is the numbered %s object.",
				DEBUG_PREFIX,
				button:GetFullName(),
				displayName,
				buttonName
			))
		end

		if button:GetAttribute("BuildCost") == nil then
			warn(string.format("%s %s missing BuildCost; prototype default will be seeded by setup", DEBUG_PREFIX, button:GetFullName()))
		end

		local sign = button:FindFirstChild(BUTTON_LABEL_SIGN_NAME)
		if sign and not sign:IsA("BasePart") then
			warn(string.format("%s %s has %s but it is not a BasePart", DEBUG_PREFIX, button:GetFullName(), BUTTON_LABEL_SIGN_NAME))
		end
	end
end

local function eachSelfAndDescendant(instance, callback)
	if WorkspaceExclusions.IsExcluded(instance) then
		return
	end

	callback(instance)

	for _, descendant in instance:GetDescendants() do
		if not WorkspaceExclusions.IsExcluded(descendant) then
			callback(descendant)
		end
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
	elseif instance:IsA("Beam")
		or instance:IsA("ParticleEmitter")
		or instance:IsA("Trail")
		or instance:IsA("Smoke")
		or instance:IsA("Fire")
		or instance:IsA("Sparkles")
		or instance:IsA("Light")
		or instance:IsA("Highlight")
	then
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
			if instance.Name == BUTTON_LABEL_SIGN_NAME or instance.Name == LEGACY_BUTTON_LABEL_ANCHOR_NAME then
				instance.Anchored = true
				instance.CanCollide = false
				instance.CanTouch = false
				instance.CanQuery = false
				instance.Transparency = 1
				instance.LocalTransparencyModifier = 1
				return
			end

			if hidden then
				instance.Transparency = 1
				instance.LocalTransparencyModifier = 1
				instance.CanCollide = false
				instance.CanTouch = false
				instance.CanQuery = false
			else
				instance.Transparency = getOriginalNumber(instance, "OriginalTransparency", instance.Transparency)
				instance.LocalTransparencyModifier = 0
				instance.CanCollide = getOriginalBoolean(instance, "OriginalCanCollide", instance.CanCollide)
				instance.CanTouch = getOriginalBoolean(instance, "OriginalCanTouch", instance.CanTouch)
				instance.CanQuery = getOriginalBoolean(instance, "OriginalCanQuery", instance.CanQuery)
			end
		elseif instance:IsA("Decal") or instance:IsA("Texture") then
			instance.Transparency = hidden and 1 or getOriginalNumber(instance, "OriginalTransparency", instance.Transparency)
		elseif instance:IsA("SurfaceGui") or instance:IsA("BillboardGui") then
			instance.Enabled = hidden and false or (instance:GetAttribute("OriginalEnabled") ~= false)
		elseif instance:IsA("Beam")
			or instance:IsA("ParticleEmitter")
			or instance:IsA("Trail")
			or instance:IsA("Smoke")
			or instance:IsA("Fire")
			or instance:IsA("Sparkles")
			or instance:IsA("Light")
			or instance:IsA("Highlight")
		then
			instance.Enabled = hidden and false or (instance:GetAttribute("OriginalEnabled") ~= false)
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

local function getButtonPart(button)
	local buttonPart = findDescendantByName(button, "ButtonPart")
	if buttonPart and buttonPart:IsA("BasePart") then
		return buttonPart
	end

	return nil
end

local function configureButtonLabelSign(sign)
	sign.Name = BUTTON_LABEL_SIGN_NAME
	sign.Anchored = true
	sign.CanCollide = false
	sign.CanTouch = false
	sign.CanQuery = false
	sign.CastShadow = false
	sign.Color = Color3.fromRGB(23, 28, 34)
	sign.Locked = true
	sign.Material = Enum.Material.SmoothPlastic
	sign.Size = Vector3.new(4.05, 1.45, 0.08)
	sign.Transparency = 0.25
	sign.LocalTransparencyModifier = 0

	if not CollectionService:HasTag(sign, BUTTON_LABEL_SIGN_TAG) then
		CollectionService:AddTag(sign, BUTTON_LABEL_SIGN_TAG)
	end
end

local function getLabelLookTarget(position)
	local spawnLocation = nil
	for _, child in Workspace:GetChildren() do
		if WorkspaceExclusions.IsExcluded(child) then
			continue
		end

		if child:IsA("SpawnLocation") then
			spawnLocation = child
		else
			spawnLocation = child:FindFirstChildWhichIsA("SpawnLocation", true)
		end
		if spawnLocation then
			break
		end
	end
	local targetPosition = spawnLocation and spawnLocation.Position or Vector3.zero
	targetPosition = Vector3.new(targetPosition.X, position.Y, targetPosition.Z)

	if (targetPosition - position).Magnitude < 0.1 then
		targetPosition = position + Vector3.new(0, 0, -1)
	end

	return targetPosition
end

local function cleanupLegacyButtonLabels(button)
	for _, descendant in button:GetDescendants() do
		if descendant.Name == BUTTON_LABEL_NAME and (descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui")) then
			descendant:Destroy()
		elseif descendant.Name == LEGACY_BUTTON_LABEL_ANCHOR_NAME then
			descendant:Destroy()
		end
	end
end

local function updateButtonLabelSign(button)
	local sign = button:FindFirstChild(BUTTON_LABEL_SIGN_NAME)
	if not sign or not sign:IsA("BasePart") then
		if sign then
			sign:Destroy()
		end

		sign = Instance.new("Part")
	end

	configureButtonLabelSign(sign)

	if sign.Parent == button then
		sign.Parent = nil
	end

	local boundingCFrame, boundingSize = button:GetBoundingBox()
	local boundingCenter = boundingCFrame.Position
	local signPosition = Vector3.new(
		boundingCenter.X,
		boundingCenter.Y + (boundingSize.Y / 2) + 2.25,
		boundingCenter.Z
	)

	sign.CFrame = CFrame.lookAt(signPosition, getLabelLookTarget(signPosition))
	sign.Parent = button

	return sign
end

local function disconnectButtonLabel(button)
	local connections = buttonLabelConnections[button]
	if not connections then
		return
	end

	for _, connection in connections do
		connection:Disconnect()
	end
	buttonLabelConnections[button] = nil
end

local function prettifyButtonName(buttonName)
	local displayName = buttonName:gsub("^BuildButton_", ""):gsub("(%l)(%u)", "%1 %2"):gsub("_", " ")
	displayName = displayName:gsub("(%a)(%w*)", function(first, rest)
		return first:upper() .. rest:lower()
	end)

	return displayName
end

local function getButtonDisplayName(button)
	local displayName = button:GetAttribute("DisplayName")
	if typeof(displayName) == "string" and displayName ~= "" then
		return displayName
	end

	return prettifyButtonName(button.Name)
end

local function getButtonBuildCost(button)
	local attributeCost = button:GetAttribute("BuildCost")
	if typeof(attributeCost) == "number" then
		return attributeCost
	end

	local buildCostValue = button:FindFirstChild("BuildCost")
	if buildCostValue and buildCostValue:IsA("ValueBase") then
		return buildCostValue.Value
	end

	return nil
end

local function getButtonPartsPerSecond(button)
	local partsPerSecond = button:GetAttribute("ProducesPartsPerSecond")
	if typeof(partsPerSecond) == "number" then
		return partsPerSecond
	end

	partsPerSecond = button:GetAttribute("PartsPerSecond")
	if typeof(partsPerSecond) == "number" then
		return partsPerSecond
	end

	return 0
end

local function getButtonIncomeMultiplier(button)
	local multiplier = button:GetAttribute(CurrencyConfig.PartsIncomeMultiplierAttribute)
	if typeof(multiplier) == "number" then
		return multiplier
	end

	return 1
end

local function formatWholeNumber(value)
	return string.format("%d", math.floor(value))
end

local function formatButtonBuildCost(cost)
	if typeof(cost) ~= "number" then
		return "Cost: ? Parts"
	end

	return string.format("Cost: %s Parts", formatWholeNumber(cost))
end

local function findButtonLabelText(labelGui, textName)
	local textLabel = labelGui:FindFirstChild(textName, true)
	return textLabel and textLabel:IsA("TextLabel") and textLabel or nil
end

local function getButtonLabelGuis(button)
	local sign = button:FindFirstChild(BUTTON_LABEL_SIGN_NAME)
	if not sign then
		return {}
	end

	local labels = {}
	for _, child in sign:GetChildren() do
		if child.Name == BUTTON_LABEL_NAME and child:IsA("SurfaceGui") then
			table.insert(labels, child)
		end
	end

	return labels
end

local function isButtonPartVisibleAndInteractable(touchPart)
	return touchPart:IsDescendantOf(Workspace)
		and touchPart.Transparency < 1
		and touchPart.LocalTransparencyModifier < 1
		and touchPart.CanTouch
		and touchPart.CanQuery
end

local function updateButtonLabelVisibility(button)
	local touchPart = getButtonPart(button)
	if button:IsA("Model") then
		updateButtonLabelSign(button)
	end

	local labelGuis = getButtonLabelGuis(button)
	if not touchPart then
		return
	end

	local isVisible = isButtonPartVisibleAndInteractable(touchPart)
	local sign = button:FindFirstChild(BUTTON_LABEL_SIGN_NAME)
	if sign and sign:IsA("BasePart") then
		sign.Transparency = isVisible and 0.25 or 1
		sign.LocalTransparencyModifier = isVisible and 0 or 1
	end

	for _, labelGui in labelGuis do
		labelGui.Enabled = isVisible
	end
end

local function updateButtonLabelText(button)
	local labelGuis = getButtonLabelGuis(button)
	if #labelGuis == 0 then
		return
	end

	for _, labelGui in labelGuis do
		local title = findButtonLabelText(labelGui, "BuildName")
		if title then
			title.Text = getButtonDisplayName(button)
		end

		local production = findButtonLabelText(labelGui, "Production")
		if production then
			local partsPerSecond = getButtonPartsPerSecond(button)
			if partsPerSecond > 0 then
				production.Visible = true
				production.Text = string.format("Production: +%s parts/sec", formatWholeNumber(partsPerSecond))
			else
				local incomeMultiplier = getButtonIncomeMultiplier(button)
				production.Visible = incomeMultiplier > 1
				if incomeMultiplier > 1 then
					production.Text = string.format("Production: x%.1f parts", incomeMultiplier)
				end
			end
		end

		local cost = findButtonLabelText(labelGui, "BuildCost")
		if cost then
			cost.Text = formatButtonBuildCost(getButtonBuildCost(button))
		end
	end

	updateButtonLabelVisibility(button)
end

local function createButtonLabelSurface(sign, face)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = BUTTON_LABEL_NAME
	surfaceGui.Adornee = sign
	surfaceGui.AlwaysOnTop = false
	surfaceGui.Face = face
	surfaceGui.LightInfluence = 0
	surfaceGui.PixelsPerStud = 80
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.Parent = sign

	local panel = Instance.new("Frame")
	panel.Name = BUTTON_PANEL_NAME
	panel.BackgroundColor3 = Color3.fromRGB(23, 28, 34)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Size = UDim2.fromScale(1, 1)
	panel.Parent = surfaceGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = BUTTON_COLORS.CannotAfford
	stroke.Thickness = BUTTON_PANEL_BORDER_THICKNESS
	stroke.Transparency = 0.15
	stroke.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 10)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "BuildName"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, 44)
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0.25
	title.TextWrapped = true
	title.Parent = panel

	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MaxTextSize = 34
	titleSize.MinTextSize = 14
	titleSize.Parent = title

	local production = Instance.new("TextLabel")
	production.Name = "Production"
	production.BackgroundTransparency = 1
	production.Font = Enum.Font.GothamBold
	production.LayoutOrder = 2
	production.Size = UDim2.new(1, 0, 0, 26)
	production.TextColor3 = Color3.fromRGB(190, 255, 150)
	production.TextScaled = true
	production.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	production.TextStrokeTransparency = 0.4
	production.TextWrapped = true
	production.Visible = false
	production.Parent = panel

	local productionSize = Instance.new("UITextSizeConstraint")
	productionSize.MaxTextSize = 20
	productionSize.MinTextSize = 10
	productionSize.Parent = production

	local cost = Instance.new("TextLabel")
	cost.Name = "BuildCost"
	cost.BackgroundTransparency = 1
	cost.Font = Enum.Font.GothamBold
	cost.LayoutOrder = 3
	cost.Size = UDim2.new(1, 0, 0, 28)
	cost.TextColor3 = Color3.fromRGB(255, 230, 126)
	cost.TextScaled = true
	cost.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	cost.TextStrokeTransparency = 0.35
	cost.TextWrapped = true
	cost.Parent = panel

	local costSize = Instance.new("UITextSizeConstraint")
	costSize.MaxTextSize = 24
	costSize.MinTextSize = 12
	costSize.Parent = cost

	return surfaceGui
end

local function createButtonLabel(button)
	cleanupLegacyButtonLabels(button)
	local sign = updateButtonLabelSign(button)

	for _, child in sign:GetChildren() do
		if child.Name == BUTTON_LABEL_NAME and (child:IsA("BillboardGui") or child:IsA("SurfaceGui")) then
			child:Destroy()
		end
	end

	createButtonLabelSurface(sign, Enum.NormalId.Front)
	createButtonLabelSurface(sign, Enum.NormalId.Back)

	updateButtonLabelText(button)
end

local function setupButtonLabel(button)
	if WorkspaceExclusions.IsExcluded(button)
		or not button:IsA("Model")
		or not CollectionService:HasTag(button, "Button")
	then
		return
	end

	local touchPart = getButtonPart(button)
	if not touchPart then
		warn(string.format("%s Tagged Button model has no ButtonPart for label: %s", DEBUG_PREFIX, button:GetFullName()))
		return
	end

	disconnectButtonLabel(button)
	createButtonLabel(button)

	local connections = {
		button:GetAttributeChangedSignal("DisplayName"):Connect(function()
			updateButtonLabelText(button)
		end),
		button:GetAttributeChangedSignal("BuildCost"):Connect(function()
			updateButtonLabelText(button)
		end),
		button:GetAttributeChangedSignal("ProducesPartsPerSecond"):Connect(function()
			updateButtonLabelText(button)
		end),
		button:GetAttributeChangedSignal("PartsPerSecond"):Connect(function()
			updateButtonLabelText(button)
		end),
		button:GetAttributeChangedSignal(CurrencyConfig.PartsIncomeMultiplierAttribute):Connect(function()
			updateButtonLabelText(button)
		end),
		touchPart:GetPropertyChangedSignal("Transparency"):Connect(function()
			updateButtonLabelVisibility(button)
		end),
		touchPart:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
			updateButtonLabelVisibility(button)
		end),
		touchPart:GetPropertyChangedSignal("CanTouch"):Connect(function()
			updateButtonLabelVisibility(button)
		end),
		touchPart:GetPropertyChangedSignal("CanQuery"):Connect(function()
			updateButtonLabelVisibility(button)
		end),
		touchPart:GetPropertyChangedSignal("CFrame"):Connect(function()
			updateButtonLabelVisibility(button)
		end),
		touchPart:GetPropertyChangedSignal("Size"):Connect(function()
			updateButtonLabelSign(button)
			updateButtonLabelVisibility(button)
		end),
		button.AncestryChanged:Connect(function(_, parent)
			if not parent then
				disconnectButtonLabel(button)
			else
				updateButtonLabelSign(button)
				updateButtonLabelVisibility(button)
			end
		end),
		button.ChildAdded:Connect(function(child)
			if child.Name == "BuildCost" and child:IsA("ValueBase") then
				setupButtonLabel(button)
			end
		end),
		button.ChildRemoved:Connect(function(child)
			if child.Name == "BuildCost" then
				updateButtonLabelText(button)
			end
		end),
	}

	local buildCostValue = button:FindFirstChild("BuildCost")
	if buildCostValue and buildCostValue:IsA("ValueBase") then
		table.insert(connections, buildCostValue:GetPropertyChangedSignal("Value"):Connect(function()
			updateButtonLabelText(button)
		end))
	end

	buttonLabelConnections[button] = connections
end

local function setupTaggedButtonLabels()
	for _, button in CollectionService:GetTagged("Button") do
		if not WorkspaceExclusions.IsExcluded(button) then
			setupButtonLabel(button)
		end
	end

	CollectionService:GetInstanceAddedSignal("Button"):Connect(function(button)
		if WorkspaceExclusions.IsExcluded(button) then
			return
		end

		task.defer(function()
			setupButtonLabel(button)
			updateButtonAffordability()
		end)
	end)

	CollectionService:GetInstanceRemovedSignal("Button"):Connect(function(button)
		disconnectButtonLabel(button)
	end)

	updateButtonAffordability()
end

local function setButtonPanelBorderColor(button, color)
	for _, labelGui in getButtonLabelGuis(button) do
		local panel = labelGui:FindFirstChild(BUTTON_PANEL_NAME)
		local stroke = panel and panel:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			stroke.Color = color
		end
	end
end

local function setButtonColor(button, color)
	if not button then
		return
	end

	eachSelfAndDescendant(button, function(instance)
		if instance:IsA("BasePart") and instance.Name ~= BUTTON_LABEL_SIGN_NAME then
			instance.Color = color
			instance.Material = Enum.Material.Neon
		end
	end)

	setButtonPanelBorderColor(button, color)
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

updateButtonAffordability = function()
	local partsValue = activePartsValue and activePartsValue.Value or 0
	local configuredButtons = {}

	for _, step in buildSteps do
		local button = buttonsByName[step.buttonName]
		if button and not purchasedButtons[step.buttonName] then
			configuredButtons[button] = true
			local cost = FREE_BUILD_TESTING and 0 or (button:GetAttribute("BuildCost") or step.cost)
			if typeof(cost) == "number" and partsValue >= cost then
				setButtonColor(button, BUTTON_COLORS.CanAfford)
			else
				setButtonColor(button, BUTTON_COLORS.CannotAfford)
			end
		end
	end

	for _, button in CollectionService:GetTagged("Button") do
		if not WorkspaceExclusions.IsExcluded(button)
			and not configuredButtons[button]
			and button:GetAttribute("Purchased") ~= true
		then
			local cost = FREE_BUILD_TESTING and 0 or getButtonBuildCost(button)
			if typeof(cost) == "number" and partsValue >= cost then
				setButtonPanelBorderColor(button, BUTTON_COLORS.CanAfford)
			else
				setButtonPanelBorderColor(button, BUTTON_COLORS.CannotAfford)
			end
		end
	end

end

local function revealObject(objectName)
	debugLog(string.format("reveal called for %s", objectName))

	local object = getRevealObject(objectName)
	if not object then
		if not objectName:match("^ScrapyardPath_") then
			warnMissing(getExpectedUnlockPath(objectName))
		end
		return
	end

	local processed = setObjectHidden(object, false)
	debugLog(string.format("reveal processed %d descendants for %s", processed, objectName))

	if objectName:match("^BrokenCar_") and BrokenCarProduction.PartsPerSecondByName[objectName] then
		object:SetAttribute("CollectorActive", true)
		debugLog(string.format("%s marked CollectorActive for Parts collector income", objectName))
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
	updateButtonAffordability()
	updateButtonLabelVisibility(button)
	debugLog(string.format("revealed button %s; processed %d descendants", buttonName, processed))
end

local function hidePurchasedButton(button, buttonName)
	purchasedButtons[buttonName] = true
	unlockedButtons[buttonName] = false
	button:SetAttribute("Purchased", true)
	disableButtonPrompts(button)
	setButtonColor(button, BUTTON_COLORS.Purchased)
	setObjectHidden(button, true)
	updateButtonLabelVisibility(button)
end

local function hideNamedUnlockDescendants(step)
	for _, hideConfig in step.hideDescendants or {} do
		local object = nil
		if hideConfig.parentFolderName == FENCES_FOLDER_NAME then
			local fencesFolder = getFencesFolder()
			object = findDescendantByName(fencesFolder, hideConfig.objectName)
		else
			object = getRevealObject(hideConfig.objectName)
		end

		if not object then
			warnMissing(hideConfig.expectedPath or getExpectedUnlockPath(hideConfig.objectName))
			continue
		end

		local descendantsByName = getDescendantsByName(object)
		for _, descendantName in hideConfig.descendantNames or {} do
			local matchingDescendants = descendantsByName[descendantName] or {}
			if #matchingDescendants == 1 then
				local descendant = matchingDescendants[1]
				local processed = setObjectHidden(descendant, true)
				debugLog(string.format("hid %s descendant %s; processed %d descendants", hideConfig.objectName, descendantName, processed))
			elseif #matchingDescendants > 1 then
				local fullPaths = {}
				for _, matchingDescendant in matchingDescendants do
					table.insert(fullPaths, matchingDescendant:GetFullName())
				end
				warn(string.format(
					"%s Expected unique expansion opening piece %s under %s but found %d matches; refusing to guess. Matches: %s",
					DEBUG_PREFIX,
					descendantName,
					hideConfig.expectedPath or object:GetFullName(),
					#matchingDescendants,
					table.concat(fullPaths, " | ")
				))
			else
				warn(string.format("%s Missing expansion opening piece %s under %s", DEBUG_PREFIX, descendantName, hideConfig.expectedPath or object:GetFullName()))
			end
		end
	end
end

local function showInsufficientPartsFeedback(player, failedCost)
	insufficientPartsRemote:FireClient(player, failedCost)
end

local function purchaseBuildStep(player, step)
	debugLog(string.format("purchase attempt for %s by %s", step.buttonName, player.Name))

	local parts = getParts(player)
	local button = buttonsByName[step.buttonName]
	if not parts or not button or purchasedButtons[step.buttonName] or not unlockedButtons[step.buttonName] then
		return
	end

	local cost = FREE_BUILD_TESTING and 0 or (button:GetAttribute("BuildCost") or step.cost)
	if typeof(cost) ~= "number" then
		warn(string.format("%s %s has nonnumeric BuildCost; purchase blocked", DEBUG_PREFIX, step.buttonName))
		showInsufficientPartsFeedback(player, nil)
		updateButtonAffordability()
		return
	end

	if parts.Value < cost then
		debugLog(string.format("touch unaffordable: %s touched %s with %s Parts; needs %s", player.Name, step.buttonName, formatWholeNumber(parts.Value), formatWholeNumber(cost)))
		showInsufficientPartsFeedback(player, cost)
		updateButtonAffordability()
		return
	end

	debugLog(string.format("purchase success: %s bought %s for %s Parts", player.Name, step.buttonName, formatWholeNumber(cost)))
	parts.Value -= cost
	hidePurchasedButton(button, step.buttonName)

	for _, objectName in step.revealObjects do
		revealObject(objectName)
	end

	hideNamedUnlockDescendants(step)

	for _, buttonName in step.revealButtons do
		revealButton(buttonName)
	end

	if step.incomeMultiplier and scrapyard then
		scrapyard:SetAttribute(CurrencyConfig.PartsIncomeMultiplierAttribute, step.incomeMultiplier)
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

local function warnStudioAttributeMismatch(button, attributeName, expectedValue)
	local actualValue = button:GetAttribute(attributeName)
	if actualValue ~= nil and actualValue ~= expectedValue then
		warn(string.format(
			"%s %s has %s=%s; expected %s. Update this attribute manually in Studio if the player-facing value should match the current config.",
			DEBUG_PREFIX,
			button:GetFullName(),
			attributeName,
			tostring(actualValue),
			tostring(expectedValue)
		))
	end
end

local function isBrokenCarButtonName(buttonName)
	return buttonName:match("^BuildButton_BrokenCar_") ~= nil
end

local function isExpansionButtonName(buttonName)
	return buttonName:match("^BuildButton_ExpandScrapyard_") ~= nil
end

local function normalizeBrokenCarDisplayName(button, step)
	if not isBrokenCarButtonName(step.buttonName) then
		return
	end

	local displayName = button:GetAttribute("DisplayName")
	if displayName ~= BROKEN_CAR_DISPLAY_NAME then
		if displayName ~= nil then
			warn(string.format(
				"%s %s has BrokenCar DisplayName=%s; updating button panel label to Broken Car per progression naming rule.",
				DEBUG_PREFIX,
				button:GetFullName(),
				tostring(displayName)
			))
		end
		button:SetAttribute("DisplayName", BROKEN_CAR_DISPLAY_NAME)
	end
end

local function updateLegacyExpansionDisplayName(button, step)
	local displayName = button:GetAttribute("DisplayName")
	if displayName == "Unlock Garden" then
		warn(string.format(
			"%s %s has legacy DisplayName='Unlock Garden'; updating to %s for the scrapyard expansion rename.",
			DEBUG_PREFIX,
			button:GetFullName(),
			step.displayName
		))
		button:SetAttribute("DisplayName", step.displayName)
	end
end

local function setupBuildButton(step)
	local button = getBuildButton(step.buttonName, step.buttonFolder)
	if not button then
		return
	end

	buttonsByName[step.buttonName] = button
	if button:GetAttribute("BuildCost") == nil and step.cost ~= nil then
		button:SetAttribute("BuildCost", step.cost)
	end
	if step.displayName and button:GetAttribute("DisplayName") == nil then
		button:SetAttribute("DisplayName", isBrokenCarButtonName(step.buttonName) and BROKEN_CAR_DISPLAY_NAME or step.displayName)
	end
	normalizeBrokenCarDisplayName(button, step)
	if isExpansionButtonName(step.buttonName) then
		updateLegacyExpansionDisplayName(button, step)
		warnStudioAttributeMismatch(button, "DisplayName", step.displayName)
	end
	if step.clearProductionAttributes then
		button:SetAttribute("ProducesPartsPerSecond", nil)
		button:SetAttribute("PartsPerSecond", nil)
		button:SetAttribute(CurrencyConfig.PartsIncomeMultiplierAttribute, nil)
	end
	if step.incomeMultiplier then
		button:SetAttribute(CurrencyConfig.PartsIncomeMultiplierAttribute, step.incomeMultiplier)
	end
	if step.producesPartsPerSecond then
		button:SetAttribute("ProducesPartsPerSecond", step.producesPartsPerSecond)
		button:SetAttribute("PartsPerSecond", nil)
	end
	updateButtonLabelText(button)
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
	for _, taggedObject in taggedObjects do
		if not WorkspaceExclusions.IsExcluded(taggedObject) then
			return findAncestorByName(taggedObject, "CarPile_Clickable") or taggedObject
		end
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

local function showPartRewardText(carPile, reward)
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
	label.Text = string.format("+%s Part%s", formatWholeNumber(reward), reward == 1 and "" or "s")
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

local function getPartsIncomeMultiplier()
	refreshScrapyardReferences()

	local multiplier = scrapyard and scrapyard:GetAttribute(CurrencyConfig.PartsIncomeMultiplierAttribute)
	if typeof(multiplier) == "number" and multiplier > 0 then
		return multiplier
	end

	return 1
end

local function getCarPileClickReward(player)
	local rawReward = PART_CLICK_REWARD * getPartsIncomeMultiplier()
	local remainderAttributeName = "CarPileClickPartsRemainder"
	local remainder = player:GetAttribute(remainderAttributeName)
	if typeof(remainder) ~= "number" then
		remainder = 0
	end

	local rawRewardWithRemainder = rawReward + remainder
	local wholeReward = math.floor(rawRewardWithRemainder)
	player:SetAttribute(remainderAttributeName, rawRewardWithRemainder - wholeReward)

	return wholeReward
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

		local reward = getCarPileClickReward(player)
		if reward > 0 then
			parts.Value += reward
		end
		bounceCarPile(carPile)
		showPartRewardText(carPile, reward)
		updateButtonAffordability()
	end)
end

local function hideInitialObject(objectName)
	local object = getRevealObject(objectName)
	if not object then
		if not objectName:match("^ScrapyardPath_") then
			warnMissing(getExpectedUnlockPath(objectName))
		end
		return
	end

	local processed = setObjectHidden(object, true)
	if objectName:match("^BrokenCar_") and BrokenCarProduction.PartsPerSecondByName[objectName] then
		object:SetAttribute("CollectorActive", false)
	end
	debugLog(string.format("initial hide processed %d descendants for %s", processed, objectName))
end

local function hideInitialButton(buttonName, options)
	local button = buttonsByName[buttonName]
	if not button then
		local step = findBuildStep(buttonName)
		button = step and getExpectedButtonForStep(step)
		if button then
			if not (options and options.suppressSetupWarning) then
				warn(string.format("%s %s was not fully set up as a tagged build button, but will still be hidden at startup", DEBUG_PREFIX, button:GetFullName()))
			end
		else
			warnMissing(string.format("Workspace > Scrapyard > HiddenButtons > %s", buttonName))
			return
		end
	end

	local processed = setObjectHidden(button, true)
	disableButtonPrompts(button)
	unlockedButtons[buttonName] = false
	updateButtonLabelVisibility(button)
	debugLog(string.format("initial hide processed %d descendants for %s", processed, buttonName))
end

local function setupBuildButtons()
	for _, step in buildSteps do
		if step.buttonFolder == HIDDEN_BUTTONS_FOLDER_NAME then
			hideInitialButton(step.buttonName, { suppressSetupWarning = true })
		end
	end

	for _, step in buildSteps do
		setupBuildButton(step)
	end

	for _, step in buildSteps do
		if step.buttonFolder == HIDDEN_BUTTONS_FOLDER_NAME then
			hideInitialButton(step.buttonName)
		end
	end

	local firstButton = buttonsByName.BuildButton_UnlockScrapyard
	if firstButton then
		setObjectHidden(firstButton, false)
		disableButtonPrompts(firstButton)
		unlockedButtons.BuildButton_UnlockScrapyard = true
		updateButtonLabelVisibility(firstButton)
	end
end

local function hideInitialScrapyardObjects()
	local hiddenObjects = {}
	for _, step in buildSteps do
		for _, objectName in step.revealObjects do
			if not hiddenObjects[objectName] then
				hiddenObjects[objectName] = true
				hideInitialObject(objectName)
			end
		end
	end

	for _, futureObjectName in { "ScrapyardSlab_04" } do
		if not hiddenObjects[futureObjectName] then
			hiddenObjects[futureObjectName] = true
			hideInitialObject(futureObjectName)
		end
	end
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
warnDuplicateExpectedObjects()
validateScrapyardLayoutObjectPlacement()
validateExpansionBrokenCarButtonSetup()
hideInitialScrapyardObjects()
setupBuildButtons()
setupTaggedButtonLabels()
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
