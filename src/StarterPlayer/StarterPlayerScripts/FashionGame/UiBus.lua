--!strict
-- Client signals between scripts (D-694): one script asks another's window
-- to open. UiBus.OpenDance / UiBus.OpenMusic are BindableEvents; the club
-- button bar (ClubQuickBar) fires them, DanceController / ClubMusicController
-- listen.

local UiBus = {}

UiBus.OpenDance = Instance.new("BindableEvent")
UiBus.OpenMusic = Instance.new("BindableEvent")
-- (D-839) the 🎵 in the song banner (ClubQuickBar): dance the choreography / stop it (ChoreoController)
UiBus.ChoreoTap = Instance.new("BindableEvent")
-- (D-896) the 🎥 in the song banner (ClubQuickBar): the stage camera on / off (StageCameraController)
UiBus.StageCamTap = Instance.new("BindableEvent")
-- (D-1343) the dance window's 안무 tab: dance a song's phrase (key) on its own (ChoreoController)
UiBus.ChoreoPhrase = Instance.new("BindableEvent")
-- (D-1365) the guide NPC's "동네 둘러보기 다시 보기": the first-visit tour again (TourController)
UiBus.StartTour = Instance.new("BindableEvent")
-- (D-1377) the ☰ menu's 기부하기: the 💝 supporter window (BannerController)
UiBus.OpenSupport = Instance.new("BindableEvent")
-- (D-1697) the guide's "뭘 해야 할지 모르겠어.": the dashed way to the club (night) / 오후네컷 (day) (FirstGoalController)
UiBus.ShowWay = Instance.new("BindableEvent")
-- (D-1983) a player closed the first card / skipped the tour: "궁금한 게 있으면 나한테 찾아와!" and the guide outlined
-- (GuideHintController)
UiBus.GuideHint = Instance.new("BindableEvent")

-- (D-1792) the neon stage (NeonStageController): dance a song's choreography on the stage's shared
-- clock (soundId, server start time), or nil to stop (ChoreoController)
UiBus.ChoreoStage = Instance.new("BindableEvent")

-- (D-1403) the player card's 🎁 주기: give the item in my hand to (player, tool) (GiveController)
UiBus.GiveTo = Instance.new("BindableEvent")

return UiBus
