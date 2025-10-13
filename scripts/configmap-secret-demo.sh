#!/usr/bin/env bash

set -e

YAML_PATH="k8s/configmap-secret.yml"

echo "=============================="
echo "📦 Plain Kubernetes Manifests Demo"
echo "=============================="
echo "⚠️  Note: This uses plain ConfigMap/Secret (not Helm or Sealed Secrets)"
echo "For Helm + Sealed Secrets, use: ./scripts/helm-deploy.sh"
echo ""

# Check if manifest exists
if [ ! -f "$YAML_PATH" ]; then
    echo "❌ Error: Manifest file not found at $YAML_PATH"
    exit 1
fi

echo "=============================="
echo "🚀 [Step 1] Apply ConfigMap / Secret / Deployment / Service"
echo "=============================="
kubectl apply -f "$YAML_PATH"

echo ""
echo "⏳ Waiting for Pod to start..."
# Wait until a Pod is READY
until kubectl get pods -l app=demo-app | grep -q '1/1'; do
    sleep 2
done

POD=$(kubectl get pods -l app=demo-app -o jsonpath="{.items[0].metadata.name}")

echo ""
echo "✅ Pod is now running: $POD"

echo ""
echo "=============================="
echo "🔍 [Step 2] Verify environment variables from ConfigMap/Secret"
echo "=============================="
kubectl exec -it "$POD" -- sh -c 'echo "--- printenv | grep APP_ ---"; printenv | grep APP_ || true'
kubectl exec -it "$POD" -- sh -c 'echo "--- printenv | grep USERNAME/PASSWORD ---"; printenv | grep -E "USERNAME|PASSWORD" || true'

echo ""
echo "=============================="
echo "📂 [Step 3] Verify mounted files from ConfigMap/Secret"
echo "=============================="
echo ""
echo "--- ConfigMap mounted at /etc/demo-config ---"
kubectl exec -it "$POD" -- sh -c 'ls -la /etc/demo-config'
echo ""
kubectl exec -it "$POD" -- sh -c 'echo "Content of WELCOME_MESSAGE:"; cat /etc/demo-config/WELCOME_MESSAGE'

echo ""
echo "--- Secret mounted at /etc/demo-secret ---"
kubectl exec -it "$POD" -- sh -c 'ls -la /etc/demo-secret'
echo ""
kubectl exec -it "$POD" -- sh -c 'echo "Content of USERNAME:"; cat /etc/demo-secret/USERNAME'
kubectl exec -it "$POD" -- sh -c 'echo "Content of PASSWORD:"; cat /etc/demo-secret/PASSWORD'

echo ""
echo "=============================="
echo "📋 [Step 4] Show all resources"
echo "=============================="
echo ""
echo "ConfigMaps:"
kubectl get configmaps -l app=demo-app
echo ""
echo "Secrets:"
kubectl get secrets -l app=demo-app
echo ""
echo "Pods:"
kubectl get pods -l app=demo-app
echo ""
echo "Services:"
kubectl get svc -l app=demo-app

echo ""
read -p "🧹 Do you want to clean up resources? (y/N): " confirm
if [[ $confirm == "y" || $confirm == "Y" ]]; then
    echo "=============================="
    echo "🧹 [Step 5] Removing all resources"
    echo "=============================="
    kubectl delete -f "$YAML_PATH"
    echo "✅ Resources deleted"
else
    echo "✅ Resources kept. Clean up manually with:"
    echo "   kubectl delete -f $YAML_PATH"
fi

echo ""
echo "=============================="
echo "✨ Demo Complete!"
echo "=============================="
echo ""
echo "💡 Next steps:"
echo "1. For production, use Helm + Sealed Secrets:"
echo "   ./scripts/sealed-secret-demo.sh     # Create sealed secrets"
echo "   ./scripts/helm-deploy.sh dev        # Deploy with Helm"
echo ""
echo "2. Never commit plain secrets to git!"
echo "   Use Sealed Secrets to encrypt them first"
echo ""