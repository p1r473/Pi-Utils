#!/bin/bash

curl_max_time=3
curl_connect_timeout=3
#SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
source "${SCRIPT_DIR}/.credentials"
source "${SCRIPT_DIR}/CheckBot.conf"
source "${SCRIPT_DIR}/log.sh"

# Check if another instance of script is running
pidof -o %PPID -x "$0" >/dev/null && echo "ERROR: Script $0 already running" && exit 1
echo $$ > /run/CheckBot.pid

# /home/pi/WaitForInternet.sh

export PATH=/usr/local/bin/:"$PATH"

touch $tempfile;

# Initialization
if ! grep -q "ping_last_run" "$tempfile"; then
  echo "ping_last_run=0" >> "$tempfile"
fi
if ! grep -q "DNS_last_run" "$tempfile"; then
  echo "DNS_last_run=0" >> "$tempfile"
fi
if ! grep -q "ISP_last_run" "$tempfile"; then
  echo "ISP_last_run=0" >> "$tempfile"
fi
if ! grep -q "speed_last_run" "$tempfile"; then
  echo "speed_last_run=0" >> "$tempfile"
fi
if ! grep -q "VPN_last_run" "$tempfile"; then
  echo "VPN_last_run=0" >> "$tempfile"
fi
if ! grep -q "hosts_last_run" "$tempfile"; then
  echo "hosts_last_run=0" >> "$tempfile"
fi
if ! grep -q "sites_last_run" "$tempfile"; then
  echo "sites_last_run=0" >> "$tempfile"
fi

# Check the hostname of the current system
#hostname=$(hostname)

DNS_all_success=1
DNS_failure_count=0
#DNS_failure_counts=(0 0 0 0 0 0)
#DNS_failure_counts=("${DNS_servers[@]/#/0}")
#DNS_success=(true true true true true true)
host_all_success=1
host_failure_count=0
#host_failure_counts=(0 0 0 0 0)
#host_failure_counts=("${hosts[@]/#/0}")
#host_success=(true true true true true)
ISP_failure_count=0
ping_all_success=1
ping_failure_count=0
site_all_success=1
site_failure_count=0
#site_failure_counts=("${sites[@]/#/0}")
#site_success=(true true true true true)
speed_failure_count=0
VPN_failure_count=0
ISP_success=1
speed_success=1
VPN_success=1
#RouterVPNDead=0
if [[ "$1" == "force" ]]; then
  force=1
else
  force=0
fi

# edumpvar checkPing
# edumpvar ping_all_success
# edumpvar checkDNS
# edumpvar DNS_all_success
# edumpvar checkISP
# edumpvar ISP_success
# edumpvar checkSpeed
# edumpvar speed_success
# edumpvar checkVPN
# edumpvar VPN_success
# edumpvar checkHosts
# edumpvar host_all_success
# edumpvar checkSites
# edumpvar site_all_success

# functions

function should_run_check()
{

  check_name=$1
  interval=$2
  #last_run=$(grep -E "^${check_name}_last_run" "$tempfile" | cut -d "=" -f 2)
  last_run=$(grep -E "^${check_name}_last_run" "$tempfile" | cut -d "=" -f 2 | tr -d '\n')
  current_time=$(date +%s)

  if [[ $last_run -eq -1 ]]; then
    return 1
  fi

  time_since_last_run=$((current_time - last_run))

  # echo "Check name: $check_name"
  # echo "Interval: $interval"
  # echo "Last run: $last_run"
  # echo "Current time: $current_time"
  # echo "Time since last run: $time_since_last_run"
  # echo "Timestamp in tempfile: $(grep -E "^${check_name}_last_run" "$tempfile")"

  if [[ $time_since_last_run -ge $interval ]]; then
    return 1
  elif [[ $force -eq 1 ]]; then
    return 1
  else
    return 0
  fi
}

function update_timestamp()
{
  check_name=$1
  success=$2

  if [[ $success -eq 1 ]]; then
    new_timestamp=$(date +%s)
  else
    new_timestamp=-1
  fi

  sed -i "/^${check_name}_last_run/c\\${check_name}_last_run=$new_timestamp" "$tempfile"

  # echo "Tempfile location: $tempfile"
  # echo "Updating timestamp for $check_name to $(date +%s)"
}

# function reassert_timestamps()
# {
#   if ! grep -q "ping_last_run" "$tempfile"; then
#     echo "ping_last_run=$ping_last_run" >> "$tempfile"
#   fi
#    if ! grep -q "DNS_last_run" "$tempfile"; then
#     echo "DNS_last_run=$DNS_last_run" >> "$tempfile"
#   fi
#    if ! grep -q "ISP_last_run" "$tempfile"; then
#     echo "ISP_last_run=$ISP_last_run" >> "$tempfile"
#   fi
#    if ! grep -q "speed_last_run" "$tempfile"; then
#     echo "speed_last_run=$speed_last_run" >> "$tempfile"
#   fi
#    if ! grep -q "VPN_last_run" "$tempfile"; then
#     echo "VPN_last_run=$VPN_last_run" >> "$tempfile"
#   fi
#    if ! grep -q "hosts_last_run" "$tempfile"; then
#     echo "hosts_last_run=$hosts_last_run" >> "$tempfile"
#   fi
#    if ! grep -q "sites_last_run" "$tempfile"; then
#     echo "sites_last_run=$sites_last_run" >> "$tempfile"
#   fi
# }

function check_DNS
{
  should_run_check "DNS" $DNS_check_interval
  if [ $? -eq 0 ]; then
    checkDNS=0
    return
  fi
  for i in "${!DNS_servers[@]}"; do
    server="${DNS_servers[i]}"
    #DNS_failure_counts[i]=0
    for d in "${domains[@]}"; do 
      #nslookup_output=$(nslookup -retry=$numDNSFailures -timeout=$timeout "$d" "$server" 2>&1)
      #nslookup_exit_code=$?
      #if [[ $nslookup_exit_code -eq 0 && ! $(echo "$nslookup_output" | grep -qiE "connection refused|no servers could be reached") ]]; then
      #if [[ $nslookup_exit_code -eq 0 ]] && ! echo "$nslookup_output" | grep -qiE "connection refused|no servers could be reached"; then
      if nslookup -retry=$numDNSFailures -timeout=$timeout "$d" "$server" >/dev/null; then
        eok "CheckBot successfully nslookuped $d using DNS server $server" false
        #DNS_success[i]=1
      else
        #((DNS_failure_counts[i]++))
        ((DNS_failure_count++))
        ewarn "CheckBot failed to nslookup $d using DNS server $server." false
        #DNS_success[i]=0
        DNS_all_success=0
      fi
    done
  done
  #for i in "${!DNS_success[@]}"; do
  #  if [ "${DNS_success[i]}" = "false" ]; then
  #    DNS_all_success=0
  #    break
  #  fi
  #done
  update_timestamp "DNS" DNS_all_success
  return $DNS_failure_count
}

function check_ISP
{
  should_run_check "ISP" $ISP_check_interval
  if [ $? -eq 0 ]; then
    checkISP=0
    return
  fi
  ISP=$(curl -sSk --ipv4 --max-time $curl_max_time --connect-timeout $curl_connect_timeout https://ipinfo.io/org?token=$ipinfo_token)
  if echo "$ISP" | grep -qi 'Rogers'; then
    ISP_success=0
    ((ISP_failure_count++))
    ewarn "CheckBot warning that we are currently failed over to Rogers" false
  elif echo "$ISP" | grep -qi 'CIK'; then
    if [[ $HOSTNAME == "Harbormaster" ]]
    then
      ISP_success=0
      ((ISP_failure_count++))
      ewarn "CheckBot warning that we aren't currently connected to VPN" false
    else
      ISP_success=1
      ISP_failure_count=0
      eok "CheckBot OK that we are currently connected to CIK" false
    fi
  elif echo "$ISP" | grep -qi 'tzulo'; then
    ISP_success=0
    ISP_failure_count=0
    eok "CheckBot OK that we are currently connected to VPN" false
  elif echo "$ISP" | grep -qi 'tzulo'; then
    ISP_success=0
    ISP_failure_count=0
    eok "CheckBot OK that we are currently connected to VPN" false
  else
    ISP_success=0
    ((ISP_failure_count++))
    ewarn "CheckBot warning that we are currently on an unknown ISP: $ISP" false
  fi
  update_timestamp "ISP" ISP_success
  return $ISP_failure_count
}


function check_speed()
{
  should_run_check "speed" $speed_check_interval
  if [ $? -eq 0 ]; then
    checkSpeed=0
    return
  fi

  RESULT=$(/usr/bin/python3 /home/pi/speedtest-cli/speedtest.py)
  DOWNLOAD=$(echo "$RESULT" | grep Download | grep -oP '\d*[.]\d*\s*Mbit/s')
  DOWNLOADINT=$(echo "$DOWNLOAD" | grep -oP '\d{1,9}[.]' | grep -oP '\d{1,9}')
  PING=$(echo "$RESULT" | grep 'Hosted by' | grep -oP '\d*[.]\d*\s*ms')
  UPLOAD=$(echo "$RESULT" | grep Upload | grep -oP '\d*[.]\d*\s*Mbit/s')

  if (( $(echo "$DOWNLOADINT < 10" | bc -l) )); then
    speed_success=0
    ((speed_failure_count++))
    eerror "CheckBot warning that we are currently experiencing speeds < 10 Mbit/s. Ping: $PING | Download: $DOWNLOAD | Upload: $UPLOAD" false
  else
    speed_success=1
    speed_failure_count=0
    eok "CheckBot OK that we are currently experiencing speeds > 10 Mbit/s. Ping: $PING | Download: $DOWNLOAD | Upload: $UPLOAD" false
  fi

  #reassert_timestamps
  update_timestamp "speed" speed_success

  return $speed_failure_count
}


function check_VPN
{
  VPN_success=1
  should_run_check "VPN" $VPN_check_interval
  if [ $? -eq 0 ]; then
    checkVPN=0
    return
  fi
  KEYWORD='You are not connected to Mullvad'
  IP=$(curl -sSk --ipv4 --max-time $curl_max_time --connect-timeout $curl_connect_timeout https://am.i.mullvad.net/connected)
  if echo "$IP" | grep -q "$KEYWORD"; then
    VPN_success=0
    ((VPN_failure_count++))
  else
    VPN_success=1
    VPN_failure_count=0
  fi
  update_timestamp "VPN" VPN_success
  return $VPN_failure_count
}

function check_ping
{
  #RouterVPNDead=0
  should_run_check "ping" $ping_check_interval
  if [ $? -eq 0 ]; then
    checkPing=0
    return
  fi
  for i in "${!ping_IPs[@]}"; do
    ping="${ping_IPs[i]}"
    if [ -z "$ping" ]; then
      continue
    fi
    if ping -c 1 -W "$timeout" "$ping" >/dev/null; then
      eok "CheckBot OK that host $ping is pingable" false
      #ping_success[i]=1
    else
      #((ping_failure_counts[i]++))
      ((ping_failure_count++))
      ewarn "CheckBot warning that host $ping is unpingable." false
      #ping_success[i]=0
      ping_all_success=0
      #if [[ " ${IPsToSetDead[@]} " =~ " ${ping} " ]]; then
      #if [[ " ${IPsToSetDead[*]} " == *"$i"* ]]; then
      #for ip in "${IPsToSetDead[@]}"; do
      #if [ "$ip" == "$ping" ]; then
      if printf '%s\n' "${IPsToSetDead[@]}" | grep -q -P "^$ping$"; then
        echo "Ping failed for IP: $ping"
        #RouterVPNDead=1
        break
      fi
    fi
  done
  update_timestamp "ping" ping_all_success
  return $ping_failure_count
}

function check_hosts
{
  should_run_check "hosts" $hosts_check_interval
  if [ $? -eq 0 ]; then
    checkHosts=0
    return
  fi
  for i in "${!hosts[@]}"; do
    host="${hosts[i]}"
    if [ -z "$host" ]; then
      continue
    fi
    if ping -c 1 -W "$timeout" "$host" >/dev/null; then
      eok "CheckBot OK that host $host is reachable" false
      #host_success[i]=1
    else
      #((host_failure_counts[i]++))
      ((host_failure_count++))
      ewarn "CheckBot warning that host $host is unreachable." false
      #host_success[i]=0
      host_all_success=0
    fi
  done
  #for i in "${!host_success[@]}"; do
  #  if [ "${host_success[i]}" = "false" ]; then
  #    host_all_success=0
  #    break
  #  fi
  #done
  update_timestamp "hosts" host_all_success
  return $host_failure_count
}


function check_sites
{
  should_run_check "sites" $sites_check_interval
  if [ $? -eq 0 ]; then
    checkSites=0
    return
  fi
  for i in "${!sites[@]}"; do
    site="${sites[i]}"
    if [ -z "$site" ]; then
      continue
    fi
    if wget --no-check-certificate --spider --timeout=$timeout --tries=$numSitesFailures "$site" 2>&1 | grep -q "200 OK"; then
      eok "CheckBot OK that we could wget $site" false
      #site_success[i]=1
    else
      #((site_failure_counts[i]++))
      ((site_failure_count++))
      ewarn "CheckBot warning that we could not wget $site." false
      #site_success[i]=0
      site_all_success=0
    fi
  done
  #for i in "${!site_success[@]}"; do
  #  if [ "${site_success[i]}" = "false" ]; then
  #    site_all_success=0
  #    break
  #  fi
  #done
  update_timestamp "sites" site_all_success
  return $site_failure_count
}


# loop to check ping, DNS, ISP, speed, VPN, hosts, and sites
#while true; do
# check ping
if [ $checkPing -eq 1 ]; then
  check_ping
  ping_failure_count=$?
fi
if [ $checkPing -eq 1 ] && [ $ping_all_success -eq 1 ]; then
    eok "CheckBot OK that pings were a success." false
elif [ $checkPing -eq 1 ] && [ $ping_all_success -eq 0 ]; then
    eerror "CheckBot error that pings are failing. There were $ping_failure_count failures." false
    #for i in 1 2 3; do
    #for i in $(seq 1 $numPingFailures); do
    #  ping_all_success=1
    #if [ "$HOSTNAME" == "Monkeebutt" ]; then
    #    /bin/bash /home/pi/CommandCenter.sh resume_Mullvad_router
		#elif [ "$HOSTNAME" == "Harbormaster" ]; then
		#    /bin/bash /home/pi/Mullvad.sh restart
		#else
		#    ewarn "Error restarting VPN: unsupported host $HOSTNAME" false
		#fi
    #  check_ping
    #  if [ $RouterVPNDead -eq 1 ]; then
    #  	break
    #  fi
    #  if [ $ping_all_success -eq 1 ]; then
    #    break
    #  fi
    #done
    # if [ $RouterVPNDead -eq 0 ]; then
    #   eok "CheckBot OK that pings were a success after restarting Mullvad on the router." false
    # elif [ $i -eq 3 ] && [ $RouterVPNDead -eq 1 ]; then
    #   eerror "CheckBot error that pings are still failing after 3 attempts. There were $ping_failure_count failures." false
    # fi
fi

  # check DNS
  if [ $checkDNS -eq 1 ]; then
    check_DNS
    DNS_failure_count=$?
  fi
  if [ $checkDNS -eq 1 ] && [ $DNS_all_success -eq 1 ]; then
      eok "CheckBot OK that DNS lookups were a success." false
  elif [ $checkDNS -eq 1 ] && [ $DNS_all_success -eq 0 ]; then
    #(($DNS_failure_count >= numDNSFailures)); then
      eerror "CheckBot error that DNS lookups are failing. There were $DNS_failure_count failures." false
  fi

  # check ISP
  if [ $checkISP -eq 1 ]; then
    check_ISP
    ISP_failure_count=$?
  fi
  if [ $checkISP -eq 1 ] && [ $ISP_success -eq 1 ] ; then
    eok "CheckBot OK that current ISP is CIK." false
  elif [ $checkISP -eq 1 ] && [ $ISP_success -eq 0 ] ; then
    #((ISP_failure_count >= numISPFailures)); then
    eerror "CheckBot error that we are currently not connected to CIK ISP. There were $ISP_failure_count failures." false
  fi

  # check speed
  if [ $checkSpeed -eq 1 ]; then
    check_speed
    speed_failure_count=$?
  fi

  if [ $checkSpeed -eq 1 ] && [ $speed_success -eq 1 ]; then
      eok "CheckBot OK that internet speeds are OK" false
  elif [ $checkSpeed -eq 1 ] && [ $speed_success -eq 0 ]; then
    #((speed_failure_count >= numSpeedFailures)); then
      eerror "CheckBot error that internet speeds are low. There were $speed_failure_count failures." false
  fi

  # check VPN
  if [ $checkVPN -eq 1 ]; then
    check_VPN
    VPN_failure_count=$?
  fi
  if [ $checkVPN -eq 1 ] && [ $VPN_success -eq 1 ]; then
    eok "CheckBot OK that we are connected to VPN" false
  elif [ $checkVPN -eq 1 ] && [ $VPN_success -eq 0 ]; then
    #((VPN_failure_count >= numVPNFailures)); then
      eerror "CheckBot error that we were not connected to the VPN. There were $VPN_failure_count failures." false
      #for i in 1 2 3; do
    #for i in $(seq 1 $numVPNFailures); do
      #VPN_success=1
      # if [ "$HOSTNAME" == "Monkeebutt" ]; then
		  #   /bin/bash /home/pi/CommandCenter.sh resume_Mullvad_router
		  # elif [ "$HOSTNAME" == "Harbormaster" ]; then
		  #  /bin/bash /home/pi/Mullvad.sh restart
		  # else
		  #  ewarn "Error restarting VPN: unsupported host $HOSTNAME" false
		  # fi
      #check_VPN
      #if [ $VPN_success -eq 1 ]; then
      #	break
      #fi
    #done
    # if [ $VPN_success -eq 1 ]; then
    #   eok "CheckBot OK that VPN is connected after restarting Mullvad on the router." false
    # elif [ $i -eq 3 ] && [ $VPN_success -eq 0 ]; then
    #   eerror "CheckBot error that VPN is still not connected after 3 attempts. There were $vpn_failure_count failures." false
    # fi
  fi

# check hosts
  if [ $checkHosts -eq 1 ]; then
    check_hosts
    host_failure_count=$?
  fi
  if [ $checkHosts -eq 1 ] && [ $host_all_success -eq 1 ]; then
    eok "CheckBot OK that host lookups were successful." false
  elif [ $checkHosts -eq 1 ] && [ $host_all_success -eq 0 ]; then
    eerror "CheckBot error that host lookups are failing. There were $host_failure_count failures." false
  fi

# check sites
if [ $checkSites -eq 1 ]; then
  check_sites
  site_failure_count=$?
fi
if [ $checkSites -eq 1 ] && [ $site_all_success -eq 1 ]; then
    eok "CheckBot OK that all site access were successful." false
elif [ $checkSites -eq 1 ] && [ $site_all_success -eq 0 ]; then
    eerror "CheckBot error that site access are failing. There were $site_failure_count failures." false
fi

#if ! rm "$tempfile"; then
#    ewarn "CheckBot could not remove temporary file $tempfile" false
#fi

# edumpvar checkPing
# edumpvar ping_all_success
# edumpvar checkDNS
# edumpvar DNS_all_success
# edumpvar checkISP
# edumpvar ISP_success
# edumpvar checkSpeed
# edumpvar speed_success
# edumpvar checkVPN
# edumpvar VPN_success
# edumpvar checkHosts
# edumpvar host_all_success
# edumpvar checkSites
# edumpvar site_all_success

if [ $checkPing -eq 1 ] || [ $checkDNS -eq 1 ] || [ $checkISP -eq 1 ] || [ $checkSpeed -eq 1 ] || [ $checkVPN -eq 1 ] || [ $checkHosts -eq 1 ] || [ $checkSites -eq 1 ]; then
   if [[ ($checkPing -eq 1 && $ping_all_success -eq 0) || ($checkDNS -eq 1 && $DNS_all_success -eq 0) || ($checkISP -eq 1 && $ISP_success -eq 0) || ($checkSpeed -eq 1 && $speed_success -eq 0) || ($checkVPN -eq 1 && $VPN_success -eq 0) || ($checkHosts -eq 1 && $host_all_success -eq 0) || ($checkSites -eq 1 && $site_all_success -eq 0) ]]; then
      blink1-tool --red >/dev/null
      exit 1
   else
    blink1-tool --off >/dev/null
    exit 0
  fi
fi


# sleep for the configured interval
# sleep $sleep_interval
#done
 
