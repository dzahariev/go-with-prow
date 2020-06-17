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

## Addition
The multistage Dockerfile example shows how to execute unit tests for different packages in parallel with the new [BuildKit](https://docs.docker.com/develop/develop-images/build_enhancements/) engine. 
Execution steps are:
 - Stage: `build` - execute build to ensure that binary can be prodiced from sources
 - Stage: `test-prepare` - prepares the tests environment by fetching all required go libraries in separate layer
 - Stage: `test-main`, `test-pckg01`, `test-pckg02` - execute the tests for each one of the packages
 - Stage: `join` - joins the build results by copying a dummy files that were created as result of each test stage
 - Stage: `release` - prepare image from scratch that contain only binary file that was produced from `build` stage.

To start the tests with BuildKit enabled:
```
DOCKER_BUILDKIT=1 docker build . --no-cache
```
Result shows the steps:
```
[+] Building 17.0s (22/22) FINISHED                                                                                 
 => [internal] load .dockerignore                                                                              0.0s
 => => transferring context: 2B                                                                                0.0s
 => [internal] load build definition from Dockerfile                                                           0.0s
 => => transferring dockerfile: 37B                                                                            0.0s
 => [internal] load metadata for docker.io/library/golang:alpine                                               0.0s
 => [internal] load build context                                                                              0.0s
 => => transferring context: 18.79kB                                                                           0.0s
 => CACHED [release 1/2] WORKDIR /bin                                                                          0.0s
 => [build 1/4] FROM docker.io/library/golang:alpine                                                           0.0s
 => CACHED [build 2/4] WORKDIR /go/src/github.com/dzahariev/go-with-prow/                                      0.0s
 => [build 3/4] COPY . ./                                                                                      0.0s
 => [build 4/4] RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -ldflags "$(build/ld  2.8s
 => [test-prepare 1/1] RUN CGO_ENABLED=0 go test -i ./...                                                      5.8s
 => [test-main 1/2] RUN CGO_ENABLED=0 go test . -ginkgo.noColor -v                                             7.3s
 => [test-pckg02 1/2] RUN CGO_ENABLED=0 go test ./pkg02 -ginkgo.noColor -v                                     7.6s
 => [test-pckg01 1/2] RUN CGO_ENABLED=0 go test ./pkg01 -ginkgo.noColor -v                                     7.6s
 => [test-main 2/2] RUN touch finished.test-main                                                               0.3s 
 => [test-pckg02 2/2] RUN touch finished.test-pckg02                                                           0.4s 
 => [join 1/4] COPY --from=test-main /go/src/github.com/dzahariev/go-with-prow/finished.test-main /test-resul  0.0s 
 => [test-pckg01 2/2] RUN touch finished.test-pckg01                                                           0.4s
 => [join 2/4] COPY --from=test-pckg01 /go/src/github.com/dzahariev/go-with-prow/finished.test-pckg01 /test-r  0.0s 
 => [join 3/4] COPY --from=test-pckg02 /go/src/github.com/dzahariev/go-with-prow/finished.test-pckg02 /test-r  0.1s 
 => [join 4/4] COPY --from=build /app /app                                                                     0.0s 
 => [release 2/2] COPY --from=join /app /bin/.                                                                 0.0s
 => exporting to image                                                                                         0.0s
 => => exporting layers                                                                                        0.0s
 => => writing image sha256:6e3cdfbce50ac4dfd3da27e6713a1db951ac30589bc48041014fc47795fef6f6                   0.0s
```

In case tets are failing, the release image is not prodiced and build result look like this:
```
[+] Building 16.6s (14/21)                                                                                          
 => [internal] load build definition from Dockerfile                                                           0.0s
 => => transferring dockerfile: 37B                                                                            0.0s
 => [internal] load .dockerignore                                                                              0.0s
 => => transferring context: 2B                                                                                0.0s
 => [internal] load metadata for docker.io/library/golang:alpine                                               0.0s
 => [internal] load build context                                                                              0.0s
 => => transferring context: 17.90kB                                                                           0.0s
 => CACHED [release 1/2] WORKDIR /bin                                                                          0.0s
 => [build 1/4] FROM docker.io/library/golang:alpine                                                           0.0s
 => CACHED [build 2/4] WORKDIR /go/src/github.com/dzahariev/go-with-prow/                                      0.0s
 => [build 3/4] COPY . ./                                                                                      0.0s
 => [build 4/4] RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -ldflags "$(build/ld  2.7s
 => [test-prepare 1/1] RUN CGO_ENABLED=0 go test -i ./...                                                      5.9s
 => CANCELED [test-main 1/2] RUN CGO_ENABLED=0 go test . -ginkgo.noColor -v                                    7.6s
 => [test-pckg02 1/2] RUN CGO_ENABLED=0 go test ./pkg02 -ginkgo.noColor -v                                     7.6s
 => ERROR [test-pckg01 1/2] RUN CGO_ENABLED=0 go test ./pkg01 -ginkgo.noColor -v                               7.6s
 => [test-pckg02 2/2] RUN touch finished.test-pckg02                                                           0.2s 
------                                                                                                              
 > [test-pckg01 1/2] RUN CGO_ENABLED=0 go test ./pkg01 -ginkgo.noColor -v:                                          
#14 7.462 === RUN   TestPkg01Suite                                                                                  
#14 7.462 Running Suite: Pkg01 Suite                                                                                
#14 7.462 ==========================                                                                                
#14 7.462 Random Seed: 1592409908
#14 7.463 Will run 1 of 1 specs
#14 7.463 
#14 7.465 • Failure [0.001 seconds]
#14 7.465 helloPkg01 function
#14 7.466 /go/src/github.com/dzahariev/go-with-prow/pkg01/pkg01_test.go:20
#14 7.466   output
#14 7.466   /go/src/github.com/dzahariev/go-with-prow/pkg01/pkg01_test.go:21
#14 7.466     should be Hello from Pkg02! [It]
#14 7.466     /go/src/github.com/dzahariev/go-with-prow/pkg01/pkg01_test.go:22
#14 7.466 
#14 7.466     Expected
#14 7.466         <string>: Hello from Pkg01!
#14 7.466     to be identical to
#14 7.466         <string>: Hello from Pkg02!
#14 7.466 
#14 7.466     /go/src/github.com/dzahariev/go-with-prow/pkg01/pkg01_test.go:23
#14 7.466 ------------------------------
#14 7.466 
#14 7.466 
#14 7.467 Summarizing 1 Failure:
#14 7.467 
#14 7.467 [Fail] helloPkg01 function output [It] should be Hello from Pkg02! 
#14 7.467 /go/src/github.com/dzahariev/go-with-prow/pkg01/pkg01_test.go:23
#14 7.467 
#14 7.467 Ran 1 of 1 Specs in 0.004 seconds
#14 7.467 FAIL! -- 0 Passed | 1 Failed | 0 Pending | 0 Skipped
#14 7.467 --- FAIL: TestPkg01Suite (0.01s)
#14 7.467 FAIL
#14 7.469 FAIL	dzahariev/go-with-prow/pkg01	0.010s
#14 7.471 FAIL
------
failed to solve with frontend dockerfile.v0: failed to build LLB: executor failed running [/bin/sh -c CGO_ENABLED=0 go test ./pkg01 -ginkgo.noColor -v]: runc did not terminate sucessfully
```

## Acknowledgements
I use several online resources to assemble this. Special thanks to those organizations and people for sharing their knowlege and resources:
- Hemani Katyal speak at [DevConf India 2018](https://devconfin2018.sched.com/event/F73Y/the-prowess-of-prow-in-kubernetes)
- Shippable.com article [Creating a kubeconfig file for a self-hosted Kubernetes cluster](http://docs.shippable.com/deploy/tutorial/create-kubeconfig-for-self-hosted-kubernetes-cluster/)
- Prow community detailed [documentation](https://github.com/kubernetes/test-infra/blob/master/prow/README.md)
- Vinay Sahni the creator of [ultrahook tool](http://www.ultrahook.com)
