using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Fortnite.com/FortPlayerUtilities }
using { /Fortnite.com/UI }
using { /Verse.org/Random }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/UI }


# Super class
base := class<concrete><unique>:
    Start(Player:player):void = {}
    InitializeDevices():void = {}

fb_trigger_switch := class(trigger_switch):
    Speed:string
    SpeedModulator:movement_modulator_device
    TrackerMap:[player]tracker_device
    FBSwitches:[]switch_device

    OnInteractingWithTrigger<override>(Agent:?agent):void =
        if(Player := player[Agent?]):
            for(FBSwitch:FBSwitches):
                FBSwitch.TurnOff(Player)
            Switch.TurnOn(Player)
            Print("Trigger triggered")
        
    OnTurningOnSwitch<override>(Agent:agent):void =
        if:
            Player := player[Agent]
            Tracker := TrackerMap[Player]
        then:
            spawn {SetDescription(Player, Tracker)}
            SpeedModulator.Activate(Player)
            Print("FBSwitch should be on")

    OnTurningOffSwitch<override>(Agent:agent):void = {}

    # Sets the description text for tracker
    <# 
        Tracker.SetDescriptionText(ToMessage("{Speed}")) doesn't change the text anymore for some reason.
        Only works once. Hence, why I created this function
    #>
    SetDescription(Player:player, Tracker:tracker_device)<suspends>:void =
        Tracker.Remove(Player)
        Sleep(0.0)
        Tracker.SetDescriptionText(ToMessage("{Speed}"))
        Tracker.Assign(Player)
        

freebuild_base := class<concrete>(base):
    @editable
    Rift:teleporter_device = teleporter_device{}
    @editable
    Bombs:[]explosive_device = array{}
    @editable
    MutatorZones:[]mutator_zone_device = array{}
    @editable
    SpeedSwitches:[]switch_device = array{}
    @editable
    SpeedTriggers:[]trigger_device = array{}
    @editable
    SpeedModulators:[]movement_modulator_device = array{}
    @editable
    BuildResetTrigger:trigger_device = trigger_device{}
    @editable
    SpeedTrackers:[]tracker_device = array{}
    @editable
    Volume:volume_device = volume_device{}
    
    var PlayerTrackerMap:[player]tracker_device = map{}
    var NumOfPlayers:int = 0

    Speeds:[]string = array:
        "0.7", "0.8", "0.9", "1.0", "1.1", "1.2", "1.3", "1.4", "1.5"
    
    Start<override>(Player:player):void =
        Rift.Teleport(Player)

    InitializeDevices<override>():void =
        BuildResetTrigger.TriggeredEvent.Subscribe(OnInteractingWithResetTrigger)
        for(MutatorZone:MutatorZones):
            MutatorZone.AgentEntersEvent.Subscribe(OnPlayerEnteringMutatorZone)
        Volume.AgentEntersEvent.Subscribe(OnPlayerEnteringZone)
        Volume.AgentExitsEvent.Subscribe(OnPlayerExitingZone)
        block:
            var Index:int = 0
            for:
                Player:GetPlayers()
                SpeedTracker := SpeedTrackers[Index]
                set PlayerTrackerMap[Player] = SpeedTracker
            do {set Index += 1}
        for:
            Index := 0..SpeedTriggers.Length-1
            FBTiggerSwitch := fb_trigger_switch:
                Trigger := SpeedTriggers[Index]
                Switch := SpeedSwitches[Index]
                Speed := Speeds[Index]
                SpeedModulator := SpeedModulators[Index]
                TrackerMap := PlayerTrackerMap
                FBSwitches := SpeedSwitches
        do {FBTiggerSwitch.Initialize()}

    OnPlayerExitingZone(Agent:agent):void =
        if:
            Player := player[Agent]
            Tracker := PlayerTrackerMap[Player]
            # set Player speed to normal
            SpeedModulator := SpeedModulators[3]
            set NumOfPlayers -= 1
        then:
            SpeedModulator.Activate(Player)
            Tracker.Remove(Player)
            Print("Tracker Unassigned")
        if(NumOfPlayers = 0):
            BuildResetTrigger.Trigger(Agent)

    OnInteractingWithResetTrigger(Agent:?agent):void =
        for:
            Bomb:Bombs
            Player := player[Agent?]
        do:
            Bomb.Explode(Player)
            Bomb.Reset()

    OnPlayerEnteringMutatorZone(Agent:agent):void =
        Rift.Teleport(Agent)

    OnPlayerEnteringZone(Agent:agent):void =
        if:
            Player := player[Agent]
            Speed := Speeds[3] # 1.0 Speed
            Trigger := SpeedTriggers[3] 
            Tracker := PlayerTrackerMap[Player]
            set NumOfPlayers += 1
        then:
            Tracker.Assign(Player)
            Trigger.Trigger(Player)
            Print("Tracker Assigned")


ai_boxfight_base := class<concrete>(base):
    @editable
    Rift:teleporter_device = teleporter_device{}
    @editable
    Bomb:explosive_device = explosive_device{}
    @editable
    Guard:guard_spawner_device = guard_spawner_device{}
    @editable
    Volume:volume_device = volume_device{}
    @editable
    Tracker:tracker_device = tracker_device{}
    @editable
    HudDevice:hud_message_device = hud_message_device{}
    @editable
    WaveHudDevice:hud_message_device = hud_message_device{}
    @editable
    Accolades:[]accolades_device = array{}

    StopWave:event() = event(){}
    
    var NumberOfAgents:int = 0
    var WaveNumber:int = 1
    var NumberOfGuards:[player]?int = map{}
    var PlayerButtonsUIMap:[player]?canvas = map{}
    var PlayerNumberUIMap:[player]?canvas = map{}
    var InPlayer:?player = false
    var ButtonsUI:canvas = canvas{}
    var TitleUI:canvas = canvas{}
    var PreviousButton:button_quiet = button_quiet{}
    var NextButton:button_quiet = button_quiet{}
    var ConfirmButton:button_loud = button_loud{}
    var CancelButton:button_loud = button_loud{}
   
    Start<override>(Player:player):void =
        if(InPlayer = false):
            Rift.Teleport(Player)
            Print("Rifted to AIB")
        else if(FortPlayer := InPlayer?):
            Message := ToMessage("Access Denied: This base is currently in use by", FortPlayer)
            HudDevice.Show(Player, Message, ?DisplayTime := 4.0)

    InitializeDevices<override>():void =
        set PreviousButton = button_quiet{DefaultText := ToMessage("◀")}
        set NextButton = button_quiet{DefaultText := ToMessage("▶")}
        set ConfirmButton = button_loud{DefaultText := ToMessage("CONFIRM")}
        set CancelButton = button_loud{DefaultText := ToMessage("CANCEL")}
        PreviousButton.OnClick().Subscribe(Subtract)
        NextButton.OnClick().Subscribe(Add)
        ConfirmButton.OnClick().Subscribe(Transfer)
        CancelButton.OnClick().Subscribe(Cancel)
        Volume.AgentEntersEvent.Subscribe(OnPlayerEnteringZone)
        Volume.AgentExitsEvent.Subscribe(OnPlayerExitingZone)
        Guard.EliminatedEvent.Subscribe(OnEliminatingGuard)
        block:
            set ButtonsUI = canvas:
                Slots := array:
                    canvas_slot:
                        Anchors := anchors:
                            Minimum := vector2{X := 0.5, Y := 0.5}
                            Maximum := vector2{X := 0.5, Y := 0.5}
                        Offsets := margin:
                            Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := stack_box:
                            Orientation := orientation.Vertical
                            Slots := array:
                                stack_box_slot:
                                    Padding := margin{Bottom := 15.0}
                                    Widget := stack_box:
                                        Orientation := orientation.Horizontal
                                        Slots := array:
                                            stack_box_slot:
                                                Padding := margin{Right := 30.0}
                                                Widget := PreviousButton
                                            stack_box_slot:
                                                Padding := margin{Left := 30.0}
                                                Widget := NextButton
                                stack_box_slot:
                                    Widget := stack_box:
                                        Orientation := orientation.Horizontal
                                        Slots := array:
                                            stack_box_slot:
                                                Padding := margin{Right := 10.0}
                                                Widget := CancelButton
                                            stack_box_slot:
                                                Padding := margin{Left := 10.0}
                                                Widget := ConfirmButton

            
    StartWave()<suspends>:void =
        race:
            StopWave.Await()
            block:
                Sleep(3.0)
                if(Player := InPlayer?):
                    Print("Showing Wave")
                    Tracker.SetDescriptionText(ToMessage("Wave {WaveNumber}"))
                    # Unassign and assign cuz Epic broke it. Description won't update without this. W Epic
                    Tracker.Remove(Player)
                    Tracker.Assign(Player)
                    Message := ToMessage("WAVE {WaveNumber}")
                    WaveHudDevice.Show(Player, Message, ?DisplayTime := 3.5)
                Sleep(3.0)
                for(Index := 0..NumberOfGuards[InPlayer?]? - 1):
                    set NumberOfAgents += 1
                    Guard.Spawn()
                    Guard.Reset()
                
    OnPlayerEnteringZone(Agent:agent):void =
        if:
            Player := player[Agent]
            NumOfGuards := NumberOfGuards[Player]?
            FortCharacter := Player.GetFortCharacter[]
        then:
            FortCharacter.SetMaxHealth(100.0)
            FortCharacter.SetMaxShield(100.0)
            set InPlayer = option{Player}
            set NumberOfAgents = 1
            Tracker.SetTitleText(ToMessage("1 V {NumOfGuards}"))
            Guard.Despawn() # to fix glitch of bots still spawned after player leaves (1v10 bug)
            spawn {StartWave()}

    OnPlayerExitingZone(Agent:agent):void =
        defer:
            if:
                set PlayerButtonsUIMap[InPlayer?] = false
                set PlayerNumberUIMap[InPlayer?] = false
                set InPlayer = false
                set WaveNumber = 1
                # set NumberOfAgents = 0 <# Not needed as guards are considered eliminated when despawned #>
        StopWave.Signal()
        Tracker.Remove(Agent)
        Guard.Despawn()
        Explode()
        
    # Triggers explosives
    Explode():void =
        if(Player := InPlayer?):
            Bomb.Explode(Player)
            Bomb.Reset()

    # Called when guards are eliminated or despawned
    OnEliminatingGuard(Result:device_ai_interaction_result):void =
        set NumberOfAgents -= 1
        Print("Number of Agents including Player: {NumberOfAgents}")
        if:
            Player := InPlayer?
            NumberOfAgents = 1 <# True means all guards eliminated #>
            FortCharacter := Result.Source?.GetFortCharacter[]
            FortCharacter.SetHealth(FortCharacter.GetMaxHealth())
            FortCharacter.SetShield(FortCharacter.GetMaxShield())
        then:
            set WaveNumber += 1
            Explode()
            spawn {StartWave()}
            if:
                NumberOfGuards[Player]? <= 3
                Accolade := Accolades[0]
            then {Accolade.Award(Player)}
            else if:
                NumberOfGuards[Player]? <= 6
                Accolade := Accolades[1]
            then {Accolade.Award(Player)}
            else if(Accolade := Accolades[2]):
                Accolade.Award(Player)
        else if(InPlayer?.Siphon(50.0)) {}


    AddUI(Player:player):void =
        if(NumberOfGuards[Player]?) {}
        else if(set NumberOfGuards[Player] = option{5}) {}

        var NumOfGuards:int = 0
        if:
            GuardNumber := NumberOfGuards[Player]?
            set NumOfGuards = GuardNumber
        NumberUI := canvas:
            Slots := array:
                canvas_slot:
                    Anchors := anchors:
                        Minimum := vector2{X := 0.495, Y := 0.44}
                        Maximum := vector2{X := 0.495, Y := 0.44}
                    Offsets := margin:
                        Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0
                    Alignment := vector2{X := 0.0, Y := 0.0}
                    SizeToContent := true
                    Widget := text_block:
                        DefaultText := ToMessage("{NumOfGuards}")

        set TitleUI = canvas:
            Slots := array:
                canvas_slot:
                    Anchors := anchors:
                        Minimum := vector2{X := 0.45, Y := 0.39}
                        Maximum := vector2{X := 0.45, Y := 0.39}
                    Offsets := margin:
                        Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0
                    Alignment := vector2{X := 0.0, Y := 0.0}
                    SizeToContent := true
                    Widget := text_block:
                        DefaultText := ToMessage("Number of Bots")
        if:
            PlayerUI := GetPlayerUI[Player]
            set PlayerNumberUIMap[Player] = option{NumberUI}
        then:
            PlayerUI.AddWidget(NumberUI)
            PlayerUI.AddWidget(TitleUI)

                                    
    Add(Message:widget_message):void =
        if:
            NumOfGuards := NumberOfGuards[Message.Player]? + 1
            NumOfGuards <= 10
            set NumberOfGuards[Message.Player] = option{NumOfGuards}
        else if(set NumberOfGuards[Message.Player] = option{1}) {}
        RemoveNumberandTitleUI(Message.Player)
        AddUI(Message.Player)

    Subtract(Message:widget_message):void =
        if:
            NumOfGuards := NumberOfGuards[Message.Player]? - 1
            NumOfGuards >= 1
            set NumberOfGuards[Message.Player] = option{NumOfGuards}
        else if(set NumberOfGuards[Message.Player] = option{10}) {}
        RemoveNumberandTitleUI(Message.Player)
        AddUI(Message.Player)

    Transfer(Message:widget_message):void =
        Cancel(Message)
        spawn {WaitForUIToDisappear(Message.Player)}

    WaitForUIToDisappear(Player:player)<suspends>:void =
        Sleep(0.75)
        Start(Player)

    RemoveNumberandTitleUI(Player:player):void =
        if:
            PlayerUI := GetPlayerUI[Player]
            NumberUI := PlayerNumberUIMap[Player]?
        then:
            PlayerUI.RemoveWidget(NumberUI)
            PlayerUI.RemoveWidget(TitleUI)

    Cancel(Message:widget_message):void =
        if:
            PlayerUI := GetPlayerUI[Message.Player]
            ButtonUI := PlayerButtonsUIMap[Message.Player]?
        then:
            RemoveNumberandTitleUI(Message.Player)
            PlayerUI.RemoveWidget(ButtonUI)
            Print("UI removed")


               
be_bases := class<concrete>:
    @editable
    Ryft90s:ryft90s = ryft90s{}
    @editable
    Quads:quadedits = quadedits{}
    @editable
    EditDowns:editdowns = editdowns{}
    @editable
    SevenLED:sevenled = sevenled{}

    SetBases()<transacts>:[]be_base =
        array:
            Ryft90s, Quads, EditDowns, SevenLED
                                

building_editing_base := class<concrete>(base):
    @editable
    BuildingEditingBases:be_bases = be_bases{}
    @editable
    HudDevice:hud_message_device = hud_message_device{}

    var BEBasesPerPlayer:[player][]be_base = map{}

    InitializeDevices<override>():void =
        for(Base:BuildingEditingBases.SetBases()):
            Base.InitializeDevices()

    # Picks a random base from Player's Map (Player choices)
    Start<override>(Player:player):void =
        if:
            Bases := CustomPlayer[GetSession()][Player].Bases
            BEBases :=
                for(Base:Bases, BEBase := be_base[Base]):
                    BEBase
        then:
            Print("Bases length {Bases.Length}")
            Print("Number of BEB Bases Chosen by Player {BEBases.Length}")
            BEBases.RandomizeBase(Player, HudDevice)
  

multi_base := class(base):
    @editable
    Rift:teleporter_device = teleporter_device{}
    @editable
    Volume:volume_device = volume_device{}
    @editable
    Bombs:[]explosive_device = array{}
    
    var InPlayer:?player = false

    InitializeDevices<override>():void =
        Volume.AgentEntersEvent.Subscribe(OnPlayerEnteringZone)
        Volume.AgentExitsEvent.Subscribe(OnPlayerExitingZone)
        
    OnPlayerEnteringZone(Agent:agent):void =
        set InPlayer = option{player[Agent]}
        Explode()
    
    OnPlayerExitingZone(Agent:agent):void =
        defer:
            set InPlayer = false
        Explode()

    Explode():void =
        for(Bomb:Bombs, Player := InPlayer?):
            Bomb.Explode(Player)
            Bomb.Reset()

    
be_base := class(multi_base):
    @editable
    MiniVolume:volume_device = volume_device{}

    InitializeDevices<override>():void =
        (super:)InitializeDevices()
        MiniVolume.AgentEntersEvent.Subscribe(OnPlayerEnteringVolume)

    OnPlayerEnteringVolume(Agent:agent):void =
        if(Player := player[Agent]):
            Print("Entered Mini Volume ")
            BuidiingEditingBase := building_editing_base{}
            BuidiingEditingBase.Start(Player)

    
ryft90s := class<concrete>(be_base):
quadedits := class<concrete>(be_base):
editdowns := class<concrete>(be_base):
sevenled := class<concrete>(be_base):

pc_bases := class<concrete>:
    @editable
    BaseA:pcbase_A = pcbase_A{}
    @editable
    BaseB:pcbase_B = pcbase_B{}
    @editable
    BaseC:pcbase_C = pcbase_C{}
    @editable
    BaseD:pcbase_D = pcbase_D{}
    @editable
    BaseE:pcbase_E = pcbase_E{}
    @editable
    BaseF:pcbase_F = pcbase_F{}
    @editable
    BaseG:pcbase_G = pcbase_G{}
    @editable
    BaseH:pcbase_H = pcbase_H{}
    @editable
    BaseI:pcbase_I = pcbase_I{}
    @editable
    BaseJ:pcbase_J = pcbase_J{}

    SetBases()<transacts>:[]pc_base =
        array:
            BaseA, BaseB, BaseC, BaseD, BaseE, BaseF, BaseG, BaseH, BaseI, BaseJ


piece_control_base := class<concrete>(base):
    @editable
    PieceControlBases:pc_bases = pc_bases{}
    @editable
    HudDevice:hud_message_device = hud_message_device{}

    InitializeDevices<override>():void =
        for(Base:PieceControlBases.SetBases()):
            Base.InitializeDevices()

    # Picks a random base from Player's Map (Player choices)
    Start<override>(Player:player):void =
        if:
            Bases := CustomPlayer[GetSession()][Player].Bases
            PCBases :=
                for(Base:Bases, PCBase := pc_base[Base]):
                    PCBase
        then:
            Print("Bases length {Bases.Length}")
            Print("Number of PCB Bases Chosen by Player {PCBases.Length}")
            PCBases.RandomizeBase(Player, HudDevice)

prop_barrier := class<concrete>:
    @editable
    Props:teleporter_device = teleporter_device{}
    @editable
    BarrierDevices:[]barrier_device = array{}

pc_base := class(multi_base):
    @editable
    PropAndBarriers:[]prop_barrier = array{}

    var Barriers:[]barrier_device = array{}
    var Guard:guard_spawner_device = guard_spawner_device{}
    var GuardOriginalLocation:transform = transform{}

    InitializeDevices<override>():void =
        (super:)InitializeDevices()
        Rift.TeleportedEvent.Subscribe(OnPlayerTeleported)

    OnPlayerTeleported(Agent:agent):void =
        if(Player := player[Agent]):
            CheckDifficulty(Player)
        defer:
            for(Barrier:Barriers):
                Barrier.Disable()
            Guard.Spawn()
            Guard.ForceAttackTarget(Agent)
        # Enable barriers in case player teleports to same base (player didn't leave base)
        # since OnPlayerLeavingZone won't be called
        for(Barrier:Barriers):
            Barrier.Enable()
        if:
            Index := GetRandomInt(0, PropAndBarriers.Length - 1)
            Prop := PropAndBarriers[Index].Props
            BarrierDevices := PropAndBarriers[Index].BarrierDevices
            set Barriers = BarrierDevices
            #PlayerGuard := CustomPlayer[GetSession()][InPlayer?].Guard
            PlayerGuard := Guards[GetSession()][InPlayer?]
            set Guard = PlayerGuard
            set GuardOriginalLocation = Guard.GetTransform()
            Guard.TeleportTo[Prop.GetTransform()]
        then {Print("Index: {Index}, Guard Spawned")}
        
    OnPlayerExitingZone<override>(Agent:agent):void =
        Print("Player left PC Base")
        defer:
            (super:)OnPlayerExitingZone(Agent)
        Guard.Despawn()
        if(Guard.TeleportTo[GuardOriginalLocation]) {}
        for(Barrier:Barriers):
            Barrier.Enable()


pcbase_A := class<concrete>(pc_base):
pcbase_B := class<concrete>(pc_base):
pcbase_C := class<concrete>(pc_base):
pcbase_D := class<concrete>(pc_base):
pcbase_E := class<concrete>(pc_base):
pcbase_F := class<concrete>(pc_base):
pcbase_G := class<concrete>(pc_base):
pcbase_H := class<concrete>(pc_base):
pcbase_I := class<concrete>(pc_base):
    @editable
    PropManipulator:prop_manipulator_device = prop_manipulator_device{}
    @editable
    Trigger:trigger_device = trigger_device{}
    @editable
    Barrier:barrier_device = barrier_device{}
    @editable
    Billboard:billboard_device = billboard_device{}

    InitializeDevices<override>():void =
        (super:)InitializeDevices()
        Trigger.TriggeredEvent.Subscribe(OnInteractingWithTrigger)

    OnInteractingWithTrigger(Agent:?agent):void =
        PropManipulator.HideProps()
        Billboard.HideText()

    OnPlayerTeleported<override>(Agent:agent):void =
        PropManipulator.ShowProps()
        Billboard.ShowText()
        Barrier.Enable()
        spawn {DisableBarrier()}
        (super:)OnPlayerTeleported(Agent)

    DisableBarrier()<suspends>:void =
        Sleep(1.0)
        Barrier.Disable()

pcbase_J := class<concrete>(pc_base):
            
    
(Base:base).TransferToBase(Agent:?agent):void =
    if(Player := player[Agent?]):
        Base.Start(Player)

(Bases:[]multi_base).RandomizeBase(Player:player, HudDevice:hud_message_device):void =
    if(Bases.Length = 0):
        return

    var Index:int = 0
    var NumOfTimes:int = 0
    loop:
        set NumOfTimes += 1
        if:
            # To prevent infinite loop
            NumOfTimes = 20
            Bases[Index].InPlayer?
        then:
            HudDevice.Show(Player, ToMessage("</><heistenemy>Base Choice(s) occupied"), ?DisplayTime:=3.0)
            Print("All choices occupied by players")
            break
        if:
            set Index = GetRandomInt(0, Bases.Length - 1)
            Base := Bases[Index]
            Base.InPlayer = false or Player = Base.InPlayer?
        then:
            Base.Explode()
            Base.Rift.Teleport(Player)
            Print("Rifting Player to base Index {Index}")
            break
        else {Print("Player in base at Index {Index}")}

# Custom Siphon function. Heals player
(Player:player).Siphon(Value:float)<transacts>:void =
    if(FortCharacter := Player.GetFortCharacter[]):
        if(FortCharacter.GetHealth() + Value <= FortCharacter.GetMaxHealth()):
            FortCharacter.SetHealth(Value + FortCharacter.GetHealth())
        else:
            ShieldToAdd := Value - (FortCharacter.GetMaxHealth() - FortCharacter.GetHealth())
            FortCharacter.SetHealth(FortCharacter.GetMaxHealth())
            FortCharacter.SetShield(ShieldToAdd + FortCharacter.GetShield())


ToMessage<localizes>(Text:string):message = "{Text}"
ToMessage<localizes>(Text:string, Player:player):message = "{Text} {Player}"
PlayerName<localizes>(Player:player):message = "{Player}"
