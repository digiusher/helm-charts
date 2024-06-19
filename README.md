## Usage

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

```
helm repo add digiusher https://digiusher.github.io/helm-charts
```

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
digiusher` to see the charts.

## Installation

Follow the instructions in [kube-cost-metrics-collector](./charts/kube-cost-metrics-collector/README.md).

### Update

First update the repo:

```
helm repo update digiusher
```
