local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurrencyConfig = require(ReplicatedStorage.Shared.CurrencyConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PartsDisplay"
screenGui.DisplayOrder = CurrencyConfig.DisplayOrder
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Container"
root.AnchorPoint = Vector2.new(0, 0)
root.Position = UDim2.fromOffset(16, 16)
root.Size = UDim2.fromOffset(260, 58)
root.BackgroundTransparency = 1
root.Parent = screenGui

local partsRow = Instance.new("Frame")
partsRow.Name = "PartsRow"
partsRow.Size = UDim2.fromOffset(260, 58)
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
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 1)
layout.Parent = partsRow

local amountLabel = Instance.new("TextLabel")
amountLabel.Name = "Amount"
amountLabel.Size = UDim2.new(1, 0, 0, 27)
amountLabel.BackgroundTransparency = 1
amountLabel.Font = Enum.Font.GothamBold
amountLabel.Text = "Parts: 0"
amountLabel.TextColor3 = Color3.fromRGB(245, 247, 250)
amountLabel.TextSize = 20
amountLabel.TextXAlignment = Enum.TextXAlignment.Left
amountLabel.Parent = partsRow

local rateLabel = Instance.new("TextLabel")
rateLabel.Name = "IncomeRate"
rateLabel.Size = UDim2.new(1, 0, 0, 19)
rateLabel.BackgroundTransparency = 1
rateLabel.Font = Enum.Font.GothamMedium
rateLabel.Text = "0 parts/sec"
rateLabel.TextColor3 = Color3.fromRGB(190, 204, 220)
rateLabel.TextSize = 14
rateLabel.TextXAlignment = Enum.TextXAlignment.Left
rateLabel.Parent = partsRow

local function formatNumber(value)
	local roundedValue = math.round(value * 10) / 10
	if roundedValue % 1 == 0 then
		return string.format("%d", math.floor(roundedValue))
	end

	return string.format("%.1f", roundedValue)
end

local function bindPartsValue(parts)
	local function updateAmount()
		amountLabel.Text = string.format("Parts: %s", formatNumber(parts.Value))
	end

	updateAmount()
	parts:GetPropertyChangedSignal("Value"):Connect(updateAmount)
end

local function bindIncomeRate()
	local function updateRate()
		local rate = player:GetAttribute(CurrencyConfig.PartsIncomeRateAttribute)
		if typeof(rate) ~= "number" then
			rate = 0
		end

		rateLabel.Text = string.format("%s parts/sec", formatNumber(rate))
	end

	updateRate()
	player:GetAttributeChangedSignal(CurrencyConfig.PartsIncomeRateAttribute):Connect(updateRate)
end

local leaderstats = player:WaitForChild("leaderstats")
local parts = leaderstats:WaitForChild(CurrencyConfig.PartsName)

bindPartsValue(parts)
bindIncomeRate()
