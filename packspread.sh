#!/bin/bash

# Enable error trapping
set -o errexit # Enable strict error checking
set -o nounset # Exit if an unset variable is used
set -o noglob  # Disable filename expansion
set -eE
set -o pipefail # trace ERR through pipes
set -o errtrace # trace ERR through 'time command' and other functions

# Variables
BACKUP_LOG_DIR="/home/ageorge/.local_update_logs"
RUN_LOG="/tmp/packspread_log.txt"
LOG_FILE="$BACKUP_LOG_DIR/Packspread.log"
username="ageorge"
remote_ips=("192.168.1.145" "192.168.1.248" "192.168.1.238")

# Function to log messages with color
log_message() {
    local color=$1
    local message=$2
    case $color in
    red) color_code="\e[31m" ;;
    green) color_code="\e[32m" ;;
    yellow) color_code="\e[33m" ;;
    blue) color_code="\e[34m" ;;
    magenta) color_code="\e[35m" ;;
    cyan) color_code="\e[36m" ;;
    white) color_code="\e[37m" ;;
    gray) color_code="\e[90m" ;;
    light_red) color_code="\e[91m" ;;
    light_green) color_code="\e[92m" ;;
    light_yellow) color_code="\e[93m" ;;
    light_blue) color_code="\e[94m" ;;
    light_magenta) color_code="\e[95m" ;;
    light_cyan) color_code="\e[96m" ;;
    *) color_code="" ;;
    esac
    echo -e "${color_code}${message}\e[0m" | tee -a "$LOG_FILE"
}

# Function to restart the script
restart_script_function() {
    log_message yellow "Restarting script..."
    exec "$0" "$@"
}

# Function for custom action (SIGUSR1)
custom_action() {
    log_message blue "Performing custom action for SIGUSR1"
    load_exclusions "/home/ageorge/Desktop/Update-Script/exclusions_config"
    log_message green "Configuration reloaded successfully."
    echo "Configuration reloaded at $(date)" >>"$RUN_LOG"
}

# Cleanup function
cleanup_function() {
    log_message yellow "Performing cleanup..."
    echo "Cleanup completed at $(date)" >>"$RUN_LOG"
}

# Error handling function with detailed output and retry
handle_error() {
    local func_name="$1"
    local err="${2:-check}"
    local retry_command="${3:-}"
    local retry_count=0
    local max_retries=3
    local backtrace_file="/tmp/error_backtrace.txt"

    local file_name="${BASH_SOURCE[1]}"
    local line_number="${BASH_LINENO[0]}"
    local error_code="$err"
    local error_message="${BASH_COMMAND}"

    echo -e "\n(!) EXIT HANDLER:\n" >&2
    echo "FUNCTION:  ${func_name}" >&2
    echo "FILE:       ${file_name}" >&2
    echo "LINE:       ${line_number}" >&2
    echo -e "\nERROR CODE: ${error_code}" >&2
    echo -e "ERROR MESSAGE:\n${error_message}" >&2

    # Check specific error codes and provide custom handling
    case "$error_code" in
    1)
        log_message yellow "General error occurred. Consider checking permissions or syntax."
        ;;
    2)
        log_message yellow "Misuse of shell builtins. Verify the command syntax."
        ;;
    126)
        log_message yellow "Command invoked cannot execute. Check file permissions."
        ;;
    127)
        log_message yellow "Command not found. Ensure the command exists in your PATH."
        ;;
    130)
        log_message yellow "Script terminated by Ctrl+C (SIGINT)."
        ;;
    *)
        log_message yellow "An unexpected error occurred (Code: ${error_code})."
        ;;
    esac

    # Generate the backtrace
    echo -e "\nBACKTRACE IS:" >"$backtrace_file"
    local i=0
    while caller $i >>"$backtrace_file"; do
        ((i++))
    done
    cat "$backtrace_file" >&2

    # Retry logic if a command is specified
    set +e
    if [[ -n "$retry_command" ]]; then
        while [[ $retry_count -lt $max_retries ]]; do
            log_message yellow "Retrying after error... Attempt $((retry_count + 1))/$max_retries"
            if eval "$retry_command"; then
                log_message green "Retried successfully on attempt $((retry_count + 1))"
                set -e
                return 0
            fi
            ((retry_count++))
            sleep $(((RANDOM % 5) + (2 ** retry_count)))
        done
    fi
    set -e

    # If retries fail, perform cleanup and exit
    log_message red "All retries failed. Exiting script."
    cleanup_function

    exit 1
}

# Trap errors and signals
trap 'handle_error "$BASH_COMMAND" "$?"' ERR
trap 'echo "Script terminated prematurely" >> "$RUN_LOG"; exit 1' SIGINT SIGTERM
trap 'handle_error "SIGPIPE received" "$?"' SIGPIPE
trap 'log_message yellow "Restarting script due to SIGHUP"; restart_script_function' SIGHUP
trap 'log_message blue "Custom action for SIGUSR1"; custom_action' SIGUSR1
trap 'cleanup_function' EXIT

# Function to validate and initialize variables
validate_variable() {
    local var_name="$1"
    local var_value="$2"
    local permissions="${3:-644}" # Default permissions if not specified

    if [[ -z "$var_value" ]]; then
        echo "Error: Variable $var_name is not set."
        exit 1
    fi

    if [[ ! -e "$var_value" ]]; then
        echo "File for $var_name does not exist. Creating $var_value."
        touch "$var_value" || {
            echo "Error: Unable to create file $var_value."
            exit 1
        }
    fi

    chmod "$permissions" "$var_value" || {
        echo "Error: Unable to set permissions on $var_value."
        exit 1
    }
    echo "Variable $var_name is valid. File exists at $var_value with permissions $permissions."
}

# Function to validate required commands
validate_commands() {
    {
        local required_commands=("ssh" "scp" "md5sum" "sudo" "apt-get")
        for cmd in "${required_commands[@]}"; do
            if ! command -v "$cmd" &>/dev/null; then
                log_message red "Error: Required command not found: $cmd"
                exit 1
            fi
        done
    } || handle_error "validate_commands" "$?"
}

# Enhanced version of check_restart_required
check_restart_required() {
    if [ -f /var/run/reboot-required ]; then
        log_message light_red "\n⚠ System Restart Required\n"
        if [ -f /var/run/reboot-required.pkgs ]; then
            log_message yellow "Packages requiring restart:"
            log_message yellow "$(cat /var/run/reboot-required.pkgs)\n"
        fi
    else
        log_message light_green "\n✓ No System Restart Required\n"
    fi

    if ! uptime_output=$(uptime); then
        handle_error "check_restart_required" "Failed to check restart status"
    else
        log_message cyan "System Uptime:"
        log_message white "${uptime_output}\n"
    fi
}

# Enhanced version of check_restart_required_no_log
check_restart_required_no_log() {
    if [ -f /var/run/reboot-required ]; then
        echo -e "\n\e[91m⚠ System Restart Required\e[0m\n"
        if [ -f /var/run/reboot-required.pkgs ]; then
            echo -e "\e[93mPackages requiring restart:\e[0m"
            echo -e "\e[93m$(cat /var/run/reboot-required.pkgs)\e[0m\n"
        fi
    else
        echo -e "\n\e[92m✓ No System Restart Required\e[0m\n"
    fi

    if ! uptime_output=$(uptime); then
        echo -e "\e[91mFailed to check restart status\e[0m"
    else
        echo -e "\e[36mSystem Uptime:\e[0m"
        echo -e "\e[97m${uptime_output}\e[0m\n"
    fi
}

# Validate and initialize RUN_LOG
validate_variable "RUN_LOG" "$RUN_LOG" "644"
validate_variable "LOG_FILE" "$LOG_FILE" "644"
validate_commands

# Init Vars
true >"$RUN_LOG"
true >"$LOG_FILE"

verify_ssh_rsa() {
    local ip="$1"
    if ! ssh -o ConnectTimeout=10 "$username@$ip" "exit" &>/dev/null; then
        echo "SSH verification failed for $ip. Please ensure:"
        echo "- The machine is reachable."
        echo "- SSH is enabled and the SSH service is running."
        echo "- The user '$username' has access."
        return 1
    fi
    echo "SSH verification passed for $ip."
    return 0
}

install_local() {
    log_message light_cyan "\n=== Installing Packages Locally ===\n"

    if sudo DEBIAN_FRONTEND=noninteractive apt-get update &&
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"; then
        log_message light_green "\n✓ Local installation completed successfully\n"
    else
        log_message light_red "\n⨯ Local installation encountered issues\n"
        return 1
    fi

    log_message light_cyan "\n=== Checking Local System Status ===\n"
    check_restart_required
}

remove_local() {
    log_message light_cyan "\n=== Removing Packages Locally ===\n"

    if sudo DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y "$@"; then
        log_message light_green "\n✓ Local removal completed successfully\n"
    else
        log_message light_red "\n⨯ Local removal encountered issues\n"
        return 1
    fi

    log_message light_cyan "\n=== Checking Local System Status ===\n"
    check_restart_required
}

manage_remote() {
    local action="$1"
    shift

    for ip in "${remote_ips[@]}"; do
        log_message light_cyan "\n=== Managing Packages on Remote Machine: $ip ===\n"

        if ! verify_ssh_rsa "$ip"; then
            log_message light_red "\n⨯ SSH verification failed for $ip\n"
            handle_error "verify_ssh_rsa" "$?" "verify_ssh_rsa \"$ip\""
            continue
        fi
        log_message light_green "✓ SSH verification successful\n"

        log_message white "${action^}ing packages..."
        if ssh -o ConnectTimeout=10 "$username@$ip" "sudo DEBIAN_FRONTEND=noninteractive apt-get update && \
            sudo DEBIAN_FRONTEND=noninteractive apt-get $action -y $*"; then
            log_message light_green "\n✓ Remote $action completed successfully on $ip\n"
        else
            log_message light_red "\n⨯ Remote $action encountered issues on $ip\n"
            handle_error "manage_remote" "$?" "manage_remote \"$action\" \"$*\""
        fi

        log_message light_cyan "\n=== Checking Remote System Status for $ip ===\n"
        ssh -o ConnectTimeout=10 "$username@$ip" "$(declare -f check_restart_required_no_log); check_restart_required_no_log"
        echo -e "\n"
    done
}

# Main execution
main() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 {install|remove} package1 [package2 ...]"
        exit 1
    fi

    local action="$1"
    shift

    case "$action" in
    install)
        install_local "$@" || handle_error "install_local" "$?" "install_local \"$*\""
        manage_remote "install" "$@" || handle_error "manage_remote" "$?" "manage_remote install \"$*\""
        ;;
    remove)
        remove_local "$@" || handle_error "remove_local" "$?" "remove_local \"$*\""
        manage_remote "remove --purge" "$@" || handle_error "manage_remote" "$?" "manage_remote remove --purge \"$*\""
        ;;
    *)
        echo "Invalid action. Use 'install' or 'remove'."
        exit 1
        ;;
    esac

    echo "Package management action '$action' completed on all machines."
}

# Run the main function
main "$@"
