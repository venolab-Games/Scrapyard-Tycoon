local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local NORMAL_WALK_SPEED = 16
local SPRINT_MULTIPLIER = 1.50
local SPRINT_WALK_SPEED = NORMAL_WALK_SPEED * SPRINT_MULTIPLIER

local player = Players.LocalPlayer

local currentHumanoid = nil
local isSprinting = false

local function applyWalkSpeed()
	if not currentHumanoid then
		return
	end

	currentHumanoid.WalkSpeed = if isSprinting then SPRINT_WALK_SPEED else NORMAL_WALK_SPEED
end

local function bindCharacter(character)
	currentHumanoid = character:WaitForChild("Humanoid")
	isSprinting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
	applyWalkSpeed()
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent or input.KeyCode ~= Enum.KeyCode.LeftShift then
		return
	end

	isSprinting = true
	applyWalkSpeed()
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode ~= Enum.KeyCode.LeftShift then
		return
	end

	isSprinting = false
	applyWalkSpeed()
end)

player.CharacterAdded:Connect(bindCharacter)

if player.Character then
	bindCharacter(player.Character)
end
