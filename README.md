# Cilium Cluster Mesh Workshop
Learn [Cilium](https://cilium.io/) and [Cilium Cluster Mesh](https://docs.cilium.io/en/stable/network/clustermesh/clustermesh/) by creating a Multi-cluster Kubernetes setup.   

## ✅ System requirements
> [!WARNING]
> For MacOS users it is recommended to use [colima](https://github.com/abiosoft/colima) instead of Docker Desktop. See https://github.com/cilium/cilium/issues/30278
* `colima` (optional for MacOS users) - [Installation instructions](https://github.com/abiosoft/colima?tab=readme-ov-file#installation)
* `docker` - [Installation instructions](https://docs.docker.com/engine/install)
* `kind` - [Installation instructions](https://kind.sigs.k8s.io/docs/user/quick-start)
* `kubectl` - [Installation instructions](https://kubernetes.io/docs/tasks/tools)
* `cilium-cli` - [Installation instructions](https://github.com/cilium/cilium-cli?tab=readme-ov-file#installation)

### Some notes on `colima` configuration
Ensure `inotify` setting are [correct](https://github.com/abiosoft/colima/issues/1000):
```sh
cp colima/override.yaml ~/.colima/_lima/_config
```
Start a virtual machine with 4 cpu and 8 Gb of RAM:
```sh
colima start --cpu 4 --memory 8
```

## ⚡️ Quick start
Prepare environment with just one command:
```bash
make all
```
This command can help you with:
* Create a setup of three Kubernetes clusters using `kind`;
* Install Cilium CNI in all three clusters using `cilium-cli`;
* Create Cluster Mesh between all three clusters;
* Install demo apps in all three clusters.
> [!TIP]
> Feel free to check out **Makefile**. It is self-explanatory 😉

## 📖 Play around with Cilium Cluster Mesh
### Scenario 1: Send http requests to `rebel-base` service from Cluster 1

We can observe that all requests are load balanced between Cluster 1 and Cluster 2.

```sh
kubectl --context kind-cluster1 exec -ti deployments/x-wing -- /bin/sh -c 'for i in $(seq 1 10); do curl rebel-base; done'
```
<details><summary><b>Output</b></summary>

```json
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
```
</details>

### Scenario 2: Send http requests to `rebel-base` service from Cluster 2

Similarly to scenario above all requests are load balanced between Cluster 2 and Cluster 1.
```sh
kubectl --context kind-cluster2 exec -ti deployments/x-wing -- /bin/sh -c 'for i in $(seq 1 10); do curl rebel-base; done'
```
<details><summary><b>Output</b></summary>

```json
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
```
</details>

### Scenario 3: Use local service affinity for Cluster 1
Set `service.cilium.io/affinity` annotation for `local`, the Global Service will load-balance across healthy local backends, and only use remote endpoints if all of local backends are not available or unhealthy.
```sh
kubectl --context kind-cluster1 annotate service rebel-base io.cilium/service-affinity=local --overwrite
```
Check the destination. As you can see the preferred endpoint destination is Cluster 1 (`local` endpoints).
```sh
kubectl --context kind-cluster1 exec -ti deployments/x-wing -- /bin/sh -c 'for i in $(seq 1 10); do curl rebel-base; done'
```
<details><summary><b>Output</b></summary>

```json
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
```
</details>

Remove `service.cilium.io/affinity` annotation.
```sh
kubectl --context kind-cluster1 annotate service rebel-base io.cilium/service-affinity-
```
You will see replies from pods in both clusters as usual.
```sh
kubectl --context kind-cluster1 exec -ti deployments/x-wing -- /bin/sh -c 'for i in $(seq 1 10); do curl rebel-base; done'
```
<details><summary><b>Output</b></summary>

```json
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
```

</details>

> [!IMPORTANT]
> Try to use `service.cilium.io/affinity` with `remote` configuration in Cluster 2 and observe the results.

> [!TIP]
> Documentation for Global Service Affinity - https://docs.cilium.io/en/latest/network/clustermesh/affinity/

### Scenario 4: Send http requests to `rebel-base` service from Cluster 3
That's the fun part. In Cluster 3 we don't have any deployments for `rebel-base`. But we can use global `rebel-base` service to reach pods in Cluster 1 and Cluster 2.

Let's try it out. We got responses from Cluster 1 and Cluster 2.

```sh
kubectl --context kind-cluster3 exec -ti deployments/x-wing -- /bin/sh -c 'for i in $(seq 1 10); do curl rebel-base; done'
```
<details><summary><b>Output</b></summary>

```json
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-1"}
```
</details>

> [!NOTE]
> [Feature proposal](https://github.com/cilium/cilium/issues/29200) for global service cluster affinity.

### Scenario 5: High Availability and Fault Tolerance
Let's try to make service temporarily unavailable in Cluster 1 and observe failover to Cluster 2.
```sh
kubectl --context kind-cluster1 scale deploy --replicas=0 rebel-base
```
Send some http requests to `rebel-base` in Cluster 1, see failover in action.
```sh
kubectl --context kind-cluster1 exec -ti deployments/x-wing -- /bin/sh -c 'for i in $(seq 1 10); do curl rebel-base; done'
```
<details><summary><b>Output</b></summary>

```json
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
```
</details>

Check `rebel-base` service from Cluster 2.
```sh
kubectl --context kind-cluster2 exec -ti deployments/x-wing -- /bin/sh -c 'for i in $(seq 1 10); do curl rebel-base; done'
```
<details><summary><b>Output</b></summary>

```json
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
{"Galaxy": "Alderaan", "Cluster": "Cluster-2"}
```
</details>

Return `rebel-base` deployment in Cluster 1 to normal operation.
```sh
kubectl --context kind-cluster1 scale deploy --replicas=2 rebel-base
```
> [!IMPORTANT]
> Try scale up/down `rebel-base` deployment in Cluster 2 and observe the result.

## 🗑️ Cleanup

```sh
make clean
```

It will delete all three clusters.
