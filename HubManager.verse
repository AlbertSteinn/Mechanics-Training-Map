using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Fortnite.com/FortPlayerUtilities }
using { /Fortnite.com/UI }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }


# This class subscribes HubTriggers to HubSwitches
trigger_switch := class:
    Trigger:trigger_device = trigger_device{}
    Switch:switch_device = switch_device{}
    Base:multi_base = multi_base{}
    
    # Subscribes Trigger and Switch
    Initialize():void =
        Trigger.TriggeredEvent.Subscribe(OnInteractingWithTrigger)
        Switch.TurnedOnEvent.Subscribe(OnTurningOnSwitch)
        Switch.TurnedOffEvent.Subscribe(OnTurningOffSwitch)
        Switch.StateLoadEvent.Subscribe(OnSwitchLoaded)
        block:
            # Weird location to place this lol
            # Basically loads the switch for all players
            Switch.LoadStateForAll()

    # Called when Trigger is triggered
    # Toggles Switch
    OnInteractingWithTrigger(Agent:?agent):void =
        if(Player := player[Agent?]):
            Switch.ToggleState(Player)

    # Called when Switch is turned on
    # Adds Base to PlayerBases
    OnTurningOnSwitch(Agent:agent):void =
        if:
            Player := player[Agent]
            set CustomPlayer[GetSession()][Player].Bases += array{Base}
            CheckedBases := CustomPlayer[GetSession()][Player].Bases
        then {Print("Hub Switch Toggled On, NumberOfCheckedBases: {CheckedBases.Length}")}

    # Called when Switch is turned off
    # Removes Base from PlayerBases
    OnTurningOffSwitch(Agent:agent):void =
        if:
            Player := player[Agent]
            Bases := (CustomPlayer[GetSession()][Player].Bases).RemoveAllElements(Base)
            set CustomPlayer[GetSession()][Player].Bases = Bases
            CheckedBases := CustomPlayer[GetSession()][Player].Bases
        then {Print("Hub Switch Toggled Off, NumberOfCheckedBases: {CheckedBases.Length}")}
            
    # Called when Switch is loaded
    # Adds/Removes Base from PlayerBases
    OnSwitchLoaded(Agent:agent):void =
        # Check if switch is on
        if(Switch.GetCurrentState[Agent]):
            <# Switch is on #>
            # Add Base to PlayerBases
            OnTurningOnSwitch(Agent)
        else: <# Switch is off #>
            # Remove Base from PlayerBases
            OnTurningOffSwitch(Agent)

# Super Class
# All Sections have a PlayTrigger
play_trigger := class<abstract>:
    @editable
    PlayTrigger:trigger_device = trigger_device{}

    <#> 
        Called when PlayTrigger is trigger
        This function is intentionally left empty in the superclass but overridden in subclasses
        to provide specific behavior for interacting with PlayTrigger.
    OnInteractingWithPlayTrigger(Agent:?agent):void = {}

    # Subscribes PlayTrigger
    InitializeDevices():void =
        PlayTrigger.TriggeredEvent.Subscribe(OnInteractingWithPlayTrigger)

# Superclass that inherits PlayTrigger
# For Sections that have Hub Switches
hub_switches := class<abstract>(play_trigger):
    @editable
    HubSwitches:[]switch_device = array{}
    @editable
    HubTriggers:[]trigger_device = array{}

    var DefaultBase:base = base{}

    # Subscribes All Switches and Triggers
    InitializeDevices<override>():void =
        (super:)InitializeDevices()
        for(Index := 0..HubTriggers.Length - 1):
            var TriggerSwitch:trigger_switch = trigger_switch{}
            if:
                Base := piece_control_base[DefaultBase]
                TrigSwitch := trigger_switch:
                    Trigger := HubTriggers[Index]
                    Switch := HubSwitches[Index]
                    Base := Base.PieceControlBases.SetBases()[Index]
                set TriggerSwitch = TrigSwitch
            else if:
                Base := building_editing_base[DefaultBase]
                TrigSwitch := trigger_switch:
                    Trigger := HubTriggers[Index]
                    Switch := HubSwitches[Index]
                    Base := Base.BuildingEditingBases.SetBases()[Index]
                set TriggerSwitch = TrigSwitch
            # Subscribe each switch and trigger
            TriggerSwitch.Initialize()


freebuild_section := class<concrete>(play_trigger):
    @editable
    Base:freebuild_base = freebuild_base{}

    InitializeDevices<override>():void =
        (super:)InitializeDevices()
        Base.InitializeDevices()

    OnInteractingWithPlayTrigger<override>(Agent:?agent):void =
        Base.TransferToBase(Agent)
        
piece_control_section := class<concrete>(hub_switches):
    @editable
    Base:piece_control_base = piece_control_base{}

    InitializeDevices<override>():void =
        set DefaultBase = Base
        (super:)InitializeDevices()
        Base.InitializeDevices()

    OnInteractingWithPlayTrigger<override>(Agent:?agent):void =
        Base.TransferToBase(Agent)
 
ai_boxfight_section := class<concrete>(play_trigger):
    @editable
    Base:ai_boxfight_base = ai_boxfight_base{}

    InitializeDevices<override>():void =
        (super:)InitializeDevices()
        Base.InitializeDevices()

    OnInteractingWithPlayTrigger<override>(Agent:?agent):void =
        if:
            Player := player[Agent?]
            PlayerUI := GetPlayerUI[Player]
            set Base.PlayerButtonsUIMap[Player] = option{Base.ButtonsUI}
        then:
            PlayerUI.AddWidget(Base.ButtonsUI, player_ui_slot{InputMode := ui_input_mode.All})
            Base.AddUI(Player)
      
building_editing_section:= class<concrete>(hub_switches):
    @editable
    Base:building_editing_base = building_editing_base{}

    InitializeDevices<override>():void =
        set DefaultBase = Base
        (super:)InitializeDevices()
        Base.InitializeDevices()

    OnInteractingWithPlayTrigger<override>(Agent:?agent):void =
        Base.TransferToBase(Agent)
     

# Sections in the hub
hub_sections := class<concrete>():
    @editable
    FreeBuild:freebuild_section = freebuild_section{}
    @editable
    AIBoxfight:ai_boxfight_section = ai_boxfight_section{}
    @editable
    Buidling_Editing:building_editing_section = building_editing_section{}
    @editable
    PieceControl:piece_control_section = piece_control_section{}
    @editable
    DifficultyModes:difficulty_section = difficulty_section{}

    @editable
    SaveTrigger:trigger_device = trigger_device{}
    @editable
    LoadTrigger:trigger_device = trigger_device{}
    @editable
    HudDevice:hud_message_device = hud_message_device{}

    Initialize():void =
        SaveTrigger.TriggeredEvent.Subscribe(OnTriggeringSaveTrigger)
        LoadTrigger.TriggeredEvent.Subscribe(OnTriggeringLoadTrigger)
        DifficultyModes.InitializeDevices()
        Sections := array:
            FreeBuild, AIBoxfight, Buidling_Editing, PieceControl
        for(Section:Sections):
            Section.InitializeDevices()
        
    # Saves state of all hub switches
    OnTriggeringSaveTrigger(Agent:?agent):void =
        if(Player := player[Agent?]):
            HudDevice.Show(Player, ToMessage("</><heistenemy>Saved!"), ?DisplayTime:=3.0)
            HubSwitches := PieceControl.HubSwitches + Buidling_Editing.HubSwitches + DifficultyModes.CombatSwitches
            PrecisionSwitch := DifficultyModes.PrecisionSwitch
            PrecisionSwitch.SaveState(Player)
            var Index:int = 0
            for(Switch:HubSwitches):
                Switch.SaveState(Player)
                Print("Saving State")
                set Index += 1
            Print("Number of Saved Switches = {Index}")

    # Loads state of all hub switches
    OnTriggeringLoadTrigger(Agent:?agent):void =
        if:
            Player := player[Agent?]
            # Empty the PlayerBases for player.
            set CustomPlayer[GetSession()][Player].Bases = array{}
        then:
            HudDevice.Show(Player, ToMessage("</><intro>Loaded!"), ?DisplayTime:=3.0)
            HubSwitches := PieceControl.HubSwitches + Buidling_Editing.HubSwitches + DifficultyModes.CombatSwitches
            for(Switch:HubSwitches):
                Switch.LoadState(Player)
                Print("Loading State")
                <#>
                    For some reason, loadstate function doesn't trigger the loadedevent
                    only loadedforall() triggers it.
                # Toggle twice to keep original state
                if(Switch.GetCurrentState[Player]):
                    Switch.ToggleState(Player)
                    Switch.ToggleState(Player)
            PrecisionSwitch := DifficultyModes.PrecisionSwitch
            PrecisionSwitch.LoadState(Player)
            PrecisionSwitch.ToggleState(Player)
            PrecisionSwitch.ToggleState(Player)
                
# This class subscribes a Buttons to Item Granters
button_granters := class:
    Button:button_device
    Granter:item_granter_device

    # Subscribes button
    InitializeDevice():void =
        Button.InteractedWithEvent.Subscribe(OnPressingButton)

    # Grants item to player
    OnPressingButton(Agent:agent):void =
        Granter.GrantItem(Agent)


# Other devices in the hub
devices := class<concrete>:
    @editable
    WeaponButtons:[]button_device = array{}
    @editable
    WeaponGranters:[]item_granter_device = array{}
    @editable
    SignalRemoteGranter:item_granter_device = item_granter_device{}
    @editable
    SignalRemoteManager:signal_remote_manager_device = signal_remote_manager_device{}
    @editable
    Rift:teleporter_device = teleporter_device{}
    @editable
    MutatorZone:mutator_zone_device = mutator_zone_device{}
    @editable
    SpawnPads:[]player_spawner_device = array{}
    @editable
    EndGameDevice:end_game_device = end_game_device{}
    @editable
    EndGameSwitch:switch_device = switch_device{}
    @editable
    SpectateButton:button_device = button_device{}
    @editable
    SpectateClassSelector:class_and_team_selector_device  = class_and_team_selector_device{}
    @editable
    PopUpEndGame:popup_dialog_device = popup_dialog_device{}
    @editable
    PopUpSpectate:popup_dialog_device = popup_dialog_device{}
    @editable
    Assistant:character_device = character_device{}
    @editable
    PopUpInstructions:[]popup_dialog_device = array{}
    
    # Subscribes all hub devices
    InitializeDevices():void =
        Assistant.InteractedWithEvent.Subscribe(OnInteractingWithCharacter)
        SignalRemoteManager.PrimarySignalEvent.Subscribe(OnTriggeringSignalRemote)
        MutatorZone.AgentEntersEvent.Subscribe(OnPlayerEnteringZone)
        for(SpawnPad:SpawnPads):
            SpawnPad.SpawnedEvent.Subscribe(OnPlayerEnteringZone)
        EndGameSwitch.TurnedOnEvent.Subscribe(OnInteractingWithEndGameSwitch)
        EndGameSwitch.TurnedOffEvent.Subscribe(OnInteractingWithEndGameSwitch)
        SpectateButton.InteractedWithEvent.Subscribe(OnInteractingWithSpectateButton)
        PopUpEndGame.RespondingButtonEvent.Subscribe(OnInteractingWithPopUpButtonEndGame)
        PopUpSpectate.RespondingButtonEvent.Subscribe(OnInteractingWithPopUpSpectateButton)
        # Subscribe all buttons to item granters
        for:
            Index := 0..WeaponButtons.Length - 1
            ButtonandGranter := button_granters:
                Button := WeaponButtons[Index]
                Granter := WeaponGranters[Index]
        do {ButtonandGranter.InitializeDevice()}

    # Teleports player to map hub
    OnTriggeringSignalRemote(Agent:agent):void =
        Rift.Teleport(Agent)

    OnInteractingWithCharacter(Agent:agent):void =
        if(PopUp := PopUpInstructions[0]):
            PopUp.RespondingButtonEvent.Subscribe(OnInteractingWithPopUpInstruction1)
            PopUp.Show(Agent)

    OnInteractingWithPopUpInstruction1(Agent:agent, Index:int):void =
        if(Index = 0):
            if(PopUp := PopUpInstructions[1]):
                PopUp.RespondingButtonEvent.Subscribe(OnInteractingWithPopUpInstruction2)
                PopUp.Show(Agent)

    OnInteractingWithPopUpInstruction2(Agent:agent, Index:int):void =
        var PopUp:popup_dialog_device = popup_dialog_device{}
        if:
            Index = 0
            PopUpInstruction := PopUpInstructions[2]
            set PopUp = PopUpInstruction
        if:
            Index = 1
            PopUpInstruction := PopUpInstructions[3]
            set PopUp = PopUpInstruction
        PopUp.RespondingButtonEvent.Subscribe(OnInteractingWithPopUpInstruction1)
        PopUp.Show(Agent)

    # Sets player health and shields to infinity.
    OnPlayerEnteringZone(Agent:agent):void =
        HudElements := array:
            creative_hud_identifier_shields{}
            creative_hud_identifier_health{}
            creative_hud_identifier_health_numbers{}
            creative_hud_identifier_shield_numbers{}
        HudElements.Show()
        if:
            Player := player[Agent]
            UI := CustomPlayer[GetSession()][Player].EliminationCanvas?
            PlayerUI := GetPlayerUI[Player]
        then {PlayerUI.RemoveWidget(UI)}
        if:
            Player := player[Agent]
            # Reset PC Guard Elimination Counter
            set CustomPlayer[GetSession()][Player].Elimination = 0
            FortCharacter := Player.GetFortCharacter[]
            FortCharacter.SetMaxHealth(Inf)
            FortCharacter.SetMaxShield(Inf)
            
    # Shows UI when EndGameSwitch is interacted with
    OnInteractingWithEndGameSwitch(Agent:agent):void =
        PopUpEndGame.SetButtonCount(2)
        PopUpEndGame.SetDescriptionText(ToMessage("End Game?"))
        PopUpEndGame.SetButtonText(ToMessage("Yes"), 0)
        PopUpEndGame.SetButtonText(ToMessage("No"), 1)
        PopUpEndGame.Show(Agent)
        
    # Shows UI when SpectateButton is interacted with
    OnInteractingWithSpectateButton(Agent:agent):void =
        PopUpSpectate.SetButtonCount(2)
        PopUpSpectate.SetDescriptionText(ToMessage("Switch to Spectate?"))
        PopUpSpectate.SetButtonText(ToMessage("Yes"), 0)
        PopUpSpectate.SetButtonText(ToMessage("No"), 1)
        PopUpSpectate.Show(Agent)

    OnInteractingWithPopUpSpectateButton(Agent:agent, Index:int):void =
        if(Index = 1):
            PopUpEndGame.Hide(Agent)
        else if: 
            Player := player[Agent]
            FortCharacter := Player.GetFortCharacter[]
        then:
            # Change player to class
            SpectateClassSelector.ChangeClass(Player)
            # Eliminate player
            FortCharacter.Damage(Inf)

    OnInteractingWithPopUpButtonEndGame(Agent:agent, Index:int):void =
        if(Index = 1):
            PopUpEndGame.Hide(Agent)
        else:
            # End game
            EndGameDevice.Activate(Agent)
        
    
# This class handles sections and devices
hub := class<concrete>:
    @editable
    HubSections:hub_sections = hub_sections{}
    @editable
    HubDevices:devices = devices{}

    Initialize():void =
        HubDevices.InitializeDevices()
        HubSections.Initialize()
