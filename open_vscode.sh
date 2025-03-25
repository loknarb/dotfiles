#!/bin/bash
osascript -e '
tell application "Visual Studio Code"
    if it is running then
        activate
    else
        launch
    end if
end tell'
