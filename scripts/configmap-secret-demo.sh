#!/usr/bin/env bash

set -e

YAML_PATH="k8s/configmap-secret.yml"

echo "=============================="
echo "🚀 [Step 1] use ConfigMap / Secret / Deployment / Service"
echo "=============================="
minikube kubectl -- apply -f "$YAML_PATH"

echo
echo "⏳ waiting Pod starting..."
# waited until un Pod READY
until minikube kubectl -- get pods -l app=demo-app | grep -q '1/1'; do
  sleep 2
done

POD=$(minikube kubectl -- get pods -l app=demo-app -o jsonpath="{.items[0].metadata.name}")

echo
echo "✅ Pod already starting：$POD"

echo
echo "=============================="
echo "🔍 [Step 2] verify env variables or secret"
echo "=============================="
minikube kubectl -- exec -it "$POD" -- sh -c 'echo "--- printenv | grep APP_ ---"; printenv | grep APP_ || true'
minikube kubectl -- exec -it "$POD" -- sh -c 'echo "--- printenv | grep USERNAME/PASSWORD ---"; printenv | grep -E "USERNAME|PASSWORD" || true'

echo
echo "=============================="
echo "📂 [Step 3] verify inside pods files"
echo "=============================="
minikube kubectl -- exec -it "$POD" -- sh -c 'echo "--- ls /etc/demo-config ---"; ls /etc/demo-config'
minikube kubectl -- exec -it "$POD" -- sh -c 'echo "--- cat /etc/demo-config/WELCOME_MESSAGE ---"; cat /etc/demo-config/WELCOME_MESSAGE'
minikube kubectl -- exec -it "$POD" -- sh -c 'echo "--- ls /etc/demo-secret ---"; ls /etc/demo-secret'
minikube kubectl -- exec -it "$POD" -- sh -c 'echo "--- cat /etc/demo-secret/USERNAME ---"; cat /etc/demo-secret/USERNAME'
minikube kubectl -- exec -it "$POD" -- sh -c 'echo "--- cat /etc/demo-secret/PASSWORD ---"; cat /etc/demo-secret/PASSWORD'

echo
read -p "🧹 Are you sure want to clear miniKube ？(y/N): " confirm
if [[ $confirm == "y" || $confirm == "Y" ]]; then
  echo "=============================="
  echo "🧹 [Step 4] Remove ConfigMap / Secret / Deployment / Service"
  echo "=============================="
  minikube kubectl -- delete -f "$YAML_PATH"
else
  echo "✅ Already verify, keep miniKube resource"
fi
