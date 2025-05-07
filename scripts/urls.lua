local URLS = {
	mod_forum = "http://forums.kleientertainment.com/forum/79-dont-starve-together-beta-mods-and-tools/",
	coming_soon = "https://forums.kleientertainment.com/topic/91519-coming-soon-the-gorge/",
}
if Platform.IsRail() then
	URLS.klei_bug_tracker = "http://plat.tgp.qq.com/forum/index.html#/2000004?type=11"
elseif Platform.IsNotConsole() then
	if RELEASE_CHANNEL == "prod" then
		URLS.klei_bug_tracker = "https://forums.kleientertainment.com/klei-bug-tracker/dont-starve-together-return-of-them/"
	else
		URLS.klei_bug_tracker = "http://forums.kleientertainment.com/klei-bug-tracker/dont-starve-together/"
	end
end

return URLS
