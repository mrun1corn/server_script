#!/bin/bash

# Colors for enhancing script output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check if a command exists
command_exists() {
    command -v "$1" > /dev/null 2>&1
}

# Function to check for root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root.${NC}"
        exit 1
    fi
}

# Function to display a message in green
success_message() {
    echo -e "${GREEN}$1${NC}"
}

# Function to prompt the user for yes/no input
prompt_yes_no() {
    read -p "$1 (y/n): " response
    if [[ $response =~ ^[Yy]$ ]]; then
        return 0  # True (yes)
    else
        return 1  # False (no)
    fi
}

# Function to add lines to a configuration file if they don't already exist
add_lines_to_config() {
    config_file="$1"
    lines="$2"

    if ! grep -q "$lines" "$config_file"; then
        echo "$lines" | tee -a "$config_file" > /dev/null
    fi
}

# Function to get PHP version
get_php_version() {
    php_version=$(php -v | grep -o 'PHP [0-9]\.[0-9]' | cut -d' ' -f2)
    if [ -n "$php_version" ]; then
        echo "$php_version"
    else
        echo "0"
    fi
}

# Function to perform Cacti installation
install_cacti() {
    check_root
    # Display welcome message
    echo -e "${GREEN}Welcome to the Cacti Installation Script!${NC}"

# Install Apache & PHP
if command -v apt &> /dev/null; then
    # Debian/Ubuntu
    apt update
    apt install -yqq apache2 php-mysql libapache2-mod-php php-xml php-ldap php-mbstring php-gd php-gmp php-intl mariadb-server mariadb-client snmp php-snmp rrdtool librrds-perl
elif command -v yum &> /dev/null; then
    # Red Hat/CentOS
    yum makecache
    yum install -y httpd php php-mysql php-xml php-ldap php-mbstring php-gd php-gmp php-intl mariadb-server mariadb php-snmp rrdtool perl-RRDTool
else
    echo -e "${RED}Error: Unsupported package manager.${NC}"
    exit 1
fi

# Allow time for package reload to complete
echo -e "${GREEN}Waiting for package reload to complete.${NC}"
sleep 5  # Adjust the sleep duration as needed

# Function to prompt for MariaDB root password
get_mariadb_root_password() {
    local max_attempts=3
    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        echo -n "Enter MariaDB root password (Attempt $attempt/$max_attempts): "
        read -s mariadb_root_password
        echo  # Move to a new line after password entry

        if [ -n "$mariadb_root_password" ]; then
            break
        else
            echo -e "\n${RED}Error: Password cannot be empty.${NC}"
            if [ "$attempt" -eq "$max_attempts" ]; then
                echo -e "${RED}Maximum attempts reached. Exiting.${NC}"
                exit 1
            fi
        fi
    done
}
    
    # Database Tuning
    config_file="/etc/mysql/mariadb.conf.d/50-server.cnf"
    add_lines_to_config "$config_file" "# Add/Update"
    add_lines_to_config "$config_file" "collation-server = utf8mb4_unicode_ci"
    add_lines_to_config "$config_file" "max_heap_table_size = 128M"
    add_lines_to_config "$config_file" "tmp_table_size = 64M"
    add_lines_to_config "$config_file" "join_buffer_size = 64M"
    add_lines_to_config "$config_file" "innodb_file_format = Barracuda"
    add_lines_to_config "$config_file" "innodb_large_prefix = 1"
    add_lines_to_config "$config_file" "innodb_buffer_pool_size = 512M"
    add_lines_to_config "$config_file" "innodb_flush_log_at_timeout = 3"
    add_lines_to_config "$config_file" "innodb_read_io_threads = 32"
    add_lines_to_config "$config_file" "innodb_write_io_threads = 16"
    add_lines_to_config "$config_file" "innodb_io_capacity = 5000"
    add_lines_to_config "$config_file" "innodb_io_capacity_max = 10000"

    systemctl restart mariadb

    # PHP Configuration
    php_version=$(get_php_version)
    if [ "$php_version" != "0" ]; then
        php_ini_dir="/etc/php/$php_version"
        php_ini_file="$php_ini_dir/apache2/php.ini"
        php_cli_ini_file="$php_ini_dir/cli/php.ini"

        if [ -f "$php_ini_file" ] && [ -f "$php_cli_ini_file" ]; then
            add_lines_to_config "$php_ini_file" "# Update PHP configuration"
            add_lines_to_config "$php_ini_file" "date.timezone = Asia/Dhaka"
            add_lines_to_config "$php_ini_file" "memory_limit = 512M"
            add_lines_to_config "$php_ini_file" "max_execution_time = 60"

            add_lines_to_config "$php_cli_ini_file" "# Update PHP configuration for CLI"
            add_lines_to_config "$php_cli_ini_file" "date.timezone = Asia/Dhaka"
            add_lines_to_config "$php_cli_ini_file" "memory_limit = 512M"
            add_lines_to_config "$php_cli_ini_file" "max_execution_time = 60"
        else
            echo -e "${RED}Error: PHP configuration files not found for version $php_version.${NC}"
        fi
    else
        echo -e "${RED}Error: PHP version not detected or unsupported.${NC}"
    fi

# Create a new site for Cacti
apache_config_file="/etc/apache2/sites-available/cacti.conf"
add_lines_to_config "$apache_config_file" "Alias /cacti /opt/cacti"
add_lines_to_config "$apache_config_file" ""
add_lines_to_config "$apache_config_file" "  <Directory /opt/cacti>"
add_lines_to_config "$apache_config_file" "      Options +FollowSymLinks"
add_lines_to_config "$apache_config_file" "      AllowOverride None"
add_lines_to_config "$apache_config_file" "      <IfVersion >= 2.3>"
add_lines_to_config "$apache_config_file" "      Require all granted"
add_lines_to_config "$apache_config_file" "      </IfVersion>"
add_lines_to_config "$apache_config_file" "      <IfVersion < 2.3>"
add_lines_to_config "$apache_config_file" "      Order Allow,Deny"
add_lines_to_config "$apache_config_file" "      Allow from all"
add_lines_to_config "$apache_config_file" "      </IfVersion>"
add_lines_to_config "$apache_config_file" ""
add_lines_to_config "$apache_config_file" "   AddType application/x-httpd-php .php"
add_lines_to_config "$apache_config_file" ""
add_lines_to_config "$apache_config_file" "<IfModule mod_php.c>"
add_lines_to_config "$apache_config_file" "      php_flag magic_quotes_gpc Off"
add_lines_to_config "$apache_config_file" "      php_flag short_open_tag On"
add_lines_to_config "$apache_config_file" "      php_flag register_globals Off"
add_lines_to_config "$apache_config_file" "      php_flag register_argc_argv On"
add_lines_to_config "$apache_config_file" "      php_flag track_vars On"
add_lines_to_config "$apache_config_file" "      # this setting is necessary for some locales"
add_lines_to_config "$apache_config_file" "      php_value mbstring.func_overload 0"
add_lines_to_config "$apache_config_file" "      php_value include_path ."
add_lines_to_config "$apache_config_file" " </IfModule>"
add_lines_to_config "$apache_config_file" ""
add_lines_to_config "$apache_config_file" "   DirectoryIndex index.php"
add_lines_to_config "$apache_config_file" "</Directory>"


# Run the function to get MariaDB root password
get_mariadb_root_password

# Create Database and Set Permissions
sudo mysql -u root -p"${mariadb_root_password}" -e "CREATE DATABASE cacti;"
sudo mysql -u root -p"${mariadb_root_password}" -e "GRANT ALL ON cacti.* TO cacti@localhost IDENTIFIED BY 'cacti';"
sudo mysql -u root -p"${mariadb_root_password}" -e "FLUSH PRIVILEGES;"

# Import MariaDB Time Zone data
sudo mysql -u root -p"${mariadb_root_password}" mysql < /usr/share/mysql/mysql_test_data_timezone.sql

# Grant SELECT privilege on time_zone_name table
sudo mysql -u root -p"${mariadb_root_password}" -e "GRANT SELECT ON mysql.time_zone_name TO cacti@localhost;"
sudo mysql -u root -p"${mariadb_root_password}" -e "FLUSH PRIVILEGES;"


	wget https://www.cacti.net/downloads/cacti-latest.tar.gz
	tar -zxvf cacti-latest.tar.gz
	sudo mv cacti-1* /opt/cacti

    sudo mysql -u root -p cacti < /opt/cacti/cacti.sql
    config_php_file="/opt/cacti/include/config.php"
    add_lines_to_config "$config_php_file" "<?php"
    add_lines_to_config "$config_php_file" "\$database_type     = \"mysql\";"
    add_lines_to_config "$config_php_file" "\$database_default  = \"cacti\";"
    add_lines_to_config "$config_php_file" "\$database_hostname = \"localhost\";"
    add_lines_to_config "$config_php_file" "\$database_username = \"cacti\";"
    add_lines_to_config "$config_php_file" "\$database_password = \"${mariadb_root_password}\";"
    add_lines_to_config "$config_php_file" "\$database_port     = \"3306\";"
    add_lines_to_config "$config_php_file" "\$database_ssl      = false;"

    # Create a crontab file
    cron_file="/etc/cron.d/cacti"
    add_lines_to_config "$cron_file" "# Add the following scheduler entry"
    add_lines_to_config "$cron_file" "*/5 * * * * www-data php /opt/cacti/poller.php > /dev/null 2>&1"

    # Enable the created site
    sudo a2ensite cacti

    # Prompt before restarting Apache
    if prompt_yes_no "Do you want to restart Apache?"; then
        systemctl restart apache2
        success_message "Apache restarted."
    else
        echo "Skipping Apache restart."
    fi

    # Create a log file for Cacti
    sudo touch /opt/cacti/log/cacti.log
    sudo chown -R www-data:www-data /opt/cacti/

    success_message "Cacti installation completed successfully!"
}

# Run the installation function
install_cacti
