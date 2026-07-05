local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)

local STARTING_PARTS = 0

local function setupCurrency(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local parts = Instance.new("IntValue")
	parts.Name = CurrencyConfig.PartsName
	parts.Value = STARTING_PARTS
	parts.Parent = leaderstats
end

Players.PlayerAdded:Connect(setupCurrency)
