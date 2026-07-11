local production = {
	{ name = "BrokenCar_01", partsPerSecond = 1 },
	{ name = "BrokenCar_02", partsPerSecond = 1 },
	{ name = "BrokenCar_03", partsPerSecond = 1 },
	{ name = "BrokenCar_04", partsPerSecond = 3 },
	{ name = "BrokenCar_05", partsPerSecond = 3 },
	{ name = "BrokenCar_06", partsPerSecond = 3 },
	{ name = "BrokenCar_07", partsPerSecond = 3 },
	{ name = "BrokenCar_08", partsPerSecond = 5 },
	{ name = "BrokenCar_09", partsPerSecond = 5 },
	{ name = "BrokenCar_10", partsPerSecond = 5 },
	{ name = "BrokenCar_11", partsPerSecond = 5 },
}

local partsPerSecondByName = {}
for _, config in production do
	partsPerSecondByName[config.name] = config.partsPerSecond
end

return {
	Production = production,
	PartsPerSecondByName = partsPerSecondByName,
}
