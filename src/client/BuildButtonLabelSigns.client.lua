local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SIGN_TAG = "BuildButtonLabelSign"

local trackedSigns = {}

local function trackSign(sign)
	if sign:IsA("BasePart") then
		trackedSigns[sign] = true
	end
end

local function untrackSign(sign)
	trackedSigns[sign] = nil
end

for _, sign in CollectionService:GetTagged(SIGN_TAG) do
	trackSign(sign)
end

CollectionService:GetInstanceAddedSignal(SIGN_TAG):Connect(trackSign)
CollectionService:GetInstanceRemovedSignal(SIGN_TAG):Connect(untrackSign)

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local cameraPosition = camera.CFrame.Position
	for sign in trackedSigns do
		if not sign.Parent then
			trackedSigns[sign] = nil
			continue
		end

		local signPosition = sign.Position
		local lookTarget = Vector3.new(cameraPosition.X, signPosition.Y, cameraPosition.Z)
		if (lookTarget - signPosition).Magnitude > 0.1 then
			sign.CFrame = CFrame.lookAt(signPosition, lookTarget)
		end
	end
end)
