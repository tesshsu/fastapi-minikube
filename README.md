# FastAPI + Kubernetes (Minikube) + Helm + Sealed Secrets

This project demonstrates how to deploy a FastAPI application on Kubernetes using Minikube with two deployment approaches:
- **Simple**: Using plain Kubernetes manifests
- **Advanced**: Using Helm charts with Sealed Secrets

## Features

✅ Building and using local Docker images inside Minikube  
✅ Deploying Pods with a Deployment manifest  
✅ Exposing Pods internally with a Service  
✅ Exposing the Service externally using an Ingress Controller  
✅ Helm chart with multi-environment support (dev/prod)  
✅ Sealed Secrets for secure secret management  
🌐 Using a custom local domain name to access the app

---

## 📁 Project Structure

```
fastapi-minikube/
├── fastapi-chart/                    # Helm chart directory
│   ├── charts/                       # Chart dependencies
│   ├── templates/                    # Kubernetes manifest templates
│   │   ├── _helpers.tpl              # Template helpers
│   │   ├── configmap.yaml            # ConfigMap template
│   │   ├── deployment.yaml           # Deployment template
│   │   ├── ingress.yaml              # Ingress template
│   │   ├── sealedsecret.yaml               # Secret template (Sealed Secrets)
│   │   └── service.yaml              # Service template
│   ├── Chart.yaml                    # Helm chart metadata
│   ├── values.yaml                   # Default values
│   ├── values.dev.yaml               # Development environment values
│   └── values.prod.yaml              # Production environment values
├── k8s/                              # Plain Kubernetes manifests
│   └── configmap-secret.yml          # ConfigMap and Secret examples
├── scripts/                          # Utility scripts
│   ├── configmap-secret-demo.sh      # Demo script for secrets
│   ├── sealed-secret-demo.sh         # ✅ FIXED - Demo script
│   ├── create-sealed-secret.sh       # 🆕 NEW - Production script
│   ├── helm-deploy.sh                # Deploy with Helm
│   └── cleanup.sh                    # Cleanup script
├── main.py                           # FastAPI application
├── requirements.txt                  # Python dependencies
├── Dockerfile                        # Docker build configuration
├── deployment.yml                    # K8s Deployment + Service (standalone)
├── ingress.yml                       # K8s Ingress configuration (standalone)
└── README.md                         # This file
```

---

## 🧰 Prerequisites

**macOS** (Intel or Apple Silicon)

### Install Required Tools

```bash
# Minikube
brew install minikube

# Kubectl
brew install kubectl

# Helm
brew install helm

# Kubeseal (for Sealed Secrets)
brew install kubeseal
```

---

## 🚀 Quick Start

### Step 1: Start Minikube

Start Minikube using the Docker driver:

```bash
minikube start --driver=docker
```

Switch Docker context to Minikube's internal Docker daemon:

```bash
eval $(minikube docker-env)
```

### Step 2: Build the FastAPI Image Inside Minikube

```bash
docker build -t fastapi-app:latest .
```

> **Note**: Because we switched Docker context to Minikube, this image will be built inside Minikube, not your local Docker Desktop.

### Step 3: Enable Ingress

Enable Minikube's built-in NGINX Ingress Controller:

```bash
minikube addons enable ingress
```

---

## 📦 Deployment Method 1: Plain Kubernetes Manifests

### Deploy the Application

Apply the Deployment and Service:

```bash
kubectl apply -f deployment.yml
```

Apply the Ingress:

```bash
kubectl apply -f ingress.yml
```

### Verify Deployment

Check that Pods are running:

```bash
kubectl get pods
```

Expected output:
```
NAME                                   READY   STATUS    RESTARTS   AGE
fastapi-deployment-xxxxxxx-xxxxx       1/1     Running   0          10s
```

Check Service:

```bash
kubectl get svc
```

Expected output:
```
NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
fastapi-service   ClusterIP   10.xxx.xxx.xxx  <none>        80/TCP    xxm
```

Check Ingress status:

```bash
kubectl get ingress
```

---

## 📦 Deployment Method 2: Helm Chart (Recommended)

### Install Sealed Secrets Controller

First, install the Sealed Secrets controller:

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system
```

Verify it's running:

```bash
kubectl -n kube-system get pods -l app.kubernetes.io/name=sealed-secrets
```

### Create Sealed Secrets

Use the demo script to create sealed secrets:

```bash
chmod +x scripts/sealed-secret-demo.sh
./scripts/sealed-secret-demo.sh
```

This will:
1. Fetch the public certificate from the Sealed Secrets controller
2. Create a sealed secret from your plaintext secrets
3. Apply it to your cluster

### Deploy with Helm

**Development Environment:**

```bash
helm install fastapi-dev ./fastapi-chart -f ./fastapi-chart/values.dev.yaml
```

**Production Environment:**

```bash
helm install fastapi-prod ./fastapi-chart -f ./fastapi-chart/values.prod.yaml
```

**Custom Values:**

```bash
helm install fastapi ./fastapi-chart \
  --set image.tag=v2.0.0 \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=myapp.local
```

### Verify Helm Deployment

```bash
# List Helm releases
helm list

# Check deployment status
kubectl get all -l app.kubernetes.io/instance=fastapi-dev

# View Helm values
helm get values fastapi-dev
```

### Upgrade Deployment

```bash
helm upgrade fastapi-dev ./fastapi-chart -f ./fastapi-chart/values.dev.yaml
```

### Uninstall

```bash
helm uninstall fastapi-dev
```

---

## 🌐 Configure /etc/hosts

Get Minikube IP:

```bash
minikube ip
# Example: 192.168.49.2
```

Edit your hosts file:

```bash
sudo nano /etc/hosts
```

Add the following line:

```
192.168.49.2   fastapi.local
```

Save and exit (`Ctrl+X`, then `Y`, then `Enter`).

---

## 🧪 Test the Application

### Using Browser

Open your browser and navigate to:

```
http://fastapi.local
```

### Using curl

```bash
curl http://fastapi.local
```

Expected response:

```json
{"message":"Hello from FastAPI on Minikube 🚀"}
```

### Test API Endpoints

```bash
# Health check
curl http://fastapi.local/health

# Docs
open http://fastapi.local/docs
```

---

## 🔐 Working with Sealed Secrets

### Create a New Sealed Secret

```bash
# 1. Create a regular Kubernetes secret (don't apply it)
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=supersecret \
  --dry-run=client -o yaml > mysecret.yaml

# 2. Seal it using kubeseal
kubeseal --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  --format yaml < mysecret.yaml > mysealedsecret.yaml

# 3. Apply the sealed secret
kubectl apply -f mysealedsecret.yaml

# 4. Delete the plaintext secret file
rm mysecret.yaml
```

### View Decrypted Secret

```bash
kubectl get secret my-secret -o jsonpath='{.data.password}' | base64 -d
```

---

## 🔄 Common Operations

### View Logs

```bash
# Plain manifest deployment
kubectl logs -l app=fastapi-app

# Helm deployment
kubectl logs -l app.kubernetes.io/instance=fastapi-dev
```

### Port Forward (for local testing without Ingress)

```bash
kubectl port-forward svc/fastapi-service 8080:80
# Access at http://localhost:8080
```

### Scale Deployment

```bash
# Plain manifest
kubectl scale deployment fastapi-deployment --replicas=3

# Helm
helm upgrade fastapi-dev ./fastapi-chart --set replicaCount=3
```

### Debug Pod Issues

```bash
# Describe pod
kubectl describe pod <pod-name>

# Get events
kubectl get events --sort-by='.lastTimestamp'

# Execute commands in pod
kubectl exec -it <pod-name> -- /bin/sh
```

---

## 🧹 Cleanup

### Remove Plain Manifests

```bash
kubectl delete -f ingress.yml
kubectl delete -f deployment.yml
```

### Remove Helm Release

```bash
helm uninstall fastapi-dev
```

### Remove Sealed Secrets Controller

```bash
helm uninstall sealed-secrets -n kube-system
```

### Delete Minikube Cluster

```bash
minikube delete
```

---

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)

---

## 🐛 Troubleshooting

### Issue: "connection refused" when using kubectl

**Solution**: Ensure Minikube is running and context is set correctly:

```bash
minikube status
kubectl config use-context minikube
kubectl cluster-info
```

### Issue: Image pull errors

**Solution**: Make sure you've switched to Minikube's Docker daemon:

```bash
eval $(minikube docker-env)
docker build -t fastapi-app:latest .
```

### Issue: Ingress not working

**Solution**: 
1. Ensure Ingress addon is enabled: `minikube addons list | grep ingress`
2. Check Ingress controller logs: `kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx`
3. Verify /etc/hosts is configured correctly

### Issue: Sealed Secret not decrypting

**Solution**:
1. Verify controller is running: `kubectl -n kube-system get pods -l app.kubernetes.io/name=sealed-secrets`
2. Check controller logs: `kubectl -n kube-system logs -l app.kubernetes.io/name=sealed-secrets`
3. Ensure the sealed secret was created with the correct certificate

---

## 📝 License

MIT