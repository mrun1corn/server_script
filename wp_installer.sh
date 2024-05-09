#!/bin/bash

# Function to display error messages and exit
display_error() {
    echo "Error: $1"
    exit 1
}

# Function to check if a package is installed (Debian/Ubuntu)
is_package_installed_debian() {
    dpkg -l "$1" &> /dev/null
}

# Function to check if a package is installed (RHEL/CentOS)
is_package_installed_rhel() {
    rpm -q "$1" &> /dev/null
}

# Function to check if a package is installed (Fedora)
is_package_installed_fedora() {
    dnf list installed "$1" &> /dev/null
}

# Function to check if a line exists in a file
is_line_in_file() {
    grep -qF -- "$1" "$2"
}

# Function to append a line to a file if it doesn't already exist
append_line_to_file() {
    is_line_in_file "$1" "$2" || echo "$1" | sudo tee -a "$2" > /dev/null
}

# Function to check if a directory exists
is_directory_exists() {
    [ -d "$1" ]
}

# Function to check if a file exists
is_file_exists() {
    [ -f "$1" ]
}

# Function to check if a MySQL user exists
is_mysql_user_exists() {
    mysql -e "SELECT 1 FROM mysql.user WHERE User='$1'" &> /dev/null
}

# Function to check if a MySQL database exists
is_mysql_database_exists() {
    mysql -e "USE $1" &> /dev/null
}

# Function to install packages on Debian/Ubuntu
install_packages_debian() {
    apt update || display_error "Failed to update system"
    apt install -y apache2 mysql-server php php-mysql libapache2-mod-php php-cli wget || display_error "Failed to install LAMP stack"
}

# Function to install packages on RHEL/CentOS
install_packages_rhel() {
    yum -y update || display_error "Failed to update system"
    yum -y install httpd mariadb-server php php-mysqlnd wget || display_error "Failed to install LAMP stack"
}

# Function to install packages on Fedora
install_packages_fedora() {
    dnf -y upgrade || display_error "Failed to update system"
    dnf -y install httpd mariadb-server php php-mysqlnd wget || display_error "Failed to install LAMP stack"
}

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    display_error "This script must be run as root"
fi

# Detect package manager
if command -v apt &> /dev/null; then
    PACKAGE_MANAGER="apt"
    is_package_installed=is_package_installed_debian
    install_packages=install_packages_debian
    MYSQL_SERVICE="mysql"
elif command -v yum &> /dev/null; then
    PACKAGE_MANAGER="yum"
    is_package_installed=is_package_installed_rhel
    install_packages=install_packages_rhel
    MYSQL_SERVICE="mariadb"
elif command -v dnf &> /dev/null; then
    PACKAGE_MANAGER="dnf"
    is_package_installed=is_package_installed_fedora
    install_packages=install_packages_fedora
    MYSQL_SERVICE="mariadb"
else
    display_error "Unsupported package manager. Script supports only apt (Debian/Ubuntu), yum (RHEL/CentOS), and dnf (Fedora)."
fi

# Install LAMP stack if not already installed
if ! $is_package_installed apache2 || ! $is_package_installed $MYSQL_SERVICE || ! $is_package_installed php || ! $is_package_installed wget; then
    $install_packages || display_error "Failed to install LAMP stack"
fi

# Start MySQL service if not already running
if ! systemctl is-active --quiet $MYSQL_SERVICE; then
    systemctl start $MYSQL_SERVICE || display_error "Failed to start $MYSQL_SERVICE service"
fi

# Ask for WordPress username and password
read -p "Enter WordPress username: " wp_user
read -sp "Enter WordPress password: " wp_pass
echo

# Ask for port and set default to 80
read -p "Enter port to configure WordPress (default 80): " port
port=${port:-80}

# Add port to Apache configuration
if [ -f /etc/apache2/ports.conf ]; then
    if ! is_line_in_file "Listen ${port}" /etc/apache2/ports.conf; then
        append_line_to_file "Listen ${port}" /etc/apache2/ports.conf || display_error "Failed to add port to Apache configuration"
    fi
elif [ -f /etc/httpd/conf/httpd.conf ]; then
    if ! is_line_in_file "Listen ${port}" /etc/httpd/conf/httpd.conf; then
        append_line_to_file "Listen ${port}" /etc/httpd/conf/httpd.conf || display_error "Failed to add port to Apache configuration"
    fi
else
    display_error "Apache configuration file not found. Please configure the port manually."
fi

# Create MySQL database and user if not already exist
if ! is_mysql_database_exists wordpress || ! is_mysql_user_exists "$wp_user"; then
    mysql -e "CREATE DATABASE IF NOT EXISTS wordpress;"
    mysql -e "CREATE USER IF NOT EXISTS '${wp_user}'@'localhost' IDENTIFIED BY '${wp_pass}';"
    mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO '${wp_user}'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
fi

# Download WordPress if not already downloaded
if ! is_directory_exists /var/www/html/wordpress; then
    cd /var/www/html || display_error "Failed to change directory to /var/www/html"
    wget https://wordpress.org/latest.tar.gz || display_error "Failed to download WordPress"
    tar -xzvf latest.tar.gz || display_error "Failed to extract WordPress"
    chown -R www-data:www-data wordpress || display_error "Failed to change ownership"
    chmod -R 755 wordpress || display_error "Failed to change permissions"
fi

# Configure wp-config.php with database details if not already configured
if ! is_file_exists /var/www/html/wordpress/wp-config.php; then
    cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php || display_error "Failed to copy wp-config-sample.php"
    sed -i "s/database_name_here/wordpress/" /var/www/html/wordpress/wp-config.php || display_error "Failed to replace database name in wp-config.php"
    sed -i "s/username_here/${wp_user}/" /var/www/html/wordpress/wp-config.php || display_error "Failed to replace database username in wp-config.php"
    sed -i "s/password_here/${wp_pass}/" /var/www/html/wordpress/wp-config.php || display_error "Failed to replace database password in wp-config.php"
else
    if ! is_line_in_file "define('DB_NAME', 'wordpress');" /var/www/html/wordpress/wp-config.php; then
        echo "define('DB_NAME', 'wordpress');" >> /var/www/html/wordpress/wp-config.php || display_error "Failed to add database name line in wp-config.php"
    fi
    if ! is_line_in_file "define('DB_USER', '${wp_user}');" /var/www/html/wordpress/wp-config.php; then
        echo "define('DB_USER', '${wp_user}');" >> /var/www/html/wordpress/wp-config.php || display_error "Failed to add database user line in wp-config.php"
    fi
    if ! is_line_in_file "define('DB_PASSWORD', '${wp_pass}');" /var/www/html/wordpress/wp-config.php; then
        echo "define('DB_PASSWORD', '${wp_pass}');" >> /var/www/html/wordpress/wp-config.php || display_error "Failed to add database password line in wp-config.php"
    fi
fi

# Configure Apache virtual host if not already configured
if ! is_file_exists /etc/apache2/sites-available/wordpress.conf; then
    cat <<EOF > /etc/apache2/sites-available/wordpress.conf
<VirtualHost *:${port}>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/wordpress
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
else
    if ! is_line_in_file "DocumentRoot /var/www/html/wordpress" /etc/apache2/sites-available/wordpress.conf; then
        sed -i "s#DocumentRoot.*#DocumentRoot /var/www/html/wordpress#" /etc/apache2/sites-available/wordpress.conf || display_error "Failed to update DocumentRoot line in wordpress.conf"
    fi
    if ! is_line_in_file "ErrorLog" /etc/apache2/sites-available/wordpress.conf; then
        sed -i "/DocumentRoot.*a\    ErrorLog \${APACHE_LOG_DIR}/error.log" /etc/apache2/sites-available/wordpress.conf || display_error "Failed to add ErrorLog line in wordpress.conf"
    fi
    if ! is_line_in_file "CustomLog" /etc/apache2/sites-available/wordpress.conf; then
        sed -i "/ErrorLog.*a\    CustomLog \${APACHE_LOG_DIR}/access.log combined" /etc/apache2/sites-available/wordpress.conf || display_error "Failed to add CustomLog line in wordpress.conf"
    fi
fi

# Enable Apache virtual host
a2ensite wordpress.conf || display_error "Failed to enable WordPress site"
a2enmod rewrite || display_error "Failed to enable Apache rewrite module"

# Restart Apache
if systemctl restart apache2 &> /dev/null || systemctl restart httpd &> /dev/null; then
    echo "Apache restarted successfully"
else
    display_error "Failed to restart Apache"
fi


echo "WordPress installation completed. You can access it at: http://your-server-ip-address:${port}/wordpress"
