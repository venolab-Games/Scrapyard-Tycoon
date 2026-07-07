-- One-time Studio helper.
-- Run once in Studio, then remove the temporary Script/Command Bar contents after verifying.
-- This clones Workspace.Scrapyard.UnlockObjects.ScrapyardFence_01 into ScrapyardFence_02.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local DEBUG_PREFIX = "[CreateScrapyardFence02]"
local SOURCE_NAME = "ScrapyardFence_01"
local TARGET_NAME = "ScrapyardFence_02"

local PIECES_TO_REMOVE = {
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

local function getUnlockObjects()
	local scrapyard = Workspace:FindFirstChild("Scrapyard")
	if not scrapyard then
		error(string.format("%s Missing Workspace.Scrapyard", DEBUG_PREFIX))
	end

	local unlockObjects = scrapyard:FindFirstChild("UnlockObjects")
	if not unlockObjects then
		error(string.format("%s Missing Workspace.Scrapyard.UnlockObjects", DEBUG_PREFIX))
	end

	return unlockObjects
end

local function copyTags(source, clone)
	for _, tag in CollectionService:GetTags(source) do
		if not CollectionService:HasTag(clone, tag) then
			CollectionService:AddTag(clone, tag)
		end
	end
end

local function copyDescendantTags(sourceRoot, cloneRoot)
	local sourceDescendants = sourceRoot:GetDescendants()
	local cloneDescendants = cloneRoot:GetDescendants()

	for index, sourceDescendant in sourceDescendants do
		local cloneDescendant = cloneDescendants[index]
		if cloneDescendant and cloneDescendant.Name == sourceDescendant.Name then
			copyTags(sourceDescendant, cloneDescendant)
		end
	end
end

local function pivotObject(object, targetPivot)
	if object:IsA("Model") then
		object:PivotTo(targetPivot)
	elseif object:IsA("BasePart") then
		object.CFrame = targetPivot
	else
		error(string.format("%s %s must be a Model or BasePart", DEBUG_PREFIX, object:GetFullName()))
	end
end

local function getObjectPivot(object)
	if object:IsA("Model") then
		return object:GetPivot()
	elseif object:IsA("BasePart") then
		return object.CFrame
	end

	error(string.format("%s %s must be a Model or BasePart", DEBUG_PREFIX, object:GetFullName()))
end

local function getObjectSize(object)
	if object:IsA("Model") then
		local _, size = object:GetBoundingBox()
		return size
	elseif object:IsA("BasePart") then
		return object.Size
	end

	error(string.format("%s %s must be a Model or BasePart", DEBUG_PREFIX, object:GetFullName()))
end

local unlockObjects = getUnlockObjects()
local source = unlockObjects:FindFirstChild(SOURCE_NAME)
if not source then
	error(string.format("%s Missing %s.%s", DEBUG_PREFIX, unlockObjects:GetFullName(), SOURCE_NAME))
end

if unlockObjects:FindFirstChild(TARGET_NAME) then
	warn(string.format("%s %s already exists; stopping without duplicating", DEBUG_PREFIX, TARGET_NAME))
else
	local clone = source:Clone()
	clone.Name = TARGET_NAME
	clone.Parent = unlockObjects
	copyTags(source, clone)
	copyDescendantTags(source, clone)

	local sourcePivot = getObjectPivot(source)
	local sourceSize = getObjectSize(source)
	local leftOffset = -sourcePivot.RightVector * sourceSize.X
	pivotObject(clone, sourcePivot + leftOffset)

	for _, pieceName in PIECES_TO_REMOVE do
		local piece = clone:FindFirstChild(pieceName, true)
		if piece then
			piece:Destroy()
		else
			warn(string.format("%s %s missing from %s; continuing", DEBUG_PREFIX, pieceName, TARGET_NAME))
		end
	end

	print(string.format(
		"%s Created %s under %s, shifted left by %.2f studs, and removed %d requested piece names from the clone only.",
		DEBUG_PREFIX,
		TARGET_NAME,
		unlockObjects:GetFullName(),
		sourceSize.X,
		#PIECES_TO_REMOVE
	))
end
