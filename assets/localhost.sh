#!/bin/bash
export PATH="/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin:/root/bin"

log="/tmp/iptables.log"
regex=":90\|:41\|:17\|tor"
lines=$(iptables -L | grep -e "$regex" | tee "$log" | wc -l)
if (( $lines < 15 ))
then
  echo "------[$(date)]: Waiting on network... Retrying------"
else
  iptables -I OUTPUT -p tcp --dport 21325 -j ACCEPT -s localhost -d localhost
  iptables -I INPUT -p tcp --dport 21325 -j ACCEPT -s localhost -d localhost
  echo 'user_pref("network.proxy.no_proxies_on", "127.0.0.1");' >> ~amnesia/.tor-browser/profile.default/prefs.js

  export DISPLAY=:1
  export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
  runuser -c 'notify-send "IPTables enabled @ 127.0.0.1:21325" "Trezor Bridge ready. Restart your browser if open."' amnesia

  rm -f /etc/cron.d/localhost
fi