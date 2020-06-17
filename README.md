# go-with-prow
This is a sample repository with some Go code, that explains how repository can be linked to local prow instance

## Preconditions

Installations:

- [docker](https://docs.docker.com/get-docker/)
- [minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Ultrahook](http://www.ultrahook.com/register) 

Tokens that should be added in `/prow/tokens` folder:
 - Bot token for dedicated GitHub [account](https://github.com/kubernetes/test-infra/blob/master/prow/getting_started_deploy.md#github-bot-account) from [here](https://github.com/settings/tokens)
 - HMAC Token - needed for [securig your webhooks](https://developer.github.com/webhooks/securing/). In general it is a random generated alphanumeric string. For example it can be created with the following command:
    ```
    openssl rand -hex 20
    ```
- kubeconfig - needed for configuration updates. See [here](http://docs.shippable.com/deploy/tutorial/create-kubeconfig-for-self-hosted-kubernetes-cluster/) how can create one. If not provided, on each configuration change you should manualy reload the configuration (scale down/up resources). In this example it is not provided
- slack - needed to report status to slack. See [here for details](https://github.com/kubernetes/test-infra/tree/master/prow/crier#slack-reporter) how to create it


## Deployment steps
### Navigate to prow folder
```
cd prow
```
### Create mnikube cluster
```
minikube start --memory 4096 --cpus 4 --profile prow-cluster
```
### Deploy prow
```
./deploy-prow.sh
```
### Start ultrahook
For ultrahook command, we need to use the IP address of the cluster and the port of the **hook** service on thie cluser.

To get minikube cluster IP address:
```
minikube profile list
```
The result look like:
```
|------------------|-----------|---------|---------------|------|---------|---------|
|     Profile      | VM Driver | Runtime |      IP       | Port | Version | Status  |
|------------------|-----------|---------|---------------|------|---------|---------|
| prow-cluster     | hyperkit  | docker  | 192.168.64.64 | 8443 | v1.18.3 | Running |
|------------------|-----------|---------|---------------|------|---------|---------|
```
To get the **hook** service port:
```
kubectl get svc hook
```
The result look like:
```
NAME   TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)          AGE
hook   NodePort   10.98.64.31   <none>        8888:31632/TCP   99m
```
Get the IP address for **prow-cluser** and the port from **hook** service to start the ultrahook:
```
ultrahook <repository name> http://192.168.64.64:31632/hook
```
### Add hook to GitHub repository
Add a webhook to your repository at address `https://github.com/<organization>/<repository name>/settings/hooks`
- Payload URL: `http://<repository name>.<ultrahook account name>.ultrahook.com`
- Content type: `application/json`
- Secret: `<HMAC token>`
- Which events would you like to trigger this webhook? - `Send me everything.`
- Achive - `checked`

### Prepare the configuration
Get the deck service port:
```
kubectl get svc deck
```
The result look like this:
```
NAME   TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
deck   NodePort   10.100.25.206   <none>        80:32320/TCP   104m
```
Inside config.yaml file updaet address and port:
```
  job_url_prefix_config:
    ‘*’: http://192.168.64.64:32320/
  job_url_template: http://192.168.64.64:32320/log?job={{.Spec.Job}}&id={{.Status.BuildID}}’
```
The **deck** of prow can be accessed on the address `http://<cluster IP>:<deck service port>/`. 

In this example the adress for **deck** is: `http://192.168.64.64:32320/`

### Apply the configuration
Jobs and plugins configurations now can be applied. Execute the follwoing 2 commands:
```
./update-configs.sh
```
and
```
./update-plugins.sh
```

It is Done!

The integration should be up and running. You may try it by creating a PR in your repository

## Configurations
- Jobs configuration `config.yaml` define jobs that shall be registered in prow
- Plugins configuration `plugins.yaml` describe enabled plugins in prow 


## Acknowledgements
I use several online resources to assemble this. Special thanks to those organizations and people for sharing their knowlege and resources:
- Hemani Katyal speak at [DevConf India 2018](https://devconfin2018.sched.com/event/F73Y/the-prowess-of-prow-in-kubernetes)
- Shippable.com article [Creating a kubeconfig file for a self-hosted Kubernetes cluster](http://docs.shippable.com/deploy/tutorial/create-kubeconfig-for-self-hosted-kubernetes-cluster/)
- Prow community detailed [documentation](https://github.com/kubernetes/test-infra/blob/master/prow/README.md)
- Vinay Sahni the creator of [ultrahook tool](http://www.ultrahook.com)
