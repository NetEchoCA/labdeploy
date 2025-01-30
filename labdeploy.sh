#!/bin/bash

# LabDeploy - Automated Homelab Deployment Script
# Version: 1.02

set -e

# Display script version
if [[ "$1" == "--version" ]]; then
    echo "LabDeploy version 1.02"
    exit 0
fi

is_port_available() {
    local PORT=$1
    if ss -tuln | grep -q ":$PORT "; then
        return 1  # Port is in use
    else
        return 0  # Port is available
    fi
}

# Ensure ~/docker directory exists
WORKDIR="$HOME/docker"
mkdir -p "$WORKDIR/config"

# Install required packages
install_packages() {
    echo "Installing required packages..."
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg

    # Add Docker’s official repository
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker.io docker-compose-plugin whiptail
    sudo usermod -aG docker "$USER"
    echo "Installation complete. Please log out and log back in to apply group changes."
}

# Ensure required packages are installed
if ! command -v docker &>/dev/null || ! command -v docker-compose &>/dev/null || ! command -v whiptail &>/dev/null; then
    install_packages
fi

# Function to uninstall LabDeploy
uninstall_labdeploy() {
    echo "DEBUG: Running uninstall_labdeploy() function"

    read -p "Are you sure you want to remove LabDeploy and all services? (y/n): " confirm </dev/tty
    echo "DEBUG: User input -> '$confirm'"

    if [[ "$confirm" == "y" ]]; then
        echo "DEBUG: Stopping and removing Docker containers"
        docker-compose -f "$WORKDIR/compose.yml" down || true

        echo "DEBUG: Deleting LabDeploy directory"
        rm -rf "$WORKDIR"

        echo "DEBUG: Removing installed dependencies..."
        sudo apt remove -y docker.io docker-compose-plugin whiptail
        sudo apt autoremove -y

        echo "DEBUG: Uninstallation complete. System is clean."
    else
        echo "DEBUG: Uninstallation cancelled by user."
    fi
}

# Function to prompt user for action
prompt_user_action() {
    ACTION=$(whiptail --title "LabDeploy" --menu "Choose an option:" 15 60 3 \
        "Install" "Deploy LabDeploy and configure services" \
        "Backup" "Backup current configuration" \
        "Uninstall" "Remove LabDeploy and all services" 3>&1 1>&2 2>&3)

    echo "DEBUG: User selected -> '$ACTION'"

    ACTION=$(echo "$ACTION" | xargs)  # Trim spaces

    case "$ACTION" in
        "Install")
            install_labdeploy
            ;;
        "Backup")
            backup_configuration
            exit 0
            ;;
        "Uninstall")
            echo "Starting uninstallation..."
            uninstall_labdeploy
            echo "DEBUG: Uninstall function executed"
            exit 0
            ;;
        *)
            echo "Invalid option. Exiting."
            exit 1
            ;;
    esac
}

# Function to ask user if they want to start Docker containers
start_containers_prompt() {
    if whiptail --yesno "Do you want to start the containers now?" 10 60; then
        docker compose -f "$WORKDIR/compose.yml" up -d
        echo "Containers are now running!"
    else
        echo "Setup complete. You can start the containers later using:"
        echo "docker-compose -f $WORKDIR/compose.yml up -d"
    fi
}

# Function to select MEDIA_ROOT interactively with tab completion
select_media_root() {
    echo "Enter the media root directory (use Tab for path completion):"
    read -e -p "Path: " MEDIA_ROOT </dev/tty
    if [ -z "$MEDIA_ROOT" ]; then
        echo "No media root selected. Exiting."
        exit 1
    fi
    export MEDIA_ROOT="$MEDIA_ROOT"
}

# Function to select timezone interactively
select_timezone() {
    TIMEZONE=$(whiptail --title "Select Timezone" --menu "Choose your timezone:" 20 60 10 $(timedatectl list-timezones | awk '{print $1 " " $1}') 3>&1 1>&2 2>&3)
    if [ -z "$TIMEZONE" ]; then
        echo "No timezone selected. Exiting."
        exit 1
    fi
    export TZ="$TIMEZONE"
}

# Function to select applications to install
select_services() {
    SERVICES=$(whiptail --title "Select Services" --checklist "Select which services to install:" 20 60 10 \
        "AdGuardHome" "Network-wide ad blocker" ON \
        "Overseerr" "Media request manager" ON \
        "Plex" "Media server" ON \
        "qBittorrent" "Torrent downloader" ON \
        "Radarr" "Movie management" ON \
        "SABnzbd" "Usenet downloader" ON \
        "Sonarr" "TV show management" ON \
        "Tautulli" "Plex monitoring" ON \
        "ZNC" "IRC Bouncer" ON 3>&1 1>&2 2>&3)

    echo "DEBUG: Selected SERVICES='$SERVICES'"

    # Ensure services are formatted correctly
    SERVICES=$(echo "$SERVICES" | tr -d '"')

    if [ -z "$SERVICES" ]; then
        echo "No services selected. Exiting."
        exit 1
    fi
    export SERVICES
}


# Function to install LabDeploy
install_labdeploy() {
    select_media_root
    select_timezone
    select_services

    # Define default ports
    declare -A DEFAULT_PORTS=(
        [radarr]=7878
        [sonarr]=8989
        [sabnzbd]=8080
        [qbittorrent]=8080
        [overseerr]=5055
        [tautulli]=8181
        [znc]=6501
        [plex]="N/A"  # Uses host mode, no manual port mapping
        [adguardhome]="N/A"  # Uses host mode, no manual port mapping
    )

    # Create necessary directories
    mkdir -p "$WORKDIR/config"
    for service in $SERVICES; do
        mkdir -p "$WORKDIR/config/$(echo $service | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
    done

    echo "Created configuration directories."

    # Create .env file
    cat <<EOF > "$WORKDIR/.env"
# LabDeploy Environment Variables
MEDIA_ROOT="$MEDIA_ROOT"
PUID=1000
PGID=1000
TZ="$TZ"
EOF

    echo "Generated .env file at $WORKDIR/.env"

    # Prompt user for ports
    echo "DEBUG: Entering port selection loop"
    echo "Enter port numbers for each service (leave blank to use default):"
    for service in $SERVICES; do
        SERVICE_NAME=$(echo "$service" | awk '{print tolower($0)}' | tr -d ' "')
        DEFAULT_PORT=${DEFAULT_PORTS[$SERVICE_NAME]}

        echo "DEBUG: Processing $SERVICE_NAME, default port: $DEFAULT_PORT"

        if [[ "$DEFAULT_PORT" == "N/A" ]]; then
            echo "DEBUG: $SERVICE_NAME runs in host mode, skipping port selection."
            continue
        fi

        while true; do
            read -p "Enter port for $SERVICE_NAME (default: $DEFAULT_PORT): " PORT </dev/tty
            PORT=${PORT:-$DEFAULT_PORT}  # Use default if blank

            if is_port_available "$PORT"; then
                export "${SERVICE_NAME^^}_PORT"="$PORT"
                echo "DEBUG: Assigned port $PORT to $SERVICE_NAME"
                break  # Port is available
            else
                echo "DEBUG: Port $PORT is in use. Asking user to enter a new one."
            fi
        done

    echo "DEBUG: Finished port selection loop"

        export "${SERVICE_NAME^^}_PORT"="$PORT"
    done

    # Generate docker-compose.yml
    echo "services:" > "$WORKDIR/compose.yml"
    for service in $SERVICES; do
        SERVICE_NAME=$(echo "$service" | awk '{print tolower($0)}' | tr -d ' "')
        case $SERVICE_NAME in
            adguardhome|plex|tautulli)
                NETWORK_CONFIG="network_mode: \"host\""
                ;;
            znc)
                NETWORK_CONFIG="networks:\n      - znc_network"
                ;;
            *)
                NETWORK_CONFIG="networks:\n      - media_network"
                ;;
        esac

        case $SERVICE_NAME in
            adguardhome)
                IMAGE="adguard/adguardhome"
                ;;
            overseerr)
                IMAGE="sctx/overseerr"
                ;;
            plex)
                IMAGE="lscr.io/linuxserver/plex"
                ;;
            qbittorrent)
                IMAGE="qbittorrentofficial/qbittorrent-nox"
                ;;
            *)
                IMAGE="lscr.io/linuxserver/$SERVICE_NAME:latest"
                ;;
        esac

        cat <<EOF >> "$WORKDIR/compose.yml"
  ${SERVICE_NAME//\"/}:
    image: ${IMAGE//\"/}
    container_name: ${SERVICE_NAME//\"/}
    restart: unless-stopped
    ${NETWORK_CONFIG}
    volumes:
      - ~/docker/config/${SERVICE_NAME//\"/}:/config
      - \${MEDIA_ROOT}/downloads:/downloads
    environment:
      - PUID=\${PUID}
      - PGID=\${PGID}
      - TZ=\${TZ}
EOF

        # Only add ports if the service is NOT using host network mode
        if [[ "$NETWORK_CONFIG" != 'network_mode: "host"' ]]; then
            echo "    ports:" >> "$WORKDIR/compose.yml"
            echo "      - \"\\${${SERVICE_NAME^^}_PORT}:${DEFAULT_PORTS[$SERVICE_NAME]}\"" >> "$WORKDIR/compose.yml"
        fi
    done

    echo "networks:
  media_network:
    driver: bridge
  znc_network:
    driver: bridge" >> "$WORKDIR/compose.yml"
    echo "Generated docker-compose.yml at $WORKDIR/compose.yml"

    # Ask the user if they want to start the containers now
    start_containers_prompt
}


# Start script by prompting user for action
prompt_user_action
