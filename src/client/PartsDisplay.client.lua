local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotesFolder = ReplicatedStorage:WaitForChild(CurrencyConfig.RemotesFolderName)
local scrapyardUpgradeRemote = remotesFolder:WaitForChild(CurrencyConfig.ScrapyardUpgradeRemoteName)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PartsDisplay"
screenGui.DisplayOrder = CurrencyConfig.DisplayOrder
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Container"
root.AnchorPoint = Vector2.new(0, 0)
root.Position = UDim2.fromOffset(16, 16)
root.Size = UDim2.fromOffset(260, 150)
root.BackgroundTransparency = 1
root.Parent = screenGui

local rootLayout = Instance.new("UIListLayout")
rootLayout.FillDirection = Enum.FillDirection.Vertical
rootLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
rootLayout.VerticalAlignment = Enum.VerticalAlignment.Top
rootLayout.Padding = UDim.new(0, 8)
rootLayout.Parent = root

local partsRow = Instance.new("Frame")
partsRow.Name = "PartsRow"
partsRow.Size = UDim2.fromOffset(260, 44)
partsRow.BackgroundColor3 = Color3.fromRGB(24, 28, 34)
partsRow.BackgroundTransparency = 0.1
partsRow.BorderSizePixel = 0
partsRow.Parent = root

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = partsRow

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = partsRow

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = partsRow

local icon = Instance.new("ImageLabel")
icon.Name = "PartsIcon"
icon.Size = UDim2.fromOffset(28, 28)
icon.BackgroundTransparency = 1
icon.Image = CurrencyConfig.PartsIcon
icon.Parent = partsRow

local amountLabel = Instance.new("TextLabel")
amountLabel.Name = "Amount"
amountLabel.Size = UDim2.new(1, -36, 1, 0)
amountLabel.BackgroundTransparency = 1
amountLabel.Font = Enum.Font.GothamBold
amountLabel.Text = "Parts: 0"
amountLabel.TextColor3 = Color3.fromRGB(245, 247, 250)
amountLabel.TextSize = 20
amountLabel.TextXAlignment = Enum.TextXAlignment.Left
amountLabel.Parent = partsRow

local infoPanel = Instance.new("Frame")
infoPanel.Name = "InfoPanel"
infoPanel.Size = UDim2.fromOffset(260, 52)
infoPanel.BackgroundColor3 = Color3.fromRGB(24, 28, 34)
infoPanel.BackgroundTransparency = 0.1
infoPanel.BorderSizePixel = 0
infoPanel.Parent = root

local infoCorner = Instance.new("UICorner")
infoCorner.CornerRadius = UDim.new(0, 8)
infoCorner.Parent = infoPanel

local infoPadding = Instance.new("UIPadding")
infoPadding.PaddingLeft = UDim.new(0, 10)
infoPadding.PaddingRight = UDim.new(0, 10)
infoPadding.Parent = infoPanel

local infoLayout = Instance.new("UIListLayout")
infoLayout.FillDirection = Enum.FillDirection.Vertical
infoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
infoLayout.VerticalAlignment = Enum.VerticalAlignment.Center
infoLayout.Padding = UDim.new(0, 4)
infoLayout.Parent = infoPanel

local speedLabel = Instance.new("TextLabel")
speedLabel.Name = "ScrapyardSpeed"
speedLabel.Size = UDim2.new(1, 0, 0, 18)
speedLabel.BackgroundTransparency = 1
speedLabel.Font = Enum.Font.GothamMedium
speedLabel.Text = "Scrapyard Speed: +1 / sec"
speedLabel.TextColor3 = Color3.fromRGB(223, 229, 235)
speedLabel.TextSize = 15
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = infoPanel

local scrapyardLevelLabel = Instance.new("TextLabel")
scrapyardLevelLabel.Name = "ScrapyardLevel"
scrapyardLevelLabel.Size = UDim2.new(1, 0, 0, 18)
scrapyardLevelLabel.BackgroundTransparency = 1
scrapyardLevelLabel.Font = Enum.Font.GothamMedium
scrapyardLevelLabel.Text = "Scrapyard Level: 1"
scrapyardLevelLabel.TextColor3 = Color3.fromRGB(223, 229, 235)
scrapyardLevelLabel.TextSize = 15
scrapyardLevelLabel.TextXAlignment = Enum.TextXAlignment.Left
scrapyardLevelLabel.Parent = infoPanel

local upgradeButton = Instance.new("TextButton")
upgradeButton.Name = "UpgradeScrapyardButton"
upgradeButton.Size = UDim2.fromOffset(260, 38)
upgradeButton.BackgroundColor3 = Color3.fromRGB(41, 94, 73)
upgradeButton.BorderSizePixel = 0
upgradeButton.Font = Enum.Font.GothamBold
upgradeButton.Text = "Upgrade Scrapyard - 10 Parts"
upgradeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
upgradeButton.TextSize = 15
upgradeButton.Parent = root

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 8)
buttonCorner.Parent = upgradeButton

local function bindPartsValue(parts)
	local function updateAmount()
		amountLabel.Text = string.format("Parts: %d", parts.Value)
	end

	updateAmount()
	parts:GetPropertyChangedSignal("Value"):Connect(updateAmount)
end

local function getScrapyardSpeedAmount(scrapyardLevel)
	local levelBonus = math.max(scrapyardLevel.Value - 1, 0) * CurrencyConfig.SCRAPYARD_INCOME_BONUS_PER_LEVEL
	return CurrencyConfig.SCRAPYARD_PARTS_AMOUNT + levelBonus
end

local function bindScrapyardLevel(scrapyardLevel)
	local function updateScrapyardInfo()
		local speedAmount = getScrapyardSpeedAmount(scrapyardLevel)
		local upgradeCost = CurrencyConfig.GetScrapyardUpgradeCost(scrapyardLevel.Value)

		speedLabel.Text = string.format("Scrapyard Speed: +%d / sec", speedAmount)
		scrapyardLevelLabel.Text = string.format("Scrapyard Level: %d", scrapyardLevel.Value)
		upgradeButton.Text = string.format("Upgrade Scrapyard - %d Parts", upgradeCost)
	end

	updateScrapyardInfo()
	scrapyardLevel:GetPropertyChangedSignal("Value"):Connect(updateScrapyardInfo)
end

local leaderstats = player:WaitForChild("leaderstats")
local parts = leaderstats:WaitForChild(CurrencyConfig.PartsName)
local scrapyardLevel = player:WaitForChild(CurrencyConfig.ScrapyardLevelName)

bindPartsValue(parts)
bindScrapyardLevel(scrapyardLevel)

upgradeButton.Activated:Connect(function()
	scrapyardUpgradeRemote:FireServer()
end)
