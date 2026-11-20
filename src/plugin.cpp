#include "PCH.h"
#include "Logger.h"
#include "Papyrus.h"
#include "SettingsMenu.h"

namespace logger = SKSE::log;

SKSEPluginLoad(const SKSE::LoadInterface* a_skse)
{
	TMS_FollowerSexNative::InitializeLog();

	logger::info("{} plugin loading", "TMS_FollowerSexNative");

	SKSE::Init(a_skse);

	const auto papyrus = SKSE::GetPapyrusInterface();
	if (papyrus) {
		papyrus->Register(TMS_FollowerSexNative::RegisterFuncs);
		logger::info("Papyrus registration callback submitted");
	} else {
		logger::error("Papyrus interface is null");
	}

	if (auto* messaging = SKSE::GetMessagingInterface()) {
		messaging->RegisterListener([](SKSE::MessagingInterface::Message* a_message) {
			if (!a_message) {
				return;
			}

			if (a_message->type == SKSE::MessagingInterface::kDataLoaded) {
				TMS_FollowerSexNative::RegisterSettingsMenu();
			}
		});
		logger::info("SKSE messaging listener registered");
	} else {
		logger::warn("SKSE messaging interface is null; SKSEMF menu cannot register");
	}

	logger::info("{} plugin loaded", "TMS_FollowerSexNative");

	return true;
}