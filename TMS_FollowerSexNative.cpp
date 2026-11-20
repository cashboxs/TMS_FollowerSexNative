#include <RE/Skyrim.h>
#include <REL/Relocation.h>
#include <SKSE/SKSE.h>

#include <Windows.h>
#include <ShlObj.h>

#include <algorithm>
#include <atomic>
#include <cfloat>
#include <cstdint>
#include <filesystem>
#include <exception>
#include <memory>
#include <mutex>
#include <string>
#include <utility>
#include <vector>

#include "SKSEMenuFramework.h"

#include <spdlog/sinks/basic_file_sink.h>

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "ole32.lib")

using namespace std::literals;

namespace logger = SKSE::log;

namespace util
{
	using SKSE::stl::report_and_fail;
}

namespace
{
	constexpr auto kPluginName = "TMS_FollowerSexNative";
	constexpr auto kLogFileName = "TMS_FollowerSexNative.log";
	constexpr auto kIniFileName = "TMS_FollowerSex.ini";

	std::filesystem::path GetDocumentsPath()
	{
		PWSTR rawPath = nullptr;

		const HRESULT result = SHGetKnownFolderPath(
			FOLDERID_Documents,
			KF_FLAG_DEFAULT,
			nullptr,
			&rawPath
		);

		if (FAILED(result) || rawPath == nullptr) {
			return {};
		}

		std::filesystem::path path(rawPath);
		CoTaskMemFree(rawPath);

		return path;
	}

	std::filesystem::path GetLogPath()
	{
		return GetDocumentsPath() /
			"My Games" /
			"Skyrim Special Edition" /
			"SKSE" /
			kLogFileName;
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

	void InitializeLog()
	{
		auto path = GetLogPath();

		if (path.empty()) {
			util::report_and_fail("TMS_FollowerSexNative: failed to find Documents log path"sv);
		}

		try {
			std::filesystem::create_directories(path.parent_path());
		} catch (...) {
			util::report_and_fail("TMS_FollowerSexNative: failed to create log directory"sv);
		}

		auto sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(path.string(), true);
		auto log = std::make_shared<spdlog::logger>("global log"s, std::move(sink));

		log->set_level(spdlog::level::info);
		log->flush_on(spdlog::level::info);

		spdlog::set_default_logger(std::move(log));
		spdlog::set_pattern("[%Y-%m-%d %H:%M:%S.%e] [%l] [%t] [%s:%#] %v"s);

		logger::info("{} logger initialized", kPluginName);
		logger::info("Log path: {}", path.string());
	}

	float GetDistanceSquared(RE::TESObjectREFR* a_refA, RE::TESObjectREFR* a_refB)
	{
		if (!a_refA || !a_refB) {
			return FLT_MAX;
		}

		const auto posA = a_refA->GetPosition();
		const auto posB = a_refB->GetPosition();

		const float dx = posA.x - posB.x;
		const float dy = posA.y - posB.y;
		const float dz = posA.z - posB.z;

		return dx * dx + dy * dy + dz * dz;
	}

	bool HasClearLineOfSight(RE::Actor* a_player, RE::Actor* a_actor)
	{
		if (!a_player || !a_actor) {
			return false;
		}

		bool playerLOSArg = false;
		const bool playerHasLOS = a_player->HasLineOfSight(a_actor, playerLOSArg);

		bool actorLOSArg = false;
		const bool actorHasLOS = a_actor->HasLineOfSight(a_player, actorLOSArg);

		return playerHasLOS || actorHasLOS;
	}

	bool IsFactionForm(RE::TESForm* a_form)
	{
		return a_form && a_form->GetFormType() == RE::FormType::Faction;
	}

	bool IsActorInFactionSafe(RE::Actor* a_actor, RE::TESFaction* a_faction, const char* a_label)
	{
		if (!a_actor || !a_faction) {
			return false;
		}

		if (!IsFactionForm(a_faction)) {
			SKSE::log::warn(
				"{} skipped: form is not faction formType={} formID={:08X}",
				a_label ? a_label : "Faction check",
				static_cast<std::uint32_t>(a_faction->GetFormType()),
				a_faction->GetFormID()
			);
			return false;
		}

		return a_actor->IsInFaction(a_faction);
	}

	std::int32_t RelationshipLevelToPapyrusRank(RE::BGSRelationship::RELATIONSHIP_LEVEL a_level)
	{
		switch (a_level) {
		case RE::BGSRelationship::RELATIONSHIP_LEVEL::kLover:
			return 4;
		case RE::BGSRelationship::RELATIONSHIP_LEVEL::kAlly:
			return 3;
		case RE::BGSRelationship::RELATIONSHIP_LEVEL::kConfidant:
			return 2;
		case RE::BGSRelationship::RELATIONSHIP_LEVEL::kFriend:
			return 1;
		case RE::BGSRelationship::RELATIONSHIP_LEVEL::kAcquaintance:
			return 0;
		case RE::BGSRelationship::RELATIONSHIP_LEVEL::kRival:
			return -1;
		case RE::BGSRelationship::RELATIONSHIP_LEVEL::kFoe:
			return -2;
		case RE::BGSRelationship::RELATIONSHIP_LEVEL::kEnemy:
			return -3;
		case RE::BGSRelationship::RELATIONSHIP_LEVEL::kArchnemesis:
			return -4;
		default:
			return -4;
		}
	}

	std::int32_t GetRelationshipRankSafe(RE::Actor* a_actor, RE::Actor* a_target)
	{
		if (!a_actor || !a_target) {
			return -4;
		}

		auto* actorBase = a_actor->GetActorBase();
		auto* targetBase = a_target->GetActorBase();

		if (!actorBase || !targetBase) {
			return -4;
		}

		auto* relationship = RE::BGSRelationship::GetRelationship(actorBase, targetBase);
		if (!relationship) {
			return -4;
		}

		return RelationshipLevelToPapyrusRank(relationship->level.get());
	}

	std::int32_t GetActorSexSafe(RE::Actor* a_actor)
	{
		if (!a_actor) {
			return -1;
		}

		auto* actorBase = a_actor->GetActorBase();
		if (!actorBase) {
			return -1;
		}

		const auto sex = actorBase->GetSex();

		if (sex == RE::SEX::kMale) {
			return 0;
		}

		if (sex == RE::SEX::kFemale) {
			return 1;
		}

		return -1;
	}

	bool IsFollowerCandidate(
		RE::Actor* a_actor,
		RE::TESFaction* a_currentFollowerFaction)
	{
		if (!a_actor) {
			return false;
		}

		if (a_actor->IsPlayerTeammate()) {
			return true;
		}

		if (a_currentFollowerFaction &&
			IsActorInFactionSafe(a_actor, a_currentFollowerFaction, "CurrentFollowerFaction")) {
			return true;
		}

		return false;
	}

	bool IsValidFollowerSexCandidate(
		RE::Actor* a_actor,
		RE::Actor* a_playerRef,
		RE::TESFaction* a_currentFollowerFaction,
		std::int32_t a_minRelationshipRank,
		float a_maxDistanceSquared,
		bool a_requireOppositeSex,
		bool a_requireLineOfSight)
	{
		if (!a_actor || !a_playerRef) {
			return false;
		}

		if (a_actor == a_playerRef) {
			return false;
		}

		if (a_actor->IsDead()) {
			return false;
		}

		if (a_actor->IsDisabled()) {
			return false;
		}

		if (a_actor->GetParentCell() != a_playerRef->GetParentCell()) {
			return false;
		}

		if (GetDistanceSquared(a_actor, a_playerRef) > a_maxDistanceSquared) {
			return false;
		}

		if (a_actor->IsInCombat()) {
			return false;
		}

		if (!IsFollowerCandidate(a_actor, a_currentFollowerFaction)) {
			return false;
		}

		if (a_requireOppositeSex) {
			const std::int32_t playerSex = GetActorSexSafe(a_playerRef);
			const std::int32_t actorSex = GetActorSexSafe(a_actor);

			if (playerSex < 0 || actorSex < 0) {
				return false;
			}

			if (playerSex == actorSex) {
				return false;
			}
		}

		if (a_minRelationshipRank > -4) {
			const std::int32_t relationshipRank = GetRelationshipRankSafe(a_actor, a_playerRef);

			if (relationshipRank < a_minRelationshipRank) {
				return false;
			}
		}

		if (a_requireLineOfSight && !HasClearLineOfSight(a_playerRef, a_actor)) {
			return false;
		}

		return true;
	}


	struct MenuGlobals
	{
		RE::TESGlobal* enabled{ nullptr };
		RE::TESGlobal* debug{ nullptr };
		RE::TESGlobal* useOStim{ nullptr };
		RE::TESGlobal* useSexLab{ nullptr };
	};

	std::mutex g_menuGlobalsLock;
	MenuGlobals g_menuGlobals;
	std::atomic_bool g_menuRegistered{ false };

	struct PersistentSettings
	{
		bool enabled{ true };
		bool debug{ false };
		bool useOStim{ true };
		bool useSexLab{ false };
	};

	bool GlobalBool(RE::TESGlobal* a_global, bool a_fallback = false)
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

namespace TMS_FollowerSexNative
{
	std::vector<RE::Actor*> FindFollowerSexCandidatesImpl(
		RE::Actor* a_playerRef,
		RE::TESFaction* a_currentFollowerFaction,
		std::int32_t a_minRelationshipRank,
		float a_maxDistance,
		bool a_requireOppositeSex,
		bool a_requireLineOfSight)
	{
		std::vector<RE::Actor*> result;

		a_minRelationshipRank = std::clamp(a_minRelationshipRank, -4, 4);

		if (a_maxDistance <= 0.0f) {
			a_maxDistance = 4096.0f;
		}

		const float maxDistanceSquared = a_maxDistance * a_maxDistance;

		SKSE::log::info(
			"FindFollowerSexCandidates called player={:08X} followerFaction={:08X} minRank={} maxDistance={} requireOppositeSex={} requireLOS={}",
			a_playerRef ? a_playerRef->GetFormID() : 0,
			a_currentFollowerFaction ? a_currentFollowerFaction->GetFormID() : 0,
			a_minRelationshipRank,
			a_maxDistance,
			a_requireOppositeSex,
			a_requireLineOfSight
		);

		if (!a_playerRef) {
			SKSE::log::warn("Invalid args: playerRef is null");
			return result;
		}

		auto* playerCell = a_playerRef->GetParentCell();
		if (!playerCell) {
			SKSE::log::warn("Player parent cell is null");
			return result;
		}

		if (!a_currentFollowerFaction) {
			SKSE::log::warn("CurrentFollowerFaction is null. Only IsPlayerTeammate() detection will be used.");
		}

		std::vector<std::pair<float, RE::Actor*>> candidatePool;

		std::uint32_t scannedActors = 0;
		std::uint32_t actorRefs = 0;
		std::uint32_t rejectedSelf = 0;
		std::uint32_t rejectedDead = 0;
		std::uint32_t rejectedDisabled = 0;
		std::uint32_t rejectedChild = 0;
		std::uint32_t rejectedWrongCell = 0;
		std::uint32_t rejectedTooFar = 0;
		std::uint32_t rejectedCombat = 0;
		std::uint32_t rejectedNotFollower = 0;
		std::uint32_t rejectedSex = 0;
		std::uint32_t rejectedRelationship = 0;
		std::uint32_t rejectedLOS = 0;
		std::uint32_t accepted = 0;

		playerCell->ForEachReference([&](RE::TESObjectREFR& a_ref) {
			++scannedActors;

			RE::Actor* actor = a_ref.As<RE::Actor>();
			if (!actor) {
				return RE::BSContainer::ForEachResult::kContinue;
			}

			++actorRefs;

			if (actor == a_playerRef) {
				++rejectedSelf;
				return RE::BSContainer::ForEachResult::kContinue;
			}

			if (actor->IsDead()) {
				++rejectedDead;
				return RE::BSContainer::ForEachResult::kContinue;
			}

			if (actor->IsDisabled()) {
				++rejectedDisabled;
				return RE::BSContainer::ForEachResult::kContinue;
			}

			if (actor->GetParentCell() != playerCell) {
				++rejectedWrongCell;
				return RE::BSContainer::ForEachResult::kContinue;
			}

			const float dist2 = GetDistanceSquared(actor, a_playerRef);
			if (dist2 > maxDistanceSquared) {
				++rejectedTooFar;
				return RE::BSContainer::ForEachResult::kContinue;
			}

			if (actor->IsInCombat()) {
				++rejectedCombat;
				return RE::BSContainer::ForEachResult::kContinue;
			}

			if (!IsFollowerCandidate(actor, a_currentFollowerFaction)) {
				++rejectedNotFollower;
				return RE::BSContainer::ForEachResult::kContinue;
			}

			if (a_requireOppositeSex) {
				const std::int32_t playerSex = GetActorSexSafe(a_playerRef);
				const std::int32_t actorSex = GetActorSexSafe(actor);

				if (playerSex < 0 || actorSex < 0 || playerSex == actorSex) {
					++rejectedSex;
					return RE::BSContainer::ForEachResult::kContinue;
				}
			}

			if (a_minRelationshipRank > -4) {
				const std::int32_t relationshipRank = GetRelationshipRankSafe(actor, a_playerRef);

				if (relationshipRank < a_minRelationshipRank) {
					++rejectedRelationship;
					return RE::BSContainer::ForEachResult::kContinue;
				}
			}

			if (a_requireLineOfSight && !HasClearLineOfSight(a_playerRef, actor)) {
				++rejectedLOS;
				return RE::BSContainer::ForEachResult::kContinue;
			}

			++accepted;
			candidatePool.emplace_back(dist2, actor);

			SKSE::log::info(
				"Accepted follower candidate actor={:08X} dist2={} sex={} relationshipRank={}",
				actor->GetFormID(),
				dist2,
				GetActorSexSafe(actor),
				GetRelationshipRankSafe(actor, a_playerRef)
			);

			return RE::BSContainer::ForEachResult::kContinue;
		});

		std::sort(
			candidatePool.begin(),
			candidatePool.end(),
			[](const auto& a_lhs, const auto& a_rhs) {
				return a_lhs.first < a_rhs.first;
			}
		);

		result.reserve(candidatePool.size());

		for (const auto& entry : candidatePool) {
			if (entry.second) {
				result.push_back(entry.second);
			}
		}

		SKSE::log::info(
			"Scan summary scannedRefs={} actorRefs={} accepted={} rejectedSelf={} rejectedDead={} rejectedDisabled={} rejectedChild={} rejectedWrongCell={} rejectedTooFar={} rejectedCombat={} rejectedNotFollower={} rejectedSex={} rejectedRelationship={} rejectedLOS={}",
			scannedActors,
			actorRefs,
			accepted,
			rejectedSelf,
			rejectedDead,
			rejectedDisabled,
			rejectedChild,
			rejectedWrongCell,
			rejectedTooFar,
			rejectedCombat,
			rejectedNotFollower,
			rejectedSex,
			rejectedRelationship,
			rejectedLOS
		);

		SKSE::log::info("FindFollowerSexCandidates returning {} candidates", result.size());

		return result;
	}

	std::vector<RE::Actor*> FindFollowerSexCandidates(
		RE::StaticFunctionTag*,
		RE::Actor* a_playerRef,
		RE::TESFaction* a_currentFollowerFaction,
		std::int32_t a_minRelationshipRank,
		float a_maxDistance,
		bool a_requireOppositeSex,
		bool a_requireLineOfSight)
	{
		return FindFollowerSexCandidatesImpl(
			a_playerRef,
			a_currentFollowerFaction,
			a_minRelationshipRank,
			a_maxDistance,
			a_requireOppositeSex,
			a_requireLineOfSight
		);
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

	bool RegisterFuncs(RE::BSScript::IVirtualMachine* a_vm)
	{
		a_vm->RegisterFunction(
			"FindFollowerSexCandidates",
			"TMS_FollowerSexNative",
			FindFollowerSexCandidates
		);

		SKSE::log::info("Registered Papyrus function: TMS_FollowerSexNative.FindFollowerSexCandidates");

		a_vm->RegisterFunction(
			"BindSettingsGlobals",
			"TMS_FollowerSexNative",
			BindSettingsGlobals
		);

		SKSE::log::info("Registered Papyrus function: TMS_FollowerSexNative.BindSettingsGlobals");

		return true;
	}
}

SKSEPluginLoad(const SKSE::LoadInterface* a_skse)
{
	InitializeLog();

	logger::info("{} plugin loading", kPluginName);

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
				RegisterSettingsMenu();
			}
		});
		logger::info("SKSE messaging listener registered");
	} else {
		logger::warn("SKSE messaging interface is null; SKSEMF menu cannot register");
	}

	logger::info("{} plugin loaded", kPluginName);

	return true;
}