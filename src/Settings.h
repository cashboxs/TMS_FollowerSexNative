#pragma once

#include <RE/Skyrim.h>
#include <filesystem>
#include <mutex>

namespace TMS_FollowerSexNative
{
    struct MenuGlobals
    {
        RE::TESGlobal* enabled{ nullptr };
        RE::TESGlobal* debug{ nullptr };
        RE::TESGlobal* useOStim{ nullptr };
        RE::TESGlobal* useSexLab{ nullptr };
    };

    struct PersistentSettings
    {
        bool enabled{ true };
        bool debug{ false };
        bool useOStim{ true };
        bool useSexLab{ false };
    };

    extern std::mutex g_menuGlobalsLock;
    extern MenuGlobals g_menuGlobals;

    std::filesystem::path GetIniPath();
    bool GlobalBool(RE::TESGlobal* a_global, bool a_fallback = false);
    void SetGlobalBool(RE::TESGlobal* a_global, bool a_value);
    bool SettingsGlobalsComplete();
    PersistentSettings ReadSettingsFromGlobals();
    void ApplySettingsToGlobals(const PersistentSettings& a_settings);
    bool SaveSettingsToIni(const PersistentSettings& a_settings);
    bool LoadSettingsFromIni();
    void SaveCurrentSettingsToIni();
    bool BindSettingsGlobals(RE::StaticFunctionTag*, RE::TESGlobal*, RE::TESGlobal*, RE::TESGlobal*, RE::TESGlobal*);
}
