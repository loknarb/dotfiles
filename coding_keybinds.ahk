#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir  ; Ensures a consistent starting directory.
SetTitleMatchMode 2  ; Title can be part of the full title
SetCapsLockState "AlwaysOff"

; === Global Hotkeys ===
^!+z::WinSetAlwaysOnTop -1, "A"  ; Ctrl+Alt+Shift+Z to toggle window always on top
^q::Send "!{F4}"                  ; Ctrl+Q to close window
#r::Send "^r"                     ; Win+R to reload
!+z::{  ; Alt + Shift + Z
    SetTitleMatchMode(2)  ; Allows partial window title matching
    if WinExist("ahk_exe Code.exe")  ; Check if VS Code is running
    {
        WinActivate()  ; Bring VS Code to the front
    }
    else
    {
        Run("cmd.exe /c code .", , "Hide")  ; Open VS Code in the current directory
    }
}
!+x::{  ; Alt + Shift + X
    if WinExist("ahk_exe WindowsTerminal.exe")
    {
        WinActivate()  ; Bring Windows Terminal to the front
    }
    else
    {
        Run("wt.exe")
    }
}


; === Window Management ===
^j::Send "#{Left}"                  ; Ctrl+J to snap window left
^Enter::Send "#{Up}"                    ; Ctrl+Enter to maximize window
^k::Send "#{Down}"                  ; Ctrl+K to minimize window
^l::Send "#{Right}"                 ; Ctrl+L to snap window right
#+5::Send "{^+5}"                   ; Win+Shift+5 shortcut
; === Symbol Input (When CapsLock is OFF) ===
#HotIf !GetKeyState("CapsLock", "P")
    !a::Send "{(}"
    !d::Send "{)}"
    !+a::Send "{[}"
    !+d::Send "{]}"
    !j::Send "{{}"
    !k::Send "{}}"
    
    ; Punctuation
    !s:: Send "{:}"
    !+s:: Send "{;}"
    !+f:: Send "{'}"
    !f:: Send "{`"}"
    !h::Send "{Delete}"
    
    ; Logical Operators
    !q::Send "{&}"
    !+w::Send "{=}"
    !e::Send "{|}"
    !+q::Send "{<}"

; === WhatsApp-Specific Controls ===
#HotIf WinActive("ahk_exe WhatsApp.exe")
    ; German Umlauts
    !a::Send "{U+00E4}"  ; ä
    !+a::Send "{U+00C4}" ; Ä
    !u::Send "{U+00FC}"  ; ü
    !+u::Send "{U+00DC}" ; Ü
    !o::Send "{U+00F6}"  ; ö
    !+o::Send "{U+00D6}" ; Ö
    !s::Send "{U+00DF}"  ; ß

; === Anki-Specific Controls ===
#HotIf WinActive("ahk_exe anki.exe")
    ; German Umlauts (same as WhatsApp)
    !a::Send "{U+00E4}"
    !+a::Send "{U+00C4}"
    !u::Send "{U+00FC}"
    !+u::Send "{U+00DC}"
    !o::Send "{U+00F6}"
    !+o::Send "{U+00D6}"
    !s::Send "{U+00DF}"
    
    ; Navigation and Controls
    +WheelDown::Send "{WheelRight}"
    +WheelUp::Send "{WheelLeft}"
    !1::Send "^!1"
    !2::Send "^!2"
    !3::Send "^!3"
    !4::Send "^!5"
    +space::Send "{Shift Up}{Right}"
    ^space::Send "{Ctrl Up}{Left}"
    !WheelUp::Send "^+>"
    !WheelDown::Send "^+<"
#HotIf
