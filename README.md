# FastAPI + Kubernetes (Minikube) + Ingress Example

This project demonstrates how to deploy a simple FastAPI application on Kubernetes using Minikube, including:

## ✅ Building and using local Docker images inside Minikube

## ✅ Deploying Pods with a Deployment manifest

## ✅ Exposing Pods internally with a Service

## ✅ Exposing the Service externally using an Ingress Controller

🌐 Using a custom local domain name to access the app

📁 Project Structure

```

fastapi-minikube/
├── main.py              # FastAPI application
├── requirements.txt     # Python dependencies
├── Dockerfile           # Docker build configuration
├── deployment.yml       # K8s Deployment + Service
└── ingress.yml          # K8s Ingress configuration

```

##🧰 Prerequisites

macOS (Intel or Apple Silicon)

```
brew install minikube
```

```
brew install kubectl
```


##🧱 Step 1: Start Minikube

Start Minikube using the Docker driver:

```
minikube start --driver=docker
```


Switch Docker context to Minikube’s internal Docker daemon:

```
eval $(minikube docker-env)
```

##🐳 Step 2: Build the FastAPI Image Inside Minikube

```
docker build -t fastapi-app:latest .
```


##📝 Because we switched Docker context to Minikube, this image will be built inside Minikube, not your local Docker Desktop.

##📜 Step 3: Deploy FastAPI to Kubernetes

Apply the Deployment and Service:

```
minikube kubectl -- apply -f deployment.yml
```


Check that Pods are running:

```
minikube kubectl -- get pods
```


Expected:

```
NAME                                   READY   STATUS    RESTARTS   AGE
fastapi-deployment-xxxxxxx-xxxxx       1/1     Running   0          10s

```

Check Service:

```
minikube kubectl -- get svc
```


Expected:

```
fastapi-service    ClusterIP   10.xxx.xxx.xxx   <none>        80/TCP   xxm
```


🌐 Step 4: Enable and Configure Ingress

Enable Minikube’s built-in NGINX Ingress Controller:

```
minikube addons enable ingress
```


Wait a few seconds, then apply the Ingress resource:

```
minikube kubectl -- apply -f ingress.yml
```


Check Ingress status:

```
minikube kubectl -- get ingress
```


📝 Step 5: Configure /etc/hosts

Get Minikube IP:

```
minikube ip
```

# Example: 192.168.49.2


Edit your hosts file:

```
sudo nano /etc/hosts

```

Add:

```
192.168.49.2   fastapi.local
```


🧪 Step 7: Test the Application

Open your browser at:

http://fastapi.local


or use curl:

curl http://fastapi.local


Expected response:

```
{"message":"Hello from FastAPI on Minikube 🚀"}
```

🧹 Cleanup

To remove resources:

```
minikube kubectl -- delete -f ingress.yml
minikube kubectl -- delete -f deployment.yml
```


To delete the entire Minikube cluster:

```
minikube delete
```

