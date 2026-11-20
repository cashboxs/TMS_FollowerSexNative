#include "PCH.h"
#include "SettingsMenu.h"
#include "Settings.h"
#include "SKSEMenuFramework.h"

namespace logger = SKSE::log;

namespace TMS_FollowerSexNative
{
namespace
{
	std::atomic_bool g_menuRegistered{ false };
}

	void __stdcall RenderSettingsMenu()
	{
		std::scoped_lock lock(g_menuGlobalsLock);

		if (!g_menuGlobals.enabled || !g_menuGlobals.debug || !g_menuGlobals.useOStim || !g_menuGlobals.useSexLab) {
			ImGuiMCP::TextDisabled("Waiting for the Generic Follower Sex quest to bind its settings.");
			return;
		}

		ImGuiMCP::SeparatorText("General");

		bool enabled = GlobalBool(g_menuGlobals.enabled, true);
		if (ImGuiMCP::Checkbox("Enable System", &enabled)) {
			SetGlobalBool(g_menuGlobals.enabled, enabled);
			SaveCurrentSettingsToIni();
			logger::info("FS_MENU: Enable System={}", enabled);
		}

		bool debug = GlobalBool(g_menuGlobals.debug, false);
		if (ImGuiMCP::Checkbox("Debug Logging", &debug)) {
			SetGlobalBool(g_menuGlobals.debug, debug);
			SaveCurrentSettingsToIni();
			logger::info("FS_MENU: Debug Logging={}", debug);
		}

		ImGuiMCP::SeparatorText("Adult Framework");

		bool useOStim = GlobalBool(g_menuGlobals.useOStim, true);
		if (ImGuiMCP::Checkbox("Use OStim", &useOStim)) {
			SetGlobalBool(g_menuGlobals.useOStim, useOStim);
			SaveCurrentSettingsToIni();
			logger::info("FS_MENU: Use OStim={}", useOStim);
		}

		bool useSexLab = GlobalBool(g_menuGlobals.useSexLab, false);
		if (ImGuiMCP::Checkbox("Use SexLab", &useSexLab)) {
			SetGlobalBool(g_menuGlobals.useSexLab, useSexLab);
			SaveCurrentSettingsToIni();
			logger::info("FS_MENU: Use SexLab={}", useSexLab);
		}

		ImGuiMCP::TextDisabled("When both frameworks are enabled and available, OStim keeps priority.");
		ImGuiMCP::TextDisabled("Romantic mini scenes such as hug/cuddle remain OStim-only.");
	}

	void RegisterSettingsMenu()
	{
		if (g_menuRegistered.exchange(true)) {
			return;
		}

		if (!SKSEMenuFramework::IsInstalled() || SKSEMenuFramework::GetMenuFrameworkVersion() <= 0.0f) {
			g_menuRegistered.store(false);
			logger::info("FS_MENU: SKSE Menu Framework not available; FS runtime remains usable without the menu");
			return;
		}

		SKSEMenuFramework::SetSection("Generic Follower Sex");
		SKSEMenuFramework::AddSectionItem("Settings", RenderSettingsMenu);

		logger::info(
			"FS_MENU: registered section frameworkVersion={}",
			SKSEMenuFramework::GetMenuFrameworkVersion());
	}

}
