#!/usr/bin/env bash

set -e

echo "=============================="
echo "🔐 Sealed Secrets Demo Script"
echo "=============================="
echo ""

# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
    echo "❌ Error: kubeseal is not installed"
    echo "Please install it: brew install kubeseal"
    exit 1
fi

# Check if sealed-secrets controller is running
echo "🔍 Checking if Sealed Secrets controller is running..."
if ! kubectl -n kube-system get pods -l app.kubernetes.io/name=sealed-secrets 2>/dev/null | grep -q Running; then
    echo "❌ Sealed Secrets controller is not running!"
    echo ""
    echo "Install it with:"
    echo "  helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets"
    echo "  helm repo update"
    echo "  helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system"
    exit 1
fi
echo "✅ Sealed Secrets controller is running"
echo ""

# Step 1: Fetch the public certificate
echo "=============================="
echo "📜 [Step 1] Fetching public certificate from controller"
echo "=============================="
kubeseal --fetch-cert \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system > mycert.pem

echo "✅ Certificate saved to mycert.pem"
echo ""

# Step 2: Create a plaintext secret (don't apply it!)
echo "=============================="
echo "🔑 [Step 2] Creating plaintext secret (not applied to cluster)"
echo "=============================="

cat > mysecret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: demo-sealed-secret
  namespace: default
type: Opaque
stringData:
  USERNAME: admin
  PASSWORD: supersecretpassword123
  API_KEY: sk-1234567890abcdef
  DB_CONNECTION_STRING: postgresql://user:pass@localhost:5432/mydb
EOF

echo "✅ Plaintext secret created: mysecret.yaml"
cat mysecret.yaml
echo ""

# Step 3: Seal the secret
echo "=============================="
echo "🔒 [Step 3] Encrypting secret with Sealed Secrets"
echo "=============================="
kubeseal --format=yaml --cert=mycert.pem < mysecret.yaml > mysealedsecret.yaml

echo "✅ Sealed secret created: mysealedsecret.yaml"
echo ""
echo "📝 Sealed secret content (safe to commit to git):"
echo "---"
cat mysealedsecret.yaml
echo "---"
echo ""

# Step 4: Apply the sealed secret
echo "=============================="
echo "📤 [Step 4] Applying sealed secret to cluster"
echo "=============================="
kubectl apply -f mysealedsecret.yaml

echo "⏳ Waiting for secret to be decrypted..."
sleep 3

# Verify the secret was created
if kubectl get secret demo-sealed-secret &> /dev/null; then
    echo "✅ Secret 'demo-sealed-secret' successfully created and decrypted!"
else
    echo "❌ Secret was not created. Check controller logs:"
    echo "   kubectl -n kube-system logs -l app.kubernetes.io/name=sealed-secrets"
    exit 1
fi
echo ""

# Step 5: Verify the decrypted secret
echo "=============================="
echo "🔍 [Step 5] Verifying decrypted secret values"
echo "=============================="
echo ""
echo "USERNAME: $(kubectl get secret demo-sealed-secret -o jsonpath='{.data.USERNAME}' | base64 -d)"
echo "PASSWORD: $(kubectl get secret demo-sealed-secret -o jsonpath='{.data.PASSWORD}' | base64 -d)"
echo "API_KEY: $(kubectl get secret demo-sealed-secret -o jsonpath='{.data.API_KEY}' | base64 -d)"
echo "DB_CONNECTION_STRING: $(kubectl get secret demo-sealed-secret -o jsonpath='{.data.DB_CONNECTION_STRING}' | base64 -d)"
echo ""

# Step 6: Show how to use in a pod
echo "=============================="
echo "📚 [Step 6] Example: Using secret in a pod"
echo "=============================="

cat > test-pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secret-test-pod
  namespace: default
spec:
  containers:
  - name: test
    image: busybox
    command: ['sh', '-c', 'echo "USERNAME=\$USERNAME"; echo "PASSWORD=\$PASSWORD"; sleep 3600']
    env:
    - name: USERNAME
      valueFrom:
        secretKeyRef:
          name: demo-sealed-secret
          key: USERNAME
    - name: PASSWORD
      valueFrom:
        secretKeyRef:
          name: demo-sealed-secret
          key: PASSWORD
EOF

echo "✅ Test pod manifest created: test-pod.yaml"
echo ""

read -p "🚀 Deploy test pod to verify secret injection? (y/N): " deploy_pod
if [[ $deploy_pod == "y" || $deploy_pod == "Y" ]]; then
    echo "Deploying test pod..."
    kubectl apply -f test-pod.yaml
    
    echo "⏳ Waiting for pod to start..."
    kubectl wait --for=condition=ready pod/secret-test-pod --timeout=60s
    
    echo ""
    echo "📋 Pod logs (showing injected secrets):"
    kubectl logs secret-test-pod
    echo ""
fi

# Step 7: Cleanup
echo "=============================="
echo "🧹 [Step 7] Cleanup"
echo "=============================="
echo ""
read -p "🗑️  Delete sealed secret and test resources? (y/N): " cleanup
if [[ $cleanup == "y" || $cleanup == "Y" ]]; then
    echo "Cleaning up..."
    kubectl delete -f mysealedsecret.yaml --ignore-not-found=true
    kubectl delete -f test-pod.yaml --ignore-not-found=true
    rm -f mysecret.yaml mysealedsecret.yaml test-pod.yaml mycert.pem
    echo "✅ Cleanup complete!"
else
    echo "⚠️  Remember to manually delete plaintext files:"
    echo "   rm mysecret.yaml mycert.pem"
    echo ""
    echo "📝 Keep these files safe (or commit to git):"
    echo "   - mysealedsecret.yaml (safe - encrypted)"
    echo "   - test-pod.yaml (example usage)"
fi

echo ""
echo "=============================="
echo "✨ Demo Complete!"
echo "=============================="
echo ""
echo "📚 Next steps:"
echo "1. Use 'mysealedsecret.yaml' in your Helm chart templates"
echo "2. Store sealed secrets in git (they're encrypted!)"
echo "3. Never commit 'mysecret.yaml' - always seal secrets first"
echo ""
