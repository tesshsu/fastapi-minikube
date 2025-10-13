#!/usr/bin/env bash

set -e

# Configuration
RELEASE_NAME="fastapi"
CHART_PATH="./fastapi-chart"
NAMESPACE="default"
ENVIRONMENT="${1:-dev}"  # dev or prod, default to dev

echo "=============================="
echo "🚀 FastAPI Helm Deployment Script"
echo "=============================="
echo "Environment: $ENVIRONMENT"
echo "Release: $RELEASE_NAME-$ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo ""

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Error: helm is not installed"
    echo "Please install it: brew install helm"
    exit 1
fi

# Check if chart exists
if [ ! -d "$CHART_PATH" ]; then
    echo "❌ Error: Helm chart not found at $CHART_PATH"
    exit 1
fi

# Determine values file
if [ "$ENVIRONMENT" == "prod" ]; then
    VALUES_FILE="$CHART_PATH/values.prod.yaml"
elif [ "$ENVIRONMENT" == "dev" ]; then
    VALUES_FILE="$CHART_PATH/values.dev.yaml"
else
    echo "❌ Error: Invalid environment. Use 'dev' or 'prod'"
    exit 1
fi

if [ ! -f "$VALUES_FILE" ]; then
    echo "❌ Error: Values file not found: $VALUES_FILE"
    exit 1
fi

# Step 1: Check if Sealed Secrets is installed
echo "=============================="
echo "🔍 [Step 1] Checking prerequisites"
echo "=============================="

if ! kubectl -n kube-system get pods -l app.kubernetes.io/name=sealed-secrets 2>/dev/null | grep -q Running; then
    echo "⚠️  Sealed Secrets controller not found!"
    read -p "Install Sealed Secrets controller? (y/N): " install_sealed
    if [[ $install_sealed == "y" || $install_sealed == "Y" ]]; then
        echo "Installing Sealed Secrets..."
        helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
        helm repo update
        helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system
        
        echo "⏳ Waiting for controller to be ready..."
        kubectl -n kube-system wait --for=condition=ready pod -l app.kubernetes.io/name=sealed-secrets --timeout=300s
        echo "✅ Sealed Secrets controller installed"
    else
        echo "⚠️  Continuing without Sealed Secrets (secrets won't be encrypted)"
    fi
else
    echo "✅ Sealed Secrets controller is running"
fi

# Check if ingress is enabled
if ! minikube addons list | grep ingress | grep -q enabled; then
    echo "⚠️  Ingress addon not enabled!"
    read -p "Enable Minikube ingress addon? (y/N): " enable_ingress
    if [[ $enable_ingress == "y" || $enable_ingress == "Y" ]]; then
        minikube addons enable ingress
        echo "✅ Ingress enabled"
    fi
else
    echo "✅ Ingress addon is enabled"
fi

echo ""

# Step 2: Lint the chart
echo "=============================="
echo "🔎 [Step 2] Linting Helm chart"
echo "=============================="
helm lint "$CHART_PATH" -f "$VALUES_FILE"
echo "✅ Chart lint passed"
echo ""

# Step 3: Dry run to preview changes
echo "=============================="
echo "📋 [Step 3] Preview deployment (dry-run)"
echo "=============================="
read -p "Show dry-run output? (y/N): " show_dryrun
if [[ $show_dryrun == "y" || $show_dryrun == "Y" ]]; then
    helm upgrade --install "$RELEASE_NAME-$ENVIRONMENT" "$CHART_PATH" \
        -f "$VALUES_FILE" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --dry-run --debug
    echo ""
fi

# Step 4: Deploy or upgrade
echo "=============================="
echo "🚀 [Step 4] Deploying to Kubernetes"
echo "=============================="

if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME-$ENVIRONMENT"; then
    echo "📦 Release exists. Upgrading..."
    ACTION="upgrade"
else
    echo "📦 New release. Installing..."
    ACTION="install"
fi

read -p "Proceed with deployment? (y/N): " proceed
if [[ $proceed != "y" && $proceed != "Y" ]]; then
    echo "❌ Deployment cancelled"
    exit 0
fi

helm upgrade --install "$RELEASE_NAME-$ENVIRONMENT" "$CHART_PATH" \
    -f "$VALUES_FILE" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --wait \
    --timeout 5m

echo "✅ Deployment complete!"
echo ""

# Step 5: Show deployment status
echo "=============================="
echo "📊 [Step 5] Deployment status"
echo "=============================="

echo ""
echo "🎯 Release info:"
helm list -n "$NAMESPACE" | grep "$RELEASE_NAME-$ENVIRONMENT"

echo ""
echo "📦 Pods:"
kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME-$ENVIRONMENT"

echo ""
echo "🌐 Services:"
kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME-$ENVIRONMENT"

echo ""
echo "🔀 Ingress:"
kubectl get ingress -n "$NAMESPACE" -l "app.kubernetes.io/instance=$RELEASE_NAME-$ENVIRONMENT"

echo ""

# Step 6: Wait for pods to be ready
echo "=============================="
echo "⏳ [Step 6] Waiting for pods to be ready"
echo "=============================="

kubectl wait --for=condition=ready pod \
    -l "app.kubernetes.io/instance=$RELEASE_NAME-$ENVIRONMENT" \
    -n "$NAMESPACE" \
    --timeout=300s

echo "✅ All pods are ready!"
echo ""

# Step 7: Get pod name and show logs
POD_NAME=$(kubectl get pods -n "$NAMESPACE" \
    -l "app.kubernetes.io/instance=$RELEASE_NAME-$ENVIRONMENT" \
    -o jsonpath="{.items[0].metadata.name}")

echo "=============================="
echo "📋 [Step 7] Application logs"
echo "=============================="
echo "Pod: $POD_NAME"
echo ""

read -p "Show application logs? (y/N): " show_logs
if [[ $show_logs == "y" || $show_logs == "Y" ]]; then
    kubectl logs -n "$NAMESPACE" "$POD_NAME" --tail=50
fi

echo ""

# Step 8: Test the application
echo "=============================="
echo "🧪 [Step 8] Testing the application"
echo "=============================="

# Get ingress host
INGRESS_HOST=$(kubectl get ingress -n "$NAMESPACE" \
    -l "app.kubernetes.io/instance=$RELEASE_NAME-$ENVIRONMENT" \
    -o jsonpath="{.items[0].spec.rules[0].host}" 2>/dev/null || echo "")

if [ -n "$INGRESS_HOST" ]; then
    MINIKUBE_IP=$(minikube ip)
    echo ""
    echo "🌐 Application URL: http://$INGRESS_HOST"
    echo "📝 Add to /etc/hosts: $MINIKUBE_IP   $INGRESS_HOST"
    echo ""
    
    # Check if host is in /etc/hosts
    if grep -q "$INGRESS_HOST" /etc/hosts 2>/dev/null; then
        echo "✅ Host entry found in /etc/hosts"
        echo ""
        read -p "Test the endpoint? (y/N): " test_endpoint
        if [[ $test_endpoint == "y" || $test_endpoint == "Y" ]]; then
            echo "Testing http://$INGRESS_HOST ..."
            curl -s "http://$INGRESS_HOST" || echo "❌ Request failed"
        fi
    else
        echo "⚠️  Add this to /etc/hosts to access the application:"
        echo "   sudo bash -c 'echo \"$MINIKUBE_IP   $INGRESS_HOST\" >> /etc/hosts'"
    fi
else
    echo "⚠️  No ingress configured. Using port-forward for testing..."
    SERVICE_NAME=$(kubectl get svc -n "$NAMESPACE" \
        -l "app.kubernetes.io/instance=$RELEASE_NAME-$ENVIRONMENT" \
        -o jsonpath="{.items[0].metadata.name}")
    
    read -p "Start port-forward to localhost:8080? (y/N): " port_forward
    if [[ $port_forward == "y" || $port_forward == "Y" ]]; then
        echo "Starting port-forward... Access at http://localhost:8080"
        echo "Press Ctrl+C to stop"
        kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE_NAME" 8080:80
    fi
fi

echo ""

# Step 9: Show useful commands
echo "=============================="
echo "📚 [Step 9] Useful commands"
echo "=============================="
echo ""
echo "View Helm release values:"
echo "  helm get values $RELEASE_NAME-$ENVIRONMENT -n $NAMESPACE"
echo ""
echo "View release manifest:"
echo "  helm get manifest $RELEASE_NAME-$ENVIRONMENT -n $NAMESPACE"
echo ""
echo "View release history:"
echo "  helm history $RELEASE_NAME-$ENVIRONMENT -n $NAMESPACE"
echo ""
echo "Rollback to previous version:"
echo "  helm rollback $RELEASE_NAME-$ENVIRONMENT -n $NAMESPACE"
echo ""
echo "View application logs:"
echo "  kubectl logs -f -n $NAMESPACE $POD_NAME"
echo ""
echo "Upgrade deployment:"
echo "  ./scripts/helm-deploy.sh $ENVIRONMENT"
echo ""
echo "Uninstall release:"
echo "  helm uninstall $RELEASE_NAME-$ENVIRONMENT -n $NAMESPACE"
echo ""

echo "=============================="
echo "✨ Deployment Complete!"
echo "=============================="