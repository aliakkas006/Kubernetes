#!/bin/bash
# ==============================================================
# Kubernetes Node Preparation Script (Master or Worker)
# Compatible: Ubuntu 22.04 / 24.04
# Author: Ali Akkas
# ==============================================================

set -e

# ---- Step 1: Set Hostname (manual input) ----------
echo ">>> Current hostname: $(hostname)"
read -p "Enter new hostname for this node (e.g., master, worker-1, worker-2): " NEW_HOSTNAME
sudo hostnamectl set-hostname "$NEW_HOSTNAME"
echo "Hostname set to $(hostnamectl --static)"

# ---- Add hostname to /etc/hosts for kubeadm compatibility ----
echo ">>> Adding new hostname to /etc/hosts..."
if ! grep -q "$NEW_HOSTNAME" /etc/hosts; then
    echo "127.0.0.1   $NEW_HOSTNAME" | sudo tee -a /etc/hosts
    echo "Added $NEW_HOSTNAME to /etc/hosts"
else
    echo "$NEW_HOSTNAME already exists in /etc/hosts"
fi


# ---- Step 2: Disable Swap ------------------------------------
echo ">>> Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo "Swap disabled"
free -h | grep Swap

# ---- Step 3: Load Kernel Modules ------------------------------
echo ">>> Loading kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
echo "Kernel modules loaded"

# ---- Step 4: Configure Sysctl Parameters ----------------------
echo ">>> Configuring sysctl parameters..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# ---- sysctl command ----
sudo sysctl --system
echo "Sysctl parameters configured"

# ---- Step 5: Install Basic Dependencies -----------------------
echo ">>> Installing dependencies..."
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gpg
echo "Dependencies installed"

# ---- Step 6: Add Kubernetes Repository ------------------------
echo ">>> Adding Kubernetes apt repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

cat /etc/apt/sources.list.d/kubernetes.list
echo "Kubernetes repo added"

# ---- Step 7: Install Kubernetes Components --------------------
echo ">>> Installing kubelet, kubeadm, and kubectl..."
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet
echo "Kubernetes components installed and held"

# ---- Step 8: Install Container Runtime (containerd) -----------
echo ">>> Installing containerd runtime..."
sudo apt update
sudo apt install -y containerd

sudo mkdir -p /etc/containerd
containerd config default \
  | sed 's/SystemdCgroup = false/SystemdCgroup = true/' \
  | sed 's|sandbox_image = ".*"|sandbox_image = "registry.k8s.io/pause:3.10"|' \
  | sudo tee /etc/containerd/config.toml > /dev/null

sudo systemctl restart containerd
sudo systemctl enable containerd

echo "containerd configured with SystemdCgroup and pause image"
systemctl status containerd --no-pager

echo "=============================================================="
echo "Node preparation complete!"
echo "Hostname     : $(hostname)"
echo "Swap Disabled: $(free -h | grep Swap)"
echo "Kubelet      : $(systemctl is-enabled kubelet)"
echo "Containerd    : $(systemctl is-active containerd)"
echo "=============================================================="
