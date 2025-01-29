#!/bin/bash

# LabDeploy - Automated Homelab Deployment Script
# Version: 1.01

set -e

# Display script version
if [[ "$1" == "--version" ]]; then
    echo "LabDeploy version 1.01"
    exit 0
fi

# Ensure ~/docker directory exists
WORKDIR="$HOME/docker"
mkdir -p "$WORKDIR/config"

# Install required packages
install_packages() {
    echo "Installing required packages..."
    sudo apt update
    sudo apt install -y docker.io docker-compose-plugin whiptail
    sudo usermod -aG docker "$USER"
    echo "Installation complete. Please log out and log back in to apply group changes."
}

# Ensure required packages are installed
if ! command -v docker &>/dev/null || ! command -v docker-compose &>/dev/null || ! command -v whiptail &>/dev/null; then
    install_packages
fi

# Function to prompt user for action
prompt_user_action() {
    ACTION=$(whiptail --title "LabDeploy" --menu "Choose an option:" 15 60 3 \
        "Install" "Deploy LabDeploy and configure services" \
        "Backup" "Backup current configuration" \
        "Uninstall" "Remove LabDeploy and all services" 3>&1 1>&2 2>&3)

    case "$ACTION" in
        "Install")
            install_labdeploy
            ;;
        "Backup")
            backup_configuration
            exit 0
            ;;
        "Uninstall")
            uninstall_labdeploy
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
        docker-compose -f "$WORKDIR/compose.yml" up -d
        echo "Containers are now running!"
    else
        echo "Setup complete. You can start the containers later using:"
        echo "docker-compose -f $WORKDIR/compose.yml up -d"
    fi
}

# Function to install LabDeploy
install_labdeploy() {
    select_media_root
    select_timezone
    select_services

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

    # Generate docker-compose.yml
    echo "services:" > "$WORKDIR/compose.yml"
    for service in $SERVICES; do
        SERVICE_NAME=$(echo $service | tr '[:upper:]' '[:lower:]' | tr -d ' ')
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
  $SERVICE_NAME:
    image: $IMAGE
    container_name: $SERVICE_NAME
    restart: unless-stopped
    networks:
      - media_network
    volumes:
      - ~/docker/config/$SERVICE_NAME:/config
      - \${MEDIA_ROOT}/downloads:/downloads
    environment:
      - PUID=\${PUID}
      - PGID=\${PGID}
      - TZ=\${TZ}
EOF
    done
    echo "networks:
  media_network:
    driver: bridge" >> "$WORKDIR/compose.yml"
    echo "Generated docker-compose.yml at $WORKDIR/compose.yml"

    # Ask the user if they want to start the containers now
    start_containers_prompt
}

# Function to uninstall LabDeploy
uninstall_labdeploy() {
    read -p "Are you sure you want to remove LabDeploy and all services? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        docker-compose -f "$WORKDIR/compose.yml" down || true
        rm -rf "$WORKDIR"
        echo "LabDeploy and all services have been removed."

        echo "Removing installed dependencies..."
        sudo apt remove -y docker.io docker-compose-plugin whiptail
        sudo apt autoremove -y
        echo "Dependencies removed. System is now clean."
    else
        echo "Uninstallation cancelled."
    fi
}

# Start script by prompting user for action
prompt_user_action
