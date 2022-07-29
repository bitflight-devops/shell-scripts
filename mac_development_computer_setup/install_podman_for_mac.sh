#!/bin/sh
mkdir -p ~/.hammerspoon
cat <<EOF > ~/.hammerspoon/init.lua
#!/usr/bin/env lua
function printf(s,...)  print(s:format(...)) end
wather = hs.caffeinate.watcher.new(function(eventType)
    -- screensDidWake, systemDidWake, screensDidUnlock
    if eventType == hs.caffeinate.watcher.systemDidWake then
        local output = hs.execute("/usr/local/bin/podman machine ssh sudo systemctl restart systemd-timesyncd.service", false)
        hs.notify.new({title="Sync Podman Machine Time At Wake", informativeText=output}):send()
        printf("%s\n", output)
    end
end)
wather:start()
EOF
brew install podman
brew install --cask hammerspoon
xattr -r -d com.apple.quarantine /Applications/Hammerspoon.app


# /Applications/Hammerspoon.app
# /usr/libexec/PlistBuddy -c "set :askForPassword 1" "${HOME}"/Library/Preferences/org.hammerspoon.Hammerspoon.plist
# killall cfprefsd
# defaults read org.hammerspoon.Hammerspoon

podman machine init
podman machine stop
podman machine set --rootful
podman machine start
