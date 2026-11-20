#pragma once

#include <RE/Skyrim.h>
#include <cstdint>
#include <vector>

namespace TMS_FollowerSexNative
{
	std::vector<RE::Actor*> FindFollowerSexCandidatesImpl(
		RE::Actor* a_playerRef, RE::TESFaction* a_currentFollowerFaction,
		std::int32_t a_minRelationshipRank, float a_maxDistance,
		bool a_requireOppositeSex, bool a_requireLineOfSight);
}
