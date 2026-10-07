# digiusher-k8s-agent

A lightweight Kubernetes collection agent for [DigiUsher](https://www.digiusher.com).
It scrapes per-node usage metrics and builds object metadata in process. It then streams
compact columnar files to DigiUsher for cost and usage analysis. The chart needs **no
in-cluster time-series database** to run, scale, or pay for.

## What it deploys

| Component | What it does |
| --- | --- |
| **agent** | A `StatefulSet` (one replica). Receives Prometheus `remote_write` from vmagent, watches the Kubernetes API via informers to synthesize `kube_*` object metadata in-process, streams raw samples to native parquet on a PersistentVolume, and uploads completed files to DigiUsher via a pre-signed URL. The PV holds in-flight parquet so nothing is lost across restarts. |
| **vmagent** | A `Deployment` (one replica). Scrapes every kubelet's cAdvisor + `/metrics` endpoints (plus optional dcgm-exporter and node-exporter) via Kubernetes service discovery, keeps a curated metric set, and `remote_write`s to the agent. |

The chart has no kube-state-metrics dependency. The agent builds that metadata itself.

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
  --set sizing=small \
  --set agent.env.digiusher_k8s_api_token=<API_TOKEN>
```

Set `sizing` to the tier that matches the cluster. See [Sizing](#sizing).

To uninstall:

```console
helm uninstall digiusher-k8s-agent --namespace digiusher-k8s
```

## Sizing

The two components scale in different ways.

- **agent — scales with objects.** Sample handling stays flat, because the agent streams samples
  to disk and paces its Go heap with `agent.goMemLimit`. The informer cache is the part that
  grows. Budget about 110 MiB plus 19 KiB for each pod.
- **vmagent — almost flat.** It forwards only the node and container metrics it scrapes, so it
  runs at a small floor. Budget about 64 MiB plus 5 KiB for each pod.

The `sizing` value picks a tier. The tier sets the CPU and memory requests of both components.
The requests are what the cluster reserves, so a tier that matches the cluster keeps the
reserved capacity close to real use.

| Tier | Cluster size | agent requests | vmagent requests |
| --- | --- | --- | --- |
| `small` (default) | Up to about 50 nodes or 1,500 pods | `25m` / `128Mi` | `25m` / `96Mi` |
| `medium` | Up to about 250 nodes or 7,500 pods | `100m` / `256Mi` | `150m` / `160Mi` |
| `large` | Up to about 1,500 nodes or 45,000 pods | `250m` / `1Gi` | `250m` / `320Mi` |

The limits do not change with the tier. The agent keeps its `2000m` / `1536Mi` limits and
`agent.goMemLimit`. vmagent has no limits, because a CPU limit throttles its scrape bursts. A
cluster that outgrows its tier keeps running. Move it to the next tier to restore the scheduling
guarantee.

| Situation | What to set |
| --- | --- |
| Most clusters | Set `sizing` to the tier that matches the cluster. |
| One component needs more | Set `agent.resources.requests` or `vmagent.resources.requests`. A request set there wins over the tier. |
| `large` clusters | At install, set `agent.persistence.size` to `50Gi`. The volume holds the files that wait for upload, so a larger volume rides out a longer loss of connection. To grow it later, see [Grow a volume](#grow-a-volume). |
| Above about 1,500 nodes | Use `large`. Raise `agent.goMemLimit` and `agent.resources.limits.memory` together, and keep GOMEMLIMIT below the limit. Budget 19 KiB for each pod. |

### Grow a volume

Volumes can grow, not shrink, and the StorageClass must allow it. Run `kubectl get storageclass` and check the
`ALLOWVOLUMEEXPANSION` column. The commands use the release name `digiusher-k8s-agent` and need Helm 3.14 or later for
`--reset-then-reuse-values`, which keeps your values and takes the defaults of the new chart version.

**vmagent** uses a standalone PersistentVolumeClaim. Raise its size with an upgrade:

```console
helm upgrade digiusher-k8s-agent digiusher/digiusher-k8s-agent \
  --namespace digiusher-k8s --reset-then-reuse-values \
  --set vmagent.persistence.size=50Gi
```

**agent** gets its volume from the StatefulSet's volume claim template. Kubernetes does not let a StatefulSet change that
template, so grow the claim first, then replace the StatefulSet object without its pod:

```console
kubectl patch pvc data-digiusher-k8s-agent-agent-0 --namespace digiusher-k8s \
  -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'
kubectl delete statefulset digiusher-k8s-agent-agent --namespace digiusher-k8s --cascade=orphan
helm upgrade digiusher-k8s-agent digiusher/digiusher-k8s-agent \
  --namespace digiusher-k8s --reset-then-reuse-values \
  --set agent.persistence.size=50Gi
```

`--cascade=orphan` deletes only the StatefulSet object. The agent pod and its volume keep running, and the upgrade
creates the StatefulSet again around them.

## Configuration

Set values with `--set key=value` or a `-f values.yaml` overrides file. The most common changes
are the required API token (`agent.env.digiusher_k8s_api_token`) and `sizing`.

### Sizing

| Key | Description | Default |
| --- | --- | --- |
| `sizing` | Resource tier: `small`, `medium` or `large`. Sets the CPU and memory requests of the agent and vmagent. See Sizing. | `small` |

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
| `serviceAccount.name` | Name to use. Empty derives from the release name. | `""` |
| `serviceAccount.annotations` | Annotations for the ServiceAccount. | `{}` |

### Agent

| Key | Description | Default |
| --- | --- | --- |
| `agent.enabled` | Deploy the agent. | `true` |
| `agent.image.repository` | Agent image repository. | `ghcr.io/digiusher/digiusher-k8s-agent` |
| `agent.image.tag` | Image tag. Empty ships the chart's `appVersion`. | `""` |
| `agent.image.pullPolicy` | Image pull policy. | `IfNotPresent` |
| `agent.env.digiusher_k8s_api_token` | **Required.** DigiUsher API token. | `""` |
| `agent.env.digiusher_k8s_api_url` | DigiUsher ingestion endpoint. | `https://app.digiusher.com/api/v3` |
| `agent.env.log_level` | Log level. | `info` |
| `agent.extraEnv` | Extra raw `env:` entries for advanced overrides. | `[]` |
| `agent.resources` | Agent CPU/memory requests and limits. Requests set here win over the `sizing` tier. Memory scales with object count. See Sizing. | requests from `sizing`, limits `2000m`/`1536Mi` |
| `agent.goMemLimit` | Soft Go heap ceiling (Go size format). Keep it below `resources.limits.memory`. | `1280MiB` |
| `agent.rbac.create` | Create the agent ClusterRole/ClusterRoleBinding. Set `false` to manage out of band. | `true` |
| `agent.service.port` | Agent metrics/ingest port. | `8111` |
| `agent.persistence.enabled` | Use a PersistentVolume for in-flight parquet. | `true` |
| `agent.persistence.size` | PVC size. Raise it for higher cardinality or longer outage tolerance. | `20Gi` |
| `agent.persistence.storageClassName` | PVC storage class. Empty uses the cluster default. | `""` |

#### Agent metadata (informers)

| Key | Description | Default |
| --- | --- | --- |
| `agent.informers.emitIntervalSeconds` | Seconds between metadata snapshots (clamped 15–300). | `60` |
| `agent.informers.annotationKeys` | Comma-separated annotation keys to collect for cost allocation. Match your chargeback tags. Avoid high-cardinality keys. | `team,cost-center,owner` |
| `agent.informers.disabledKinds` | Comma-separated resource kinds to stop watching (plural lowercase). Empty watches all. | `""` |
| `agent.informers.enableParityExport` | Export the KSM-parity debug endpoint (diagnostics only). | `false` |

### vmagent

| Key | Description | Default |
| --- | --- | --- |
| `vmagent.enabled` | Deploy vmagent. | `true` |
| `vmagent.image.repository` | vmagent image repository. | `victoriametrics/vmagent` |
| `vmagent.image.tag` | vmagent image tag. | `v1.143.0` |
| `vmagent.intervals.cadvisor` | cAdvisor scrape interval. Shorten it (for example `20s`) for clusters with many short-lived pods. | `60s` |
| `vmagent.intervals.kubelet` | Kubelet scrape interval. | `60s` |
| `vmagent.memoryAllowedBytes` | Soft cap on vmagent's memory (`-memory.allowedBytes`). Size it above steady state with headroom. The default rarely needs a change. | `1GB` |
| `vmagent.maxDiskUsagePerURL` | Disk cap for vmagent's remote_write retry queue (outage buffer). | `20GB` |
| `vmagent.resources` | vmagent CPU/memory requests and limits. Requests set here win over the `sizing` tier. No limits by default. Set one for a hard cap. | requests from `sizing`, no limits |
| `vmagent.persistence.enabled` | Use a PersistentVolume for the remote_write queue. | `true` |
| `vmagent.persistence.size` | vmagent queue PVC size. | `30Gi` |

#### Optional exporters (auto-detected)

Both are **on by default**. When the matching exporter is absent, the scrape job finds no targets
and does nothing. A cluster without these exporters therefore pays nothing, and collection starts
as soon as an exporter appears. No chart change is needed.

| Key | Description | Default |
| --- | --- | --- |
| `vmagent.dcgm.enabled` | Scrape dcgm-exporter for GPU cost/utilization. | `true` |
| `vmagent.dcgm.namespace` | Namespace to discover dcgm-exporter in. `""` scans all. | `gpu-operator` |
| `vmagent.dcgm.selectorLabelName` / `selectorLabelValue` | Service label selector for dcgm-exporter (underscore-sanitized key). | `app_kubernetes_io_name` / `dcgm-exporter` |
| `vmagent.dcgm.port` / `interval` | dcgm-exporter port and scrape interval. | `9400` / `60s` |
| `vmagent.nodeExporter.enabled` | Scrape node-exporter for node-consolidation analysis. | `true` |
| `vmagent.nodeExporter.namespace` | Namespace to discover node-exporter in. `""` scans all. | `""` |
| `vmagent.nodeExporter.selectorLabelName` / `selectorLabelValue` | Service label selector for node-exporter. | `app_kubernetes_io_name` / `node-exporter` |
| `vmagent.nodeExporter.port` / `interval` | node-exporter port and scrape interval. | `9100` / `60s` |

### Scheduling & security (both components)

`nodeSelector`, `tolerations`, `affinity`, `podAnnotations`, `podSecurityContext`, `securityContext`,
and the agent's `startupProbe`/`livenessProbe`/`readinessProbe` follow standard Helm conventions.
You can override each one per component (`agent.*` / `vmagent.*`). Both components ship with a
`digiusher-k8s` `NoSchedule` toleration. Clear it if you do not taint nodes for the agent.

See [`values.yaml`](./values.yaml) for the complete set and inline rationale.
