.DEFAULT_TARGET: all

all: k8s/kind cilium/install cilium/wait cilium/connect cilium/wait k8s/apps k8s/wait

k8s/kind:
	kind create cluster --config=kind/cluster1.yaml --name cluster1
	kind create cluster --config=kind/cluster2.yaml --name cluster2
	kind create cluster --config=kind/cluster3.yaml --name cluster3

k8s/apps:
	kubectl --context kind-cluster1 apply -f apps/cluster1.yaml
	kubectl --context kind-cluster2 apply -f apps/cluster2.yaml
	kubectl --context kind-cluster3 apply -f apps/cluster3.yaml

k8s/wait:
	kubectl --context kind-cluster1 wait deploy/rebel-base --for=condition=Available --timeout=300s
	kubectl --context kind-cluster1 wait deploy/x-wing --for=condition=Available --timeout=300s
	kubectl --context kind-cluster2 wait deploy/rebel-base --for=condition=Available --timeout=300s
	kubectl --context kind-cluster2 wait deploy/x-wing --for=condition=Available --timeout=300s
	kubectl --context kind-cluster3 wait deploy/x-wing --for=condition=Available --timeout=300s

cilium/install:
	cilium --context kind-cluster1 install --version v1.15.4 --values cilium/cluster1.yaml 
	cilium --context kind-cluster2 install --version v1.15.4 --values cilium/cluster2.yaml 
	cilium --context kind-cluster3 install --version v1.15.4 --values cilium/cluster3.yaml 

cilium/wait:
	cilium --context kind-cluster1 status --wait --wait-duration 10m
	cilium --context kind-cluster2 status --wait --wait-duration 10m
	cilium --context kind-cluster3 status --wait --wait-duration 10m
	cilium --context kind-cluster1 clustermesh status --wait
	cilium --context kind-cluster2 clustermesh status --wait
	cilium --context kind-cluster3 clustermesh status --wait

cilium/connect:
	cilium clustermesh connect --context kind-cluster1 --destination-context kind-cluster2
	cilium clustermesh connect --context kind-cluster1 --destination-context kind-cluster3
	cilium clustermesh connect --context kind-cluster2 --destination-context kind-cluster3

.PHONY: clean
clean:
	kind delete cluster --name cluster1
	kind delete cluster --name cluster2
	kind delete cluster --name cluster3
