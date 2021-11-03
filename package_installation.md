##  Deployment of a shared services cluster

After deploying the management cluster, it is time to deploy the shared-services cluster, which is where the Tanzu packages will be deployed into. By deploying services into the
[shared services cluster](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-extensions-index.html#shared), said services will be able to serve to other services.

Create a cluster and change to its context:
```bash
tanzu cluster create --file ~/.config/tanzu/tkg/clusterconfigs/tkg_services_cluster_config.yaml --verbose 8
```

Switch to the management cluster's context and add the "tanzu-services" label to the shared services cluster as its role.
```bash
kubectl config use-context mgmt-admin@mgmt
kubectl label cluster.cluster.x-k8s.io/tkg-services cluster-role.tkg.tanzu.vmware.com/tanzu-services="" --overwrite=true
tanzu cluster list --include-management-cluster
```

Get credentials for tkg-services cluster:
```bash
tanzu cluster kubeconfig get tkg-services --admin
kubectl config use-context tkg-services-admin@tkg-services
```

### Installing the packages

1. Create a directory wehere we will store all the config files for each package
 ```bash
mkdir ~/tanzu/package_values
cd ~/tanzu/package_values
```

#### Install cert-manager

Install cert-manager on the tkg-services cluster:

1. Extract cert's manager latest available version from the newly added repository
 ```bash
cert_manager_version=`tanzu package available list cert-manager.community.tanzu.vmware.com -A -o json | jq .[-1].version`
cert_manager_version=`sed -e 's/^"//' -e 's/"$//' <<<$cert_manager_version`
```

2. Install cert-manager
```bash
tanzu package install cert-manager --package-name cert-manager.community.tanzu.vmware.com --version $cert_manager_version -n cert-manager --create-namespace
```

#### Install contour

![alt text](SDDC-Deployment/images/contour.svg)

1. Extract contour's latest available version
```bash
contour_version=`tanzu package available list contour.community.tanzu.vmware.com -A -o json | jq .[-1].version`
contour_version=`sed -e 's/^"//' -e 's/"$//' <<<$contour_version`
```

2. Download a template config file for contour's deployment
```bash
image_url=$(kubectl -n tanzu-package-repo-global get packages contour.community.tanzu.vmware.com.$contour_version -o jsonpath='{.spec.template.spec.fetch[0].imgpkgBundle.image}')
imgpkg pull -b $image_url -o /tmp/contour-package-$contour_version
cp /tmp/contour-package-$contour_version/config/values.yaml contour-data-values.yaml

# REMOVE ALL COMMENT FROM THE DATA VALUES FILE
yq -i eval '... comments=""' contour-data-values.yaml
```
3. Since we are deploying without a load balancer, we need to change the service type from LoadBalancer to ClusterIP, and enable host ports.
```bash
sed -i 's/LoadBalancer/ClusterIP/' contour-data-values.yaml
yq e -i '.envoy.hostPorts.enable= "true"' contour-data-values.yaml
```

4. Deploy contour
```bash
tanzu package install contour \
--package-name contour.community.tanzu.vmware.com \
--version $contour_version \
--namespace projectcontour --create-namespace \
--values-file contour-data-values.yaml
```

5. Check that the deployment was successful by running (if the deployment was successful, the description of the app will be "Reconcile succeded")
```bash
kubectl get app contour -n tanzu-system-ingress
```

#### Install harbor

![alt text](SDDC-Deployment/images/harbor.png)

1. Extract harbor's latest available version
```bash
harbor_version=`tanzu package available list harbor.community.tanzu.vmware.com -A -o json | jq .[-1].version`
harbor_version=`sed -e 's/^"//' -e 's/"$//' <<<$harbor_version`
```

2. Retrieve the template for the Harbor Package
```bash
image_url=$(kubectl -n tanzu-package-repo-global get packages harbor.community.tanzu.vmware.com.$harbor_version -o jsonpath='{.spec.template.spec.fetch[0].imgpkgBundle.image}')
imgpkg pull -b $image_url -o /tmp/harbor-package-$harbor_version
cp /tmp/harbor-package-$harbor_version/config/values.yaml harbor-data-values.yaml
```

3. Generate and set mandatory passwords, and delete comments from the yaml file
```bash
bash /tmp/harbor-package-$harbor_version/config/scripts/generate-passwords.sh harbor-data-values.yaml
yq -i eval '... comments=""' harbor-data-values.yaml
```
4. Deploy harbor
```bash
tanzu package install harbor \
--package-name harbor.community.tanzu.vmware.com \
--version $harbor_version \
--values-file harbor-data-values.yaml \
--namespace harbor --create-namespace
```

5. Check the that the deployment was successful by running (The description must be "Reconcile succeeded")
```bash
kubectl get app harbor -n tanzu-system-registry
```

6. Obtain the Harbor CA certificate
```bash
kubectl -n harbor get secret harbor-tls -o=jsonpath="{.data.ca\.crt}" | base64 -d
```

7. Store the Harbor CA certificate
```bash
mkdir /etc/docker/certs.d
mkdir /etc/docker/certs.d/harbor.yourdomain.com
sudo chmod +777 harbor.yourdomain.com/
kubectl -n harbor get secret harbor-tls -o=jsonpath="{.data.ca\.crt}" | base64 -d > /etc/docker/certs.d/harbor.yourdomain.com/ca.crt
```


#### Install prometheus


![alt text](SDDC-Deployment/images/prometheus.png)

1. Extract prometheus' latest available version
```bash
prometheus_version=`tanzu package available list prometheus.community.tanzu.vmware.com -A -o json | jq .[0].version`
prometheus_version=`sed -e 's/^"//' -e 's/"$//' <<<$prometheus_version`
```

2. Retrieve the template for the Prometheus Package
```bash
image_url=$(kubectl -n tanzu-package-repo-global get packages prometheus.community.tanzu.vmware.com.$prometheus_version -o jsonpath='{.spec.template.spec.fetch[0].imgpkgBundle.image}')
imgpkg pull -b $image_url -o /tmp/prometheus-package-$prometheus_version
cp /tmp/prometheus-package-$prometheus_version/config/values.yaml prometheus-data-values.yaml
```

3. Delete comments from the yaml file
```bash
yq -i eval '... comments=""' prometheus-data-values.yaml
```

4. Enable ingress
```bash
    cat <<EOF >> prometheus-data-values.yaml
ingress:
  enabled: true
  virtual_host_fqdn: "prometheus.yourdomain.com"
  prometheus_prefix: "/"
  alertmanager_prefix: "/alertmanager/"
  prometheusServicePort: 80
  alertmanagerServicePort: 80
  #! [Optional] The certificate for the ingress if you want to use your own TLS certificate.
  #! We will issue the certificate by cert-manager when it's empty.
  tlsCertificate:
    #! [Required] the certificate
    tls.crt:
    #! [Required] the private key
    tls.key:
    #! [Optional] the CA certificate
    ca.crt:
EOF
```

5. Install prometheus
```bash
tanzu package install prometheus \
--package-name prometheus.community.tanzu.vmware.com \
--version $prometheus_version \
--values-file prometheus-data-values.yaml \
--namespace prometheus --create-namespace
```


After a few minutes, you will be able to access prometheus on prometheus.yourdomain.com (provided you added an entry to your hosts file)
#### Install grafana

![alt text](SDDC-Deployment/images/grafana.png)

1. Extract Grafana's latest available version
```bash
grafana_version=`tanzu package available list grafana.community.tanzu.vmware.com -A -o json | jq .[-1].version`
grafana_version=`sed -e 's/^"//' -e 's/"$//' <<<$grafana_version`
```

2. Retrieve the template for the Grafana Package
```bash
image_url=$(kubectl -n tanzu-package-repo-global get packages grafana.community.tanzu.vmware.com.$grafana_version -o jsonpath='{.spec.template.spec.fetch[0].imgpkgBundle.image}')
imgpkg pull -b $image_url -o /tmp/grafana-package-$grafana_version
cp /tmp/grafana-package-$grafana_version/config/values.yaml grafana-data-values.yaml
```

3. Delete comments from the yaml file
```bash
yq -i eval '... comments=""' grafana-data-values.yaml
```

4. Choose a password, base64 encrypt it and set it into the data-values file. Additionally, edit the service type and change the FQDN (if desired)
```bash
# SET A PASSWORD
grafana_password=`echo "mypassword" | base64`
# FILL IN THE ADMIN_PASSWORD FIELD IN THE YAML FILE
yq e -i ".grafana.secret.admin_password = \"$grafana_password\""  grafana-data-values.yaml

# FILL IN THE FQDN YOU WANT TO ASSIGN TO YOUR GRAFANA DEPLOYMENT
yq e -i ".ingress.virtual_host_fqdn = \"grafana.yourdomain.com\""  grafana-data-values.yaml

# CHANGE THE SERVICE TYPE TO CLUSTERIP
yq e -i '.grafana.service.type = "ClusterIP"'  grafana-data-values.yaml
```

5. Install grafana
```bash
tanzu package install grafana \
--package-name grafana.community.tanzu.vmware.com \
--version $grafana_version \
--values-file grafana-data-values.yaml \
--namespace grafana --create-namespace
```
