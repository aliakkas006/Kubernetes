We should apply the `--node-ip` configuration **on both the master and worker nodes**, but **with their respective IPs**:

### **Master Node (`192.168.56.100`)**
1. **Edit `/etc/default/kubelet`:**
   ```bash
   sudo vi /etc/default/kubelet
   ```
2. **Set the master's IP:**
   ```bash
   KUBELET_EXTRA_ARGS="--node-ip=192.168.56.100"
   ```
3. **Restart kubelet:**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart kubelet
   ```

### **Worker Node (`192.168.56.102`)**
1. **Edit `/etc/default/kubelet`:**
   ```bash
   sudo vi /etc/default/kubelet
   ```
2. **Set the worker's IP:**
   ```bash
   KUBELET_EXTRA_ARGS="--node-ip=192.168.56.102"
   ```
3. **Restart kubelet:**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart kubelet
   ```

---

### **Why?**
- **Master Node (`192.168.56.100`)**  
  Needs its correct IP for:  
  - `kube-apiserver` communication (`--advertise-address=192.168.56.100`)  
  - `kubelet` registration with the control plane  

- **Worker Node (`192.168.56.102`)**  
  Needs its own IP for:  
  - Joining the cluster correctly  
  - Pod networking and node-to-node communication  

---

### **Verification**
Run on **each node** to confirm the correct IP is set:
```bash
ps aux | grep kubelet | grep node-ip
```
Expected output:
- **Master:** `--node-ip=192.168.56.100`
- **Worker:** `--node-ip=192.168.56.102`

Check cluster node IPs:
```bash
kubectl get nodes -o wide
```
Should show:
```
NAME      STATUS   INTERNAL-IP      ...
master    Ready    192.168.56.100   ...
worker    Ready    192.168.56.102   ...
```

---

### **Troubleshooting**
If the worker node fails to join:
1. Check logs:
   ```bash
   sudo journalctl -u kubelet -n 50 --no-pager
   ```
2. Verify network connectivity:
   ```bash
   ping 192.168.56.100  # From worker to master
   ping 192.168.56.102  # From master to worker
   ```

