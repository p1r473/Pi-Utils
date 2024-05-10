#!/bin/bash
SSH_timeout=3

title="Command Center online."
prompt="Pick an option: "
options=("Pihole Status" "Pihole Restart DNS" "Pihole Update Adlists" "Pihole Update Gravity" "Pihole Update" "Pihole Pause" "Pihole Resume" "Mullvad Status" "Mullvad Toggle [all]" "Mullvad Pause [all]" "Mullvad Resume [all]" "Mullvad Toggle [Router]" "Mullvad Pause [Router]" "Mullvad Resume [Router]" "Mullvad Toggle [Pi]" "Mullvad Pause [Pi]" "Mullvad Resume [Pi]" "Skynet Pause " "Skynet Resume" "Status Everything" "Pause Everything" "Resume Everything" "Siren Start" "Siren Stop" "Gaming Process Kill" "EmulationStation Start" "ScummVM Start" "Saved Games Backup" "Saved Games Restore" "RAM Usage" "CPU Usage" "Temperatures" "CPU Clock" "CPU Throttle" "GPU Clock" "Hardware" "Toggle Backlight" "Restart" "Restart Everything" "Shutdown" "Shutdown Everything" "Lock PC" "Unlock PC" "Lock Everything" "Brown Noise [Bedroom]" "Brown Noise [Office]" "Silence")

myHostname=
otherHostname=
if [[ $HOSTNAME == "Monkeebutt" ]]
then
  myHostname="Monkeebutt"
  otherHostname="Harbormaster"
elif [[ $HOSTNAME == "Harbormaster" ]]
then
  myHostname="Harbormaster"
  otherHostname="Monkeebutt"
fi

shopt -s expand_aliases
alias ssh='/home/pi/custom_ssh'

selector=$1;
if [ ! -z "$selector" ]
then 
    case "$selector" in
    1 | status_Pihole) echo "Pihole Status";  echo $myHostname; pihole status; echo $otherHostname; ssh "pihole status";;
    2 | restart_Pihole) echo "Restarting Pihole"; echo $myHostname; pihole restartdns; echo $otherHostname; ssh "pihole restartdns";;
    3 | pihole_adlists) echo "Updating Pihole Adlists"; echo $myHostname; /home/pi/adlist-sequence.sh; echo $otherHostname; ssh "/home/pi/adlist-sequence.sh";;
    4 | pihole_gravity) echo "Updating Pihole Gravity"; echo $myHostname; pihole -g;  echo $otherHostname; ssh "pihole -g"; ssh "pihole -g";;
    5 | pihole_update) echo "Updating Pihole"; echo $myHostname; pihole -up; echo $otherHostname; ssh "pihole -up";;
    6 | pause_Pihole) echo "Pausing Pihole"; echo $myHostname; pihole disable 30m; echo $otherHostname; ssh "pihole disable 30m";;
    7 | resume_Pihole) echo "Resuming Pihole"; echo $myHostname; pihole enable; echo $otherHostname; ssh "pihole enable";;
    8 | status_Mullvad) echo "Mullvad Status"; echo "PortRoyal "; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh status"; echo $myHostname; /home/pi/Mullvad.sh status; echo $otherHostname; ssh "/home/pi/Mullvad.sh status";;
    9 | toggle_Mullvad) echo "Toggling Mullvad [all]"; echo "PortRoyal "; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh toggle policy"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh toggle";;
    10 | pause_Mullvad) echo "Pausing Mullvad [all]"; echo "PortRoyal "; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh stop"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh stop";;
    11 | resume_Mullvad) echo "Resuming Mullvad [all]"; echo "PortRoyal "; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh start policy"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh start";;
    12 | toggle_Mullvad_router) echo "Toggling Mullvad [Router]"; echo "PortRoyal "; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh toggle policy";;
    13 | pause_Mullvad_router) echo "Pausing Mullvad [Router]"; echo "PortRoyal "; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh stop";;
    14 | resume_Mullvad_router) echo "Resuming Mullvad [Router]"; echo "PortRoyal "; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh start policy";;
    15 | toggle_Mullvad_router_pi) echo "Toggling Mullvad [Pi]"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh toggle";;
    16 | pause_Mullvad_pi) echo "Pausing Mullvad [Pi]"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh stop";;
    17 | resume_Mullvad_pi) echo "Resuming Mullvad [Pi]"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh start";;
    18 | pause_Skynet) echo "Pausing Skynet"; ssh PortRoyal "/jffs/scripts/firewall disable";;
    19 | resume_Skynet) echo "Resuming Skynet"; ssh PortRoyal "/jffs/scripts/firewall restart";;
    20 | status) echo "Status Everything"; echo $myHostname; pihole status; /home/pi/Mullvad.sh status; echo "PortRoyal"; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh status"; echo $otherHostname; ssh "pihole status";  ssh otherHostname "/home/pi/Mullvad.sh status";;
    21 | pause) echo "Pausing Everything"; echo $myHostname; pihole disable 30m; echo "PortRoyal"; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh stop"; ssh PortRoyal "/jffs/scripts/firewall disable"; echo $otherHostname; ssh "pihole disable 30m"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh disable";;
    22 | resume) echo "Resuming Everything"; echo $myHostname; pihole enable; echo "PortRoyal"; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh start"; ssh PortRoyal "/jffs/scripts/firewall restart"; echo $otherHostname; ssh "pihole enable"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh start";;
    23 | start_siren) echo "Starting Siren"; /home/pi/Siren/SirenStart.sh;;
    24 | stop_siren) echo "Stopping Siren"; /home/pi/Siren/SirenStop.sh;;
    #for i in `cat hostlist`;do ssh -q $i kill `ssh -q $i ps -ef | grep <process name>|awk '{print $2}'`;done
    #ssh remotehost "kill -9 \$(ps -aux | grep foo | grep bar | awk '{print \$2}')"
    #25) echo "Killing Gaming Process"; ssh Tron kill -9 ` ssh Tron ps -ef | grep 'scummvm\|retroarch\|emulationstation'|awk '{print $2}'`;;
    25 | kill_game) echo "Killing Gaming Process"; ssh Tron "kill -9 \$(ps -aux | grep 'scummvm\|retroarch\|emulationstation' | awk '{print \$2}')";;
    26 | emulationstation) echo "Starting EmulationStation and RetroArch"; ssh Tron "su pi /usr/bin/emulationstation" &;;
    27 | ScummVM) echo "Starting ScummVM"; ssh Tron "/usr/games/scummvm" &;;
    28 | backup_saves) echo "Backing up saved games"; ssh Tron "find /home/pi/RetroPie/roms/ -name "*.srm" -o -name "*.state*" | tar --transform 's|/home/pi/||g' -PcJf /home/pi/savegamebackup/savegames.$(date +%Y-%m-%d).tar.xz -T -";;
    #29) echo "Restored Saved Games"; ssh Tron "tar -C /home/pi/ -xJf /home/pi/savegamebackup/current/retropie_saves.tar.xz";;
    29 | restore_savegame) echo "Restored Saved Games"; ssh Tron "ls -t -d -1 "/home/pi/savegamebackup/"* | head -n1 | xargs tar -C /home/pi/ -xJf";;
    30 | RAM) echo "Checking RAM Usage"; free;;
    31 | CPU) echo "Checking CPU Usage"; top;;
    32 | temp) echo "Checking Temperatures"; /home/pi/temperature.sh;;
    33 | clock) echo "Checking CPU Clock"; watch -n 1 vcgencmd measure_clock arm;;
    34 | throttle) echo "Checking CPU Throttle"; watch -n 1 vcgencmd get_throttled show;;
    35 | GPU) echo "Checking GPU Clock"; watch -n 1 vcgencmd measure_clock v3d;;
    36 | hardware) echo "Showing hardware"; /home/pi/monitor.sh;;
    37 | toggle_backlight) echo "Toggling backlight"; ssh Harbormaster "rpi-backlight -p toggle"; ssh Monkeebutt "sudo /home/pi/rpi-hdmi.sh toggle";;
    38 | reboot) echo "Restarting"; reboot;;
    39 | restart | reboot) echo "Restarting Everything"; echo "Shield"; adb connect Shield; adb reboot; echo "Firewalla.RumRunnersIsle"; ssh Firewalla.RumRunnersIsle "sudo reboot"; echo "pwnagotchi"; ssh pwnagotchi "sudo reboot"; echo "Tron"; ssh Tron "sudo reboot"; echo $otherHostname; ssh "sudo reboot"; echo "NetMonitor"; ssh NetMonitor "sudo reboot"; echo "Steamdeck"; ssh Steamdeck "sudo reboot"; echo "Firewalla"; ssh Firewalla "sudo reboot"; echo "PortRoyal"; ssh PortRoyal "reboot"; echo "Firewalla.RumRunnersIsle"; ssh BlackPearl 'psexec -s -i 1 "psshutdown.exe" -r -f -t 0'; echo $myHostname; sudo reboot;;
    40 | shutdown_pi) echo "Shutting down"; shutdown now;;
    41 | shutdown) echo "Shutting down everything"; echo "Shield"; adb connect Shield; adb shutdown; echo "Firewalla.RumRunnersIsle"; ssh Firewalla.RumRunnersIsle "sudo shutdown now"; echo "pwnagotchi"; ssh pwnagotchi "sudo reboot"; echo "Tron"; ssh Tron "sudo shutdown now"; echo $otherHostname; ssh "sudo shutdown now"; echo "NetMonitor"; ssh NetMonitor "sudo shutdown now"; echo "Steamdeck"; ssh Steamdeck "sudo shutdown now"; echo "Firewalla"; ssh Firewalla "sudo shutdown now";  echo "Firewalla.RumRunnersIsle"; ssh BlackPearl "psexec -s -i 1 "psshutdown.exe" -f -t 0"; echo $myHostname; sudo shutdown now;;
    # Locking PC: psexec -s -i 1 \\HOSTNAME "C:\Windows\System32\psshutdown.exe" -l -t 0
    # Sleeping PC: psshutdown -d -t 0
    # Shutdown PC: psshutdown -f -t 0
    # Rebooting PC: psshutdown -r -t 0
    42 | lockPC) echo "Locking PC"; ssh BlackPearl "psexec -s -i 1 "psshutdown.exe" -l -t 0";;
    # Shutdown PC: psshutdown -f -t 0
    #Original script
    #The problem was, that without opening an RDP connection first, quser $env:USERNAME shows an already active session with the name "console", and executing tscon $sessionid /dest:console throws error 7045. This however can be easily fixed by running tsdiscon $sessionid before running tscon $sessionid /dest:console.
    #There is one catch though when doing this in the script: When ((quser $env:USERNAME | select -Skip 1) -split '\s+')[2] is executed before tsdiscon, it returns the session name ("console"). So simply running tsdiscon $sessionid; tscon $sessionid /dest:console would not work, as the disconnected session does not have a name anymore, so the ID has to be used instead.
    #This however can be easily fixed by executing ((quser $env:USERNAME | select -Skip 1) -split '\s+')[2] again after running tsdiscon, which then returns the session ID instead the name. The complete script therefor is:
    #@powershell -NoProfile -ExecutionPolicy unrestricted -Command "$sessionid=((quser $env:USERNAME | select -Skip 1) -split '\s+')[2]; tscon $sessionid /dest:console" 2> UnlockErrors.log
    43 | unlockPC) echo "Unlocking PC"; ssh BlackPearl 'powershell -NoProfile -ExecutionPolicy unrestricted -Command "$sessionid=((quser $env:USERNAME | select -Skip 1) -split '\''\s+'\'')[2]; tsdiscon $sessionid; $sessionid=((quser $env:USERNAME | select -Skip 1) -split '\''\s+'\'')[2]; tscon $sessionid /dest:console"';;
    44 | lock) echo "Locking everything"; echo "Harbormaster"; ssh Harbormaster "rpi-backlight -p off"; echo "Monkeebutt"; ssh Monkeebutt "sudo /home/pi/rpi-hdmi.sh toggle"; ssh BlackPearl "psexec -s -i 1 "psshutdown.exe" -l -t 0";;
    45 | sleep) echo "Brown Noise [Bedroom]"; /usr/bin/python3 /home/pi/Siren/BedroomStart_BrownNoise.py;;
    46 | work) echo "Brown Noise [Office]"; /usr/bin/python3 /home/pi/Siren/OfficeStart_BrownNoise.py;;
    47 | silence) echo "Silence"; /usr/bin/python3 /home/pi/Siren/silence.py;;
    $((${#options[@]}+1))) exit;;
    *) echo "Invalid option.";;
    esac
exit
fi

echo "$title"
PS3="$prompt"
select opt in "${options[@]}" "Quit";do
    case "$REPLY" in
    1 | status_Pihole) echo "Pihole Status";  echo $myHostname; pihole status; echo $otherHostname; ssh "pihole status";;
    2 | restart_Pihole) echo "Restarting Pihole"; echo $myHostname; pihole restartdns; echo $otherHostname; ssh "pihole restartdns";;
    3 | pihole_adlists) echo "Updating Pihole Adlists"; echo $myHostname; /home/pi/adlist-sequence.sh; echo $otherHostname; ssh "/home/pi/adlist-sequence.sh";;
    4 | pihole_gravity) echo "Updating Pihole Gravity"; echo $myHostname; pihole -g;  echo $otherHostname; ssh "pihole -g"; ssh "pihole -g";;
    5 | pihole_update) echo "Updating Pihole"; echo $myHostname; pihole -up; echo $otherHostname; ssh "pihole -up";;
    6 | pause_Pihole) echo "Pausing Pihole"; echo $myHostname; pihole disable 30m; echo $otherHostname; ssh "pihole disable 30m";;
    7 | resume_Pihole) echo "Resuming Pihole"; echo $myHostname; pihole enable; echo $otherHostname; ssh "pihole enable";;
    8 | status_Mullvad) echo "Mullvad Status"; echo "PortRoyal "; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh status"; echo $myHostname; /home/pi/Mullvad.sh status; echo $otherHostname; ssh "/home/pi/Mullvad.sh status";;
    9 | toggle_Mullvad) echo "Toggling Mullvad [all]"; echo "PortRoyal "; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh toggle policy"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh toggle";;
    10 | pause_Mullvad) echo "Pausing Mullvad [all]"; echo "PortRoyal "; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh stop"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh stop";;
    11 | resume_Mullvad) echo "Resuming Mullvad [all]"; echo "PortRoyal "; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh start policy"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh start";;
    12 | toggle_Mullvad_router) echo "Toggling Mullvad [Router]"; echo "PortRoyal "; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh toggle policy";;
    13 | pause_Mullvad_router) echo "Pausing Mullvad [Router]"; echo "PortRoyal "; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh stop";;
    14 | resume_Mullvad_router) echo "Resuming Mullvad [Router]"; echo "PortRoyal "; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh start policy";;
    15 | toggle_Mullvad_router_pi) echo "Toggling Mullvad [Pi]"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh toggle";;
    16 | pause_Mullvad_pi) echo "Pausing Mullvad [Pi]"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh stop";;
    17 | resume_Mullvad_pi) echo "Resuming Mullvad [Pi]"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh start";;
    18 | pause_Skynet) echo "Pausing Skynet"; ssh PortRoyal "/jffs/scripts/firewall disable";;
    19 | resume_Skynet) echo "Resuming Skynet"; ssh PortRoyal "/jffs/scripts/firewall restart";;
    20 | status) echo "Status Everything"; echo $myHostname; pihole status; /home/pi/Mullvad.sh status; echo "PortRoyal"; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh status"; echo $otherHostname; ssh "pihole status";  ssh otherHostname "/home/pi/Mullvad.sh status";;
    21 | pause) echo "Pausing Everything"; echo $myHostname; pihole disable 30m; echo "PortRoyal"; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh stop"; ssh PortRoyal "/jffs/scripts/firewall disable"; echo $otherHostname; ssh "pihole disable 30m"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh disable";;
    22 | resume) echo "Resuming Everything"; echo $myHostname; pihole enable; echo "PortRoyal"; ssh PortRoyal "/opt/etc/wireguard.d/Mullvad.sh start"; ssh PortRoyal "/jffs/scripts/firewall restart"; echo $otherHostname; ssh "pihole enable"; echo "Harbormaster"; ssh Harbormaster "/home/pi/Mullvad.sh start";;
    23 | start_siren) echo "Starting Siren"; /home/pi/Siren/SirenStart.sh;;
    24 | stop_siren) echo "Stopping Siren"; /home/pi/Siren/SirenStop.sh;;
    #for i in `cat hostlist`;do ssh -q $i kill `ssh -q $i ps -ef | grep <process name>|awk '{print $2}'`;done
    #ssh remotehost "kill -9 \$(ps -aux | grep foo | grep bar | awk '{print \$2}')"
    #25) echo "Killing Gaming Process"; ssh Tron kill -9 ` ssh Tron ps -ef | grep 'scummvm\|retroarch\|emulationstation'|awk '{print $2}'`;;
    25 | kill_game) echo "Killing Gaming Process"; ssh Tron "kill -9 \$(ps -aux | grep 'scummvm\|retroarch\|emulationstation' | awk '{print \$2}')";;
    26 | emulationstation) echo "Starting EmulationStation and RetroArch"; ssh Tron "su pi /usr/bin/emulationstation" &;;
    27 | ScummVM) echo "Starting ScummVM"; ssh Tron "/usr/games/scummvm" &;;
    28 | backup_saves) echo "Backing up saved games"; ssh Tron "find /home/pi/RetroPie/roms/ -name "*.srm" -o -name "*.state*" | tar --transform 's|/home/pi/||g' -PcJf /home/pi/savegamebackup/savegames.$(date +%Y-%m-%d).tar.xz -T -";;
    #29) echo "Restored Saved Games"; ssh Tron "tar -C /home/pi/ -xJf /home/pi/savegamebackup/current/retropie_saves.tar.xz";;
    29 | restore_savegame) echo "Restored Saved Games"; ssh Tron "ls -t -d -1 "/home/pi/savegamebackup/"* | head -n1 | xargs tar -C /home/pi/ -xJf";;
    30 | RAM) echo "Checking RAM Usage"; free;;
    31 | CPU) echo "Checking CPU Usage"; top;;
    32 | temp) echo "Checking Temperatures"; /home/pi/temperature.sh;;
    33 | clock) echo "Checking CPU Clock"; watch -n 1 vcgencmd measure_clock arm;;
    34 | throttle) echo "Checking CPU Throttle"; watch -n 1 vcgencmd get_throttled show;;
    35 | GPU) echo "Checking GPU Clock"; watch -n 1 vcgencmd measure_clock v3d;;
    36 | hardware) echo "Showing hardware"; /home/pi/monitor.sh;;
    37 | toggle_backlight) echo "Toggling backlight"; ssh Harbormaster "rpi-backlight -p toggle"; ssh Monkeebutt "sudo /home/pi/rpi-hdmi.sh toggle";;
    38 | reboot) echo "Restarting"; reboot;;
    39 | restart | reboot) echo "Restarting Everything"; echo "Shield"; adb connect Shield; adb reboot; echo "Firewalla.RumRunnersIsle"; ssh Firewalla.RumRunnersIsle "sudo reboot"; echo "pwnagotchi"; ssh pwnagotchi "sudo reboot"; echo "Tron"; ssh Tron "sudo reboot"; echo $otherHostname; ssh "sudo reboot"; echo "NetMonitor"; ssh NetMonitor "sudo reboot"; echo "Steamdeck"; ssh Steamdeck "sudo reboot"; echo "Firewalla"; ssh Firewalla "sudo reboot"; echo "PortRoyal"; ssh PortRoyal "reboot"; echo "Firewalla.RumRunnersIsle"; ssh BlackPearl 'psexec -s -i 1 "psshutdown.exe" -r -f -t 0'; echo $myHostname; sudo reboot;;
    40 | shutdown_pi) echo "Shutting down"; shutdown now;;
    41 | shutdown) echo "Shutting down everything"; echo "Shield"; adb connect Shield; adb shutdown; echo "Firewalla.RumRunnersIsle"; ssh Firewalla.RumRunnersIsle "sudo shutdown now"; echo "pwnagotchi"; ssh pwnagotchi "sudo reboot"; echo "Tron"; ssh Tron "sudo shutdown now"; echo $otherHostname; ssh "sudo shutdown now"; echo "NetMonitor"; ssh NetMonitor "sudo shutdown now"; echo "Steamdeck"; ssh Steamdeck "sudo shutdown now"; echo "Firewalla"; ssh Firewalla "sudo shutdown now";  echo "Firewalla.RumRunnersIsle"; ssh BlackPearl "psexec -s -i 1 "psshutdown.exe" -f -t 0"; echo $myHostname; sudo shutdown now;;
    # Locking PC: psexec -s -i 1 \\HOSTNAME "C:\Windows\System32\psshutdown.exe" -l -t 0
    # Sleeping PC: psshutdown -d -t 0
    # Shutdown PC: psshutdown -f -t 0
    # Rebooting PC: psshutdown -r -t 0
    42 | lockPC) echo "Locking PC"; ssh BlackPearl "psexec -s -i 1 "psshutdown.exe" -l -t 0";;
    # Shutdown PC: psshutdown -f -t 0
    #Original script
    #The problem was, that without opening an RDP connection first, quser $env:USERNAME shows an already active session with the name "console", and executing tscon $sessionid /dest:console throws error 7045. This however can be easily fixed by running tsdiscon $sessionid before running tscon $sessionid /dest:console.
    #There is one catch though when doing this in the script: When ((quser $env:USERNAME | select -Skip 1) -split '\s+')[2] is executed before tsdiscon, it returns the session name ("console"). So simply running tsdiscon $sessionid; tscon $sessionid /dest:console would not work, as the disconnected session does not have a name anymore, so the ID has to be used instead.
    #This however can be easily fixed by executing ((quser $env:USERNAME | select -Skip 1) -split '\s+')[2] again after running tsdiscon, which then returns the session ID instead the name. The complete script therefor is:
    #@powershell -NoProfile -ExecutionPolicy unrestricted -Command "$sessionid=((quser $env:USERNAME | select -Skip 1) -split '\s+')[2]; tscon $sessionid /dest:console" 2> UnlockErrors.log
    43 | unlockPC) echo "Unlocking PC"; ssh BlackPearl 'powershell -NoProfile -ExecutionPolicy unrestricted -Command "$sessionid=((quser $env:USERNAME | select -Skip 1) -split '\''\s+'\'')[2]; tsdiscon $sessionid; $sessionid=((quser $env:USERNAME | select -Skip 1) -split '\''\s+'\'')[2]; tscon $sessionid /dest:console"';;
    44 | lock) echo "Locking everything"; echo "Harbormaster"; ssh Harbormaster "rpi-backlight -p off"; echo "Monkeebutt"; ssh Monkeebutt "sudo /home/pi/rpi-hdmi.sh toggle"; ssh BlackPearl "psexec -s -i 1 "psshutdown.exe" -l -t 0";;
    45 | sleep) echo "Brown Noise [Bedroom]"; /usr/bin/python3 /home/pi/Siren/BedroomStart_BrownNoise.py;;
    46 | work) echo "Brown Noise [Office]"; /usr/bin/python3 /home/pi/Siren/OfficeStart_BrownNoise.py;;
    47 | silence) echo "Silence"; /usr/bin/python3 /home/pi/Siren/silence.py;;
    $((${#options[@]}+1))) exit;;
    *) echo "Invalid option.";;
    esac
done



