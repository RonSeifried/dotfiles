#!/usr/bin/env bash
# Rofi script-mode for installer menu
# Can be called from rofi modi or standalone

# Directory containing installer scripts
INSTALLER_DIR="$HOME/.config/scripts/installer"

# Define menu options with icons and display names
declare -a menu_order=(
    " System Update"
    " Install Official Packages"
    " Install AUR Packages"
    " Remove Packages"
    " Create Web App"
    " Remove Web App"
)

declare -A options
options[" System Update"]="system-update.sh"
options[" Install AUR Packages"]="pkg-aur-install.sh"
options[" Install Official Packages"]="pkg-pacman-install.sh"
options[" Remove Packages"]="pkg-remove.sh"
options[" Create Web App"]="webapp-install.sh"
options[" Remove Web App"]="webapp-remove.sh"

# Function to show menu items
show_menu() {
    for display_name in "${menu_order[@]}"; do
        echo "$display_name"
    done
}

# Function to execute selected script
execute_selection() {
    local selected="$1"
    local script_name="${options[$selected]}"

    if [[ -n "$script_name" && -f "$INSTALLER_DIR/$script_name" ]]; then
        # Execute the script in kitty terminal
        coproc ( kitty --class installer -e bash -c "cd '$INSTALLER_DIR' && ./'$script_name'; echo; echo 'Press Enter to close...'; read" & )
        exit 0
    elif [[ -n "$script_name" ]]; then
        notify-send "Error" "Script not found: $INSTALLER_DIR/$script_name" -u critical
        exit 1
    fi
}

# Main logic: check if we're in rofi script-mode or standalone
if [[ -n "$ROFI_RETV" ]]; then
    # We're in rofi script-mode
    case "$ROFI_RETV" in
        0)
            # Initial call - show menu
            show_menu
            ;;
        1)
            # User selected an entry
            execute_selection "$1"
            ;;
        2)
            # Custom input (user typed something not in list)
            # Just show menu again
            show_menu
            ;;
    esac
else
    # Standalone mode - check if argument passed
    if [[ -n "$1" ]]; then
        # Selection passed as argument (called from rofi without ROFI_RETV)
        execute_selection "$1"
    else
        # No argument - just output menu (for rofi to consume)
        show_menu
    fi
fi
