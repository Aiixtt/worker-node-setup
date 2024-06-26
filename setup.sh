#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root" 
   exit 1
fi

set -e

KUBERNETES_VERSION=1.29
MASTER_IP="<MASTER_IP>"
TOKEN="<NEW_TOKEN>"
CA_CERT_HASH="<NEW_CA_CERT_HASH>"

# Function to print error messages and exit
error_exit() {
    echo "Error: $1"
    exit 1
}

# Load necessary kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay || error_exit "Failed to load overlay module"
sudo modprobe br_netfilter || error_exit "Failed to load br_netfilter module"

# Set up sysctl parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl parameters
sudo sysctl --system || error_exit "Failed to apply sysctl parameters"

# Update package list and install prerequisites
sudo apt-get update -y || error_exit "Failed to update package list"
sudo apt-get install -y software-properties-common curl apt-transport-https ca-certificates || error_exit "Failed to install prerequisites"

# Download and add the CRI-O apt key
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg || error_exit "Failed to download and add the CRI-O apt key"

# Add the CRI-O apt repository
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list || error_exit "Failed to add the CRI-O apt repository"

# Update package list again
sudo apt-get update -y || error_exit "Failed to update package list"

# Install CRI-O
sudo apt-get install -y cri-o || error_exit "Failed to install CRI-O"

# Enable and start CRI-O service
sudo systemctl daemon-reload || error_exit "Failed to reload systemd daemon"
sudo systemctl enable crio --now || error_exit "Failed to enable and start CRI-O service"
sudo systemctl start crio.service || error_exit "Failed to start CRI-O service"

# Create directory for Kubernetes keyrings
sudo mkdir -p /etc/apt/keyrings || error_exit "Failed to create /etc/apt/keyrings"

# Download and add the Kubernetes apt key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg || error_exit "Failed to download and add the Kubernetes apt key"

# Add the Kubernetes apt repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list || error_exit "Failed to add the Kubernetes apt repository"

# Update package list again
sudo apt-get update -y || error_exit "Failed to update package list"

# Install kubelet, kubeadm, and kubectl
sudo apt-get install -y kubelet kubeadm kubectl || error_exit "Failed to install kubelet, kubeadm, and kubectl"

# Mark kubelet, kubeadm, and kubectl to prevent them from being automatically updated
sudo apt-mark hold kubelet kubeadm kubectl || error_exit "Failed to hold kubelet, kubeadm, and kubectl"

# Join the Kubernetes cluster
#sudo kubeadm join $MASTER_IP:6443 --token $TOKEN --discovery-token-ca-cert-hash $CA_CERT_HASH || error_exit "Failed to join the Kubernetes cluster"

echo "Worker node setup completed successfully."
