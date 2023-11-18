#!/bin/bash

# Function to prompt for user input
get_user_input() {
    read -p "Enter the Mikrotik gateway IP address: " mikrotik_ip
    read -p "Enter the local IP address for SNMP Exporter (default is 127.0.0.1): " local_ip
    local_ip=${local_ip:-127.0.0.1}
}

# Function to download and install Prometheus
install_prometheus() {
    wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
    tar xzf prometheus-2.45.0.linux-amd64.tar.gz
    mv prometheus-2.45.0.linux-amd64 /etc/prometheus
    cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
[Service]
ExecStart=/etc/prometheus/prometheus --config.file=/etc/prometheus/prometheus.yml
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl restart prometheus
    systemctl enable prometheus
    systemctl status prometheus
    q
    ip
}

# Function to download and install SNMP Exporter
install_snmp_exporter() {
    wget https://github.com/prometheus/snmp_exporter/releases/download/v0.22.0/snmp_exporter-0.22.0.linux-amd64.tar.gz
    tar xzf snmp_exporter-0.22.0.linux-amd64.tar.gz
    mv snmp_exporter-0.22.0.linux-amd64 /etc/snmp_exporter
    cat <<EOF > /etc/systemd/system/snmp_exporter.service
[Unit]
Description=SNMP Exporter
Wants=network-online.target
After=network-online.target
[Service]
ExecStart=/etc/snmp_exporter/snmp_exporter --config.file=/etc/snmp_exporter/snmp.yml
Restart=always
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl restart snmp_exporter
    systemctl enable snmp_exporter
    systemctl status snmp_exporter
    q
}

# Function to configure Prometheus scraping
configure_prometheus_scraping() {
    cat <<EOF >> /etc/prometheus/prometheus.yml
  - job_name: 'Mikrotik'
    static_configs:
      - targets:
        - $mikrotik_ip  # Mikrotik device.
    metrics_path: /snmp
    params:
      module: [mikrotik]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: $local_ip:9116
EOF
}

# Function to download and install Grafana
install_grafana() {
    sudo apt install -y adduser libfontconfig1
    wget https://dl.grafana.com/enterprise/release/grafana-enterprise_10.0.1_amd64.deb
    sudo dpkg -i grafana-enterprise_10.0.1_amd64.deb
    systemctl restart grafana-server
    systemctl enable grafana-server
    systemctl status grafana-server
    q
}

# Main script
get_user_input
install_prometheus
install_snmp_exporter
configure_prometheus_scraping
install_grafana
echo now open grafana using browser through port 3000
echo create a new connection in prometheus using your host ip and port of 9090, an placeholder will given
echo now goto dashboard and import 14857
