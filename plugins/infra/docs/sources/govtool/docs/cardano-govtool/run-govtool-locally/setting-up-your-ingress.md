# Setting up Your Ingress

## Prerequisites

To expose your Minikube cluster and test your deployment of the services works as expected you will need to ensure that you have the Minikube ingress service enabled so you can access via the tunnel command. If issues occur using the default NodePort a patch can be applied to use either a LoadBalancer or ClusterIP using the following command

`kubectl patch svc ingress-nginx-controller -n ingress-nginx -p '{"spec": {"type": "<LoadBalancer/ClusterIP>"}}'`

## Setting up Your Ingress

If planning to run everything via localhost as is currently done in the example ingress provided there are some additional considerations required:

1. Edit your /etc/hosts file to ensure that your localhost (127.0.0.1) can resolve to the domains you plan to use e.g. be.localhost, md.localhost, oc.localhost, pdf.localhost
2. Install a root CA for you system to avoid any network certificate errors as the different services attempt to communicate with each other and create a tls certificate and key file for use with the cluster (the example ingress expects a TLS secret named `govtool-tls`)
3. The name space you will deploy your ingress service to (testing on multiple different Minikube images has proven that the default namespace is not suitable to deploy the ingress and so may lead to issues). The example `ingress.yaml` does not set a namespace, so apply it with `kubectl apply -n govtool -f ingress.yaml` (the other manifests use the `govtool` namespace)
4. Make any desired modifications for the services and domains you wish to test with
5. Use `kubectl apply` to start your ingress service
