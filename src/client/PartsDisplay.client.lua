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

local container = Instance.new("Frame")
container.Name = "Container"
container.AnchorPoint = Vector2.new(0, 0)
container.Position = UDim2.fromOffset(16, 16)
container.Size = UDim2.fromOffset(150, 44)
container.BackgroundColor3 = Color3.fromRGB(24, 28, 34)
container.BackgroundTransparency = 0.1
container.BorderSizePixel = 0
container.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = container

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = container

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = container

local icon = Instance.new("ImageLabel")
icon.Name = "PartsIcon"
icon.Size = UDim2.fromOffset(28, 28)
icon.BackgroundTransparency = 1
icon.Image = CurrencyConfig.PartsIcon
icon.Parent = container

local amountLabel = Instance.new("TextLabel")
amountLabel.Name = "Amount"
amountLabel.Size = UDim2.new(1, -36, 1, 0)
amountLabel.BackgroundTransparency = 1
amountLabel.Font = Enum.Font.GothamBold
amountLabel.Text = "0"
amountLabel.TextColor3 = Color3.fromRGB(245, 247, 250)
amountLabel.TextSize = 22
amountLabel.TextXAlignment = Enum.TextXAlignment.Left
amountLabel.Parent = container

local function bindPartsValue(parts)
	local function updateAmount()
		amountLabel.Text = tostring(parts.Value)
	end

	updateAmount()
	parts:GetPropertyChangedSignal("Value"):Connect(updateAmount)
end

local leaderstats = player:WaitForChild("leaderstats")
local parts = leaderstats:WaitForChild(CurrencyConfig.PartsName)

bindPartsValue(parts)
