#!/bin/bash

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with sudo. Please rerun with sudo."
    exit 1
fi

# Function to check if a command is available and install if not
check_command() {
    local command_name="$1"
    local package_name="$2"
    if ! command -v "$command_name" &> /dev/null; then
        if [ -n "$package_name" ]; then
            sudo apt update
            sudo apt install -y "$package_name"
        else
            echo "Error: $command_name is not installed and no package provided to install."
            exit 1
        fi
    fi
}

# Function to fix every line in a configuration file
fix_config_file() {
    local file_path="$1"
    local expected_content="$2"
    if [ ! -f "$file_path" ]; then
        echo "Creating $file_path"
        sudo tee "$file_path" > /dev/null <<< "$expected_content"
    else
        local existing_content=$(sudo cat "$file_path")
        local new_content="$expected_content"
        local line
        while IFS= read -r line; do
            if ! grep -q "^$line" <<< "$existing_content"; then
                echo "Fixing line '$line' in $file_path"
                new_content+=$'\n'"$line"
            fi
        done <<< "$expected_content"
        sudo tee "$file_path" > /dev/null <<< "$new_content"
    fi
}

# Check and install required commands and packages
check_command "aria2c" "aria2"
check_command "apache2"
check_command "unzip"
check_command "python3"
check_command "pip3" "python3-pip"

# Install Google Drive API Dependencies
sudo pip3 install --upgrade google-api-python-client google-auth-httplib2 google-auth-oauthlib

# Check if AriaNG directory exists
if [ ! -d "/var/www/html/ariang" ]; then
    # Download and extract AriaNG WebUI
    sudo wget -O /tmp/AriaNg-1.2.2.zip https://github.com/mayswind/AriaNg/releases/download/1.2.2/AriaNg-1.2.2.zip
    sudo unzip -q /tmp/AriaNg-1.2.2.zip -d /var/www/html/ariang
    sudo rm /tmp/AriaNg-1.2.2.zip
fi

# Check if Aria2 configuration exists
if [ ! -f "/etc/aria2.conf" ]; then
    # Prompt for Aria2 RPC secret token
    read -p "Enter a secret token for Aria2 RPC (leave blank for no authentication): " secret_token

    # Create Aria2 configuration file content
    aria2_conf_content="
dir=/home/$USER/download
enable-rpc=true
rpc-allow-origin-all=true
rpc-listen-all=true
bt-enable-lpd=true
max-concurrent-downloads=5
continue=true
max-connection-per-server=5
min-split-size=10M
rpc-secret=$secret_token
enable-rpc=true
rpc-listen-all=true
file-allocation=none
disable-ipv6=true
enable-http-pipelining=true
enable-dht=true
enable-dht6=false
enable-peer-exchange=true
seed-ratio=0.0
rpc-listen-port=6800
follow-torrent=true
bt-max-peers=55
seed-time=0
max-overall-upload-limit=0
max-overall-download-limit=0
log-level=warn
save-session=/etc/aria2.session
input-file=/etc/aria2.session
save-session-interval=30
disk-cache=64M
enable-rpc=true
rpc-listen-all=true
"

    # Fix Aria2 configuration file
    fix_config_file "/etc/aria2.conf" "$aria2_conf_content"

    # Authorize Google Drive access
    sudo aria2c --conf-path=/etc/aria2.conf --enable-http-proxy=false --rpc-listen-port=6801
fi

# Check if download directory exists, if not, create it
download_dir="/home/$USER/download"
if [ ! -d "$download_dir" ]; then
    sudo mkdir -p "$download_dir"
    sudo chown -R "$USER:$USER" "$download_dir"
fi

# Check if systemd service unit file exists
if [ ! -f "/etc/systemd/system/aria2.service" ]; then
    # Define systemd service unit file content
    systemd_service_content="[Unit]
Description=Aria2 Download Manager
After=network.target

[Service]
User=$USER
ExecStart=/usr/bin/aria2c --enable-rpc --rpc-listen-all --conf-path=/etc/aria2.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
"

    # Fix systemd service unit file
    fix_config_file "/etc/systemd/system/aria2.service" "$systemd_service_content"

    # Reload systemd and start Aria2 service
    sudo systemctl daemon-reload
    sudo systemctl start aria2
fi

# Check if Apache configuration files are correct, fix if necessary
apache_conf_content="
Alias /ariang /var/www/html/ariang
<Directory /var/www/html/ariang>
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>
"
fix_config_file "/etc/apache2/sites-available/000-default.conf" "$apache_conf_content"

# Check if Aria2 and Apache services are running
if ! systemctl is-active --quiet aria2; then
    sudo systemctl start aria2
fi

if ! systemctl is-active --quiet apache2; then
    sudo systemctl start apache2
fi

# Done
echo "Aria2 and AriaNG WebUI have been installed and configured."
echo "You can access the WebUI by visiting http://your_server_ip/ariang"
