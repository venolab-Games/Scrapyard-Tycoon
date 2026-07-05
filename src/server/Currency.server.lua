local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)

local STARTING_PARTS = 0
local STARTING_SCRAPYARD_LEVEL = 1

local scrapyardGenerationPlayers = {}

local remotesFolder = ReplicatedStorage:FindFirstChild(CurrencyConfig.RemotesFolderName)
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = CurrencyConfig.RemotesFolderName
	remotesFolder.Parent = ReplicatedStorage
end

local scrapyardUpgradeRemote = remotesFolder:FindFirstChild(CurrencyConfig.ScrapyardUpgradeRemoteName)
if not scrapyardUpgradeRemote then
	scrapyardUpgradeRemote = Instance.new("RemoteEvent")
	scrapyardUpgradeRemote.Name = CurrencyConfig.ScrapyardUpgradeRemoteName
	scrapyardUpgradeRemote.Parent = remotesFolder
end

local function getCurrencyValues(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil, nil
	end

	local parts = leaderstats:FindFirstChild(CurrencyConfig.PartsName)
	local scrapyardLevel = player:FindFirstChild(CurrencyConfig.ScrapyardLevelName)

	return parts, scrapyardLevel
end

local function getScrapyardSpeedAmount(scrapyardLevel)
	local levelBonus = math.max(scrapyardLevel.Value - 1, 0) * CurrencyConfig.SCRAPYARD_INCOME_BONUS_PER_LEVEL
	return CurrencyConfig.SCRAPYARD_PARTS_AMOUNT + levelBonus
end

local function startScrapyardGeneration(player, parts, scrapyardLevel)
	if scrapyardGenerationPlayers[player] then
		return
	end

	scrapyardGenerationPlayers[player] = true

	task.spawn(function()
		while player.Parent do
			task.wait(CurrencyConfig.SCRAPYARD_INCOME_INTERVAL_SECONDS)

			if not player.Parent or not parts.Parent or not scrapyardLevel.Parent then
				break
			end

			parts.Value += getScrapyardSpeedAmount(scrapyardLevel)
		end

		scrapyardGenerationPlayers[player] = nil
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

	local scrapyardLevel = Instance.new("IntValue")
	scrapyardLevel.Name = CurrencyConfig.ScrapyardLevelName
	scrapyardLevel.Value = STARTING_SCRAPYARD_LEVEL
	scrapyardLevel.Parent = player

	startScrapyardGeneration(player, parts, scrapyardLevel)
end

local function requestScrapyardUpgrade(player)
	local parts, scrapyardLevel = getCurrencyValues(player)
	if not parts or not scrapyardLevel then
		return
	end

	local upgradeCost = CurrencyConfig.GetScrapyardUpgradeCost(scrapyardLevel.Value)
	if parts.Value < upgradeCost then
		return
	end

	parts.Value -= upgradeCost
	scrapyardLevel.Value += 1
end

Players.PlayerAdded:Connect(setupCurrency)
Players.PlayerRemoving:Connect(function(player)
	scrapyardGenerationPlayers[player] = nil
end)

scrapyardUpgradeRemote.OnServerEvent:Connect(requestScrapyardUpgrade)
