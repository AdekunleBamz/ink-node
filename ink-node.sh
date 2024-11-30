#!/bin/bash
# ----------------------------

# Colors and Icons Definitions
# ----------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No color

CHECKMARK="✅"
ERROR="❌"
PROGRESS="⏳"
INSTALL="📦"
SUCCESS="🎉"
WARNING="⚠️"
NODE="🖥️"
INFO="ℹ️"

# Icons for the header
ICON_TELEGRAM="🚀"
ICON_INSTALL="🛠️"
ICON_DELETE="🗑️"
ICON_UPDATE="🔄"
ICON_LOGS="📄"
ICON_CONFIG="⚙️"
ICON_EXIT="🚪"

# ----------------------------
# Configuration Variables
# ----------------------------
LOG_FILE="$HOME/ink_node/ink_installation.log"

# Ensure the log directory exists
mkdir -p "$HOME/ink_node"

# ----------------------------
# Logging Function
# ----------------------------
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# ----------------------------
# Dependency Check Function
# ----------------------------
check_dependency() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo -e "${WARNING} ${YELLOW}$1 is not installed. Installing...${NC}"
        sudo apt install -y "$1" || { echo -e "${ERROR} ${RED}Failed to install $1.${NC}"; log "Failed to install $1."; }
    fi
}

# ----------------------------
# User Privilege Check
# ----------------------------
if [[ $EUID -ne 0 ]]; then
    echo -e "${ERROR} ${RED}This script must be run as root. Please run with sudo.${NC}"
    exit 1
fi

# ----------------------------
# ASCII Art Header
# ----------------------------
display_ascii() {
    echo -e "    ${RED}___          __  __ ____________${RESET}"
    echo -e "    ${GREEN}|  _ \   /\   |  \/  |___  |___  /${RESET}"
    echo -e "    ${BLUE}| |_) | /  \  | \  / |  / /   / / ${RESET}"
    echo -e "    ${CYAN}|  _ < / /\ \ | |\/| | / /   / /  ${RESET}"
    echo -e "    ${MAGENTA}| |_) / ____ \| |  | |/ /__ / /__ ${RESET}"
    echo -e "    ${YELLOW}|____/_/    \_|_|  |_/_____/_____|${RESET}"
    echo -e "    ${MAGENTA}${ICON_TELEGRAM} Follow us on Telegram: https://t.me/bamzz_bamzz${RESET}"
    echo -e "    ${YELLOW}📢 Follow us on Twitter: https://x.com/HRH_Mckay${RESET}"
}

# ----------------------------
# Menu Borders
# ----------------------------
draw_top_border() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
}

draw_middle_border() {
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
}

draw_bottom_border() {
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
}

# ----------------------------
# Header and Separator Functions
# ----------------------------
show_header() {
    display_ascii
    echo ""
}

show_separator() {
    draw_middle_border
}

# ----------------------------
# Port Checking Function
# ----------------------------
TCP_PORTS=(8545 8546 30303 9222 7300 6060)
UDP_PORTS=(30303)
ALT_TCP_PORTS=(8550 8552 30304 9223 7301 6061)
ALT_UDP_PORTS=(30304)

check_ports() {
    echo -e "${CYAN}Checking port availability...${NC}"
    for i in "${!TCP_PORTS[@]}"; do
        port=${TCP_PORTS[$i]}
        alt_port=${ALT_TCP_PORTS[$i]}

        if sudo lsof -iTCP:$port -sTCP:LISTEN &>/dev/null; then
            echo -e "${YELLOW}⚠️  TCP Port $port is in use. Switching to alternative port $alt_port.${NC}"
            TCP_PORTS[$i]=$alt_port
        else
            echo -e "${GREEN}✅ TCP Port $port is available.${NC}"
        fi
    done

    for i in "${!UDP_PORTS[@]}"; do
        port=${UDP_PORTS[$i]}
        alt_port=${ALT_UDP_PORTS[$i]}

        if sudo lsof -iUDP:$port &>/dev/null; then
            echo -e "${YELLOW}⚠️  UDP Port $port is in use. Switching to alternative port $alt_port.${NC}"
            UDP_PORTS[$i]=$alt_port
        else
            echo -e "${GREEN}✅ UDP Port $port is available.${NC}"
        fi
    done
}

# ----------------------------
# Install Dependencies and Configure
# ----------------------------
install_dependencies_and_configure() {
    echo -e "${CYAN}Installing prerequisites and configuring INK Node...${NC}"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y screen git jq ca-certificates curl gnupg lsb-release || { echo -e "${ERROR} ${RED}Failed to install required packages.${NC}"; log "Failed to install required packages."; exit 1; }
    screen -S InkNode -d -m
    echo -e "${GREEN}Prerequisites installed.${NC}"

    if ! command -v docker &> /dev/null; then
        echo -e "${CYAN}Installing Docker from official Docker repositories...${NC}"
        
        # Install Docker from official Docker repository
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io || { echo -e "${ERROR} ${RED}Failed to install Docker.${NC}"; log "Failed to install Docker."; exit 1; }

        sudo systemctl start docker
        sudo systemctl enable docker

        # Verify Docker installation
        docker --version || { echo -e "${ERROR} ${RED}Docker installation verification failed.${NC}"; log "Docker installation verification failed."; exit 1; }

        echo -e "${GREEN}Docker installed successfully.${NC}"
    else
        echo -e "${YELLOW}Docker is already installed. Skipping installation.${NC}"
    fi

    # Install Docker Compose (latest version)
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${CYAN}Installing Docker Compose...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose

        # Verify Docker Compose installation
        docker-compose --version || { echo -e "${ERROR} ${RED}Docker Compose installation failed.${NC}"; log "Docker Compose installation failed."; exit 1; }

        echo -e "${GREEN}Docker Compose installed successfully.${NC}"
    else
        echo -e "${YELLOW}Docker Compose is already installed. Updating to the latest version...${NC}"
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose

        # Verify Docker Compose update
        docker-compose --version || { echo -e "${ERROR} ${RED}Docker Compose update failed.${NC}"; log "Docker Compose update failed."; exit 1; }

        echo -e "${GREEN}Docker Compose updated successfully.${NC}"
    fi

    # Install and Configure INK Node
    setup_ink_node
}

# ----------------------------
# Setup INK Node Function
# ----------------------------
setup_ink_node() {
    echo -e "${CYAN}Installing INK Node...${NC}"
    mkdir -p "$HOME/InkNode" && cd "$HOME/InkNode"
    if git clone https://github.com/inkonchain/node; then
        cd node

        # Write .env.ink-sepolia file with updated L1 RPC URLs
        cat <<EOL > .env.ink-sepolia
L1_RPC_URL="https://ethereum-sepolia-rpc.publicnode.com"
L1_BEACON_URL="https://ethereum-sepolia-beacon-api.publicnode.com"
EOL

        # Update entrypoint.sh with available ports
        sed -i "s/8551/${TCP_PORTS[0]}/g" "$HOME/InkNode/node/op-node/entrypoint.sh"
        sed -i "s/30303/${TCP_PORTS[2]}/g" "$HOME/InkNode/node/op-node/entrypoint.sh"
        sed -i "s/30303/${UDP_PORTS[0]}/g" "$HOME/InkNode/node/op-node/entrypoint.sh"

        echo -e "${GREEN}INK Node installed and ports configured.${NC}"
    else
        echo -e "${RED}Failed to clone INK Node repository.${NC}"
        exit 1
    fi

    # Start the Ink Node
    manage_ink_node
}

# ----------------------------
# Run and Manage Ink Node
# ----------------------------
manage_ink_node() {
    echo -e "${CYAN}Starting Ink Node...${NC}"
    cd "$HOME/InkNode/node"
    

    if ./setup.sh; then
        echo -e "${GREEN}Setup completed successfully.${NC}"
    else
        echo -e "${RED}Failed to complete setup.${NC}"
        return 1  # Прерываем выполнение, если setup не удался
    fi
    
    if docker-compose up -d; then
        echo -e "${GREEN}Ink Node is running.${NC}"
    else
        echo -e "${RED}Failed to start Ink Node.${NC}"
        return 1
    fi


    echo -e "${CYAN}Verifying Sync Status...${NC}"
    curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}' http://localhost:9545 | jq

    echo -e "${CYAN}Comparing local and remote block numbers...${NC}"
    local_block=$(curl -s -X POST http://localhost:8545 -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["finalized", false],"id":1}' \
        | jq -r .result.number | sed 's/^0x//' | awk '{printf "%d\n", "0x" $0}')
    remote_block=$(curl -s -X POST https://rpc-gel-sepolia.inkonchain.com/ -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["finalized", false],"id":1}' \
        | jq -r .result.number | sed 's/^0x//' | awk '{printf "%d\n", "0x" $0}')
    echo -e "${GREEN}Local finalized block: $local_block${NC}"
    echo -e "${GREEN}Remote finalized block: $remote_block${NC}"
}

# ----------------------------
# Restart Node Function
# ----------------------------
restart_node() {
    echo -e "${CYAN}Restarting the node...${NC}"
    cd "$HOME/InkNode/node"
    sudo docker-compose down && sudo docker-compose up -d
    echo -e "${GREEN}Node restarted.${NC}"
}

# ----------------------------
# Shutdown Node Function
# ----------------------------
shutdown_node() {
    echo -e "${CYAN}Shutting down the node...${NC}"
    sudo docker-compose -f "$HOME/InkNode/node/docker-compose.yml" down
    echo -e "${GREEN}Node shut down.${NC}"
}

# ----------------------------
# Delete Node Function
# ----------------------------
delete_node() {
    echo -e "${RED}Deleting INK Node...${NC}"
    rm -rf "$HOME/InkNode/"
    echo -e "${GREEN}INK Node deleted.${NC}"
}

# ----------------------------
# View Logs for node-op-geth Function
# ----------------------------
view_logs_op_geth() {
    echo -e "${CYAN}Checking logs for node-op-geth...${NC}"
    docker logs --tail 50 -f node-op-geth-1
}

# ----------------------------
# View Logs for node-op-node Function
# ----------------------------
view_logs_op_node() {
    echo -e "${CYAN}Checking logs for node-op-node...${NC}"
    docker logs --tail 50 -f node-op-node-1
}

# ----------------------------
# Backup Wallet Function
# ----------------------------
backup_wallet() {
    echo -e "${CYAN}Displaying generated wallet backup...${NC}"
    cat ~/InkNode/node/var/secrets/jwt.txt
}


update_node() {
  sudo docker-compose -f "$HOME/InkNode/node/docker-compose.yml" down
  cd "$HOME/InkNode/node" || { echo "Failed to change directory."; exit 1; }
  git pull origin || { echo "Failed to run git pull."; exit 1; }
  ./setup.sh || { echo "Failed to execute setup.sh."; exit 1; }
  sudo docker-compose -f "$HOME/InkNode/node/docker-compose.yml" up -d
  echo "Update process completed successfully."
}

# ----------------------------
# Main Menu Function
# ----------------------------
main_menu() {
    while true; do
        show_header
        echo -e "    ${SUCCESS} ${GREEN}Welcome to the INK Node Installation Wizard!${NC}"
        show_separator

        echo "    1. Check Port Availability ${INFO}"
        echo "    2. Install Node ${ICON_INSTALL}"
        echo "    3. Restart Node ${ICON_UPDATE}"
        echo "    4. Shutdown Node ${INSTALL}"
        echo "    5. Delete Node ${ERROR}"
        echo "    6. Check Logs for node-op-geth ${ICON_LOGS}"
        echo "    7. Check Logs for node-op-node ${ICON_LOGS}"
        echo "    8. Backup Your Generated Wallet ${NODE}"
        echo "    9. Update ${ICON_INSTALL}"
        echo "    10. Exit ${ICON_EXIT}"
        show_separator
        read -p "Choose an option: " choice

        case $choice in
            1)
                check_ports
                read -p "Press Enter to continue..."
                ;;
            2)
                install_dependencies_and_configure
                read -p "Press Enter to continue..."
                ;;
            3)
                restart_node
                read -p "Press Enter to continue..."
                ;;
            4)
                shutdown_node
                read -p "Press Enter to continue..."
                ;;
            5)
                delete_node
                read -p "Press Enter to continue..."
                ;;
            6)
                view_logs_op_geth
                read -p "Press Enter to continue..."
                ;;
            7)
                view_logs_op_node
                read -p "Press Enter to continue..."
                ;;
            8)
                backup_wallet
                read -p "Press Enter to continue..."
                ;;
            9)  update_node
                read -p "Press Enter to continue..."
                ;;

            10)
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}
# ----------------------------
# Execute Main Menu
# ----------------------------
main_menu
