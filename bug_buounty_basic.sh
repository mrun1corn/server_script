#!/bin/bash

set -e

# Function to wait for dpkg/apt lock release
wait_for_dpkg_lock() {
    echo "Waiting for dpkg/apt lock release..."
    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
        sleep 1
    done
}

# Function to install required packages
install_required_packages() {
    echo "Installing required packages..."
    wait_for_dpkg_lock
    sudo apt update -y
    wait_for_dpkg_lock
    sudo apt install -y wget curl python3 python3-pip git
    echo "Required packages installation complete."
}

# Function to get the latest Go version
get_latest_go_version() {
    echo "Fetching the latest version of Go..."
    latest_version=$(curl -s https://go.dev/VERSION?m=text | head -1)
    echo "Latest Go version is $latest_version"
}

# Function to install the latest version of Go
install_latest_go() {
    get_latest_go_version
    echo "Installing Go $latest_version..."
    wget "https://go.dev/dl/${latest_version}.linux-amd64.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "${latest_version}.linux-amd64.tar.gz"
    rm "${latest_version}.linux-amd64.tar.gz"
    echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.profile
    export PATH=$PATH:/usr/local/go/bin
    echo "Go $latest_version installation complete."
}

# Function to check if Go is installed
check_go_installed() {
    if command -v go &> /dev/null
    then
        echo "Go is installed"
        go version
    else
        echo "Go is not installed. Installing the latest version of Go..."
        install_latest_go
        if command -v go &> /dev/null
        then
            echo "Go installation successful"
            go version
        else
            echo "Go installation failed. Please check the installation steps."
            exit 1
        fi
    fi
}

# Function to install Sublist3r
install_sublist3r() {
    echo "Installing Sublist3r..."
    pip3 install sublist3r
    echo "Sublist3r installation complete."
}

# Function to install Subfinder
install_subfinder() {
    echo "Installing Subfinder..."
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest || {
        echo "Failed to install Subfinder. Ensure Go is properly installed and environment variables are set."
        exit 1
    }
    sudo mv $HOME/go/bin/subfinder /usr/local/bin/
    echo "Subfinder installation complete."
}

# Function to install Dirsearch
install_dirsearch() {
    echo "Installing Dirsearch..."
    git clone https://github.com/maurosoria/dirsearch.git
    cd dirsearch
    sudo python3 setup.py install
    sudo ln -s $(pwd)/dirsearch.py /usr/local/bin/dirsearch
    cd ..
    echo "Dirsearch installation complete."
}

# Function to install httpx
install_httpx() {
    echo "Installing httpx..."
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest || {
        echo "Failed to install httpx. Ensure Go is properly installed and environment variables are set."
        exit 1
    }
    sudo mv $HOME/go/bin/httpx /usr/local/bin/
    echo "httpx installation complete."
}

# Function to install Nuclei
install_nuclei() {
    echo "Installing Nuclei..."
    go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest || {
        echo "Failed to install Nuclei. Ensure Go is properly installed and environment variables are set."
        exit 1
    }
    sudo mv $HOME/go/bin/nuclei /usr/local/bin/
    echo "Nuclei installation complete."
	echo "updating nuclei"
	sudo nuclei --update
	sudo nuclei --update-templates
}

# Function to check if Nuclei is installed
check_nuclei_installed() {
    if command -v nuclei &> /dev/null
    then
        echo "Nuclei is installed"
        nuclei -version
    else
        echo "Nuclei is not installed. Installing Nuclei..."
        install_nuclei
    fi
}

# Function to check if Sublist3r is installed
check_sublist3r_installed() {
    if command -v sublist3r &> /dev/null
    then
        echo "Sublist3r is installed"
    else
        echo "Sublist3r is not installed. Installing Sublist3r..."
        install_sublist3r
    fi
}

# Function to check if Subfinder is installed
check_subfinder_installed() {
    if command -v subfinder &> /dev/null
    then
        echo "Subfinder is installed"
        subfinder -version
    else
        echo "Subfinder is not installed. Installing Subfinder..."
        install_subfinder
    fi
}

# Function to check if Dirsearch is installed
check_dirsearch_installed() {
    if command -v dirsearch &> /dev/null
    then
        echo "Dirsearch is installed"
    else
        echo "Dirsearch is not installed. Installing Dirsearch..."
        install_dirsearch
    fi
}

# Function to check if httpx is installed
check_httpx_installed() {
    if command -v httpx &> /dev/null
    then
        echo "httpx is installed"
        httpx -version
    else
        echo "httpx is not installed. Installing httpx..."
        install_httpx
    fi
}

# Main script execution

echo "Installing required packages..."
install_required_packages

echo "Checking Go installation..."
check_go_installed

echo "Checking Sublist3r installation..."
check_sublist3r_installed

echo "Checking Subfinder installation..."
check_subfinder_installed

echo "Checking Dirsearch installation..."
check_dirsearch_installed

echo "Checking Nuclei installation..."
check_nuclei_installed

echo "Checking httpx installation..."
check_httpx_installed

echo "Installation script completed."
