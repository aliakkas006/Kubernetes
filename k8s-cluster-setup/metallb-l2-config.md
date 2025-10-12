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

```bash
kubectl get pods -n metallb-system
```
```bash
kubectl get deployments -n metallb-system
```

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
sudo vim nginx-deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.27.2
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 250m
              memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  labels:
    app: nginx
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - name: http
      port: 80          # Port exposed by the service
      targetPort: 80    # Port on the container
```

```bash
kubectl apply -f nginx-deployment.yaml
```

```bash
kubectl get svc nginx-service
```

- EXTERNAL-IP should show an IP from our pool (e.g. 192.168.56.240)

```bash
# from our host or any machine on the same subnet:
curl http://<EXTERNAL-IP>
```






