#!/usr/bin/env bash

set -e

echo "=============================="
echo "🧹 Cleanup Script"
echo "=============================="
echo ""

ENVIRONMENT="${1:-dev}"

echo "⚠️  This will remove:"
echo "  - Helm release: fastapi-$ENVIRONMENT"
echo "  - Plain manifests (if any)"
echo "  - Test pods and resources"
echo ""

read -p "Continue with cleanup? (y/N): " confirm
if [[ $confirm != "y" && $confirm != "Y" ]]; then
    echo "❌ Cleanup cancelled"
    exit 0
fi

echo ""
echo "=============================="
echo "🗑️  Removing Helm releases"
echo "=============================="

# Check if Helm release exists
if helm list | grep -q "fastapi-$ENVIRONMENT"; then
    echo "Uninstalling Helm release: fastapi-$ENVIRONMENT"
    helm uninstall "fastapi-$ENVIRONMENT" --namespace default
    echo "✅ Helm release removed"
else
    echo "ℹ️  No Helm release found for: fastapi-$ENVIRONMENT"
fi

echo ""
echo "=============================="
echo "🗑️  Removing plain manifests"
echo "=============================="

# Remove plain manifest deployments
if kubectl get deployment demo-app 2>/dev/null; then
    echo "Removing plain manifest resources..."
    kubectl delete -f k8s/configmap-secret.yml --ignore-not-found=true
    kubectl delete -f deployment.yml --ignore-not-found=true
    kubectl delete -f ingress.yml --ignore-not-found=true
    echo "✅ Plain manifests removed"
else
    echo "ℹ️  No plain manifest deployments found"
fi

echo ""
echo "=============================="
echo "🗑️  Removing test resources"
echo "=============================="

# Remove test resources
kubectl delete pod secret-test-pod --ignore-not-found=true
kubectl delete secret demo-sealed-secret --ignore-not-found=true
kubectl delete sealedsecret demo-sealed-secret --ignore-not-found=true

echo "✅ Test resources removed"

echo ""
echo "=============================="
echo "📋 Remaining resources"
echo "=============================="

echo ""
echo "Pods:"
kubectl get pods 2>/dev/null || echo "No pods found"

echo ""
echo "Services:"
kubectl get svc 2>/dev/null || echo "No services found"

echo ""
echo "Ingress:"
kubectl get ingress 2>/dev/null || echo "No ingress found"

echo ""
echo "Secrets:"
kubectl get secrets 2>/dev/null || echo "No secrets found"

echo ""
echo "=============================="
echo "⚠️  Additional cleanup options"
echo "=============================="
echo ""

read -p "Remove Sealed Secrets controller? (y/N): " remove_sealed
if [[ $remove_sealed == "y" || $remove_sealed == "Y" ]]; then
    helm uninstall sealed-secrets -n kube-system 2>/dev/null || echo "Sealed Secrets not installed via Helm"
    kubectl delete -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml --ignore-not-found=true
    echo "✅ Sealed Secrets controller removed"
fi

read -p "Disable Minikube ingress addon? (y/N): " disable_ingress
if [[ $disable_ingress == "y" || $disable_ingress == "Y" ]]; then
    minikube addons disable ingress
    echo "✅ Ingress addon disabled"
fi

read -p "🔥 Delete entire Minikube cluster? (y/N): " delete_cluster
if [[ $delete_cluster == "y" || $delete_cluster == "Y" ]]; then
    echo "🔥 Deleting Minikube cluster..."
    minikube delete
    echo "✅ Minikube cluster deleted"
    echo ""
    echo "To start fresh, run: minikube start --driver=docker"
else
    echo "✅ Minikube cluster preserved"
fi

echo ""
echo "=============================="
echo "✨ Cleanup Complete!"
echo "=============================="
echo ""
echo "💡 Remember to clean up temporary files:"
echo "   rm -f mysecret.yaml mysealedsecret.yaml mycert.pem test-pod.yaml"
echo ""