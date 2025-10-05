## 1. Enable strict ARP mode

```bash
kubectl edit configmap -n kube-system kube-proxy
```

```yaml
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
```

---
  
## 2. Install MetalLB (controller + speakers)

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
```

## 3. Verify the `metallb-system` namespace and pods

kubectl get pods -n metallb-system
kubectl get deployments -n metallb-system

## 4. Basic L2 (Layer-2) configuration

```bash
sudo vim metallb-ip-pool.yaml
```

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  namespace: metallb-system
  name: my-ip-pool
spec:
  addresses:
    - 192.168.56.240-192.168.56.250   # <--- our reserved IP range
```

```bash
kubectl apply -f metallb-ip-pool.yaml
```

## 5. Advertise the IP Address Pool

```bash
sudo vim metallb-l2-adv.yaml
```

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  namespace: metallb-system
  name: my-l2-advert
spec:
  ipAddressPools:
    - my-ip-pool
```

```bash
kubectl apply -f metallb-l2-adv.yaml
```


## 6. Test with a LoadBalancer service

```bash
kubectl create deployment nginx --image=nginx
```

```bash
kubectl expose deployment nginx --port=80 --target-port=80 --type=LoadBalancer --name=nginx-lb
```

```bash
kubectl get svc nginx-lb
```

- EXTERNAL-IP should show an IP from our pool (e.g. 192.168.56.240)

```bash
# from our host or any machine on the same subnet:
curl http://<EXTERNAL-IP>
```






