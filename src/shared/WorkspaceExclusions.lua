local Workspace = game:GetService("Workspace")

local WorkspaceExclusions = {}

function WorkspaceExclusions.IsExcluded(instance)
	if not instance then
		return false
	end

	local tempScrapyard = Workspace:FindFirstChild("TEMPScrapyard")
	return tempScrapyard ~= nil
		and (instance == tempScrapyard or instance:IsDescendantOf(tempScrapyard))
end

return table.freeze(WorkspaceExclusions)
