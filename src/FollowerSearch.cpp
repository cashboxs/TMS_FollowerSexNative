#include "PCH.h"
#include "FollowerSearch.h"
#include <cfloat>

namespace
{
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

}
