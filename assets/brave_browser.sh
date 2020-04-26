#!/bin/bash
export PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin:/root/bin"

rm -f /etc/cron.d/brave_browser
log="/tmp/brave_browser.log"
echo 1 > /proc/sys/kernel/unprivileged_userns_clone
echo "Done" >> "$log"
export DISPLAY=:1
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
runuser -c 'notify-send "Brave enablement complete" "The Brave Browser will be ready when install completes"' amnesia
