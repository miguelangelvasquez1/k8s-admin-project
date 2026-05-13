# 1. Namespace
kubectl apply -f namespaces/epm-namespace.yaml

# 2. ConfigMaps (todos desde config-files/)
kubectl create configmap hcm-init-sql --from-file=init.sql=./config-files/hcm-init.sql -n epm
kubectl create configmap cmdb-init-sql --from-file=init.sql=./config-files/cmdb-init.sql -n epm
kubectl create configmap erp-html-config --from-file=index.html=./config-files/erp-index.html -n epm
kubectl create configmap wazuh-rules --from-file=custom-rules.xml=./config-files/wazuh-rules.xml -n epm
kubectl create configmap ldap-seed --from-file=epm.ldif=./config-files/epm.ldif -n epm

# 3. Todo lo demás
kubectl apply -f ldap/
kubectl apply -f databases/
kubectl apply -f erp/
kubectl apply -f tools/
kubectl apply -f monitoring/wazuh-indexer-deployment.yaml

# 4. Esperar indexer antes de manager y dashboard
kubectl wait --for=condition=ready pod -l app=epm-wazuh-indexer -n epm --timeout=180s

kubectl apply -f monitoring/wazuh-manager-deployment.yaml
kubectl apply -f monitoring/wazuh-dashboard-deployment.yaml

# 5. Verificar todo
kubectl get all -n epm
kubectl get configmaps -n epm
kubectl get pvc -n epm
minikube service list -n epm

## Servicios corriendo:
minikube service epm-adminer-svc -n epm
minikube service epm-ldap-ui-svc -n epm
minikube service epm-wazuh-dashboard-svc -n epm

minikube dashboard