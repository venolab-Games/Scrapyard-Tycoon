local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)

local STARTING_PARTS = 0

local function startPassiveIncome(player, parts)
	task.spawn(function()
		while player.Parent do
			task.wait(CurrencyConfig.PASSIVE_PARTS_INTERVAL_SECONDS)

			if not player.Parent or not parts.Parent then
				break
			end

			parts.Value += CurrencyConfig.PASSIVE_PARTS_AMOUNT
		end
	end)
end

local function setupCurrency(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local parts = Instance.new("IntValue")
	parts.Name = CurrencyConfig.PartsName
	parts.Value = STARTING_PARTS
	parts.Parent = leaderstats

	startPassiveIncome(player, parts)
end

Players.PlayerAdded:Connect(setupCurrency)
