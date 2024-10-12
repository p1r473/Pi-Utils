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

# Function to remove trailing slash from a path
remove_trailing_slash() {
    local path="$1"
    # Remove trailing slash unless the path is just a single slash
    echo "${path%/}"
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

# Function to handle remote path expansion with wildcards, including empty directories
expand_remote_paths() {
    local src="$1"
    local remote_host="${src%%:*}"
    local remote_dir="${src#*:}"
    local base_dir="${remote_dir%\/*}"  # Extract the directory portion before the last slash
    local pattern="${remote_dir##*/}"   # Potentially a wildcard pattern
    local expanded_sources=()
    # Command to handle file and directory expansion
    local cmd
    if [[ "$pattern" == "*" ]]; then
        cmd="find '$base_dir' -mindepth 1 -maxdepth 1; [ -d '$base_dir' ] && echo '$base_dir'"
    elif [[ "$pattern" == *"*"* ]]; then
        cmd="find '$base_dir' -mindepth 1 -maxdepth 1 -name '$pattern'; [ -d '$base_dir' ] && echo '$base_dir'"
    else
        cmd="if [ -d '$base_dir/$pattern' ] || [ -f '$base_dir/$pattern' ]; then echo '$base_dir/$pattern'; else echo 'NO_MATCH'; fi"
    fi
    local results=$(ssh -o ConnectTimeout=$SSH_timeout "$remote_host" "$cmd")
    if [[ -z "$results" ]]; then
        echo "NO_MATCH"
        return 1  # Indicate failure to expand
    else
        # Process results into the correct format, ensuring proper quoting and handling empty directories
        while IFS= read -r line; do
            if [[ -n "$line" && "$line" != "NO_MATCH" ]]; then
                line="'$remote_host:$line'"
                expanded_sources+=("$line")
            fi
        done <<< "$results"
        printf "%s\n" "${expanded_sources[@]}"
        return 0
    fi
}

# Function to handle local source expansion with wildcards
expand_local_sources() {
    local src="$1"
    local path="${src#*:}"  # Extract the path without the hostname
    local expanded_paths=()
    # Perform glob expansion
    eval "expanded_paths=($path)"
    for expanded in "${expanded_paths[@]}"; do
        if [[ -e $expanded ]]; then
            expanded_paths+=("$expanded")
        fi
    done
    if [[ ${#expanded_paths[@]} -eq 0 ]]; then
        echo "No valid files found at the specified path."
        return 1
    else
        printf "'%s' " "${expanded_paths[@]}"
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

# Function to extract base directory of a path (before the last '/')
get_base_directory() {
    local path="$1"
    echo "$(dirname "$path")"
}

different_base_dirs() {
    local -a base_dirs
    for src in "$@"; do
        base_dir=$(get_base_directory "$src")
        base_dirs+=("$base_dir")
    done

    # Remove duplicates and get unique base directories
    local -a unique_dirs=($(echo "${base_dirs[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    # If there are more than one unique base directory, return true (trigger full path usage)
    if [[ "${#unique_dirs[@]}" -gt 1 ]]; then
        return 0  # More than one unique base directory
    else
        return 1  # Only one base directory
    fi
}

# Determine the default destination based on the current hostname and path
get_default_destination() {
    local src_path="$1"
    local path_only

    # If the source path is local, get the full path using realpath
    if [[ "$src_path" != *:* ]]; then
        path_only=$(realpath "$src_path")
    else
        # If remote, just strip off the hostname
        path_only="${src_path#*:}"
    fi

    # Determine if the source is remote by checking for colon presence
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
        # Source is local, determine default remote destination based on current host
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
    # Add a trailing slash to the source path if needed to avoid creating an extra subdirectory
    if [[ "$source_basename" == "$destination_basename" ]]; then
        # Add a trailing slash to the source path
        rsync_sources="${rsync_sources%/}/"
    fi
    # Perform a dry run if the non-interactive flag is not set to 'yes'
    if [ "$non_interactive" != "yes" ]; then
        echo "Performing dry run command: $rsync_command -n"
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
use_relative="false"  # Default to not use relative paths

# Process flags
while getopts "fd" opt; do
  case $opt in
    f) dry_run_confirmation="yes" ;;  # Enable non-interactive mode
    d) delete_flag="--delete" ;;      # Enable rsync delete option
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
  esac
done

# Processing sources with handling both local and remote wildcards
shift $((OPTIND-1))
expanded_sources=()  # Prepare to collect expanded sources

# Remove trailing slashes from user inputs
for i in "$@"; do
    normalized_paths+=("$(remove_trailing_slash "$i")")
done
# Reassign normalized paths to positional parameters
set -- "${normalized_paths[@]}"

if [[ "$#" -eq 1 ]]; then
    sources=("$1")  # Single source scenario
    destination=$(get_default_destination "${sources[0]}")
    echo "Only one path provided. Defaulting destination to: $destination"
else
    input_sources=("${@:1:$#-1}")
    destination="${@: -1}"
    for src in "${input_sources[@]}"; do
        if [[ "$src" =~ "$PRIMARY_HOST:"* ]] && [[ "$(hostname)" == "$PRIMARY_HOST" ]]; then
            # Local sources with hostname and wildcards
            local_path="${src#*:}"
            expanded=($(expand_local_sources "$src"))
            if [[ $? -eq 0 ]]; then
                expanded_sources+=("${expanded[@]}")
            else
                echo "Failed to expand $src"
                continue
            fi
        elif is_remote "$src" && [[ "$src" == *"*"* ]]; then
            # Remote sources with wildcards
            expanded_sources_string=$(expand_remote_paths "$src")
            if [ $? -eq 0 ]; then
                IFS=$'\n' read -r -a expanded_sources <<< "$expanded_sources_string"
            else
                echo "Failed to expand $src"
                continue
            fi
        else
            # Direct inclusion of paths without expansion
            expanded_sources+=("$src")
        fi
    done
    sources=("${expanded_sources[@]}")
fi
# After stripping hostnames if they match the current host
source_paths=()
for src in "${sources[@]}"; do
    modified_src=$(remove_hostname_if_current "$src")
    source_paths+=("$modified_src")  # Collect modified source paths
done

# Normalize destination to include trailing slash if it's meant to be root.
if [[ "$destination" == "" || "$destination" == *":" ]]; then
    destination="${destination}/"
fi
# Remove the hostname if it matches the current host, making the destination path local.
destination=$(remove_hostname_if_current "$destination")

# Check if the destination is considered local root or remote root and adjust accordingly.
if [[ "$destination" == "/" || "$destination" == "$HOSTNAME:/" ]]; then
    destination="/"
elif [[ "$destination" == *":/" ]]; then
    remote_host="${destination%%:*}"
    destination="$remote_host:/"
fi



# Change the logic to use full source paths in the destination if different_base_dirs and destination is root
if different_base_dirs "${source_paths[@]}" && [[ "$destination" == "/" || "$destination" == *":/" ]]; then
    echo "Source files have different base directories, and destination is root (/). Using full source paths for destination."
    use_relative="true"  # Enable relative path usage
fi

# Form the rsync command with individually quoted source paths
rsync_sources=""
for path in "${source_paths[@]}"; do
    # Add trailing slash if the source is a directory to copy contents only
    if [[ -d "$path" ]]; then
        path="${path%/}/"
    fi
    rsync_sources+="'$path' "  # Append each path, properly quoted
done

# Include -R flag for relative paths if use_relative is true
rsync_command="rsync -ave ssh"
[[ "$use_relative" == "true" ]] && rsync_command+=" -R"
if is_remote "${sources[0]}" && [[ "$destination" == "/" ]]; then
    # Adjust destination for remote-to-local with root as destination
    rsync_command+=" $rsync_sources '/' ${delete_flag:+$delete_flag}"
else
    rsync_command+=" $rsync_sources '$destination' ${delete_flag:+$delete_flag}"
fi


# Ensure destination ends with a single slash if it is root directory
if [[ "$destination" == *":" ]]; then
    destination="${destination}/"
fi

if is_remote "$destination"; then
    ensure_destination_directory "$destination"
fi

# After determining sources and destination:
source_basename=$(basename "$(get_path_only "${sources[-1]}")")
destination_basename=$(basename "$(get_path_only "$destination")")

# If the source and destination basenames are the same, we should avoid creating an extra subdirectory
if [ "$source_basename" == "$destination_basename" ]; then
    # If the destination is root, leave the destination as is, but prevent subdirectory creation
    if [[ "$destination" == "/" || "$destination" == *":/" ]]; then
        destination_path="$destination"
    else
        # Otherwise, set the destination to its parent directory
        destination_path=$(dirname "$destination")
    fi
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
    if is_remote "${sources[0]}" && is_remote "$destination"; then
        echo "Remote to Remote transfer"
        # Construct the SSH command for remote-to-remote transfers
        source_server="${sources[0]%%:*}"
        remote_command="/home/pi/FileSpreader.sh ${sources[*]} $destination ${delete_flag:+$delete_flag}"
        rsync_command="ssh $source_server \"$remote_command\""
        echo "Executing on $source_server: $rsync_command"
        eval "$rsync_command"
    else
        # Local to Local or Local to Remote or Remote to Local transfer
        echo "Executing: $rsync_command"
        perform_rsync "$rsync_command" "$dry_run_confirmation"
    fi
fi

