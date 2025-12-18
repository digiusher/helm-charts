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

### Installing a Chart

To install the `digiusher-k8s-ingestion` chart:

```console
helm install my-release digiusher/digiusher-k8s-ingestion
```

To uninstall:

```console
helm uninstall my-release
```

## Charts

- [digiusher-k8s-ingestion](./charts/digiusher-k8s-ingestion): Helm chart for Kubernetes ingestion service.
