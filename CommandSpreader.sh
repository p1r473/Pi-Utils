#!/bin/bash
SSH_timeout=3

# Function to interpret color codes for any command output
colorize_output() {
  awk '{ gsub(/\\e/, "\x1b"); print }'
  #sed -u 's/\\e/\x1b/g'
  
}

# Function to determine if an IP address is within a private range
IsPrivateIP() {
    ip=$1
    if [[ $ip =~ ^10\. || $ip =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. || $ip =~ ^192\.168\. ]]; then
        return 0 # True, IP is private
    else
        return 1 # False, IP is not private
    fi
}

# Function to determine if SSH should jump through BlackPearl based on subnet differences and private IP
IsDifferentSubnet() {
    local_ip=$(hostname -I | awk '{print tolower($1)}')
    target_hostname=$(echo "$1" | awk '{print tolower($0)}')
    target_ip=$(getent ahosts "$target_hostname" | head -n 1 | awk '{print $1}')

    # Extract subnet parts
    local_subnet=${local_ip%.*}
    target_subnet=${target_ip%.*}

    if [[ "$local_subnet" != "$target_subnet" ]] && IsPrivateIP "$target_ip"; then
        return 0 # True, different subnet and target IP is private
    else
        return 1 # False, same subnet or target IP is not private
    fi
}

function display_help() {
    echo "Usage: $0 'command' ['host1' 'optional_host2' ... 'optional_hostN']"
    echo
    echo "Arguments:"
    echo "  command        The command to execute on the specified hosts."
    echo "  host1          The primary host on which to execute the command."
    echo "  optional_host  Additional hosts (optional) on which to execute the command."
    echo
    echo "Example:"
    echo "  $0 'ls -l' 'Harbormaster' 'Monkeebutt'"
    echo "If no hosts are specified, a default will be chosen based on the current hostname."
}

# Check if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    display_help
    exit 0
fi

# Usage message if not enough arguments are provided
if [ $# -lt 1 ]; then
    display_help
    exit 1
fi

# Extract the command to be executed
COMMAND="$1"
shift # shift the arguments left, removing the first one (the command)

# Determine default host if no hosts are provided
if [ $# -eq 0 ]; then
    case $HOSTNAME in
        Harbormaster)
            set -- "Monkeebutt"  # Set default host to Monkeebutt if on Harbormaster
            ;;
        Monkeebutt)
            set -- "Harbormaster"  # Set default host to Harbormaster if on Monkeebutt
            ;;
        *)
            echo "Error: No default SSH destination configured for hostname $HOSTNAME." >&2
            exit 1
            ;;
    esac
fi

# Collect all hosts for the confirmation message
all_hosts=("$@")

# Confirmation function to proceed with command execution on all hosts
function confirm_execution() {
    echo "Are you sure you want to execute '$COMMAND' on the following hosts: ${all_hosts[*]}? (y/n)"
    read response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Confirm before executing on any host
if confirm_execution; then
    for HOST in "${all_hosts[@]}"; do
        echo "Executing '$COMMAND' on host $HOST"
        if IsDifferentSubnet "$HOST"; then
        echo "Using jump box: ssh -J BlackPearl $HOST $COMMAND" >&2
            ssh -t -o ConnectTimeout=$SSH_timeout -J "BlackPearl" "$HOST" "$COMMAND" | colorize_output
        else
            ssh -t -o ConnectTimeout=$SSH_timeout "$HOST" "$COMMAND" | colorize_output
        fi
    done
else
    echo "Execution cancelled."
fi
