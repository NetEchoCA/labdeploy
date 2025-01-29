# LabDeploy - Automated Homelab Deployment Script

## Version: 1.02

LabDeploy is a Bash script designed to automate the setup and deployment of a homelab media stack using Docker and Docker Compose on a Debian-based system.

### Features:
- Interactive **whiptail** menus for selecting media storage and timezone.
- Allows users to select which applications to install.
- Dynamically generates a **docker-compose.yml** based on user selections.
- Uses `.env` file for storing environment variables.
- Ensures **Docker and Docker Compose** are installed.
- Creates required **configuration directories** automatically.
- Provides an option to **start containers** immediately after setup.
- Includes **backup** and **uninstall** options for easy management.

## Supported Applications
LabDeploy allows users to install the following applications:

- **AdGuard Home** (Network-wide ad blocker)
- **Overseerr** (Media request manager)
- **Plex** (Media server)
- **qBittorrent** (Torrent downloader)
- **Radarr** (Movie management)
- **SABnzbd** (Usenet downloader)
- **Sonarr** (TV show management)
- **Tautulli** (Plex monitoring tool)
- **ZNC** (IRC Bouncer)

## Installation

### Option 1: Run Directly Using Curl
```bash
curl -fsSL https://raw.githubusercontent.com/NetEchoCA/labdeploy/main/labdeploy.sh | bash
```

### Option 2: Clone the Repository and Run
```bash
git clone https://github.com/NetEchoCA/labdeploy.git
cd labdeploy
chmod +x labdeploy.sh
./labdeploy.sh
```

## How It Works
1. The script ensures that Docker and Docker Compose are installed.
2. The user selects a **media root directory** for storage.
3. The user selects a **timezone** from an interactive menu.
4. The user selects **which applications** to install.
5. The script generates a `.env` file and `docker-compose.yml` based on the selected services.
6. The script prompts the user to **start the containers** immediately or later.

## Uninstallation
To completely remove LabDeploy and all installed services:
```bash
curl -fsSL https://raw.githubusercontent.com/NetEchoCA/labdeploy/main/labdeploy.sh | bash
```
Then, select **Uninstall** from the menu.

This will:
- Stop and remove all containers
- Delete all configuration files
- Remove installed dependencies (`docker.io`, `docker-compose-plugin`, `whiptail`)
- Restore the system to a clean state

(Note: This will remove all installed services and configurations but **not your media files**.)

## Changelog
### **v1.01 (Latest)**
- Added **menu prompt at launch** (Install, Backup, Uninstall options)
- Replaced `docker-compose` with **Docker Compose v2 (`docker-compose-plugin`)**
- Implemented **backup functionality**
- Added **dependency removal** during uninstall to restore a clean system
- Fixed **MEDIA_ROOT input** to support **Tab completion**
- Added **confirmation prompt** to start containers after installation

### **v1.0**
- Initial release with basic setup and Docker installation
- Interactive selection of services
- `.env` and `docker-compose.yml` generation
- Basic container deployment

## License
LabDeploy is an open-source project licensed under the MIT License.

## Contributors
- **NetEchoCA** - Creator & Maintainer

## Issues & Feedback
If you encounter any issues, feel free to open an issue on GitHub: [NetEchoCA/labdeploy](https://github.com/NetEchoCA/labdeploy/issues)

