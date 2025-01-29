#!/bin/bash

# LabDeploy - Automated Homelab Deployment Script
# Version: 1.0

set -e

# Display script version
if [[ "$1" == "--version" ]]; then
    echo "LabDeploy version 1.0"
    exit 0
fi

# Ensure ~/docker directory exists
WORKDIR="$HOME/docker"
mkdir -p "$WORKDIR/config"

# Install required packages
install_packages() {
    echo "Installing required packages..."
    sudo apt update
    sudo apt install -y docker.io docker-compose whiptail
    sudo usermod -aG docker "$USER"
    echo "Installation complete. Please log out and log back in to apply group changes."
}

# Ensure required packages are installed
if ! command -v docker &>/dev/null || ! command -v docker-compose &>/dev/null || ! command -v whiptail &>/dev/null; then
    install_packages
fi

# Function to select MEDIA_ROOT interactively
select_media_root() {
    MEDIA_ROOT=$(whiptail --inputbox "Enter the media root directory (use Tab for path completion):" 10 60 "$HOME/media" 3>&1 1>&2 2>&3)
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
        "AdGuard Home" "Network-wide ad blocker" ON \
        "Overseerr" "Media request manager" ON \
        "Plex" "Media server" ON \
        "qBittorrent" "Torrent downloader" ON \
        "Radarr" "Movie management" ON \
        "SABnzbd" "Usenet downloader" ON \
        "Sonarr" "TV show management" ON \
        "Tautulli" "Plex monitoring" ON \
        "ZNC" "IRC Bouncer" ON 3>&1 1>&2 2>&3)
    if [ -z "$SERVICES" ]; then
        echo "No services selected. Exiting."
        exit 1
    fi
    export SERVICES
}

# Prompt for MEDIA_ROOT selection
select_media_root

# Prompt for Timezone selection
select_timezone

# Prompt for service selection
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
    ports:
      - "\${${SERVICE_NAME^^}_PORT}:7878"
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

# Run docker-compose up
read -p "Do you want to start the containers now? (y/n): " start_containers
if [[ "$start_containers" == "y" ]]; then
    docker-compose -f "$WORKDIR/compose.yml" up -d
    echo "Containers are now running!"
else
    echo "Setup complete. Run 'docker-compose -f $WORKDIR/compose.yml up -d' to start containers."
fi
