# Basic Instructions

aws eks update-kubeconfig --region eu-west-1 --name tud-eks-alex

helm install --values values.yaml consul hashicorp/consul --create-namespace --namespace consul

helm ls --all-namespaces

kubectl delete namespace consul

kubectl delete deployment --all --namespace=consul
kubectl delete deployment,serviceaccounts,intentions --all --namespace=default
