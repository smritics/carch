#!/bin/bash

VERSION="4.2.3"
CONFIG_DIR="$HOME/.config/carch"
CACHE_DIR="$HOME/.cache/carch-install"
LOG_FILE="$CACHE_DIR/install.log"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
BOLD="\033[1m"
RESET="\033[0m"

mkdir -p "$CONFIG_DIR" "$CACHE_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

if [ -f /etc/os-release ]; then
    DISTRO=$(grep ^NAME= /etc/os-release | cut -d= -f2 | tr -d '"')
elif command -v lsb_release &>/dev/null; then
    DISTRO=$(lsb_release -d | cut -f2)
else
    DISTRO="Unknown Linux Distribution"
fi
ARCH=$(uname -m)

if ! pacman -Qi "fzf" &>/dev/null; then
    echo "FZF is required for this script. Installing fzf..."
    sudo pacman -Sy --noconfirm fzf || { 
        echo "Failed to install fzf. Exiting."
        exit 1
    }
fi

fzf_confirm() {
    local prompt="$1"
    local options=("Yes" "No")
    local selected=$(printf "%s\n" "${options[@]}" | fzf --prompt="$prompt " --height=10 --layout=reverse --border)
    
    if [[ "$selected" == "Yes" ]]; then
        return 0
    else
        return 1
    fi
}

check_and_install() {
    local pkg="$1"
    if ! pacman -Qi "$pkg" &>/dev/null; then
        echo -e "${YELLOW}Installing missing dependency: $pkg${RESET}"
        echo "Installing $pkg..."
        sudo pacman -Sy --noconfirm "$pkg"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ $pkg installed successfully${RESET}"
        else
            echo -e "${RED}✗ Failed to install $pkg${RESET}"
            return 1
        fi
    else
        echo -e "${GREEN}✓ $pkg is already installed${RESET}"
    fi
    return 0
}

clear

echo -e "${CYAN}┌──────────────────────────────────────────────────┐${RESET}"
echo -e "${CYAN}│                     ${BOLD}CARCH${RESET}${CYAN}                        │${RESET}"
echo -e "${CYAN}│               ${WHITE}Version $VERSION${RESET}${CYAN}                      │${RESET}"
echo -e "${CYAN}│          ${WHITE}Distribution: $DISTRO${RESET}${CYAN}             │${RESET}"
echo -e "${CYAN}│            ${WHITE}Architecture: $ARCH${RESET}${CYAN}                  │${RESET}"
echo -e "${CYAN}└──────────────────────────────────────────────────┘${RESET}"

echo -e "${YELLOW}┌──────────────────────────────────────────────────┐${RESET}"
echo -e "${YELLOW}│              Installing dependencies...          │${RESET}"
echo -e "${YELLOW}└──────────────────────────────────────────────────┘${RESET}"

dependencies=("figlet" "ttf-jetbrains-mono-nerd" "ttf-jetbrains-mono" "git")
failed_deps=0

for dep in "${dependencies[@]}"; do
    check_and_install "$dep" || ((failed_deps++))
done

if [ $failed_deps -gt 0 ]; then
    echo -e "${RED}Some dependencies failed to install. Check the logs.${RESET}"
    fzf_confirm "Continue anyway?" || exit 1
fi

echo -e "${GREEN}NOTE: Stable Release is recommended.${RESET}"
echo -e "${RED}Git package is not fully recommended as it grabs the latest commit which may have bugs.${RESET}"
echo -e "${YELLOW}${BOLD}Select installation type:${RESET}"

options=("Stable Release [Recommended]" "Carch-git [GitHub Latest Commit]" "Cancel")
CHOICE=$(printf "%s\n" "${options[@]}" | fzf --prompt="Select package version to install: " --height=15 --layout=reverse --border)

if [[ $CHOICE == "Cancel" ]]; then
    echo -e "${RED}Installation canceled by the user.${RESET}"
    exit 0
fi

fzf_confirm "Install $CHOICE?" || {
    echo -e "${RED}Installation canceled by the user.${RESET}"
    exit 0
}

echo -e "${YELLOW}Preparing installation environment...${RESET}"
cd "$CACHE_DIR" || exit 1
if [ -d "pkgs" ]; then
    echo -e "${YELLOW}Updating existing repository...${RESET}"
    echo "Updating repository..."
    git -C pkgs pull
else
    echo -e "${YELLOW}Cloning repository...${RESET}"
    echo "Cloning repository..."
    git clone https://github.com/carch-org/pkgs
fi

cd pkgs || {
    echo -e "${RED}Failed to access repository.${RESET}"
    exit 1
}

case "$CHOICE" in
    "Carch-git [GitHub Latest Commit]")
        echo -e "${YELLOW}Installing Git Version (Latest Commit)...${RESET}"
        cd carch-git || exit 1
        ;;
    "Stable Release [Recommended]")
        echo -e "${YELLOW}Installing Stable Release...${RESET}"
        cd carch || exit 1
        ;;
esac

echo -e "${CYAN}Building and installing package...${RESET}"
makepkg -si

if [ $? -eq 0 ]; then
    echo -e "${GREEN}┌──────────────────────────────────────────────────┐${RESET}"
    echo -e "${GREEN}│              ${BOLD}INSTALLATION COMPLETE${RESET}${GREEN}               │${RESET}"
    echo -e "${GREEN}│      ${WHITE}Carch has been successfully installed!${RESET}${GREEN}      │${RESET}"
    echo -e "${GREEN}│      ${WHITE}Run 'carch -h' to see available options${RESET}${GREEN}     │${RESET}"
    echo -e "${GREEN}└──────────────────────────────────────────────────┘${RESET}"
else
    echo -e "${RED}Failed to build or install package.${RESET}"
    exit 1
fi

fzf_confirm "Clean up installation files?" && {
    echo "Cleaning up..."
    rm -rf "$CACHE_DIR/pkgs"
    echo -e "${GREEN}Cleanup complete.${RESET}"
}

exit 0
