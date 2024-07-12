using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Fortnite.com/FortPlayerUtilities }
using { /Fortnite.com/UI }
using { /Verse.org/Colors }
using { /Verse.org/Colors/NamedColors }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/UI }


custom_player := class:
    # To keep track of bases player has checkmarked
    var Bases:[]multi_base
    # Assigned to players for piececontrol bases.
    # The guard is teleported to the piece control base player is at

    <#
        Guard:guard_spawner_device
        # Doesn't work anymore, it gives error.
        # Solution: Created a Guard array weakmap 
    #>

    # For Healing Guard
    HealthPowerUp:health_powerup_device
    Color:color
    var EliminationCanvas:?canvas = false
    var GuardEliminationSubscription:?cancelable = false
    var GuardDamageSubscription:?cancelable = false
    var GuardState:guard_state = guard_state.Standard
    var PlayerState:player_state = player_state.Standard
    var Elimination:int = 0
    
    UpdateUI(Player:player):void =
        var UI:canvas = canvas{}
        if:
            ElimCanvas := EliminationCanvas?
            PlayerUI := GetPlayerUI[Player]
        then:
            set UI = ElimCanvas
            PlayerUI.RemoveWidget(UI)
        set UI = canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := 0.05, Y := 0.9}, Maximum := vector2{X := 0.05, Y := 0.9}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.0, Y := 1.0}
                        SizeToContent := true
                        Widget := text_block:
                            DefaultText := ToMessage("Elimination: {Elimination}")
                            DefaultTextColor := Color
        if:
            set EliminationCanvas = option{UI}
            PlayerUI := GetPlayerUI[Player]
        then {PlayerUI.AddWidget(UI)}


guard_state := enum:
    Standard # Guard Health is normal
    Precision # Guard has to be maxed to be eliminated

player_state := enum:
    Standard # 200 Shield, Infinite Health
    Siphon # Start with 100 Shield and 100 Health, 50HP Siphon
    Survival # Start with 100 Shield and 100 Health
    Critical # 1 HP


difficulty_trigger_switch := class(trigger_switch):
    CombatModeSwitches:[]switch_device
    State:player_state

    # Turns on switch while disabling other switches
    OnInteractingWithTrigger<override>(Agent:?agent):void =
        if(Player := player[Agent?]):
            for(CombatModeSwitch:CombatModeSwitches):
                CombatModeSwitch.TurnOff(Player)
            Switch.TurnOn(Player)

    # Sets Player State to State assigned
    OnTurningOnSwitch<override>(Agent:agent):void =
        if:
            Player := player[Agent]
            set CustomPlayer[GetSession()][Player].PlayerState = State
            
    OnTurningOffSwitch<override>(Agent:agent):void = {}


difficulty_section := class<concrete>:
    @editable
    CombatSwitches:[]switch_device = array{}
    @editable
    CombatTriggers:[]trigger_device = array{}
    @editable
    PrecisionSwitch:switch_device = switch_device{}
    @editable
    PrecisionTrigger:trigger_device = trigger_device{}

    PlayerStates:[]player_state = array:
        player_state.Standard, player_state.Siphon, player_state.Survival, player_state.Critical


    InitializeDevices():void =
        PrecisionTrigger.TriggeredEvent.Subscribe(OnInteractingWithTrigger)
        PrecisionSwitch.TurnedOnEvent.Subscribe(OnTurningOnSwitch)
        PrecisionSwitch.TurnedOffEvent.Subscribe(OnTurningOffSwitch)
        PrecisionSwitch.StateLoadEvent.Subscribe(OnSwitchLoaded)
        PrecisionSwitch.LoadStateForAll()
        for:
            Index := 0..CombatSwitches.Length-1
            DifficultyTriggerSwitch := difficulty_trigger_switch:
                Switch := CombatSwitches[Index]
                Trigger := CombatTriggers[Index]
                State := PlayerStates[Index]
                CombatModeSwitches := CombatSwitches
        do {DifficultyTriggerSwitch.Initialize()}

    OnInteractingWithTrigger(Agent:?agent):void =
        if(Player := player[Agent?]):
            PrecisionSwitch.ToggleState(Player)

    OnTurningOnSwitch(Agent:agent):void =
        if:
            Player := player[Agent]
            set CustomPlayer[GetSession()][Player].GuardState = guard_state.Precision

    OnTurningOffSwitch(Agent:agent):void =
        if:
            Player := player[Agent]
            set CustomPlayer[GetSession()][Player].GuardState = guard_state.Standard

    OnSwitchLoaded(Agent:agent):void =
        if(PrecisionSwitch.GetCurrentState[Agent]):
            OnTurningOnSwitch(Agent)
        else {OnTurningOffSwitch(Agent)}
            

CheckDifficulty(Player:player):void =
    if(PlayerMap := CustomPlayer[GetSession()][Player]):
        PlayerMap.UpdateUI(Player)
    if:
        FortCharacter := Player.GetFortCharacter[]
        Guard := Guards[GetSession()][Player]
        GuardState := CustomPlayer[GetSession()][Player].GuardState
        PlayerState := CustomPlayer[GetSession()][Player].PlayerState
    then:
        if(CustomPlayer[GetSession()][Player].GuardEliminationSubscription?.Cancel()) {}
        if(CustomPlayer[GetSession()][Player].GuardDamageSubscription?.Cancel()) {}
        case(GuardState):
            guard_state.Standard =>
            guard_state.Precision =>
                if:
                   Subscription := Guard.DamagedEvent.Subscribe(OnGuardDamaged)
                    set CustomPlayer[GetSession()][Player].GuardDamageSubscription = option{Subscription}  
        case(PlayerState):
            player_state.Standard =>
                HudElements := array:
                    creative_hud_identifier_health{}
                    creative_hud_identifier_health_numbers{}
                HudElements.Hide()
                if:
                    Subscription := Guard.EliminatedEvent.Subscribe(OnGuardEliminatedStandardMode)
                    set CustomPlayer[GetSession()][Player].GuardEliminationSubscription = option{Subscription}
                    FortCharacter.SetMaxHealth(Inf)
                    FortCharacter.SetMaxShield(200.0) 
            player_state.Siphon =>
                if:
                    Subscription := Guard.EliminatedEvent.Subscribe(OnGuardEliminatedSiphonMode)
                    set CustomPlayer[GetSession()][Player].GuardEliminationSubscription = option{Subscription}
                    FortCharacter.SetMaxHealth(100.0)
                    FortCharacter.SetMaxShield(100.0)
            player_state.Survival =>
                FortCharacter.SetMaxHealth(100.0)
                FortCharacter.SetMaxShield(100.0)
            player_state.Critical =>
                HudElements:= array:
                    creative_hud_identifier_shields{}
                    creative_hud_identifier_health{}
                    creative_hud_identifier_health_numbers{}
                    creative_hud_identifier_shield_numbers{}
                HudElements.Hide()
                # 1.0 kinda causes game to freeze
                FortCharacter.SetMaxHealth(1.1)
                FortCharacter.SetMaxShield(0.0)


# Called when PC Guards are eliminated
OnGuardEliminatedStandardMode(Result:device_ai_interaction_result):void =
    if:
        FortCharacter := Result.Source?.GetFortCharacter[]
        FortCharacter.SetShield(200.0)

# Called when PC Guards are eliminated 5 times
OnGuardEliminatedSiphonMode(Result:device_ai_interaction_result):void =
    if:
        Player := player[Result.Source?]
        Number := CustomPlayer[GetSession()][Player].Elimination
        Number.Modulo[5]
        Player.Siphon(50.0)

# Called when PC Guards are damaged
# Heals Guard to Max if damage doesn't eliminate guard (One-Shot Headshot Mechanic)
OnGuardDamaged(Result:device_ai_interaction_result):void =
    if:
        Player := player[Result.Source?]
        Guard := Result.Target?
        PowerUp := CustomPlayer[GetSession()][Player].HealthPowerUp
    then {PowerUp.Pickup(Guard)}

# Modulo Function (Number % Num == 0)
(Number:int).Modulo(Num:int)<decides><transacts>:void = Ceil(Number / Num) * Num = Number
