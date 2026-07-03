# digiusher-k8s-agent

A lightweight Kubernetes collection agent for [DigiUsher](https://www.digiusher.com).
It scrapes per-node usage metrics, synthesizes object metadata in-process, and streams
compact columnar files to DigiUsher for cost and usage analysis — with **no in-cluster
time-series database** to run, scale, or pay for.

## What it deploys

| Component | What it does |
| --- | --- |
| **agent** | A `StatefulSet` (one replica). Receives Prometheus `remote_write` from vmagent, watches the Kubernetes API via informers to synthesize `kube_*` object metadata in-process, streams raw samples to native parquet on a PersistentVolume, and uploads completed files to DigiUsher via a pre-signed URL. The PV holds in-flight parquet so nothing is lost across restarts. |
| **vmagent** | A `Deployment` (one replica). Scrapes every kubelet's cAdvisor + `/metrics` endpoints (plus optional dcgm-exporter and node-exporter) via Kubernetes service discovery, keeps a curated metric set, and `remote_write`s to the agent. |

There is no kube-state-metrics dependency — the agent synthesizes that metadata itself.

## Prerequisites

- A Kubernetes cluster and Helm 3.
- A DigiUsher API token (provided by the DigiUsher team).
- Permission to create the agent's `ClusterRole`/`ClusterRoleBinding` (get/list/watch on the
  watched kinds), or have an admin pre-create them and set `agent.rbac.create=false`.

## Install

```console
helm repo add digiusher https://digiusher.github.io/helm-charts
helm repo update

helm install digiusher-k8s-agent digiusher/digiusher-k8s-agent \
  --namespace digiusher-k8s --create-namespace \
  --set agent.env.digiusher_k8s_api_token=<API_TOKEN>
```

To uninstall:

```console
helm uninstall digiusher-k8s-agent --namespace digiusher-k8s
```

## Sizing

The two components scale differently, so they tune differently:

- **agent — flat.** It streams samples straight to disk and paces its Go heap with
  `agent.goMemLimit`, so its memory does **not** grow with cluster size or series cardinality.
  The default fits clusters of any size as-is; you do not raise it as you grow.
- **vmagent — series-driven.** Its footprint grows with the number of active series it scrapes
  (≈ nodes × pods × kept metrics). On large / high-cardinality clusters this is the component to
  size up: raise `vmagent.memoryAllowedBytes` (with headroom above steady state) and optionally
  set an explicit `vmagent.resources.limits.memory`.

Rule of thumb: if memory pressure appears as you scale, it is vmagent — the agent stays flat.
The chart **defaults carry a large cluster (well into the thousands of nodes) comfortably**; you
generally don't change them. Tune only at the edges:

| Situation | What to set |
| --- | --- |
| Typical clusters (up to a few thousand nodes) | Leave the defaults — agent stays flat; `vmagent.memoryAllowedBytes: 1GB` has ample headroom. |
| Small clusters reclaiming overhead | Optionally lower `agent.resources.limits.memory` + `agent.goMemLimit` together (keep GOMEMLIMIT below the limit). |
| Very large / high-cardinality clusters | Raise `vmagent.memoryAllowedBytes` above steady-state usage and set an explicit `vmagent.resources.limits.memory`. The agent's defaults still hold. |

## Configuration

Set values with `--set key=value` or a `-f values.yaml` overrides file. The most common change
is the required API token (`agent.env.digiusher_k8s_api_token`).

### Global

| Key | Description | Default |
| --- | --- | --- |
| `global.useDevImages` | Pull the private `*-dev` images instead of the public prod ones (requires `imagePullSecrets` and per-service `image.devTag`). | `false` |
| `global.imagePullSecrets` | Image-pull secrets for private registries. | `[]` |

### Service account

| Key | Description | Default |
| --- | --- | --- |
| `serviceAccount.create` | Create a ServiceAccount for the agent. | `true` |
| `serviceAccount.automount` | Auto-mount the ServiceAccount token. | `true` |
| `serviceAccount.name` | Name to use; empty derives from the release name. | `""` |
| `serviceAccount.annotations` | Annotations for the ServiceAccount. | `{}` |

### Agent

| Key | Description | Default |
| --- | --- | --- |
| `agent.enabled` | Deploy the agent. | `true` |
| `agent.image.repository` | Agent image repository. | `ghcr.io/digiusher/digiusher-k8s-agent` |
| `agent.image.tag` | Image tag; empty ships the chart's `appVersion`. | `""` |
| `agent.image.pullPolicy` | Image pull policy. | `IfNotPresent` |
| `agent.env.digiusher_k8s_api_token` | **Required.** DigiUsher API token. | `""` |
| `agent.env.digiusher_k8s_api_url` | DigiUsher ingestion endpoint. | `https://app.digiusher.com/api/v3` |
| `agent.env.log_level` | Log level. | `info` |
| `agent.extraEnv` | Extra raw `env:` entries for advanced overrides. | `[]` |
| `agent.resources` | Agent CPU/memory requests and limits. Memory is flat — see Sizing. | requests `200m`/`128Mi`, limits `2000m`/`1536Mi` |
| `agent.goMemLimit` | Soft Go heap ceiling (Go size format); keep below `resources.limits.memory`. | `1280MiB` |
| `agent.rbac.create` | Create the agent ClusterRole/ClusterRoleBinding. Set `false` to manage out of band. | `true` |
| `agent.service.port` | Agent metrics/ingest port. | `8111` |
| `agent.persistence.enabled` | Use a PersistentVolume for in-flight parquet. | `true` |
| `agent.persistence.size` | PVC size; scale up for higher cardinality or longer outage tolerance. | `20Gi` |
| `agent.persistence.storageClassName` | PVC storage class; empty uses the cluster default. | `""` |

#### Agent metadata (informers)

| Key | Description | Default |
| --- | --- | --- |
| `agent.informers.emitIntervalSeconds` | Seconds between metadata snapshots (clamped 15–300). | `60` |
| `agent.informers.annotationKeys` | Comma-separated annotation keys to collect for cost allocation. Match your chargeback tags; avoid high-cardinality keys. | `team,cost-center,owner` |
| `agent.informers.disabledKinds` | Comma-separated resource kinds to stop watching (plural lowercase); empty watches all. | `""` |
| `agent.informers.enableParityExport` | Export the KSM-parity debug endpoint (diagnostics only). | `false` |

### vmagent

| Key | Description | Default |
| --- | --- | --- |
| `vmagent.enabled` | Deploy vmagent. | `true` |
| `vmagent.image.repository` | vmagent image repository. | `victoriametrics/vmagent` |
| `vmagent.image.tag` | vmagent image tag. | `v1.143.0` |
| `vmagent.intervals.cadvisor` | cAdvisor scrape interval; tighten (e.g. `20s`) for clusters with many short-lived pods. | `60s` |
| `vmagent.intervals.kubelet` | Kubelet scrape interval. | `60s` |
| `vmagent.memoryAllowedBytes` | Soft cap on vmagent's memory (`-memory.allowedBytes`); size above steady state with headroom. The main lever on large clusters. | `1GB` |
| `vmagent.maxDiskUsagePerURL` | Disk cap for vmagent's remote_write retry queue (outage buffer). | `20GB` |
| `vmagent.resources` | vmagent CPU/memory requests; memory limit is unset by default — set one to cap hard. | requests `200m`/`256Mi`, limits `500m` cpu |
| `vmagent.persistence.enabled` | Use a PersistentVolume for the remote_write queue. | `true` |
| `vmagent.persistence.size` | vmagent queue PVC size. | `30Gi` |

#### Optional exporters (auto-detected)

Both are **on by default** and are a harmless no-op when the matching exporter isn't present — the
scrape job simply finds no targets, so non-GPU/non-node-exporter clusters pay nothing and
collection starts the moment an exporter appears (no chart change needed).

| Key | Description | Default |
| --- | --- | --- |
| `vmagent.dcgm.enabled` | Scrape dcgm-exporter for GPU cost/utilization. | `true` |
| `vmagent.dcgm.namespace` | Namespace to discover dcgm-exporter in; `""` scans all. | `gpu-operator` |
| `vmagent.dcgm.selectorLabelName` / `selectorLabelValue` | Service label selector for dcgm-exporter (underscore-sanitized key). | `app_kubernetes_io_name` / `dcgm-exporter` |
| `vmagent.dcgm.port` / `interval` | dcgm-exporter port and scrape interval. | `9400` / `60s` |
| `vmagent.nodeExporter.enabled` | Scrape node-exporter for node-consolidation analysis. | `true` |
| `vmagent.nodeExporter.namespace` | Namespace to discover node-exporter in; `""` scans all. | `""` |
| `vmagent.nodeExporter.selectorLabelName` / `selectorLabelValue` | Service label selector for node-exporter. | `app_kubernetes_io_name` / `node-exporter` |
| `vmagent.nodeExporter.port` / `interval` | node-exporter port and scrape interval. | `9100` / `60s` |

### Scheduling & security (both components)

`nodeSelector`, `tolerations`, `affinity`, `podAnnotations`, `podSecurityContext`, `securityContext`,
and the agent's `startupProbe`/`livenessProbe`/`readinessProbe` follow standard Helm conventions and
can be overridden per component (`agent.*` / `vmagent.*`). Both components ship with a
`digiusher-k8s` `NoSchedule` toleration by default; clear it if you don't taint nodes for the agent.

See [`values.yaml`](./values.yaml) for the complete set and inline rationale.
