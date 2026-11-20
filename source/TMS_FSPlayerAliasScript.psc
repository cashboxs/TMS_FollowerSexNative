Scriptname TMS_FSPlayerAliasScript extends ReferenceAlias

TMS_FollowerSexQuestScript Property Main Auto
Keyword Property LocTypePlayerHouse Auto
GlobalVariable Property TMS_FSDebugGV Auto

Bool Function IsDebugOn()
    If !TMS_FSDebugGV
        Return False
    EndIf
    Return TMS_FSDebugGV.GetValueInt() == 1
EndFunction

Function N(String s)
    If IsDebugOn()
        Debug.Trace("[TMS FS][PAL] " + s)
    EndIf
EndFunction

Function NR(String s)
    N(s)
EndFunction

Event OnInit()
    N("OnInit ref=" + GetReference())
    NR("OnInit fired ref=" + GetReference())

    If !TMS_FSDebugGV
        NR("OnInit: TMS_FSDebugGV=None")
    Else
        NR("OnInit: DebugGV=" + TMS_FSDebugGV.GetValueInt())
    EndIf

    If !Main
        NR("OnInit: Main=None")
    Else
        NR("OnInit: Main OK")
    EndIf
EndEvent

Event OnPlayerLoadGame()
    N("OnPlayerLoadGame ref=" + GetReference())
    NR("OnPlayerLoadGame fired ref=" + GetReference())

    If !TMS_FSDebugGV
        NR("OnPlayerLoadGame: TMS_FSDebugGV=None")
    Else
        NR("OnPlayerLoadGame: DebugGV=" + TMS_FSDebugGV.GetValueInt())
    EndIf

    If Main
        Main.EnsurePlayer()
        Main.RegisterEvents()
        Main.SyncDebugFromMCM()
        N("OnPlayerLoadGame: re-register ostim events")
    Else
        NR("OnPlayerLoadGame: Main=None")
    EndIf
EndEvent

Event OnSit(ObjectReference akFurniture)
	NR("OnSit fired furn=" + akFurniture)

	If !Main
		NR("OnSit: Main=None")
		Return
	EndIf

	; Bed event first. Do not fall through to normal OnSit approach scene.
	If Main.IsFurnitureBed(akFurniture)
		N("OnSit: bed -> TryStartCuddleSleepEvent")
		Main.TryStartCuddleSleepEvent("OnSitBed", akFurniture)
		Return
	EndIf

	If !Main.IsPlayerFemale()
		N("OnSit: blocked, player not female")
		Return
	EndIf

	N("OnSit: female -> TryStart")
	Main.TryStartFollowerApproachScene("OnSit")
EndEvent

Event OnLocationChange(Location akOldLoc, Location akNewLoc)
    NR("OnLocationChange fired old=" + akOldLoc + " new=" + akNewLoc)

    If !Main
        NR("OnLocationChange: Main=None")
        Return
    EndIf

    ; Cold Weather Hug is self-gated in the main script.
    ; It returns immediately indoors, in SexLab mode, during cooldown, etc.
    Main.TryStartColdWeatherHugScene("OnLocationChange")

    If !akNewLoc
        N("OnLocationChange: akNewLoc=None")
        Return
    EndIf

    If !LocTypePlayerHouse
        NR("OnLocationChange: LocTypePlayerHouse not bound")
        Return
    EndIf

    If !akNewLoc.HasKeyword(LocTypePlayerHouse)
        N("OnLocationChange: not player house")
        Return
    EndIf

    If !Main.IsPlayerMale()
        N("OnLocationChange: blocked, player not male")
        Return
    EndIf

    N("OnLocationChange: male -> TryStart")
    Main.TryStartMaleOnHomeScene("OnLocationChange")
EndEvent

Event OnCombatStateChanged(Actor akTarget, int aeCombatState)
    NR("OnCombatStateChanged fired target=" + akTarget + " state=" + aeCombatState)

    If !Main
        NR("OnCombatStateChanged: Main=None")
        Return
    EndIf

    Bool abInCombat = (aeCombatState == 0)
    N("OnCombatStateChanged: abInCombat=" + abInCombat)
    Main.CombatOver_OnCombatStateChanged(akTarget, abInCombat)
EndEvent