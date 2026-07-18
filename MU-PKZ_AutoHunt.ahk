; MU-PKZ Auto Hunt / Combo - AutoHotkey v1.1 (32-bit)
; Boss scanner + native MU Helper pathfinding + event routing/safe-zone escape.

#NoEnv
#SingleInstance Off
#UseHook On
#MaxThreadsPerHotkey 2
SetBatchLines, -1
CoordMode, Mouse, Client
SendMode Input
SetKeyDelay, 0, 0

; ========== GLOBAL VARIABLES ==========
; --- Process / Memory ---
global IsClassDL := 1                ; Đặt thành 1 nếu acc này là DL, đặt thành 0 nếu là class khác
global SummonSkillKey := "5"         ; Phím cài đặt skill Triệu Hồi (Summon) trong game
global HasSummonedCurrentBoss := 0   ; Biến trạng thái để kiểm tra xem đã triệu hồi ở Boss này chưa
global hProcess := 0
global GamePid := 0
global GameHwnd := 0
global ManagerMode := true
global WorkerMode := false
global WorkerTargetPid := 0
global WorkerAutoStart := false
global WorkerSingleBossArg := -1
global WorkerMultiBossArg := -1
global WorkerAutoTravelArg := -1
global WorkerComboAutoStart := false
global WorkerComboClassIdArg := 0
global WorkerStartAttempts := 0
global WorkerMaxStartAttempts := 15
global InstanceMutexHandle := 0
global ManagerAccountRows := []
global ManagerFirstRefresh := true
global ManagerLastRefreshTick := 0
global MaxManagerAccounts := 12
global SettingsReloadMessage := 0x8001
global WorkerCommandMessage := 0x8002
; Hunt and combo use independent idempotent mailboxes. The manager can post
; both desired states in one reconcile pass without either command replacing
; the other before the worker timer runs.
global PendingWorkerHuntDesired := -1
global PendingWorkerComboDesiredClassId := -1
global PendingComboStartClassId := 0
global WorkerHuntDesired := false
global WorkerHuntStarting := false
global WorkerHuntFailed := false
global WorkerLastWindowTitle := ""
global ManagerListRebuilding := false
global ManagerDesiredWorkers := {}
global ManagerPidCharacters := {}
global ManagerWorkerLaunchTick := {}
global ManagerEnabledCharacters := "*"
global ManagerComboSelectedPid := 0
global ManagerComboSelectedCharacter := ""
global ManagerComboDesiredPid := 0
global ManagerComboDesiredCharacter := ""
global ManagerComboObservedPid := 0
global ManagerComboObservedClass := "OFF"
global ManagerComboClass := "RF"
global ManagerComboSpeedPercent := 286
global ManagerCtrlF1Remembered := {}
global ManagerReconcileBusy := false
global BossNames := ["Dong 1: Dai Chien Lorencia"
                , "Dong 2: Phu Thuy Trang"
                , "Dong 3: Tu Than Xuong So"
                , "Dong 4: Rong Do"
                , "Dong 5: Tho Ngoc"
                , "Dong 6: Mua He"
                , "Dong 7: Boss Viem Dia Chua"
                , "Dong 8: Boss Class"
                , "Dong 9: Kho Bau Hoang Toc"
                , "Dong 10: Boss Chien Than"
                , "Dong 11: Boss Ma Than Tuong"
                , "Dong 12: Boss Ta Than Tuong"
                , "Dong 13: Boss Nguu Vuong"
                , "Dong 14: Boss Thuy Hoang De"
                , "Dong 15: Boss Anubis"
                , "Dong 16: Boss Long Vuong"
                , "Dong 17: Boss Hon Thach"
                , "Dong 18: Boss Ma Thu"]

; Khai báo biến lưu trạng thái bật/tắt (1 là bật, 0 là tắt) cho từng Boss
global BossFilters := {1:0, 2:1, 3:0, 4:0, 5:1, 6:1, 7:1, 8:0, 9:1, 10:1, 11:1, 12:1, 13:1, 14:1, 15:1, 16:1, 17:1, 18:1}


; --- Character Memory Layout ---
global CharactersBase := 0
global HeroPtr := 0
global CharacterStride := 0
global CharactersPointerAddress := 0x09F69618
global HeroPointerAddress := 0x09F6961C

; --- Hunt Module ---
global CurrentTarget := -1
global CurrentTargetMonsterIndex := -1
global TargetClaimHandles := []
global TargetClaimKey := ""
global TargetClaimX := -1
global TargetClaimY := -1
global PeerReservedMonsterSeen := false
global TargetClaimCellSize := 12
global WorkerRosterSlot := 1
global WorkerRosterCount := 1
global WorkerRosterRefreshTick := 0
global WorkerRosterScope := ""
global TargetEventCountAtSelection := -1
global HuntWaitUntil := 0
global LastHuntClick := 0
global LootUntil := 0
global NoMonsterSince := 0
global LastPatrolMove := 0
global PatrolStep := 0
global KilledOnCurrentEvent := 0
global LastTravelAttempt := 0
global LootActive := false
global LootSpawnGraceUntil := 0
global LootLastSeen := 0
global LastGroundItemScan := 0
global GroundItemsPresent := false
global LastApproachClick := 0
global PatrolLastHeroX := -1
global PatrolLastHeroY := -1
global PatrolStuckCount := 0
global ItemsBase := 0x0B9029D4
global ItemStride := 0x2D8

; --- Terrain / Pathfinding ---
global TerrainWallAddress := 0x0BCD4DD8
global NavPath := []
global NavPathPos := 1
global NavTargetX := -1
global NavTargetY := -1
global LastNavCompute := 0

; --- Builtin Helper ---
global BuiltinHelperBase := 0x00C115E8
global BuiltinHelperStartAddress := 0x0041ED00
global BuiltinHelperStopAddress := 0x0041EEE0
global BuiltinDirectMoveAddress := 0x0041E890
global RemoteCallBusy := false
global RemotePendingThread := 0
global RemotePendingBuffer := 0
global HelperTransitionBusy := false
global HelperCleanupFault := false
global BuiltinAttackRange := 10
; Get adjacent to the selected monster before handing combat to MU Helper.
; Dynamic collision can prevent occupying the exact same/adjacent tile. Live
; tests reached distance 1 on one target but hard-stopped at distance 2 on
; another, so 2 is the closest reliable server-valid handoff distance.
global BuiltinApproachDistance := 2
global BuiltinPostKillUntil := 0
global BuiltinLootHardDeadline := 0
global BuiltinLootLastSeen := 0
global LastBuiltinMove := 0
global BuiltinMode := ""
global BuiltinConfigSnapshotReady := false
global BuiltinWasActiveAtStart := false
global BuiltinOriginalRange := 0
global BuiltinOriginalRegroup := 0
global BuiltinOriginalRegroupRange := 0
global BuiltinOriginalPickupRange := 0
global BuiltinOriginalPickupAll := 0
global BuiltinOriginalPickupSelected := 0
global NativeLastHeroX := -1
global NativeLastHeroY := -1
global NativeLastProgressTick := 0
global NativeFallbackUntil := 0
global NativeBestDistance := 0x7FFFFFFF
global NativeLastCloserTick := 0

; --- Event System ---
global OrdinaryEventBase := 0
; Mua He and Tho Ngoc have the highest priority. Rows 1 (Dai Chien Loren),
; 3 (Tu Than Xuong So), 4 (Rong Do) and 8 (Boss Class) are always excluded.
global PriorityEventRows := [6, 5, 2, 7, 10, 11, 12, 9, 13, 14, 15, 16, 17, 18]
global CompletedEventRows := {}
global CurrentEventRow := 0
global CurrentEventMap := -1
global CurrentEventMonsterCount := 0
global CurrentAllowedMonsterCount := -1
global EventInitialAllowedCount := -1
global TravelBusy := false
; Despite the legacy variable name, keys are raw server MonsterIndex values.
; Live verification on this build: Character + 0x7C holds MonsterIndex 719
; for Ma Thu while Object.Type at +0x3BC is 660. Filtering Object.Type loses
; custom bosses, so every event filter below deliberately uses +0x7C.
global AllowedEventTypes := {}
global AllowedEventTypesRow := 0
global AllowedEventTypesRefreshTick := 0
global EventArrivedTick := 0
; Single-boss instances stream the boss beside the H arrival point. Wait only
; long enough for the client array to settle; never patrol those maps.
global SingleBossScanGraceMs := 3000
; Hon Thach (row 17) respawns 2-3 delayed waves near the previous boss, not on
; the exact same tile. Keep MU Helper attacking/picking nearby for a quiet
; 15-second window after every observed boss kill, then resume full-map patrol.
global HonThachWaveWaitUntil := 0
global HonThachHelperHoldMs := 15000
global HonThachWaveKills := 0
global HuntGeneration := 0
global HuntSessionActive := false
global EventPanelPointerAddress := 0x00C99368
global ScriptCleanupRunning := false
global TimerPeriodActive := false

; --- Patrol System (full map scanning) ---
global PatrolWaypoints := []
global PatrolWaypointIndex := 0
global PatrolExploredSectors := {}
global PatrolSectorSize := 20
global LastPatrolWaypointMove := 0
global PatrolWaypointStartTick := 0
global PatrolNavPath := []
global PatrolNavPathPos := 1
global PatrolNavTargetX := -1
global PatrolNavTargetY := -1
global PatrolCompletedCycles := 0

; --- Combo Module ---
global ComboRunning := false
global ComboSelectedClass := "DW"
global ComboGeneration := 0
global ComboLoopActive := false
global ComboMacroCache := {}
global ComboMacroSources := {}
; Time spent pulsing Engine's per-process key edge is deducted from the delay
; that follows that action. This keeps the source .mcr wall timing as close as
; possible while retaining the live-verified three-frame background pulse.
global ComboPendingDispatchMs := 0
global ComboCycleAbort := false
global ComboPulseRepeats := 3
global ComboPulseSleepMs := 3
global ComboHiResTimerHandle := 0
; Jitbit MAX uses 1.3^(1-5)=0.350127 of every >=30 ms delay, i.e. 285.61%.
; The custom control can go beyond that when a class needs tighter chaining.
global ComboPlaybackSpeedPercent := 286
global ComboDWNextBuffTick := 0

; --- Persistent Settings (HKCU; keeps the packaged folder to one EXE) ---
global SettingsRegKey := "Software\MU-PKZ\AutoHunt"
global CurrentMacroProfileRevision := 2
global SavedHuntModuleEnabled := 1
global SavedComboModuleEnabled := 0
global SavedActivePatrol := 1
global SavedLootAfterKill := 1
global SavedAutoEventTravel := 1
global SavedHuntSingleBoss := 1
global SavedHuntMultiBoss := 1
global SavedMapEmptySeconds := 15
global SavedComboClass := "DW"
global SavedComboSpeedPercent := 286
global UiScalePercent := 100

; --- Live / Free UI Scaling ---
global MainGuiHwnd := 0
global FreeScaleReady := false
global FreeScaleControls := []
global FreeScaleStyles := {}
global FreeScaleFonts := {}
global FreeScaleBaseClientW := 0
global FreeScaleBaseClientH := 0
global FreeScaleNonClientW := 0
global FreeScaleNonClientH := 0
global FreeScaleAppliedFontPercent := 0
global FreeScaleInternalUpdate := false
global FreeScaleRequestedPercent := 0
global FreeScaleMinPercent := 50
global FreeScaleMaxPercent := 200
global FreeScaleAbsoluteMaxPercent := 200

; --- SafeZone Escape ---
global SafeZoneEscapeActive := false
global SafeZoneEscapeTarget := []
global SafeZoneEscapePath := []
global SafeZoneEscapePathPos := 1
global SafeZoneTargetSetTick := 0
global LastSafeZoneEscape := 0
global AtlansEscapeStage := 0
global LastAtlansWarp := 0
global AtlansStage3Since := 0
global AtlansWarpFailures := 0
global AtlansDwellSince := 0
; Kho Bau Hoang Toc / Long Vuong alternate Atlans2 <-> Atlans3 after five
; minutes. Expiry only arms the switch; the nearby scanner must then remain
; clear for a short confirmation window so combat/loot is never interrupted.
global AtlansRotationIntervalMs := 300000
global AtlansClearConfirmMs := 3000
global AtlansTransitTargetStage := 0
global AtlansTransitStartedTick := 0
global LastAtlansTransitMove := 0
global AtlansTransitTimeoutMs := 120000
global AtlansTransitLastHeroX := -1
global AtlansTransitLastHeroY := -1
global AtlansTransitLastProgressTick := 0
global AtlansTransitStallCount := 0
global AtlansTransitStallMs := 15000
global AtlansTransitMaxStalls := 3

; --- Per-process background input (verified on this Engine build) ---
global InternalKeyStateAddress := 0x00CDF900
global InternalMouseXAddress := 0x0BE82C38
global InternalMouseYAddress := 0x0BE82C3C
global MoveMenuPointerAddress := 0x00CDFD84

; ========== ADMIN CHECK ==========
SkipAdminForTest := false
SyntaxCheckOnly := false
MacroSelfTestOutput := ""
for _, arg in A_Args
{
    if (arg = "--no-admin-test")
        SkipAdminForTest := true
    else if (arg = "--syntax-check")
        SyntaxCheckOnly := true
    else if (RegExMatch(arg, "i)^--macro-self-test=(.+)$", macroTestMatch))
        MacroSelfTestOutput := macroTestMatch1
    else if (RegExMatch(arg, "i)^--worker-pid=(\d+)$", workerMatch))
    {
        WorkerMode := true
        ManagerMode := false
        WorkerTargetPid := workerMatch1 + 0
    }
    else if (arg = "--worker-autostart")
        WorkerAutoStart := true
    else if (arg = "--combo-autostart")
        WorkerComboAutoStart := true
    else if (RegExMatch(arg, "i)^--combo-class-id=([1-9])$", comboClassMatch))
        WorkerComboClassIdArg := comboClassMatch1 + 0
    else if (RegExMatch(arg, "i)^--single=([01])$", singleMatch))
        WorkerSingleBossArg := singleMatch1 + 0
    else if (RegExMatch(arg, "i)^--multi=([01])$", multiMatch))
        WorkerMultiBossArg := multiMatch1 + 0
    else if (RegExMatch(arg, "i)^--travel=([01])$", travelMatch))
        WorkerAutoTravelArg := travelMatch1 + 0
}
if (SyntaxCheckOnly)
    ExitApp
if (MacroSelfTestOutput != "")
{
    macroTestOk := RunComboMacroSelfTest(macroTestReport)
    FileDelete, %MacroSelfTestOutput%
    FileAppend, %macroTestReport%, %MacroSelfTestOutput%, UTF-8
    macroTestExitCode := macroTestOk ? 0 : 2
    ExitApp, %macroTestExitCode%
}
if (!A_IsAdmin && !SkipAdminForTest)
{
    if (A_IsCompiled)
        Run, *RunAs "%A_ScriptFullPath%"
    else
        Run, *RunAs "%A_AhkPath%" "%A_ScriptFullPath%"
    ExitApp
}
DllCall("Winmm\timeBeginPeriod", "UInt", 1)
TimerPeriodActive := true
OnExit, HandleScriptExit
DetectHiddenWindows, On
CoordMode, Mouse, Client
CoordMode, Pixel, Client
LoadPersistentSettings()
OnMessage(SettingsReloadMessage, "HandleWorkerSettingsReload")
OnMessage(WorkerCommandMessage, "HandleWorkerCommandMessage")

if (WorkerMode)
{
    Hotkey, ^F1, Off
    Hotkey, ^F2, Off
    Hotkey, F7, Off
    if (WorkerSingleBossArg >= 0)
        SavedHuntSingleBoss := WorkerSingleBossArg
    if (WorkerMultiBossArg >= 0)
        SavedHuntMultiBoss := WorkerMultiBossArg
    if (WorkerAutoTravelArg >= 0)
        SavedAutoEventTravel := WorkerAutoTravelArg
    if (WorkerComboClassIdArg)
    {
        workerComboClass := ComboIdToClass(WorkerComboClassIdArg)
        if (workerComboClass != "")
        {
            SavedComboClass := workerComboClass
            SavedComboSpeedPercent := ReadComboSpeedSetting(workerComboClass)
            ComboPlaybackSpeedPercent := SavedComboSpeedPercent
        }
    }
    if (!AcquireInstanceMutex("Local\MU-PKZ.AutoHunt.Worker." . WorkerTargetPid))
        ExitApp
}
else
{
    if (!AcquireInstanceMutex("Local\MU-PKZ.AutoHunt.Manager"))
    {
        MsgBox, 48, MU-PKZ Auto Hunt, Tool quan ly dang chay.
        ExitApp
    }
    Gosub, InitializeManagerGui
    return
}

; ========== GUI ==========
; +DPIScale honors Windows display scaling. +Resize plus the live layout engine
; lets the user drag any edge/corner continuously without restarting the tool.
Gui, +HwndMainGuiHwnd +DPIScale +Resize +AlwaysOnTop -MaximizeBox
marginX := ScaleUiValue(20), marginY := ScaleUiValue(12)
Gui, Margin, %marginX%, %marginY%
SetScaledGuiFont(12, "Bold")
Gui, Add, Text, % ScaleGuiOptions("xm ym"), MU-PKZ - AUTO HUNT / COMBO
SetScaledGuiFont(9, "Norm")
Gui, Add, Text, % ScaleGuiOptions("xm y+10 w380 vProcessText"), Engine.exe: chua gan
Gui, Add, Button, % ScaleGuiOptions("x+8 yp-3 w75 h26 gAttachGame"), Gan lai
Gui, Add, Text, % ScaleGuiOptions("xm y+9"), Scale (keo goc):
Gui, Add, Slider, % ScaleGuiOptions("x+8 yp-4 w270 h24 vUiScaleSlider gChangeUiScale Range50-200 ToolTip"), 100
Gui, Add, Text, % ScaleGuiOptions("x+7 yp+4 w50 vUiScaleValueText"), 100`%
Gui, Add, CheckBox, % ScaleGuiOptions("xm+12 y+6 vIsClassDL gToggleClassDL"), Nhân vật Dark Lord (DL)
SetScaledGuiFont(10, "Bold")


; --- Module Checkboxes ---
SetScaledGuiFont(10, "Bold")
Gui, Add, CheckBox, % ScaleGuiOptions("xm y+12 vHuntModuleEnabled gToggleHuntModule Checked"), Module San Quai (Ctrl+F1)
Gui, Add, CheckBox, % ScaleGuiOptions("xm y+6 vComboModuleEnabled gToggleComboModule"), Module Combo (Ctrl+F2)
SetScaledGuiFont(9, "Norm")

; --- Hunt Module GroupBox ---
Gui, Add, GroupBox, % ScaleGuiOptions("xm y+14 w460 h250"), MODULE SAN QUAI
Gui, Add, Button, % ScaleGuiOptions("xp+12 yp+22 w100 h28 gStartHunt vStartHuntButton"), BAT DAU
Gui, Add, Button, % ScaleGuiOptions("x+8 yp w80 h28 gStopHunt vStopHuntButton Disabled"), DUNG
Gui, Add, Text, % ScaleGuiOptions("x+12 yp+7"), Ctrl+F1: bat/dung
Gui, Add, Text, % ScaleGuiOptions("xm+12 y+10 w430"), Loi san: Auto Train Helper (khong click chuot tan cong)
Gui, Add, CheckBox, % ScaleGuiOptions("xm+12 y+6 vActivePatrol gSaveSettings Checked"), Tuan tra voi su kien nhieu quai
Gui, Add, CheckBox, % ScaleGuiOptions("xm+12 y+6 vLootAfterKill gSaveSettings Checked"), MU Helper tu nhat do
Gui, Add, CheckBox, % ScaleGuiOptions("xm+12 y+8 vAutoEventTravel gSaveSettings Checked"), Tu di chuyen theo uu tien su kien
Gui, Add, CheckBox, % ScaleGuiOptions("xm+12 y+6 vHuntSingleBoss gSaveSettings Checked"), San boss don (Viem Dia/Chien Than/Ma Than/Ta Than)
Gui, Add, CheckBox, % ScaleGuiOptions("xm+12 y+6 vHuntMultiBoss gSaveSettings Checked"), San su kien nhieu quai/boss
Gui, Add, Text, % ScaleGuiOptions("xm+12 y+8"), Khong con quai trong:
Gui, Add, Edit, % ScaleGuiOptions("x+7 yp-3 w45 vMapEmptySeconds gSaveSettings Number Limit3"), 15
Gui, Add, Text, % ScaleGuiOptions("x+4 yp+3"), giay
Gui, Add, Text, % ScaleGuiOptions("xm+12 y+8 w435 vHuntStatusText c666666"), Chua bat - bam BAT DAU hoac Ctrl+F1

; --- Combo Module GroupBox ---
Gui, Add, GroupBox, % ScaleGuiOptions("xm y+14 w460 h75"), MODULE COMBO
Gui, Add, Text, % ScaleGuiOptions("xp+12 yp+22"), Class:
Gui, Add, DropDownList, % ScaleGuiOptions("x+8 yp-3 w145 vComboClassChoice gSaveSettings Choose1"), DW|DK|DK V1|ELF|RF|SUM|DL|MG|AUTO HP
Gui, Add, Text, % ScaleGuiOptions("x+15 yp+3"), Ctrl+F2: Bat/Tat combo
Gui, Add, Text, % ScaleGuiOptions("xm+12 y+10 w435 vComboStatusText c666666"), Combo: TAT - chon class va bam Ctrl+F2

; --- Event & Status ---
Gui, Add, Text, % ScaleGuiOptions("xm y+14 w460 h34 vEventStatusText c7A3E00"), Su kien thuong: dang doc bang...
Gui, Add, Text, % ScaleGuiOptions("xm y+10 w460 h42 vStatusText c0066CC"), Mo game va vao nhan vat, sau do bam Gan lai.
Gui, Add, CheckBox, % ScaleGuiOptions("xm y+0 w0 h0 vHuntEnabled Hidden"), hunt

; --- Khu vực nạp cấu hình chuẩn ---
ApplyPersistentSettings()
GuiControl,, IsClassDL, %IsClassDL%
RegRead, SavedIsClassDL, HKCU, %SettingsRegKey%, SavedIsClassDL
if ErrorLevel
    SavedIsClassDL := 1 
GuiControl,, IsClassDL, %SavedIsClassDL%
IsClassDL := SavedIsClassDL

; --- CHÈN LỆNH GỌI HÀM VÀO ĐÂY KHI KHỞI ĐỘNG TOOL ---
CapNhatMangPriorityEvent()
; ----------------------------------------------------

GuiControl, ChooseString, ManagerComboClassChoice, %SavedComboClass%

Gui, Show, Hide, MU-PKZ Worker - GamePID %WorkerTargetPid%

ApplyPersistentSettings()

; --- CHÈN LỆNH NÀY VÀO ĐỂ SỬA LỖI ACC PHỤ ĐỨNG IM ---
CapNhatMangPriorityEvent()
; ---------------------------------------------------

Gui, Show, Hide, MU-PKZ Worker - GamePID %WorkerTargetPid%

SetTimer, RefreshEngine, 250
SetTimer, HuntLoop, 100
SetTimer, RefreshOrdinaryEvents, 1000
SetTimer, EventRouteLoop, 1000
SetTimer, ComboLoop, -1

; --- THAY THẾ DÒNG GOSUB BẰNG LỆNH GÁN TRỰC TIẾP TẠI ĐÂY ---
WinGet, GameHwnd, ID, ahk_pid %WorkerTargetPid%
if (GameHwnd) {
    TargetGameWindowHwnd := GameHwnd
}
; -----------------------------------------------------------

WorkerHuntDesired := WorkerAutoStart ? true : false

WorkerHuntStarting := WorkerHuntDesired
UpdateWorkerWindowTitle()
if (WorkerAutoStart)
    SetTimer, WorkerStartHunt, -700
if (WorkerComboAutoStart)
    SetTimer, WorkerStartCombo, -1000
return

; ========== GUI EVENT HANDLERS ==========
InitializeManagerGui:
    Gui, +HwndMainGuiHwnd +DPIScale +Resize +AlwaysOnTop -MaximizeBox
    marginX := ScaleUiValue(20), marginY := ScaleUiValue(12)
    Gui, Margin, %marginX%, %marginY%
    SetScaledGuiFont(12, "Bold")
    Gui, Add, Text, % ScaleGuiOptions("xm ym"), MU-PKZ - MULTI ACCOUNT AUTO HUNT
    SetScaledGuiFont(9, "Norm")
    Gui, Add, Text, % ScaleGuiOptions("xm y+8 w600"), Chạy nền theo từng Engine.exe - Không chiếm chuột/Bàn phím Windows
    Gui, Add, Tab3, % ScaleGuiOptions("x20 y62 w650 h485 vManagerTabs"), SAN BOSS|AUTO COMBO
    Gui, Tab, 1
    Gui, Add, Button, % ScaleGuiOptions("x38 y96 w120 h28 gManagerRefreshAccounts"), QUET TAI KHOAN
    Gui, Add, Text, % ScaleGuiOptions("x172 y102 w360 vManagerSummaryText c0066CC"), Dang tim cua so game...
    Gui, Add, Text, % ScaleGuiOptions("x38 y128 w610 h20 c666666"), Tick = Bật Auto ngay | Bỏ tick = Dừng Auto cho nhân vật đó
    Gui, Add, ListView, % ScaleGuiOptions("x38 y150 w614 h185 vManagerAccounts gManagerAccountToggled Checked Grid AltSubmit"), Chon|Nhan vat|PID|Map|Trang thai

    ; --- KHU VUC BO LOC 18 DANH MUC BOSS ---
    Gui, Add, GroupBox, % ScaleGuiOptions("x38 y345 w614 h115"), MENU BOSS MỜI BẠN ORDER! XIN VUI LÒNG PHỤC VỤ QUÝ KHÁCH!

    ; Cot 1: Dong 1 den 6 (Bat dau tu x55 y365)
    Loop, 6 {
        row := A_Index
        name := BossNames[row]
        isChecked := BossFilters[row] ? "Checked" : ""
        posY := 365 + (A_Index - 1) * 15
        Gui, Add, CheckBox, % ScaleGuiOptions("x55 y" . posY . " vFilterBoss" . row . " gOnBossFilterChanged " . isChecked), %name%
    }

    ; Cot 2: Dong 7 den 12 (Bat dau tu x255 y365)
    Loop, 6 {
        row := A_Index + 6
        name := BossNames[row]
        isChecked := BossFilters[row] ? "Checked" : ""
        posY := 365 + (A_Index - 1) * 15
        Gui, Add, CheckBox, % ScaleGuiOptions("x255 y" . posY . " vFilterBoss" . row . " gOnBossFilterChanged " . isChecked), %name%
    }

    ; Cot 3: Dong 13 den 18 (Bat dau tu x455 y365)
    Loop, 6 {
        row := A_Index + 12
        name := BossNames[row]
        isChecked := BossFilters[row] ? "Checked" : ""
        posY := 365 + (A_Index - 1) * 15
        Gui, Add, CheckBox, % ScaleGuiOptions("x455 y" . posY . " vFilterBoss" . row . " gOnBossFilterChanged " . isChecked), %name%
    }

; === KHU VỰC NÚT BẤM VÀ TEXT TRẠNG THÁI CHUẨN ===
Gui, Add, CheckBox, % ScaleGuiOptions("x38 y465 vIsClassDL gToggleClassDL Checked"), Tài khoản đang chạy là Class DL (Chúa Tể)
Gui, Add, Button, % ScaleGuiOptions("x38 y495 w135 h32 gManagerStartSelected"), CHỌN TẤT CẢ
Gui, Add, Button, % ScaleGuiOptions("x185 y495 w135 h32 gManagerStopSelected"), BỎ CHỌN TẤT CẢ
Gui, Add, Text, % ScaleGuiOptions("x335 y500 w295"), Ctrl+ F1: Tạm Dừng/ Khôi Phục Nhóm Chọn
Gui, Add, Text, % ScaleGuiOptions("x38 y525 w614 h28 vManagerStatusText c666666"), Chọn Nhân Vật Để Auto Ngay

    Gui, Tab, 2
    Gui, Add, Text, % ScaleGuiOptions("x38 y100 w610 h38 c0066CC"), Chi duoc chon 1 nhan vat. Macro combo chay nen tren dung Engine da chon.
    Gui, Add, ListView, % ScaleGuiOptions("x38 y145 w614 h220 vManagerComboAccounts gManagerComboAccountToggled Checked Grid AltSubmit"), Chon|Nhan vat|PID|Map|Trang thai
    Gui, Add, Text, % ScaleGuiOptions("x38 y390 w55"), Class:
    Gui, Add, DropDownList, % ScaleGuiOptions("x95 y386 w165 vManagerComboClassChoice gManagerComboClassChanged Choose1"), DW|DK|DK V1|ELF|RF|SUM|DL|MG|AUTO HP
    Gui, Add, Button, % ScaleGuiOptions("x280 y383 w165 h34 gManagerToggleCombo vManagerComboToggleButton"), BAT / DUNG COMBO
    Gui, Add, Text, % ScaleGuiOptions("x462 y391 w170"), Ctrl+F2: bat/dung
    Gui, Add, Text, % ScaleGuiOptions("x38 y429 w55"), Speed:
    Gui, Add, Slider, % ScaleGuiOptions("x95 y420 w280 h28 vManagerComboSpeedSlider gManagerComboSpeedChanged Range50-600 TickInterval50 ToolTip"), 286
    Gui, Add, Text, % ScaleGuiOptions("x385 y428 w72 vManagerComboSpeedText c0066CC"), 286`%
    Gui, Add, Text, % ScaleGuiOptions("x462 y428 w170 c666666"), Jitbit MAX ~ 286`%
    Gui, Add, Text, % ScaleGuiOptions("x462 y448 w170 c666666"), Replay: vo han den khi dung
    Gui, Add, Text, % ScaleGuiOptions("x38 y472 w614 h54 vManagerComboStatusText c666666"), Chon 1 nhan vat, chon class, sau do bam Ctrl+F2.
    Gui, Tab
    Gui, Show,, MU-PKZ - Multi Account Auto Hunt
    InitializeFreeGuiScaling()
    GuiControl,, ManagerHuntSingleBoss, %SavedHuntSingleBoss%
    GuiControl,, ManagerHuntMultiBoss, %SavedHuntMultiBoss%
    GuiControl,, ManagerAutoTravel, %SavedAutoEventTravel%
    GuiControl, ChooseString, ManagerComboClassChoice, %SavedComboClass%
    ManagerComboClass := SavedComboClass
    ManagerComboSpeedPercent := ReadComboSpeedSetting(ManagerComboClass)
    GuiControl,, ManagerComboSpeedSlider, %ManagerComboSpeedPercent%
    GuiControl,, ManagerComboSpeedText, % ManagerComboSpeedPercent . "%"
    RefreshManagerAccounts()
    SetTimer, ManagerRefreshTimer, 2000
    SetTimer, ManagerReconcileTimer, 500
return

ManagerRefreshAccounts:
    RefreshManagerAccounts()
return

ManagerRefreshTimer:
    RefreshManagerAccounts()
return

ManagerReconcileTimer:
    ReconcileManagerWorkers()
return

ManagerAccountToggled:
    flags := ErrorLevel
    changedRow := A_EventInfo
    eventKind := A_GuiEvent
    HandleManagerHuntToggle(eventKind, flags, changedRow)
return

ManagerComboAccountToggled:
    flags := ErrorLevel
    changedRow := A_EventInfo
    eventKind := A_GuiEvent
    HandleManagerComboToggle(eventKind, flags, changedRow)
return

ManagerStartSelected:
    StartSelectedManagerWorkers()
return

ManagerStopSelected:
    StopSelectedManagerWorkers()
return

ManagerToggleCombo:
    ToggleManagerCombo()
return

ManagerComboClassChanged:
    HandleManagerComboClassChanged()
return

ManagerComboSpeedChanged:
    HandleManagerComboSpeedChanged()
return

ManagerOptionsChanged:
    GuiControlGet, managerSingle,, ManagerHuntSingleBoss
    GuiControlGet, managerMulti,, ManagerHuntMultiBoss
    GuiControlGet, managerTravel,, ManagerAutoTravel
    SaveManagerSettings(managerSingle, managerMulti, managerTravel)
    NotifyManagerWorkersSettingsChanged()
return

WorkerStartHunt:
    if (!WorkerMode)
        return
    if (!WorkerHuntDesired)
    {
        SetTimer, WorkerStartHunt, Off
        WorkerStartAttempts := 0
        WorkerHuntStarting := false
        WorkerHuntFailed := false
        UpdateWorkerWindowTitle()
        return
    }
    WorkerHuntStarting := true
    WorkerHuntFailed := false
    Process, Exist, %WorkerTargetPid%
    if (ErrorLevel != WorkerTargetPid)
        ExitApp
    if (!hProcess)
        AttachToEngine(false)
    if (hProcess)
        Gosub, StartHunt
    GuiControlGet, workerHuntOn,, HuntEnabled
    if (workerHuntOn)
    {
        WorkerStartAttempts := 0
        WorkerHuntStarting := false
        UpdateWorkerWindowTitle()
        return
    }
    WorkerStartAttempts += 1
    if (WorkerStartAttempts < WorkerMaxStartAttempts)
    {
        UpdateWorkerWindowTitle()
        SetTimer, WorkerStartHunt, -1000
        return
    }
    WorkerHuntStarting := false
    WorkerHuntFailed := true
    UpdateWorkerWindowTitle()
    SetStatus("Khong the khoi dong san nen sau " . WorkerMaxStartAttempts . " lan thu.", "CC0000")
    SetTimer, WorkerStartFailedExit, -2500
return

WorkerStartFailedExit:
    if (WorkerMode && WorkerHuntDesired && WorkerHuntFailed)
        ExitApp
return

WorkerStartCombo:
    if (WorkerMode)
        StartWorkerCombo(WorkerComboClassIdArg ? WorkerComboClassIdArg : ComboClassToId(SavedComboClass))
return

ProcessWorkerCommand:
    ProcessPendingWorkerCommand()
return

WorkerReleaseComboKeys:
    ReleaseAllComboKeys()
return

WorkerRetryComboStart:
    RetryPendingWorkerComboStart()
return

ToggleClassDL:
Gui, Submit, NoHide

; 1. Ghi cấu hình ô tích Class DL vào Registry
RegWrite, REG_DWORD, HKCU, %SettingsRegKey%, SavedIsClassDL, %IsClassDL%

; 2. SỬA LỖI TRIỆT ĐỂ: Tự động gom trạng thái 18 ô Checkbox Boss thành chuỗi cấu hình dạng "1,2,5..."
if (ManagerMode) {
    NewEventsAllowedStr := ""
    ; Vòng lặp quét qua 18 ô Checkbox dựa trên biến mảng BossFilters sẵn có trong file gốc của bạn
    Loop, 18 {
        if (BossFilters[A_Index]) {
            if (NewEventsAllowedStr == "")
                NewEventsAllowedStr := A_Index
            else
                NewEventsAllowedStr := NewEventsAllowedStr . "," . A_Index
        }
    }
    ; Gán lại cho biến hệ thống và ghi thẳng xuống Registry mà không cần gọi nhãn phụ nào cả
    SavedEventsAllowed := NewEventsAllowedStr
    RegWrite, REG_SZ, HKCU, %SettingsRegKey%, SavedEventsAllowed, %SavedEventsAllowed%
}

; 3. Nạp lại mảng danh sách Boss di chuyển cho tiến trình hiện tại
CapNhatMangPriorityEvent()

; 4. Phát tín hiệu thông báo cho toàn bộ các tài khoản phụ (Worker) tải lại đường đi mới
if (ManagerMode) {
    NotifyManagerWorkersSettingsChanged()
}
return


; -----------------------------------------------------



SaveSettings:
    SavePersistentSettings()
return

ChangeUiScale:
    if (!FreeScaleReady || FreeScaleInternalUpdate)
        return
    GuiControlGet, requestedScale,, UiScaleSlider
    FreeScaleRequestedPercent := NormalizeUiScale(requestedScale, UiScalePercent)
    ; Coalesce rapid thumb-track notifications so the latest position always
    ; wins and old WM_SIZE messages cannot pull the slider backwards.
    SetTimer, ApplyRequestedFreeScale, -30
return

ApplyRequestedFreeScale:
    requestedScale := FreeScaleRequestedPercent
    FreeScaleRequestedPercent := 0
    if (requestedScale)
        ResizeMainGuiToScale(requestedScale)
return

SaveFreeScaleSetting:
    if (FreeScaleReady)
        SavePersistentSettings()
return

StartHunt:
    GuiControlGet, huntMod,, HuntModuleEnabled
    if (!huntMod)
    {
        GuiControl,, HuntModuleEnabled, 1
        Gosub, ToggleHuntModule
    }
    GuiControlGet, huntOn,, HuntEnabled
    if (huntOn)
        return
    if (RemoteCallBusy || BuiltinMode != "" || HelperCleanupFault)
    {
        SetHuntStatus("Helper cu chua cleanup xong; bam Gan lai roi moi BAT DAU.", "CC0000")
        return
    }
    GuiControl,, HuntEnabled, 1
    ResetHuntState()
	global HasSummonedCurrentBoss
HasSummonedCurrentBoss := 0

    Gosub, ToggleHunt
return

StopHunt:
    Critical, On
    HuntSessionActive := false
    HuntGeneration += 1
    GuiControl,, HuntEnabled, 0
    Critical, Off
    Gosub, ToggleHunt
return

ResetHuntState()
{

    global
    ReleaseTargetClaim()
    HuntGeneration += 1
    CompletedEventRows := {}
    CurrentEventRow := 0
    CurrentEventMap := -1
    CurrentEventMonsterCount := 0
    CurrentAllowedMonsterCount := -1
    EventInitialAllowedCount := -1
    CurrentTargetMonsterIndex := -1
    TargetEventCountAtSelection := -1
    NoMonsterSince := A_TickCount
    LastPatrolMove := 0
    PatrolStep := 0
    KilledOnCurrentEvent := 0
    LootActive := false
    LootSpawnGraceUntil := 0
    LootLastSeen := 0
    LastGroundItemScan := 0
    GroundItemsPresent := false
    LastApproachClick := 0
    PatrolLastHeroX := -1
    PatrolLastHeroY := -1
    PatrolStuckCount := 0
    BuiltinPostKillUntil := 0
    BuiltinLootHardDeadline := 0
    BuiltinLootLastSeen := 0
    LastBuiltinMove := 0
    NativeLastHeroX := -1
    NativeLastHeroY := -1
    NativeLastProgressTick := A_TickCount
    NativeFallbackUntil := 0
    NativeBestDistance := 0x7FFFFFFF
    NativeLastCloserTick := A_TickCount
    NavPath := []
    NavPathPos := 1
    NavTargetX := -1
    NavTargetY := -1
    LastNavCompute := 0
    PatrolWaypoints := []
    PatrolWaypointIndex := 0
    PatrolExploredSectors := {}
    LastPatrolWaypointMove := 0
    PatrolWaypointStartTick := 0
    PatrolNavPath := []
    PatrolNavPathPos := 1
    PatrolNavTargetX := -1
    PatrolNavTargetY := -1
    PatrolCompletedCycles := 0
    SafeZoneEscapeActive := false
    SafeZoneEscapeTarget := []
    SafeZoneEscapePath := []
    SafeZoneEscapePathPos := 1
    SafeZoneTargetSetTick := 0
    AllowedEventTypes := {}
    AllowedEventTypesRow := 0
    AllowedEventTypesRefreshTick := 0
    EventArrivedTick := 0
    HonThachWaveWaitUntil := 0
    HonThachWaveKills := 0
    AtlansEscapeStage := 0
    LastAtlansWarp := 0
    AtlansStage3Since := 0
    AtlansWarpFailures := 0
    AtlansDwellSince := 0
    ResetAtlansConnectedTransit()
}

ToggleHunt:
    Gui, Submit, NoHide
    GuiControlGet, huntOn,, HuntEnabled
    if (huntOn)
    {
        if (!EnsureAttached() || !ResolveCharacterMemory())
        {
            GuiControl,, HuntEnabled, 0
            GuiControl, Enable, StartHuntButton
            GuiControl, Disable, StopHuntButton
            SetHuntStatus("Khong doc duoc danh sach nhan vat/quai.", "CC0000")
            return
        }
        ; EnsureAttached may create a fresh process handle through DetachEngine,
        ; which intentionally clears stale hunt state. Reassert this start.
        GuiControl,, HuntEnabled, 1
        if (RemoteCallBusy || BuiltinMode = "fault" || HelperCleanupFault)
        {
            GuiControl,, HuntEnabled, 0
            GuiControl, Disable, StartHuntButton
            GuiControl, Disable, StopHuntButton
            SetHuntStatus("Remote/helper cu chua cleanup xong; bam Gan lai sau vai giay.", "CC0000")
            return
        }
        ; Native patrol, combat and pickup all own/restore Helper state for the
        ; duration of a hunt. There is no synthetic combat fallback.
        if (!ReadBuiltinHelperActive(helperWasActive))
        {
            GuiControl,, HuntEnabled, 0
            GuiControl, Enable, StartHuntButton
            GuiControl, Disable, StopHuntButton
            SetHuntStatus("Khong doc duoc trang thai MU Helper.", "CC0000")
            return
        }
        BuiltinWasActiveAtStart := helperWasActive
        if (!SnapshotBuiltinHelperConfig())
        {
            GuiControl,, HuntEnabled, 0
            GuiControl, Enable, StartHuntButton
            GuiControl, Disable, StopHuntButton
            SetHuntStatus("Khong doc duoc cau hinh Auto Train Helper.", "CC0000")
            return
        }
        CurrentTarget := -1
        CurrentTargetMonsterIndex := -1
        HuntWaitUntil := 0
        LootUntil := 0
        LootActive := false
        LastHuntClick := 0
        BuiltinPostKillUntil := 0
        BuiltinLootHardDeadline := 0
        BuiltinLootLastSeen := 0
        BuiltinMode := ""
        HuntSessionActive := true
        GuiControl, Disable, StartHuntButton
        GuiControl, Enable, StopHuntButton

        SetHuntStatus("Dang quet monster toan map...", "008000")
        GuiControlGet, autoTravel,, AutoEventTravel
        if (autoTravel)
            EnsureOrdinaryEventTable(HuntGeneration)

    }
    else
    {
        HuntSessionActive := false
        ReleaseTargetClaim()
        CurrentTarget := -1
        CurrentTargetMonsterIndex := -1
        HuntWaitUntil := 0
        LootUntil := 0
        LootActive := false
        BuiltinPostKillUntil := 0
        BuiltinLootHardDeadline := 0
        BuiltinLootLastSeen := 0
        cleanupOk := true
        if (hProcess)
            cleanupOk := PrepareNativeMovement()
        if (hProcess && cleanupOk && BuiltinWasActiveAtStart)
        {
            if (!ReadBuiltinHelperActive(helperActive) || (!helperActive && !StartBuiltinHelper()))
                cleanupOk := false
        }
        if (cleanupOk)
        {
            BuiltinWasActiveAtStart := false
            BuiltinMode := ""
            BuiltinConfigSnapshotReady := false
            HelperCleanupFault := false
            GuiControl, Enable, StartHuntButton
        }
        else
        {
            if (BuiltinMode = "")
                BuiltinMode := "fault"
            HelperCleanupFault := true
            GuiControl, Disable, StartHuntButton
        }
        GuiControl, Disable, StopHuntButton
        SetHuntStatus(cleanupOk ? "Da tat module san quai."
            : "Da dung san quai, nhung khong khoi phuc duoc MU Helper.", cleanupOk ? "666666" : "CC0000")
    }
    UpdateWorkerWindowTitle()
return

ToggleHuntModule:
    Gui, Submit, NoHide
    if (!HuntModuleEnabled)
    {
        HuntSessionActive := false
        HuntGeneration += 1
        GuiControl,, HuntEnabled, 0
        Gosub, ToggleHunt
    }
    SavePersistentSettings()
return

ToggleComboModule:
    Gui, Submit, NoHide
    if (!ComboModuleEnabled && ComboRunning)
    {
        ComboRunning := false
        ReleaseAllComboKeys()
        UpdateComboStatus()
    }
    SavePersistentSettings()
return

; ========== HOTKEYS ==========
$^F1::
    if (ManagerMode)
    {
        ToggleManagerHuntGroup()
        return
    }
    SoundBeep, 1000, 50
    GuiControlGet, huntMod,, HuntModuleEnabled
    if (!huntMod)
    {
        GuiControl,, HuntModuleEnabled, 1
        Gosub, ToggleHuntModule
    }
    GuiControlGet, huntOn,, HuntEnabled
    if (huntOn)
        Gosub, StopHunt
    else
        Gosub, StartHunt
return

$^F2::
    if (ManagerMode)
    {
        ToggleManagerCombo()
        return
    }
    GuiControlGet, comboMod,, ComboModuleEnabled
    if (!comboMod)
    {
        GuiControl,, ComboModuleEnabled, 1
        Gosub, ToggleComboModule
    }
    ComboRunning := !ComboRunning
    Gui, Submit, NoHide
    ComboSelectedClass := ComboClassChoice
    UpdateComboStatus()
    if (ComboRunning)
    {
        SoundBeep, 1500, 80
        SetTimer, ComboLoop, -1
    }
    else
    {
        ReleaseAllComboKeys()
        SoundBeep, 650, 80
    }
return

$F7::
    ExitApp
return

; ========== TIMER LOOPS ==========
RefreshEngine:
    if (!hProcess)
        return
    Process, Exist, %GamePid%
    if (!ErrorLevel)
    {
        DetachEngine()
        SetStatus("Game da dong.", "CC0000")
        if (WorkerMode)
            ExitApp
        return
    }
return

RefreshOrdinaryEvents:
    RefreshOrdinaryEventStatus()
    UpdateWorkerWindowTitle()
return

EventRouteLoop:
    routeGeneration := HuntGeneration
    GuiControlGet, huntOn,, HuntEnabled
    GuiControlGet, autoTravel,, AutoEventTravel
    if (huntOn && autoTravel && !TravelBusy && IsHuntTokenValid(routeGeneration))
        UpdateEventRoute(routeGeneration)
	
return

HuntLoop:
; ========================================================
; CHU TRÌNH PHẢN XẠ VÀ GỌI ĐỒNG ĐỘI CHO CLASS DL
; ========================================================
if (IsClassDL && CurrentTargetMonsterIndex != -1) {
    
    ; 1. Bật hệ thống tự động tìm và áp sát mục tiêu của game MU (Bypass qua lỗi đứng im)
    if (ReadBuiltinHelperActive(helperActive) && !helperActive) {
        StartBuiltinHelper()
    }
    Sleep, 300 ; Chờ nhân vật tự động áp sát chạy lại gần Boss
    
    ; 2. CLICK CHUỘT TRÁI VÀO Ô SỐ 5 (Tọa độ thực tế Client máy bạn: X=913, Y=652)
    PostMessage, 0x0201, 1, ((652 << 16) | 913), , ahk_id %GameHwnd% ; WM_LBUTTONDOWN (Nhấn chuột)
    Sleep, 150
    PostMessage, 0x0202, 0, ((652 << 16) | 913), , ahk_id %GameHwnd% ; WM_LBUTTONUP (Thả chuột)
    
    ; 3. ĐỨNG CHỜ ĐÚNG 5 GIÂY theo yêu cầu của bạn
    Sleep, 5000
    
    ; 4. GIẢ LẬP BẤM PHÍM "HOME" ẨN VÀO CỬA SỔ GAME (Mã Hex: 0x24)
    PostMessage, 0x0100, 0x24, 0x01470001, , ahk_id %GameHwnd% ; WM_KEYDOWN
    Sleep, 50
    PostMessage, 0x0101, 0x24, 0xC1470001, , ahk_id %GameHwnd% ; WM_KEYUP
    
    ; Giải phóng mục tiêu để kết thúc chu trình xử lý Boss hiện tại
    CurrentTargetMonsterIndex := -1
    LastSummonTime := A_TickCount
}
; ========================================================

; ... [Giữ nguyên toàn bộ các đoạn mã quét quái mặc định của file gốc phía dưới] ...



    loopGeneration := HuntGeneration
    GuiControlGet, huntOn,, HuntEnabled
    if (!huntOn || !hProcess || !CharactersBase || !HeroPtr || TravelBusy)
        return
    GuiControlGet, autoTravel,, AutoEventTravel
    if (!autoTravel && CurrentEventRow)
    {
        CurrentEventRow := 0
        CurrentEventMap := -1
        CurrentEventMonsterCount := 0
        CurrentAllowedMonsterCount := -1
        EventInitialAllowedCount := -1
        AllowedEventTypes := {}
        AllowedEventTypesRow := 0
        EventArrivedTick := 0
        HonThachWaveWaitUntil := 0
        HonThachWaveKills := 0
        SafeZoneEscapeActive := false
        AtlansEscapeStage := 0
        AtlansStage3Since := 0
        AtlansDwellSince := 0
        ResetAtlansConnectedTransit()
        ResetPatrolRoute()
    }
    if (autoTravel && !CurrentEventRow)
    {
        SetHuntStatus("Dang cho su kien boss thuong hoat dong...", "666666")
        return
    }
    if (autoTravel && CurrentEventRow && !EventArrivedTick)
    {
        SetHuntStatus("Dang cho nut H dua nhan vat den dung su kien...", "0077AA")
        return
    }
    if (autoTravel && CurrentEventRow && GetCurrentMapId(currentMap)
        && currentMap != CurrentEventMap)
    {
        SetHuntStatus("Dang cho di chuyen den " . GetEventName(CurrentEventRow)
            . " - MapID " . CurrentEventMap . "...", "0077AA")
        return
    }

    ; Helper is the only combat/loot core. No synthetic attack click or Space.
    BuiltinHuntTick(loopGeneration)
return

IsHuntTokenValid(expectedGeneration := -1)
{
    global HuntGeneration, HuntSessionActive, hProcess
    if (expectedGeneration < 0)
        return true
    return (HuntSessionActive && hProcess && expectedGeneration = HuntGeneration)
}

; Feed the target Engine's own input state array. This is per-process and does
; not activate a game window or touch the user's real keyboard/mouse.
SendGameVirtualKey(vk, scanCode := 0, holdMs := 25, expectedGeneration := -1)
{
    global hProcess, InternalKeyStateAddress
    if (!hProcess || !IsHuntTokenValid(expectedGeneration))
        return false
    eventWasOpen := (vk = 0x48) ? IsEventPanelOpen() : false
    moveWasOpen := (vk = 0x4D) ? IsMoveMenuOpen() : false
    needsAck := (vk = 0x48 || vk = 0x4D)
    timeoutMs := needsAck ? 1600 : Max(40, holdMs)
    started := A_TickCount, success := false
    Critical, On
    while (A_TickCount - started < timeoutMs && IsHuntTokenValid(expectedGeneration))
    {
        ; The Engine advances 2->3/1/0 every frame. Repulse until the relevant
        ; UI acknowledgement changes, otherwise a single write can be consumed
        ; before the H/M handler observes it.
        if (!WriteByte(InternalKeyStateAddress + vk, 2))
            break
        Sleep, 10
        if (vk = 0x48 && IsEventPanelOpen() != eventWasOpen)
        {
            success := true
            break
        }
        if (vk = 0x4D && IsMoveMenuOpen() != moveWasOpen)
        {
            success := true
            break
        }
        if (!needsAck && A_TickCount - started >= holdMs)
        {
            success := true
            break
        }
    }
    WriteByte(InternalKeyStateAddress + vk, 0)
    Critical, Off
    return success
}

SendGameMouseClick(clientX, clientY, expectedGeneration := -1)
{
    global hProcess, InternalKeyStateAddress, InternalMouseXAddress, InternalMouseYAddress
    if (!hProcess || !IsHuntTokenValid(expectedGeneration))
        return false
    logicalX := Round(clientX), logicalY := Round(clientY)
    if (logicalX < 0 || logicalY < 0
        || !WriteDword(InternalMouseXAddress, logicalX)
        || !WriteDword(InternalMouseYAddress, logicalY))
        return false
    panelWasOpen := IsEventPanelOpen()
    moveWasOpen := IsMoveMenuOpen()
    Critical, On
    ; A release edge (1) is what these two client UI handlers consume. Repulse
    ; for a few frames and stop immediately if the clicked panel closes.
    WriteByte(InternalKeyStateAddress + 1, 3)
    Loop, 24
    {
        if (!IsHuntTokenValid(expectedGeneration))
            break
        WriteDword(InternalMouseXAddress, logicalX)
        WriteDword(InternalMouseYAddress, logicalY)
        WriteByte(InternalKeyStateAddress + 1, 1)
        Sleep, 8
        if ((panelWasOpen && !IsEventPanelOpen())
            || (moveWasOpen && !IsMoveMenuOpen()))
            break
    }
    WriteByte(InternalKeyStateAddress + 1, 0)
    Critical, Off
    return true
}

GetMoveMenuObject(ByRef moveObj)
{
    global MoveMenuPointerAddress
    moveObj := 0
    return ReadDword(MoveMenuPointerAddress, moveObj)
        && moveObj >= 0x10000 && moveObj < 0x80000000
}

IsMoveMenuOpen()
{
    return GetMoveMenuObject(moveObj) && ReadByte(moveObj + 0x08, visible)
        && visible != 0
}

; ========== COMBO LOOP ==========
ComboLoop:
    if (ComboLoopActive)
        return
    if (!ComboRunning)
        return
    ComboLoopActive := true
    comboLoopGeneration := ComboGeneration
    if (TravelBusy)
    {
        ReleaseAllComboKeys()
        ComboLoopActive := false
        SetTimer, ComboLoop, -50
        return
    }
    ; Execute exactly one source cycle, then return to the message pump before
    ; scheduling the next. Replay remains infinite, while Ctrl+F2, speed changes
    ; and travel commands can never be starved by a permanent while-loop.
    ComboCycleAbort := false
    GuiControlGet, comboMod,, ComboModuleEnabled
    if (!comboMod)
        ComboRunning := false
    else if (ComboSelectedClass = "DW")
        ComboDW_TELE()
    else if (ComboSelectedClass = "DK")
        ComboDK_MCR()
    else if (ComboSelectedClass = "DK V1")
        ComboDK_V1_MCR()
    else if (ComboSelectedClass = "ELF")
        ComboELF()
    else if (ComboSelectedClass = "RF")
        ComboRF()
    else if (ComboSelectedClass = "SUM")
        ComboSUM()
    else if (ComboSelectedClass = "DL")
        ComboDL()
    else if (ComboSelectedClass = "MG")
        ComboMG()
    else if (ComboSelectedClass = "AUTO HP")
        ComboAutoHP()
    else
        ComboRunning := false
    if (!ComboRunning || comboLoopGeneration != ComboGeneration || ComboCycleAbort || TravelBusy)
        ReleaseAllComboKeys()
    ComboLoopActive := false
    UpdateComboStatus()
    UpdateWorkerWindowTitle()
    if (ComboRunning)
        SetTimer, ComboLoop, -1
return

GuiSize:
    if (A_EventInfo != 1 && FreeScaleReady)
        ApplyFreeGuiScaleForCurrentWindow()
return

GuiClose:
GuiEscape:
    ExitApp
return

HandleScriptExit:
    if (!ScriptCleanupRunning)
    {
        ScriptCleanupRunning := true
        if (ManagerMode)
        {
            SetTimer, ManagerRefreshTimer, Off
            SetTimer, ManagerReconcileTimer, Off
            StopAllManagerWorkers()
            Sleep, 500
            if (TimerPeriodActive)
            {
                DllCall("Winmm\timeEndPeriod", "UInt", 1)
                TimerPeriodActive := false
            }
            ReleaseFreeScaleResources()
            if (InstanceMutexHandle)
                DllCall("Kernel32\CloseHandle", "Ptr", InstanceMutexHandle)
            DllCall("Kernel32\ExitProcess", "UInt", 0)
        }
        SavePersistentSettings()
        HuntSessionActive := false
        HuntGeneration += 1
        ComboRunning := false
        SetTimer, HuntLoop, Off
        SetTimer, EventRouteLoop, Off
        SetTimer, SaveFreeScaleSetting, Off
        SetTimer, ApplyRequestedFreeScale, Off
        ReleaseAllComboKeys()
        if (!DetachEngine(false))
            DetachEngine(true)
        if (TimerPeriodActive)
        {
            DllCall("Winmm\timeEndPeriod", "UInt", 1)
            TimerPeriodActive := false
        }
        ReleaseFreeScaleResources()
        if (InstanceMutexHandle)
            DllCall("Kernel32\CloseHandle", "Ptr", InstanceMutexHandle)
    }
    ; AHK v1's legacy OnExit label can resume the script after Return. Finish
    ; explicitly so Reload/#SingleInstance never leaves a detached ghost GUI.
    DllCall("Kernel32\ExitProcess", "UInt", 0)
return

; ========== UI SCALING ==========
NormalizeUiScale(value, fallback := 100)
{
    global FreeScaleMinPercent, FreeScaleMaxPercent
    value += 0
    if (value < FreeScaleMinPercent || value > FreeScaleMaxPercent)
        return fallback
    return Round(value)
}

ScaleUiValue(value)
{
    global UiScalePercent
    return Round((value + 0) * UiScalePercent / 100.0)
}

ScaleGuiOptions(options)
{
    result := ""
    Loop, Parse, options, %A_Space%
    {
        token := A_LoopField
        if (RegExMatch(token, "i)^(x|y|w|h)([+-]?)(\d+)$", part))
            token := part1 . part2 . ScaleUiValue(part3)
        else if (RegExMatch(token, "i)^(xm|ym|xp|yp)([+-])(\d+)$", relative))
            token := relative1 . relative2 . ScaleUiValue(relative3)
        if (token != "")
            result .= (result = "" ? "" : " ") . token
    }
    return result
}

SetScaledGuiFont(baseSize, style := "Norm")
{
    scaledSize := ScaleUiValue(baseSize)
    if (scaledSize < 5)
        scaledSize := 5
    fontOptions := "s" . scaledSize . " " . style
    Gui, Font, %fontOptions%, Segoe UI
}

InitializeFreeGuiScaling()
{
    global MainGuiHwnd, UiScalePercent, FreeScaleReady, FreeScaleControls
    global FreeScaleBaseClientW, FreeScaleBaseClientH
    global FreeScaleNonClientW, FreeScaleNonClientH
    global FreeScaleAppliedFontPercent, FreeScaleMinPercent, FreeScaleMaxPercent
    if (!MainGuiHwnd)
        return false

    initialScale := UiScalePercent / 100.0
    VarSetCapacity(clientRect, 16, 0)
    VarSetCapacity(windowRect, 16, 0)
    if (!DllCall("GetClientRect", "Ptr", MainGuiHwnd, "Ptr", &clientRect)
        || !DllCall("GetWindowRect", "Ptr", MainGuiHwnd, "Ptr", &windowRect))
        return false
    clientW := NumGet(clientRect, 8, "Int")
    clientH := NumGet(clientRect, 12, "Int")
    windowW := NumGet(windowRect, 8, "Int") - NumGet(windowRect, 0, "Int")
    windowH := NumGet(windowRect, 12, "Int") - NumGet(windowRect, 4, "Int")
    FreeScaleBaseClientW := clientW / initialScale
    FreeScaleBaseClientH := clientH / initialScale
    FreeScaleNonClientW := windowW - clientW
    FreeScaleNonClientH := windowH - clientH
    FreeScaleControls := []
    minControlX := 0x7FFFFFFF, minControlY := 0x7FFFFFFF
    maxControlRight := 0, maxControlBottom := 0

    windowSpec := "ahk_id " . MainGuiHwnd
    WinGet, childHandles, ControlListHwnd, %windowSpec%
    Loop, Parse, childHandles, `n, `r
    {
        controlHwnd := A_LoopField + 0
        if (!controlHwnd)
            continue
        if (!GetChildClientRect(controlHwnd, MainGuiHwnd, x, y, width, height))
            continue
        if (width > 0 || height > 0)
        {
            minControlX := Min(minControlX, x), minControlY := Min(minControlY, y)
            maxControlRight := Max(maxControlRight, x + width)
            maxControlBottom := Max(maxControlBottom, y + height)
        }
        styleKey := CaptureFreeScaleStyle(controlHwnd, initialScale)
        FreeScaleControls.Push({hwnd: controlHwnd, x: x / initialScale
            , y: y / initialScale, width: width / initialScale
            , height: height / initialScale, styleKey: styleKey})
    }
    ; Child extents preserve the intended auto-size even if Windows capped an
    ; oversized saved window to the current monitor during Gui, Show.
    if (minControlX < 0x7FFFFFFF && maxControlRight > 0)
        FreeScaleBaseClientW := (maxControlRight + minControlX) / initialScale
    if (minControlY < 0x7FFFFFFF && maxControlBottom > 0)
        FreeScaleBaseClientH := (maxControlBottom + minControlY) / initialScale
    initialPercent := Round(initialScale * 100)
    FreeScaleAppliedFontPercent := initialPercent
    UpdateFreeScaleRangeForMonitor()
    FreeScaleReady := true
    OnMessage(0x0214, "FreeScaleOnSizing")
    if (UiScalePercent != initialPercent)
        ResizeMainGuiToScale(UiScalePercent)
    return true
}

UpdateFreeScaleRangeForMonitor()
{
    global MainGuiHwnd, UiScalePercent, FreeScaleBaseClientW, FreeScaleBaseClientH
    global FreeScaleNonClientW, FreeScaleNonClientH, FreeScaleMinPercent
    global FreeScaleMaxPercent, FreeScaleAbsoluteMaxPercent
    monitor := DllCall("MonitorFromWindow", "Ptr", MainGuiHwnd, "UInt", 2, "Ptr")
    if (monitor)
    {
        VarSetCapacity(monitorInfo, 40, 0)
        NumPut(40, monitorInfo, 0, "UInt")
        if (DllCall("GetMonitorInfo", "Ptr", monitor, "Ptr", &monitorInfo))
        {
            workW := NumGet(monitorInfo, 28, "Int") - NumGet(monitorInfo, 20, "Int")
            workH := NumGet(monitorInfo, 32, "Int") - NumGet(monitorInfo, 24, "Int")
            fitW := (workW - FreeScaleNonClientW) / FreeScaleBaseClientW * 100.0
            fitH := (workH - FreeScaleNonClientH) / FreeScaleBaseClientH * 100.0
            FreeScaleMaxPercent := Floor(Min(FreeScaleAbsoluteMaxPercent, fitW, fitH))
        }
    }
    if (FreeScaleMaxPercent < FreeScaleMinPercent)
        FreeScaleMaxPercent := FreeScaleMinPercent
    rangeOptions := "+Range" . FreeScaleMinPercent . "-" . FreeScaleMaxPercent
    GuiControl, %rangeOptions%, UiScaleSlider
    if (UiScalePercent > FreeScaleMaxPercent)
        UiScalePercent := FreeScaleMaxPercent
    GuiControl,, UiScaleSlider, %UiScalePercent%
    scaleLabel := UiScalePercent . "%"
    GuiControl,, UiScaleValueText, %scaleLabel%
    return true
}

GetChildClientRect(childHwnd, parentHwnd, ByRef x, ByRef y, ByRef width, ByRef height)
{
    VarSetCapacity(rect, 16, 0)
    if (!DllCall("GetWindowRect", "Ptr", childHwnd, "Ptr", &rect))
        return false
    left := NumGet(rect, 0, "Int"), top := NumGet(rect, 4, "Int")
    right := NumGet(rect, 8, "Int"), bottom := NumGet(rect, 12, "Int")
    VarSetCapacity(point1, 8, 0), VarSetCapacity(point2, 8, 0)
    NumPut(left, point1, 0, "Int"), NumPut(top, point1, 4, "Int")
    NumPut(right, point2, 0, "Int"), NumPut(bottom, point2, 4, "Int")
    if (!DllCall("ScreenToClient", "Ptr", parentHwnd, "Ptr", &point1)
        || !DllCall("ScreenToClient", "Ptr", parentHwnd, "Ptr", &point2))
        return false
    x := NumGet(point1, 0, "Int"), y := NumGet(point1, 4, "Int")
    width := NumGet(point2, 0, "Int") - x
    height := NumGet(point2, 4, "Int") - y
    return true
}

CaptureFreeScaleStyle(controlHwnd, initialScale)
{
    global FreeScaleStyles
    fontHwnd := DllCall("SendMessage", "Ptr", controlHwnd, "UInt", 0x31
        , "Ptr", 0, "Ptr", 0, "Ptr")
    if (!fontHwnd)
        return ""
    VarSetCapacity(logFont, 92, 0)
    if (DllCall("Gdi32\GetObjectW", "Ptr", fontHwnd, "Int", 92, "Ptr", &logFont, "Int") <= 0)
        return ""
    baseHeight := NumGet(logFont, 0, "Int") / initialScale
    baseWidth := NumGet(logFont, 4, "Int") / initialScale
    weight := NumGet(logFont, 16, "Int")
    italic := NumGet(logFont, 20, "UChar")
    underline := NumGet(logFont, 21, "UChar")
    strikeOut := NumGet(logFont, 22, "UChar")
    charSet := NumGet(logFont, 23, "UChar")
    outPrecision := NumGet(logFont, 24, "UChar")
    clipPrecision := NumGet(logFont, 25, "UChar")
    quality := NumGet(logFont, 26, "UChar")
    pitchAndFamily := NumGet(logFont, 27, "UChar")
    faceName := StrGet(&logFont + 28, 32, "UTF-16")
    styleKey := Round(baseHeight, 2) . "|" . Round(baseWidth, 2) . "|" . weight
        . "|" . italic . "|" . underline . "|" . strikeOut . "|" . charSet
        . "|" . outPrecision . "|" . clipPrecision . "|" . quality
        . "|" . pitchAndFamily . "|" . faceName
    if (!FreeScaleStyles.HasKey(styleKey))
        FreeScaleStyles[styleKey] := {height: baseHeight, width: baseWidth, weight: weight
            , italic: italic, underline: underline, strikeOut: strikeOut, charSet: charSet
            , outPrecision: outPrecision, clipPrecision: clipPrecision, quality: quality
            , pitchAndFamily: pitchAndFamily, faceName: faceName}
    return styleKey
}

ApplyFreeGuiScale(clientWidth, clientHeight)
{
    global MainGuiHwnd, UiScalePercent, FreeScaleControls, FreeScaleReady
    global FreeScaleBaseClientW, FreeScaleBaseClientH, FreeScaleInternalUpdate
    global FreeScaleRequestedPercent
    if (!FreeScaleReady || clientWidth <= 0 || clientHeight <= 0)
        return false
    scale := Min(clientWidth / FreeScaleBaseClientW, clientHeight / FreeScaleBaseClientH)
    percent := NormalizeUiScale(Round(scale * 100), UiScalePercent)
    scale := percent / 100.0
    contentWidth := FreeScaleBaseClientW * scale
    contentHeight := FreeScaleBaseClientH * scale
    offsetX := Round((clientWidth - contentWidth) / 2.0)
    offsetY := Round((clientHeight - contentHeight) / 2.0)
    count := FreeScaleControls.Length()
    deferHandle := DllCall("BeginDeferWindowPos", "Int", count, "Ptr")
    for _, control in FreeScaleControls
    {
        newX := offsetX + Round(control.x * scale)
        newY := offsetY + Round(control.y * scale)
        newW := Max(0, Round(control.width * scale))
        newH := Max(0, Round(control.height * scale))
        if (deferHandle)
        {
            nextHandle := DllCall("DeferWindowPos", "Ptr", deferHandle, "Ptr", control.hwnd
                , "Ptr", 0, "Int", newX, "Int", newY, "Int", newW, "Int", newH
                , "UInt", 0x14, "Ptr")
            if (nextHandle)
                deferHandle := nextHandle
        }
        else
            DllCall("SetWindowPos", "Ptr", control.hwnd, "Ptr", 0, "Int", newX, "Int", newY
                , "Int", newW, "Int", newH, "UInt", 0x14)
    }
    if (deferHandle)
        DllCall("EndDeferWindowPos", "Ptr", deferHandle)
    ApplyFreeScaleFonts(scale, percent)
    UiScalePercent := percent
    if (!FreeScaleRequestedPercent)
    {
        FreeScaleInternalUpdate := true
        GuiControl,, UiScaleSlider, %percent%
        scaleLabel := percent . "%"
        GuiControl,, UiScaleValueText, %scaleLabel%
        FreeScaleInternalUpdate := false
    }
    SetTimer, SaveFreeScaleSetting, -500
    return true
}

ApplyFreeGuiScaleForCurrentWindow()
{
    global MainGuiHwnd
    VarSetCapacity(clientRect, 16, 0)
    if (!MainGuiHwnd || !DllCall("GetClientRect", "Ptr", MainGuiHwnd, "Ptr", &clientRect))
        return false
    return ApplyFreeGuiScale(NumGet(clientRect, 8, "Int"), NumGet(clientRect, 12, "Int"))
}

ApplyFreeScaleFonts(scale, percent)
{
    global MainGuiHwnd, FreeScaleStyles, FreeScaleControls, FreeScaleFonts
    global FreeScaleAppliedFontPercent
    if (percent = FreeScaleAppliedFontPercent)
        return true
    newFonts := {}
    for styleKey, style in FreeScaleStyles
    {
        fontHeight := Round(style.height * scale)
        fontWidth := Round(style.width * scale)
        newFont := DllCall("Gdi32\CreateFontW", "Int", fontHeight, "Int", fontWidth
            , "Int", 0, "Int", 0, "Int", style.weight, "UInt", style.italic
            , "UInt", style.underline, "UInt", style.strikeOut, "UInt", style.charSet
            , "UInt", style.outPrecision, "UInt", style.clipPrecision, "UInt", style.quality
            , "UInt", style.pitchAndFamily, "WStr", style.faceName, "Ptr")
        if (newFont)
            newFonts[styleKey] := newFont
    }
    for _, control in FreeScaleControls
    {
        if (control.styleKey != "" && newFonts.HasKey(control.styleKey))
            DllCall("SendMessage", "Ptr", control.hwnd, "UInt", 0x30
                , "Ptr", newFonts[control.styleKey], "Ptr", 0)
    }
    for _, oldFont in FreeScaleFonts
        DllCall("Gdi32\DeleteObject", "Ptr", oldFont)
    FreeScaleFonts := newFonts
    FreeScaleAppliedFontPercent := percent
    DllCall("RedrawWindow", "Ptr", MainGuiHwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x181)
    return true
}

ResizeMainGuiToScale(requestedPercent)
{
    global MainGuiHwnd, FreeScaleReady, FreeScaleBaseClientW, FreeScaleBaseClientH
    global FreeScaleNonClientW, FreeScaleNonClientH, UiScalePercent
    if (!FreeScaleReady || !MainGuiHwnd)
        return false
    requestedPercent := NormalizeUiScale(requestedPercent, UiScalePercent)
    scale := requestedPercent / 100.0
    targetW := Round(FreeScaleBaseClientW * scale + FreeScaleNonClientW)
    targetH := Round(FreeScaleBaseClientH * scale + FreeScaleNonClientH)
    VarSetCapacity(rect, 16, 0)
    if (!DllCall("GetWindowRect", "Ptr", MainGuiHwnd, "Ptr", &rect))
        return false
    currentW := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")
    currentH := NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")
    centerX := NumGet(rect, 0, "Int") + currentW / 2.0
    centerY := NumGet(rect, 4, "Int") + currentH / 2.0
    targetX := Round(centerX - targetW / 2.0)
    targetY := Round(centerY - targetH / 2.0)
    return DllCall("SetWindowPos", "Ptr", MainGuiHwnd, "Ptr", 0
        , "Int", targetX, "Int", targetY, "Int", targetW, "Int", targetH, "UInt", 0x14)
}

FreeScaleOnSizing(wParam, lParam, msg, hwnd)
{
    global MainGuiHwnd, FreeScaleReady, FreeScaleBaseClientW, FreeScaleBaseClientH
    global FreeScaleNonClientW, FreeScaleNonClientH, FreeScaleMinPercent, FreeScaleMaxPercent
    if (!FreeScaleReady || hwnd != MainGuiHwnd || !lParam)
        return
    left := NumGet(lParam + 0, 0, "Int"), top := NumGet(lParam + 0, 4, "Int")
    right := NumGet(lParam + 0, 8, "Int"), bottom := NumGet(lParam + 0, 12, "Int")
    proposedClientW := Max(1, right - left - FreeScaleNonClientW)
    proposedClientH := Max(1, bottom - top - FreeScaleNonClientH)
    if (wParam = 3 || wParam = 6)
        scale := proposedClientH / FreeScaleBaseClientH
    else
        scale := proposedClientW / FreeScaleBaseClientW
    scale := Max(FreeScaleMinPercent / 100.0, Min(FreeScaleMaxPercent / 100.0, scale))
    targetW := Round(FreeScaleBaseClientW * scale + FreeScaleNonClientW)
    targetH := Round(FreeScaleBaseClientH * scale + FreeScaleNonClientH)
    centerX := (left + right) / 2.0, centerY := (top + bottom) / 2.0
    if (wParam = 1)
    {
        left := right - targetW
        top := Round(centerY - targetH / 2.0), bottom := top + targetH
    }
    else if (wParam = 2)
    {
        right := left + targetW
        top := Round(centerY - targetH / 2.0), bottom := top + targetH
    }
    else if (wParam = 3)
    {
        top := bottom - targetH
        left := Round(centerX - targetW / 2.0), right := left + targetW
    }
    else if (wParam = 4)
        left := right - targetW, top := bottom - targetH
    else if (wParam = 5)
        right := left + targetW, top := bottom - targetH
    else if (wParam = 6)
    {
        bottom := top + targetH
        left := Round(centerX - targetW / 2.0), right := left + targetW
    }
    else if (wParam = 7)
        left := right - targetW, bottom := top + targetH
    else if (wParam = 8)
        right := left + targetW, bottom := top + targetH
    NumPut(left, lParam + 0, 0, "Int"), NumPut(top, lParam + 0, 4, "Int")
    NumPut(right, lParam + 0, 8, "Int"), NumPut(bottom, lParam + 0, 12, "Int")
    return true
}

ReleaseFreeScaleResources()
{
    global FreeScaleReady, FreeScaleFonts
    FreeScaleReady := false
    OnMessage(0x0214, "")
    for _, fontHwnd in FreeScaleFonts
        DllCall("Gdi32\DeleteObject", "Ptr", fontHwnd)
    FreeScaleFonts := {}
}

; ========== PERSISTENT SETTINGS ==========
IsValidComboClass(value)
{
    validClasses := {"DW": 1, "DK": 1, "DK V1": 1, "ELF": 1, "RF": 1, "SUM": 1
        , "DL": 1, "MG": 1, "AUTO HP": 1}
    return validClasses.HasKey(value)
}

AcquireInstanceMutex(name)
{
    global InstanceMutexHandle
    handle := DllCall("Kernel32\CreateMutex", "Ptr", 0, "Int", 0, "Str", name, "Ptr")
    if (!handle)
        return false
    if (A_LastError = 183)
    {
        DllCall("Kernel32\CloseHandle", "Ptr", handle)
        return false
    }
    InstanceMutexHandle := handle
    return true
}

FindWorkerWindow(gamePid)
{
    DetectHiddenWindows, On
    WinGet, workerList, List, MU-PKZ Worker - GamePID
    Loop, %workerList%
    {
        hwnd := workerList%A_Index%
        if (!hwnd)
            continue
        WinGetTitle, title, ahk_id %hwnd%
        if (RegExMatch(title, "^MU-PKZ Worker - GamePID " . gamePid . "(?: -|$)"))
            return hwnd
    }
    return 0
}

ParseGameWindowIdentity(title, ByRef character, ByRef mapId)
{
    character := "Khong ro", mapId := "--"
    if (RegExMatch(title, "i)-\s*([^|]+?)\s*\|\|", nameMatch))
        character := Trim(nameMatch1)
    if (RegExMatch(title, "i)MapID\s*:\s*(\d+)", mapMatch))
        mapId := mapMatch1 + 0
    return true
}

FindGameWindowForPid(gamePid)
{
    if (!gamePid)
        return 0
    oldDetect := A_DetectHiddenWindows
    DetectHiddenWindows, On
    WinGet, gameWindows, List, ahk_pid %gamePid%
    foundHwnd := 0
    Loop, %gameWindows%
    {
        hwnd := gameWindows%A_Index%
        if (!hwnd)
            continue
        WinGetTitle, title, ahk_id %hwnd%
        if (title != "" && RegExMatch(title, "i)MapID\s*:\s*\d+"))
        {
            foundHwnd := hwnd
            break
        }
    }
    DetectHiddenWindows, %oldDetect%
    return foundHwnd
}

RefreshManagerAccounts()
{
    global ManagerAccountRows, ManagerFirstRefresh, ManagerMode, ManagerListRebuilding
    global ManagerDesiredWorkers, ManagerPidCharacters, ManagerWorkerLaunchTick
    global ManagerEnabledCharacters
    global ManagerComboSelectedPid, ManagerComboSelectedCharacter
    global ManagerComboDesiredPid, ManagerComboDesiredCharacter
    global ManagerComboObservedPid, ManagerComboObservedClass
    if (!ManagerMode)
        return
    Critical, On
    ManagerListRebuilding := true
    GuiControl, -g, ManagerAccounts
    GuiControl, -g, ManagerComboAccounts
    Gui, ListView, ManagerAccounts
    LV_Delete()
    Gui, ListView, ManagerComboAccounts
    LV_Delete()
    ManagerAccountRows := []
    WinGet, engineList, List, ahk_exe Engine.exe
    found := 0, running := 0, seenPids := {}, accounts := []
    resolvedSelectedPid := 0, resolvedDesiredPid := 0
    Loop, %engineList%
    {
        hwnd := engineList%A_Index%
        if (!hwnd)
            continue
        WinGet, pid, PID, ahk_id %hwnd%
        WinGetTitle, title, ahk_id %hwnd%
        if (!pid || seenPids.HasKey(pid) || title = ""
            || !RegExMatch(title, "i)MapID\s*:\s*\d+"))
            continue
        seenPids[pid] := true
        ParseGameWindowIdentity(title, character, mapId)
        if (!resolvedSelectedPid && ManagerComboSelectedCharacter != ""
            && character = ManagerComboSelectedCharacter)
            resolvedSelectedPid := pid
        if (!resolvedDesiredPid && ManagerComboDesiredCharacter != ""
            && character = ManagerComboDesiredCharacter)
            resolvedDesiredPid := pid
        workerHwnd := FindWorkerWindow(pid)
        GetWorkerModuleState(workerHwnd, huntOn, comboClass, workerState)
        identityChanged := ManagerPidCharacters.HasKey(pid)
            && ManagerPidCharacters[pid] != character
        if (!ManagerDesiredWorkers.HasKey(pid))
            ManagerDesiredWorkers[pid] := workerHwnd ? huntOn : IsSavedManagerCharacterEnabled(character)
        else if (identityChanged)
            ManagerDesiredWorkers[pid] := IsSavedManagerCharacterEnabled(character)
        ManagerPidCharacters[pid] := character
        if (huntOn)
            running += 1
        accounts.Push({pid: pid, hwnd: hwnd, character: character, mapId: mapId
            , huntOn: huntOn, comboClass: comboClass, state: workerState})
        ManagerAccountRows.Push({pid: pid, hwnd: hwnd, character: character, mapId: mapId})
        found += 1
    }
    ; PIDs are transient. Dropping stale identities prevents a recycled Engine
    ; PID (or a different character logged into the same PID) from inheriting
    ; another character's previous tick state.
    stalePids := []
    for knownPid, _ in ManagerPidCharacters
        if (!seenPids.HasKey(knownPid))
            stalePids.Push(knownPid)
    for _, stalePid in stalePids
    {
        ManagerPidCharacters.Delete(stalePid)
        ManagerDesiredWorkers.Delete(stalePid)
        ManagerWorkerLaunchTick.Delete(stalePid)
    }
    ManagerComboSelectedPid := resolvedSelectedPid
    ManagerComboDesiredPid := resolvedDesiredPid
    ManagerComboObservedPid := 0
    ManagerComboObservedClass := "OFF"
    ; Prefer the desired worker when observing an in-flight switch. Any other
    ; combo worker is still recorded and will be stopped by reconciliation.
    for _, account in accounts
    {
        if (account.comboClass = "OFF")
            continue
        if (!ManagerComboObservedPid || account.pid = ManagerComboDesiredPid)
        {
            ManagerComboObservedPid := account.pid
            ManagerComboObservedClass := account.comboClass
        }
    }
    for _, account in accounts
    {
        huntState := account.huntOn ? "Đang ăn Buffet BOSS" : (account.state = "STARTING" ? "Đang Khởi Động" : "Đang Đứng Ngắm Hoa Lệ Rơi")
        Gui, ListView, ManagerAccounts
        huntOption := ManagerDesiredWorkers[account.pid] ? "Check" : ""
        LV_Add(huntOption, "", account.character, account.pid, account.mapId, huntState)
        Gui, ListView, ManagerComboAccounts
        comboSelected := (ManagerComboSelectedPid = account.pid)
        comboOption := comboSelected ? "Check" : ""
        comboState := account.comboClass != "OFF" ? ("Đang Chạy - " . account.comboClass) : "Tắt"
        LV_Add(comboOption, "", account.character, account.pid, account.mapId, comboState)
    }
    Gui, ListView, ManagerAccounts
    LV_ModifyCol(1, 48)
    LV_ModifyCol(2, 155)
    LV_ModifyCol(3, 75)
    LV_ModifyCol(4, 65)
    LV_ModifyCol(5, 190)
    Gui, ListView, ManagerComboAccounts
    LV_ModifyCol(1, 48)
    LV_ModifyCol(2, 175)
    LV_ModifyCol(3, 80)
    LV_ModifyCol(4, 70)
    LV_ModifyCol(5, 190)
    ManagerFirstRefresh := false
    GuiControl,, ManagerSummaryText, % "Da nhan " . found . " tai khoan | Dang chay: " . running
    GuiControl, +gManagerAccountToggled, ManagerAccounts
    GuiControl, +gManagerComboAccountToggled, ManagerComboAccounts
    ManagerListRebuilding := false
    Critical, Off
    UpdateManagerComboStatus()
}

GetWorkerModuleState(workerHwnd, ByRef huntOn, ByRef comboClass, ByRef state)
{
    huntOn := 0, comboClass := "OFF", state := "STOPPED"
    if (!workerHwnd)
        return false
    WinGetTitle, title, ahk_id %workerHwnd%
    if (InStr(title, " - START FAILED"))
        state := "FAILED"
    else if (InStr(title, "STARTING"))
        state := "STARTING"
    else
        state := "READY"
    if (RegExMatch(title, "HUNT=(ON|OFF)", huntMatch))
        huntOn := (huntMatch1 = "ON") ? 1 : 0
    else if (InStr(title, " - RUNNING"))
        huntOn := 1
    if (RegExMatch(title, "COMBO=([A-Z0-9_]+)", comboMatch))
        comboClass := StrReplace(comboMatch1, "_", " ")
    return true
}

IsSavedManagerCharacterEnabled(character)
{
    global ManagerEnabledCharacters
    if (ManagerEnabledCharacters = "*")
        return 1
    if (ManagerEnabledCharacters = "" || ManagerEnabledCharacters = "-")
        return 0
    Loop, Parse, ManagerEnabledCharacters, |
        if (A_LoopField = character)
            return 1
    return 0
}

SaveManagerEnabledCharacters()
{
    global ManagerAccountRows, ManagerDesiredWorkers, ManagerEnabledCharacters, SettingsRegKey
    value := ""
    for _, account in ManagerAccountRows
        if (ManagerDesiredWorkers.HasKey(account.pid) && ManagerDesiredWorkers[account.pid])
            value .= (value = "" ? "" : "|") . account.character
    if (value = "")
        value := "-"
    ManagerEnabledCharacters := value
    RegWrite, REG_SZ, HKEY_CURRENT_USER, %SettingsRegKey%, EnabledCharacters, %value%
}

SaveManagerSettings(singleBoss, multiBoss, autoTravel)
{
    global SettingsRegKey, SavedHuntSingleBoss, SavedHuntMultiBoss, SavedAutoEventTravel
    singleBoss := singleBoss ? 1 : 0
    multiBoss := multiBoss ? 1 : 0
    autoTravel := autoTravel ? 1 : 0
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, %SettingsRegKey%, HuntSingleBoss, %singleBoss%
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, %SettingsRegKey%, HuntMultiBoss, %multiBoss%
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, %SettingsRegKey%, AutoEventTravel, %autoTravel%
    SavedHuntSingleBoss := singleBoss
    SavedHuntMultiBoss := multiBoss
    SavedAutoEventTravel := autoTravel
}

NotifyManagerWorkersSettingsChanged()
{
    global SettingsReloadMessage
    DetectHiddenWindows, On
    WinGet, workerList, List, MU-PKZ Worker - GamePID
    Loop, %workerList%
    {
        hwnd := workerList%A_Index%
        if (hwnd)
            PostMessage, %SettingsReloadMessage%, 0, 0,, ahk_id %hwnd%
    }
}

HandleWorkerSettingsReload(wParam, lParam, msg, hwnd)
{
    global WorkerMode, SavedHuntSingleBoss, SavedHuntMultiBoss, SavedAutoEventTravel
    global SavedComboClass, SavedComboSpeedPercent, ComboSelectedClass, ComboPlaybackSpeedPercent
    if (!WorkerMode)
        return 0
    SavedHuntSingleBoss := NormalizeSavedBool(ReadPersistentSetting("HuntSingleBoss", SavedHuntSingleBoss), SavedHuntSingleBoss)
    SavedHuntMultiBoss := NormalizeSavedBool(ReadPersistentSetting("HuntMultiBoss", SavedHuntMultiBoss), SavedHuntMultiBoss)
    SavedAutoEventTravel := NormalizeSavedBool(ReadPersistentSetting("AutoEventTravel", SavedAutoEventTravel), SavedAutoEventTravel)
    GuiControl,, HuntSingleBoss, %SavedHuntSingleBoss%
    GuiControl,, HuntMultiBoss, %SavedHuntMultiBoss%
    GuiControl,, AutoEventTravel, %SavedAutoEventTravel%
    speedClass := ComboSelectedClass != "" ? ComboSelectedClass : SavedComboClass
    SavedComboSpeedPercent := ReadComboSpeedSetting(speedClass)
    ComboPlaybackSpeedPercent := SavedComboSpeedPercent
    UpdateWorkerWindowTitle()
    return 1
}

HandleWorkerCommandMessage(wParam, lParam, msg, hwnd)
{
    global WorkerMode, PendingWorkerHuntDesired, PendingWorkerComboDesiredClassId
    if (!WorkerMode)
        return 0
    commandId := wParam + 0
    argument := lParam + 0
    ; Keep the newest desired state for each independent module. This is both
    ; lossless across hunt+combo posts and naturally collapses duplicate timer
    ; reconciliations without growing an unbounded queue.
    Critical, On
    if (commandId = 1 || commandId = 2)
        PendingWorkerHuntDesired := (commandId = 1) ? 1 : 0
    else if (commandId = 3 || commandId = 4)
        PendingWorkerComboDesiredClassId := (commandId = 3) ? argument : 0
    Critical, Off
    SetTimer, ProcessWorkerCommand, -10
    return 1
}

ProcessPendingWorkerCommand()
{
    global PendingWorkerHuntDesired, PendingWorkerComboDesiredClassId
    global PendingComboStartClassId, WorkerHuntDesired, WorkerHuntStarting
    global WorkerHuntFailed, WorkerStartAttempts
    Critical, On
    huntDesired := PendingWorkerHuntDesired
    comboDesiredClassId := PendingWorkerComboDesiredClassId
    PendingWorkerHuntDesired := -1
    PendingWorkerComboDesiredClassId := -1
    Critical, Off
    if (huntDesired >= 0)
    {
        WorkerHuntDesired := huntDesired ? true : false
        WorkerHuntFailed := false
        if (WorkerHuntDesired)
        {
            WorkerHuntStarting := true
            WorkerStartAttempts := 0
            SetTimer, WorkerStartHunt, -1
        }
        else
        {
            WorkerHuntStarting := false
            WorkerStartAttempts := 0
            SetTimer, WorkerStartHunt, Off
            Gosub, StopHunt
        }
    }
    if (comboDesiredClassId > 0)
        StartWorkerCombo(comboDesiredClassId)
    else if (comboDesiredClassId = 0)
    {
        PendingComboStartClassId := 0
        StopWorkerCombo()
    }
    UpdateWorkerWindowTitle()
}

StartWorkerCombo(classId)
{
    global hProcess, ComboRunning, ComboSelectedClass, ComboGeneration, ComboLoopActive
    global PendingComboStartClassId, SavedComboClass, SavedComboSpeedPercent
    global ComboPlaybackSpeedPercent
    comboClass := ComboIdToClass(classId)
    if (comboClass = "")
        return false
    if (ComboLoopActive)
    {
        if (ComboRunning && ComboSelectedClass = comboClass)
            return true
        PendingComboStartClassId := classId
        StopWorkerCombo()
        SetTimer, WorkerRetryComboStart, -100
        return true
    }
    if (!hProcess && !AttachToEngine(false))
        return false
    GuiControl,, ComboModuleEnabled, 1
    GuiControl, ChooseString, ComboClassChoice, %comboClass%
    ComboSelectedClass := comboClass
    SavedComboClass := comboClass
    SavedComboSpeedPercent := ReadComboSpeedSetting(comboClass)
    ComboPlaybackSpeedPercent := SavedComboSpeedPercent
    ComboGeneration += 1
    ComboRunning := true
    UpdateComboStatus()
    UpdateWorkerWindowTitle()
    if (!ComboLoopActive)
        SetTimer, ComboLoop, -1
    return true
}

RetryPendingWorkerComboStart()
{
    global PendingComboStartClassId, ComboLoopActive
    if (!PendingComboStartClassId)
        return
    if (ComboLoopActive)
    {
        SetTimer, WorkerRetryComboStart, -100
        return
    }
    classId := PendingComboStartClassId
    PendingComboStartClassId := 0
    StartWorkerCombo(classId)
}

StopWorkerCombo()
{
    global ComboRunning, ComboGeneration, PendingComboStartClassId
    ComboRunning := false
    ComboGeneration += 1
    ReleaseAllComboKeys()
    SetTimer, WorkerReleaseComboKeys, -75
    UpdateComboStatus()
    UpdateWorkerWindowTitle()
    return true
}

UpdateWorkerWindowTitle()
{
    global WorkerMode, MainGuiHwnd, WorkerTargetPid
    global ComboRunning, ComboSelectedClass, ComboPlaybackSpeedPercent, CurrentEventRow
    global WorkerHuntStarting, WorkerHuntFailed, WorkerStartAttempts
    global WorkerMaxStartAttempts, WorkerLastWindowTitle
    if (!WorkerMode || !MainGuiHwnd)
        return
    GuiControlGet, huntOn,, HuntEnabled
    comboToken := ComboRunning ? StrReplace(ComboSelectedClass, " ", "_") : "OFF"
    if (WorkerHuntFailed)
        phase := "START FAILED"
    else if (WorkerHuntStarting)
        phase := "STARTING " . WorkerStartAttempts . "/" . WorkerMaxStartAttempts
    else
        phase := "READY"
    mapId := -1
    GetCurrentMapId(mapId)
    title := "MU-PKZ Worker - GamePID " . WorkerTargetPid . " - " . phase . " - HUNT="
        . (huntOn ? "ON" : "OFF") . " - COMBO=" . comboToken
        . " - SPEED=" . ComboPlaybackSpeedPercent . "%"
        . " - MAP=" . mapId . " - EVENT=" . CurrentEventRow
    if (title != WorkerLastWindowTitle)
    {
        WinSetTitle, ahk_id %MainGuiHwnd%,, %title%
        WorkerLastWindowTitle := title
    }
}

HandleManagerHuntToggle(eventKind, flags, row)
{
    global ManagerListRebuilding, ManagerDesiredWorkers
    if (ManagerListRebuilding || eventKind != "I" || !row)
        return
    if (InStr(flags, "C", true))
        want := 1
    else if (InStr(flags, "c", true))
        want := 0
    else
        return
    Gui, ListView, ManagerAccounts
    LV_GetText(gamePid, row, 3)
    gamePid += 0
    if (!gamePid)
        return
    if (want)
    {
        ; Quét kiểm tra xem người dùng có tích chọn mục nào trong 18 Boss không
        hasAnyBossSelected := false
        Loop, 18 
        {
            if (BossFilters[A_Index] == 1) 
            {
                hasAnyBossSelected := true
                break
            }
        }

        ; Nếu không có mục Boss nào được chọn thì tự động nhả tích nhân vật và báo lỗi
        if (!hasAnyBossSelected)
        {
            ManagerListRebuilding := true
            LV_Modify(row, "-Check")
            ManagerListRebuilding := false
            GuiControl, +cCC0000, ManagerStatusText
            GuiControl,, ManagerStatusText, Hay bat it nhat mot nhom su kien truoc khi tick acc.
            return
        }
    }
    ManagerDesiredWorkers[gamePid] := want
    SaveManagerEnabledCharacters()
    GuiControl, +c0066CC, ManagerStatusText
    GuiControl,, ManagerStatusText, % want ? "Dang bat auto cho PID " . gamePid . "..." : "Dang dung auto cho PID " . gamePid . "..."
    ReconcileManagerWorkers()
}


HandleManagerComboToggle(eventKind, flags, row)
{
    global ManagerListRebuilding, ManagerComboSelectedPid, ManagerComboSelectedCharacter
    global ManagerComboDesiredPid, ManagerComboDesiredCharacter, SettingsRegKey
    if (ManagerListRebuilding || eventKind != "I" || !row)
        return
    if (InStr(flags, "C", true))
        checked := 1
    else if (InStr(flags, "c", true))
        checked := 0
    else
        return
    Gui, ListView, ManagerComboAccounts
    LV_GetText(gamePid, row, 3)
    LV_GetText(character, row, 2)
    gamePid += 0
    if (!gamePid)
        return
    if (checked)
    {
        ManagerListRebuilding := true
        other := 0
        while (other := LV_GetNext(other, "Checked"))
            if (other != row)
                LV_Modify(other, "-Check")
        ManagerListRebuilding := false
        comboWasDesired := (ManagerComboDesiredCharacter != "")
        ManagerComboSelectedPid := gamePid
        ManagerComboSelectedCharacter := character
        ; If combo is already on, moving the single check mark transfers it to
        ; the newly selected character automatically; no extra Ctrl+F2 press.
        if (comboWasDesired)
        {
            ManagerComboDesiredPid := gamePid
            ManagerComboDesiredCharacter := character
        }
        RegWrite, REG_SZ, HKEY_CURRENT_USER, %SettingsRegKey%, ComboCharacter, %character%
    }
    else if (ManagerComboSelectedPid = gamePid)
    {
        ManagerComboDesiredPid := 0
        ManagerComboDesiredCharacter := ""
        ManagerComboSelectedPid := 0
        ManagerComboSelectedCharacter := ""
        RegWrite, REG_SZ, HKEY_CURRENT_USER, %SettingsRegKey%, ComboCharacter,
    }
    ReconcileManagerWorkers()
    UpdateManagerComboStatus()
}

ComboClassToId(comboClass)
{
    classes := {"DW":1, "DK":2, "ELF":3, "RF":4, "SUM":5, "DL":6, "MG":7
        , "AUTO HP":8, "DK V1":9}
    return classes.HasKey(comboClass) ? classes[comboClass] : 0
}

ComboIdToClass(classId)
{
    classes := ["DW", "DK", "ELF", "RF", "SUM", "DL", "MG", "AUTO HP", "DK V1"]
    return (classId >= 1 && classId <= classes.Length()) ? classes[classId] : ""
}

HandleManagerComboClassChanged()
{
    global ManagerComboClass, ManagerComboSpeedPercent
    global SavedComboClass, SavedComboSpeedPercent, SettingsRegKey
    GuiControlGet, selectedClass,, ManagerComboClassChoice
    if (!IsValidComboClass(selectedClass))
        return
    ManagerComboClass := selectedClass
    SavedComboClass := selectedClass
    ManagerComboSpeedPercent := ReadComboSpeedSetting(selectedClass)
    SavedComboSpeedPercent := ManagerComboSpeedPercent
    GuiControl,, ManagerComboSpeedSlider, %ManagerComboSpeedPercent%
    GuiControl,, ManagerComboSpeedText, % ManagerComboSpeedPercent . "%"
    RegWrite, REG_SZ, HKEY_CURRENT_USER, %SettingsRegKey%, ComboClass, %selectedClass%
    NotifyManagerWorkersSettingsChanged()
    ReconcileManagerWorkers()
    UpdateManagerComboStatus()
}

HandleManagerComboSpeedChanged()
{
    global ManagerComboClass, ManagerComboSpeedPercent, SavedComboSpeedPercent
    GuiControlGet, requestedSpeed,, ManagerComboSpeedSlider
    requestedSpeed := NormalizeComboSpeed(requestedSpeed, ManagerComboSpeedPercent)
    ManagerComboSpeedPercent := SaveComboSpeedSetting(ManagerComboClass, requestedSpeed)
    SavedComboSpeedPercent := ManagerComboSpeedPercent
    GuiControl,, ManagerComboSpeedSlider, %ManagerComboSpeedPercent%
    GuiControl,, ManagerComboSpeedText, % ManagerComboSpeedPercent . "%"
    NotifyManagerWorkersSettingsChanged()
    UpdateManagerComboStatus()
}

ToggleManagerCombo()
{
    global ManagerComboSelectedPid, ManagerComboSelectedCharacter, ManagerComboClass
    global ManagerComboDesiredPid, ManagerComboDesiredCharacter
    if (ManagerComboDesiredCharacter != "")
    {
        ManagerComboDesiredPid := 0
        ManagerComboDesiredCharacter := ""
        ReconcileManagerWorkers()
        UpdateManagerComboStatus()
        return true
    }
    if (!ManagerComboSelectedPid)
    {
        GuiControl, +cCC0000, ManagerComboStatusText
        GuiControl,, ManagerComboStatusText, Hay tick dung 1 nhan vat trong tab AUTO COMBO.
        return false
    }
    classId := ComboClassToId(ManagerComboClass)
    if (!classId)
        return false
    ManagerComboDesiredPid := ManagerComboSelectedPid
    ManagerComboDesiredCharacter := ManagerComboSelectedCharacter
    ReconcileManagerWorkers()
    UpdateManagerComboStatus()
    return true
}

UpdateManagerComboStatus()
{
    global ManagerComboSelectedPid, ManagerComboSelectedCharacter
    global ManagerComboDesiredPid, ManagerComboDesiredCharacter, ManagerComboClass
    global ManagerComboSpeedPercent
    global ManagerComboObservedPid, ManagerComboObservedClass
    if (ManagerComboDesiredCharacter != "")
    {
        if (ManagerComboDesiredPid && ManagerComboObservedPid = ManagerComboDesiredPid
            && ManagerComboObservedClass = ManagerComboClass)
        {
            GuiControl, +c008000, ManagerComboStatusText
            GuiControl,, ManagerComboStatusText, % "Combo DANG CHAY: " . ManagerComboDesiredCharacter
                . " | Class " . ManagerComboClass . " | Speed " . ManagerComboSpeedPercent
                . "% | Ctrl+F2 de dung."
        }
        else
        {
            GuiControl, +c0066CC, ManagerComboStatusText
            stateText := ManagerComboDesiredPid ? "DANG KHOI DONG" : "DANG CHO NHAN VAT MO LAI"
            GuiControl,, ManagerComboStatusText, % "Combo " . stateText . ": "
                . ManagerComboDesiredCharacter . " | Class " . ManagerComboClass
                . " | Speed " . ManagerComboSpeedPercent . "%"
        }
    }
    else if (ManagerComboSelectedCharacter != "")
    {
        GuiControl, +c666666, ManagerComboStatusText
        GuiControl,, ManagerComboStatusText, % "Da chon " . ManagerComboSelectedCharacter
            . " | Class " . ManagerComboClass . " | Speed " . ManagerComboSpeedPercent
            . "% | Ctrl+F2 de bat."
    }
    else
    {
        GuiControl, +c666666, ManagerComboStatusText
        GuiControl,, ManagerComboStatusText, Chon 1 nhan vat, chon class, sau do bam Ctrl+F2.
    }
}

SendWorkerCommand(gamePid, commandId, argument := 0)
{
    global WorkerCommandMessage
    hwnd := FindWorkerWindow(gamePid)
    if (!hwnd)
        return false
    PostMessage, %WorkerCommandMessage%, %commandId%, %argument%,, ahk_id %hwnd%
    return true
}

LaunchManagerWorker(gamePid, startHunt, startCombo := false)
{
    global SkipAdminForTest, ManagerWorkerLaunchTick, ManagerComboClass
    GuiControlGet, singleBoss,, ManagerHuntSingleBoss
    GuiControlGet, multiBoss,, ManagerHuntMultiBoss
    GuiControlGet, autoTravel,, ManagerAutoTravel
    Process, Exist, %gamePid%
    if (ErrorLevel != gamePid)
        return false
    args := " --worker-pid=" . gamePid . " --single=" . (singleBoss ? 1 : 0)
        . " --multi=" . (multiBoss ? 1 : 0) . " --travel=" . (autoTravel ? 1 : 0)
    if (startHunt)
        args .= " --worker-autostart"
    if (startCombo)
        args .= " --combo-autostart --combo-class-id=" . ComboClassToId(ManagerComboClass)
    if (SkipAdminForTest)
        args .= " --no-admin-test"
    quote := Chr(34)
    command := A_IsCompiled
        ? (quote . A_ScriptFullPath . quote . args)
        : (quote . A_AhkPath . quote . " " . quote . A_ScriptFullPath . quote . args)
    Run, %command%, %A_ScriptDir%, Hide UseErrorLevel, workerPid
    if (ErrorLevel)
        return false
    ManagerWorkerLaunchTick[gamePid] := A_TickCount
    return true
}

ReconcileManagerWorkers()
{
    global ManagerMode, ManagerReconcileBusy, ManagerDesiredWorkers
    global ManagerWorkerLaunchTick, ManagerComboDesiredPid
    global ManagerComboDesiredCharacter, ManagerComboClass
    if (!ManagerMode || ManagerReconcileBusy)
        return
    ManagerReconcileBusy := true
    for gamePid, huntWanted in ManagerDesiredWorkers
    {
        comboWanted := (ManagerComboDesiredCharacter != "" && ManagerComboDesiredPid = gamePid)
        workerHwnd := FindWorkerWindow(gamePid)
        if (!workerHwnd)
        {
            lastLaunch := ManagerWorkerLaunchTick.HasKey(gamePid) ? ManagerWorkerLaunchTick[gamePid] : 0
            if ((huntWanted || comboWanted) && (!lastLaunch || A_TickCount - lastLaunch > 5000))
                LaunchManagerWorker(gamePid, huntWanted, comboWanted)
            continue
        }
        ManagerWorkerLaunchTick.Delete(gamePid)
        GetWorkerModuleState(workerHwnd, huntOn, comboClass, workerState)
        ; STARTING publishes HUNT=OFF. A stop must still be posted so the worker
        ; can cancel its armed retry timer immediately.
        if (workerState = "STARTING" && !huntWanted)
            SendWorkerCommand(gamePid, 2, 0)
        else if (huntWanted != huntOn && workerState != "STARTING")
            SendWorkerCommand(gamePid, huntWanted ? 1 : 2, 0)
        if (comboWanted)
        {
            if (comboClass != ManagerComboClass)
                SendWorkerCommand(gamePid, 3, ComboClassToId(ManagerComboClass))
        }
        else if (comboClass != "OFF")
            SendWorkerCommand(gamePid, 4, 0)
    }
    ManagerReconcileBusy := false
}

SetAllManagerHuntDesired(enable)
{
    global ManagerAccountRows, ManagerDesiredWorkers, ManagerListRebuilding
    if (enable)
    {
        ; Quét kiểm tra xem người dùng có tích chọn mục nào trong 18 Boss không
        hasAnyBossSelected := false
        Loop, 18 
        {
            if (BossFilters[A_Index] == 1) 
            {
                hasAnyBossSelected := true
                break
            }
        }
        
        ; Nếu không có mục Boss nào được chọn thì tiến hành báo lỗi và chặn lại
        if (!hasAnyBossSelected)
        {
            GuiControl, +cCC0000, ManagerStatusText
            GuiControl,, ManagerStatusText, Hay bat it nhat mot nhom su kien truoc khi tick acc.
            return false
        }
    }

    ManagerListRebuilding := true
    Gui, ListView, ManagerAccounts
    row := 0
    for _, account in ManagerAccountRows
    {
        row += 1
        ManagerDesiredWorkers[account.pid] := enable ? 1 : 0
        LV_Modify(row, enable ? "Check" : "-Check")
    }
    ManagerListRebuilding := false
    SaveManagerEnabledCharacters()
    ReconcileManagerWorkers()
    return true
}

StartSelectedManagerWorkers()
{
    if (SetAllManagerHuntDesired(true))
    {
        GuiControl,, ManagerStatusText, Da tick tat ca; tool dang bat auto tung acc.
        return true
    }
    return false
}

StopSelectedManagerWorkers()
{
    SetAllManagerHuntDesired(false)
    GuiControl,, ManagerStatusText, Da bo tick tat ca; tool dang dung auto tung acc.
    return true
}

AnySelectedManagerWorkerRunning()
{
    global ManagerDesiredWorkers
    for _, desired in ManagerDesiredWorkers
        if (desired)
            return true
    return false
}

ToggleManagerHuntGroup()
{
    global ManagerDesiredWorkers, ManagerCtrlF1Remembered
    global ManagerAccountRows, ManagerListRebuilding
    if (AnySelectedManagerWorkerRunning())
    {
        ManagerCtrlF1Remembered := {}
        for gamePid, desired in ManagerDesiredWorkers
            if (desired)
                ManagerCtrlF1Remembered[gamePid] := 1
        SetAllManagerHuntDesired(false)
        GuiControl,, ManagerStatusText, Ctrl+F1: da tam dung nhom acc dang tick.
        return
    }
    GuiControlGet, singleBoss,, ManagerHuntSingleBoss
    GuiControlGet, multiBoss,, ManagerHuntMultiBoss
    if (!singleBoss && !multiBoss)
    {
        GuiControl, +cCC0000, ManagerStatusText
        GuiControl,, ManagerStatusText, Ctrl+F1: hay bat it nhat mot nhom su kien truoc.
        return
    }
    ManagerListRebuilding := true
    Gui, ListView, ManagerAccounts
    row := 0
    for _, account in ManagerAccountRows
    {
        row += 1
        enable := ManagerCtrlF1Remembered.HasKey(account.pid)
        ManagerDesiredWorkers[account.pid] := enable ? 1 : 0
        LV_Modify(row, enable ? "Check" : "-Check")
    }
    ManagerListRebuilding := false
    if (!ObjectHasAnyKey(ManagerCtrlF1Remembered))
        SetAllManagerHuntDesired(true)
    else
    {
        SaveManagerEnabledCharacters()
        ReconcileManagerWorkers()
    }
    GuiControl,, ManagerStatusText, Ctrl+F1: da khoi phuc nhom acc truoc do.
}

StopAllManagerWorkers()
{
    DetectHiddenWindows, On
    WinGet, workerList, List, MU-PKZ Worker - GamePID
    Loop, %workerList%
    {
        hwnd := workerList%A_Index%
        if (hwnd)
            WinClose, ahk_id %hwnd%
    }
}

ReadPersistentSetting(valueName, fallback)
{
    global SettingsRegKey
    RegRead, value, HKEY_CURRENT_USER, %SettingsRegKey%, %valueName%
    if (ErrorLevel)
        return fallback
    return value
}

NormalizeSavedBool(value, fallback)
{
    if (value = 0 || value = 1)
        return value + 0
    return fallback
}

GetDefaultComboSpeed(comboClass)
{
    ; Jitbit's right-most/MAX position is 1.3^(1-5)=0.350127 delay,
    ; equivalent to 285.61% playback. Every combat macro defaults to MAX;
    ; AUTO HP is the only utility profile that keeps its source timing.
    if (comboClass != "AUTO HP")
        return 286
    return 100
}

NormalizeComboSpeed(value, fallback := 286)
{
    value += 0
    if (value < 50 || value > 600)
        value := fallback + 0
    if (value < 50 || value > 600)
        value := 286
    return Round(value)
}

GetComboSpeedSettingName(comboClass)
{
    return "ComboSpeed_" . StrReplace(comboClass, " ", "_")
}

ReadComboSpeedSetting(comboClass)
{
    settingName := GetComboSpeedSettingName(comboClass)
    fallback := GetDefaultComboSpeed(comboClass)
    return NormalizeComboSpeed(ReadPersistentSetting(settingName, fallback), fallback)
}

SaveComboSpeedSetting(comboClass, speedPercent)
{
    global SettingsRegKey
    speedPercent := NormalizeComboSpeed(speedPercent, GetDefaultComboSpeed(comboClass))
    settingName := GetComboSpeedSettingName(comboClass)
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, %SettingsRegKey%, %settingName%, %speedPercent%
    return speedPercent
}

ApplyMacroProfileRevision()
{
    global SettingsRegKey, CurrentMacroProfileRevision
    installedRevision := ReadPersistentSetting("MacroProfileRevision", 0) + 0
    if (installedRevision >= CurrentMacroProfileRevision)
        return false
    ; The whole class macro set changed in revision 2. Reset each combat
    ; profile exactly once to Jitbit Fast/MAX; later user tuning is preserved.
    for _, comboClass in ["DW", "DK", "DK V1", "ELF", "RF", "SUM", "DL", "MG"]
        SaveComboSpeedSetting(comboClass, 286)
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, %SettingsRegKey%, MacroProfileRevision, %CurrentMacroProfileRevision%
    return true
}

LoadPersistentSettings() {
    global
    ; ... (Các dòng RegRead cũ của bạn giữ nguyên) ...
    RegRead, SavedIsClassDL, HKCU, %SettingsRegKey%, SavedIsClassDL
    if ErrorLevel
        SavedIsClassDL := 0
}
{
    global SavedHuntModuleEnabled, SavedComboModuleEnabled
    global SavedActivePatrol, SavedLootAfterKill, SavedAutoEventTravel
    global SavedHuntSingleBoss, SavedHuntMultiBoss
    global SavedMapEmptySeconds, SavedComboClass, SavedComboSpeedPercent, UiScalePercent
    global ManagerEnabledCharacters, ManagerComboSelectedCharacter, ManagerComboClass
    global ManagerComboSpeedPercent, ComboPlaybackSpeedPercent

    ApplyMacroProfileRevision()
    SavedHuntModuleEnabled := NormalizeSavedBool(ReadPersistentSetting("HuntModuleEnabled", SavedHuntModuleEnabled), SavedHuntModuleEnabled)
    SavedComboModuleEnabled := NormalizeSavedBool(ReadPersistentSetting("ComboModuleEnabled", SavedComboModuleEnabled), SavedComboModuleEnabled)
    SavedActivePatrol := NormalizeSavedBool(ReadPersistentSetting("ActivePatrol", SavedActivePatrol), SavedActivePatrol)
    SavedLootAfterKill := NormalizeSavedBool(ReadPersistentSetting("LootAfterKill", SavedLootAfterKill), SavedLootAfterKill)
    SavedAutoEventTravel := NormalizeSavedBool(ReadPersistentSetting("AutoEventTravel", SavedAutoEventTravel), SavedAutoEventTravel)
    SavedHuntSingleBoss := NormalizeSavedBool(ReadPersistentSetting("HuntSingleBoss", SavedHuntSingleBoss), SavedHuntSingleBoss)
    SavedHuntMultiBoss := NormalizeSavedBool(ReadPersistentSetting("HuntMultiBoss", SavedHuntMultiBoss), SavedHuntMultiBoss)
    UiScalePercent := NormalizeUiScale(ReadPersistentSetting("UiScalePercent", UiScalePercent), 100)

    mapEmpty := ReadPersistentSetting("MapEmptySeconds", SavedMapEmptySeconds) + 0
    if (mapEmpty < 10 || mapEmpty > 300)
        mapEmpty := 15
    SavedMapEmptySeconds := mapEmpty

    comboClass := ReadPersistentSetting("ComboClass", SavedComboClass)
    if (!IsValidComboClass(comboClass))
        comboClass := "DW"
    SavedComboClass := comboClass
    ManagerComboClass := comboClass
    SavedComboSpeedPercent := ReadComboSpeedSetting(comboClass)
    ManagerComboSpeedPercent := SavedComboSpeedPercent
    ComboPlaybackSpeedPercent := SavedComboSpeedPercent
    ManagerEnabledCharacters := ReadPersistentSetting("EnabledCharacters", "*")
    if (ManagerEnabledCharacters = "")
        ManagerEnabledCharacters := "*"
    ManagerComboSelectedCharacter := ReadPersistentSetting("ComboCharacter", "")
}

ApplyPersistentSettings()

; --- CHÈN THÊM ĐOẠN NÀY ĐỂ WORKER NHẬN DIỆN DL ---
RegRead, SavedIsClassDL, HKCU, %SettingsRegKey%, SavedIsClassDL
if !ErrorLevel
    IsClassDL := SavedIsClassDL
; ------------------------------------------------

GuiControl,, HuntEnabled, %SavedHuntModuleEnabled%

{
    global SavedHuntModuleEnabled, SavedComboModuleEnabled
    global SavedActivePatrol, SavedLootAfterKill, SavedAutoEventTravel
    global SavedHuntSingleBoss, SavedHuntMultiBoss
    global SavedMapEmptySeconds, SavedComboClass, SavedComboSpeedPercent, ComboSelectedClass
    global ComboPlaybackSpeedPercent
    global UiScalePercent

    GuiControl,, HuntModuleEnabled, %SavedHuntModuleEnabled%
    GuiControl,, ComboModuleEnabled, %SavedComboModuleEnabled%
    GuiControl,, ActivePatrol, %SavedActivePatrol%
    GuiControl,, LootAfterKill, %SavedLootAfterKill%
    GuiControl,, AutoEventTravel, %SavedAutoEventTravel%
    GuiControl,, HuntSingleBoss, %SavedHuntSingleBoss%
    GuiControl,, HuntMultiBoss, %SavedHuntMultiBoss%
    GuiControl,, MapEmptySeconds, %SavedMapEmptySeconds%
    GuiControl, ChooseString, ComboClassChoice, %SavedComboClass%
    GuiControl,, UiScaleSlider, %UiScalePercent%
    scaleLabel := UiScalePercent . "%"
    GuiControl,, UiScaleValueText, %scaleLabel%
    ComboSelectedClass := SavedComboClass
    ComboPlaybackSpeedPercent := SavedComboSpeedPercent

}

SavePersistentSettings()
{
    global WorkerMode
    global SettingsRegKey
    global SavedHuntModuleEnabled, SavedComboModuleEnabled
    global SavedActivePatrol, SavedLootAfterKill, SavedAutoEventTravel
    global SavedHuntSingleBoss, SavedHuntMultiBoss
    global SavedMapEmptySeconds, SavedComboClass, UiScalePercent

    if (WorkerMode)
        return true

    ; If shutdown occurs before GUI creation, preserve the existing Registry
    ; values rather than overwriting them with blank control reads.
    GuiControlGet, comboClass,, ComboClassChoice
    if (ErrorLevel)
        return false
    if (!IsValidComboClass(comboClass))
        comboClass := IsValidComboClass(SavedComboClass) ? SavedComboClass : "DW"

    GuiControlGet, huntModule,, HuntModuleEnabled
    GuiControlGet, comboModule,, ComboModuleEnabled
    GuiControlGet, activePatrol,, ActivePatrol
    GuiControlGet, lootAfterKill,, LootAfterKill
    GuiControlGet, autoEventTravel,, AutoEventTravel
    GuiControlGet, huntSingleBoss,, HuntSingleBoss
    GuiControlGet, huntMultiBoss,, HuntMultiBoss
    GuiControlGet, mapEmpty,, MapEmptySeconds
    GuiControlGet, selectedUiScale,, UiScaleSlider
    selectedUiScale := NormalizeUiScale(selectedUiScale, UiScalePercent)
    mapEmpty += 0
    if (mapEmpty < 10 || mapEmpty > 300)
        mapEmpty := SavedMapEmptySeconds

    huntModule := huntModule ? 1 : 0
    comboModule := comboModule ? 1 : 0
    activePatrol := activePatrol ? 1 : 0
    lootAfterKill := lootAfterKill ? 1 : 0
    autoEventTravel := autoEventTravel ? 1 : 0
    huntSingleBoss := huntSingleBoss ? 1 : 0
    huntMultiBoss := huntMultiBoss ? 1 : 0

    RegWrite, REG_DWORD, HKEY_CURRENT_USER, %SettingsRegKey%, HuntModuleEnabled, %huntModule%
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, %SettingsRegKey%, ComboModuleEnabled, %comboModule%
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, %SettingsRegKey%, ActivePatrol, %activePatrol%
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, %SettingsRegKey%, LootAfterKill, %lootAfterKill%
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, %SettingsRegKey%, AutoEventTravel, %autoEventTravel%
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, %SettingsRegKey%, HuntSingleBoss, %huntSingleBoss%
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, %SettingsRegKey%, HuntMultiBoss, %huntMultiBoss%
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, %SettingsRegKey%, MapEmptySeconds, %mapEmpty%
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, %SettingsRegKey%, UiScalePercent, %selectedUiScale%
    RegWrite, REG_SZ, HKEY_CURRENT_USER, %SettingsRegKey%, ComboClass, %comboClass%

    SavedHuntModuleEnabled := huntModule
    SavedComboModuleEnabled := comboModule
    SavedActivePatrol := activePatrol
    SavedLootAfterKill := lootAfterKill
    SavedAutoEventTravel := autoEventTravel
    SavedHuntSingleBoss := huntSingleBoss
    SavedHuntMultiBoss := huntMultiBoss
    SavedMapEmptySeconds := mapEmpty
    SavedComboClass := comboClass
    UiScalePercent := selectedUiScale
    return true
}

; ========== PROCESS ATTACH/DETACH ==========
AttachToEngine(showError := true)
{
    global hProcess, GamePid, GameHwnd, WorkerMode, WorkerTargetPid
    if (!DetachEngine())
    {
        SetStatus("Remote call cu van dang chay; chua the gan lai an toan.", "CC0000")
        return false
    }
    if (WorkerMode && WorkerTargetPid)
    {
        Process, Exist, %WorkerTargetPid%
        GamePid := (ErrorLevel = WorkerTargetPid) ? WorkerTargetPid : 0
    }
    else
    {
        Process, Exist, Engine.exe
        GamePid := ErrorLevel
    }
    if (!GamePid)
    {
        SetStatus("Khong tim thay Engine.exe.", "CC0000")
        return false
    }
    ; QUERY_INFORMATION | CREATE_THREAD | VM_OPERATION | VM_READ | VM_WRITE.
    ; Remote calls are limited to the client's own MU Helper methods.
    hProcess := DllCall("OpenProcess", "UInt", 0x043A, "Int", 0, "UInt", GamePid, "Ptr")
    if (!hProcess)
    {
        SetStatus("Khong mo duoc process. Hay chay bang Admin.", "CC0000")
        return false
    }
    GameHwnd := FindGameWindowForPid(GamePid)
    if (!GameHwnd)
    {
        SetStatus("Khong tim thay cua so Engine.exe.", "CC0000")
        DetachEngine()
        return false
    }
    GuiControl,, ProcessText, Engine.exe: PID %GamePid% - da gan
    SetStatus("Da gan thanh cong. San boss dung scanner + pathfinder MU Helper.", "008000")
    return true
}

EnsureAttached()
{
    global hProcess
    return hProcess ? true : AttachToEngine(true)
}

DetachEngine(forceClose := false)
{
    global hProcess, GamePid, CharactersBase, HeroPtr, CharacterStride
    global GameHwnd, CurrentTarget, HuntWaitUntil, LootUntil, LootActive
    global BuiltinMode, BuiltinHelperBase, BuiltinWasActiveAtStart, BuiltinConfigSnapshotReady
    global HuntGeneration, RemoteCallBusy, RemotePendingThread, RemotePendingBuffer
    global HelperCleanupFault, HuntSessionActive, ComboRunning
    HuntSessionActive := false
    ComboRunning := false
    ReleaseTargetClaim()
    ReleaseAllComboKeys()
    HuntGeneration += 1
    GuiControl,, HuntEnabled, 0
    if (hProcess)
    {
        pendingStillRunning := false
        if (RemotePendingThread)
        {
            waitResult := DllCall("Kernel32\WaitForSingleObject", "Ptr", RemotePendingThread
                , "UInt", forceClose ? 2500 : 1500, "UInt")
            if (waitResult != 0 && !forceClose)
            {
                HelperCleanupFault := true
                SetStatus("Remote pathfinder cu chua ket thuc; khong gan lai de tranh chay chong.", "CC0000")
                GuiControl, Disable, StartHuntButton
                GuiControl, Disable, StopHuntButton
                return false
            }
            if (waitResult = 0)
            {
                if (RemotePendingBuffer)
                    DllCall("Kernel32\VirtualFreeEx", "Ptr", hProcess, "Ptr", RemotePendingBuffer
                        , "UPtr", 0, "UInt", 0x8000)
            }
            else
                pendingStillRunning := true
            DllCall("Kernel32\CloseHandle", "Ptr", RemotePendingThread)
            RemotePendingThread := 0
            RemotePendingBuffer := 0
            RemoteCallBusy := false
        }
        cleanupOk := true
        if (!pendingStillRunning && (BuiltinMode != "" || BuiltinConfigSnapshotReady))
            cleanupOk := PrepareNativeMovement()
        if (!cleanupOk && !forceClose)
        {
            HelperCleanupFault := true
            SetStatus("Khong cleanup duoc MU Helper; giu ket noi cu de tranh mat trang thai.", "CC0000")
            GuiControl, Disable, StartHuntButton
            GuiControl, Disable, StopHuntButton
            return false
        }
        restoreActiveOk := true
        if (!pendingStillRunning && cleanupOk && BuiltinWasActiveAtStart)
        {
            restoreActiveOk := ReadBuiltinHelperActive(helperActive)
            if (restoreActiveOk && !helperActive)
                restoreActiveOk := StartBuiltinHelper()
        }
        if (!restoreActiveOk && !forceClose)
        {
            HelperCleanupFault := true
            SetStatus("Da khoi phuc config nhung chua bat lai duoc MU Helper; se thu lai.", "CC0000")
            GuiControl, Disable, StartHuntButton
            GuiControl, Disable, StopHuntButton
            return false
        }
        DllCall("CloseHandle", "Ptr", hProcess)
    }
    hProcess := 0, GamePid := 0
    CharactersBase := 0, HeroPtr := 0, CharacterStride := 0, GameHwnd := 0
    CurrentTarget := -1, CurrentTargetMonsterIndex := -1
    HuntWaitUntil := 0, LootUntil := 0
    LootActive := false
    BuiltinMode := ""
    BuiltinWasActiveAtStart := false
    BuiltinConfigSnapshotReady := false
    RemotePendingThread := 0
    RemotePendingBuffer := 0
    RemoteCallBusy := false
    HelperCleanupFault := false
    GuiControl, Enable, StartHuntButton
    GuiControl, Disable, StopHuntButton
    GuiControl,, ProcessText, Engine.exe: chua gan
    return true
}

ResolveCharacterMemory()
{
    global CharactersBase, HeroPtr, CharacterStride, GameHwnd, GamePid
    global CharactersPointerAddress, HeroPointerAddress
    if (!ReadDword(CharactersPointerAddress, base) || !ReadDword(HeroPointerAddress, hero))
        return false
    if (base < 0x10000 || hero < base)
        return false
    CharacterStride := 0
    for _, stride in [0x5E8, 0x594, 0x580]
    {
        delta := hero - base
        index := Floor(delta / stride)
        if (Mod(delta, stride) = 0 && index >= 0 && index < 400)
        {
            CharacterStride := stride
            break
        }
    }
    if (!CharacterStride)
        return false
    CharactersBase := base
    HeroPtr := hero
    GameHwnd := FindGameWindowForPid(GamePid)
    if (!GameHwnd)
        return false
    if (!ReadByte(HeroPtr + 0x39E, heroKind) || heroKind != 1)
        return false
    return true
}

; ========== MONSTER SCANNING ========== 
RefreshWorkerRoster(force := false)
{
    global WorkerMode, WorkerTargetPid, WorkerRosterSlot, WorkerRosterCount
    global WorkerRosterRefreshTick, WorkerRosterScope, CurrentEventRow
    if (!WorkerMode)
    {
        WorkerRosterSlot := 1, WorkerRosterCount := 1, WorkerRosterScope := ""
        return false
    }
    currentMap := -1
    mapKnown := GetCurrentMapId(currentMap)
    currentScope := mapKnown ? ("M" . currentMap . ":E" . CurrentEventRow)
        : ("UNKNOWN:" . WorkerTargetPid)
    if (!force && currentScope = WorkerRosterScope && WorkerRosterRefreshTick
        && A_TickCount - WorkerRosterRefreshTick < 2000)
        return false
    oldSlot := WorkerRosterSlot
    oldCount := WorkerRosterCount
    oldScope := WorkerRosterScope
    WorkerRosterRefreshTick := A_TickCount
    seen := {}, pidText := ""
    if (mapKnown)
    {
        DetectHiddenWindows, On
        WinGet, workerList, List, MU-PKZ Worker - GamePID
        Loop, %workerList%
        {
            hwnd := workerList%A_Index%
            WinGetTitle, title, ahk_id %hwnd%
            if (!RegExMatch(title, "^MU-PKZ Worker - GamePID (\d+)", pidMatch)
                || !InStr(title, "HUNT=ON")
                || !RegExMatch(title, "i) - MAP=(-?\d+) - EVENT=(\d+)", scopeMatch)
                || scopeMatch1 + 0 != currentMap
                || scopeMatch2 + 0 != CurrentEventRow
                || seen.HasKey(pidMatch1 + 0))
                continue
            seen[pidMatch1 + 0] := true
            pidText .= (pidMatch1 + 0) . "`n"
        }
    }
    if (!seen.HasKey(WorkerTargetPid))
        pidText .= WorkerTargetPid . "`n"
    Sort, pidText, N U
    count := 0, slot := 1
    Loop, Parse, pidText, `n, `r
    {
        if (A_LoopField = "")
            continue
        count += 1
        if (A_LoopField + 0 = WorkerTargetPid)
            slot := count
    }
    WorkerRosterCount := Max(1, count)
    WorkerRosterSlot := slot
    WorkerRosterScope := currentScope
    changed := (oldSlot != WorkerRosterSlot || oldCount != WorkerRosterCount
        || oldScope != WorkerRosterScope)
    if (changed)
        ResetPatrolRoute()
    return changed
}

IsPatrolSectorAssignedToThisWorker(col, row)
{
    global WorkerRosterSlot, WorkerRosterCount
    if (WorkerRosterCount <= 1)
        return true
    return (Mod(row * 13 + col, WorkerRosterCount) = WorkerRosterSlot - 1)
}

BuildTargetMutexName(kind, mapId, value1, value2 := 0)
{
    global CurrentEventRow
    return "Local\MU-PKZ.AutoHunt.Target." . kind . ".M" . mapId . ".E" . CurrentEventRow
        . "." . value1 . (kind = "C" ? ("_" . value2) : "")
}

IsNamedTargetMutexOwned(name)
{
    handle := DllCall("Kernel32\OpenMutexW", "UInt", 0x100001, "Int", 0, "WStr", name, "Ptr")
    if (!handle)
        return false
    waitResult := DllCall("Kernel32\WaitForSingleObject", "Ptr", handle, "UInt", 0, "UInt")
    owned := (waitResult = 0x102)
    if (waitResult = 0 || waitResult = 0x80)
        DllCall("Kernel32\ReleaseMutex", "Ptr", handle)
    DllCall("Kernel32\CloseHandle", "Ptr", handle)
    return owned
}

IsTargetClaimedByPeer(objectKey, monsterX, monsterY)
{
    global TargetClaimCellSize
    if (!GetCurrentMapId(mapId))
        mapId := -1
    if (objectKey > 0
        && IsNamedTargetMutexOwned(BuildTargetMutexName("K", mapId, objectKey)))
        return true
    cellX := Floor(monsterX / TargetClaimCellSize)
    cellY := Floor(monsterY / TargetClaimCellSize)
    return IsNamedTargetMutexOwned(BuildTargetMutexName("C", mapId, cellX, cellY))
}

AcquireNamedTargetMutex(name, ByRef handles)
{
    handle := DllCall("Kernel32\CreateMutexW", "Ptr", 0, "Int", 1, "WStr", name, "Ptr")
    createError := A_LastError
    if (!handle)
        return false
    if (createError = 183)
    {
        waitResult := DllCall("Kernel32\WaitForSingleObject", "Ptr", handle, "UInt", 0, "UInt")
        if (waitResult != 0 && waitResult != 0x80)
        {
            DllCall("Kernel32\CloseHandle", "Ptr", handle)
            return false
        }
    }
    handles.Push(handle)
    return true
}

ReleaseTargetClaim()
{
    global TargetClaimHandles, TargetClaimKey, TargetClaimX, TargetClaimY
    if (IsObject(TargetClaimHandles))
    {
        for _, handle in TargetClaimHandles
        {
            if (handle)
            {
                DllCall("Kernel32\ReleaseMutex", "Ptr", handle)
                DllCall("Kernel32\CloseHandle", "Ptr", handle)
            }
        }
    }
    TargetClaimHandles := []
    TargetClaimKey := ""
    TargetClaimX := -1, TargetClaimY := -1
}

AcquireTargetClaim(characterIndex)
{
    global CharactersBase, CharacterStride, TargetClaimHandles
    global TargetClaimKey, TargetClaimX, TargetClaimY, TargetClaimCellSize
    if (characterIndex < 0 || !CharactersBase || !CharacterStride)
        return false
    address := CharactersBase + characterIndex * CharacterStride
    if (!ReadWord(address + 0x76, objectKey)
        || !ReadWord(address + 0x7C, monsterIndex)
        || !ReadInt(address + 0xA8, monsterX) || !ReadInt(address + 0xAC, monsterY))
        return false
    if (!GetCurrentMapId(mapId))
        mapId := -1
    names := []
    if (objectKey > 0)
        names.Push(BuildTargetMutexName("K", mapId, objectKey))
    cellX := Floor(monsterX / TargetClaimCellSize)
    cellY := Floor(monsterY / TargetClaimCellSize)
    dy := -1
    while (dy <= 1)
    {
        dx := -1
        while (dx <= 1)
        {
            names.Push(BuildTargetMutexName("C", mapId, cellX + dx, cellY + dy))
            dx += 1
        }
        dy += 1
    }
    ReleaseTargetClaim()
    acquired := []
    for _, name in names
    {
        if (!AcquireNamedTargetMutex(name, acquired))
        {
            for _, handle in acquired
            {
                DllCall("Kernel32\ReleaseMutex", "Ptr", handle)
                DllCall("Kernel32\CloseHandle", "Ptr", handle)
            }
            return false
        }
    }
    TargetClaimHandles := acquired
    TargetClaimKey := mapId . ":" . objectKey . ":" . monsterIndex
    TargetClaimX := monsterX, TargetClaimY := monsterY
    return true
}

FindNearestMonster(onlyHonThachBoss := false)
{
    global hProcess, CharactersBase, HeroPtr, CharacterStride
    global CurrentEventRow, AllowedEventTypes, PeerReservedMonsterSeen
    static characterBuffer, allocatedSize := 0
    PeerReservedMonsterSeen := false
    RefreshAllowedEventTypes()
    attackEveryMonster := IsAllMonsterEventMode()
    if (!ReadInt(HeroPtr + 0xA8, heroX) || !ReadInt(HeroPtr + 0xAC, heroY))
        return -1
    if (CurrentEventRow && !onlyHonThachBoss && !attackEveryMonster
        && !ObjectHasAnyKey(AllowedEventTypes))
        return -1
    totalSize := CharacterStride * 400
    if (allocatedSize != totalSize)
    {
        VarSetCapacity(characterBuffer, totalSize, 0)
        allocatedSize := totalSize
    }
    bytesRead := 0
    if (!DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", CharactersBase
        , "Ptr", &characterBuffer, "UPtr", totalSize, "UPtr*", bytesRead)
        || bytesRead != totalSize)
        return -1
    bestIndex := -1
    bestDistance := 0x7FFFFFFF
    Loop, 400
    {
        index := A_Index - 1
        offset := index * CharacterStride
        if (NumGet(characterBuffer, offset + 0x388, "UChar") != 1
            || NumGet(characterBuffer, offset + 0x39E, "UChar") != 2
            || NumGet(characterBuffer, offset + 0x28, "UChar") != 0)
            continue
        monsterIndex := NumGet(characterBuffer, offset + 0x7C, "UShort")
        if (onlyHonThachBoss && monsterIndex != 700)
            continue
        if (CurrentEventRow && !onlyHonThachBoss && !attackEveryMonster
            && !AllowedEventTypes.HasKey(monsterIndex))
            continue
        monsterX := NumGet(characterBuffer, offset + 0xA8, "Int")
        monsterY := NumGet(characterBuffer, offset + 0xAC, "Int")
        objectKey := NumGet(characterBuffer, offset + 0x76, "UShort")
        if (IsTargetClaimedByPeer(objectKey, monsterX, monsterY))
        {
            PeerReservedMonsterSeen := true
            continue
        }
        dx := monsterX - heroX
        dy := monsterY - heroY
        distance := dx * dx + dy * dy
        if (distance < bestDistance)
        {
            bestDistance := distance
            bestIndex := index
        }
    }
    return bestIndex
}

IsMonsterAlive(index, requireVisible := false)
{
    global CharactersBase, CharacterStride
    if (index < 0 || index >= 400 || !CharactersBase || !CharacterStride)
        return false
    address := CharactersBase + index * CharacterStride
    if (!ReadByte(address + 0x388, live) || live != 1)
        return false
    if (!ReadByte(address + 0x39E, kind) || kind != 2)
        return false
    if (!ReadByte(address + 0x28, dead) || dead != 0)
        return false
    if (!IsAllowedMonsterForMap(address))
        return false
    if (requireVisible)
    {
        if (!ReadByte(address + 0x391, visible) || visible != 1)
            return false
        if (!GetMonsterScreenPosition(index, sx, sy))
            return false
    }
    return true
}

IsConfirmedTargetDeath(index, countAtSelection)
{
    global CharactersBase, CharacterStride, OrdinaryEventBase, CurrentEventRow
    if (index >= 0 && index < 400)
    {
        address := CharactersBase + index * CharacterStride
        if (ReadByte(address + 0x28, dead) && dead != 0)
            return true
    }
    if (CurrentEventRow && OrdinaryEventBase && countAtSelection > 0)
    {
        if (GetAllowedEventRemainingCount(CurrentEventRow, currentCount)
            && currentCount < countAtSelection)
            return true
    }
    return false
}

GetAllowedEventRemainingCount(row, ByRef remaining)
{
    global OrdinaryEventBase, AllowedEventTypes, AllowedEventTypesRow
    remaining := -1
    if (!row || !OrdinaryEventBase)
        return false
    if (AllowedEventTypesRow != row || !ObjectHasAnyKey(AllowedEventTypes))
        RefreshAllowedEventTypes(true)
    if (!ObjectHasAnyKey(AllowedEventTypes))
        return false

    eventAddress := OrdinaryEventBase + (row - 1) * 0x90
    if (ReadInt(eventAddress + 0x3C, typeCount) && typeCount > 0 && typeCount <= 16)
    {
        total := 0, matched := false
        Loop, %typeCount%
        {
            pair := eventAddress + 0x40 + (A_Index - 1) * 8
            if (!ReadInt(pair, monsterIndex) || !ReadInt(pair + 4, count))
                continue
            if (monsterIndex >= 0 && monsterIndex <= 2000
                && AllowedEventTypes.HasKey(monsterIndex))
            {
                total += Max(0, count)
                matched := true
            }
        }
        if (matched)
        {
            remaining := total
            return true
        }
    }

    ; The row total is safe as a fallback except Lorencia, where the event can
    ; include Orcs but the requested target is White Wizard only.
    if (row != 2 && ReadInt(eventAddress + 0x34, totalCount))
    {
        remaining := Max(0, totalCount)
        return true
    }
    return false
}

RefreshAllowedEventTypes(force := false)
{
    global CurrentEventRow, OrdinaryEventBase
    global AllowedEventTypes, AllowedEventTypesRow, AllowedEventTypesRefreshTick

    if (!CurrentEventRow || !OrdinaryEventBase)
    {
        AllowedEventTypes := {}
        AllowedEventTypesRow := 0
        AllowedEventTypesRefreshTick := A_TickCount
        return false
    }
    if (!force && AllowedEventTypesRow = CurrentEventRow
        && A_TickCount - AllowedEventTypesRefreshTick < 1000)
        return ObjectHasAnyKey(AllowedEventTypes)

    types := {}
    eventAddress := OrdinaryEventBase + (CurrentEventRow - 1) * 0x90
    if (ReadInt(eventAddress + 0x3C, typeCount) && typeCount > 0 && typeCount <= 16)
    {
        Loop, %typeCount%
        {
            if (ReadInt(eventAddress + 0x40 + (A_Index - 1) * 8, monsterIndex))
            {
                if (monsterIndex >= 0 && monsterIndex <= 2000)
                    types[monsterIndex] := true
            }
        }
    }
    if (!ObjectHasAnyKey(types) && ReadInt(eventAddress + 0x38, monsterIndex))
    {
        if (monsterIndex >= 0 && monsterIndex <= 2000)
            types[monsterIndex] := true
    }
    if (!ObjectHasAnyKey(types))
    {
        fallback := GetFallbackEventMonsterIndices(CurrentEventRow)
        for _, monsterIndex in fallback
        {
            if (monsterIndex >= 0 && monsterIndex <= 2000)
                types[monsterIndex] := true
        }
    }
    ; Yeu cau rieng tai Lorencia: bo qua Orc/monster phu neu event co khai
    ; bao nhieu loai; chi san dung Phu Thuy Trang (MonsterIndex 135).
    if (CurrentEventRow = 2)
    {
        types := {}
        types[135] := true
    }
    AllowedEventTypes := types
    AllowedEventTypesRow := CurrentEventRow
    AllowedEventTypesRefreshTick := A_TickCount
    return ObjectHasAnyKey(AllowedEventTypes)
}

GetFallbackEventMonsterIndices(row)
{
    if (row = 2)
        return [135]
    if (row = 5)
        return [413]
    if (row = 6)
        return [463]
    if (row = 7)
        return [720]
    if (row = 9)
        return [724, 725]
    if (row = 10)
        return [723]
    if (row = 11)
        return [722]
    if (row = 12)
        return [721]
    if (row = 13)
        return [717]
    if (row = 14)
        return [713]
    if (row = 15)
        return [712]
    if (row = 16)
        return [709]
    if (row = 17)
        return [700]
    if (row = 18)
        return [719]
    return []
}

ObjectHasAnyKey(object)
{
    if (!IsObject(object))
        return false
    for _, value in object
        return true
    return false
}

IsAllMonsterEventMode()
{
    global CurrentEventRow
    ; Kho Bau/Long Vuong o Atlans va Hon Thach deu can diet moi object kind=2
    ; dang song trong map, ke ca ruong quai va monster thuong.
    return (CurrentEventRow = 9 || CurrentEventRow = 16 || CurrentEventRow = 17)
}

IsAllowedMonsterForMap(address)
{
    global CurrentEventRow, AllowedEventTypes
    if (!CurrentEventRow || IsAllMonsterEventMode())
        return true
    ; Character + 0x7C is the authoritative raw MonsterIndex sent by the
    ; server. Object.Type is a client model slot and is not a stable mapping
    ; for custom monsters in this build.
    if (!ReadWord(address + 0x7C, monsterIndex))
        return false
    if (!ObjectHasAnyKey(AllowedEventTypes))
        RefreshAllowedEventTypes(true)
    return ObjectHasAnyKey(AllowedEventTypes)
        ? AllowedEventTypes.HasKey(monsterIndex) : false
}

GetCurrentMapId(ByRef mapId)
{
    global GameHwnd
    if (!GameHwnd)
        return false
    WinGetTitle, title, ahk_id %GameHwnd%
    if (!RegExMatch(title, "i)MapID\s*:\s*(\d+)", match))
        return false
    mapId := match1 + 0
    return true
}

; ========== ACTIVE PATROL SYSTEM ==========
; Khi khong tim thay monster trong CHARACTER array (server chi gui entity gan),
; tool tu dong di chuyen tuan tra theo luoi de kham pha toan map.
PatrolForMonsters(expectedGeneration := -1)
{
    global GameHwnd, HeroPtr, NoMonsterSince, LastPatrolMove, PatrolStep
    global CurrentEventRow, CurrentEventMap, PatrolWaypoints, PatrolWaypointIndex
    global PatrolExploredSectors, PatrolSectorSize, LastPatrolWaypointMove
    global PatrolLastHeroX, PatrolLastHeroY, PatrolStuckCount
    global PatrolNavPath, PatrolNavPathPos, PatrolNavTargetX, PatrolNavTargetY
    global PatrolWaypointStartTick
    global WorkerRosterSlot, WorkerRosterCount

    if (!IsHuntTokenValid(expectedGeneration))
        return

    if (!NoMonsterSince)
        NoMonsterSince := A_TickCount

    GuiControlGet, usePatrol,, ActivePatrol
    if (!usePatrol)
    {
        elapsed := Floor((A_TickCount - NoMonsterSince) / 1000)
        eventName := CurrentEventRow ? GetEventName(CurrentEventRow) : "map hien tai"
        SetHuntStatus("Khong thay quai tren " . eventName . " (" . elapsed . "s) - tuan tra TAT.", "CC7700")
        return
    }

    if (A_TickCount - LastPatrolMove < 1000)
        return

    if (!ReadInt(HeroPtr + 0xA8, heroX) || !ReadInt(HeroPtr + 0xAC, heroY))
        return

    ; Rebuild the route whenever a peer on this same map/event joins, leaves or
    ; changes scope. Workers on unrelated maps never reduce this route.
    RefreshWorkerRoster()

    ; Check stuck
    if (PatrolLastHeroX = heroX && PatrolLastHeroY = heroY)
        PatrolStuckCount += 1
    else
    {
        PatrolStuckCount := 0
    }
    PatrolLastHeroX := heroX, PatrolLastHeroY := heroY

    ; Build waypoints if empty
    if (!IsObject(PatrolWaypoints) || PatrolWaypoints.Length() = 0)
        BuildPatrolWaypoints(heroX, heroY)

    if (PatrolWaypointIndex < 1 || PatrolWaypointIndex > PatrolWaypoints.Length())
        PatrolWaypointIndex := 1
    if (!LastPatrolWaypointMove)
        LastPatrolWaypointMove := A_TickCount
    if (!PatrolWaypointStartTick)
        PatrolWaypointStartTick := A_TickCount

    ; Get next waypoint
    wp := PatrolWaypoints[PatrolWaypointIndex]
    wpX := wp[1], wpY := wp[2]

    ; Build one reachable terrain path per sector target. MU's PathFinding2 only
    ; queues a short route, so never hand it an arbitrary far/grid coordinate.
    if (PatrolNavTargetX != wpX || PatrolNavTargetY != wpY
        || !IsObject(PatrolNavPath) || PatrolNavPath.Length() = 0)
    {
        ; Safe/NoAttack tiles are valid transit corridors (not hunt goals).
        ; Lorencia's outer fields are split by the city SafeZone; forbidding
        ; transit here would scan one side and falsely declare the map empty.
        if (!BuildTerrainPath(heroX, heroY, wpX, wpY, patrolPath, false))
        {
            AdvancePatrolWaypoint(heroX, heroY)
            LastPatrolMove := A_TickCount
            SetHuntStatus("Bo qua sector khong co duong di; dang chon sector ke tiep.", "CC7700")
            return
        }
        if (!IsHuntTokenValid(expectedGeneration))
            return
        PatrolNavPath := patrolPath
        PatrolNavPathPos := 1
        PatrolNavTargetX := wpX
        PatrolNavTargetY := wpY
        LastPatrolWaypointMove := A_TickCount
        PatrolWaypointStartTick := A_TickCount
    }

    goal := PatrolNavPath[PatrolNavPath.Length()]
    if (Abs(heroX - goal[1]) <= 2 && Abs(heroY - goal[2]) <= 2)
    {
        sectorKey := Floor(goal[1] / PatrolSectorSize) . "," . Floor(goal[2] / PatrolSectorSize)
        PatrolExploredSectors[sectorKey] := true
        AdvancePatrolWaypoint(heroX, heroY)
        return
    }

    ; A native chunk can skip several intermediate A* nodes. Snap the cursor
    ; forward to the nearest node instead of requiring every old node to be hit.
    oldPathPos := PatrolNavPathPos
    nearestPos := PatrolNavPathPos, nearestScore := 0x7FFFFFFF
    maxProbe := Min(PatrolNavPath.Length(), PatrolNavPathPos + 24)
    probe := PatrolNavPathPos
    while (probe <= maxProbe)
    {
        probeNode := PatrolNavPath[probe]
        score := (probeNode[1]-heroX)*(probeNode[1]-heroX)
            + (probeNode[2]-heroY)*(probeNode[2]-heroY)
        if (score < nearestScore)
            nearestScore := score, nearestPos := probe
        probe += 1
    }
    PatrolNavPathPos := Max(PatrolNavPathPos, nearestPos)
    while (PatrolNavPathPos <= PatrolNavPath.Length())
    {
        node := PatrolNavPath[PatrolNavPathPos]
        if (Abs(node[1] - heroX) <= 2 && Abs(node[2] - heroY) <= 2)
            PatrolNavPathPos += 1
        else
            break
    }
    if (PatrolNavPathPos > oldPathPos)
        LastPatrolWaypointMove := A_TickCount
    if (PatrolNavPathPos > PatrolNavPath.Length())
    {
        AdvancePatrolWaypoint(heroX, heroY)
        return
    }

    ; Skip a route only when its monotonic A* cursor stops progressing. The
    ; absolute cap prevents coordinate oscillation from keeping one sector alive.
    if (PatrolStuckCount >= 4 || A_TickCount - LastPatrolWaypointMove >= 12000
        || A_TickCount - PatrolWaypointStartTick >= 60000)
    {
        AdvancePatrolWaypoint(heroX, heroY)
        return
    }

    ; The client route packet is about 15 nodes. Feed at most eight A* nodes so
    ; maze corners and gates stay inside its reliable budget.
    chunkPos := Min(PatrolNavPath.Length(), PatrolNavPathPos + 7)
    chunk := PatrolNavPath[chunkPos]
    if (!IsHuntTokenValid(expectedGeneration)
        || !CallBuiltinDirectMove(chunk[1], chunk[2], expectedGeneration))
    {
        PatrolNavPath := []
        PatrolStuckCount += 1
        LastPatrolMove := A_TickCount
        SetHuntStatus("Loi goi path native; dang tinh lai duong tuan tra.", "CC0000")
        return
    }
    LastPatrolMove := A_TickCount
    PatrolStep += 1
    elapsed := Floor((A_TickCount - NoMonsterSince) / 1000)
    SetHuntStatus("Tuan tra sector " . PatrolWaypointIndex . "/" . PatrolWaypoints.Length()
        . " (" . elapsed . "s) theo A* den (" . goal[1] . "," . goal[2]
        . ") | acc " . WorkerRosterSlot . "/" . WorkerRosterCount
        . " | hien tai (" . heroX . "," . heroY . ")...", "CC7700")
}

AdvancePatrolWaypoint(heroX, heroY)
{
    global PatrolWaypointIndex, PatrolWaypoints, PatrolExploredSectors
    global PatrolNavPath, PatrolNavPathPos, PatrolNavTargetX, PatrolNavTargetY
    global PatrolStuckCount, LastPatrolWaypointMove
    global PatrolCompletedCycles, PatrolWaypointStartTick
    PatrolStuckCount := 0
    PatrolWaypointIndex += 1
    LastPatrolWaypointMove := A_TickCount
    PatrolWaypointStartTick := A_TickCount
    PatrolNavPath := []
    PatrolNavPathPos := 1
    PatrolNavTargetX := -1
    PatrolNavTargetY := -1
    if (PatrolWaypointIndex > PatrolWaypoints.Length())
    {
        PatrolCompletedCycles += 1
        PatrolExploredSectors := {}
        BuildPatrolWaypoints(heroX, heroY)
        PatrolWaypointIndex := 1
    }
}

BuildPatrolWaypoints(startX, startY)
{
    global PatrolWaypoints, PatrolExploredSectors, PatrolSectorSize
    PatrolWaypoints := []
    reachableGoals := {}
    haveReachableMap := BuildReachablePatrolGoals(startX, startY, reachableGoals)
    ; 256x256 terrain with 20-tile sectors = 13x13 cells. Expand in complete
    ; square rings from the hero so nearby spawn sectors stream first. Only
    ; retain sectors in the hero's connected walkable component; this avoids
    ; wasting one second per blocked island/maze sector and makes one completed
    ; cycle a reliable proof that every reachable spawn sector was streamed.
    startKey := Floor(startX / PatrolSectorSize) . "," . Floor(startY / PatrolSectorSize)
    if (!PatrolExploredSectors.HasKey(startKey))
        PatrolWaypoints.Push([startX, startY])
    added := {}
    added[startKey] := true
    centerCol := Max(0, Min(12, Floor(startX / PatrolSectorSize)))
    centerRow := Max(0, Min(12, Floor(startY / PatrolSectorSize)))
    radius := 1
    while (radius <= 12)
    {
        left := centerCol - radius, right := centerCol + radius
        top := centerRow - radius, bottom := centerRow + radius
        col := left
        while (col <= right)
        {
            AddPatrolSectorWaypoint(col, top, added, reachableGoals, haveReachableMap)
            col += 1
        }
        row := top + 1
        while (row <= bottom)
        {
            AddPatrolSectorWaypoint(right, row, added, reachableGoals, haveReachableMap)
            row += 1
        }
        col := right - 1
        while (col >= left)
        {
            AddPatrolSectorWaypoint(col, bottom, added, reachableGoals, haveReachableMap)
            col -= 1
        }
        row := bottom - 1
        while (row > top)
        {
            AddPatrolSectorWaypoint(left, row, added, reachableGoals, haveReachableMap)
            row -= 1
        }
        radius += 1
    }
}

BuildReachablePatrolGoals(startX, startY, ByRef goals)
{
    global PatrolSectorSize
    goals := {}
    if (!LoadTerrainBuffer())
        return false
    startX := Max(0, Min(255, Round(startX)))
    startY := Max(0, Min(255, Round(startY)))
    if (IsTerrainBlocked(startX, startY))
    {
        if (!FindNearestWalkableGoal(startX, startY, startX, startY
            , walkX, walkY, false))
            return false
        startX := walkX, startY := walkY
    }
    start := startY * 256 + startX
    queue := [start], head := 1, visited := {}
    visited[start] := true
    dirs := [[1,0],[-1,0],[0,1],[0,-1]]
    while (head <= queue.Length())
    {
        current := queue[head]
        head += 1
        x := Mod(current, 256), y := Floor(current / 256)
        ; Traverse restricted cells to connect fields, but never make one a
        ; patrol destination where Helper would be unable to attack.
        if (!IsTerrainRestricted(x, y))
        {
            col := Floor(x / PatrolSectorSize), row := Floor(y / PatrolSectorSize)
            sectorKey := col . "," . row
            centerX := Min(250, col * PatrolSectorSize + Floor(PatrolSectorSize / 2))
            centerY := Min(250, row * PatrolSectorSize + Floor(PatrolSectorSize / 2))
            score := (x-centerX)*(x-centerX) + (y-centerY)*(y-centerY)
            if (!goals.HasKey(sectorKey) || score < goals[sectorKey][3])
                goals[sectorKey] := [x, y, score]
        }
        for _, d in dirs
        {
            nx := x + d[1], ny := y + d[2]
            if (nx < 0 || nx > 255 || ny < 0 || ny > 255
                || IsTerrainBlocked(nx, ny))
                continue
            next := ny * 256 + nx
            if (visited.HasKey(next))
                continue
            visited[next] := true
            queue.Push(next)
        }
    }
    return ObjectHasAnyKey(goals)
}

IsAtlansCoordinateForStage(x, y, stage)
{
    if (stage = 1)
        return x >= 140
    if (stage = 2)
        return x < 140 && y >= 100
    return x < 140 && y < 100
}

AddPatrolSectorWaypoint(col, row, ByRef added, ByRef reachableGoals
    , haveReachableMap := false)
{
    global PatrolWaypoints, PatrolExploredSectors, PatrolSectorSize
    global CurrentEventRow, AtlansEscapeStage
    if (col < 0 || col > 12 || row < 0 || row > 12)
        return
    sectorKey := col . "," . row
    if (added.HasKey(sectorKey) || PatrolExploredSectors.HasKey(sectorKey))
        return
    if (!IsPatrolSectorAssignedToThisWorker(col, row))
        return
    if (haveReachableMap)
    {
        if (!reachableGoals.HasKey(sectorKey))
            return
        goal := reachableGoals[sectorKey]
        cx := goal[1], cy := goal[2]
    }
    else
    {
        cx := Min(250, col * PatrolSectorSize + Floor(PatrolSectorSize / 2))
        cy := Min(250, row * PatrolSectorSize + Floor(PatrolSectorSize / 2))
    }
    if ((CurrentEventRow = 9 || CurrentEventRow = 16)
        && (AtlansEscapeStage = 1 || AtlansEscapeStage = 2)
        && !IsAtlansCoordinateForStage(cx, cy, AtlansEscapeStage))
        return
    PatrolWaypoints.Push([cx, cy])
    added[sectorKey] := true
}

MoveHeroTowards(targetX, targetY, heroX, heroY, expectedGeneration := -1)
{
    global LastApproachClick
    if (!IsHuntTokenValid(expectedGeneration) || A_TickCount - LastApproachClick < 350)
        return
    if (CallBuiltinTerrainStep(heroX, heroY, targetX, targetY, 8, expectedGeneration))
        LastApproachClick := A_TickCount
}

; ========== SAFEZONE ESCAPE ==========
InferCurrentAtlansStage(ByRef inferredStage, ByRef heroX, ByRef heroY)
{
    global HeroPtr
    inferredStage := 0
    if (!GetCurrentMapId(mapId) || mapId != 7
        || !ReadInt(HeroPtr + 0xA8, heroX) || !ReadInt(HeroPtr + 0xAC, heroY))
        return false
    ; All three Atlans areas share MapID 7. Nearest-gate classification labels
    ; Atlans1 (23,20 / 48,41 live) as Atlans3 and was the source of the stutter.
    ; Use the actual connected-map regions with a small hysteresis-free split.
    if (heroX >= 140)
        inferredStage := 1       ; Atlans2
    else if (heroY >= 100)
        inferredStage := 2       ; Atlans3
    else
        return false             ; Atlans1: route to Atlans2 first
    return true
}

InitializeAtlansRotationFromPosition(announce := false)
{
    global CurrentEventRow, AtlansEscapeStage, AtlansDwellSince
    global LastAtlansWarp, AtlansWarpFailures
    global AtlansTransitTargetStage
    if ((CurrentEventRow != 9 && CurrentEventRow != 16) || AtlansEscapeStage != 0
        || AtlansTransitTargetStage
        || !InferCurrentAtlansStage(inferredStage, inferredX, inferredY))
        return false
    AtlansEscapeStage := inferredStage
    AtlansDwellSince := A_TickCount
    LastAtlansWarp := A_TickCount
    AtlansWarpFailures := 0
    ResetPatrolRoute()
    if (announce)
        SetHuntStatus("Nhan dien dang o "
            . (inferredStage = 1 ? "Atlans2" : "Atlans3")
            . " tai (" . inferredX . "," . inferredY . ") - bat dau dem 5 phut.", "0077AA")
    return true
}

BeginAtlansConnectedTransit(targetStage)
{
    global AtlansTransitTargetStage, AtlansTransitStartedTick
    global LastAtlansTransitMove, SafeZoneEscapeActive
    global AtlansTransitLastHeroX, AtlansTransitLastHeroY
    global AtlansTransitLastProgressTick, AtlansTransitStallCount
    if (targetStage != 1 && targetStage != 2)
        return false
    AtlansTransitTargetStage := targetStage
    AtlansTransitStartedTick := A_TickCount
    LastAtlansTransitMove := 0
    AtlansTransitLastHeroX := -1
    AtlansTransitLastHeroY := -1
    AtlansTransitLastProgressTick := A_TickCount
    AtlansTransitStallCount := 0
    SafeZoneEscapeActive := true
    ResetPatrolRoute()
    return true
}

ResetAtlansConnectedTransit()
{
    global AtlansTransitTargetStage, AtlansTransitStartedTick, LastAtlansTransitMove
    global AtlansTransitLastHeroX, AtlansTransitLastHeroY
    global AtlansTransitLastProgressTick, AtlansTransitStallCount
    AtlansTransitTargetStage := 0
    AtlansTransitStartedTick := 0
    LastAtlansTransitMove := 0
    AtlansTransitLastHeroX := -1
    AtlansTransitLastHeroY := -1
    AtlansTransitLastProgressTick := 0
    AtlansTransitStallCount := 0
}

FallbackAtlansConnectedTransit(reason)
{
    global AtlansEscapeStage, AtlansStage3Since, AtlansDwellSince
    global SafeZoneEscapeActive, NoMonsterSince
    ResetAtlansConnectedTransit()
    ; Stage 3 is the connected-terrain fallback: it scans every reachable
    ; Atlans sector instead of waiting forever at a blocked transition.
    AtlansEscapeStage := 3
    AtlansStage3Since := A_TickCount
    AtlansDwellSince := 0
    NoMonsterSince := A_TickCount
    SafeZoneEscapeActive := true
    ResetPatrolRoute()
    SetHuntStatus("Atlans A*: " . reason . " Chuyen sang quet terrain lien thong toan map.", "CC7700")
    return true
}

HandleAtlansConnectedTransit(expectedGeneration := -1)
{
    global HeroPtr, AtlansTransitTargetStage, AtlansTransitStartedTick
    global LastAtlansTransitMove, AtlansTransitTimeoutMs
    global AtlansTransitLastHeroX, AtlansTransitLastHeroY
    global AtlansTransitLastProgressTick, AtlansTransitStallCount
    global AtlansTransitStallMs, AtlansTransitMaxStalls
    global AtlansEscapeStage, AtlansDwellSince, LastAtlansWarp
    global SafeZoneEscapeActive, NoMonsterSince
    if (!AtlansTransitTargetStage || !IsHuntTokenValid(expectedGeneration)
        || !ReadInt(HeroPtr + 0xA8, heroX) || !ReadInt(HeroPtr + 0xAC, heroY))
        return false
    targetStage := AtlansTransitTargetStage
    targetX := (targetStage = 1) ? 226 : 63
    targetY := (targetStage = 1) ? 53 : 163
    distance := Max(Abs(heroX - targetX), Abs(heroY - targetY))
    if (AtlansTransitLastHeroX < 0)
    {
        AtlansTransitLastHeroX := heroX
        AtlansTransitLastHeroY := heroY
        AtlansTransitLastProgressTick := A_TickCount
    }
    else if (heroX != AtlansTransitLastHeroX || heroY != AtlansTransitLastHeroY)
    {
        AtlansTransitLastHeroX := heroX
        AtlansTransitLastHeroY := heroY
        AtlansTransitLastProgressTick := A_TickCount
        AtlansTransitStallCount := 0
    }
    if (distance <= 8)
    {
        AtlansEscapeStage := targetStage
        AtlansDwellSince := A_TickCount
        LastAtlansWarp := A_TickCount
        SafeZoneEscapeActive := false
        NoMonsterSince := A_TickCount
        ResetAtlansConnectedTransit()
        ResetPatrolRoute()
        SetHuntStatus("Da di lien mach den " . (targetStage = 1 ? "Atlans2" : "Atlans3")
            . " - bat dau quet bai 5 phut.", "008000")
        return true
    }
    if (!AtlansTransitStartedTick)
        AtlansTransitStartedTick := A_TickCount
    if (A_TickCount - AtlansTransitStartedTick > AtlansTransitTimeoutMs)
        return FallbackAtlansConnectedTransit("qua 120 giay chua toi gate.")
    if (AtlansTransitLastProgressTick
        && A_TickCount - AtlansTransitLastProgressTick > AtlansTransitStallMs)
    {
        AtlansTransitStallCount += 1
        AtlansTransitLastProgressTick := A_TickCount
        LastAtlansTransitMove := 0
        ResetPatrolRoute()
        if (AtlansTransitStallCount >= AtlansTransitMaxStalls)
            return FallbackAtlansConnectedTransit("nhan vat dung yen qua 3 lan tinh lai duong.")
        SetHuntStatus("Atlans A*: nhan vat dang mac dia hinh, tinh lai route ("
            . AtlansTransitStallCount . "/" . AtlansTransitMaxStalls . ").", "CC7700")
    }
    if (A_TickCount - LastAtlansTransitMove >= 700)
    {
        if (!CallBuiltinTerrainStep(heroX, heroY, targetX, targetY, 8, expectedGeneration))
        {
            SetHuntStatus("Atlans A*: dang tinh lai duong noi den "
                . (targetStage = 1 ? "Atlans2" : "Atlans3") . ".", "CC7700")
            LastAtlansTransitMove := A_TickCount
            return false
        }
        LastAtlansTransitMove := A_TickCount
    }
    SetHuntStatus("Dang di nen A* " . (AtlansEscapeStage = 0 ? "Atlans1" : (AtlansEscapeStage = 1 ? "Atlans2" : "Atlans3"))
        . " -> " . (targetStage = 1 ? "Atlans2" : "Atlans3")
        . " | (" . heroX . "," . heroY . ") con " . distance . " tile.", "0077AA")
    return true
}

HandleSafeZoneEscape(expectedGeneration := -1)
{
    global CurrentEventRow, LastSafeZoneEscape, SafeZoneEscapeActive
    global CurrentEventMonsterCount, CurrentAllowedMonsterCount, CompletedEventRows
    global AtlansEscapeStage, LastAtlansWarp, AtlansStage3Since, AtlansWarpFailures
    global AtlansDwellSince, AtlansRotationIntervalMs, AtlansClearConfirmMs
    global AtlansTransitTargetStage
    global NoMonsterSince
    global HeroPtr, PatrolCompletedCycles, PatrolWaypointIndex, PatrolWaypoints

    if (!IsHuntTokenValid(expectedGeneration))
        return

    ; Kho Bau va Long Vuong: H co the dua nhan vat vao Atlans1. Atlans1/2/3
    ; cung MapID 7 va lien thong, nen di A* tren terrain noi bo thay vi mo M;
    ; cach nay khong doi focus va tranh khung/chon nham dong tren move menu.
    if (CurrentEventRow = 9 || CurrentEventRow = 16)
    {
        ; The table's monster counter is not authoritative on this server: it
        ; can reach zero before all distant/chained spawns have streamed. Only
        ; the row leaving Active state is allowed to end the Atlans loop.
        if (!IsOrdinaryEventRowActive(CurrentEventRow))
        {
            CompletedEventRows[CurrentEventRow] := true
            SafeZoneEscapeActive := false
            AtlansEscapeStage := 0
            AtlansStage3Since := 0
            AtlansWarpFailures := 0
            AtlansDwellSince := 0
            ResetAtlansConnectedTransit()
            SetHuntStatus("Su kien Atlans da het thoi gian; chuyen uu tien ke tiep.", "008000")
            return
        }
        if (GetAllowedEventRemainingCount(CurrentEventRow, allowedRemaining))
            CurrentAllowedMonsterCount := allowedRemaining
        else
            allowedRemaining := CurrentEventMonsterCount

        if (AtlansTransitTargetStage)
        {
            HandleAtlansConnectedTransit(expectedGeneration)
            return
        }

        if (AtlansWarpFailures >= 3 && AtlansEscapeStage < 3)
        {
            AtlansEscapeStage := 3
            AtlansStage3Since := A_TickCount
            AtlansDwellSince := 0
            ResetPatrolRoute()
            SetHuntStatus("Bang M khong dua duoc den Atlans; chuyen sang A* thoat bai va tuan tra.", "CC7700")
        }
        if (AtlansEscapeStage >= 3)
        {
            if (!ReadByte(HeroPtr + 0x12, safeZone))
            {
                SetHuntStatus("Khong doc duoc trang thai SafeZone; tam dung route Atlans.", "CC0000")
                return
            }
            if (ReadInt(HeroPtr + 0xA8, hx) && ReadInt(HeroPtr + 0xAC, hy)
                && IsTerrainRestricted(hx, hy, true))
                safeZone := 1
            if (safeZone != 0)
            {
                ; Do not count the empty-map timeout while still trapped inside
                ; a non-attack area.
                AtlansStage3Since := 0
                SafeZoneEscapeActive := true
                if (A_TickCount - LastSafeZoneEscape >= 900)
                {
                    LastSafeZoneEscape := A_TickCount
                    WalkOutOfSafeZone(expectedGeneration)
                }
            }
            else
            {
                if (!AtlansStage3Since)
                    AtlansStage3Since := A_TickCount
                if (PatrolCompletedCycles > 0)
                {
                    ; The event is still active: loop both Atlans hubs again
                    ; regardless of the non-authoritative monster counter.
                    SafeZoneEscapeActive := false
                    AtlansEscapeStage := 0
                    AtlansStage3Since := 0
                    AtlansWarpFailures := 0
                    LastAtlansWarp := 0
                    ResetPatrolRoute()
                    SetHuntStatus("Su kien Atlans van hoat dong; quay lai quet Atlans2/3.", "CC7700")
                    return
                }
                SafeZoneEscapeActive := false
                PatrolForMonsters(expectedGeneration)
                if (PatrolCompletedCycles = 0)
                    SetHuntStatus("Dang quet connected terrain cua Atlans de tim boss con lai.", "CC7700")
            }
            return
        }
        SafeZoneEscapeActive := true
        if (AtlansEscapeStage = 0)
        {
            if (InitializeAtlansRotationFromPosition(true))
                return
            BeginAtlansConnectedTransit(1)
            HandleAtlansConnectedTransit(expectedGeneration)
            return
        }
        if (!ReadByte(HeroPtr + 0x12, stageSafe))
        {
            SetHuntStatus("Khong doc duoc SafeZone tai bai Atlans; tam dung route.", "CC0000")
            return
        }
        if (ReadInt(HeroPtr + 0xA8, stageX) && ReadInt(HeroPtr + 0xAC, stageY)
            && IsTerrainRestricted(stageX, stageY, true))
            stageSafe := 1
        if (stageSafe != 0)
        {
            SafeZoneEscapeActive := true
            if (A_TickCount - LastSafeZoneEscape >= 900)
            {
                LastSafeZoneEscape := A_TickCount
                WalkOutOfSafeZone(expectedGeneration)
            }
            SetHuntStatus("Da den " . (AtlansEscapeStage = 1 ? "Atlans2" : "Atlans3")
                . " - A* dang dua nhan vat ra khu duoc danh.", "0077AA")
            return
        }
        SafeZoneEscapeActive := false
        if (!AtlansDwellSince)
            AtlansDwellSince := A_TickCount
        rotationElapsed := A_TickCount - AtlansDwellSince
        if (rotationElapsed >= AtlansRotationIntervalMs)
        {
            clearElapsed := NoMonsterSince ? A_TickCount - NoMonsterSince : 0
            if (clearElapsed < AtlansClearConfirmMs)
            {
                clearRemain := Ceil((AtlansClearConfirmMs - clearElapsed) / 1000.0)
                SetHuntStatus("Da du 5 phut tai "
                    . (AtlansEscapeStage = 1 ? "Atlans2" : "Atlans3")
                    . " - dang xac nhan xung quanh het quai (" . clearRemain . "s)...", "0077AA")
                return
            }
            nextAtlansKey := (AtlansEscapeStage = 1) ? "Atlans3" : "Atlans2"
            nextAtlansStage := (AtlansEscapeStage = 1) ? 2 : 1
            SetHuntStatus("Da du 5 phut va xung quanh khong con quai - chuyen "
                . nextAtlansKey . "...", "0077AA")
            BeginAtlansConnectedTransit(nextAtlansStage)
            HandleAtlansConnectedTransit(expectedGeneration)
            return
        }
        PatrolForMonsters(expectedGeneration)
        if (!IsHuntTokenValid(expectedGeneration))
            return
        rotationRemain := Ceil((AtlansRotationIntervalMs - rotationElapsed) / 1000.0)
        SetHuntStatus("Dang quet du sector reachable " . (AtlansEscapeStage = 1 ? "Atlans2" : "Atlans3")
            . " (" . PatrolWaypointIndex . "/" . PatrolWaypoints.Length() . ")"
            . " | doi bai sau " . FormatEventTime(rotationRemain) . ".", "CC7700")
        return
    }

    if (A_TickCount - LastSafeZoneEscape < 900)
        return
    LastSafeZoneEscape := A_TickCount
    SafeZoneEscapeActive := true
    SetHuntStatus("Chua co slot boss - pathfinder dang thu cac cua ra SafeZone...", "CC7700")
    WalkOutOfSafeZone(expectedGeneration)
}

WarpToEscapeMap(mapKey, nextStage, expectedGeneration := -1)
{
    global GameHwnd, TravelBusy, CurrentEventMap, NoMonsterSince
    global CurrentTarget, CurrentTargetMonsterIndex
    global LastAtlansWarp, AtlansEscapeStage, SafeZoneEscapeActive, HuntGeneration, HeroPtr
    global AtlansWarpFailures, AtlansStage3Since, AtlansDwellSince
    if (!GameHwnd)
        ResolveCharacterMemory()
    if (TravelBusy || !GameHwnd)
        return false
    TravelBusy := true
    AbortComboForTravel()
    generation := (expectedGeneration >= 0) ? expectedGeneration : HuntGeneration
    if (!IsHuntTokenValid(generation))
    {
        TravelBusy := false
        return false
    }
    CurrentTarget := -1
    CurrentTargetMonsterIndex := -1
    if (!PrepareNativeMovement(generation))
    {
        SetHuntStatus("Khong dung duoc MU Helper truoc khi mo bang M; se thu lai.", "CC0000")
        TravelBusy := false
        return false
    }
    SetHuntStatus("Dang mo bang M va chon " . mapKey . "...", "0077AA")
    ok := WarpByMoveMenu(mapKey, generation)
    arrived := false
    if (ok)
    {
        deadline := A_TickCount + 8000
        while (A_TickCount < deadline && generation = HuntGeneration)
        {
            Sleep, 200
            if (!ReadInt(HeroPtr + 0xA8, heroX) || !ReadInt(HeroPtr + 0xAC, heroY))
                continue
            mapKnown := GetCurrentMapId(actualMap)
            if (IsNearAtlansGate(mapKey, heroX, heroY) && (!mapKnown || actualMap = 7))
            {
                arrived := true
                break
            }
        }
    }
    if (generation != HuntGeneration)
    {
        TravelBusy := false
        return false
    }
    LastAtlansWarp := A_TickCount
    if (arrived)
    {
        AtlansEscapeStage := nextStage
        AtlansWarpFailures := 0
        AtlansStage3Since := 0
        AtlansDwellSince := A_TickCount
        SafeZoneEscapeActive := true
        CurrentEventMap := 7
        NoMonsterSince := A_TickCount
        ResetPatrolRoute()
        SetHuntStatus("Da den " . mapKey . " - dang quet boss toan bai.", "008000")
    }
    else
    {
        AtlansWarpFailures += 1
        SetHuntStatus("Chua den dung gate " . mapKey . " (lan " . AtlansWarpFailures
            . "/3); se mo bang M va thu lai.", "CC0000")
    }
    if (arrived)
        NoMonsterSince := A_TickCount
    TravelBusy := false
    return arrived
}

WarpByMoveMenu(mapKey, expectedGeneration := -1)
{
    global GameHwnd
    if (!GameHwnd || !IsHuntTokenValid(expectedGeneration))
        return false
    if (IsEventPanelOpen())
        CloseEventPanel()
    Critical, On
    if (!IsHuntTokenValid(expectedGeneration))
    {
        Critical, Off
        return false
    }
    if (mapKey != "Atlans2" && mapKey != "Atlans3")
    {
        Critical, Off
        return false
    }
    ; Logical Engine coordinates (not Windows pixels): Atlans2 (120,244),
    ; Atlans3 (120,257). SendGameVirtualKey waits for the M-panel visibility ACK.
    if (!SendGameVirtualKey(0x4D, 0x32, 60, expectedGeneration))
    {
        Critical, Off
        return false
    }
    clickX := 120
    baseY := (mapKey = "Atlans2") ? 244 : 257
    clickY := baseY
    ok := SendGameMouseClick(clickX, clickY, expectedGeneration)
    Critical, Off
    return ok
}

IsNearAtlansGate(mapKey, x, y)
{
    if (mapKey = "Atlans2")
        return (x >= 215 && x <= 238 && y >= 40 && y <= 63)
    if (mapKey = "Atlans3")
        return (x >= 52 && x <= 78 && y >= 147 && y <= 173)
    return false
}

WalkOutOfSafeZone(expectedGeneration := -1)
{
    global HeroPtr, SafeZoneEscapeTarget, SafeZoneEscapePath, SafeZoneEscapePathPos
    global SafeZoneTargetSetTick
    global PatrolLastHeroX, PatrolLastHeroY, PatrolStuckCount

    if (!IsHuntTokenValid(expectedGeneration)
        || !ReadInt(HeroPtr + 0xA8, heroX) || !ReadInt(HeroPtr + 0xAC, heroY))
        return

    if (PatrolLastHeroX = heroX && PatrolLastHeroY = heroY)
        PatrolStuckCount += 1
    else
    {
        PatrolStuckCount := 0
    }
    PatrolLastHeroX := heroX, PatrolLastHeroY := heroY

    needTarget := !IsObject(SafeZoneEscapePath) || SafeZoneEscapePath.Length() = 0
        || PatrolStuckCount >= 3
        || (SafeZoneTargetSetTick && A_TickCount - SafeZoneTargetSetTick >= 10000)
    if (needTarget)
    {
        if (!BuildSafeZoneExitPath(heroX, heroY, exitPath))
        {
            SafeZoneEscapePath := []
            SetHuntStatus("Khong tim thay cua ra reachable tren TerrainWall cua map.", "CC0000")
            return false
        }
        if (!IsHuntTokenValid(expectedGeneration))
            return false
        SafeZoneEscapePath := exitPath
        SafeZoneEscapePathPos := 1
        SafeZoneEscapeTarget := exitPath[exitPath.Length()]
        SafeZoneTargetSetTick := A_TickCount
        PatrolStuckCount := 0
    }

    oldPathPos := SafeZoneEscapePathPos
    nearestPos := SafeZoneEscapePathPos, nearestScore := 0x7FFFFFFF
    maxProbe := Min(SafeZoneEscapePath.Length(), SafeZoneEscapePathPos + 24)
    probe := SafeZoneEscapePathPos
    while (probe <= maxProbe)
    {
        probeNode := SafeZoneEscapePath[probe]
        score := (probeNode[1]-heroX)*(probeNode[1]-heroX)
            + (probeNode[2]-heroY)*(probeNode[2]-heroY)
        if (score < nearestScore)
            nearestScore := score, nearestPos := probe
        probe += 1
    }
    SafeZoneEscapePathPos := Max(SafeZoneEscapePathPos, nearestPos)
    while (SafeZoneEscapePathPos <= SafeZoneEscapePath.Length())
    {
        node := SafeZoneEscapePath[SafeZoneEscapePathPos]
        if (Abs(node[1] - heroX) <= 1 && Abs(node[2] - heroY) <= 1)
            SafeZoneEscapePathPos += 1
        else
            break
    }
    if (SafeZoneEscapePathPos > oldPathPos)
        SafeZoneTargetSetTick := A_TickCount
    if (SafeZoneEscapePathPos > SafeZoneEscapePath.Length())
    {
        SafeZoneEscapePath := []
        return true
    }
    chunkPos := Min(SafeZoneEscapePath.Length(), SafeZoneEscapePathPos + 7)
    chunk := SafeZoneEscapePath[chunkPos]
    if (!CallBuiltinDirectMove(chunk[1], chunk[2], expectedGeneration))
    {
        SafeZoneEscapePath := []
        SafeZoneEscapeTarget := []
        SetHuntStatus("Loi path native khi thoat SafeZone; dang tinh lai.", "CC0000")
        return false
    }
    SetHuntStatus("A* dang dua nhan vat qua cua ra (" . chunk[1] . "," . chunk[2]
        . ") -> bai quai (" . SafeZoneEscapeTarget[1] . "," . SafeZoneEscapeTarget[2] . ").", "0077AA")
    return true
}

ResetPatrolRoute()
{
    global PatrolWaypoints, PatrolWaypointIndex, PatrolExploredSectors
    global PatrolLastHeroX, PatrolLastHeroY, PatrolStuckCount, LastPatrolMove
    global LastPatrolWaypointMove, SafeZoneEscapeTarget, SafeZoneEscapePath
    global SafeZoneEscapePathPos, SafeZoneTargetSetTick
    global PatrolNavPath, PatrolNavPathPos, PatrolNavTargetX, PatrolNavTargetY
    global PatrolCompletedCycles, PatrolWaypointStartTick
    PatrolWaypoints := []
    PatrolWaypointIndex := 0
    PatrolExploredSectors := {}
    PatrolLastHeroX := -1
    PatrolLastHeroY := -1
    PatrolStuckCount := 0
    LastPatrolMove := 0
    LastPatrolWaypointMove := 0
    PatrolWaypointStartTick := 0
    PatrolNavPath := []
    PatrolNavPathPos := 1
    PatrolNavTargetX := -1
    PatrolNavTargetY := -1
    PatrolCompletedCycles := 0
    SafeZoneEscapeTarget := []
    SafeZoneEscapePath := []
    SafeZoneEscapePathPos := 1
    SafeZoneTargetSetTick := 0
}

; ========== BUILTIN MU HELPER ==========
; Scanner cua tool chon dung boss. Game van tu tim duong/danh/nhat bang
; chinh cac ham cua MU Helper; khong click uoc luong toa do tren man hinh.

SnapshotBuiltinHelperConfig()
{
    global BuiltinHelperBase, BuiltinConfigSnapshotReady
    global BuiltinOriginalRange, BuiltinOriginalRegroup, BuiltinOriginalRegroupRange
    global BuiltinOriginalPickupRange, BuiltinOriginalPickupAll, BuiltinOriginalPickupSelected
    ; Snapshot only fields this tool changes. The old 108-byte raw copy included
    ; a heap/container pointer near +0x7C that could become stale if Helper UI
    ; was edited while hunting.
    ok := ReadDword(BuiltinHelperBase + 0x1C, BuiltinOriginalRange)
        && ReadByte(BuiltinHelperBase + 0x21, BuiltinOriginalRegroup)
        && ReadDword(BuiltinHelperBase + 0x24, BuiltinOriginalRegroupRange)
        && ReadDword(BuiltinHelperBase + 0x70, BuiltinOriginalPickupRange)
        && ReadByte(BuiltinHelperBase + 0x74, BuiltinOriginalPickupAll)
        && ReadByte(BuiltinHelperBase + 0x75, BuiltinOriginalPickupSelected)
    BuiltinConfigSnapshotReady := ok
    return BuiltinConfigSnapshotReady
}

RestoreBuiltinHelperConfig()
{
    global hProcess, BuiltinHelperBase, BuiltinConfigSnapshotReady
    global BuiltinOriginalRange, BuiltinOriginalRegroup, BuiltinOriginalRegroupRange
    global BuiltinOriginalPickupRange, BuiltinOriginalPickupAll, BuiltinOriginalPickupSelected
    if (!BuiltinConfigSnapshotReady || !hProcess)
        return false
    return WriteDword(BuiltinHelperBase + 0x1C, BuiltinOriginalRange)
        && WriteByte(BuiltinHelperBase + 0x21, BuiltinOriginalRegroup)
        && WriteDword(BuiltinHelperBase + 0x24, BuiltinOriginalRegroupRange)
        && WriteDword(BuiltinHelperBase + 0x70, BuiltinOriginalPickupRange)
        && WriteByte(BuiltinHelperBase + 0x74, BuiltinOriginalPickupAll)
        && WriteByte(BuiltinHelperBase + 0x75, BuiltinOriginalPickupSelected)
}

ReadBuiltinHelperActive(ByRef active)
{
    global BuiltinHelperBase
    if (!ReadByte(BuiltinHelperBase + 0x98, rawActive))
        return false
    active := (rawActive != 0)
    return true
}

IsBuiltinHelperActive()
{
    return (ReadBuiltinHelperActive(active) && active)
}

StartBuiltinHelper()
{
    global BuiltinHelperStartAddress
    if (!ReadBuiltinHelperActive(active))
        return false
    if (active)
        return true
    if (!RemoteThisCall0(BuiltinHelperStartAddress, reason))
        return false
    return WaitBuiltinHelperState(true, 800)
}

StopBuiltinHelper()
{
    global BuiltinHelperStopAddress, BuiltinHelperBase
    if (!ReadBuiltinHelperActive(active))
        return false
    if (!active)
        return WriteDword(BuiltinHelperBase + 0xB8, 0xFFFFFFFF)
    if (!RemoteThisCall0(BuiltinHelperStopAddress, reason))
        return false
    if (!WaitBuiltinHelperState(false, 800))
        return false
    if (!WriteDword(BuiltinHelperBase + 0xB8, 0xFFFFFFFF))
        return false
    ; +0x98 is cleared before an already-entered Work/Attack callback fully
    ; returns. Let that callback quiesce before restoring config/path state.
    Sleep, 80
    return true
}

WaitBuiltinHelperState(wantedActive, timeoutMs)
{
    started := A_TickCount
    while (A_TickCount - started < timeoutMs)
    {
        if (ReadBuiltinHelperActive(active) && active = wantedActive)
            return true
        Sleep, 20
    }
    return (ReadBuiltinHelperActive(active) && active = wantedActive)
}

CallBuiltinDirectMove(x, y, expectedGeneration := -1)
{
    global BuiltinDirectMoveAddress
    if (x < 0 || x > 255 || y < 0 || y > 255
        || !IsHuntTokenValid(expectedGeneration))
        return false
    ; Keep the tiny generation-check/remote-dispatch window atomic. Ctrl+F1 can run
    ; as soon as the native call returns, never between the guard and dispatch.
    Critical, On
    if (!IsHuntTokenValid(expectedGeneration))
    {
        Critical, Off
        return false
    }
    ok := RemoteThisCallPoint(BuiltinDirectMoveAddress, x, y, reason)
    Critical, Off
    return ok
}

ForceBuiltinTarget(index)
{
    global CharactersBase, CharacterStride, BuiltinHelperBase
    if (index < 0 || index >= 400)
        return false
    address := CharactersBase + index * CharacterStride
    if (!ReadByte(address + 0x388, live) || live != 1
        || !ReadByte(address + 0x39E, kind) || kind != 2
        || !ReadByte(address + 0x28, dead) || dead != 0
        || !IsAllowedMonsterForMap(address)
        || !ReadShort(address + 0x76, monsterKey) || monsterKey = -1)
        return false
    ; Helper target field is a 32-bit int; the object Key source is 16-bit.
    if (!WriteDword(BuiltinHelperBase + 0xB8, monsterKey))
        return false
    if (!ReadShort(address + 0x76, verifyKey) || verifyKey != monsterKey
        || !ReadDword(BuiltinHelperBase + 0xB8, helperKey))
    {
        WriteDword(BuiltinHelperBase + 0xB8, 0xFFFFFFFF)
        return false
    }
    expected := (monsterKey < 0) ? monsterKey + 0x100000000 : monsterKey
    if (helperKey != expected)
    {
        WriteDword(BuiltinHelperBase + 0xB8, 0xFFFFFFFF)
        return false
    }
    return true
}

PrepareNativeMovement(expectedGeneration := -1)
{
    global BuiltinMode, BuiltinHelperBase, HelperTransitionBusy
    if (HelperTransitionBusy || !IsHuntTokenValid(expectedGeneration))
        return false
    HelperTransitionBusy := true
    Critical, On
    if (!IsHuntTokenValid(expectedGeneration))
    {
        HelperTransitionBusy := false
        Critical, Off
        return false
    }
    ok := ReadBuiltinHelperActive(active)
    if (ok && active)
        ok := StopBuiltinHelper()
    else if (ok && !active && BuiltinMode != "")
        Sleep, 80
    if (ok)
        ok := WriteDword(BuiltinHelperBase + 0xB8, 0xFFFFFFFF)
    if (ok && BuiltinMode != "")
        ok := RestoreBuiltinHelperConfig()
    if (ok)
        BuiltinMode := ""
    HelperTransitionBusy := false
    Critical, Off
    return ok
}

RemoteThisCall0(functionAddress, ByRef reason)
{
    global BuiltinHelperBase
    VarSetCapacity(code, 17, 0)
    NumPut(0xB9, code, 0, "UChar")
    NumPut(BuiltinHelperBase, code, 1, "UInt")
    NumPut(0xB8, code, 5, "UChar")
    NumPut(functionAddress, code, 6, "UInt")
    NumPut(0xFF, code, 10, "UChar"), NumPut(0xD0, code, 11, "UChar")
    NumPut(0x31, code, 12, "UChar"), NumPut(0xC0, code, 13, "UChar")
    NumPut(0xC2, code, 14, "UChar"), NumPut(0x04, code, 15, "UChar")
    NumPut(0x00, code, 16, "UChar")
    return RunRemoteCode(code, 17, 2000, reason)
}

RemoteThisCallPoint(functionAddress, x, y, ByRef reason)
{
    global BuiltinHelperBase
    VarSetCapacity(code, 27, 0)
    NumPut(0x68, code, 0, "UChar"), NumPut(y, code, 1, "Int")
    NumPut(0x68, code, 5, "UChar"), NumPut(x, code, 6, "Int")
    NumPut(0xB9, code, 10, "UChar"), NumPut(BuiltinHelperBase, code, 11, "UInt")
    NumPut(0xB8, code, 15, "UChar"), NumPut(functionAddress, code, 16, "UInt")
    NumPut(0xFF, code, 20, "UChar"), NumPut(0xD0, code, 21, "UChar")
    NumPut(0x31, code, 22, "UChar"), NumPut(0xC0, code, 23, "UChar")
    NumPut(0xC2, code, 24, "UChar"), NumPut(0x04, code, 25, "UChar")
    NumPut(0x00, code, 26, "UChar")
    return RunRemoteCode(code, 27, 2000, reason)
}

RunRemoteCode(ByRef code, codeSize, timeoutMs, ByRef reason)
{
    global hProcess, RemoteCallBusy, RemotePendingThread, RemotePendingBuffer
    reason := ""
    if (RemoteCallBusy && !ReapPendingRemoteCall())
    {
        reason := "previous-remote-call-pending"
        return false
    }
    if (!hProcess)
    {
        reason := "detached"
        return false
    }
    RemoteCallBusy := true
    remote := DllCall("Kernel32\VirtualAllocEx", "Ptr", hProcess, "Ptr", 0
        , "UPtr", codeSize, "UInt", 0x3000, "UInt", 0x04, "Ptr")
    if (!remote)
    {
        reason := "VirtualAllocEx:" . A_LastError
        RemoteCallBusy := false
        return false
    }
    ok := DllCall("Kernel32\WriteProcessMemory", "Ptr", hProcess, "Ptr", remote
        , "Ptr", &code, "UPtr", codeSize, "UPtr*", written)
    if (!ok || written != codeSize)
    {
        reason := "WriteProcessMemory:" . A_LastError
        DllCall("Kernel32\VirtualFreeEx", "Ptr", hProcess, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        RemoteCallBusy := false
        return false
    }
    if (!DllCall("Kernel32\VirtualProtectEx", "Ptr", hProcess, "Ptr", remote
        , "UPtr", codeSize, "UInt", 0x20, "UInt*", oldProtect))
    {
        reason := "VirtualProtectEx:" . A_LastError
        DllCall("Kernel32\VirtualFreeEx", "Ptr", hProcess, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        RemoteCallBusy := false
        return false
    }
    DllCall("Kernel32\FlushInstructionCache", "Ptr", hProcess, "Ptr", remote, "UPtr", codeSize)
    thread := DllCall("Kernel32\CreateRemoteThread", "Ptr", hProcess, "Ptr", 0, "UPtr", 0
        , "Ptr", remote, "Ptr", 0, "UInt", 0, "UInt*", threadId, "Ptr")
    if (!thread)
    {
        reason := "CreateRemoteThread:" . A_LastError
        DllCall("Kernel32\VirtualFreeEx", "Ptr", hProcess, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        RemoteCallBusy := false
        return false
    }
    waitResult := DllCall("Kernel32\WaitForSingleObject", "Ptr", thread, "UInt", timeoutMs, "UInt")
    if (waitResult = 0)
    {
        DllCall("Kernel32\CloseHandle", "Ptr", thread)
        DllCall("Kernel32\VirtualFreeEx", "Ptr", hProcess, "Ptr", remote, "UPtr", 0, "UInt", 0x8000)
        reason := "ok"
        RemoteCallBusy := false
        return true
    }
    ; Do not unlock while the old thread may still be using pathfinding state.
    ; A later call polls/reaps it before any new remote call is allowed.
    RemotePendingThread := thread
    RemotePendingBuffer := remote
    reason := (waitResult = 0x102) ? "timeout-pending" : "wait-failed-pending"
    return false
}

ReapPendingRemoteCall()
{
    global hProcess, RemoteCallBusy, RemotePendingThread, RemotePendingBuffer
    if (!RemoteCallBusy)
        return true
    if (!RemotePendingThread)
        return false
    waitResult := DllCall("Kernel32\WaitForSingleObject", "Ptr", RemotePendingThread, "UInt", 0, "UInt")
    if (waitResult != 0)
        return false
    DllCall("Kernel32\CloseHandle", "Ptr", RemotePendingThread)
    if (hProcess && RemotePendingBuffer)
        DllCall("Kernel32\VirtualFreeEx", "Ptr", hProcess, "Ptr", RemotePendingBuffer
            , "UPtr", 0, "UInt", 0x8000)
    RemotePendingThread := 0
    RemotePendingBuffer := 0
    RemoteCallBusy := false
    return true
}

ConfigureBuiltinHelper(range, targetedMode := false, pickupMode := true)
{
    global BuiltinHelperBase
    if (!RestoreBuiltinHelperConfig())
        return false
    if (!WriteDword(BuiltinHelperBase + 0x1C, range))
        return false
    if (targetedMode)
    {
        ; Tat "return to original position" de Helper khong keo nhan vat
        ; quay lai diem vao thanh trong luc dang bam theo boss o xa.
        if (!WriteByte(BuiltinHelperBase + 0x21, 0)
            || !WriteDword(BuiltinHelperBase + 0x24, 0))
            return false
    }
    if (!WriteDword(BuiltinHelperBase + 0x70, 10))
        return false
    GuiControlGet, lootOn,, LootAfterKill
    pickupEnabled := (pickupMode && lootOn) ? 1 : 0
    if (!WriteByte(BuiltinHelperBase + 0x74, pickupEnabled)
        || !WriteByte(BuiltinHelperBase + 0x75, pickupEnabled))
        return false
    if (!WriteDword(BuiltinHelperBase + 0xB8, 0xFFFFFFFF))
        return false
    return true
}

EnterBuiltinMode(mode, targetIndex := -1, expectedGeneration := -1)
{
    global BuiltinMode, BuiltinAttackRange, BuiltinHelperBase, HelperTransitionBusy
    global HelperCleanupFault
    if (HelperTransitionBusy || !IsHuntTokenValid(expectedGeneration))
        return false
    HelperTransitionBusy := true
    Critical, On
    if (!IsHuntTokenValid(expectedGeneration))
    {
        HelperTransitionBusy := false
        Critical, Off
        return false
    }
    ok := ReadBuiltinHelperActive(active)
    if (ok && BuiltinMode = mode && active)
    {
        if (mode = "target")
            ok := ForceBuiltinTarget(targetIndex)
        HelperTransitionBusy := false
        Critical, Off
        return ok
    }
    if (ok && active)
        ok := StopBuiltinHelper()
    else if (ok && !active && BuiltinMode != "")
        Sleep, 80
    if (!ok)
    {
        HelperTransitionBusy := false
        Critical, Off
        return false
    }
    if (mode = "target")
    {
        ; Range 0 prevents the selector from briefly choosing a normal nearby
        ; mob while Start() resets B8. A forced Key still bypasses that selector;
        ; this build keeps a minimum native path radius internally.
        ok := ConfigureBuiltinHelper(0, true, false)
    }
    else if (mode = "loot")
        ok := ConfigureBuiltinHelper(0, false, true)
    else if (mode = "wave")
        ok := ConfigureBuiltinHelper(BuiltinAttackRange, false, true)
    else
        ok := false
    if (ok)
        ok := StartBuiltinHelper()
    if (ok && mode = "target")
        ok := ForceBuiltinTarget(targetIndex)
    if (ok)
    {
        BuiltinMode := mode
        HelperCleanupFault := false
    }
    else
    {
        cleanupOk := ReadBuiltinHelperActive(rollbackActive)
        if (cleanupOk && rollbackActive)
            cleanupOk := StopBuiltinHelper()
        else if (cleanupOk)
            Sleep, 80
        if (cleanupOk)
            cleanupOk := WriteDword(BuiltinHelperBase + 0xB8, 0xFFFFFFFF)
                && RestoreBuiltinHelperConfig()
        ; Keep a non-empty dirty marker if cleanup failed so Stop/Detach will
        ; retry rather than forgetting that Helper config may be modified.
        BuiltinMode := cleanupOk ? "" : "fault"
        HelperCleanupFault := !cleanupOk
    }
    HelperTransitionBusy := false
    Critical, Off
    return ok
}

BuiltinHuntTick(expectedGeneration := -1)
{
    global CurrentTarget, CurrentTargetMonsterIndex, CharactersBase, CharacterStride, HeroPtr
    global TargetEventCountAtSelection, CurrentEventMonsterCount, CurrentAllowedMonsterCount
    global KilledOnCurrentEvent, NoMonsterSince, PatrolStep
    global BuiltinPostKillUntil, BuiltinLootHardDeadline, BuiltinLootLastSeen, LastGroundItemScan
    global GroundItemsPresent, BuiltinMode, BuiltinApproachDistance
    global LastBuiltinMove
    global CurrentEventRow, CurrentEventMap, LastTravelAttempt, SafeZoneEscapeActive
    global PatrolExploredSectors
    global NativeLastHeroX, NativeLastHeroY, NativeLastProgressTick
    global NativeFallbackUntil, NativeBestDistance, NativeLastCloserTick
    global AtlansEscapeStage, AtlansStage3Since, AtlansDwellSince
    global EventArrivedTick, SingleBossScanGraceMs, CompletedEventRows
    global HonThachWaveWaitUntil, HonThachHelperHoldMs, HonThachWaveKills
    global PeerReservedMonsterSeen

    if (!IsHuntTokenValid(expectedGeneration))
        return
    if (!ResolveCharacterMemory())
    {
        SetHuntStatus("Khong doc duoc Hero/monster cua game.", "CC0000")
        return
    }
    ; Start the five-minute clock immediately after arriving/restarting on
    ; Atlans, even if a monster is already streamed and selected at once.
    if ((CurrentEventRow = 9 || CurrentEventRow = 16) && AtlansEscapeStage = 0)
        InitializeAtlansRotationFromPosition(false)

    ; Boss vua chet - nhat do
    if (CurrentTarget >= 0 && !IsMonsterAlive(CurrentTarget, false))
    {
        lostTarget := CurrentTarget
        lostMonsterIndex := CurrentTargetMonsterIndex
        if (lostMonsterIndex < 0)
            ReadWord(CharactersBase + lostTarget * CharacterStride + 0x7C, lostMonsterIndex)
        lostHonThachBoss := (CurrentEventRow = 17 && lostMonsterIndex = 700)
        confirmedKill := IsConfirmedTargetDeath(lostTarget, TargetEventCountAtSelection)
        ; This server can recycle the Hon Thach slot before its dead flag/event
        ; counter becomes observable. Only index 700 is a wave boss; ordinary
        ; monsters on this map must not trigger a new 15-second wait.
        if (lostHonThachBoss && !confirmedKill)
            confirmedKill := true
        if (!IsHuntTokenValid(expectedGeneration))
            return
        CurrentTarget := -1
        CurrentTargetMonsterIndex := -1
        TargetEventCountAtSelection := -1
        if (confirmedKill)
        {
            KilledOnCurrentEvent += 1
            if (lostHonThachBoss)
            {
                HonThachWaveKills += 1
            }
        }
        NoMonsterSince := A_TickCount
        PatrolStep := 0
        BuiltinLootLastSeen := 0
        LastGroundItemScan := 0
        GroundItemsPresent := false
        ; Hon Thach waves spawn beside the previous boss. Leave native Helper
        ; fully active so it can acquire, attack and pick up the nearby wave.
        ; HuntLoop still scans every 100 ms; when it sees the new boss it takes
        ; over with the exact forced target and rearms this window after death.
        if (lostHonThachBoss && HonThachWaveKills > 0)
        {
            HonThachWaveWaitUntil := A_TickCount + HonThachHelperHoldMs
            BuiltinPostKillUntil := 0
            BuiltinLootHardDeadline := 0
            helperWaveOk := EnterBuiltinMode("wave", -1, expectedGeneration)
            SetHuntStatus("Hon Thach da chet - MU Helper cho boss moi gan day trong 15s..."
                , helperWaveOk ? "0077AA" : "CC0000")
            return
        }
        GuiControlGet, lootOn,, LootAfterKill
        if (lootOn && confirmedKill)
        {
            BuiltinPostKillUntil := A_TickCount + 1500
            BuiltinLootHardDeadline := A_TickCount + 15000
            helperLootOk := EnterBuiltinMode("loot", -1, expectedGeneration)
            SetHuntStatus((confirmedKill ? "Boss da chet" : "Boss mat slot")
                . (helperLootOk ? " - MU Helper dang tu nhat vat pham..."
                    : " - khong khoi dong duoc Helper nhat do."), helperLootOk ? "CC7700" : "CC0000")
        }
        else
        {
            ReleaseTargetClaim()
            BuiltinPostKillUntil := 0
            BuiltinLootHardDeadline := 0
            if (!PrepareNativeMovement(expectedGeneration))
                SetHuntStatus("Boss mat slot nhung khong dung duoc MU Helper.", "CC0000")
            else
                SetHuntStatus((confirmedKill ? "Boss da chet" : "Boss mat slot")
                    . (confirmedKill ? " - dang quet boss tiep theo..."
                        : " - quet lai ngay, khong nhat mu."), "008000")
        }
        return
    }

    if (BuiltinPostKillUntil)
    {
        if (A_TickCount - LastGroundItemScan >= 100)
        {
            GroundItemsPresent := HasVisibleGroundItems()
            LastGroundItemScan := A_TickCount
            if (GroundItemsPresent)
                BuiltinLootLastSeen := A_TickCount
        }
        keepLooting := (A_TickCount < BuiltinLootHardDeadline)
            && ((A_TickCount < BuiltinPostKillUntil) || GroundItemsPresent
            || (BuiltinLootLastSeen && A_TickCount - BuiltinLootLastSeen < 700))
        if (keepLooting)
        {
            if (!ReadBuiltinHelperActive(helperActive)
                || (!helperActive && !EnterBuiltinMode("loot", -1, expectedGeneration)))
            {
                SetHuntStatus("Loi MU Helper khi nhat; dang thu khoi dong lai che do tu nhat.", "CC0000")
                return
            }
            SetHuntStatus("Dang nhat do...", "CC7700")
            return
        }
        if (!PrepareNativeMovement(expectedGeneration))
        {
            SetHuntStatus("Khong ket thuc duoc che do nhat cua MU Helper; se thu lai.", "CC0000")
            return
        }
        BuiltinPostKillUntil := 0
        BuiltinLootHardDeadline := 0
        ReleaseTargetClaim()
        NoMonsterSince := A_TickCount
        SetHuntStatus("Da nhat het - dang quet tiep...", "008000")
    }

    if (CurrentTarget < 0)
    {
        waitingHonThachWave := (CurrentEventRow = 17 && HonThachWaveKills > 0
            && HonThachWaveWaitUntil && A_TickCount < HonThachWaveWaitUntil)
        if (waitingHonThachWave)
            foundTarget := FindNearestMonster(true)
        else if (CurrentEventRow = 17 && HonThachWaveKills > 0)
        {
            ; The nearby-wave grace period ended. This does not finish the map:
            ; restore native movement and resume the all-monster patrol.
            if (!PrepareNativeMovement(expectedGeneration))
            {
                SetHuntStatus("Khong dung duoc Helper de tiep tuc quet map Hon Thach.", "CC0000")
                return
            }
            HonThachWaveWaitUntil := 0
            HonThachWaveKills := 0
            ReleaseTargetClaim()
            NoMonsterSince := A_TickCount
            PatrolStep := 0
            ResetPatrolRoute()
            SetHuntStatus("Hon Thach: het 15s cho wave - tiep tuc quet tat ca monster trong map.", "008000")
            return
        }
        else
            foundTarget := FindNearestMonster()
        if (!IsHuntTokenValid(expectedGeneration))
            return
        if (foundTarget >= 0 && !AcquireTargetClaim(foundTarget))
        {
            PeerReservedMonsterSeen := true
            foundTarget := -1
        }
        CurrentTarget := foundTarget
        if (CurrentTarget < 0)
        {
            if (!NoMonsterSince)
                NoMonsterSince := A_TickCount
            if (PeerReservedMonsterSeen)
            {
                NoMonsterSince := A_TickCount
                if (IsSingleBossEvent(CurrentEventRow) || waitingHonThachWave)
                {
                    SetHuntStatus("Boss/quai nay dang do acc khac xu ly - dung tranh muc tieu.", "0077AA")
                    return
                }
                if (!PrepareNativeMovement(expectedGeneration))
                    return
                PatrolForMonsters(expectedGeneration)
                SetHuntStatus("Acc khac dang xu ly cum quai gan day - chuyen sang sector rieng.", "0077AA")
                return
            }
            if (waitingHonThachWave)
            {
                remain := Ceil((HonThachWaveWaitUntil - A_TickCount) / 1000.0)
                helperWaveOk := EnterBuiltinMode("wave", -1, expectedGeneration)
                SetHuntStatus("Hon Thach: da giet " . HonThachWaveKills
                    . " luot - Helper dang cho boss gan day (" . remain . "s)..."
                    , helperWaveOk ? "0077AA" : "CC0000")
                return
            }
            if (IsSingleBossEvent(CurrentEventRow))
            {
                elapsed := EventArrivedTick ? A_TickCount - EventArrivedTick : 0
                if (!EventArrivedTick || elapsed < SingleBossScanGraceMs)
                {
                    remainMs := Max(0, SingleBossScanGraceMs - elapsed)
                    SetHuntStatus("Boss don: dung tai diem den, cho client quet "
                        . Ceil(remainMs / 1000.0) . "s...", "0077AA")
                    return
                }
                if (!PrepareNativeMovement(expectedGeneration))
                {
                    SetHuntStatus("Khong dung duoc Helper truoc khi bo qua boss don.", "CC0000")
                    return
                }
                CompletedEventRows[CurrentEventRow] := true
                CurrentAllowedMonsterCount := 0
                ResetPatrolRoute()
                SetHuntStatus("Khong thay boss quanh diem dich chuyen; coi nhu da chet, chuyen su kien.", "008000")
                return
            }
            if (!PrepareNativeMovement(expectedGeneration))
            {
                SetHuntStatus("Khong dung duoc MU Helper de chuyen sang tim duong.", "CC0000")
                return
            }
            if (!ReadByte(HeroPtr + 0x12, safeZone))
            {
                SetHuntStatus("Khong doc duoc trang thai SafeZone; khong khoi dong Helper.", "CC0000")
                return
            }
            if (safeZone = 0 && ReadInt(HeroPtr + 0xA8, safeX)
                && ReadInt(HeroPtr + 0xAC, safeY) && IsTerrainRestricted(safeX, safeY, true))
                safeZone := 1
            if ((CurrentEventRow = 9 || CurrentEventRow = 16)
                && (safeZone != 0 || SafeZoneEscapeActive || AtlansEscapeStage > 0
                || (NoMonsterSince && A_TickCount - NoMonsterSince >= 3000)))
            {
                HandleSafeZoneEscape(expectedGeneration)
                return
            }
            ; For ordinary maps, patrol A* may cross SafeZone to connect all
            ; outside fields. Its goals are always attack-valid tiles. Atlans
            ; keeps the dedicated M/escape flow above.
            if (safeZone != 0)
                SafeZoneEscapeActive := false
            if (SafeZoneEscapeActive)
            {
                NoMonsterSince := A_TickCount
                ResetPatrolRoute()
            }
            SafeZoneEscapeActive := false
            PatrolForMonsters(expectedGeneration)
            return
        }
        NoMonsterSince := 0
        if (CurrentEventRow = 17)
            HonThachWaveWaitUntil := 0
        selectedAddress := CharactersBase + CurrentTarget * CharacterStride
        if (!ReadWord(selectedAddress + 0x7C, CurrentTargetMonsterIndex))
            CurrentTargetMonsterIndex := -1
        if (GetAllowedEventRemainingCount(CurrentEventRow, allowedAtSelection))
        {
            TargetEventCountAtSelection := allowedAtSelection
            CurrentAllowedMonsterCount := allowedAtSelection
        }
        else
            TargetEventCountAtSelection := CurrentEventMonsterCount
        PatrolStep := 0
        ResetPatrolRoute()
        NativeLastHeroX := -1
        NativeLastHeroY := -1
        NativeLastProgressTick := A_TickCount
        NativeFallbackUntil := 0
        NativeBestDistance := 0x7FFFFFFF
        NativeLastCloserTick := A_TickCount
        SafeZoneEscapeActive := false
        if (CurrentEventRow = 9 || CurrentEventRow = 16)
        {
            AtlansStage3Since := 0
            ; Keep the five-minute dwell clock running while fighting multiple
            ; monsters. Rotation is checked only after the scanner is clear.
        }
        else
            AtlansEscapeStage := 0
    }

    address := CharactersBase + CurrentTarget * CharacterStride
    if (!ReadInt(HeroPtr + 0xA8, heroX) || !ReadInt(HeroPtr + 0xAC, heroY)
        || !ReadInt(address + 0xA8, monsterX) || !ReadInt(address + 0xAC, monsterY))
    {
        SetHuntStatus("Chua doc duoc toa do quai.", "CC0000")
        return
    }

    dx := Abs(monsterX - heroX)
    dy := Abs(monsterY - heroY)
    distance := Max(dx, dy)
    if (!ReadByte(HeroPtr + 0x12, safeZone))
    {
        PrepareNativeMovement(expectedGeneration)
        SetHuntStatus("Mat trang thai SafeZone; tam dung handoff cho MU Helper.", "CC0000")
        return
    }
    if (safeZone = 0 && IsTerrainRestricted(heroX, heroY, true))
        safeZone := 1

    if (NativeLastHeroX != heroX || NativeLastHeroY != heroY)
    {
        NativeLastHeroX := heroX
        NativeLastHeroY := heroY
        NativeLastProgressTick := A_TickCount
    }
    if (distance < NativeBestDistance)
    {
        NativeBestDistance := distance
        NativeLastCloserTick := A_TickCount
    }

    ; MU Helper tu stop trong SafeZone. Goi truc tiep pathfinder cua no toi
    ; toa do boss; game se tu tim cua ra thay vi click man hinh/phong doan.
    if (safeZone != 0)
    {
        if (!PrepareNativeMovement(expectedGeneration))
        {
            SetHuntStatus("Khong dung duoc Helper trong SafeZone.", "CC0000")
            return
        }
        if (A_TickCount - NativeLastCloserTick >= 5000)
        {
            if (A_TickCount - LastBuiltinMove >= 900)
            {
                WalkOutOfSafeZone(expectedGeneration)
                LastBuiltinMove := A_TickCount
            }
            SetHuntStatus("Duong thang toi boss bi ket; A* dang tim cua ra SafeZone.", "CC7700")
            return
        }
        if (A_TickCount - LastBuiltinMove >= 900)
        {
            if (!CallBuiltinTerrainStep(heroX, heroY, monsterX, monsterY, 8, expectedGeneration))
                WalkOutOfSafeZone(expectedGeneration)
            LastBuiltinMove := A_TickCount
        }
        SetHuntStatus("Da thay boss (" . monsterX . "," . monsterY
            . ") - pathfinder dang dua nhan vat ra khoi SafeZone...", "0077AA")
        return
    }

    ; Neu Helper bi ket tren duong dai/maze, cho direct pathfinder mot khoang
    ; ngan roi giao lai target cho Helper.
    if (NativeFallbackUntil > A_TickCount && distance > BuiltinApproachDistance)
    {
        if (!PrepareNativeMovement(expectedGeneration))
        {
            SetHuntStatus("Khong chuyen duoc sang duong A* du phong.", "CC0000")
            return
        }
        if (A_TickCount - LastBuiltinMove >= 900)
        {
            CallBuiltinTerrainStep(heroX, heroY, monsterX, monsterY, 8, expectedGeneration)
            LastBuiltinMove := A_TickCount
        }
        SetHuntStatus("Dang tai lap duong native toi boss (" . monsterX . "," . monsterY . ")...", "0077AA")
        return
    }
    if (distance <= BuiltinApproachDistance)
        NativeFallbackUntil := 0

    ; First use the client's native pathfinder to reach the exact boss tile
    ; (or an adjacent collision-valid tile). Only then start combat Helper;
    ; otherwise ranged skills can make Helper stop several tiles too early.
    if (BuiltinMode != "target" && distance > BuiltinApproachDistance)
    {
        if (!PrepareNativeMovement(expectedGeneration))
        {
            SetHuntStatus("Khong chuyen duoc sang A* de ap sat boss.", "CC0000")
            return
        }
        if (A_TickCount - LastBuiltinMove >= 900)
        {
            if (!CallBuiltinTerrainStep(heroX, heroY, monsterX, monsterY, 8, expectedGeneration))
            {
                SetHuntStatus("A* chua tim duoc buoc ap sat boss; dang thu lai.", "CC7700")
                LastBuiltinMove := A_TickCount
                return
            }
            LastBuiltinMove := A_TickCount
        }
        SetHuntStatus("Dang ap sat dung toa do boss (" . monsterX . "," . monsterY
            . ") | con " . distance . " tile.", "0077AA")
        return
    }

    ; Scanner toan map chon boss; target mode range 0 va force Key vao B8.
    if (!EnterBuiltinMode("target", CurrentTarget, expectedGeneration))
    {
        SetHuntStatus("Khong khoi dong duoc loi MU Helper.", "CC0000")
        return
    }
    if (distance > BuiltinApproachDistance
        && (A_TickCount - NativeLastProgressTick >= 5000
            || A_TickCount - NativeLastCloserTick >= 5000))
    {
        if (!PrepareNativeMovement(expectedGeneration))
        {
            SetHuntStatus("Helper bi ket nhung khong chuyen duoc sang A*.", "CC0000")
            return
        }
        CallBuiltinTerrainStep(heroX, heroY, monsterX, monsterY, 8, expectedGeneration)
        LastBuiltinMove := A_TickCount
        NativeFallbackUntil := A_TickCount + 3000
        NativeLastProgressTick := A_TickCount
        SetHuntStatus("Helper bi ket - dang tai lap duong toi boss...", "CC7700")
        return
    }

    SetHuntStatus("MU Helper dang bam dung boss (" . monsterX . "," . monsterY
        . ") | khoang cach " . distance . " tile.", "008000")
}

; ========== NAVIGATION ==========
GetMonsterScreenPosition(index, ByRef x, ByRef y)
{
    global CharactersBase, CharacterStride, HeroPtr, GameHwnd
    address := CharactersBase + index * CharacterStride
    VarSetCapacity(rect, 16, 0)
    if (!DllCall("GetClientRect", "Ptr", GameHwnd, "Ptr", &rect))
        return false
    width := NumGet(rect, 8, "Int")
    height := NumGet(rect, 12, "Int")
    if (ReadShort(address + 0x3B0, internalX) && ReadShort(address + 0x3B2, internalY)
        && internalX > 0 && internalY > 0 && internalX < 640 && internalY < 480)
    {
        x := Round(internalX * width / 640.0)
        y := Round(internalY * height / 480.0)
        return (x >= 2 && y >= 2 && x < width - 2 && y < height - 2)
    }
    if (!ReadInt(HeroPtr + 0xA8, heroX) || !ReadInt(HeroPtr + 0xAC, heroY)
        || !ReadInt(address + 0xA8, monsterX) || !ReadInt(address + 0xAC, monsterY))
        return false
    dx := monsterX - heroX
    dy := monsterY - heroY
    x := Round(width / 2.0 + (dx - dy) * width / 53.0)
    y := Round(height / 2.0 + (dx + dy) * height / 62.0 - height / 24.0)
    return (x >= 2 && y >= 2 && x < width - 2 && y < height - 2)
}

IsMonsterVisible(index)
{
    global CharactersBase, CharacterStride
    address := CharactersBase + index * CharacterStride
    return (ReadByte(address + 0x391, visible) && visible = 1)
}

NavigateToTarget(index, expectedGeneration := -1)
{
    global CharactersBase, CharacterStride, HeroPtr, GameHwnd, LastApproachClick
    global NavPath, NavPathPos, NavTargetX, NavTargetY, LastNavCompute
    if (!IsHuntTokenValid(expectedGeneration))
        return false
    address := CharactersBase + index * CharacterStride
    if (!ReadInt(HeroPtr + 0xA8, heroX) || !ReadInt(HeroPtr + 0xAC, heroY)
        || !ReadInt(address + 0xA8, monsterX) || !ReadInt(address + 0xAC, monsterY))
        return false
    dxBoss := Abs(monsterX - heroX), dyBoss := Abs(monsterY - heroY)
    if (dxBoss <= 1 && dyBoss <= 1)
        return true
    if (IsMonsterVisible(index))
        return MoveCloseToTarget(index, expectedGeneration)

    needPath := (NavTargetX != monsterX || NavTargetY != monsterY || !IsObject(NavPath)
        || NavPath.Length() = 0 || A_TickCount - LastNavCompute > 10000)
    if (needPath)
    {
        SetHuntStatus("Da thay boss tai (" . monsterX . "," . monsterY
            . ") - dang tinh duong A*...", "0077AA")
        if (!BuildTerrainPath(heroX, heroY, monsterX, monsterY, newPath))
        {
            ; Fallback: di truc tiep bang click
            MoveHeroTowards(monsterX, monsterY, heroX, heroY, expectedGeneration)
            LastNavCompute := A_TickCount
            return false
        }
        if (!IsHuntTokenValid(expectedGeneration))
            return false
        NavPath := newPath
        NavPathPos := 1
        NavTargetX := monsterX, NavTargetY := monsterY
        LastNavCompute := A_TickCount
    }

    while (NavPathPos <= NavPath.Length())
    {
        node := NavPath[NavPathPos]
        if (Abs(node[1] - heroX) <= 1 && Abs(node[2] - heroY) <= 1)
            NavPathPos += 1
        else
            break
    }
    if (NavPathPos > NavPath.Length())
        return false

    waypoint := NavPath[NavPathPos]
    probe := NavPathPos
    while (probe <= NavPath.Length())
    {
        candidate := NavPath[probe]
        if (Abs(candidate[1] - heroX) > 6 || Abs(candidate[2] - heroY) > 6)
            break
        waypoint := candidate
        probe += 1
    }
    if (A_TickCount - LastApproachClick < 500)
        return false
    MoveHeroTowards(waypoint[1], waypoint[2], heroX, heroY, expectedGeneration)
    SetHuntStatus("Dang di A* den boss (" . monsterX . "," . monsterY . ") | hien tai ("
        . heroX . "," . heroY . ")...", "0077AA")
    return false
}

MoveCloseToTarget(index, expectedGeneration := -1)
{
    global CharactersBase, CharacterStride, HeroPtr, LastApproachClick
    if (!IsHuntTokenValid(expectedGeneration))
        return false
    address := CharactersBase + index * CharacterStride
    if (!ReadInt(HeroPtr + 0xA8, heroX) || !ReadInt(HeroPtr + 0xAC, heroY)
        || !ReadInt(address + 0xA8, monsterX) || !ReadInt(address + 0xAC, monsterY))
        return false
    dx := Abs(monsterX - heroX), dy := Abs(monsterY - heroY)
    if (dx <= 1 && dy <= 1)
        return true
    if (A_TickCount - LastApproachClick < 350)
        return false
    if (!CallBuiltinTerrainStep(heroX, heroY, monsterX, monsterY, 8, expectedGeneration))
        return false
    LastApproachClick := A_TickCount
    SetHuntStatus("Dang tien sat quai (lech " . dx . "," . dy . " tile)...", "0077AA")
    return false
}

; ========== PATHFINDING (A*) ==========
LoadTerrainBuffer()
{
    global hProcess, TerrainWallAddress, TerrainBuffer
    static lastLoadTick := 0, lastHandle := 0, lastOk := false
    if (!hProcess)
        return false
    if (lastOk && lastHandle = hProcess && A_TickCount - lastLoadTick < 250)
        return true
    VarSetCapacity(TerrainBuffer, 131072, 0), got := 0
    ; In this exact build 0x0BCD4DD8 is the UShort[256*256] buffer itself,
    ; not a pointer variable (verified from live bytes).
    lastOk := DllCall("Kernel32\ReadProcessMemory", "Ptr", hProcess, "Ptr", TerrainWallAddress
        , "Ptr", &TerrainBuffer, "UPtr", 131072, "UPtr*", got) && got = 131072
    lastHandle := hProcess
    lastLoadTick := A_TickCount
    return lastOk
}

CallBuiltinTerrainStep(startX, startY, targetX, targetY, maxNodes := 8
    , expectedGeneration := -1)
{
    global CurrentEventRow
    static cachedPath := [], cachedTargetX := -1, cachedTargetY := -1
    static cachedTick := 0, cachedEventRow := -1, cachedPathPos := 1
    if (!IsHuntTokenValid(expectedGeneration))
        return false
    needPath := !IsObject(cachedPath) || cachedPath.Length() = 0
        || cachedTargetX != targetX || cachedTargetY != targetY
        || cachedEventRow != CurrentEventRow
        || A_TickCount - cachedTick >= 2500
    if (needPath)
    {
        if (!BuildTerrainPath(startX, startY, targetX, targetY, newPath))
        {
            ; A very short native call can still work when the terrain snapshot
            ; changes between frames; never send a long blind destination.
            return (Max(Abs(targetX-startX), Abs(targetY-startY)) <= 10)
                ? CallBuiltinDirectMove(targetX, targetY, expectedGeneration) : false
        }
        if (!IsHuntTokenValid(expectedGeneration))
            return false
        cachedPath := newPath
        cachedTargetX := targetX
        cachedTargetY := targetY
        cachedEventRow := CurrentEventRow
        cachedTick := A_TickCount
        cachedPathPos := 1
    }

    ; Keep the cursor monotonic and only probe a short forward window. Searching
    ; the entire cached A* path can jump across a nearby U-turn/wall segment.
    nearestPos := cachedPathPos, nearestScore := 0x7FFFFFFF
    maxProbe := Min(cachedPath.Length(), cachedPathPos + 24)
    pos := cachedPathPos
    while (pos <= maxProbe)
    {
        node := cachedPath[pos]
        score := (node[1]-startX)*(node[1]-startX) + (node[2]-startY)*(node[2]-startY)
        if (score < nearestScore)
            nearestScore := score, nearestPos := pos
        pos += 1
    }
    cachedPathPos := Max(cachedPathPos, nearestPos)
    while (cachedPathPos <= cachedPath.Length())
    {
        node := cachedPath[cachedPathPos]
        if (Abs(node[1]-startX) <= 2 && Abs(node[2]-startY) <= 2)
            cachedPathPos += 1
        else
            break
    }
    if (cachedPathPos > cachedPath.Length())
        return true
    chunkPos := Min(cachedPath.Length(), cachedPathPos + Max(1, maxNodes) - 1)
    chunk := cachedPath[chunkPos]
    return CallBuiltinDirectMove(chunk[1], chunk[2], expectedGeneration)
}

BuildSafeZoneExitPath(startX, startY, ByRef resultPath)
{
    resultPath := []
    if (!LoadTerrainBuffer() || startX < 0 || startX > 255 || startY < 0 || startY > 255)
        return false
    start := startY * 256 + startX
    queue := [start], head := 1
    visited := {}, came := {}, depth := {}, outsideRun := {}
    visited[start] := true
    depth[start] := 0
    outsideRun[start] := IsTerrainRestricted(startX, startY) ? 0 : 1
    goal := -1
    dirs := [[1,0],[-1,0],[0,1],[0,-1]]
    while (head <= queue.Length())
    {
        current := queue[head]
        head += 1
        cx := Mod(current, 256), cy := Floor(current / 256)
        ; Go several tiles beyond the boundary so the helper is not stopped
        ; again by an adjacent SafeZone/NoAttack tile.
        if (outsideRun[current] >= 8)
        {
            goal := current
            break
        }
        for _, d in dirs
        {
            nx := cx + d[1], ny := cy + d[2]
            if (nx < 1 || nx > 254 || ny < 1 || ny > 254 || IsTerrainBlocked(nx, ny))
                continue
            next := ny * 256 + nx
            if (visited.HasKey(next))
                continue
            visited[next] := true
            came[next] := current
            depth[next] := depth[current] + 1
            outsideRun[next] := IsTerrainRestricted(nx, ny) ? 0 : outsideRun[current] + 1
            queue.Push(next)
        }
    }
    if (goal < 0)
        return false
    reverse := [], cur := goal
    reverse.Push([Mod(cur, 256), Floor(cur / 256)])
    while (cur != start)
    {
        if (!came.HasKey(cur))
            return false
        cur := came[cur]
        reverse.Push([Mod(cur, 256), Floor(cur / 256)])
    }
    Loop, % reverse.Length()
        resultPath.Push(reverse[reverse.Length() - A_Index + 1])
    return (resultPath.Length() > 1)
}

BuildTerrainPath(startX, startY, targetX, targetY, ByRef resultPath, avoidRestricted := false)
{
    resultPath := []
    if (startX < 0 || startX > 255 || startY < 0 || startY > 255
        || targetX < 0 || targetX > 255 || targetY < 0 || targetY > 255)
        return false
    if (!LoadTerrainBuffer())
        return false
    ; Engine::GetTerrainIndex = (Y << 8) + X for this build.
    if (!FindNearestWalkableGoal(startX, startY, targetX, targetY, goalX, goalY, avoidRestricted))
        return false
    start := startY * 256 + startX
    goal := goalY * 256 + goalX
    openNode := [], openF := [], gScore := {}, came := {}, closed := {}
    gScore[start] := 0
    HeapPush(openNode, openF, start, NavHeuristic(startX, startY, goalX, goalY))
    expanded := 0
    dirs := [[1,0,10],[-1,0,10],[0,1,10],[0,-1,10]
        ,[1,1,14],[1,-1,14],[-1,1,14],[-1,-1,14]]
    found := false
    while (HeapPop(openNode, openF, current, currentF))
    {
        if (closed.HasKey(current))
            continue
        closed[current] := true
        expanded += 1
        if (current = goal)
        {
            found := true
            break
        }
        if (expanded > 65536)
            break
        cx := Mod(current, 256), cy := Floor(current / 256)
        for _, d in dirs
        {
            nx := cx + d[1], ny := cy + d[2]
            if (nx < 0 || nx > 255 || ny < 0 || ny > 255 || IsTerrainBlocked(nx, ny)
                || (avoidRestricted && IsTerrainRestricted(nx, ny)))
                continue
            if (d[1] != 0 && d[2] != 0
                && (IsTerrainBlocked(cx + d[1], cy) || IsTerrainBlocked(cx, cy + d[2])
                    || (avoidRestricted && (IsTerrainRestricted(cx + d[1], cy)
                        || IsTerrainRestricted(cx, cy + d[2])))))
                continue
            next := ny * 256 + nx
            if (closed.HasKey(next))
                continue
            tentative := gScore[current] + d[3]
            if (!gScore.HasKey(next) || tentative < gScore[next])
            {
                gScore[next] := tentative
                came[next] := current
                f := tentative + NavHeuristic(nx, ny, goalX, goalY)
                HeapPush(openNode, openF, next, f)
            }
        }
    }
    if (!found)
        return false
    reverse := []
    cur := goal
    reverse.Push([Mod(cur, 256), Floor(cur / 256)])
    while (cur != start)
    {
        if (!came.HasKey(cur))
            return false
        cur := came[cur]
        reverse.Push([Mod(cur, 256), Floor(cur / 256)])
    }
    Loop, % reverse.Length()
        resultPath.Push(reverse[reverse.Length() - A_Index + 1])
    return (resultPath.Length() > 0)
}

FindNearestWalkableGoal(startX, startY, targetX, targetY, ByRef goalX, ByRef goalY
    , avoidRestricted := false)
{
    if (!IsTerrainBlocked(targetX, targetY)
        && (!avoidRestricted || !IsTerrainRestricted(targetX, targetY)))
    {
        goalX := targetX, goalY := targetY
        return true
    }
    best := 0x7FFFFFFF, found := false
    Loop, 12
    {
        radius := A_Index
        min := -radius, max := radius
        y := min
        while (y <= max)
        {
            x := min
            while (x <= max)
            {
                if (Abs(x) != radius && Abs(y) != radius)
                {
                    x += 1
                    continue
                }
                gx := targetX + x, gy := targetY + y
                if (gx >= 0 && gx <= 255 && gy >= 0 && gy <= 255
                    && !IsTerrainBlocked(gx, gy)
                    && (!avoidRestricted || !IsTerrainRestricted(gx, gy)))
                {
                    score := (gx-startX)*(gx-startX) + (gy-startY)*(gy-startY)
                    if (score < best)
                        best := score, goalX := gx, goalY := gy, found := true
                }
                x += 1
            }
            y += 1
        }
        if (found)
            return true
    }
    return false
}

IsTerrainBlocked(x, y)
{
    global TerrainBuffer
    if (x < 0 || x > 255 || y < 0 || y > 255)
        return true
    index := y * 256 + x
    wall := NumGet(TerrainBuffer, index * 2, "UShort")
    return ((wall & 4) != 0)
}

IsTerrainRestricted(x, y, refresh := false)
{
    global TerrainBuffer
    if (refresh && !LoadTerrainBuffer())
        return false
    if (x < 0 || x > 255 || y < 0 || y > 255)
        return true
    index := y * 256 + x
    wall := NumGet(TerrainBuffer, index * 2, "UShort")
    ; 0x0001 = SafeZone, 0x0100 = NoAttack custom-zone flag.
    return ((wall & 0x0101) != 0)
}

NavHeuristic(x1, y1, x2, y2)
{
    dx := Abs(x2 - x1), dy := Abs(y2 - y1)
    return 10 * Max(dx, dy) + 4 * Min(dx, dy)
}

HeapPush(ByRef nodes, ByRef scores, node, score)
{
    pos := nodes.Length() + 1
    nodes[pos] := node, scores[pos] := score
    while (pos > 1)
    {
        parent := Floor(pos / 2)
        if (scores[parent] <= score)
            break
        nodes[pos] := nodes[parent], scores[pos] := scores[parent]
        pos := parent
    }
    nodes[pos] := node, scores[pos] := score
}

HeapPop(ByRef nodes, ByRef scores, ByRef node, ByRef score)
{
    count := nodes.Length()
    if (count = 0)
        return false
    node := nodes[1], score := scores[1]
    lastNode := nodes[count], lastScore := scores[count]
    nodes.RemoveAt(count), scores.RemoveAt(count)
    count -= 1
    if (count = 0)
        return true
    pos := 1
    while (pos * 2 <= count)
    {
        child := pos * 2
        if (child < count && scores[child + 1] < scores[child])
            child += 1
        if (scores[child] >= lastScore)
            break
        nodes[pos] := nodes[child], scores[pos] := scores[child]
        pos := child
    }
    nodes[pos] := lastNode, scores[pos] := lastScore
    return true
}

; ========== GROUND ITEMS ==========
HasVisibleGroundItems()
{
    global hProcess, ItemsBase, ItemStride
    static itemBuffer, bufferReady := false
    totalSize := ItemStride * 1000
    if (!bufferReady)
    {
        VarSetCapacity(itemBuffer, totalSize, 0)
        bufferReady := true
    }
    ok := DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", ItemsBase
        , "Ptr", &itemBuffer, "UPtr", totalSize, "UPtr*", bytesRead)
    if (!ok || bytesRead != totalSize)
        return false
    Loop, 1000
    {
        offset := (A_Index - 1) * ItemStride
        if (NumGet(itemBuffer, offset + 0x7C, "UChar") = 1
            && NumGet(itemBuffer, offset + 0x85, "UChar") = 1)
            return true
    }
    return false
}

; ========== EVENT SYSTEM ==========
IsSingleBossEvent(row)
{
    ; Verified single-spawn group on this server: Viem Dia Chua, Chien Than,
    ; Ma Than Tuong and Ta Than Tuong. Their boss is streamed beside the H
    ; arrival point, so absence there means another player already killed it.
    return (row = 7 || row = 10 || row = 11 || row = 12)
}

IsEventCategoryEnabled(row)
{
    global SavedHuntSingleBoss, SavedHuntMultiBoss
    ; Hard exclusion: these rows must never be selected even if another caller
    ; asks about them directly instead of iterating PriorityEventRows.
    if (row = 1 || row = 3 || row = 4 || row = 8)
        return false
    GuiControlGet, singleBoss,, HuntSingleBoss
    if (ErrorLevel)
        singleBoss := SavedHuntSingleBoss
    GuiControlGet, multiBoss,, HuntMultiBoss
    if (ErrorLevel)
        multiBoss := SavedHuntMultiBoss
    return IsSingleBossEvent(row) ? (singleBoss != 0) : (multiBoss != 0)
}

IsOrdinaryEventRowActive(row)
{
    global OrdinaryEventBase
    ; A failed read must never make the tool abandon a delayed wave chain.
    if (!OrdinaryEventBase || row < 1 || row > 18)
        return true
    address := OrdinaryEventBase + (row - 1) * 0x90
    if (!ReadInt(address + 0x04, seconds))
        return true
    return (seconds = 0)
}

GetBestActiveEvent(ByRef foundRow, ByRef foundMap, ByRef foundCount)
{
    global OrdinaryEventBase, PriorityEventRows, CompletedEventRows, CurrentEventRow
    ; Once Hon Thach starts, finish its active map session instead of letting a
    ; newly opened row pull the character away between wave wait and patrol.
    if (CurrentEventRow = 17 && IsEventCategoryEnabled(17)
        && !CompletedEventRows.HasKey(17))
    {
        currentAddress := OrdinaryEventBase + 16 * 0x90
        if (ReadInt(currentAddress + 0x04, currentSeconds) && currentSeconds = 0
            && ReadInt(currentAddress + 0x08, currentMap) && currentMap >= 0 && currentMap <= 255
            && ReadInt(currentAddress + 0x34, currentCount))
        {
            foundRow := 17, foundMap := currentMap, foundCount := currentCount
            return true
        }
    }
    for _, row in PriorityEventRows
    {
        if (!IsEventCategoryEnabled(row))
            continue
        address := OrdinaryEventBase + (row - 1) * 0x90
        if (!ReadInt(address + 0x04, seconds) || !ReadInt(address + 0x08, mapId)
            || !ReadInt(address + 0x34, monsterCount))
            continue
        if (seconds != 0)
        {
            if (CompletedEventRows.HasKey(row))
                CompletedEventRows.Delete(row)
            continue
        }
        if (CompletedEventRows.HasKey(row) || mapId < 0 || mapId > 255
            || (monsterCount <= 0 && row != CurrentEventRow
                && row != 9 && row != 16 && row != 17))
            continue
        foundRow := row, foundMap := mapId, foundCount := monsterCount
        return true
    }
    return false
}

UpdateEventRoute(expectedGeneration := -1)
{
    global OrdinaryEventBase, CompletedEventRows, CurrentEventRow, CurrentEventMap
    global CurrentEventMonsterCount, CurrentAllowedMonsterCount, EventInitialAllowedCount
    global KilledOnCurrentEvent, NoMonsterSince, LootActive
    global PatrolStep, LastTravelAttempt
    global BuiltinPostKillUntil, SafeZoneEscapeActive, AtlansEscapeStage
    global AtlansStage3Since, AtlansWarpFailures
    global AllowedEventTypes, AllowedEventTypesRow, EventArrivedTick
    global CurrentTarget, CurrentTargetMonsterIndex
    global HuntGeneration, AtlansDwellSince, PatrolCompletedCycles
    global HonThachWaveWaitUntil, HonThachWaveKills
    if (!IsHuntTokenValid(expectedGeneration) || !EnsureOrdinaryEventTable(expectedGeneration)
        || !IsHuntTokenValid(expectedGeneration))
        return false
    ; Never interrupt Helper pickup or a delayed Hon Thach wave chain. The kill
    ; count keeps row 17 latched while its target is fought and during the quiet
    ; 15-second Helper window. HuntLoop alone clears it after that window ends.
    waitingHonThachWave := (CurrentEventRow = 17 && HonThachWaveKills > 0)
    if (LootActive || BuiltinPostKillUntil || waitingHonThachWave)
        return true
    GuiControlGet, emptyText,, MapEmptySeconds
    emptySeconds := emptyText + 0
    if (emptySeconds < 10)
        emptySeconds := 10
    if (CurrentEventRow)
    {
        persistentAllMonsterEvent := (CurrentEventRow = 9
            || CurrentEventRow = 16 || CurrentEventRow = 17)
        address := OrdinaryEventBase + (CurrentEventRow - 1) * 0x90
        ReadInt(address + 0x34, CurrentEventMonsterCount)
        remainingKnown := GetAllowedEventRemainingCount(CurrentEventRow, allowedRemaining)
        CurrentAllowedMonsterCount := remainingKnown ? allowedRemaining : -1
        if (ReadInt(address + 0x04, currentSeconds) && currentSeconds != 0)
            CompletedEventRows[CurrentEventRow] := true
        else if (!persistentAllMonsterEvent
            && EventInitialAllowedCount = 1 && KilledOnCurrentEvent > 0)
            CompletedEventRows[CurrentEventRow] := true
        ; Several event rows expose the initial spawn total and do not
        ; decrement it after a kill. A complete reachable-map patrol with no
        ; target is therefore also authoritative evidence that this instance
        ; is empty; otherwise multi-monster events would never advance.
        else if (!persistentAllMonsterEvent && ((remainingKnown && allowedRemaining <= 0)
                || (!remainingKnown && CurrentEventMonsterCount <= 0)
                || PatrolCompletedCycles > 0)
            && EventArrivedTick && NoMonsterSince
            && A_TickCount - NoMonsterSince >= emptySeconds * 1000
            && !SafeZoneEscapeActive && !(AtlansEscapeStage > 0 && AtlansEscapeStage < 3))
            CompletedEventRows[CurrentEventRow] := true
    }
    if (!GetBestActiveEvent(nextRow, nextMap, nextCount))
    {
        if (!PrepareNativeMovement(expectedGeneration))
        {
            SetHuntStatus("Khong dung duoc MU Helper khi ket thuc route su kien.", "CC0000")
            return false
        }
        CurrentEventRow := 0
        CurrentEventMap := -1
        CurrentEventMonsterCount := 0
        CurrentAllowedMonsterCount := -1
        EventInitialAllowedCount := -1
        ReleaseTargetClaim()
        CurrentTarget := -1
        CurrentTargetMonsterIndex := -1
        AllowedEventTypes := {}
        AllowedEventTypesRow := 0
        SafeZoneEscapeActive := false
        AtlansEscapeStage := 0
        AtlansStage3Since := 0
        AtlansWarpFailures := 0
        AtlansDwellSince := 0
        ResetAtlansConnectedTransit()
        HonThachWaveWaitUntil := 0
        HonThachWaveKills := 0
        HuntGeneration += 1
        return false
    }
    changed := (nextRow != CurrentEventRow)
    if (changed)
    {
        ; Cancel a HuntLoop thread that was working on the previous event.
        ReleaseTargetClaim()
        HuntGeneration += 1
        expectedGeneration := HuntGeneration
        CurrentEventRow := nextRow
        CurrentEventMap := nextMap
        CurrentEventMonsterCount := nextCount
        CurrentAllowedMonsterCount := -1
        EventInitialAllowedCount := -1
        KilledOnCurrentEvent := 0
        NoMonsterSince := A_TickCount
        PatrolStep := 0
        AllowedEventTypes := {}
        AllowedEventTypesRow := 0
        SafeZoneEscapeActive := false
        AtlansEscapeStage := 0
        AtlansStage3Since := 0
        AtlansWarpFailures := 0
        AtlansDwellSince := 0
        ResetAtlansConnectedTransit()
        HonThachWaveWaitUntil := 0
        HonThachWaveKills := 0
        EventArrivedTick := 0
        ResetPatrolRoute()
        RefreshAllowedEventTypes(true)
        if (GetAllowedEventRemainingCount(nextRow, initialAllowed))
        {
            CurrentAllowedMonsterCount := initialAllowed
            EventInitialAllowedCount := initialAllowed
        }
        else
            EventInitialAllowedCount := nextCount
        SetHuntStatus("Chon su kien: " . GetEventName(nextRow) . " - MapID " . nextMap . ".", "0077AA")
    }
    mapKnown := GetCurrentMapId(mapId)
    needTravel := changed || !EventArrivedTick || (mapKnown && mapId != CurrentEventMap)
    if (!SafeZoneEscapeActive && AtlansEscapeStage = 0 && needTravel)
    {
        if (changed || A_TickCount - LastTravelAttempt >= 15000)
            TravelToEvent(nextRow, nextMap, expectedGeneration)
    }
    return true
}

EnsureOrdinaryEventTable(expectedGeneration := -1)
{
    global GameHwnd, TravelBusy, HuntGeneration
    if (LocateOrdinaryEventTable())
        return true
    if (!GameHwnd)
        ResolveCharacterMemory()
    if (!GameHwnd || TravelBusy || !IsHuntTokenValid(expectedGeneration))
        return false
    TravelBusy := true
    AbortComboForTravel()
    generation := (expectedGeneration >= 0) ? expectedGeneration : HuntGeneration
    SetHuntStatus("Dang nhan H de doc bang su kien tu game...", "0077AA")
    panelWasOpen := IsEventPanelOpen()
    if (!OpenEventPanel(expectedGeneration))
    {
        SetHuntStatus("Khong mo/nhan dien duoc bang H; khong click mu.", "CC0000")
        TravelBusy := false
        return false
    }
    found := false
    Loop, 15
    {
        Sleep, 100
        if (expectedGeneration >= 0 && !IsHuntTokenValid(generation))
            break
        if (LocateOrdinaryEventTable())
        {
            found := true
            break
        }
    }
    if (!panelWasOpen)
        CloseEventPanel()
    TravelBusy := false
    return found
}

GetEventUiCoordinates(row, ByRef tabX, ByRef tabY, ByRef listX, ByRef listY
    , ByRef moveX, ByRef moveY, ByRef width, ByRef height)
{
    global GameHwnd
    VarSetCapacity(rect, 16, 0)
    if (!GameHwnd || !DllCall("GetClientRect", "Ptr", GameHwnd, "Ptr", &rect))
        return false
    width := NumGet(rect, 8, "Int")
    height := NumGet(rect, 12, "Int")
    if (GetEventPanelObject(eventObj)
        && ReadInt(eventObj + 0x10, objectX) && ReadInt(eventObj + 0x14, objectY)
        && ReadInt(eventObj + 0x24, buttonX) && ReadInt(eventObj + 0x28, buttonY)
        && ReadInt(eventObj + 0x2C, buttonW) && ReadInt(eventObj + 0x30, buttonH)
        && objectX >= 0 && objectX < 1000 && objectY >= 0 && objectY < 1000
        && buttonW > 0 && buttonW < 300 && buttonH > 0 && buttonH < 100)
    {
        ; The background backend writes the Engine's logical mouse coordinates
        ; directly, so do not convert these values to Windows client pixels.
        logicalWidth := 2 * objectX + 640
        logicalHeight := Round(height * logicalWidth / Max(1, width))
        tabX := Round(objectX + 48)
        tabY := Round(objectY + 49)
        listX := Round(objectX + 110)
        listY := Round(objectY + 98 + (row - 1) * 12)
        moveX := Round(buttonX + buttonW / 2.0)
        moveY := Round(buttonY + buttonH / 2.0)
    }
    else
        return false
    return (tabX >= 0 && tabX < logicalWidth && listX >= 0 && listX < logicalWidth
        && moveX >= 0 && moveX < logicalWidth && moveY >= 0 && moveY < logicalHeight)
}

GetEventPanelObject(ByRef eventObj)
{
    global EventPanelPointerAddress
    eventObj := 0
    return ReadDword(EventPanelPointerAddress, eventObj)
        && eventObj >= 0x10000 && eventObj < 0x80000000
}

IsEventPanelOpen()
{
    if (GetEventPanelObject(eventObj) && ReadByte(eventObj + 0x08, visible))
        return (visible != 0)
    return false
}

WaitEventSelection(row, timeoutMs := 1500)
{
    if (!GetEventPanelObject(eventObj))
        return false
    rawIndex := row + 11
    started := A_TickCount
    while (A_TickCount - started < timeoutMs)
    {
        if (ReadInt(eventObj + 0x1C4, selected) && selected = rawIndex)
            return true
        Sleep, 50
    }
    return false
}

WaitEventOrdinaryTab(timeoutMs := 800)
{
    if (!GetEventPanelObject(eventObj))
        return false
    started := A_TickCount
    while (A_TickCount - started < timeoutMs)
    {
        if (ReadInt(eventObj + 0x1C8, tab) && tab = 0)
            return true
        Sleep, 40
    }
    return false
}

SelectOrdinaryEventRow(row, expectedGeneration := -1)
{
    Loop, 3
    {
        if (!IsHuntTokenValid(expectedGeneration) || !IsEventPanelOpen())
            return false
        ; Re-read panel geometry on every attempt because its centered object
        ; and scrollbar finish updating asynchronously after the tab click.
        if (!GetEventUiCoordinates(row, tabX, tabY, listX, listY
            , moveX, moveY, width, height))
            return false
        if (!ClickGamePointIfCurrent(listX, listY, expectedGeneration))
            return false
        if (WaitEventSelection(row, 800))
            return true
        Sleep, 150
    }
    return false
}

CanMoveSelectedEvent(row, ByRef seconds)
{
    seconds := -1
    if (!GetEventPanelObject(eventObj))
        return false
    rawIndex := row + 11
    if (!ReadInt(eventObj + 0x1994, totalRecords) || rawIndex < 0 || rawIndex >= totalRecords
        || !ReadInt(eventObj + 0x1C4, selected) || selected != rawIndex
        || !ReadInt(eventObj + 0x1F4 + rawIndex * 0x90 + 0x04, seconds))
        return false
    ; Exact client CanMove() gate: movement opens only in the final 5 minutes.
    return (seconds >= 0 && seconds <= 299)
}

WaitEventMoveReady(row, expectedGeneration, ByRef moveX, ByRef moveY
    , ByRef seconds, timeoutMs := 2000)
{
    ; Selecting an event rebuilds the detail pane asynchronously. A click sent
    ; while that rebuild is in progress is silently swallowed by this client.
    ; Require two identical, move-enabled button samples before clicking it.
    started := A_TickCount
    stableSamples := 0
    previousX := -1, previousY := -1
    seconds := -1
    while (A_TickCount - started < timeoutMs)
    {
        if (!IsHuntTokenValid(expectedGeneration) || !IsEventPanelOpen())
            return false
        if (!CanMoveSelectedEvent(row, currentSeconds))
        {
            seconds := currentSeconds
            stableSamples := 0
            Sleep, 100
            continue
        }
        if (!GetEventUiCoordinates(row, tabX, tabY, currentX, currentY
            , currentMoveX, currentMoveY, width, height))
        {
            stableSamples := 0
            Sleep, 100
            continue
        }
        seconds := currentSeconds
        moveX := currentMoveX, moveY := currentMoveY
        if (currentMoveX = previousX && currentMoveY = previousY)
            stableSamples += 1
        else
        {
            previousX := currentMoveX, previousY := currentMoveY
            stableSamples := 1
        }
        if (stableSamples >= 2)
            return true
        Sleep, 100
    }
    return false
}

OpenEventPanel(expectedGeneration := -1)
{
    global GameHwnd
    if (!IsHuntTokenValid(expectedGeneration))
        return false
    if (IsEventPanelOpen())
        return true
    ; Hidden/background Engine windows do not run the H hotkey handler. The
    ; panel object is already constructed, so change only its own visibility
    ; byte; row/button actions still run on the target client's UI thread.
    if (GetEventPanelObject(eventObj) && WriteByte(eventObj + 0x08, 1))
    {
        Loop, 10
        {
            Sleep, 20
            if (IsEventPanelOpen())
                return true
        }
    }
    Critical, On
    if (!IsHuntTokenValid(expectedGeneration))
    {
        Critical, Off
        return false
    }
    if (!SendGameVirtualKey(0x48, 0x23, 60, expectedGeneration))
        return false
    Critical, Off
    Loop, 12
    {
        Sleep, 100
        if (!IsHuntTokenValid(expectedGeneration))
            return false
        if (IsEventPanelOpen())
            return true
    }
    return false
}

CloseEventPanel()
{
    global GameHwnd
    if (!IsEventPanelOpen())
        return true
    if (GetEventPanelObject(eventObj) && WriteByte(eventObj + 0x08, 0))
    {
        Sleep, 30
        if (!IsEventPanelOpen())
            return true
    }
    if (!SendGameVirtualKey(0x48, 0x23, 60))
        return false
    Loop, 6
    {
        Sleep, 80
        if (!IsEventPanelOpen())
            return true
    }
    ; Esc is safe here because the signature proves the H panel is open.
    SendGameVirtualKey(0x1B, 0x01, 40)
    Sleep, 120
    return !IsEventPanelOpen()
}

TravelToEvent(row, mapId, expectedGeneration := -1)
{
    global TravelBusy, LastTravelAttempt, GameHwnd, NoMonsterSince
    global CurrentTarget, CurrentTargetMonsterIndex
    global BuiltinMode, CurrentEventMap, HeroPtr, HuntGeneration, EventArrivedTick
    global SafeZoneEscapeActive, AtlansEscapeStage, AtlansStage3Since, AtlansWarpFailures
    global AtlansDwellSince
    generation := (expectedGeneration >= 0) ? expectedGeneration : HuntGeneration
    if (!IsHuntTokenValid(generation))
        return false
    if (!GameHwnd)
        ResolveCharacterMemory()
    if (TravelBusy || !GameHwnd || !IsHuntTokenValid(generation))
        return false
    TravelBusy := true
    AbortComboForTravel()
    LastTravelAttempt := A_TickCount
    ReleaseTargetClaim()
    CurrentTarget := -1
    CurrentTargetMonsterIndex := -1
    if (!PrepareNativeMovement(generation))
    {
        SetHuntStatus("Khong dung duoc MU Helper truoc khi mo bang H.", "CC0000")
        TravelBusy := false
        return false
    }
    SetHuntStatus("Dang chon " . GetEventName(row) . " va bam Di chuyen...", "0077AA")
    ; UI interaction is written directly to this Engine process; no foreground
    ; window or visible worker GUI is required.
    Sleep, 150
    if (!OpenEventPanel(generation))
    {
        TravelBusy := false
        SetHuntStatus("Khong nhan dien duoc bang H; da huy de tranh click xuong map.", "CC0000")
        return false
    }
    if (!IsHuntTokenValid(generation))
    {
        CloseEventPanel()
        TravelBusy := false
        return false
    }
    ; The panel object/rect is initialized only after H becomes visible.
    if (!GetEventUiCoordinates(row, tabX, tabY, listX, listY, moveX, moveY, width, height))
    {
        CloseEventPanel()
        TravelBusy := false
        SetHuntStatus("Da mo H nhung khong doc duoc toa do tab/dong su kien.", "CC0000")
        return false
    }
    if (!ClickGamePointIfCurrent(tabX, tabY, generation))
    {
        CloseEventPanel()
        TravelBusy := false
        return false
    }
    if (!WaitEventOrdinaryTab(800))
    {
        CloseEventPanel()
        TravelBusy := false
        SetHuntStatus("Khong chuyen duoc bang H sang tab Thuong.", "CC0000")
        return false
    }
    ; The list rebuilds after switching tabs. The final rows (17/18) are near
    ; the bottom edge and can ignore a click made against the pre-refresh rect.
    Sleep, 250
    if (!IsEventPanelOpen())
    {
        TravelBusy := false
        SetHuntStatus("Bang H mat signature sau khi chon tab; khong click tiep.", "CC0000")
        return false
    }
    if (!SelectOrdinaryEventRow(row, generation))
    {
        actualRowText := ""
        if (GetEventPanelObject(eventObj) && ReadInt(eventObj + 0x1C4, actualRaw)
            && actualRaw >= 12)
            actualRowText := " (dang chon dong " . (actualRaw - 11) . ")"
        CloseEventPanel()
        TravelBusy := false
        SetHuntStatus("Bang H khong chon dung dong " . row . actualRowText
            . "; da huy nut Di chuyen.", "CC0000")
        return false
    }
    ; Let the selected row finish rebuilding its detail pane. The old 250-ms
    ; one-shot path frequently clicked while the Move button was being replaced.
    Sleep, 500
    if (!IsHuntTokenValid(generation))
    {
        CloseEventPanel()
        TravelBusy := false
        return false
    }

    if (!IsEventPanelOpen())
    {
        TravelBusy := false
        SetHuntStatus("Khong con thay bang H truoc nut Di chuyen; da huy click.", "CC0000")
        return false
    }
    if (!WaitEventMoveReady(row, generation, moveX, moveY, moveSeconds, 2000))
    {
        CloseEventPanel()
        TravelBusy := false
        if (moveSeconds > 299)
            SetHuntStatus("Nut Di chuyen chua mo: con " . FormatEventTime(moveSeconds)
                . " (client chi cho di trong 5 phut cuoi).", "CC7700")
        else
            SetHuntStatus("Khong doc duoc trang thai nut Di chuyen cua bang H.", "CC0000")
        return false
    }
    originMap := -1
    originMapKnown := GetCurrentMapId(originMap)
    if (!ReadInt(HeroPtr + 0xA8, originX) || !ReadInt(HeroPtr + 0xAC, originY))
    {
        CloseEventPanel()
        TravelBusy := false
        SetHuntStatus("Khong doc duoc toa do truoc khi di chuyen su kien.", "CC0000")
        return false
    }
    previousX := originX, previousY := originY

    ; A background input pulse only proves that the client saw an edge; it does
    ; not prove the event handler accepted it. Retry at most three times, revalidating the
    ; selection and live button rect before every click, and require a real UI,
    ; map or character-position acknowledgement before entering the travel wait.
    moveAcknowledged := false
    moveClickTick := 0
    Loop, 3
    {
        moveAttempt := A_Index
        if (!IsHuntTokenValid(generation) || !IsEventPanelOpen()
            || !WaitEventSelection(row, 250)
            || !CanMoveSelectedEvent(row, moveSeconds)
            || !GetEventUiCoordinates(row, tabX, tabY, listX, listY
                , moveX, moveY, width, height))
            break
        SetHuntStatus("Dang bam Di chuyen (lan " . moveAttempt . "/3)...", "0077AA")
        if (!ClickGamePointIfCurrent(moveX, moveY, generation))
            break
        moveClickTick := A_TickCount
        acknowledgeDeadline := A_TickCount + 1000
        while (A_TickCount < acknowledgeDeadline && IsHuntTokenValid(generation))
        {
            if (!IsEventPanelOpen())
            {
                moveAcknowledged := true
                break
            }
            clickMapKnown := GetCurrentMapId(clickMap)
            if (originMapKnown && clickMapKnown && clickMap != originMap)
            {
                moveAcknowledged := true
                break
            }
            if (ReadInt(HeroPtr + 0xA8, clickHeroX)
                && ReadInt(HeroPtr + 0xAC, clickHeroY)
                && Abs(clickHeroX - originX) + Abs(clickHeroY - originY) >= 8)
            {
                moveAcknowledged := true
                break
            }
            Sleep, 80
        }
        if (moveAcknowledged)
            break
        Sleep, 300
    }
    if (!moveAcknowledged)
    {
        CloseEventPanel()
        TravelBusy := false
        SetHuntStatus("Nut Di chuyen khong nhan click sau 3 lan; se thu lai sau 15 giay.", "CC0000")
        return false
    }

    arrived := false
    actualMap := mapId
    deadline := A_TickCount + 15000
    while (A_TickCount < deadline && IsHuntTokenValid(generation))
    {
        Sleep, 250
        if (!ReadInt(HeroPtr + 0xA8, heroX) || !ReadInt(HeroPtr + 0xAC, heroY))
            continue
        arrivedMapKnown := GetCurrentMapId(arrivedMap)
        panelClosed := !IsEventPanelOpen()
        sampleJump := Abs(heroX - previousX) + Abs(heroY - previousY)
        expectedMap := !arrivedMapKnown || arrivedMap = mapId
        ; Several ordinary bosses use an instance map (live test: table MapID 1
        ; for Ma Than Tuong is delivered to MapID 85). After the row and Move
        ; button are memory-verified, any real MapID transition is authoritative.
        changedAfterVerifiedMove := originMapKnown && arrivedMapKnown
            && arrivedMap != originMap
        sameMapTeleport := panelClosed && expectedMap
            && ((!originMapKnown || originMap = mapId) && sampleJump >= 8)
        if (changedAfterVerifiedMove || sameMapTeleport)
        {
            if (arrivedMapKnown)
                actualMap := arrivedMap
            arrived := true
            break
        }
        previousX := heroX, previousY := heroY
    }
    if (!IsHuntTokenValid(generation))
    {
        CloseEventPanel()
        TravelBusy := false
        return false
    }
    ; Some servers intentionally no-op H when the character is already on the
    ; event map. Treat that as arrival and let terrain A*/patrol leave the city.
    if (!arrived && GetCurrentMapId(fallbackMap) && fallbackMap = mapId)
    {
        arrived := true
        actualMap := fallbackMap
    }
    if (arrived)
    {
        CurrentEventMap := actualMap
        NoMonsterSince := A_TickCount
        EventArrivedTick := A_TickCount
        SafeZoneEscapeActive := false
        AtlansEscapeStage := 0
        AtlansStage3Since := 0
        AtlansWarpFailures := 0
        AtlansDwellSince := 0
        ResetAtlansConnectedTransit()
        ResetPatrolRoute()
        RefreshAllowedEventTypes(true)
        SetHuntStatus("Da den " . GetEventName(row) . " - dang quet dung boss.", "008000")
    }
    else
    {
        CloseEventPanel()
        SetHuntStatus("Chua di chuyen duoc bang H; se thu lai sau 15 giay.", "CC0000")
    }
    TravelBusy := false
    return arrived
}

IsMapUsedByOtherActiveEvent(mapId, selectedRow)
{
    global OrdinaryEventBase
    if (!OrdinaryEventBase || mapId < 0)
        return false
    Loop, 18
    {
        row := A_Index
        if (row = selectedRow || row = 1 || row = 4 || row = 8)
            continue
        address := OrdinaryEventBase + (row - 1) * 0x90
        if (ReadInt(address + 0x04, seconds) && seconds = 0
            && ReadInt(address + 0x08, otherMap) && otherMap = mapId
            && ReadInt(address + 0x34, count) && count > 0)
            return true
    }
    return false
}

ClickGamePointIfCurrent(x, y, expectedGeneration)
{
    return SendGameMouseClick(x, y, expectedGeneration)
}

GetEventName(row)
{
    names := ["Dai Chien Loren", "Phu Thuy Trang", "Tu Than Xuong So", "Rong Do"
        , "Tho Ngoc", "Mua He", "Boss Viem Dia Chua", "Boss Class"
        , "Kho Bau Hoang Toc", "Boss Chien Than", "Boss Ma Than Tuong"
        , "Boss Ta Than Tuong", "Boss Nguu Vuong", "Boss Thuy Hoang De"
        , "Boss Anubis", "Boss Long Vuong", "Boss Hon Thach", "Boss Ma Thu"]
    return (row >= 1 && row <= names.Length()) ? names[row] : ("Su kien " . row)
}

FormatEventTime(totalSeconds)
{
    totalSeconds := Max(0, totalSeconds + 0)
    hours := Floor(totalSeconds / 3600)
    minutes := Floor(Mod(totalSeconds, 3600) / 60)
    seconds := Mod(totalSeconds, 60)
    return Format("{:02}:{:02}:{:02}", hours, minutes, seconds)
}

RefreshOrdinaryEventStatus()
{
    global hProcess, OrdinaryEventBase, PriorityEventRows, HuntGeneration
    if (!hProcess)
    {
        GuiControl,, EventStatusText, Su kien thuong: chua gan Engine.exe.
        return
    }
    GuiControlGet, huntOn,, HuntEnabled
    GuiControlGet, autoTravel,, AutoEventTravel
    if (huntOn && autoTravel)
        EnsureOrdinaryEventTable(HuntGeneration)
    if (!LocateOrdinaryEventTable())
    {
        GuiControl,, EventStatusText, Su kien thuong: chua nhan duoc bang tu game.
        return
    }
    first := "", second := ""
    for _, row in PriorityEventRows
    {
        if (!IsEventCategoryEnabled(row))
            continue
        address := OrdinaryEventBase + (row - 1) * 0x90
        if (!ReadInt(address + 0x04, seconds) || !ReadInt(address + 0x08, mapId)
            || !ReadInt(address + 0x34, monsterCount))
            continue
        if (seconds != 0
            || (monsterCount <= 0 && row != 9 && row != 16 && row != 17))
            continue
        countText := monsterCount > 0 ? (" | " . monsterCount . " quai") : ""
        item := GetEventName(row) . " | MapID " . mapId . countText
        if (first = "")
            first := item
        else if (second = "")
        {
            second := item
            break
        }
    }
    if (first != "" && second != "")
        message := "Uu tien: " . first . ". Sau do: " . second . "."
    else if (first != "")
        message := "Uu tien: " . first . "."
    else
        message := "Su kien thuong: hien khong co boss dang hoat dong."
    GuiControl,, EventStatusText, %message%
}

LocateOrdinaryEventTable()
{
    global OrdinaryEventBase
    ; The live CNewUIEventTime object owns all records. Row 1 starts at raw
    ; record 12: object + 0x1F4 + 12*0x90 = object + 0x8B4. Heap scanning can
    ; find an older but structurally valid table in a multi-client session, so
    ; never fall back to a cached/scanned heap copy on this verified client.
    if (GetEventPanelObject(eventObj))
    {
        liveBase := eventObj + 0x8B4
        if (ValidateOrdinaryEventTable(liveBase))
        {
            OrdinaryEventBase := liveBase
            return true
        }
    }
    OrdinaryEventBase := 0
    return false
}

ValidateOrdinaryEventTable(base)
{
    if (!base)
        return false
    validRows := 0
    Loop, 18
    {
        row := A_Index
        address := base + (row - 1) * 0x90
        if (!ReadInt(address, eventIndex) || eventIndex != row + 11
            || !ReadInt(address + 0x04, seconds) || seconds < 0 || seconds > 172800
            || !ReadInt(address + 0x08, mapId) || mapId < 0 || mapId > 255
            || !ReadInt(address + 0x34, count) || count < 0 || count > 10000)
            return false
        validRows += 1
    }
    return (validRows = 18)
}

; ========== COMBO FUNCTIONS ==========
LoadMcrSequence(filePath, ByRef sequence)
{
    sequence := []
    if (!FileExist(filePath))
        return false
    FileRead, macroText, %filePath%
    if (ErrorLevel || macroText = "")
        return false
    pendingIndex := 0
    Loop, Parse, macroText, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        if (RegExMatch(line, "i)^Keyboard\s*:\s*([A-Z0-9]+)\s*:\s*(KeyDown|KeyUp|KeyPress)\s*$", keyMatch))
        {
            if (pendingIndex)
                return false
            rawKey := keyMatch1
            if (RegExMatch(rawKey, "i)^D([0-9])$", digitMatch))
                key := digitMatch1
            else
            {
                StringLower, key, rawKey
            }
            if (!RegExMatch(key, "i)^[0-9qewr]$"))
                return false
            if (keyMatch2 = "KeyPress")
            {
                ; Jitbit KeyPress is one complete tap followed by its DELAY.
                ; Keep the delay on the release half so the next source action
                ; starts at exactly the recorded point.
                sequence.Push([key, 1, 0])
                sequence.Push([key, 0, 0])
            }
            else
            {
                isDown := (keyMatch2 = "KeyDown") ? 1 : 0
                sequence.Push([key, isDown, 0])
            }
            pendingIndex := sequence.Length()
            continue
        }
        if (RegExMatch(line, "i)^Mouse\s*:\s*[^:]*:\s*[^:]*:\s*(RightButtonDown|RightButtonUp)\s*:", mouseMatch))
        {
            if (pendingIndex)
                return false
            isDown := (mouseMatch1 = "RightButtonDown") ? 1 : 0
            sequence.Push(["RButton", isDown, 0])
            pendingIndex := sequence.Length()
            continue
        }
        if (RegExMatch(line, "i)^DELAY\s*:\s*([0-9]+(?:\.[0-9]+)?)\s*$", delayMatch))
        {
            if (!pendingIndex)
                return false
            sequence[pendingIndex][3] := delayMatch1 + 0
            pendingIndex := 0
            continue
        }
        return false
    }
    return (!pendingIndex && sequence.Length() >= 4)
}

GetEmbeddedComboMacroSequence(profile)
{
    ; Portable fallbacks are regenerated from Macro\*.mcr. They make the
    ; compiled EXE fully standalone while source mode still loads the editable
    ; files first. A Jitbit KeyPress is expanded into Down(0 ms), Up(delay).
    if (profile = "DW")
        return [["1",1,118], ["7",1,215], ["3",1,279], ["1",0,5]
            , ["7",0,5], ["3",0,5], ["1",0,5], ["7",0,5]
            , ["3",0,5]]
    if (profile = "DK")
        return [["4",1,0], ["4",0,160], ["4",0,20], ["q",1,14]
            , ["q",0,13], ["e",1,14], ["e",0,13], ["1",1,0]
            , ["1",0,430], ["q",1,14], ["q",0,13], ["e",1,14]
            , ["e",0,13], ["3",1,230], ["3",0,20], ["q",1,14]
            , ["q",0,13], ["e",1,14], ["e",0,13]]
    if (profile = "DK V1")
        return [["4",1,260], ["2",1,115], ["3",1,138], ["4",0,30]
            , ["q",1,29], ["q",0,28], ["e",1,29], ["e",0,28]
            , ["2",0,30], ["e",1,29], ["e",0,28], ["3",0,30]
            , ["q",1,29], ["q",0,28], ["e",1,29], ["e",0,28]]
    if (profile = "ELF")
        return [["3",1,666], ["1",1,185], ["2",1,225], ["3",0,5]
            , ["1",0,5], ["2",0,5], ["3",0,5], ["1",0,5]
            , ["2",0,5]]
    if (profile = "SUM")
        return [["RButton",1,10], ["1",1,150], ["1",0,5], ["q",1,14]
            , ["q",0,13], ["e",1,14], ["e",0,13], ["2",1,60]
            , ["2",0,5], ["q",1,14], ["q",0,13], ["e",1,14]
            , ["e",0,13], ["3",1,120], ["3",0,5], ["q",1,14]
            , ["q",0,13], ["e",1,14], ["e",0,13]]
    if (profile = "RF")
        return [["1",1,55], ["q",1,25], ["q",0,10], ["e",1,25], ["e",0,10]
            , ["1",1,55], ["q",1,25], ["q",0,10], ["e",1,25], ["e",0,10]
            , ["q",1,25], ["q",0,10], ["1",1,85], ["1",0,50]
            , ["2",1,185], ["2",0,45], ["q",1,25], ["q",0,10]
            , ["e",1,25], ["e",0,10], ["q",1,25], ["q",0,10]
            , ["e",1,25], ["e",0,10], ["q",1,25], ["q",0,10]
            , ["3",1,85], ["3",0,50], ["q",1,25], ["q",0,10]
            , ["e",1,25], ["e",0,10], ["q",1,25], ["q",0,10]
            , ["e",1,25], ["e",0,10], ["q",1,25], ["q",0,10]]
    if (profile = "DL")
        return [["1",1,45], ["1",1,5], ["1",1,5], ["q",1,10]
            , ["q",0,10], ["e",1,10], ["e",0,10], ["1",0,5]
            , ["1",0,5], ["2",1,45], ["2",1,5], ["q",1,10]
            , ["q",0,10], ["2",0,10], ["2",0,5], ["4",1,110]
            , ["3",1,735], ["3",0,10], ["3",0,10], ["e",1,10]
            , ["e",0,10], ["q",1,10], ["q",0,10], ["1",0,5]
            , ["2",0,5], ["3",0,5], ["4",0,5], ["1",0,5]
            , ["2",0,5], ["3",0,5], ["4",0,5]]
    if (profile = "MG")
        return [["1",1,123], ["q",1,10], ["q",0,10], ["e",1,10]
            , ["e",0,10], ["2",1,20], ["5",1,5], ["q",1,10]
            , ["q",0,10], ["e",1,10], ["e",0,10], ["3",1,80]
            , ["q",1,10], ["q",0,10], ["e",1,10], ["e",0,10]
            , ["1",0,20], ["2",0,10], ["3",0,5], ["5",0,5]
            , ["q",1,10], ["q",0,10], ["e",1,10], ["e",0,10]]
    return []
}

GetComboMacroSequence(profile, ByRef sequence)
{
    global ComboMacroCache, ComboMacroSources
    static files := {"DW":"DW - Combo CotLua_MuaDoc_MuaBangTuyet_Speed1500.mcr"
        , "DK":"DK Combo 3Sk_CN.DG.XK_HP.Q.E_Speed 2000.mcr"
        ; Wildcard avoids making the AHK source depend on a Unicode filename.
        , "DK V1":"V1. DK Combo *ChemBang_Speed 2000.mcr"
        , "ELF":"ELF V2 Combo 3Skill_3Tien_5Tien_TenBang_Speed1700.mcr"
        , "RF":"RF Combo chuan 3sk ML.VN.GT_Speed 1000.mcr"
        , "SUM":"Test. Skill combo + Bom Mau _SUM_Speed1000.mcr"
        , "DL":"DL Skill combo chuan DL_Xich.HL.HoaDiem_DamNguaSpeed1500.mcr"
        , "MG":"MG Combo 4Sk_HP.Q.E.Speed 1500.mcr"}
    if (ComboMacroCache.HasKey(profile))
    {
        sequence := ComboMacroCache[profile]
        return true
    }
    loadedFromFile := false
    parsed := []
    if (files.HasKey(profile))
    {
        sourcePath := ResolveComboMacroPath(files[profile])
        loadedFromFile := LoadMcrSequence(sourcePath, parsed)
    }
    if (!loadedFromFile)
        parsed := GetEmbeddedComboMacroSequence(profile)
    if (!IsObject(parsed) || parsed.Length() < 4)
        return false
    ComboMacroCache[profile] := parsed
    ComboMacroSources[profile] := loadedFromFile ? sourcePath : ("embedded " . profile)
    sequence := parsed
    return true
}

ResolveComboMacroPath(filePattern)
{
    for _, baseDir in [A_ScriptDir . "\Macro", A_ScriptDir]
    {
        candidate := baseDir . "\" . filePattern
        if (!InStr(filePattern, "*") && FileExist(candidate))
            return candidate
        if (InStr(filePattern, "*"))
        {
            Loop, Files, %candidate%, F
                return A_LoopFileFullPath
        }
    }
    return ""
}

RunComboMacroSelfTest(ByRef report)
{
    global ComboMacroCache, ComboMacroSources
    expectedLengths := {"DW":9, "DK":19, "DK V1":16, "ELF":9, "RF":38
        , "SUM":19, "DL":31, "MG":24}
    ComboMacroCache := {}
    ComboMacroSources := {}
    report := "MU-PKZ macro self-test | mode=" . (A_IsCompiled ? "compiled" : "source") . "`r`n"
    allOk := true
    for profile, expectedLength in expectedLengths
    {
        loaded := GetComboMacroSequence(profile, sequence)
        actualLength := loaded && IsObject(sequence) ? sequence.Length() : 0
        source := ComboMacroSources.HasKey(profile) ? ComboMacroSources[profile] : "not-loaded"
        sourceOk := A_IsCompiled ? true : !InStr(source, "embedded ")
        profileOk := loaded && actualLength = expectedLength && sourceOk
        report .= (profileOk ? "PASS" : "FAIL") . " | " . profile
            . " | actions=" . actualLength . "/" . expectedLength . " | " . source . "`r`n"
        if (!profileOk)
            allOk := false
    }
    report .= "Default playback: 286% = Jitbit Fast/MAX`r`n"
    return allOk
}

PlayComboMcrProfile(profile)
{
    global ComboRunning
    if (!GetComboMacroSequence(profile, sequence))
    {
        ComboRunning := false
        SetHuntStatus("Khong nap duoc profile combo " . profile . ".", "CC0000")
        return false
    }
    for _, step in sequence
    {
        if (!ComboRunning)
            return false
        if (step[2])
            ComboKeyDown(step[1])
        else
            ComboKeyUp(step[1])
        if (ComboWaitMs(step[3]))
            return false
    }
    return true
}

; DW profile synchronized from Macro\DW - Combo ... Speed1500.ahk.
; Its source adds rapid Q edges to skills 1/7, holds E with skill 3 and taps
; buff slot 0 every five minutes. All waits still pass through the shared
; Jitbit playback scaler, whose default is Fast/MAX (286%).
ComboDW_TELE()
{
    global ComboRunning, ComboDWNextBuffTick
    if (!ComboDWNextBuffTick || A_TickCount >= ComboDWNextBuffTick)
    {
        ComboTapKey("0", 143, 0)
        if (!ComboRunning)
            return
        ComboDWNextBuffTick := A_TickCount + 300000
    }
    ComboKeyDown("1")
    ComboKeyDown("q")
    ComboKeyUp("q")
    ComboKeyDown("q")
    ComboKeyUp("q")
    ComboKeyDown("q")
    if ComboWaitMs(118)
        return
    ComboKeyDown("7")
    ComboKeyUp("q")
    ComboKeyDown("q")
    ComboKeyUp("q")
    ComboKeyDown("q")
    ComboKeyUp("q")
    ComboKeyDown("q")
    if ComboWaitMs(215)
        return
    ComboKeyDown("3")
    ComboKeyDown("e")
    if ComboWaitMs(279)
        return
    ComboKeyUp("1")
    ComboKeyUp("q")
    ComboKeyUp("7")
    ComboKeyUp("3")
    ComboKeyUp("e")
    if ComboWaitMs(5)
        return
}

; Main DK profile from Macro\DK Combo 3Sk_CN.DG.XK_HP.Q.E_Speed 2000.mcr.
ComboDK_MCR()
{
    PlayComboMcrProfile("DK")
}

; Second DK variant supplied in Macro\V1...ChemBang...mcr.
ComboDK_V1_MCR()
{
    PlayComboMcrProfile("DK V1")
}

; ELF V2: 3 Tien -> 5 Tien -> Ten Bang.
ComboELF()
{
    PlayComboMcrProfile("ELF")
}

; RF Combo chuan 3sk ML.VN.GT_Speed 1000
ComboRF()
{
    PlayComboMcrProfile("RF")
}

; SUM profile includes the recorded RightButtonDown plus skills 1/2/3.
ComboSUM()
{
    PlayComboMcrProfile("SUM")
}

ComboDL()
{
    PlayComboMcrProfile("DL")
}

ComboMG()
{
    PlayComboMcrProfile("MG")
}

; Combo helper functions
ComboKeyDown(key)
{
    global hProcess, InternalKeyStateAddress, ComboPendingDispatchMs
    global ComboCycleAbort, TravelBusy
    global ComboPulseRepeats, ComboPulseSleepMs
    ; Keep a travel timer from interrupting between a pulse and the final held
    ; state. The high-resolution sequence is about 9-11 ms at three pulses.
    Critical, On
    if (!hProcess || ComboCycleAbort || TravelBusy)
    {
        Critical, Off
        return false
    }
    vk := GetKeyVK(key)
    if (!vk)
    {
        Critical, Off
        return false
    }
    dispatchStarted := A_TickCount
    ; Repeat the press edge across several Engine frames, then leave the key in
    ; its per-process held state. No Windows keyboard state is changed.
    Loop, %ComboPulseRepeats%
    {
        WriteByte(InternalKeyStateAddress + vk, 2)
        PreciseComboSleep(ComboPulseSleepMs)
    }
    WriteByte(InternalKeyStateAddress + vk, 3)
    ComboPendingDispatchMs += A_TickCount - dispatchStarted
    Critical, Off
    return true
}

ComboKeyUp(key)
{
    global hProcess, InternalKeyStateAddress, ComboPendingDispatchMs
    global ComboCycleAbort, TravelBusy
    global ComboPulseRepeats, ComboPulseSleepMs
    Critical, On
    if (!hProcess || ComboCycleAbort || TravelBusy)
    {
        Critical, Off
        return false
    }
    vk := GetKeyVK(key)
    if (!vk)
    {
        Critical, Off
        return false
    }
    dispatchStarted := A_TickCount
    Loop, %ComboPulseRepeats%
    {
        WriteByte(InternalKeyStateAddress + vk, 1)
        PreciseComboSleep(ComboPulseSleepMs)
    }
    WriteByte(InternalKeyStateAddress + vk, 0)
    ComboPendingDispatchMs += A_TickCount - dispatchStarted
    Critical, Off
    return true
}

PreciseComboSleep(ms)
{
    global ComboHiResTimerHandle
    ms := Max(1, Round(ms))
    if (!ComboHiResTimerHandle)
    {
        ; CREATE_WAITABLE_TIMER_HIGH_RESOLUTION (Windows 10 1803+).
        ComboHiResTimerHandle := DllCall("Kernel32\CreateWaitableTimerExW"
            , "Ptr", 0, "Ptr", 0, "UInt", 0x2, "UInt", 0x1F0003, "Ptr")
        if (!ComboHiResTimerHandle)
            ComboHiResTimerHandle := DllCall("Kernel32\CreateWaitableTimer"
                , "Ptr", 0, "Int", 0, "Ptr", 0, "Ptr")
    }
    if (ComboHiResTimerHandle)
    {
        VarSetCapacity(dueTime, 8, 0)
        NumPut(-1 * ms * 10000, dueTime, 0, "Int64")
        if (DllCall("Kernel32\SetWaitableTimerEx", "Ptr", ComboHiResTimerHandle
            , "Ptr", &dueTime, "Int", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0
            , "UInt", 0))
        {
            DllCall("Kernel32\WaitForSingleObject", "Ptr", ComboHiResTimerHandle
                , "UInt", 0xFFFFFFFF)
            return true
        }
    }
    DllCall("Sleep", "UInt", ms)
    return false
}

ComboTapKey(key, downDelay, upDelay)
{
    global ComboRunning
    if !ComboRunning
        return
    ComboKeyDown(key)
    if ComboWaitMs(downDelay)
        return
    ComboKeyUp(key)
    ComboWaitMs(upDelay)
}

ScaleComboPlaybackDelay(ms)
{
    global ComboPlaybackSpeedPercent
    ms += 0
    if (ms <= 0)
        return 0
    speed := NormalizeComboSpeed(ComboPlaybackSpeedPercent, 100)
    coefficient := 100.0 / speed
    ; Literal Jitbit behavior: at Fast/MAX, keyboard-to-keyboard delays below
    ; 30 ms are deliberately not shortened, preserving detectable key edges.
    if (coefficient < 1.0 && ms < 30)
        return Round(ms)
    return Max(0, Round(ms * coefficient))
}

ComboWaitMs(ms)
{
    global ComboRunning, TravelBusy, ComboPendingDispatchMs, ComboCycleAbort
    dispatchMs := ComboPendingDispatchMs
    ComboPendingDispatchMs := 0
    if (!ComboRunning || TravelBusy || ComboCycleAbort)
    {
        if (TravelBusy || ComboCycleAbort)
            ReleaseAllComboKeys()
        return true
    }
    scaledMs := ScaleComboPlaybackDelay(ms)
    remainingMs := Max(0, scaledMs - dispatchMs)
    if (remainingMs > 0)
        Sleep, %remainingMs%
    if (TravelBusy || ComboCycleAbort)
    {
        ReleaseAllComboKeys()
        return true
    }
    return !ComboRunning
}

AbortComboForTravel()
{
    global ComboCycleAbort
    ; Timers can interrupt a combo during Sleep. Keep this flag sticky until
    ; ComboLoop reaches the next clean iteration, even if travel already ended.
    ComboCycleAbort := true
    ReleaseAllComboKeys()
}

; AutoHP Ver2.0.exe embedded source: Q, E, Q, Q only.
ComboAutoHP()
{
    global ComboRunning
    keys := ["q", "e", "q", "q"]
    sourceSleeps := [0.3, 0.05, 0.05, 0.05]
    for index, key in keys
    {
        if (!ComboRunning)
            return
        ; Mirrors SetKeyDelay, 1, 1 from the embedded source. Its fractional
        ; Sleep values round to a zero-duration yield in AHK v1, as original.
        ComboTapKey(key, 1, 1)
        if ComboWaitMs(sourceSleeps[index])
            return
    }
}

ReleaseAllComboKeys()
{
    global hProcess, InternalKeyStateAddress, ComboPendingDispatchMs, ComboDWNextBuffTick
    ComboPendingDispatchMs := 0
    ComboDWNextBuffTick := 0
    if (!hProcess)
        return
    for _, key in ["0", "1", "2", "3", "4", "5", "6", "7", "q", "e", "w", "r", "RButton"]
    {
        vk := GetKeyVK(key)
        if (vk)
            WriteByte(InternalKeyStateAddress + vk, 0)
    }
}

UpdateComboStatus()
{
    global ComboRunning, ComboSelectedClass
    if (ComboRunning)
    {
        state := "DANG CHAY - " . ComboSelectedClass
        color := "008800"
    }
    else
    {
        state := "TAT"
        color := "666666"
    }
    GuiControl, +c%color%, ComboStatusText
    GuiControl,, ComboStatusText, Combo: %state% | Ctrl+F2 de bat/tat
}

; ========== MEMORY READ/WRITE ==========
ReadDword(address, ByRef value)
{
    global hProcess
    VarSetCapacity(buf, 4, 0)
    ok := DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", address, "Ptr", &buf, "UPtr", 4, "UPtr*", read)
    if (!ok || read != 4)
        return false
    value := NumGet(buf, 0, "UInt")
    return true
}

ReadInt(address, ByRef value)
{
    global hProcess
    VarSetCapacity(buf, 4, 0)
    ok := DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", address, "Ptr", &buf, "UPtr", 4, "UPtr*", read)
    if (!ok || read != 4)
        return false
    value := NumGet(buf, 0, "Int")
    return true
}

ReadByte(address, ByRef value)
{
    global hProcess
    VarSetCapacity(buf, 1, 0)
    ok := DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", address, "Ptr", &buf, "UPtr", 1, "UPtr*", read)
    if (!ok || read != 1)
        return false
    value := NumGet(buf, 0, "UChar")
    return true
}

ReadWord(address, ByRef value)
{
    global hProcess
    VarSetCapacity(buf, 2, 0)
    ok := DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", address, "Ptr", &buf, "UPtr", 2, "UPtr*", read)
    if (!ok || read != 2)
        return false
    value := NumGet(buf, 0, "UShort")
    return true
}

ReadShort(address, ByRef value)
{
    global hProcess
    VarSetCapacity(buf, 2, 0)
    ok := DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", address, "Ptr", &buf, "UPtr", 2, "UPtr*", read)
    if (!ok || read != 2)
        return false
    value := NumGet(buf, 0, "Short")
    return true
}

WriteWord(address, value)
{
    global hProcess
    VarSetCapacity(buf, 2, 0)
    NumPut(value, buf, 0, "UShort")
    ok := DllCall("WriteProcessMemory", "Ptr", hProcess, "Ptr", address, "Ptr", &buf, "UPtr", 2, "UPtr*", written)
    return (ok && written = 2)
}

WriteByte(address, value)
{
    global hProcess
    VarSetCapacity(buf, 1, 0)
    NumPut(value, buf, 0, "UChar")
    ok := DllCall("WriteProcessMemory", "Ptr", hProcess, "Ptr", address
        , "Ptr", &buf, "UPtr", 1, "UPtr*", written)
    return (ok && written = 1)
}

WriteDword(address, value)
{
    global hProcess
    VarSetCapacity(buf, 4, 0)
    NumPut(value, buf, 0, "UInt")
    ok := DllCall("WriteProcessMemory", "Ptr", hProcess, "Ptr", address, "Ptr", &buf, "UPtr", 4, "UPtr*", written)
    return (ok && written = 4)
}

; ========== UI HELPERS ==========
SetStatus(message, color)
{
    GuiControl, +c%color%, StatusText
    GuiControl,, StatusText, %message%
}

SetHuntStatus(message, color)
{
    GuiControl, +c%color%, HuntStatusText
    GuiControl,, HuntStatusText, %message%
}
; ==============================================================================
; LOGIC HIỂN THỊ VÀ CẬP NHẬT BỘ LỌC EVENT BOSS (VỊ TRÍ 2)
; ==============================================================================
MoBangChonEvent:
    Gui, EventGui:Destroy
    Gui, EventGui:+AlwaysOnTop +Owner%MainGuiHwnd%
    Gui, EventGui:Margin, 15, 12
    
    SetScaledGuiFont(10, "Bold")
    Gui, EventGui:Add, Text, xm ym, TÍCH CHỌN CÁC EVENT / BOSS THAM GIA:
    SetScaledGuiFont(9, "Norm")
    
    ; --- ĐOẠN THAY THẾ: Đặt tên chi tiết cho từng mục Boss theo dòng hiển thị ---
    TenEvents := ["Dong 1: Dai Chien Lorencia"
                , "Dong 2: Phu Thuy Trang"
                , "Dong 3: Tu Than Xuong So"
                , "Dong 4: Rong Do"
                , "Dong 5: Tho Ngoc"
                , "Dong 6: Mua He"
                , "Dong 7: Boss Viem Dia Chua"
                , "Dong 8: Boss Class"
                , "Dong 9: Kho Bau Hoang Toc"
                , "Dong 10: Boss Chien Than"
                , "Dong 11: Boss Ma Than Tuong"
                , "Dong 12: Boss Ta Than Tuong"
                , "Dong 13: Boss Nguu Vuong"
                , "Dong 14: Boss Thuy Hoang De"
                , "Dong 15: Boss Anubis"
                , "Dong 16: Boss Long Vuong"
                , "Dong 17: Boss Hon Thach"
                , "Dong 18: Boss Ma Thu"]

    Loop, 18 {
        RowIdx := A_Index
        IsChecked := InStr("," . SavedEventsAllowed . ",", "," . RowIdx . ",") ? "Checked" : ""
        
        if (RowIdx = 1)
            Options := "xm y+10 w240"
        else if (RowIdx = 10)
            Options := "x+20 ym+30 w240" 
        else
            Options := "xp y+8 w240"
            
        FinalOptions := ScaleGuiOptions(Options) . " vCbEvent" . RowIdx . " " . IsChecked
        Gui, EventGui:Add, CheckBox, %FinalOptions%, % TenEvents[RowIdx]
    }
    
    SetScaledGuiFont(9, "Bold")
    Gui, EventGui:Add, Button, xm y+20 w140 h32 gLuuCauHinhEvent, LƯU BỘ LỌC
    Gui, EventGui:Show,, Cấu hình Event Boss

; ==============================================================================
; HÀM CẬP NHẬT ĐỘNG MẢNG QUÉT BOSS THEO CHECKBOX ĐÃ LƯU
; ==============================================================================
LuuCauHinhEvent:
    Gui, EventGui:Submit
    
    NewAllowed := ""
    Loop, 18 {
        if (CbEvent%A_Index%) {
            NewAllowed .= (NewAllowed = "" ? "" : ",") . A_Index
        }
    }
    
    SavedEventsAllowed := NewAllowed
    RegWrite, REG_SZ, HKCU, %SettingsRegKey%, EventsAllowed, %SavedEventsAllowed%
    
    ; Gọi hàm xử lý nạp lại mảng ưu tiên sự kiện
    CapNhatMangPriorityEvent()
    
    MsgBox, 64, MU-PKZ, Da cap nhat bo loc Event thanh cong!
return

; ==============================================================================
; HÀM CẬP NHẬT MẢNG QUÉT BOSS ĐÃ ĐƯỢC FIX LỖI XUNG ĐỘT BIẾN LOCAL
; ==============================================================================
CapNhatMangPriorityEvent() {
    global PriorityEventRows, SavedEventsAllowed, SettingsRegKey, ManagerMode
    PriorityEventRows := [] ; Xóa sạch mảng cũ để nạp mới
    chuoiCauHinh := ""
    
    if (ManagerMode) {
        chuoiCauHinh := SavedEventsAllowed
    } else {
        ; Nếu là Worker, đọc trực tiếp chuỗi Boss từ Registry hệ thống
        RegRead, chuoiCauHinh, HKCU, %SettingsRegKey%, SavedEventsAllowed
    }
    
    if (ErrorLevel || chuoiCauHinh == "")
        return
        
    ; Bóc tách chuỗi "1,2,5" thành các phần tử số nguyên chính xác
    Loop, Parse, chuoiCauHinh, `,
    {
        if (A_LoopField != "") {
            soHàng := A_LoopField + 0 ; Ép kiểu số nguyên (Integer) bắt buộc cho mảng di chuyển
            PriorityEventRows.Push(soHàng)
        }
    }
}



; ==============================================================================
; LOGIC HIỂN THỊ VÀ ĐỒNG BỘ BỘ LỌC EVENT BOSS CHO GIAO DIỆN MANAGER
; ==============================================================================
MoBangChonEventManager:
    Gui, MgrEventGui:Destroy
    Gui, MgrEventGui:+AlwaysOnTop +Owner%MainGuiHwnd%
    Gui, MgrEventGui:Margin, 15, 12
    
    SetScaledGuiFont(10, "Bold")
    Gui, MgrEventGui:Add, Text, xm ym, TICH CHON CAC EVENT DONG BO CHO ALL ACC:
    SetScaledGuiFont(9, "Norm")
    
    ; Danh sách tên 18 dòng Event/Boss viết không dấu để chống lỗi font tuyệt đối
    TenEvents := ["Dong 1: Dai Chien Lorencia"
                , "Dong 2: Phu Thuy Trang"
                , "Dong 3: Tu Than Xuong So"
                , "Dong 4: Rong Do"
                , "Dong 5: Tho Ngoc"
                , "Dong 6: Mua He"
                , "Dong 7: Boss Viem Dia Chua"
                , "Dong 8: Boss Class"
                , "Dong 9: Kho Bau Hoang Toc"
                , "Dong 10: Boss Chien Than"
                , "Dong 11: Boss Ma Than Tuong"
                , "Dong 12: Boss Ta Than Tuong"
                , "Dong 13: Boss Nguu Vuong"
                , "Dong 14: Boss Thuy Hoang De"
                , "Dong 15: Boss Anubis"
                , "Dong 16: Boss Long Vuong"
                , "Dong 17: Boss Hon Thach"
                , "Dong 18: Boss Ma Thu"]

    ; Vòng lặp tạo đầy đủ 18 ô Checkbox phân thành 2 cột dựa trên chuỗi cấu hình chung
    Loop, 18 {
        RowIdx := A_Index
        IsChecked := InStr("," . SavedEventsAllowed . ",", "," . RowIdx . ",") ? "Checked" : ""
        
        if (RowIdx = 1)
            Options := "xm y+10 w240"
        else if (RowIdx = 10)
            Options := "x+20 ym+30 w240" 
        else
            Options := "xp y+8 w240"
            
        FinalOptions := ScaleGuiOptions(Options) . " vMgrCbEvent" . RowIdx . " " . IsChecked
        Gui, MgrEventGui:Add, CheckBox, %FinalOptions%, % TenEvents[RowIdx]
    }
    
    SetScaledGuiFont(9, "Bold")
    Gui, MgrEventGui:Add, Button, xm y+20 w140 h32 gLuuCauHinhEventManager, LUU DONG BO
    Gui, MgrEventGui:Show,, Bo loc Event - Manager
return

LuuCauHinhEventManager:
    ; Thu thập dữ liệu từ các CheckBox trong bảng cấu hình nâng cao
    Gui, MgrEventGui:Submit
    
    NewAllowed := ""
    Loop, 18 {
        if (MgrCbEvent%A_Index%) {
            NewAllowed .= (NewAllowed = "" ? "" : ",") . A_Index
        }
    }
    
    ; --- ĐOẠN ĐÃ NÂNG CẤP: Gán giá trị 1 và cập nhật trực tiếp lên biến kiểm tra của GUI Manager ---
    ManagerHuntSingleBoss := 1
    ManagerHuntMultiBoss := 1
    ManagerAutoTravel := 1
    
    ; Lưu chuỗi cấu hình 18 dòng vào hệ thống Registry
    SavedEventsAllowed := NewAllowed
    RegWrite, REG_SZ, HKCU, %SettingsRegKey%, EventsAllowed, %SavedEventsAllowed%
    
    ; Nạp lại mảng ưu tiên để các tài khoản nhận diện dòng mới tích
    CapNhatMangPriorityEvent()
    
    ; Gửi tín hiệu thông báo cho toàn bộ các cửa sổ game cày ngầm (Workers) cập nhật theo
    NotifyManagerWorkersSettingsChanged()
    
    ; Tự động kích hoạt lại hàm cập nhật trạng thái tùy chọn của Manager để tắt dòng thông báo đỏ
    Gosub, ManagerOptionsChanged
    
    MsgBox, 64, MU-PKZ, Da dong bo bo loc Event cho toan bo cac tai khoan!
	
SaveDLClassSetting:
    Gui, Submit, NoHide
    ; Lưu trạng thái vào khóa Registry dùng chung của hệ thống MU-PKZ
    RegWrite, REG_DWORD, HKCU, %SettingsRegKey%, IsDarkLordClass, %IsDarkLordClass%
	
RebuildPriorityRows() {
    global PriorityEventRows, BossFilters
    PriorityEventRows := []
    
    BasePriority :=
    
    for index, rowNum in BasePriority {
        ; Nếu người dùng TÍCH CHỌN thì mới nạp hàng đó vào danh sách đi săn
        if (BossFilters[rowNum] == 1) {
            PriorityEventRows.Push(rowNum)
        }
    }
}

OnBossFilterChanged:
    Gui, Submit, NoHide
    Loop, 18 {
        BossFilters[A_Index] := FilterBoss%A_Index%
    }
    RebuildPriorityRows() ; Cập nhật lại mảng ưu tiên ngay lập tức
	
    ; === ĐOẠN MÃ THAY THẾ DÀNH RIÊNG CHO CLASS DL ===
    if (IsClassDL == 1) 
    {
        ; Nếu con Boss này chưa được triệu hồi thành viên trong lượt này
        if (HasSummonedCurrentBoss == 0) 
        {
            ; 1. Bấm phím skill số 6 cài sẵn chiêu Triệu Hồi
            ControlSend,, %SummonSkillKey%, ahk_id %GameHwnd%
            Sleep, 300 ; Chờ 0.3 giây cho game chuyển đổi skill hoàn tất
            
            ; 2. Click chuột phải chạy nền vào tâm màn hình (tọa độ x400 y300) để Triệu Hồi
            ControlClick, x400 y300, ahk_id %hwndGame%,, Right, 1, NA
            
            ; Đánh dấu đã triệu hồi xong, tránh việc vòng lặp quét liên tục bấm lại phím 6
            HasSummonedCurrentBoss := 1
            
            ; 3. Đứng bất động đợi đúng 5 giây cho thành viên Guild/Party dịch chuyển lên
            Sleep, 5000
        }
    }

    ; Sau khi xử lý DL xong (hoặc nếu là Class khác), tiến hành bật Helper như bình thường
    ; Hãy sửa phím {End} thành {Home} nếu server của bạn dùng phím Home để bật Helper nhé
    ControlSend,, {End}, ahk_id %GameHwnd% 
    ; ================================================
ApplyPersistentSettings() {
    global
    ; Đồng bộ trạng thái ô tích từ cấu hình đã lưu
    RegRead, SavedIsClassDL, HKCU, %SettingsRegKey%, SavedIsClassDL
    if ErrorLevel
        SavedIsClassDL := 1
    IsClassDL := SavedIsClassDL
AttachGame:
    return
}
