local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)

local STARTING_PARTS = 0

local function setupCurrency(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local parts = Instance.new("NumberValue")
	parts.Name = CurrencyConfig.PartsName
	parts.Value = STARTING_PARTS
	parts.Parent = leaderstats

	if player:GetAttribute(CurrencyConfig.PartsIncomeRateAttribute) == nil then
		player:SetAttribute(CurrencyConfig.PartsIncomeRateAttribute, 0)
	end
end

Players.PlayerAdded:Connect(setupCurrency)
