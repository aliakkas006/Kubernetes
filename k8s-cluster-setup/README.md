# Kubernetes Cluster Setup Guide

This guide provides step-by-step instructions to set up a single-master Kubernetes cluster with Containerd as the container runtime, Cilium as the CNI plugin, Helm for package management, and the Kubernetes Dashboard for cluster visualization. It is designed for beginners to advanced users, with clear explanations and best practices.

## Prerequisites

- **Operating System**: Ubuntu 22.04 or later (or a compatible Linux distribution).
- **Hardware**:
  - **Master Node**: At least 2 CPUs, 2GB RAM, and 20GB disk space.
  - **Worker Nodes**: At least 1 CPU, 1GB RAM, and 15GB disk space.
- **Network**: All nodes must be on the same network with static IPs (e.g., 192.168.56.100 for the master).
- **User Permissions**: Root or sudo access on all nodes.
- **Internet Access**: Required for downloading packages and tools.

## Step 1: Prepare All Nodes (Control Plane + Worker Nodes)

These steps configure the system settings and install necessary dependencies on all nodes (master and workers).

### Disable Swap

Kubernetes requires swap to be disabled to ensure predictable performance.

```bash
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a
```

Verify by editing `/etc/fstab` and ensuring the swap line (e.g., `swap.img`) is commented out:

```bash
sudo nano /etc/fstab
```

### Load Kernel Modules

Enable required kernel modules for Kubernetes networking.

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

### Configure Sysctl Parameters

Enable IP forwarding and bridge networking.

```bash
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
sudo sysctl -w net.ipv4.ip_forward=1
```

Verify IP forwarding:

```bash
sysctl net.ipv4.ip_forward
```

### Install Dependencies

Install tools required for Kubernetes package management.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl apt-transport-https
```

### Install Kubernetes Components

Add the Kubernetes apt repository and install `kubelet`, `kubeadm`, and `kubectl`.

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet
```

### Install Containerd

Install and configure Containerd as the container runtime.

```bash
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
```

Verify the configuration:

```bash
cat /etc/containerd/config.toml
```

## Step 2: Initialize the Control Plane

These steps are performed **only on the master node** to initialize the Kubernetes control plane.

### Initialize the Cluster

Use `kubeadm init` to set up the control plane. Replace `192.168.61.90` with your master node's IP and ensure the `--pod-network-cidr` matches your network configuration.

```bash
sudo kubeadm init --apiserver-advertise-address=192.168.61.90 --pod-network-cidr=192.168.0.0/16 --cri-socket /run/containerd/containerd.sock --ignore-preflight-errors Swap
```

### Configure kubectl

Set up the Kubernetes configuration for the admin user.

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Verify Cluster

Check the status of the pods in all namespaces.

```bash
kubectl get pod -A
```

### Reset Cluster (If Needed)

To reset the cluster configuration, run:

```bash
sudo kubeadm reset -f
```

### Reboot

Reboot the master node to ensure all changes take effect.

```bash
sudo reboot
```

## Step 3: Install Cilium (Control Plane Node Only)

Cilium is used as the Container Network Interface (CNI) plugin for networking.

### Install Cilium CLI

Download and install the Cilium CLI.

```bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
```

Verify the installation:

```bash
cilium version
```

### Install Cilium

Deploy Cilium version 1.17.4.

```bash
cilium install --version 1.17.4
cilium status
```

Verify the Cilium pods:

```bash
kubectl get pod -n kube-system
```

Check cluster information:

```bash
kubectl cluster-info
```

## Step 4: Join Worker Nodes

These steps are performed **on each worker node** to join them to the cluster.

### Join the Cluster

On the master node, generate a join command:

```bash
kubeadm token create --print-join-command
```

Copy the output (e.g., `kubeadm join 192.168.61.90:6443 --token ...`) and run it on each worker node with `sudo`.

### Verify Nodes

On the master node, check the cluster nodes:

```bash
kubectl get nodes
```

View all pods with details:

```bash
kubectl get pod -A -o wide
```

## Step 5: Install Helm (Master Node Only)

Helm is a package manager for Kubernetes.

### Install Helm

Download and run the Helm installation script.

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

Verify the installation:

```bash
helm version
```

## Step 6: Label Worker Nodes

Assign the `worker` role to worker nodes for proper workload scheduling.

### Label Nodes

On the master node, label each worker node (replace `node-01` with the actual node name from `kubectl get nodes`):

```bash
kubectl label node node-01 node-role.kubernetes.io/worker=worker
```

Verify the labels:

```bash
kubectl get nodes
```

## Step 7: Install Kubernetes Dashboard (Master Node Only)

The Kubernetes Dashboard provides a web-based UI for cluster management.

### Add Helm Repository

Add the Kubernetes Dashboard repository.

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
```

### Deploy Dashboard

Install the dashboard using Helm.

```bash
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
```

### Verify Service

Check the dashboard service:

```bash
kubectl -n kubernetes-dashboard get svc -o wide
```

### Create Admin User

Create a service account and role binding for admin access.

```bash
mkdir -p /opt/kubernetes-dashboard
cd /opt/kubernetes-dashboard
```

Create `dashboard-adminuser.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
```

Create `cluster-role.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
```

Apply the configurations:

```bash
kubectl apply -f dashboard-adminuser.yaml
kubectl apply -f cluster-role.yaml
```

### Access the Dashboard

Use `screen` to manage the port-forwarding session.

```bash
sudo apt-get install -y screen
screen -S kubernetes-dashboard
kubectl -n kubernetes-dashboard port-forward --address 0.0.0.0 svc/kubernetes-dashboard-kong-proxy 8443:443
```

To detach from the screen session, press `Ctrl+A`, then `Ctrl+D`. To reattach:

```bash
screen -dr kubernetes-dashboard
```

### Generate Access Token

Create a token for dashboard login:

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

Access the dashboard at `https://<master-ip>:8443` using the generated token.

## Troubleshooting

- **Swap Error**: Ensure swap is disabled by checking `/etc/fstab` and running `swapoff -a`.
- **Cilium Issues**: Verify Cilium pods are running (`kubectl get pod -n kube-system`).
- **Dashboard Access**: If `port-forward` fails, check the service name with `kubectl -n kubernetes-dashboard get svc`.
- **Node Not Ready**: Ensure the join command is correct and the CNI (Cilium) is properly installed.

## Best Practices

- **Backup Configurations**: Save `/etc/kubernetes/admin.conf` and other critical files.
- **Monitor Cluster**: Use `kubectl get nodes` and `kubectl get pod -A` regularly to monitor cluster health.
- **Security**: Restrict dashboard access by limiting the port-forward address or using a reverse proxy with authentication.
- **Updates**: Regularly update Kubernetes components and Cilium to the latest stable versions.

