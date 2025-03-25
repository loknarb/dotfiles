#!/bin/bash
osascript -e '
tell application "iTerm"
    if (count of windows) = 0 then
        create window with default profile
    else
        activate
    end if
end tell'
