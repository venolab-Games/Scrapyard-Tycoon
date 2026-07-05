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
root.Size = UDim2.fromOffset(260, 44)
root.BackgroundTransparency = 1
root.Parent = screenGui

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

local function bindPartsValue(parts)
	local function updateAmount()
		amountLabel.Text = string.format("Parts: %d", parts.Value)
	end

	updateAmount()
	parts:GetPropertyChangedSignal("Value"):Connect(updateAmount)
end

local leaderstats = player:WaitForChild("leaderstats")
local parts = leaderstats:WaitForChild(CurrencyConfig.PartsName)

bindPartsValue(parts)
