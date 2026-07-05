local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)

local STARTING_PARTS = 0
local TEST_GRANT_AMOUNT = 10
local TEST_GRANT_DELAY = 3

local function setupLeaderstats(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local parts = Instance.new("IntValue")
	parts.Name = CurrencyConfig.PartsName
	parts.Value = STARTING_PARTS
	parts.Parent = leaderstats

	task.delay(TEST_GRANT_DELAY, function()
		if not parts.Parent then
			return
		end

		-- Temporary test behavior: grants Parts once so Rojo-synced currency updates can be verified.
		parts.Value += TEST_GRANT_AMOUNT
	end)
end

Players.PlayerAdded:Connect(setupLeaderstats)
