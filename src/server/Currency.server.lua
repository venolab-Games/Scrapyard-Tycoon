local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)

local STARTING_PARTS = 0
local STARTING_MOTOR_POOL_LEVEL = 1

local scrapyardIncomePlayers = {}

local remotesFolder = ReplicatedStorage:FindFirstChild(CurrencyConfig.RemotesFolderName)
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = CurrencyConfig.RemotesFolderName
	remotesFolder.Parent = ReplicatedStorage
end

local motorPoolUpgradeRemote = remotesFolder:FindFirstChild(CurrencyConfig.MotorPoolUpgradeRemoteName)
if not motorPoolUpgradeRemote then
	motorPoolUpgradeRemote = Instance.new("RemoteEvent")
	motorPoolUpgradeRemote.Name = CurrencyConfig.MotorPoolUpgradeRemoteName
	motorPoolUpgradeRemote.Parent = remotesFolder
end

local function getCurrencyValues(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil, nil
	end

	local parts = leaderstats:FindFirstChild(CurrencyConfig.PartsName)
	local motorPoolLevel = leaderstats:FindFirstChild(CurrencyConfig.MotorPoolLevelName)

	return parts, motorPoolLevel
end

local function getScrapyardIncomeAmount(motorPoolLevel)
	local levelBonus = math.max(motorPoolLevel.Value - 1, 0) * CurrencyConfig.MOTOR_POOL_INCOME_BONUS_PER_LEVEL
	return CurrencyConfig.SCRAPYARD_PARTS_AMOUNT + levelBonus
end

local function startScrapyardIncome(player, parts, motorPoolLevel)
	if scrapyardIncomePlayers[player] then
		return
	end

	scrapyardIncomePlayers[player] = true

	task.spawn(function()
		while player.Parent do
			task.wait(CurrencyConfig.SCRAPYARD_INCOME_INTERVAL_SECONDS)

			if not player.Parent or not parts.Parent or not motorPoolLevel.Parent then
				break
			end

			parts.Value += getScrapyardIncomeAmount(motorPoolLevel)
		end

		scrapyardIncomePlayers[player] = nil
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

	local motorPoolLevel = Instance.new("IntValue")
	motorPoolLevel.Name = CurrencyConfig.MotorPoolLevelName
	motorPoolLevel.Value = STARTING_MOTOR_POOL_LEVEL
	motorPoolLevel.Parent = leaderstats

	startScrapyardIncome(player, parts, motorPoolLevel)
end

local function requestMotorPoolUpgrade(player)
	local parts, motorPoolLevel = getCurrencyValues(player)
	if not parts or not motorPoolLevel then
		return
	end

	if parts.Value < CurrencyConfig.MOTOR_POOL_UPGRADE_COST then
		return
	end

	parts.Value -= CurrencyConfig.MOTOR_POOL_UPGRADE_COST
	motorPoolLevel.Value += 1
end

Players.PlayerAdded:Connect(setupCurrency)
Players.PlayerRemoving:Connect(function(player)
	scrapyardIncomePlayers[player] = nil
end)

motorPoolUpgradeRemote.OnServerEvent:Connect(requestMotorPoolUpgrade)
