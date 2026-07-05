local CurrencyConfig = {
	PartsName = "Parts",
	ScrapyardLevelName = "ScrapyardLevel",
	PartsIcon = "rbxassetid://121262043800613",
	DisplayOrder = 10,
	RemotesFolderName = "Remotes",
	ScrapyardUpgradeRemoteName = "RequestScrapyardUpgrade",
	SCRAPYARD_PARTS_AMOUNT = 1,
	SCRAPYARD_INCOME_INTERVAL_SECONDS = 1,
	SCRAPYARD_BASE_UPGRADE_COST = 10,
	SCRAPYARD_UPGRADE_COST_MULTIPLIER = 1.5,
	SCRAPYARD_INCOME_BONUS_PER_LEVEL = 1,
}

function CurrencyConfig.GetScrapyardUpgradeCost(scrapyardLevel)
	return math.ceil(CurrencyConfig.SCRAPYARD_BASE_UPGRADE_COST * CurrencyConfig.SCRAPYARD_UPGRADE_COST_MULTIPLIER ^ (scrapyardLevel - 1))
end

return CurrencyConfig
