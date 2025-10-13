#!/usr/bin/env bash

set -e

HELM_CHART_DIR="fastapi-chart"
SECRET_NAME="${1:-fastapi-app-secret}"
ENVIRONMENT="${2:-dev}"

echo "=============================="
echo "🔐 Create Sealed Secret for Helm"
echo "=============================="
echo "Secret Name: $SECRET_NAME"
echo "Environment: $ENVIRONMENT"
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

# Step 1: Collect secret data interactively
echo "=============================="
echo "🔑 [Step 1] Enter your secret values"
echo "=============================="
echo "⚠️  These values will be encrypted. You can leave fields empty to skip."
echo ""

read -p "Database Username (default: admin): " DB_USERNAME
DB_USERNAME=${DB_USERNAME:-admin}

read -sp "Database Password (default: password123): " DB_PASSWORD
echo ""
DB_PASSWORD=${DB_PASSWORD:-password123}

read -sp "API Key (default: sk-test-key): " API_KEY
echo ""
API_KEY=${API_KEY:-sk-test-key}

read -p "Database Host (default: postgres): " DB_HOST
DB_HOST=${DB_HOST:-postgres}

read -p "Database Port (default: 5432): " DB_PORT
DB_PORT=${DB_PORT:-5432}

read -p "Database Name (default: myapp): " DB_NAME
DB_NAME=${DB_NAME:-myapp}

# Construct connection string
DB_CONNECTION_STRING="postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

echo ""
echo "✅ Secret values collected"
echo ""

# Step 2: Create plaintext secret
echo "=============================="
echo "📄 [Step 2] Creating plaintext secret manifest"
echo "=============================="

cat > .secret-plaintext.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: default
type: Opaque
stringData:
  DB_USERNAME: "${DB_USERNAME}"
  DB_PASSWORD: "${DB_PASSWORD}"
  DB_HOST: "${DB_HOST}"
  DB_PORT: "${DB_PORT}"
  DB_NAME: "${DB_NAME}"
  DB_CONNECTION_STRING: "${DB_CONNECTION_STRING}"
  API_KEY: "${API_KEY}"
EOF

echo "✅ Plaintext secret created: .secret-plaintext.yaml"
echo "⚠️  This file contains sensitive data and will be deleted after encryption"
echo ""

# Step 3: Fetch certificate
echo "=============================="
echo "📜 [Step 3] Fetching public certificate"
echo "=============================="

kubeseal --fetch-cert \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system > .sealed-secrets-cert.pem

echo "✅ Certificate saved"
echo ""

# Step 4: Encrypt the secret
echo "=============================="
echo "🔒 [Step 4] Encrypting secret"
echo "=============================="

kubeseal --format=yaml \
  --cert=.sealed-secrets-cert.pem \
  < .secret-plaintext.yaml \
  > "${HELM_CHART_DIR}/templates/sealedsecret-${ENVIRONMENT}.yaml"

echo "✅ Sealed secret created: ${HELM_CHART_DIR}/templates/sealedsecret-${ENVIRONMENT}.yaml"
echo ""

# Step 5: Show preview
echo "=============================="
echo "📋 [Step 5] Preview sealed secret"
echo "=============================="
echo ""
head -20 "${HELM_CHART_DIR}/templates/sealedsecret-${ENVIRONMENT}.yaml"
echo "..."
echo ""

# Step 6: Apply to cluster for testing
echo "=============================="
echo "🧪 [Step 6] Test deployment"
echo "=============================="
read -p "Apply sealed secret to cluster for testing? (y/N): " apply_test
if [[ $apply_test == "y" || $apply_test == "Y" ]]; then
    kubectl apply -f "${HELM_CHART_DIR}/templates/sealedsecret-${ENVIRONMENT}.yaml"
    
    echo "⏳ Waiting for decryption..."
    sleep 3
    
    if kubectl get secret "${SECRET_NAME}" &> /dev/null; then
        echo "✅ Secret successfully decrypted!"
        echo ""
        echo "Verify values:"
        echo "DB_USERNAME: $(kubectl get secret ${SECRET_NAME} -o jsonpath='{.data.DB_USERNAME}' | base64 -d)"
        echo "DB_HOST: $(kubectl get secret ${SECRET_NAME} -o jsonpath='{.data.DB_HOST}' | base64 -d)"
        echo "DB_PORT: $(kubectl get secret ${SECRET_NAME} -o jsonpath='{.data.DB_PORT}' | base64 -d)"
        echo "DB_NAME: $(kubectl get secret ${SECRET_NAME} -o jsonpath='{.data.DB_NAME}' | base64 -d)"
    else
        echo "❌ Secret decryption failed"
        exit 1
    fi
fi

echo ""

# Step 7: Update values file
echo "=============================="
echo "📝 [Step 7] Update Helm values"
echo "=============================="

VALUES_FILE="${HELM_CHART_DIR}/values.${ENVIRONMENT}.yaml"
if [ -f "$VALUES_FILE" ]; then
    echo ""
    echo "Add this to your $VALUES_FILE:"
    echo ""
    cat <<EOF
# Sealed Secrets Configuration
sealedSecrets:
  enabled: true
  secretName: ${SECRET_NAME}

# Use in deployment like this:
# env:
#   - name: DB_USERNAME
#     valueFrom:
#       secretKeyRef:
#         name: ${SECRET_NAME}
#         key: DB_USERNAME
#   - name: DB_PASSWORD
#     valueFrom:
#       secretKeyRef:
#         name: ${SECRET_NAME}
#         key: DB_PASSWORD
EOF
    echo ""
fi

# Step 8: Cleanup plaintext files
echo "=============================="
echo "🧹 [Step 8] Cleanup sensitive files"
echo "=============================="

echo "Removing plaintext files..."
rm -f .secret-plaintext.yaml .sealed-secrets-cert.pem
echo "✅ Sensitive files removed"
echo ""

# Step 9: Git instructions
echo "=============================="
echo "✨ Complete!"
echo "=============================="
echo ""
echo "📋 What was created:"
echo "  ✅ ${HELM_CHART_DIR}/templates/sealedsecret-${ENVIRONMENT}.yaml (encrypted, safe to commit)"
echo ""
echo "📚 Next steps:"
echo ""
echo "1. Commit the sealed secret to git:"
echo "   git add ${HELM_CHART_DIR}/templates/sealedsecret-${ENVIRONMENT}.yaml"
echo "   git commit -m 'Add sealed secret for ${ENVIRONMENT}'"
echo ""
echo "2. Update your deployment to use the secret:"
echo "   Edit ${HELM_CHART_DIR}/templates/deployment.yaml"
echo "   Add environment variables referencing the secret"
echo ""
echo "3. Deploy with Helm:"
echo "   ./scripts/helm-deploy.sh ${ENVIRONMENT}"
echo ""
echo "4. To recreate/update the secret:"
echo "   ./scripts/create-sealed-secret.sh ${SECRET_NAME} ${ENVIRONMENT}"
echo ""
echo "⚠️  Important:"
echo "  - The sealed secret is environment-specific (tied to this cluster)"
echo "  - For a new cluster, regenerate sealed secrets"
echo "  - Never commit .secret-plaintext.yaml (already deleted)"
echo ""