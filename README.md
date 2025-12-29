# DigiUsher Kubernetes Helm Charts

This repository contains Helm charts for DigiUsher services.

## Usage

[Helm](https://helm.sh) must be installed to use the charts.
Please refer to Helm's [documentation](https://helm.sh/docs/) to get started.

Once Helm is set up properly, add the repo as follows:

```console
helm repo add digiusher https://digiusher.github.io/helm-charts
helm repo update
```

You can then run `helm search repo digiusher` to see the charts.

### Installing

To install the `digiusher-k8s-agent` chart:

```console
helm install digiusher-k8s-agent digiusher/digiusher-k8s-agent \
--set uploader.env.digiusher_k8s_api_token=<insert_api_token> \
--namespace digiusher-k8s \
--create-namespace
```

## Charts

- [digiusher-k8s-agent](./charts/digiusher-k8s-agent): Helm chart for Kubernetes agent service.
