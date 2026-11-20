#include "PCH.h"
#include "Papyrus.h"
#include "FollowerSearch.h"
#include "Settings.h"

namespace TMS_FollowerSexNative
{
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
