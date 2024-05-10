#!/bin/bash
SSH_timeout=3
PRIMARY_HOST="Harbormaster"
SECONDARY_HOST="Monkeebutt"

# Usage: FileSpreader.sh <source>... <destination>
# <source> and <destination> format: [user@]host:path or /local/path

# Function to remove current hostname from path if present
remove_hostname_if_current() {
    local path="$1"
    local path_hostname="${path%%:*}"
    local path_portion="${path#*:}"

    # Normalize for comparison
    local normalized_path_hostname=$(echo "$path_hostname" | awk '{print tolower($0)}')
    local normalized_hostname=$(echo "$HOSTNAME" | awk '{print tolower($0)}')

    if [[ "$path" == *":"* && "$normalized_path_hostname" == "$normalized_hostname" ]]; then
        echo "$path_portion"
    else
        echo "$path"
    fi
}

# Determine if source is remote or local and check existence
check_source_existence() {
    local path="$1"
    if [[ "$path" == *:* ]]; then
        remote_file_exists "$path"
    else
        local_file_exists "$path"
    fi
}

# Function to check if a remote file or directory exists
remote_file_exists() {
    local remote_path="$1"
    local ssh_server="${remote_path%%:*}"
    local path="${remote_path#*:}"
    /usr/bin/ssh -o ConnectTimeout=$SSH_timeout "$ssh_server" "[[ -e \"$path\" ]]" && return 0 || return 1
}

# Function to check if a local file or directory exists
local_file_exists() {
    local path="$1"
    [[ -e "$path" ]] && return 0 || return 1
}

ensure_destination_directory() {
    if [[ "$destination" == *:* ]]; then
        local remote_host="${destination%%:*}"
        local remote_path="${destination##*:}"
        local remote_dir=$(dirname "$remote_path")
        /usr/bin/ssh -o ConnectTimeout=$SSH_timeout "$remote_host" "mkdir -p \"$remote_dir\""
        if [ $? -ne 0 ]; then
            echo "Failed to ensure remote directory exists. Exiting."
            exit 1
        fi
    fi
}

# Function to check if a path is remote
is_remote() {
    local path="$1"
    local path_hostname="${path%%:*}"  # Extract the hostname from the path

    # Normalize to lowercase for comparison
    local normalized_path_hostname=$(echo "$path_hostname" | awk '{print tolower($0)}')
    local normalized_hostname=$(echo "$HOSTNAME" | awk '{print tolower($0)}')

    # Check if the path contains a colon and the hostname part is not the current hostname
    if [[ "$path" == *":"* ]] && [[ "$normalized_path_hostname" == "$normalized_hostname" ]]; then
        return 1  # It's local
    elif [[ "$path" == *":"* ]]; then
        return 0  # It's remote
    else
        return 1  # It's local (no colon in the path)
    fi
}

# Extract path without the server part
get_path_only() {
    if is_remote "$1"; then
        echo "${1##*:}"
    else
        echo "$1"
    fi
}

# Determine the default destination based on the current hostname and path
get_default_destination() {
    local src_path="$1"
    local path_only="${src_path#*:}"  # Strip off the hostname from the path

    # Determine if the source is remote by checking for colon presence before stripping
    if [[ "$src_path" == *:* ]]; then
        local src_hostname="${src_path%%:*}"
        # Check if the source hostname matches either known host and switch destination host accordingly
        if [ "$src_hostname" == "$SECONDARY_HOST" ]; then
            echo "$PRIMARY_HOST:$path_only"  # Source is secondary, default destination to primary
        elif [ "$src_hostname" == "$PRIMARY_HOST" ]; then
            echo "$SECONDARY_HOST:$path_only"  # Source is primary, default destination to secondary
        else
            echo "Error: Remote host not recognized."
            exit 1
        fi
    else
        # Source is local, determine default remote destination
        if [[ "$HOSTNAME" == "$PRIMARY_HOST" ]]; then
            echo "$SECONDARY_HOST:$path_only"
        elif [[ "$HOSTNAME" == "$SECONDARY_HOST" ]]; then
            echo "$PRIMARY_HOST:$path_only"
        else
            echo "Error: Host not recognized."
            exit 1
        fi
    fi
}


perform_rsync() {
    local rsync_command=$1
    local non_interactive=$2
    # Perform a dry run if the non-interactive flag is not set to 'yes'
    if [ "$non_interactive" != "yes" ]; then
        echo "Performing ry run command: $rsync_command -n"
        eval "$rsync_command -n"
        if [ $? -eq 0 ]; then
            echo "Dry run complete. The above files would be copied."
            echo "Do you want to proceed with the actual copy? (y/n):"
            read -p "" confirm
            case "$confirm" in
                [Yy]* ) eval "$rsync_command";;
                [Nn]* ) echo "Copy operation aborted."; return 1;;
                * ) echo "Invalid input. Copy operation aborted."; return 1;;
            esac
        else
            echo "Dry run failed. Please check the rsync command."
            return 1
        fi
    else
        echo "Non-interactive mode: Automatically proceeding with the copy."
        eval "$rsync_command"
    fi
}

# Check if the first argument is --help or if no arguments are provided
if [[ "$1" == "--help" ]] || [[ $# -eq 0 ]]; then
    echo "Usage: $0 <source>... <destination>"
    echo "Examples:"
    echo "  $0 /path/to/source /path/to/destination  # Local to Local"
    echo "  $0 /path/to/source user@remote:/path/to/destination  # Local to Remote"
    echo "  $0 user@remote:/path/to/source /local/path  # Remote to Local"
    echo "  $0 user@remote:/path/to/source user@remote2:/path/to/destination  # Remote to Remote"
    exit 0
fi

# Initialize flags
delete_flag=""
dry_run_confirmation="no"  # Default to 'no' for non-interactive

# Process flags
while getopts "fd" opt; do
  case $opt in
    f) dry_run_confirmation="yes" ;;  # Enable non-interactive mode
    d) delete_flag="--delete" ;;      # Enable rsync delete option
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
  esac
done

# Shift off the options and their arguments
shift $((OPTIND-1))

if [[ "$#" -eq 1 ]]; then
    sources=("$1")  # Handle a single source as an array for uniform processing
    destination=$(get_default_destination "${sources[0]}")
    echo "Only one path provided. Defaulting destination to: $destination"
else
    sources=("${@:1:$#-1}")
    destination="${@: -1}"
fi

# After stripping hostnames if they match the current host
source_paths=()
for src in "${sources[@]}"; do
    modified_src=$(remove_hostname_if_current "$src")
    source_paths+=("$modified_src")  # Collect modified source paths
done

destination=$(remove_hostname_if_current "$destination")
if is_remote "$destination"; then
    ensure_destination_directory "$destination"
fi

# Form the rsync command with individually quoted source paths
rsync_sources=""
for path in "${source_paths[@]}"; do
    rsync_sources+="'$path' "  # Append each path, properly quoted
done

# Check if the basename of the source and destination are the same
src_base_name=$(basename "$(get_path_only "${sources[-1]}")")
dest_base_name=$(basename "$(get_path_only "$destination")")

# Determine the type of operation
if [[ "$src_base_name" == "$dest_base_name" ]]; then
    # Adjust destination to sync directly to the path instead of subdirectory
    destination_path=$(dirname "$destination")
else
    destination_path="$destination"
fi

echo "Sources: ${sources[*]}"
echo "Destination: $destination"

if is_remote "${sources[0]}" && is_remote "$destination"; then
    echo "Remote to Remote transfer"
    # Extract necessary components from the paths
    source_server="${sources[0]%%:*}"
    dest_server="${destination%%:*}"
    dest_path="${destination##*:}"

    # Construct the remote command to execute on the source server
    remote_command="/home/pi/FileSpreader.sh"
    [[ $delete_flag ]] && remote_command+=" $delete_flag"  # Include delete flag if set
    [[ $dry_run_confirmation == "yes" ]] && remote_command+=" -f"  # Include non-interactive flag if set

    # Properly quote the paths for the remote command
    remote_command+=" '${sources[*]}' '$dest_server:$dest_path'"

    # SSH command to execute the rsync command on the source server
    rsync_command="ssh $source_server \"$remote_command\""
    echo "Executing on $source_server: $rsync_command"

    # Execute the remote rsync command
    eval "$rsync_command"
else
    if is_remote "${sources[0]}"; then
        echo "Remote to Local transfer"
        rsync_command="rsync -ave ssh $rsync_sources '$destination' $delete_flag"
    elif is_remote "$destination"; then
        echo "Local to Remote transfer"
        rsync_command="rsync -ave ssh $rsync_sources '$destination' $delete_flag"
    else
        echo "Local to Local transfer"
        rsync_command="rsync -av $rsync_sources '$destination' $delete_flag"
    fi
    perform_rsync "$rsync_command" "$dry_run_confirmation"
fi
