Scriptname TMS_FollowerSexQuestScript extends Quest

; =========================================================
; TMS FS NSFW Quest
; - Male player + female follower line
; - OStim / SexLab runtime detect
; - OStim fixed highest priority
; =========================================================

; =========================================================
; Properties
; =========================================================

; --- Debug / General ---
Bool Property bDebug = False Auto
GlobalVariable Property TMS_FSDebugGV Auto
GlobalVariable Property TMS_FSEnableGV Auto
GlobalVariable Property TMS_FSUseOStimGV Auto
GlobalVariable Property TMS_FSUseSexLabGV Auto
GlobalVariable Property TMS_FSAddonMiniActiveGV Auto
GlobalVariable Property TMS_FSAddonMiniUntilGV Auto

Actor Property PlayerRef Auto
Faction Property CurrentFollowerFaction Auto
Keyword Property LocTypeDungeon Auto

; --- Follower scenes ---
Scene Property FollowerApproachScene Auto
Scene Property FollowerOstimAfterScene Auto

; --- OStim-only addon events ---
GlobalVariable Property TMS_FSAffectionDurationGV Auto ; shared timed hug duration
Scene Property FSCuddleSleepEventScene Auto

; Tap OStim's own Hide UI key for short addon mini scenes.
; Soft-resolved at runtime, so OStim is NOT a hard master.
; OStimKeyHideUI [GLOB:FE000EE9] -> local FormID 0x000EE9 in OStim.esp.
Bool Property ForceHideOStimUIDuringAddonMini = True Auto
Bool Property ForceDisableOStimAutoModeKeyDuringAddonMini = True Auto
Float Property FSAddonHideOStimUIDelay = 0.5 Auto
Float Property FSAddonRestoreOStimUIFallbackDelay = 3.0 Auto
Float Property FSHugRestoreOStimUIDelay = 6.0 Auto
Float Property FSCuddleSleepRestoreOStimUIDelay = 3.0 Auto
String Property OStimPluginFileName = "OStim.esp" Auto
Int Property OStimHideUIKeyFormID = 0x000EE9 Auto
Int Property OStimAutoModeKeyFormID = 0x000DEB Auto

Float Property FSAffectionDurationDefault = 12.0 Auto

Bool Property bFSCuddleSleepEventEnabled = True Auto

String Property FSHugMaleStartingAnim = "OARE_ActionMaleCaressHug" Auto
String Property FSHugFemaleStartingAnim = "OARE_ActionFemaleCaressHug" Auto
String Property FSCuddleSleepStartingAnim = "OARE_SpooningCuddling1" Auto

; 0 = male/female slot order, 1 = dom/sub slot order
Int Property FSHugSlotMode = 1 Auto
Int Property FSCuddleSleepSlotMode = 0 Auto

; only used when SlotMode == 1. False means follower is the active/dom actor.
Bool Property FSHugPlayerDom = True Auto
Bool Property FSCuddleSleepPlayerDom = False Auto

Float Property FSCuddleSleepMaxDistance = 2048.0 Auto
Float Property FSCuddleSleepCooldownHours = 8.0 Auto
Float Property FSCuddleSleepChance = 100.0 Auto
Float Property FSCuddleSleepStartHour = 20.0 Auto
Float Property FSCuddleSleepEndHour = 6.0 Auto
Float Property FSCuddleSleepSceneTimeout = 45.0 Auto

; --- Cold Weather Hug Event ---
Scene Property FSColdWeatherHugScene Auto
GlobalVariable Property GameHour Auto

Float Property FSColdWeatherHugCooldownHours = 12.0 Auto
Float Property FSColdWeatherHugChance = 100.0 Auto
Float Property FSColdWeatherHugPlayerMoveTolerance = 512.0 Auto
Float Property FSColdWeatherHugTimeout = 12.0 Auto
Float Property FSColdWeatherHugUpdateInterval = 1.0 Auto

; --- Male follower scenes ---
Scene Property MaleHomeScene Auto
Scene Property MaleHomeAfterScene Auto
Scene Property MaleCombatOverScene Auto
Scene Property MaleCombatOverAfterScene Auto

; --- Aliases / Globals ---
ReferenceAlias Property TMS_FollowerBaseAlias Auto
GlobalVariable Property TMS_FSStateGV Auto
GlobalVariable Property TMS_FSAfterSceneArmedGV Auto
GlobalVariable Property TMS_FSMaleWarmWindowGV Auto
GlobalVariable Property TMS_FSUseSmartStartGV Auto
GlobalVariable Property TMS_FSFollowerHelloGV Auto

; --- Dynamic follower selection ---
Bool Property bDynamicFollowerSelection = True Auto
Float Property DynamicFollowerScanRadius = 4096.0 Auto
Int Property DynamicFollowerMinRelationshipRank = 1 Auto
Bool Property DynamicFollowerRequireOppositeSex = True Auto
Bool Property DynamicFollowerRequireLOS = False Auto
Int Property MaleHomeFollowerRetryCount = 4 Auto
Float Property MaleHomeFollowerRetryDelay = 0.75 Auto

; --- Timing ---
Float Property FollowerCooldownHours = 24.0 Auto
Float Property MaleWarmCooldownHours = 6.0 Auto
Float Property MaleHomeTimeoutCleanupDelay = 10.0 Auto
Float Property WDWatchdogInterval = 0.5 Auto
Float Property CombatWindowSec = 60.0 Auto
Float Property CombatCheckDelaySec = 10.0 Auto
Float Property CombatCheckIntervalSec = 3.0 Auto

; --- Framework runtime config ---
String Property SexLabHookName = "TMSFS" Auto

; --- Cold Weather Hug runtime ---
Bool bColdWeatherHugPending = False
Actor ColdWeatherHugFollower = None

Float ColdWeatherHugAnchorX = 0.0
Float ColdWeatherHugAnchorY = 0.0
Float ColdWeatherHugAnchorZ = 0.0
Float ColdWeatherHugStartRT = 0.0
Float FSColdWeatherHugNextAllowedGT = 0.0


; =========================================================
; Runtime Variables
; =========================================================
Bool bWDUpdateQueued = False

Bool bMaleWarmArmed = False
Float MaleWarmUntilRT = 0.0
Float MaleWarmNextAllowedGT = 0.0
Int   MaleWarmToken = 0
Float MaleHomeTimeoutCleanupRT = 0.0

Bool bCombatWindowArmed = False
Location CombatWindowLoc = None
Float CombatWindowUntilRT = 0.0
Float CombatNextCheckRT = 0.0

Float FollowerNextAllowedGT = 0.0

; --- Framework detect ---
Bool bOStimInstalled = False
Bool bSexLabInstalled = False
Int  ActiveAdultFramework = 0
; 0 = none
; 1 = OStim
; 2 = SexLab

; --- OStim addon mini runtime ---
Bool bFSAddonMiniRunning = False
Bool bFSAddonMiniCleaning = False
Bool bFSAddonOStimUIToggled = False
Bool bFSAddonOStimUIHideRequested = False
Int ActiveAddonEventType = 0 ; 0 none, 1 hug, 2 kiss, 3 cuddle sleep
Int ActiveAddonThreadId = -1
Float FSAffectionEndRT = 0.0
ObjectReference ActiveCuddleSleepBedRef = None
Float CuddleSleepSceneStartRT = 0.0
Float FSCuddleSleepNextAllowedGT = 0.0

; Soft cache for OStimKeyHideUI. Do not bind OStim forms as properties, or OStim becomes a hard master.
GlobalVariable CachedOStimHideUIKeyGV = None
Bool bTriedResolveOStimHideUIKeyGV = False

; Soft cache for OStimKeyAutoMode. Romantic mini scenes temporarily disable the key and restore it at cleanup.
GlobalVariable CachedOStimAutoModeKeyGV = None
Bool bTriedResolveOStimAutoModeKeyGV = False
Bool bFSAddonAutoModeKeyDisabled = False
Int FSAddonAutoModeKeyOriginalValue = -999999


; =========================================================
; Logging
; =========================================================
Bool Function IsDebugOn()
	If TMS_FSDebugGV
		Return TMS_FSDebugGV.GetValueInt() == 1
	EndIf
	Return bDebug
EndFunction

Function L(String s)
	If IsDebugOn()
		Debug.Trace("[TMS FS] " + s)
	EndIf
EndFunction

Function LR(String s)
	L(s)
EndFunction

String Function BoolStr(Bool abValue)
	If abValue
		Return "1"
	EndIf
	Return "0"
EndFunction

String Function FrameworkName(Int aiFramework)
	If aiFramework == 1
		Return "OStim"
	ElseIf aiFramework == 2
		Return "SexLab"
	EndIf
	Return "None"
EndFunction


; =========================================================
; Lifecycle
; =========================================================
Event OnInit()
	EnsurePlayer()
	DetectAdultFramework()
	RegisterEvents()
	SyncDebugFromMCM()
EndEvent

Event OnPlayerLoadGame()
    EnsurePlayer()
    DetectAdultFramework()
    RegisterEvents()
    SyncDebugFromMCM()

    CloseMaleWarmWindow("loadgame_reset", 0)
    bMaleWarmArmed = False
    MaleWarmUntilRT = 0.0
    MaleHomeTimeoutCleanupRT = 0.0

    If TMS_FSMaleWarmWindowGV
        TMS_FSMaleWarmWindowGV.SetValueInt(0)
    EndIf

    ; If a save was made while a romantic mini had disabled OStim's auto-mode key, resolve the GV fresh and restore it before clearing runtime flags.
    CachedOStimAutoModeKeyGV = None
    bTriedResolveOStimAutoModeKeyGV = False
    FS_RestoreOStimAutoModeKeyForAddonMini("loadgame_safety")
    ClearAddonMiniLock("loadgame_safety")
    bFSAddonMiniRunning = False
    bFSAddonMiniCleaning = False
    ActiveAddonEventType = 0
    ActiveAddonThreadId = -1
    bFSAddonOStimUIToggled = False
    bFSAddonOStimUIHideRequested = False
    CachedOStimHideUIKeyGV = None
    bTriedResolveOStimHideUIKeyGV = False
    CachedOStimAutoModeKeyGV = None
    bTriedResolveOStimAutoModeKeyGV = False
    bFSAddonAutoModeKeyDisabled = False
    FSAddonAutoModeKeyOriginalValue = -999999
    FSAffectionEndRT = 0.0
    ActiveCuddleSleepBedRef = None
    CuddleSleepSceneStartRT = 0.0
    FSCuddleSleepNextAllowedGT = 0.0
    bColdWeatherHugPending = False
    ColdWeatherHugFollower = None
    ColdWeatherHugStartRT = 0.0
EndEvent

Event OnUpdate()
	EnsurePlayer()
	bWDUpdateQueued = False

	If bColdWeatherHugPending
		UpdateColdWeatherHugPending()
		Return
	EndIf

	TickMaleWarmWindow()
	TickCombatWindow()

	If bMaleWarmArmed || bCombatWindowArmed || MaleHomeTimeoutCleanupRT > 0.0
		StartWatchdogUpdates()
	EndIf


	If bFSAddonMiniRunning && ActiveAddonEventType == 1
		If FSAffectionEndRT > 0.0 && Utility.GetCurrentRealTime() >= FSAffectionEndRT
			CleanupHugOStimMini("duration")
			Return
		EndIf

		RegisterForSingleUpdate(0.5)
	EndIf

	If ActiveAddonEventType == 3 && !bFSAddonMiniRunning && CuddleSleepSceneStartRT > 0.0
		TickCuddleSleepTriggerScene()
		Return
	EndIf

	If bFSAddonMiniRunning && ActiveAddonEventType == 3
		RegisterForSingleUpdate(0.5)
	EndIf
EndEvent

Event OnOStimStart(String eventName, String strArg, Float numArg, Form sender)
	; OStim may create or recreate its UI during thread-start setup, so hide after ostim_start.
	If bFSAddonOStimUIHideRequested && ForceHideOStimUIDuringAddonMini
		If FSAddonHideOStimUIDelay > 0.0
			Utility.Wait(FSAddonHideOStimUIDelay)
		EndIf
		FS_HideOStimUIForAddonMini("addon mini thread start")
	EndIf

EndEvent

Event OnOStimEnd(String eventName, String strArg, Float numArg, Form sender)
	If bFSAddonMiniCleaning
		; Cleanup was initiated by our duration/key handler.
		; Do not restore UI here: OStim may still be playing its exit blend/transition.
		; The cleanup function owns the delayed restore.
		L("OnOStimEnd: addon cleanup already running; defer UI restore to cleanup wait")
		Return
	EndIf

	If bFSAddonMiniRunning
		If ActiveAddonEventType == 1
			CleanupHugOStimMini("ostim_end")
		ElseIf ActiveAddonEventType == 3
			CleanupCuddleSleepOStimMini("ostim_end")
		EndIf
		Return
	EndIf

	If ActiveAdultFramework != 1
		Return
	EndIf
	HandleAdultSceneEnd("OStim")
EndEvent

Event OnSexLabEnd(Int threadId, Bool hasPlayer)
	If ActiveAdultFramework != 2 || !hasPlayer
		Return
	EndIf
	HandleAdultSceneEnd("SexLab")
EndEvent


; =========================================================
; Framework Detect / Events
; =========================================================
Function DetectAdultFramework()
	bOStimInstalled = Game.IsPluginInstalled("OStim.esp")
	bSexLabInstalled = Game.IsPluginInstalled("SexLab.esm")

	ResolveAdultFrameworkPriority()

	L("Framework detect: OStim=" + BoolStr(bOStimInstalled) + " SL=" + BoolStr(bSexLabInstalled) + " Active=" + FrameworkName(ActiveAdultFramework))
EndFunction

Function ResolveAdultFrameworkPriority()
	ActiveAdultFramework = 0

	Bool useO = (TMS_FSUseOStimGV && TMS_FSUseOStimGV.GetValueInt() == 1)
	Bool useSL = (TMS_FSUseSexLabGV && TMS_FSUseSexLabGV.GetValueInt() == 1)

	L("ResolveAdultFrameworkPriority: useO=" + useO + " useSL=" + useSL + " bOStimInstalled=" + bOStimInstalled + " bSexLabInstalled=" + bSexLabInstalled)

	If useO && bOStimInstalled
		ActiveAdultFramework = 1
		L("Framework: OStim (selected)")
		Return
	EndIf

	If useSL && bSexLabInstalled
		ActiveAdultFramework = 2
		L("Framework: SexLab (selected)")
		Return
	EndIf

	L("Framework: none (disabled or not installed)")
EndFunction

Bool Function HasAdultFramework()
	ResolveAdultFrameworkPriority()
	L("HasAdultFramework: ActiveAdultFramework=" + ActiveAdultFramework)
	Return ActiveAdultFramework != 0
EndFunction

Function RegisterEvents()
	UnregisterForModEvent("ostim_start")
	RegisterForModEvent("ostim_start", "OnOStimStart")

	UnregisterForModEvent("ostim_end")
	RegisterForModEvent("ostim_end", "OnOStimEnd")

	; Clear old diagnostic ModEvent registration from previous test builds. Do not re-register.
	UnregisterForModEvent("TMS FS DEBUG SYNC")

	; SexLab hook end event (only meaningful if SexLab is installed)
	String slEndEvent = "HookAnimationEnd_" + SexLabHookName
	UnregisterForModEvent(slEndEvent)
	RegisterForModEvent(slEndEvent, "OnSexLabEnd")

	LR("RegisterEvents done")
	L("RegisterEvents done")
EndFunction


; =========================================================
; Shared Adult Scene End
; =========================================================
Function HandleAdultSceneEnd(String frameworkName)
	Int mode = 0
	If TMS_FSAfterSceneArmedGV
		mode = TMS_FSAfterSceneArmedGV.GetValueInt()
	EndIf

	If mode <= 0
		ClearAddonMiniLock(frameworkName + "End no after-scene")
		Return
	EndIf

	If TMS_FSAfterSceneArmedGV
		TMS_FSAfterSceneArmedGV.SetValueInt(0)
	EndIf

	Actor f = None
	If TMS_FollowerBaseAlias
		f = TMS_FollowerBaseAlias.GetActorReference()
	EndIf
	If mode == 11
		If f
			StartFollowerOstimAfterSceneWithTarget(f)
		Else
			StartFollowerOstimAfterScene()
		EndIf
		L(frameworkName + "End -> FollowerOnSitAfter")
		Return
	EndIf

	If !f
		L(frameworkName + "End target=None mode=" + mode)
		ClearAddonMiniLock(frameworkName + "End target none")
		Return
	EndIf

	If mode == 110
		L(frameworkName + "End -> MaleHomeAfter")
		StartMaleHomeAfterSceneWithTarget(f)
		Return

	ElseIf mode == 120
		L(frameworkName + "End -> MaleCombatOverAfter")
		StartMaleCombatOverAfterSceneWithTarget(f)
		Return
	EndIf

	L(frameworkName + "End unknown mode=" + mode)
	ClearAddonMiniLock(frameworkName + "End unknown mode")
EndFunction


; =========================================================
; Core Helpers
; =========================================================
Function EnsurePlayer()
	If !PlayerRef
		PlayerRef = Game.GetPlayer()
	EndIf
EndFunction

Bool Function IsEnabled()
	If !TMS_FSEnableGV
		Return True
	EndIf
	Return TMS_FSEnableGV.GetValueInt() == 1
EndFunction

Function SyncDebugFromMCM()
	; Legacy function name kept for save/alias compatibility.
	; SKSEMF edits the same four persistent GlobalVariables that the old MCM used.
	TMS_FollowerSexNative.BindSettingsGlobals(TMS_FSEnableGV, TMS_FSDebugGV, TMS_FSUseOStimGV, TMS_FSUseSexLabGV)

	If TMS_FSDebugGV
		bDebug = (TMS_FSDebugGV.GetValueInt() == 1)
		L("SyncDebugSetting GV=" + TMS_FSDebugGV.GetValueInt() + " bDebug=" + BoolStr(bDebug))
	Else
		; If the GV property is not bound, keep the serialized/property bDebug value as fallback.
		If bDebug
			Debug.Trace("[TMS FS] SyncDebugSetting GV=None; using bDebug property fallback")
		EndIf
	EndIf
EndFunction

Bool Function IsPlayerMale()
	Actor p = Game.GetPlayer()
	If !p
		Return False
	EndIf
	Return p.GetLeveledActorBase().GetSex() == 0
EndFunction

Bool Function IsPlayerFemale()
	Actor p = Game.GetPlayer()
	If !p
		Return False
	EndIf
	Return p.GetLeveledActorBase().GetSex() == 1
EndFunction

Bool Function StartSceneSimple(Scene scn)
	If !scn
		Return False
	EndIf
	If scn.IsPlaying()
		Return False
	EndIf

	scn.Start()
	Return True
EndFunction

Function StopSceneSimple(Scene scn)
	If scn && scn.IsPlaying()
		scn.Stop()
	EndIf
EndFunction

Function StartWatchdogUpdates()
	If (bMaleWarmArmed || bCombatWindowArmed || MaleHomeTimeoutCleanupRT > 0.0) && !bWDUpdateQueued
		bWDUpdateQueued = True
		RegisterForSingleUpdate(WDWatchdogInterval)
	EndIf
EndFunction

Int Function GetFSState()
    If !TMS_FSStateGV
        Return 0
    EndIf
    Return TMS_FSStateGV.GetValueInt()
EndFunction

Function SetFSState(Int aiState)
    If !TMS_FSStateGV
        Return
    EndIf
    TMS_FSStateGV.SetValueInt(aiState)
EndFunction

; =========================================================
; OStim-only Addon Event Helpers
; =========================================================

Bool Function IsOStimMode()
	If !TMS_FSUseOStimGV
		Return False
	EndIf

	Return TMS_FSUseOStimGV.GetValueInt() == 1
EndFunction
Bool Function CanRunOStimOnlyAddonEvent(String reason)
	If !IsEnabled()
		L("OStim addon BLOCK: disabled reason=" + reason)
		Return False
	EndIf

	ResolveAdultFrameworkPriority()

	If !IsOStimMode()
		L("OStim addon BLOCK: OStim mode off reason=" + reason)
		Return False
	EndIf

	; OStim-only addon only needs the resolved active framework to be OStim.
	; Do NOT reject merely because the SexLab toggle/GV is also on;
	; ResolveAdultFrameworkPriority() already gives OStim priority.
	If ActiveAdultFramework != 1
		L("OStim addon BLOCK: active framework not OStim active=" + ActiveAdultFramework + " reason=" + reason)
		Return False
	EndIf

	Return True
EndFunction

Function ClearStaleAddonLock(String reason)
	; Safety repair for saves where an addon prep state was left behind before the OStim mini actually started.
	; Do not clear a real running mini, and do not interrupt an active prep scene.
	If bFSAddonMiniRunning
		Return
	EndIf

	If ActiveAddonEventType == 3
		If FSCuddleSleepEventScene && FSCuddleSleepEventScene.IsPlaying()
			Return
		EndIf

		If GetFSState() == 220 || ActiveAddonThreadId < 0
			L("ClearStaleAddonLock: clearing stale CuddleSleep lock state=" + GetFSState() + " tid=" + ActiveAddonThreadId + " reason=" + reason)
			FS_RestoreOStimUIForAddonMini("stale CuddleSleep:" + reason)
			SetFSState(0)
			ActiveAddonEventType = 0
			ActiveAddonThreadId = -1
			bFSAddonMiniCleaning = False
			FSAffectionEndRT = 0.0
			ActiveCuddleSleepBedRef = None
			CuddleSleepSceneStartRT = 0.0
			ReleaseActiveFollower("Clear stale CuddleSleep lock:" + reason)
		EndIf
		Return
	EndIf

	If ActiveAddonEventType == 1
		If FSColdWeatherHugScene && FSColdWeatherHugScene.IsPlaying()
			Return
		EndIf

		If GetFSState() == 205 || GetFSState() == 210 || ActiveAddonThreadId < 0
			L("ClearStaleAddonLock: clearing stale Hug lock state=" + GetFSState() + " tid=" + ActiveAddonThreadId + " reason=" + reason)
			FS_RestoreOStimUIForAddonMini("stale Hug:" + reason)
			SetFSState(0)
			ActiveAddonEventType = 0
			ActiveAddonThreadId = -1
			bFSAddonMiniCleaning = False
			FSAffectionEndRT = 0.0
			bColdWeatherHugPending = False
			ColdWeatherHugFollower = None
			ColdWeatherHugStartRT = 0.0
			ReleaseActiveFollower("Clear stale Hug lock:" + reason)
		EndIf
		Return
	EndIf
EndFunction

Int Function GetActorSexSafe(Actor akActor)
	If !akActor
		Return -1
	EndIf

	ActorBase ab = akActor.GetLeveledActorBase()
	If !ab
		Return -1
	EndIf

	Return ab.GetSex()
EndFunction

Bool Function IsMaleActor(Actor akActor)
	Return GetActorSexSafe(akActor) == 0
EndFunction

Bool Function IsFemaleActor(Actor akActor)
	Return GetActorSexSafe(akActor) == 1
EndFunction

Actor Function GetMaleActorInPair(Actor akFollower)
	EnsurePlayer()

	If PlayerRef && IsMaleActor(PlayerRef)
		Return PlayerRef
	EndIf

	If akFollower && IsMaleActor(akFollower)
		Return akFollower
	EndIf

	Return None
EndFunction

Actor Function GetFemaleActorInPair(Actor akFollower)
	EnsurePlayer()

	If PlayerRef && IsFemaleActor(PlayerRef)
		Return PlayerRef
	EndIf

	If akFollower && IsFemaleActor(akFollower)
		Return akFollower
	EndIf

	Return None
EndFunction

Actor Function GetAddonFollower(String reason)
	Actor f = None

	If TMS_FollowerBaseAlias
		f = TMS_FollowerBaseAlias.GetActorReference()
	EndIf

	If f
		Return f
	EndIf

	; Requires the dynamic alias resolver from the previous step.
	f = ResolveFollowerForEvent("Addon:" + reason)

	Return f
EndFunction

Actor[] Function BuildMiniActorArray(Actor akFollower, Int aiSlotMode, Bool abPlayerDom, String reason)
	EnsurePlayer()

	If !PlayerRef || !akFollower
		L("BuildMiniActorArray failed: player/follower none reason=" + reason)
		Return None
	EndIf

	Actor[] actors = new Actor[2]

	If aiSlotMode == 1
		; dom/sub order
		If abPlayerDom
			actors[0] = PlayerRef
			actors[1] = akFollower
			L("BuildMiniActorArray dom/sub: player dom reason=" + reason)
		Else
			actors[0] = akFollower
			actors[1] = PlayerRef
			L("BuildMiniActorArray dom/sub: follower dom reason=" + reason)
		EndIf

		Return actors
	EndIf

	; default: male/female order
	Actor maleActor = GetMaleActorInPair(akFollower)
	Actor femaleActor = GetFemaleActorInPair(akFollower)

	If !maleActor || !femaleActor
		L("BuildMiniActorArray failed: missing male/female actor reason=" + reason + " playerSex=" + GetActorSexSafe(PlayerRef) + " followerSex=" + GetActorSexSafe(akFollower))
		Return None
	EndIf

	actors[0] = maleActor
	actors[1] = femaleActor

	L("BuildMiniActorArray male/female OK male=" + maleActor + " female=" + femaleActor + " reason=" + reason)

	Return actors
EndFunction

Actor Function GetMiniDomActor(Actor akFollower, Bool abPlayerDom)
	EnsurePlayer()

	If abPlayerDom
		Return PlayerRef
	EndIf

	Return akFollower
EndFunction

String Function PickMiniAnimByDomSex(Actor akFollower, String maleAnim, String femaleAnim, Bool abPlayerDom, String reason)
	Actor domActor = GetMiniDomActor(akFollower, abPlayerDom)
	Int sex = GetActorSexSafe(domActor)

	If sex == 0
		L("PickMiniAnimByDomSex male anim=" + maleAnim + " reason=" + reason)
		Return maleAnim
	EndIf

	If sex == 1
		L("PickMiniAnimByDomSex female anim=" + femaleAnim + " reason=" + reason)
		Return femaleAnim
	EndIf

	L("PickMiniAnimByDomSex fallback male anim=" + maleAnim + " reason=" + reason)
	Return maleAnim
EndFunction

Int Function StartOStimMiniWithSlotRule_ReturnTid(Actor akFollower, String startingAnim, Int aiSlotMode, Bool abPlayerDom, String reason)
	If !CanRunOStimOnlyAddonEvent("Mini:" + reason)
		Return -1
	EndIf

	If !akFollower
		L("StartOStimMini BLOCK: follower=None reason=" + reason)
		Return -1
	EndIf

	Actor[] actors = BuildMiniActorArray(akFollower, aiSlotMode, abPlayerDom, reason)

	If !actors || actors.Length < 2
		L("StartOStimMini BLOCK: actor array invalid reason=" + reason)
		Return -1
	EndIf

	If !actors[0] || !actors[1]
		L("StartOStimMini BLOCK: actor slot none reason=" + reason)
		Return -1
	EndIf

	; Important: this mini scene should not arm another after-scene chain.
	If TMS_FSAfterSceneArmedGV
		TMS_FSAfterSceneArmedGV.SetValueInt(0)
	EndIf

	Int tid = StartOStimMiniNoFurniture(actors, startingAnim, reason)
	L("StartOStimMini tid=" + tid + " anim=" + startingAnim + " reason=" + reason)

	Return tid
EndFunction
Bool Function IsActorOnBed(Actor akActor)
	If !akActor
		Return False
	EndIf

	ObjectReference furn = akActor.GetFurnitureReference()
	If !furn
		Return False
	EndIf

	String furnType = OFurniture.GetFurnitureType(furn)
	If furnType == "" || furnType == "none"
		Return False
	EndIf

	Return OFurniture.IsChildOf("bed", furnType)
EndFunction

Bool Function IsCuddleSleepPairReady(Actor akFollower, String reason, ObjectReference akEventBed = None)
	EnsurePlayer()

	If !PlayerRef || !akFollower
		L("CuddleSleep pair blocked: player/follower none reason=" + reason)
		Return False
	EndIf

	If PlayerRef.IsInCombat() || akFollower.IsInCombat()
		L("CuddleSleep pair blocked: combat reason=" + reason)
		Return False
	EndIf

	If PlayerRef.GetParentCell() != akFollower.GetParentCell()
		L("CuddleSleep pair blocked: different cell reason=" + reason)
		Return False
	EndIf

	If PlayerRef.GetDistance(akFollower) > FSCuddleSleepMaxDistance
		L("CuddleSleep pair blocked: too far distance=" + PlayerRef.GetDistance(akFollower) + " reason=" + reason)
		Return False
	EndIf

	If IsFurnitureBed(akEventBed)
		If akEventBed.GetParentCell() != PlayerRef.GetParentCell()
			L("CuddleSleep pair blocked: event bed different cell bed=" + akEventBed + " reason=" + reason)
			Return False
		EndIf
		Return True
	EndIf

	If IsFurnitureBed(ActiveCuddleSleepBedRef)
		If ActiveCuddleSleepBedRef.GetParentCell() != PlayerRef.GetParentCell()
			L("CuddleSleep pair blocked: active bed different cell bed=" + ActiveCuddleSleepBedRef + " reason=" + reason)
			Return False
		EndIf
		Return True
	EndIf

	If !IsActorOnBed(PlayerRef) && !IsActorOnBed(akFollower)
		L("CuddleSleep pair blocked: neither actor on bed reason=" + reason)
		Return False
	EndIf

	Return True
EndFunction

Float Function GetFSAffectionDuration()
	Float dur = FSAffectionDurationDefault

	If TMS_FSAffectionDurationGV
		dur = TMS_FSAffectionDurationGV.GetValue()
	EndIf

	If dur < 3.0
		dur = 3.0
	EndIf

	If dur > 120.0
		dur = 120.0
	EndIf

	Return dur
EndFunction

GlobalVariable Function GetOStimHideUIKeyGV()
	If CachedOStimHideUIKeyGV
		Return CachedOStimHideUIKeyGV
	EndIf

	If bTriedResolveOStimHideUIKeyGV
		Return None
	EndIf

	bTriedResolveOStimHideUIKeyGV = True

	If OStimPluginFileName == ""
		L("GetOStimHideUIKeyGV: plugin filename empty")
		Return None
	EndIf

	If OStimHideUIKeyFormID <= 0
		L("GetOStimHideUIKeyGV: form id not set")
		Return None
	EndIf

	Form f = Game.GetFormFromFile(OStimHideUIKeyFormID, OStimPluginFileName)
	If !f
		L("GetOStimHideUIKeyGV: form not found file=" + OStimPluginFileName + " id=" + (OStimHideUIKeyFormID as String))
		Return None
	EndIf

	CachedOStimHideUIKeyGV = f as GlobalVariable
	If !CachedOStimHideUIKeyGV
		L("GetOStimHideUIKeyGV: form is not GlobalVariable form=" + f)
		Return None
	EndIf

	L("GetOStimHideUIKeyGV: resolved gv=" + CachedOStimHideUIKeyGV)
	Return CachedOStimHideUIKeyGV
EndFunction

Bool Function FS_TapOStimHideUI()
	GlobalVariable keyGV = GetOStimHideUIKeyGV()
	If !keyGV
		L("FS_TapOStimHideUI: keyGV none")
		Return False
	EndIf

	Int keyCode = keyGV.GetValueInt()
	If keyCode <= 0
		L("FS_TapOStimHideUI: key not set (<=0) key=" + (keyCode as String))
		Return False
	EndIf

	Input.TapKey(keyCode)
	L("FS_TapOStimHideUI: TapKey=" + (keyCode as String))
	Return True
EndFunction

Function FS_RequestHideOStimUIForAddonMini(String reason)
	If !ForceHideOStimUIDuringAddonMini
		Return
	EndIf

	bFSAddonOStimUIToggled = False
	bFSAddonOStimUIHideRequested = True
	L("Addon OStim UI hide requested. reason=" + reason)
EndFunction

Function FS_HideOStimUIForAddonMini(String reason)
	If !ForceHideOStimUIDuringAddonMini
		Return
	EndIf

	If bFSAddonOStimUIToggled
		Return
	EndIf

	If FS_TapOStimHideUI()
		bFSAddonOStimUIToggled = True
		L("Addon OStim UI hidden. reason=" + reason)
	EndIf
EndFunction

Function FS_RestoreOStimUIForAddonMini(String reason)
	bFSAddonOStimUIHideRequested = False

	If !bFSAddonOStimUIToggled
		Return
	EndIf

	If FS_TapOStimHideUI()
		L("Addon OStim UI restored. reason=" + reason)
	EndIf

	bFSAddonOStimUIToggled = False
EndFunction

Function StopActiveAddonOStimThread(String reason)
	If ActiveAddonThreadId < 0
		L("StopActiveAddonOStimThread skipped: no active tid reason=" + reason)
		bFSAddonMiniRunning = False
		Return
	EndIf

	Int oldTid = ActiveAddonThreadId
	ActiveAddonThreadId = -1
	bFSAddonMiniRunning = False

	L("StopActiveAddonOStimThread tid=" + oldTid + " reason=" + reason)
	OThread.Stop(oldTid)
EndFunction

GlobalVariable Function GetOStimAutoModeKeyGV()
	If CachedOStimAutoModeKeyGV
		Return CachedOStimAutoModeKeyGV
	EndIf

	If bTriedResolveOStimAutoModeKeyGV
		Return None
	EndIf

	bTriedResolveOStimAutoModeKeyGV = True

	If OStimPluginFileName == ""
		L("GetOStimAutoModeKeyGV BLOCK: plugin filename empty")
		Return None
	EndIf

	If OStimAutoModeKeyFormID <= 0
		L("GetOStimAutoModeKeyGV BLOCK: form id not set")
		Return None
	EndIf

	Form f = Game.GetFormFromFile(OStimAutoModeKeyFormID, OStimPluginFileName)
	If !f
		L("GetOStimAutoModeKeyGV BLOCK: form not found file=" + OStimPluginFileName + " id=" + (OStimAutoModeKeyFormID as String))
		Return None
	EndIf

	CachedOStimAutoModeKeyGV = f as GlobalVariable
	If !CachedOStimAutoModeKeyGV
		L("GetOStimAutoModeKeyGV BLOCK: form is not GlobalVariable form=" + f)
		Return None
	EndIf

	L("GetOStimAutoModeKeyGV PASS: resolved gv=" + CachedOStimAutoModeKeyGV)
	Return CachedOStimAutoModeKeyGV
EndFunction

Function FS_DisableOStimAutoModeKeyForAddonMini(String reason)
	If !ForceDisableOStimAutoModeKeyDuringAddonMini
		Return
	EndIf

	If bFSAddonAutoModeKeyDisabled
		Return
	EndIf

	GlobalVariable keyGV = GetOStimAutoModeKeyGV()
	If !keyGV
		L("Addon OStim auto mode key BLOCK: keyGV none reason=" + reason)
		Return
	EndIf

	FSAddonAutoModeKeyOriginalValue = keyGV.GetValueInt()
	keyGV.SetValueInt(-1)
	bFSAddonAutoModeKeyDisabled = True

	L("Addon OStim auto mode key disabled original=" + (FSAddonAutoModeKeyOriginalValue as String) + " reason=" + reason)
EndFunction

Function FS_RestoreOStimAutoModeKeyForAddonMini(String reason)
	If !bFSAddonAutoModeKeyDisabled
		Return
	EndIf

	GlobalVariable keyGV = GetOStimAutoModeKeyGV()
	If !keyGV
		L("Addon OStim auto mode key restore BLOCK: keyGV none reason=" + reason)
		bFSAddonAutoModeKeyDisabled = False
		FSAddonAutoModeKeyOriginalValue = -999999
		Return
	EndIf

	If FSAddonAutoModeKeyOriginalValue != -999999
		keyGV.SetValueInt(FSAddonAutoModeKeyOriginalValue)
		L("Addon OStim auto mode key restored key=" + (FSAddonAutoModeKeyOriginalValue as String) + " reason=" + reason)
	Else
		L("Addon OStim auto mode key restore BLOCK: original value missing reason=" + reason)
	EndIf

	bFSAddonAutoModeKeyDisabled = False
	FSAddonAutoModeKeyOriginalValue = -999999
EndFunction

; =========================================================
; Follower Core
; =========================================================
Bool Function IsFollowerActorUsable(Actor akActor)
	EnsurePlayer()

	If !akActor
		Return False
	EndIf

	If !PlayerRef
		Return False
	EndIf

	If akActor == PlayerRef
		Return False
	EndIf

	If akActor.IsDead()
		Return False
	EndIf

	If akActor.IsDisabled()
		Return False
	EndIf

	If akActor.IsInCombat()
		Return False
	EndIf

	If akActor.GetParentCell() != PlayerRef.GetParentCell()
		Return False
	EndIf

	Bool isFollower = False

	If akActor.IsPlayerTeammate()
		isFollower = True
	EndIf

	If !isFollower && CurrentFollowerFaction && akActor.IsInFaction(CurrentFollowerFaction)
		isFollower = True
	EndIf

	If !isFollower
		Return False
	EndIf

	Return True
EndFunction

Actor Function GetActiveFollower()
	If !TMS_FollowerBaseAlias
		Return None
	EndIf

	Actor f = TMS_FollowerBaseAlias.GetActorReference()
	If IsFollowerActorUsable(f)
		Return f
	EndIf

	Return None
EndFunction

Bool Function BindActiveFollower(Actor akFollower, String reason)
	If !TMS_FollowerBaseAlias
		L("BindActiveFollower blocked: alias=None reason=" + reason)
		Return False
	EndIf

	If !IsFollowerActorUsable(akFollower)
		L("BindActiveFollower blocked: invalid follower=" + akFollower + " reason=" + reason)
		Return False
	EndIf

	TMS_FollowerBaseAlias.ForceRefTo(akFollower as ObjectReference)
	L("BindActiveFollower OK follower=" + akFollower + " reason=" + reason)
	Return True
EndFunction

Actor Function PickDynamicFollower(String reason)
	EnsurePlayer()

	If !PlayerRef
		L("PickDynamicFollower failed: PlayerRef=None reason=" + reason)
		Return None
	EndIf

	If !bDynamicFollowerSelection
		L("PickDynamicFollower skipped: dynamic disabled reason=" + reason)
		Return None
	EndIf

	Actor[] candidates = TMS_FollowerSexNative.FindFollowerSexCandidates(PlayerRef, CurrentFollowerFaction, DynamicFollowerMinRelationshipRank, DynamicFollowerScanRadius, DynamicFollowerRequireOppositeSex, DynamicFollowerRequireLOS)

	If !candidates
		L("PickDynamicFollower failed: candidates=None reason=" + reason)
		Return None
	EndIf

	If candidates.Length <= 0
		L("PickDynamicFollower failed: no candidates reason=" + reason)
		Return None
	EndIf

	Int idx = Utility.RandomInt(0, candidates.Length - 1)
	Actor picked = candidates[idx]

	If !picked
		L("PickDynamicFollower failed: picked=None count=" + candidates.Length + " reason=" + reason)
		Return None
	EndIf

	If !BindActiveFollower(picked, reason)
		Return None
	EndIf

	L("PickDynamicFollower OK picked=" + picked + " index=" + idx + " count=" + candidates.Length + " reason=" + reason)
	Return picked
EndFunction

Actor Function ResolveFollowerForEvent(String reason)
	Actor picked = PickDynamicFollower(reason)
	If picked
		Return picked
	EndIf

	Actor cur = GetActiveFollower()
	If cur
		L("ResolveFollowerForEvent fallback active=" + cur + " reason=" + reason)
		Return cur
	EndIf

	L("ResolveFollowerForEvent failed reason=" + reason)
	Return None
EndFunction

Actor Function ResolveFollowerForEventRetry(String reason, Int attempts, Float waitSeconds)
	If attempts <= 1
		Return ResolveFollowerForEvent(reason + ":try0")
	EndIf

	Actor f = None
	Int i = 0

	While i < attempts
		f = ResolveFollowerForEvent(reason + ":try" + (i as String))
		If f
			If i > 0
				L("ResolveFollowerForEventRetry PASS: follower found try=" + (i as String) + " reason=" + reason + " follower=" + f)
			EndIf
			Return f
		EndIf

		i += 1
		If i < attempts && waitSeconds > 0.0
			L("ResolveFollowerForEventRetry WAIT: no follower yet try=" + (i as String) + "/" + (attempts as String) + " delay=" + waitSeconds + " reason=" + reason)
			Utility.Wait(waitSeconds)
		EndIf
	EndWhile

	L("ResolveFollowerForEventRetry BLOCK: no follower after attempts=" + (attempts as String) + " reason=" + reason)
	Return None
EndFunction

Function ReleaseActiveFollower(String reason)
	Actor old = None

	If TMS_FollowerBaseAlias
		old = TMS_FollowerBaseAlias.GetActorReference()
		TMS_FollowerBaseAlias.Clear()
	EndIf

	If TMS_FSFollowerHelloGV
		TMS_FSFollowerHelloGV.SetValueInt(0)
	EndIf

	L("ReleaseActiveFollower old=" + old + " reason=" + reason)
EndFunction

Function FollowerRemark(Actor akSpeaker)
	If !IsEnabled()
		L("FollowerRemark blocked: disabled")
		Return
	EndIf

	If !akSpeaker
		L("FollowerRemark blocked: akSpeaker=None")
		Return
	EndIf

	; V2: manual dialogue remark becomes optional manual target binding.
	BindActiveFollower(akSpeaker, "FollowerRemark")
EndFunction

; =========================================================
; Follower Scenes
; =========================================================
Bool Function StartFollowerApproachScene_Bool()
	If StartSceneSimple(FollowerApproachScene)
		L("FollowerApproachScene START")
		Return True
	EndIf
	Return False
EndFunction

Function StartFollowerApproachSceneWithTarget(Actor akTarget)
	If !akTarget
		Return
	EndIf

	If TMS_FollowerBaseAlias
		TMS_FollowerBaseAlias.ForceRefTo(akTarget as ObjectReference)
	EndIf

	StartFollowerApproachScene_Bool()
EndFunction

Function TryStartFollowerApproachScene(String reason)
	If !IsEnabled()
		L("TryStartFollowerApproachScene blocked: disabled reason=" + reason)
		Return
	EndIf

	If !CanStartNewEventStrict("FollowerApproach:" + reason)
		Return
	EndIf

	Actor p = Game.GetPlayer()
	If !p || p.IsInCombat()
		L("TryStartFollowerApproachScene blocked: player invalid/combat reason=" + reason)
		Return
	EndIf

	Float now = Utility.GetCurrentGameTime()
	If now < FollowerNextAllowedGT
		L("TryStartFollowerApproachScene blocked: cooldown reason=" + reason)
		Return
	EndIf

	If !FollowerApproachScene || FollowerApproachScene.IsPlaying()
		L("TryStartFollowerApproachScene blocked: scene none/playing reason=" + reason)
		Return
	EndIf

	Actor f = ResolveFollowerForEvent("FollowerApproach:" + reason)
	If !f
		L("TryStartFollowerApproachScene blocked: no follower reason=" + reason)
		Return
	EndIf

	Bool ok = StartFollowerApproachScene_Bool()
	If ok
		FollowerNextAllowedGT = now + (FollowerCooldownHours / 24.0)
		L("FollowerApproach cooldown set reason=" + reason)
	EndIf
EndFunction
Function StartFollowerOstimAfterScene()
	If StartSceneSimple(FollowerOstimAfterScene)
		L("FollowerOstimAfterScene START")
	Else
		L("FollowerOstimAfterScene start FAILED")
		ClearAddonMiniLock("FollowerOstimAfterScene start failed")
	EndIf
EndFunction

Function StartFollowerOstimAfterSceneWithTarget(Actor akTarget)
	If !akTarget
		Return
	EndIf

	If TMS_FollowerBaseAlias
		TMS_FollowerBaseAlias.ForceRefTo(akTarget as ObjectReference)
	EndIf

	StartFollowerOstimAfterScene()
EndFunction

Function CleanupFollowerOstimAfterScene()
	StopSceneSimple(FollowerOstimAfterScene)

	ClearAddonMiniLock("FollowerOstimAfterScene done")
	ReleaseActiveFollower("FollowerOstimAfterScene done")
EndFunction

Function CleanupFollowerApproachScene()
	StopSceneSimple(FollowerApproachScene)
EndFunction


; =========================================================
; Adult Scene Start (OStim / SexLab)
; =========================================================
Function StartFollowerOstimScene(Actor npc, Int afterMode)
	StartFollowerSceneByBestFramework(npc, afterMode)
EndFunction

Bool Function StartFollowerSceneByBestFramework(Actor npc, Int afterMode)
	If !npc
		L("StartFollowerScene blocked: npc=None")
		Return False
	EndIf

	If !HasAdultFramework()
		L("StartFollowerScene blocked: no adult framework")
		Return False
	EndIf

	If ActiveAdultFramework == 1
		L("StartFollowerScene -> OStim")
		StartFollowerOstimScene_Impl(npc, afterMode)
		Return True
	ElseIf ActiveAdultFramework == 2
		L("StartFollowerScene -> SexLab")
		Return StartFollowerSexLabScene_Impl(npc, afterMode)
	EndIf

	L("StartFollowerScene blocked: unknown framework")
	Return False
EndFunction

Function StartFollowerOstimScene_Impl(Actor npc, Int afterMode)
	If !npc
		Return
	EndIf

	If TMS_FollowerBaseAlias
		TMS_FollowerBaseAlias.ForceRefTo(npc as ObjectReference)
	EndIf

	If afterMode == 110
		MaleHomeTimeoutCleanupRT = 0.0
	EndIf

	If TMS_FSAfterSceneArmedGV
		TMS_FSAfterSceneArmedGV.SetValueInt(afterMode)
	EndIf

	L("Follower OStim start afterMode=" + afterMode + " npc=" + npc)

	Actor player = Game.GetPlayer()
	Actor[] actors = new Actor[2]
	actors[0] = player
	actors[1] = npc

	StartThreadSmartOrOstim(actors)
EndFunction

Bool Function StartFollowerSexLabScene_Impl(Actor npc, Int afterMode)
	If !npc
		Return False
	EndIf

	If !bSexLabInstalled
		L("SexLab start blocked: SexLab not installed")
		Return False
	EndIf

	EnsurePlayer()
	If !PlayerRef
		L("SexLab start blocked: PlayerRef=None")
		Return False
	EndIf

	If TMS_FollowerBaseAlias
		TMS_FollowerBaseAlias.ForceRefTo(npc as ObjectReference)
	EndIf

	If afterMode == 110
		MaleHomeTimeoutCleanupRT = 0.0
	EndIf

	If TMS_FSAfterSceneArmedGV
		TMS_FSAfterSceneArmedGV.SetValueInt(afterMode)
	EndIf

	L("Follower SexLab start afterMode=" + afterMode + " npc=" + npc + " hook=" + SexLabHookName)

	; NOTE:
	; This is still a runtime soft dependency for players,
	; but YOU need SexLab papyrus source in your local compile environment.
	SexLabUtil.QuickStart(PlayerRef, npc, None, None, None, None, SexLabHookName, "")

	Return True
EndFunction

Int Function StartThreadSmartOrOstim(Actor[] actors, String startingAnim = "")
	; Tell ATJ and other companion addons that this OStim thread belongs to FS before OStim fires ostim_start.
	ArmAddonMiniLock("FS OStim start")

	If TMS_FSUseSmartStartGV && TMS_FSUseSmartStartGV.GetValueInt() == 1
		Int tid = QuickStartSmart(actors, startingAnim)
		L("StartThreadEntry -> SMART tid=" + tid)
		If tid < 0
			ClearAddonMiniLock("FS OStim smart start failed")
		EndIf
		Return tid
	EndIf

	If startingAnim != ""
		Int tidWithAnim = OThread.QuickStart(actors, startingAnim, None)
		L("StartThreadEntry -> OSTIM_DEFAULT anim tid=" + tidWithAnim + " anim=" + startingAnim)
		If tidWithAnim < 0
			ClearAddonMiniLock("FS OStim anim start failed")
		EndIf
		Return tidWithAnim
	EndIf

	Int tid = OThread.QuickStart(actors)
	L("StartThreadEntry -> OSTIM_DEFAULT tid=" + tid)
	If tid < 0
		ClearAddonMiniLock("FS OStim default start failed")
	EndIf
	Return tid
EndFunction

Int Function QuickStartSmart(Actor[] actors, String startingAnim = "")
	If !actors || actors.Length == 0
		L("QuickStartSmart aborted: actors empty")
		Return -1
	EndIf

	Actor player = Game.GetPlayer()
	ObjectReference chosenFurn = None

	If player
		ObjectReference fp = player.GetFurnitureReference()
		If fp
			chosenFurn = fp
		EndIf
	EndIf

	If chosenFurn && actors.Length > 2
		If !IsBedForGroup(chosenFurn, actors.Length)
			L("QuickStartSmart: player furniture blocked for group")
			chosenFurn = None
		EndIf
	EndIf

	If !chosenFurn
		Int i = 0
		While i < actors.Length && !chosenFurn
			Actor a = actors[i]
			If a
				ObjectReference f = a.GetFurnitureReference()
				If f
					If actors.Length > 2
						If IsBedForGroup(f, actors.Length)
							chosenFurn = f
						EndIf
					Else
						chosenFurn = f
					EndIf
				EndIf
			EndIf
			i += 1
		EndWhile
	EndIf

	If !chosenFurn && actors.Length > 2
		ObjectReference centerRef = player as ObjectReference
		If !centerRef && actors[0]
			centerRef = actors[0] as ObjectReference
		EndIf

		If centerRef
			ObjectReference cand = OFurniture.FindFurnitureOfType("bed", centerRef, 250.0, 128.0)
			If cand && IsBedForGroup(cand, actors.Length)
				chosenFurn = cand
				L("QuickStartSmart: found nearest bed")
			EndIf
		EndIf
	EndIf

	If !chosenFurn && actors.Length > 2
		L("QuickStartSmart: no bed found, fallback")
		Return OThread.QuickStart(actors, startingAnim, None)
	EndIf

	If chosenFurn
		L("QuickStartSmart: use furniture")
		Return OThread.QuickStart(actors, startingAnim, chosenFurn)
	EndIf

	L("QuickStartSmart: no furniture, fallback")
	Return OThread.QuickStart(actors, startingAnim, None)
EndFunction

Bool Function IsBedForGroup(ObjectReference furn, Int actorCount)
	If !furn
		Return False
	EndIf
	If actorCount <= 2
		Return True
	EndIf

	String t = OFurniture.GetFurnitureType(furn)
	If t == "" || t == "none"
		Return False
	EndIf

	Return OFurniture.IsChildOf("bed", t)
EndFunction


; =========================================================
; MaleWarm / Home
; =========================================================
Bool Function CanOpenMaleWarmWindow()
	If MaleWarmCooldownHours <= 0.0
		Return True
	EndIf
	Return Utility.GetCurrentGameTime() >= MaleWarmNextAllowedGT
EndFunction

Bool Function IsMaleWarmWindowOpen()
	Return bMaleWarmArmed
EndFunction

Int Function OpenMaleWarmWindow(Float seconds, String reason)
	If seconds <= 0.0
		seconds = 30.0
	EndIf

	If !CanOpenMaleWarmWindow()
		L("MaleWarmWindow OPEN blocked reason=" + reason)
		Return 0
	EndIf

	MaleWarmToken += 1
	Int token = MaleWarmToken

	MaleWarmUntilRT = Utility.GetCurrentRealTime() + seconds
	bMaleWarmArmed = True
	MaleHomeTimeoutCleanupRT = 0.0

	If TMS_FSMaleWarmWindowGV
		TMS_FSMaleWarmWindowGV.SetValueInt(1)
	EndIf

	If MaleWarmCooldownHours > 0.0
		MaleWarmNextAllowedGT = Utility.GetCurrentGameTime() + (MaleWarmCooldownHours / 24.0)
	EndIf

	StartWatchdogUpdates()
	L("MaleWarmWindow OPEN token=" + token + " reason=" + reason)
	Return token
EndFunction

Function CloseMaleWarmWindow(String reason, Int token)
	If token != 0 && token != MaleWarmToken
		L("MaleWarmWindow CLOSE ignored stale token reason=" + reason)
		Return
	EndIf

	If !bMaleWarmArmed
		Return
	EndIf

	bMaleWarmArmed = False
	MaleWarmUntilRT = 0.0

	If TMS_FSMaleWarmWindowGV
		TMS_FSMaleWarmWindowGV.SetValueInt(0)
	EndIf

	L("MaleWarmWindow CLOSE reason=" + reason)
EndFunction

Function TickMaleWarmWindow()
	Float now = Utility.GetCurrentRealTime()

	If bMaleWarmArmed && MaleWarmUntilRT > 0.0 && now >= MaleWarmUntilRT
		CloseMaleWarmWindow("timeout", 0)

		If GetFSState() == 11
			Float delay = MaleHomeTimeoutCleanupDelay
			If delay < 1.0
				delay = 1.0
			EndIf

			MaleHomeTimeoutCleanupRT = now + delay
			L("MaleHome timeout cleanup armed rt=" + MaleHomeTimeoutCleanupRT)
		EndIf
	EndIf

	TickMaleHomeTimeoutCleanup()
EndFunction

Function TickMaleHomeTimeoutCleanup()
	If MaleHomeTimeoutCleanupRT <= 0.0
		Return
	EndIf

	If Utility.GetCurrentRealTime() < MaleHomeTimeoutCleanupRT
		Return
	EndIf

	MaleHomeTimeoutCleanupRT = 0.0

	If GetFSState() != 11
		L("MaleHome timeout cleanup skipped: state changed state=" + GetFSState())
		Return
	EndIf

	Int mode = 0
	If TMS_FSAfterSceneArmedGV
		mode = TMS_FSAfterSceneArmedGV.GetValueInt()
	EndIf

	If mode > 0
		L("MaleHome timeout cleanup skipped: adult scene armed mode=" + mode)
		Return
	EndIf

	If MaleHomeAfterScene && MaleHomeAfterScene.IsPlaying()
		L("MaleHome timeout cleanup skipped: after scene playing")
		Return
	EndIf

	StopSceneSimple(MaleHomeScene)
	SetFSState(0)
	ReleaseActiveFollower("MaleHome timeout cleanup")

	L("MaleHome timeout cleanup done")
EndFunction

Bool Function IsAfterSceneArmed()
	Int mode = 0
	If TMS_FSAfterSceneArmedGV
		mode = TMS_FSAfterSceneArmedGV.GetValueInt()
	EndIf

	Return mode > 0
EndFunction

Bool Function CanStartNewEventStrict(String reason)
	If bFSAddonMiniRunning || ActiveAddonEventType != 0
		L("Start BLOCK: addon active type=" + ActiveAddonEventType + " running=" + BoolStr(bFSAddonMiniRunning) + " reason=" + reason)
		Return False
	EndIf

	If IsAfterSceneArmed()
		L("Start BLOCK: after scene armed reason=" + reason)
		Return False
	EndIf

	Int st = GetFSState()
	If st != 0
		L("Start BLOCK: state=" + st + " reason=" + reason)
		Return False
	EndIf

	Return True
EndFunction

Function CancelMaleHomeWindowForBedSit(String reason)
	If !bMaleWarmArmed
		Return
	EndIf

	If IsAfterSceneArmed()
		L("BedSit home window cancel skipped: after scene already armed reason=" + reason)
		Return
	EndIf

	L("BedSit cancelling MaleHome window reason=" + reason + " state=" + GetFSState() + " follower=" + GetActiveFollower())

	CloseMaleWarmWindow("bed_sit_override", 0)
	MaleHomeTimeoutCleanupRT = 0.0
	StopSceneSimple(MaleHomeScene)

	If GetFSState() == 11
		SetFSState(0)
	EndIf

	; Keep TMS_FollowerBaseAlias bound. Cuddle Sleep may reuse the same follower picked by Home.
	L("BedSit cancelled MaleHome window done reason=" + reason)
EndFunction

Bool Function CanStartCuddleSleepEvent(String reason)
	If bFSAddonMiniRunning || ActiveAddonEventType != 0
		L("CuddleSleep BLOCK: addon active type=" + ActiveAddonEventType + " running=" + BoolStr(bFSAddonMiniRunning) + " reason=" + reason)
		Return False
	EndIf

	If IsAfterSceneArmed()
		L("CuddleSleep BLOCK: after scene armed reason=" + reason)
		Return False
	EndIf

	Int st = GetFSState()
	If st == 11 && bMaleWarmArmed
		; Home dialogue window is the only non-idle state Cuddle Sleep may override later, once all sleep gates pass.
		Return True
	EndIf

	If st != 0
		L("CuddleSleep BLOCK: state=" + st + " reason=" + reason)
		Return False
	EndIf

	Return True
EndFunction

Function TryStartMaleOnHomeScene(String reason)
	If IsMaleWarmWindowOpen()
		L("MaleOnHome REOPEN: window already open reason=" + reason)
		CloseMaleWarmWindow("home_reopen", 0)
		If GetFSState() == 11
			SetFSState(0)
		EndIf
	EndIf

	ClearStaleAddonLock("MaleOnHome precheck:" + reason)

	If !IsEnabled()
		L("MaleOnHome BLOCK: disabled reason=" + reason)
		Return
	EndIf

	If Utility.IsInMenuMode()
		L("MaleOnHome BLOCK: menu mode reason=" + reason)
		Return
	EndIf

	If !CanStartNewEventStrict("MaleOnHome:" + reason)
		Return
	EndIf

	Actor f = ResolveFollowerForEventRetry("MaleOnHome:" + reason, MaleHomeFollowerRetryCount, MaleHomeFollowerRetryDelay)
	If !f
		L("MaleOnHome BLOCK: no follower reason=" + reason)
		Return
	EndIf

	If !CanOpenMaleWarmWindow()
		L("MaleOnHome BLOCK: cooldown reason=" + reason)
		Return
	EndIf

	If !HasAdultFramework()
		L("MaleOnHome BLOCK: no adult framework reason=" + reason)
		Return
	EndIf

	If !MaleHomeScene
		L("MaleOnHome BLOCK: MaleHomeScene=None reason=" + reason)
		Return
	EndIf

	If MaleHomeScene.IsPlaying()
		L("MaleOnHome BLOCK: MaleHomeScene already playing reason=" + reason)
		Return
	EndIf

	L("MaleOnHome PASS reason=" + reason + " follower=" + f)

	; Set state before scene start in case CK scene conditions depend on it.
	SetFSState(11)

	If StartSceneSimple(MaleHomeScene)
		OpenMaleWarmWindow(30.0, reason)
		L("MaleHomeScene START reason=" + reason)
	Else
		SetFSState(0)
		L("MaleHomeScene start FAILED reason=" + reason)
	EndIf
EndFunction

Bool Function StartMaleHomeAfterScene_Bool()
	If StartSceneSimple(MaleHomeAfterScene)
		L("MaleHomeAfterScene START")
		Return True
	EndIf
	ClearAddonMiniLock("MaleHomeAfterScene start failed")
	Return False
EndFunction

Function StartMaleHomeAfterSceneWithTarget(Actor akTarget)
	If !akTarget
		Return
	EndIf

	If TMS_FollowerBaseAlias
		TMS_FollowerBaseAlias.ForceRefTo(akTarget as ObjectReference)
	EndIf

	StartMaleHomeAfterScene_Bool()
EndFunction

Function CleanupMaleHomeScene()
	StopSceneSimple(MaleHomeScene)
EndFunction

Function CleanupMaleHomeAfterScene()
	If GetFSState() == 0
		Return
	EndIf

	StopSceneSimple(MaleHomeAfterScene)
	MaleHomeTimeoutCleanupRT = 0.0

	SetFSState(0)

	Actor a = GetActiveFollower()
	If a
		a.EvaluatePackage()
	EndIf

	ClearAddonMiniLock("MaleHomeAfterScene done")
	ReleaseActiveFollower("MaleHomeAfterScene done")

	L("CleanupMaleHomeAfterScene done")
EndFunction

; =========================================================
; CombatOver
; =========================================================
Function CombatOver_OnCombatStateChanged(Actor akTarget, Bool abInCombat)
	L("CombatOver_OnCombatStateChanged enter target=" + akTarget + " abInCombat=" + abInCombat)

	If abInCombat
		L("CombatOver_OnCombatStateChanged: in combat -> return")
		Return
	EndIf

	Actor p = Game.GetPlayer()
	If !p
		L("CombatOver_OnCombatStateChanged: player=None")
		Return
	EndIf

	Location loc = p.GetCurrentLocation()
	If !loc
		L("CombatOver_OnCombatStateChanged: loc=None")
		Return
	EndIf

	If !LocTypeDungeon || !loc.HasKeyword(LocTypeDungeon)
		L("CombatOver_OnCombatStateChanged: not dungeon loc=" + loc)
		Return
	EndIf

	If bCombatWindowArmed
		L("CombatOver_OnCombatStateChanged: already armed")
		Return
	EndIf

	L("CombatOver_OnCombatStateChanged: arm combat window loc=" + loc)
	ArmCombatWindow(loc, "CombatOver")
EndFunction

Function ArmCombatWindow(Location loc, String reason)
	If !loc
		Actor p = Game.GetPlayer()
		If p
			loc = p.GetCurrentLocation()
		EndIf
	EndIf

	If !loc
		L("CombatWindow ARM aborted reason=" + reason)
		Return
	EndIf

	Float now = Utility.GetCurrentRealTime()
	bCombatWindowArmed = True
	CombatWindowLoc = loc
	CombatWindowUntilRT = now + CombatWindowSec
	CombatNextCheckRT = now + CombatCheckDelaySec

	L("CombatWindow ARM reason=" + reason + " loc=" + loc + " until=" + CombatWindowUntilRT)
	StartWatchdogUpdates()
EndFunction

Function DisarmCombatWindow(String reason)
	If bCombatWindowArmed
		L("CombatWindow DISARM reason=" + reason)
	EndIf

	bCombatWindowArmed = False
	CombatWindowUntilRT = 0.0
	CombatNextCheckRT = 0.0
	CombatWindowLoc = None
EndFunction

Function TickCombatWindow()
	If !bCombatWindowArmed
		Return
	EndIf

	Float now = Utility.GetCurrentRealTime()

	If CombatWindowUntilRT > 0.0 && now >= CombatWindowUntilRT
		L("TickCombatWindow: timeout")
		DisarmCombatWindow("timeout")
		Return
	EndIf

	If CombatNextCheckRT > 0.0 && now < CombatNextCheckRT
		Return
	EndIf

	CombatNextCheckRT = now + CombatCheckIntervalSec

	Actor p = Game.GetPlayer()
	If !p
		L("TickCombatWindow: player=None")
		DisarmCombatWindow("player_none")
		Return
	EndIf

	If p.IsInCombat()
		L("TickCombatWindow: still in combat")
		Return
	EndIf

	Location cur = p.GetCurrentLocation()
	If !cur || !CombatWindowLoc || cur != CombatWindowLoc
		L("TickCombatWindow: leave_dungeon cur=" + cur + " armedLoc=" + CombatWindowLoc)
		DisarmCombatWindow("leave_dungeon")
		Return
	EndIf

	L("TickCombatWindow: cur=" + cur + " cleared=" + cur.IsCleared())

	If cur.IsCleared()
		If Utility.IsInMenuMode()
			L("TickCombatWindow: menu mode while cleared")
			Return
		EndIf

		L("TickCombatWindow: TryStartMaleCombatOverScene")
		TryStartMaleCombatOverScene("DungeonCleared")

		If MaleCombatOverScene && MaleCombatOverScene.IsPlaying()
			DisarmCombatWindow("cleared")
		EndIf
	EndIf
EndFunction

Function TryStartMaleCombatOverScene(String reason)
	If Utility.IsInMenuMode()
		L("TryStartCombatOver BLOCK: menu mode reason=" + reason)
		Return
	EndIf

	If IsMaleWarmWindowOpen()
		Return
	EndIf

	If !IsEnabled()
		Return
	EndIf

	Actor p = Game.GetPlayer()
	If !IsPlayerMale()
		Return
	EndIf
	If !p || p.IsInCombat()
		Return
	EndIf

	ClearStaleAddonLock("MaleCombatOver precheck:" + reason)

	If !CanStartNewEventStrict("MaleCombatOver:" + reason)
		Return
	EndIf

	Actor f = ResolveFollowerForEvent("MaleCombatOver:" + reason)
	If !f
		L("MaleCombatOverScene BLOCK: no follower reason=" + reason)
		Return
	EndIf

	If !CanOpenMaleWarmWindow()
		L("MaleCombatOverScene blocked by cooldown reason=" + reason)
		Return
	EndIf

	If !HasAdultFramework()
		L("MaleCombatOverScene BLOCK: no adult framework reason=" + reason)
		Return
	EndIf

	If MaleCombatOverScene && MaleCombatOverScene.IsPlaying()
		L("TryStartCombatOver BLOCK: scene playing reason=" + reason)
		Return
	EndIf

	If MaleCombatOverAfterScene && MaleCombatOverAfterScene.IsPlaying()
		L("TryStartCombatOver BLOCK: after playing reason=" + reason)
		Return
	EndIf

	SetFSState(12)
	OpenMaleWarmWindow(60.0, reason)

	If MaleCombatOverScene && !MaleCombatOverScene.IsPlaying()
		MaleCombatOverScene.Start()
		L("MaleCombatOverScene START reason=" + reason + " follower=" + f)
	Else
		L("MaleCombatOverScene start FAILED reason=" + reason)
	EndIf
EndFunction

Bool Function StartMaleCombatOverAfterScene_Bool()
	If StartSceneSimple(MaleCombatOverAfterScene)
		L("MaleCombatOverAfterScene START")
		Return True
	EndIf
	ClearAddonMiniLock("MaleCombatOverAfterScene start failed")
	Return False
EndFunction

Function StartMaleCombatOverAfterSceneWithTarget(Actor akTarget)
	If !akTarget
		Return
	EndIf

	If TMS_FollowerBaseAlias
		TMS_FollowerBaseAlias.ForceRefTo(akTarget as ObjectReference)
	EndIf

	StartMaleCombatOverAfterScene_Bool()
EndFunction

Function CleanupCombatOverScene()
	StopSceneSimple(MaleCombatOverScene)
EndFunction

Function CleanupMaleCombatOverAfterScene()
	If GetFSState() == 0
		Return
	EndIf

	StopSceneSimple(MaleCombatOverAfterScene)

	SetFSState(0)

	Actor a = GetActiveFollower()
	If a
		a.EvaluatePackage()
	EndIf

	ClearAddonMiniLock("MaleCombatOverAfterScene done")
	ReleaseActiveFollower("MaleCombatOverAfterScene done")

	L("CleanupMaleCombatOverAfterScene done")
EndFunction


; =========================================================
; Addon Event 01: Cold Weather Hug timed mini
; =========================================================
Bool Function StartHugMiniFromFragment(String reason) 
	Actor f = GetAddonFollower("HugMini:" + reason)
	If !f
		L("HugMini skipped: follower none reason=" + reason)
		Return False
	EndIf

	SetFSState(210)
	ActiveAddonEventType = 1

	Int hugSlotMode = FSHugSlotMode
	Bool hugPlayerDom = FSHugPlayerDom

	If IsPlayerFemale()
		hugSlotMode = 0 ; male/female slot order
		hugPlayerDom = False
		L("HugMini female player override: slotMode=0 playerDom=False reason=" + reason)
	Else
		L("HugMini male/default player rule: slotMode=" + hugSlotMode + " playerDom=" + hugPlayerDom + " reason=" + reason)
	EndIf

	String anim = PickMiniAnimByDomSex(f, FSHugMaleStartingAnim, FSHugFemaleStartingAnim, hugPlayerDom, "HugMini:" + reason)
	Int tid = StartOStimMiniWithSlotRule_ReturnTid(f, anim, hugSlotMode, hugPlayerDom, "HugMini:" + reason)

	If tid < 0
		L("HugMini failed to start reason=" + reason)
		CleanupHugOStimMini("start_failed")
		Return False
	EndIf

	If reason == "ColdWeatherHug"
		bColdWeatherHugPending = False
		ColdWeatherHugFollower = None
		L("ColdWeatherHug pending cleared by hug mini start")
	EndIf

	ActiveAddonThreadId = tid
	bFSAddonMiniRunning = True
	FSAffectionEndRT = Utility.GetCurrentRealTime() + GetFSAffectionDuration()

	RegisterForSingleUpdate(0.5)

	L("HugMini START tid=" + tid + " anim=" + anim + " endRT=" + FSAffectionEndRT + " reason=" + reason)

	Return True
EndFunction

Function CleanupHugOStimMini(String reason)
	If GetFSState() != 210 && ActiveAddonEventType != 1
		Return
	EndIf

	If bFSAddonMiniCleaning
		Return
	EndIf
	bFSAddonMiniCleaning = True

	L("CleanupHugOStimMini reason=" + reason)

	If reason != "ostim_end"
		StopActiveAddonOStimThread("Hug:" + reason)
	EndIf

	If FSHugRestoreOStimUIDelay > 0.0 && bFSAddonOStimUIToggled
		; Keep OStim UI hidden through the full hug stop/exit transition.
		; Hug exit blending can outlive ostim_end on some OStim builds, so use a longer hug-specific delay.
		L("Hug UI restore delayed seconds=" + FSHugRestoreOStimUIDelay + " reason=" + reason)
		Utility.Wait(FSHugRestoreOStimUIDelay)
	EndIf

	FS_RestoreOStimUIForAddonMini("Hug:" + reason)
	FS_RestoreOStimAutoModeKeyForAddonMini("Hug:" + reason)
	ClearAddonMiniLock("Hug mini done:" + reason)
	StopSceneSimple(FSColdWeatherHugScene)

	SetFSState(0)
	ActiveAddonEventType = 0
	ActiveAddonThreadId = -1
	bFSAddonMiniRunning = False
	FSAffectionEndRT = 0.0
	bColdWeatherHugPending = False
	ColdWeatherHugFollower = None

	Actor f = GetActiveFollower()
	If f
		f.EvaluatePackage()
	EndIf

	ReleaseActiveFollower("Hug mini done:" + reason)

	bFSAddonMiniCleaning = False
EndFunction
; =========================================================
; Addon Event 02: Cuddle Sleep
; =========================================================
Bool Function IsFurnitureBed(ObjectReference akFurniture)
	If !akFurniture
		Return False
	EndIf

	String furnType = OFurniture.GetFurnitureType(akFurniture)
	If furnType == "" || furnType == "none"
		Return False
	EndIf

	Return OFurniture.IsChildOf("bed", furnType)
EndFunction

ObjectReference Function GetCuddleSleepBedRef(Actor akFollower, ObjectReference akPreferredBed = None)
	EnsurePlayer()

	If IsFurnitureBed(akPreferredBed)
		Return akPreferredBed
	EndIf

	If IsFurnitureBed(ActiveCuddleSleepBedRef)
		Return ActiveCuddleSleepBedRef
	EndIf

	If PlayerRef
		ObjectReference pBed = PlayerRef.GetFurnitureReference()
		If IsFurnitureBed(pBed)
			Return pBed
		EndIf
	EndIf

	If akFollower
		ObjectReference fBed = akFollower.GetFurnitureReference()
		If IsFurnitureBed(fBed)
			Return fBed
		EndIf
	EndIf

	Return None
EndFunction

Bool Function CanTryCuddleSleepByTime(String reason)
	Float h = Utility.GetCurrentGameTime()
	h = (h - Math.Floor(h)) * 24.0

	If FSCuddleSleepStartHour > FSCuddleSleepEndHour
		If h >= FSCuddleSleepStartHour || h < FSCuddleSleepEndHour
			Return True
		EndIf
	Else
		If h >= FSCuddleSleepStartHour && h < FSCuddleSleepEndHour
			Return True
		EndIf
	EndIf

	L("CuddleSleep BLOCK: not sleep time hour=" + h + " reason=" + reason)
	Return False
EndFunction

Function ArmCuddleSleepCooldown(String reason)
	Float nowGT = Utility.GetCurrentGameTime()
	FSCuddleSleepNextAllowedGT = nowGT + (FSCuddleSleepCooldownHours / 24.0)
	L("CuddleSleep cooldown armed by outer trigger reason=" + reason + " now=" + nowGT + " next=" + FSCuddleSleepNextAllowedGT + " hours=" + FSCuddleSleepCooldownHours)
EndFunction

Bool Function TryStartCuddleSleepEvent(String reason, ObjectReference akEventFurniture = None)
	L("CuddleSleep ENTER reason=" + reason + " eventFurniture=" + akEventFurniture)
	ClearStaleAddonLock("CuddleSleep precheck:" + reason)

	If !bFSCuddleSleepEventEnabled
		L("CuddleSleep BLOCK: disabled reason=" + reason)
		Return False
	EndIf

	If !CanStartCuddleSleepEvent(reason)
		Return False
	EndIf

	If !CanRunOStimOnlyAddonEvent("CuddleSleep:" + reason)
		Return False
	EndIf

	If !CanTryCuddleSleepByTime(reason)
		Return False
	EndIf

	Float nowGT = Utility.GetCurrentGameTime()
	If nowGT < FSCuddleSleepNextAllowedGT
		L("CuddleSleep BLOCK: cooldown now=" + nowGT + " next=" + FSCuddleSleepNextAllowedGT + " reason=" + reason)
		Return False
	EndIf

	Actor f = GetAddonFollower("CuddleSleep:" + reason)
	If !f
		L("CuddleSleep BLOCK: follower none reason=" + reason)
		Return False
	EndIf

	ObjectReference bedRef = None
	If IsFurnitureBed(akEventFurniture)
		bedRef = akEventFurniture
		L("CuddleSleep use event bed=" + bedRef + " reason=" + reason)
	EndIf

	If !IsCuddleSleepPairReady(f, reason, bedRef)
		Return False
	EndIf

	bedRef = GetCuddleSleepBedRef(f, bedRef)
	If !bedRef
		L("CuddleSleep BLOCK: bedRef none reason=" + reason)
		Return False
	EndIf

	If !FSCuddleSleepEventScene
		L("CuddleSleep BLOCK: scene none reason=" + reason)
		Return False
	EndIf

	If FSCuddleSleepEventScene.IsPlaying()
		L("CuddleSleep BLOCK: scene already playing reason=" + reason)
		Return False
	EndIf

	If !RollChance(FSCuddleSleepChance)
		L("CuddleSleep BLOCK: roll failed chance=" + FSCuddleSleepChance + " reason=" + reason)
		; Bed sit is explicit player intent. If Home dialogue window is pending, cancel it even when the sleep roll fails.
		CancelMaleHomeWindowForBedSit(reason + ":roll_failed")
		ArmCuddleSleepCooldown("roll_failed:" + reason)
		; Roll failed means no event will start, so release any follower/alias picked for this attempt.
		ReleaseActiveFollower("CuddleSleep roll failed:" + reason)
		Return False
	EndIf

	CancelMaleHomeWindowForBedSit(reason)
	ArmCuddleSleepCooldown("scene_start:" + reason)

	SetFSState(220)
	ActiveAddonEventType = 3
	ActiveAddonThreadId = -1
	bFSAddonMiniRunning = False
	ActiveCuddleSleepBedRef = bedRef
	CuddleSleepSceneStartRT = Utility.GetCurrentRealTime()

	If TMS_FollowerBaseAlias
		TMS_FollowerBaseAlias.ForceRefTo(f as ObjectReference)
	EndIf

	FSCuddleSleepEventScene.Start()
	Utility.Wait(0.3)

	If !FSCuddleSleepEventScene.IsPlaying()
		L("CuddleSleep scene failed to play after Start reason=" + reason)
		ActiveAddonEventType = 0
		ActiveAddonThreadId = -1
		bFSAddonMiniRunning = False
		ActiveCuddleSleepBedRef = None
		CuddleSleepSceneStartRT = 0.0
		If GetFSState() == 220
			SetFSState(0)
		EndIf
		ReleaseActiveFollower("CuddleSleep scene failed:" + reason)
		Return False
	EndIf

	RegisterForSingleUpdate(0.5)
	L("CuddleSleep PASS: scene playing follower=" + f + " bed=" + bedRef + " reason=" + reason)

	Return True
EndFunction

Bool Function IsPlayerStillOnCuddleSleepBed(String reason)
	If !PlayerRef
		L("CuddleSleep trigger BLOCK: player none reason=" + reason)
		Return False
	EndIf

	ObjectReference currentFurniture = PlayerRef.GetFurnitureReference()
	If !IsFurnitureBed(currentFurniture)
		L("CuddleSleep trigger BLOCK: player left bed currentFurniture=" + currentFurniture + " reason=" + reason)
		Return False
	EndIf

	If ActiveCuddleSleepBedRef && currentFurniture != ActiveCuddleSleepBedRef
		L("CuddleSleep trigger BLOCK: player changed bed current=" + currentFurniture + " expected=" + ActiveCuddleSleepBedRef + " reason=" + reason)
		Return False
	EndIf

	Return True
EndFunction

Function TickCuddleSleepTriggerScene()
	If CuddleSleepSceneStartRT <= 0.0
		Return
	EndIf

	If ActiveAddonEventType != 3 || bFSAddonMiniRunning
		Return
	EndIf

	If !IsPlayerStillOnCuddleSleepBed("trigger wait")
		CancelCuddleSleepTriggerScene("player left bed")
		Return
	EndIf

	If !FSCuddleSleepEventScene
		CancelCuddleSleepTriggerScene("scene none")
		Return
	EndIf

	If !FSCuddleSleepEventScene.IsPlaying()
		CancelCuddleSleepTriggerScene("scene ended before mini")
		Return
	EndIf

	Float timeoutSeconds = FSCuddleSleepSceneTimeout
	If timeoutSeconds <= 0.0
		timeoutSeconds = 45.0
	EndIf

	Float elapsed = Utility.GetCurrentRealTime() - CuddleSleepSceneStartRT
	If elapsed > timeoutSeconds
		CancelCuddleSleepTriggerScene("timeout " + elapsed)
		Return
	EndIf

	RegisterForSingleUpdate(0.5)
EndFunction

Function CancelCuddleSleepTriggerScene(String reason)
	L("CancelCuddleSleepTriggerScene reason=" + reason)

	StopSceneSimple(FSCuddleSleepEventScene)

	If GetFSState() == 220
		SetFSState(0)
	EndIf

	ActiveAddonEventType = 0
	ActiveAddonThreadId = -1
	bFSAddonMiniRunning = False
	bFSAddonMiniCleaning = False
	ActiveCuddleSleepBedRef = None
	CuddleSleepSceneStartRT = 0.0
	FSAffectionEndRT = 0.0

	FS_RestoreOStimUIForAddonMini("CuddleSleep trigger canceled:" + reason)
	FS_RestoreOStimAutoModeKeyForAddonMini("CuddleSleep trigger canceled:" + reason)
	ClearAddonMiniLock("CuddleSleep trigger canceled:" + reason)

	ReleaseActiveFollower("CuddleSleep trigger canceled:" + reason)
EndFunction

Bool Function StartCuddleSleepMiniFromFragment(String reason)
	Actor f = GetAddonFollower("CuddleSleepMini:" + reason)
	If !f
		L("CuddleSleepMini skipped: follower none reason=" + reason)
		Return False
	EndIf

	If !IsCuddleSleepPairReady(f, reason)
		Return False
	EndIf

	SetFSState(220)
	ActiveAddonEventType = 3

	Int tid = StartCuddleSleepOStimMiniWithBed_ReturnTid(f, "CuddleSleepMini:" + reason)

	If tid < 0
		L("CuddleSleepMini failed to start reason=" + reason)
		CleanupCuddleSleepOStimMini("start_failed")
		Return False
	EndIf

	ActiveAddonThreadId = tid
	bFSAddonMiniRunning = True
	CuddleSleepSceneStartRT = 0.0
	ActiveCuddleSleepBedRef = GetCuddleSleepBedRef(f, ActiveCuddleSleepBedRef)

	RegisterForSingleUpdate(0.5)

	L("CuddleSleepMini START tid=" + tid + " reason=" + reason)

	Return True
EndFunction

Int Function StartCuddleSleepOStimMiniWithBed_ReturnTid(Actor akFollower, String reason)
	If !CanRunOStimOnlyAddonEvent("CuddleSleepMini:" + reason)
		Return -1
	EndIf

	If !akFollower
		L("StartCuddleSleepOStimMiniWithBed BLOCK: follower none reason=" + reason)
		Return -1
	EndIf

	ObjectReference bedRef = GetCuddleSleepBedRef(akFollower, ActiveCuddleSleepBedRef)

	If !IsCuddleSleepPairReady(akFollower, reason, bedRef)
		Return -1
	EndIf

	bedRef = GetCuddleSleepBedRef(akFollower, bedRef)
	If !bedRef
		L("StartCuddleSleepOStimMiniWithBed BLOCK: bedRef none reason=" + reason)
		Return -1
	EndIf

	Actor[] actors = BuildMiniActorArray(akFollower, FSCuddleSleepSlotMode, FSCuddleSleepPlayerDom, reason)

	If !actors || actors.Length < 2
		L("StartCuddleSleepOStimMiniWithBed BLOCK: actor array invalid reason=" + reason)
		Return -1
	EndIf

	If !actors[0] || !actors[1]
		L("StartCuddleSleepOStimMiniWithBed BLOCK: actor slot none reason=" + reason)
		Return -1
	EndIf

	If FSCuddleSleepStartingAnim == ""
		L("StartCuddleSleepOStimMiniWithBed BLOCK: anim empty reason=" + reason)
		Return -1
	EndIf

	If TMS_FSAfterSceneArmedGV
		TMS_FSAfterSceneArmedGV.SetValueInt(0)
	EndIf

	Int tid = StartOStimMiniWithFurniture(actors, FSCuddleSleepStartingAnim, bedRef, reason)

	L("StartCuddleSleepOStimMiniWithBed tid=" + tid + " bed=" + bedRef + " anim=" + FSCuddleSleepStartingAnim + " reason=" + reason)

	Return tid
EndFunction

Int Function StartOStimMiniWithFurniture(Actor[] actors, String startingAnim, ObjectReference furnitureRef, String reason)
	If !actors || actors.Length < 2
		L("StartOStimMiniWithFurniture BLOCK: actors invalid reason=" + reason)
		Return -1
	EndIf

	If startingAnim == ""
		L("StartOStimMiniWithFurniture BLOCK: anim empty reason=" + reason)
		Return -1
	EndIf

	If !furnitureRef
		L("StartOStimMiniWithFurniture BLOCK: furniture none reason=" + reason)
		Return -1
	EndIf

	ArmAddonMiniLock("Furniture:" + reason)
	FS_RequestHideOStimUIForAddonMini("Furniture:" + reason)
	FS_DisableOStimAutoModeKeyForAddonMini("Furniture:" + reason)
	RequestStageFlowSuppressNextMiniThread("Furniture:" + reason)
	Int tid = OThread.QuickStart(actors, startingAnim, furnitureRef)
	If tid < 0
		bFSAddonOStimUIHideRequested = False
		FS_RestoreOStimAutoModeKeyForAddonMini("Furniture start failed:" + reason)
		ClearAddonMiniLock("Furniture start failed:" + reason)
	EndIf
	L("StartOStimMiniWithFurniture tid=" + tid + " anim=" + startingAnim + " furniture=" + furnitureRef + " reason=" + reason)

	Return tid
EndFunction


Function CleanupCuddleSleepOStimMini(String reason)
	If GetFSState() != 220 && ActiveAddonEventType != 3
		Return
	EndIf

	If bFSAddonMiniCleaning
		Return
	EndIf
	bFSAddonMiniCleaning = True

	L("CleanupCuddleSleepOStimMini reason=" + reason)

	If reason != "ostim_end"
		StopActiveAddonOStimThread("CuddleSleep:" + reason)
	EndIf

	If FSCuddleSleepRestoreOStimUIDelay > 0.0 && bFSAddonOStimUIToggled
		; Keep OStim UI hidden through the stop/exit transition.
		L("CuddleSleep UI restore delayed seconds=" + FSCuddleSleepRestoreOStimUIDelay + " reason=" + reason)
		Utility.Wait(FSCuddleSleepRestoreOStimUIDelay)
	EndIf

	FS_RestoreOStimUIForAddonMini("CuddleSleep:" + reason)
	FS_RestoreOStimAutoModeKeyForAddonMini("CuddleSleep:" + reason)
	ClearAddonMiniLock("CuddleSleep mini done:" + reason)

	StopSceneSimple(FSCuddleSleepEventScene)

	SetFSState(0)
	ActiveAddonEventType = 0
	ActiveAddonThreadId = -1
	bFSAddonMiniRunning = False
	ActiveCuddleSleepBedRef = None
	CuddleSleepSceneStartRT = 0.0

	Actor f = GetActiveFollower()
	If f
		f.EvaluatePackage()
	EndIf

	ReleaseActiveFollower("CuddleSleep mini done:" + reason)

	bFSAddonMiniCleaning = False
EndFunction


Function UpdateColdWeatherHugPending()
	If !bColdWeatherHugPending
		Return
	EndIf

	EnsurePlayer()

	If !PlayerRef
		CancelColdWeatherHug("PlayerRef none")
		Return
	EndIf

	If !ColdWeatherHugFollower
		CancelColdWeatherHug("follower none")
		Return
	EndIf

	If PlayerRef.IsInCombat()
		CancelColdWeatherHug("player combat")
		Return
	EndIf

	If ColdWeatherHugFollower.IsInCombat()
		CancelColdWeatherHug("follower combat")
		Return
	EndIf

	If PlayerRef.GetParentCell() != ColdWeatherHugFollower.GetParentCell()
		CancelColdWeatherHug("different cell")
		Return
	EndIf

	Float dx = PlayerRef.GetPositionX() - ColdWeatherHugAnchorX
	Float dy = PlayerRef.GetPositionY() - ColdWeatherHugAnchorY
	Float dz = PlayerRef.GetPositionZ() - ColdWeatherHugAnchorZ
	Float moved = Math.Sqrt(dx * dx + dy * dy + dz * dz)

	If moved > FSColdWeatherHugPlayerMoveTolerance
		CancelColdWeatherHug("player moved " + moved)
		Return
	EndIf

	Float elapsed = Utility.GetCurrentRealTime() - ColdWeatherHugStartRT
	If elapsed > FSColdWeatherHugTimeout
		CancelColdWeatherHug("timeout " + elapsed)
		Return
	EndIf

	; Scene handles follower approach and dialogue distance.
	; Keep watching until the mini hug starts, times out, or gets canceled.
	RegisterForSingleUpdate(FSColdWeatherHugUpdateInterval)
EndFunction

Function CancelColdWeatherHug(String reason)
	L("CancelColdWeatherHug reason=" + reason)

	bColdWeatherHugPending = False
	ColdWeatherHugFollower = None
	ColdWeatherHugStartRT = 0.0

	StopSceneSimple(FSColdWeatherHugScene)

	If GetFSState() == 205
		SetFSState(0)
	EndIf

	ActiveAddonEventType = 0
	ActiveAddonThreadId = -1
	bFSAddonMiniRunning = False
	FSAffectionEndRT = 0.0

	ReleaseActiveFollower("ColdWeatherHug canceled:" + reason)
EndFunction

Bool Function IsNightTime()
	If !GameHour
		Return False
	EndIf

	Float h = GameHour.GetValue()

	If h >= 20.0 || h < 6.0
		Return True
	EndIf

	Return False
EndFunction

Bool Function IsPlayerExterior()
	EnsurePlayer()

	If !PlayerRef
		Return False
	EndIf

	Cell c = PlayerRef.GetParentCell()
	If !c
		Return False
	EndIf

	If c.IsInterior()
		Return False
	EndIf

	Return True
EndFunction

Bool Function IsRainOrSnowWeather()
	Weather w = Weather.GetCurrentWeather()
	If !w
		Return False
	EndIf

	Int cls = w.GetClassification()

	; 2 = Rainy, 3 = Snow
	If cls == 2 || cls == 3
		Return True
	EndIf

	Return False
EndFunction

Bool Function RollChance(Float chance)
	If chance >= 100.0
		Return True
	EndIf

	If chance <= 0.0
		Return False
	EndIf

	Float r = Utility.RandomFloat(0.0, 100.0)
	Return r <= chance
EndFunction

Bool Function IsActorUsingFurniture(Actor akActor)
	If !akActor
		Return False
	EndIf

	If akActor.GetFurnitureReference()
		Return True
	EndIf

	If akActor.GetSitState() != 0
		Return True
	EndIf

	Return False
EndFunction

Function ArmColdWeatherHugCooldown(String reason)
	Float nowGT = Utility.GetCurrentGameTime()
	FSColdWeatherHugNextAllowedGT = nowGT + (FSColdWeatherHugCooldownHours / 24.0)
	L("ColdWeatherHug cooldown armed by outer trigger reason=" + reason + " now=" + nowGT + " next=" + FSColdWeatherHugNextAllowedGT + " hours=" + FSColdWeatherHugCooldownHours)
EndFunction

Bool Function TryStartColdWeatherHugScene(String reason)
	ClearStaleAddonLock("ColdWeatherHug precheck:" + reason)

	If !CanRunOStimOnlyAddonEvent("ColdWeatherHug:" + reason)
		Return False
	EndIf

	If !CanStartNewEventStrict("ColdWeatherHug:" + reason)
		Return False
	EndIf

	If bColdWeatherHugPending
		L("ColdWeatherHug BLOCK: pending already active reason=" + reason)
		Return False
	EndIf

	EnsurePlayer()

	If !PlayerRef
		L("ColdWeatherHug BLOCK: PlayerRef=None reason=" + reason)
		Return False
	EndIf

	If PlayerRef.IsInCombat()
		L("ColdWeatherHug BLOCK: player combat reason=" + reason)
		Return False
	EndIf

	If IsActorUsingFurniture(PlayerRef)
		L("ColdWeatherHug BLOCK: player using furniture reason=" + reason)
		Return False
	EndIf

	If !IsPlayerExterior()
		L("ColdWeatherHug BLOCK: not exterior reason=" + reason)
		Return False
	EndIf

	If !IsNightTime()
		L("ColdWeatherHug BLOCK: not night reason=" + reason)
		Return False
	EndIf

	If !IsRainOrSnowWeather()
		L("ColdWeatherHug BLOCK: not rain/snow reason=" + reason)
		Return False
	EndIf

	Float nowGT = Utility.GetCurrentGameTime()
	If nowGT < FSColdWeatherHugNextAllowedGT
		L("ColdWeatherHug BLOCK: cooldown now=" + nowGT + " next=" + FSColdWeatherHugNextAllowedGT + " reason=" + reason)
		Return False
	EndIf

	If !RollChance(FSColdWeatherHugChance)
		L("ColdWeatherHug BLOCK: roll failed chance=" + FSColdWeatherHugChance + " reason=" + reason)
		ArmColdWeatherHugCooldown("roll_failed:" + reason)
		; Roll failed means no event will start, so release any stale/picked alias before the next trigger.
		ReleaseActiveFollower("ColdWeatherHug roll failed:" + reason)
		Return False
	EndIf

	Actor f = ResolveFollowerForEvent("ColdWeatherHug:" + reason)
	If !f
		L("ColdWeatherHug BLOCK: no follower reason=" + reason)
		Return False
	EndIf

	If f.IsInCombat()
		L("ColdWeatherHug BLOCK: follower combat reason=" + reason)
		ReleaseActiveFollower("ColdWeatherHug follower combat")
		Return False
	EndIf

	If IsActorUsingFurniture(f)
		L("ColdWeatherHug BLOCK: follower using furniture reason=" + reason)
		ReleaseActiveFollower("ColdWeatherHug follower using furniture")
		Return False
	EndIf

	If !FSColdWeatherHugScene
		L("ColdWeatherHug BLOCK: scene=None reason=" + reason)
		ReleaseActiveFollower("ColdWeatherHug scene none")
		Return False
	EndIf

	If FSColdWeatherHugScene.IsPlaying()
		L("ColdWeatherHug BLOCK: scene already playing reason=" + reason)
		ReleaseActiveFollower("ColdWeatherHug scene playing")
		Return False
	EndIf

	ColdWeatherHugFollower = f

	ColdWeatherHugAnchorX = PlayerRef.GetPositionX()
	ColdWeatherHugAnchorY = PlayerRef.GetPositionY()
	ColdWeatherHugAnchorZ = PlayerRef.GetPositionZ()
	ColdWeatherHugStartRT = Utility.GetCurrentRealTime()

	bColdWeatherHugPending = True

	SetFSState(205)
	ActiveAddonEventType = 1
	ActiveAddonThreadId = -1
	bFSAddonMiniRunning = False
	FSAffectionEndRT = 0.0

	If TMS_FollowerBaseAlias
		TMS_FollowerBaseAlias.ForceRefTo(f as ObjectReference)
	EndIf

	ArmColdWeatherHugCooldown("scene_start:" + reason)

	FSColdWeatherHugScene.Start()
	Utility.Wait(0.3)

	If !FSColdWeatherHugScene.IsPlaying()
		L("ColdWeatherHug scene failed to play after Start reason=" + reason)
		bColdWeatherHugPending = False
		ColdWeatherHugFollower = None
		ColdWeatherHugStartRT = 0.0
		If GetFSState() == 205
			SetFSState(0)
		EndIf
		ActiveAddonEventType = 0
		ActiveAddonThreadId = -1
		bFSAddonMiniRunning = False
		FSAffectionEndRT = 0.0
		ReleaseActiveFollower("ColdWeatherHug scene failed:" + reason)
		Return False
	EndIf

	RegisterForSingleUpdate(FSColdWeatherHugUpdateInterval)

	L("ColdWeatherHug PASS: scene playing pending follower=" + f + " reason=" + reason)

	Return True
EndFunction

Function RequestStageFlowSuppressNextMiniThread(String reason)
	; Optional Stage Flow handshake for FS-owned short romantic threads only.
	; No hard dependency: if Stage Flow is absent, nobody receives this event.
	; Keep this OUT of ArmAddonMiniLock(), because normal FS adult OStim threads use that lock too.
	SendModEvent("TMS_StageFlow_SuppressNextPlayerThread", "TMS_FollowerSex:" + reason, 3.0)

	; Give a listening SF controller one tiny scheduler window to arm suppression
	; before OStim emits its thread-start event. SF also supports late-arrival suppression.
	Utility.Wait(0.05)
	L("StageFlow mini suppression requested reason=" + reason)
EndFunction

Int Function StartOStimMiniNoFurniture(Actor[] actors, String startingAnim, String reason)
	If !actors || actors.Length < 2
		L("StartOStimMiniNoFurniture BLOCK: actors invalid reason=" + reason)
		Return -1
	EndIf

	If startingAnim == ""
		L("StartOStimMiniNoFurniture BLOCK: startingAnim empty reason=" + reason)
		Return -1
	EndIf

	; Romantic no-furniture mini start.
	; Do not use OThread.QuickStart(..., None) here: in OStim that can still open the furniture selection UI.
	; Use OThreadBuilder.NoFurniture() to explicitly bypass furniture selection.
	ArmAddonMiniLock("NoFurniture:" + reason)
	FS_RequestHideOStimUIForAddonMini("NoFurniture:" + reason)
	FS_DisableOStimAutoModeKeyForAddonMini("NoFurniture:" + reason)

	Int builderId = OThreadBuilder.Create(actors)
	If builderId < 0
		L("StartOStimMiniNoFurniture BLOCK: builder create failed reason=" + reason)
		bFSAddonOStimUIHideRequested = False
		FS_RestoreOStimAutoModeKeyForAddonMini("NoFurniture builder failed:" + reason)
		ClearAddonMiniLock("NoFurniture builder failed:" + reason)
		Return -1
	EndIf

	OThreadBuilder.NoFurniture(builderId)
	OThreadBuilder.SetStartingAnimation(builderId, startingAnim)

	RequestStageFlowSuppressNextMiniThread("NoFurniture:" + reason)
	Int tid = OThreadBuilder.Start(builderId)
	If tid < 0
		L("StartOStimMiniNoFurniture BLOCK: builder start failed builder=" + builderId + " anim=" + startingAnim + " reason=" + reason)
		OThreadBuilder.Cancel(builderId)
		bFSAddonOStimUIHideRequested = False
		FS_RestoreOStimAutoModeKeyForAddonMini("NoFurniture start failed:" + reason)
		ClearAddonMiniLock("NoFurniture start failed:" + reason)
		Return -1
	EndIf

	; ostim_start should hide the UI, but add a local fallback because the furniture/start UI can appear
	; before or around the start event on some builds.
;	If bFSAddonOStimUIHideRequested && !bFSAddonOStimUIToggled && ForceHideOStimUIDuringAddonMini
;		If FSAddonHideOStimUIDelay > 0.0
;			Utility.Wait(FSAddonHideOStimUIDelay)
;		EndIf
;		FS_HideOStimUIForAddonMini("NoFurniture fallback after start:" + reason)
;	EndIf

	L("StartOStimMiniNoFurniture PASS: tid=" + tid + " builder=" + builderId + " anim=" + startingAnim + " reason=" + reason)

	Return tid
EndFunction

Function ArmAddonMiniLock(String reason)
	If TMS_FSAddonMiniActiveGV
		TMS_FSAddonMiniActiveGV.SetValueInt(1)
	EndIf

	If TMS_FSAddonMiniUntilGV
		TMS_FSAddonMiniUntilGV.SetValue(Utility.GetCurrentRealTime() + 600.0)
	EndIf

	L("Addon mini lock armed reason=" + reason)
EndFunction

Function ClearAddonMiniLock(String reason)
	If TMS_FSAddonMiniActiveGV
		TMS_FSAddonMiniActiveGV.SetValueInt(0)
	EndIf

	If TMS_FSAddonMiniUntilGV
		TMS_FSAddonMiniUntilGV.SetValue(0.0)
	EndIf

	L("Addon mini lock cleared reason=" + reason)
EndFunction