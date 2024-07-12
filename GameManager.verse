using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Fortnite.com/UI }
using { /Verse.org/Colors }
using { /Verse.org/Colors/NamedColors }
using { /Verse.org/Random }
using { /Verse.org/Simulation }

# Global Variable
var CustomPlayer:weak_map(session, [player]custom_player) = map{}
var Guards:weak_map(session, [player]guard_spawner_device) = map{}

# Custom creative device that manages the map
GameManager := class(creative_device):
    @editable
    Accolade:accolades_device = accolades_device{}
    @editable
    PCGuards:[]guard_spawner_device = array{}
    @editable
    Hub:hub = hub{}
    @editable
    PowerUp:health_powerup_device = health_powerup_device{}
 
    var Colors:[]color = array{Red, Blue, LimeGreen, Yellow}

    # Automatically triggered on game start
    OnBegin<override>()<suspends>:void =
        spawn {GrantXPForPlaytime()}   
        InitializePlayers()
        Hub.Initialize()


    # Grants xp every "Playtime" minutes
    GrantXPForPlaytime()<suspends>:void =
        loop:
            Sleep(600.0)
            for(Player:GetPlayers()):
                Accolade.Award(Player)

    # Initializes all players
    InitializePlayers():void =
        # weak maps have to be initialized before use
        if(set CustomPlayer[GetSession()] = map{}) {}
        if(set Guards[GetSession()] = map{}) {}
        set Colors = Shuffle(Colors)
        var Index:int = 0
        for:
            Player:GetPlayers()
            # Subscribe and Assign each guard to a player
            CP := custom_player:
                Bases := array{}
                Color := Colors[Index]
                HealthPowerUp := PowerUp
            Guard := PCGuards[Index]
            set Guards[GetSession()][Player] = Guard
            set CustomPlayer[GetSession()][Player] = CP
            PCGuards[Index].EliminatedEvent.Subscribe(OnGuardEliminated)
            ARGranter := Hub.HubDevices.WeaponGranters[4]
            ShotgunGranter := Hub.HubDevices.WeaponGranters[6]
        do:
            set Index += 1
            Hub.HubDevices.SignalRemoteGranter.GrantItem(Player)
            ARGranter.GrantItem(Player)
            ShotgunGranter.GrantItem(Player)

    # Called when PC Guards are eliminated
    OnGuardEliminated(Result:device_ai_interaction_result):void =
        if:
            Player := player[Result.Source?]
            set CustomPlayer[GetSession()][Player].Elimination += 1
        then:
            PieceControlBase := piece_control_base{}
            PieceControlBase.Start(Player)
        
# Gets a list of all players in the map
GetPlayers()<transacts>:[]player =
    GM := GameManager{}
    for(Player:GM.GetPlayspace().GetPlayers()):
        Player

# Shows Hud Elements on Player UI
(HudElements:[]hud_element_identifier).Show():void =
    GM := GameManager{}
    Hud := GM.GetPlayspace().GetHUDController()
    Hud.ShowElements(HudElements)

# Hides Hud Elements on Player UI
(HudElements:[]hud_element_identifier).Hide():void =
    GM := GameManager{}
    HudController := GM.GetPlayspace().GetHUDController()
    HudController.HideElements(HudElements)