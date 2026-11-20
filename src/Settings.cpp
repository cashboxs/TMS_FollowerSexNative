#include "PCH.h"
#include "Settings.h"
#include <Windows.h>
#include <exception>

namespace logger = SKSE::log;

namespace TMS_FollowerSexNative
{
std::mutex g_menuGlobalsLock;
MenuGlobals g_menuGlobals;

namespace
{
	constexpr auto kIniFileName = "TMS_FollowerSex.ini";
}

	std::filesystem::path GetIniPath()
	{
		try {
			return std::filesystem::current_path() /
				"Data" /
				"SKSE" /
				"Plugins" /
				kIniFileName;
		} catch (...) {
			return {};
		}
	}
	bool GlobalBool(RE::TESGlobal* a_global, bool a_fallback)
	{
		return a_global ? a_global->value >= 0.5f : a_fallback;
	}

	void SetGlobalBool(RE::TESGlobal* a_global, bool a_value)
	{
		if (a_global) {
			a_global->value = a_value ? 1.0f : 0.0f;
		}
	}

	bool SettingsGlobalsComplete()
	{
		return g_menuGlobals.enabled &&
			g_menuGlobals.debug &&
			g_menuGlobals.useOStim &&
			g_menuGlobals.useSexLab;
	}

	PersistentSettings ReadSettingsFromGlobals()
	{
		PersistentSettings settings;
		settings.enabled = GlobalBool(g_menuGlobals.enabled, true);
		settings.debug = GlobalBool(g_menuGlobals.debug, false);
		settings.useOStim = GlobalBool(g_menuGlobals.useOStim, true);
		settings.useSexLab = GlobalBool(g_menuGlobals.useSexLab, false);
		return settings;
	}

	void ApplySettingsToGlobals(const PersistentSettings& a_settings)
	{
		SetGlobalBool(g_menuGlobals.enabled, a_settings.enabled);
		SetGlobalBool(g_menuGlobals.debug, a_settings.debug);
		SetGlobalBool(g_menuGlobals.useOStim, a_settings.useOStim);
		SetGlobalBool(g_menuGlobals.useSexLab, a_settings.useSexLab);
	}

	bool ReadIniBool(
		const std::filesystem::path& a_path,
		const wchar_t* a_section,
		const wchar_t* a_key,
		bool a_fallback)
	{
		const auto value = GetPrivateProfileIntW(
			a_section,
			a_key,
			a_fallback ? 1 : 0,
			a_path.c_str());

		return value != 0;
	}

	bool WriteIniBool(
		const std::filesystem::path& a_path,
		const wchar_t* a_section,
		const wchar_t* a_key,
		bool a_value)
	{
		return WritePrivateProfileStringW(
			a_section,
			a_key,
			a_value ? L"1" : L"0",
			a_path.c_str()) != FALSE;
	}

	bool SaveSettingsToIni(const PersistentSettings& a_settings)
	{
		const auto path = GetIniPath();
		if (path.empty()) {
			logger::error("FS_CONFIG: failed to resolve INI path");
			return false;
		}

		try {
			std::filesystem::create_directories(path.parent_path());
		} catch (const std::exception& e) {
			logger::error("FS_CONFIG: failed to create INI directory path={} error={}", path.parent_path().string(), e.what());
			return false;
		} catch (...) {
			logger::error("FS_CONFIG: failed to create INI directory path={}", path.parent_path().string());
			return false;
		}

		bool ok = true;
		ok = WriteIniBool(path, L"General", L"Enabled", a_settings.enabled) && ok;
		ok = WriteIniBool(path, L"General", L"Debug", a_settings.debug) && ok;
		ok = WriteIniBool(path, L"Integration", L"OStim", a_settings.useOStim) && ok;
		ok = WriteIniBool(path, L"Integration", L"SexLab", a_settings.useSexLab) && ok;

		WritePrivateProfileStringW(nullptr, nullptr, nullptr, path.c_str());

		if (ok) {
			logger::info(
				"FS_CONFIG: saved path={} enabled={} debug={} ostim={} sexlab={}",
				path.string(),
				a_settings.enabled,
				a_settings.debug,
				a_settings.useOStim,
				a_settings.useSexLab);
		} else {
			logger::error("FS_CONFIG: one or more INI writes failed path={}", path.string());
		}

		return ok;
	}

	bool LoadSettingsFromIni()
	{
		if (!SettingsGlobalsComplete()) {
			return false;
		}

		const auto path = GetIniPath();
		if (path.empty()) {
			logger::error("FS_CONFIG: failed to resolve INI path");
			return false;
		}

		const PersistentSettings fallback = ReadSettingsFromGlobals();

		if (!std::filesystem::exists(path)) {
			logger::info(
				"FS_CONFIG: no INI found; importing current GV values as initial persistent settings path={}",
				path.string());
			return SaveSettingsToIni(fallback);
		}

		PersistentSettings loaded;
		loaded.enabled = ReadIniBool(path, L"General", L"Enabled", fallback.enabled);
		loaded.debug = ReadIniBool(path, L"General", L"Debug", fallback.debug);
		loaded.useOStim = ReadIniBool(path, L"Integration", L"OStim", fallback.useOStim);
		loaded.useSexLab = ReadIniBool(path, L"Integration", L"SexLab", fallback.useSexLab);

		ApplySettingsToGlobals(loaded);

		logger::info(
			"FS_CONFIG: loaded path={} enabled={} debug={} ostim={} sexlab={}",
			path.string(),
			loaded.enabled,
			loaded.debug,
			loaded.useOStim,
			loaded.useSexLab);

		return true;
	}

	void SaveCurrentSettingsToIni()
	{
		if (!SettingsGlobalsComplete()) {
			return;
		}

		SaveSettingsToIni(ReadSettingsFromGlobals());
	}

	bool BindSettingsGlobals(
		RE::StaticFunctionTag*,
		RE::TESGlobal* a_enabled,
		RE::TESGlobal* a_debug,
		RE::TESGlobal* a_useOStim,
		RE::TESGlobal* a_useSexLab)
	{
		std::scoped_lock lock(g_menuGlobalsLock);
		g_menuGlobals.enabled = a_enabled;
		g_menuGlobals.debug = a_debug;
		g_menuGlobals.useOStim = a_useOStim;
		g_menuGlobals.useSexLab = a_useSexLab;

		const bool complete =
			a_enabled != nullptr &&
			a_debug != nullptr &&
			a_useOStim != nullptr &&
			a_useSexLab != nullptr;

		logger::info(
			"FS_MENU: settings globals bound complete={} enabled={:08X} debug={:08X} ostim={:08X} sexlab={:08X}",
			complete,
			a_enabled ? a_enabled->GetFormID() : 0,
			a_debug ? a_debug->GetFormID() : 0,
			a_useOStim ? a_useOStim->GetFormID() : 0,
			a_useSexLab ? a_useSexLab->GetFormID() : 0);

		if (complete) {
			LoadSettingsFromIni();
		}

		return complete;
	}

}
