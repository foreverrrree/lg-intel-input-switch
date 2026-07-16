#Requires AutoHotkey v2.0
#SingleInstance Force

if !A_IsAdmin {
    Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp
}

intelSwitchPath := A_ScriptDir "\lg-intel-switch.ps1"
logPath := A_ScriptDir "\lg-intel-switch.log"

; Edit lg-intel-switch.ps1 if your LG monitor uses different input values.
USBC := "usbc"
USBC_ALT := "usbc2"
HDMI1 := "hdmi1"
HDMI2 := "hdmi2"
DISPLAYPORT := "dp"

; Ctrl + Alt + H: HDMI 1
^!h::SwitchDisplays(HDMI1, "HDMI 1")

; Ctrl + Alt + 2: HDMI 2
^!2::SwitchDisplays(HDMI2, "HDMI 2")

; Ctrl + Alt + U: USB-C / Thunderbolt
^!u::SwitchDisplays(USBC, "USB-C")

; Ctrl + Alt + Shift + U: alternate USB-C / DP2-USB-C value
^!+u::SwitchDisplays(USBC_ALT, "USB-C alternate")

; Ctrl + Alt + D: DisplayPort
^!d::SwitchDisplays(DISPLAYPORT, "DisplayPort")

SwitchDisplays(inputValue, inputName) {
    global intelSwitchPath, logPath

    if !FileExist(intelSwitchPath) {
        MsgBox("Missing lg-intel-switch.ps1 next to this AutoHotkey script.", "LG Intel input switch failed", "Iconx")
        return
    }

    q := Chr(34)
    psCommand := "powershell -NoProfile -ExecutionPolicy Bypass -File " q intelSwitchPath q " " inputValue
    command := q A_ComSpec q " /c " q psCommand " > " q logPath q " 2>&1" q
    exitCode := RunWait(command, , "Hide")

    if exitCode != 0 {
        detailCommand := "powershell -ExecutionPolicy Bypass -File " q intelSwitchPath q " " inputValue
        MsgBox(
            Format("Failed to switch to {} through Intel IGCL.`n`nLog:`n{}`n`nRun manually for details:`n{}", inputName, logPath, detailCommand),
            "LG Intel input switch failed",
            "Iconx"
        )
    } else {
        TrayTip("LG monitor input", Format("Intel IGCL command sent: {}", inputName), "Mute")
    }
}
