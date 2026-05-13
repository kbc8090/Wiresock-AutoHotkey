#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; AUTO-ADMIN ELEVATION
; ==============================================================================
if !A_IsAdmin {
    Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"')
    ExitApp()
}

SetWorkingDir A_InitialWorkingDir

; ==============================================================================
; SETTINGS & PATHS
; ==============================================================================
global WiresockExe    := "C:\Program Files\WireSock Secure Connect\sdk\wiresock-client.exe"
global ProfileDir     := "C:\ProgramData\WireSock Foundation\WireSock Secure Connect\Profiles"
global IniFile        := A_ScriptDir "\settings.ini"

global CheckInterval  := 10000
global Connected      := false
global ActivePID      := 0
global CurrentProfile := IniRead(IniFile, "Settings", "LastProfile", "")
global AutoConnect    := (IniRead(IniFile, "Settings", "AutoConnect", "0") == "1")

; Tray Icons (imageres.dll) — kept for reference
; global IconDisconnected := "imageres.dll"
; global IconDiscNum      := 101
; global IconConnected    := "imageres.dll"
; global IconConnNum      := 102

; Tray Icons (.ico files — place in same folder as this script)
global IconDisconnected := A_ScriptDir "\ovpn-red.ico"
global IconDiscNum      := 1
global IconConnected    := A_ScriptDir "\ovpn-green.ico"
global IconConnNum      := 1

; ==============================================================================
; INITIALIZE
; ==============================================================================
A_IconTip := "Wiresock Tray"
TraySetIcon(IconDisconnected, IconDiscNum)
BuildMenu()

SetTimer(Watchdog, CheckInterval)

if (AutoConnect && CurrentProfile != "")
    StartWiresock(CurrentProfile)

; ==============================================================================
; FUNCTIONS
; ==============================================================================

ShowToast(Title, Message) {
    TrayTip(Title, Message)
    SetTimer(() => TrayTip(), -5000)
}

BuildMenu() {
    TrayMenu := A_TrayMenu
    TrayMenu.Delete()

    ; Profiles Submenu
    ProfileMenu := Menu()
    Loop Files, ProfileDir "\*.conf" {
        ProfileName := StrReplace(A_LoopFileName, ".conf", "")
        ProfileMenu.Add(ProfileName, MenuHandler_ProfileSelect)
        if (ProfileName == CurrentProfile)
            ProfileMenu.Check(ProfileName)
    }

    ; Edit Configs Submenu
    EditMenu := Menu()
    Loop Files, ProfileDir "\*.conf" {
        ProfileName := StrReplace(A_LoopFileName, ".conf", "")
        EditMenu.Add(ProfileName, MenuHandler_EditConfig)
    }

    TrayMenu.Add("Profiles", ProfileMenu)
    TrayMenu.Add("Edit Configs", EditMenu)
    TrayMenu.Add("Auto Connect on Startup", MenuHandler_AutoConnect)
    TrayMenu.Add()
    TrayMenu.Add("Connect...", MenuHandler_SmartConnect)
    TrayMenu.Add("Disconnect", MenuHandler_Disconnect)
    TrayMenu.Add()
    TrayMenu.Add("Exit", MenuHandler_Exit)

    UpdateMenuState()
}

UpdateMenuState() {
    if (Connected) {
        A_TrayMenu.Disable("Connect...")
        A_TrayMenu.Enable("Disconnect")
        TraySetIcon(IconConnected, IconConnNum)
        A_IconTip := "Wiresock - Connected: " CurrentProfile
    } else {
        A_TrayMenu.Enable("Connect...")
        A_TrayMenu.Disable("Disconnect")
        TraySetIcon(IconDisconnected, IconDiscNum)
        A_IconTip := "Wiresock - Disconnected"
    }

    if (AutoConnect)
        A_TrayMenu.Check("Auto Connect on Startup")
    else
        A_TrayMenu.Uncheck("Auto Connect on Startup")
}

MenuHandler_ProfileSelect(ItemName, ItemPos, MyMenu) {
    global CurrentProfile
    CurrentProfile := ItemName
    IniWrite(CurrentProfile, IniFile, "Settings", "LastProfile")
    StartWiresock(CurrentProfile)
}

MenuHandler_SmartConnect(*) {
    if (CurrentProfile == "") {
        MsgBox("Please select a profile from the 'Profiles' menu first.")
        return
    }
    StartWiresock(CurrentProfile)
}

MenuHandler_AutoConnect(*) {
    global AutoConnect
    AutoConnect := !AutoConnect
    IniWrite(AutoConnect ? "1" : "0", IniFile, "Settings", "AutoConnect")
    UpdateMenuState()
}

MenuHandler_EditConfig(ItemName, ItemPos, MyMenu) {
    ConfPath := ProfileDir "\" ItemName ".conf"
    try {
        Run(ConfPath)
    } catch {
        Run("notepad.exe " ConfPath)
    }
}

StartWiresock(ProfileName) {
    global ActivePID, Connected

    ConfPath := ProfileDir "\" ProfileName ".conf"

    if !FileExist(ConfPath) {
        ShowToast("WireSock Error", "Profile not found: " ConfPath)
        return
    }

    if (ActivePID)
        ProcessClose(ActivePID)
    RunWait("taskkill /F /IM wiresock-client.exe", , "Hide")
    ProcessWaitClose("wiresock-client.exe", 5)  ; wait up to 5s for it to actually die
    Connected := false                           ; show red X during transition
    TraySetIcon(IconDisconnected, IconDiscNum)
    A_IconTip := "Wiresock - Connecting..."
    Run(WiresockExe ' run -config "' ConfPath '" -log-level none', , "Hide", &PID)
    ActivePID := PID
    Sleep(1600)

    if ProcessExist(ActivePID) {
        Connected := true
    } else {
        Connected := false
        ShowToast("WireSock Error", "Failed to connect using profile: " ProfileName)
    }

    BuildMenu()
}

MenuHandler_Disconnect(*) {
    global ActivePID, Connected
    if (ActivePID) {
        ProcessClose(ActivePID)
        ActivePID := 0
    }
    Run("taskkill /F /IM wiresock-client.exe", , "Hide")
    Connected := false
    BuildMenu()
}

Watchdog() {
    global Connected, ActivePID
    if (!Connected)
        return

    if (!ProcessExist(ActivePID)) {
        Connected := false
        ShowToast("WireSock", "Connection dropped — tunnel process exited")
        BuildMenu()
    }
}

MenuHandler_Exit(*) {
    global Connected
    if (Connected) {
        Result := MsgBox("Disconnect and Exit?", "WireSock", "YesNo Icon?")
        if (Result != "Yes")
            return
        RunWait("taskkill /F /IM wiresock-client.exe", , "Hide")
    }
    ExitApp()
}