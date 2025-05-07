local Localization = require "questral.localization"
return Localization{
	id = "zh-CN",
	name = "Chinese (Simplified)",
	incomplete = true,
	fonts =
	{
		title = { font = "fonts/blockhead_sdf.zip", sdfthreshold = 0.36, sdfboldthreshold = 0.30 },
		body = { font = "fonts/blockhead_sdf.zip", sdfthreshold = 0.4, sdfboldthreshold = 0.33 },
		button = { font = "fonts/blockhead_sdf.zip", sdfthreshold = 0.4, sdfboldthreshold = 0.33 },
		tooltip = { font = "fonts/blockhead_sdf.zip", sdfthreshold = 0.4, sdfboldthreshold = 0.33 },
		speech = { font = "fonts/blockhead_sdf.zip", sdfthreshold = 0.4, sdfboldthreshold = 0.33 },
	},

	po_filenames = {
		"localizations/zh_cn.po",
	},

	default_languages =
	{
		"zh-CN",
		"zh-Hans",
	},
}

