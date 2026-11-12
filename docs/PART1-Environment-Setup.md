# Part 1 — Environment Setup (Docker + Kubernetes)

**Assignment title:** Build, Configure, and Troubleshoot a Multi-Service Hadoop Ecosystem on Kubernetes  
**Cluster name:** `hadoop-lab` (Kind)  
**Namespace:** `hadoop`  
**Lab host:** `10.1.0.213` (`alphtatalakehouse6`)  
**Working directory:** `/opt/hadoop-lab`

This document is written so you can **re-run every step** and also **explain it in an interview** (what each command does and why).

---

## 0) Big picture (say this in interviews)

We run a **mini Hadoop ecosystem inside Kubernetes**:

1. A Linux **VM** runs **Docker**.
2. **Kind** creates a local Kubernetes cluster where each “node” is a Docker container.
3. Inside Kubernetes, **Pods** run HDFS, YARN, ZooKeeper, Kafka, HBase, and Solr.
4. Pods find each other using **Kubernetes DNS Service names** (example: `namenode`, `resourcemanager`, `zk-0.zk-hs.hadoop.svc.cluster.local`) — **not hard-coded pod IPs**, because pod IPs change on restart.

```
VM
 └─ Docker
     └─ Kind nodes (control-plane + workers)
         └─ Kubernetes Pods (HDFS / YARN / ZK / Kafka / HBase / Solr)
```

---

## 1) Tools we installed first

### 1.1 Docker

**Why:** Docker runs containers. Kind nodes and our service images are containers.

```bash
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
docker --version
docker run --rm hello-world
```

- `systemctl enable --now docker` → start Docker now and on boot  
- `hello-world` → proves Docker can pull and run an image

### 1.2 kubectl

**Why:** kubectl is the CLI to talk to the Kubernetes API (create pods, services, check status).

```bash
cd /tmp
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

### 1.3 Kind

**Why:** Kind = Kubernetes IN Docker. Good for labs without cloud VMs.

```bash
cd /tmp
curl -Lo kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
chmod +x kind
install -o root -g root -m 0755 kind /usr/local/bin/kind
```

---

## 2) Create the Kind cluster

```bash
cat > /root/kind-cluster.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

kind create cluster --name hadoop-lab --config /root/kind-cluster.yaml
kubectl get nodes
kubectl cluster-info
```

**Interview tip:** Kind nodes share the **host VM CPU/RAM**. If the VM has 8 vCPU / 32 GiB, that is the real capacity — not “3 × node capacity”.

```bash
kubectl create namespace hadoop
mkdir -p /opt/hadoop-lab/{hdfs,yarn,spark,kafka,hbase,solr,zookeeper,scripts,docs}
mkdir -p /opt/hadoop-lab/hdfs/{conf,manifests,data}
```

---

## 3) Docker images used (Part 1)

| Service | Image | Role |
|---------|-------|------|
| HDFS + YARN | `apache/hadoop:3.3.6` | NameNode, DataNode, RM, NM |
| ZooKeeper | `zookeeper:3.9` | Coordination for Kafka/HBase/Solr |
| Kafka | `apache/kafka:3.9.1` | 3 brokers (ZooKeeper mode) |
| HBase | `openeuler/hbase:2.6.5-oe2403sp3` | 1 Master + 2 RegionServers |
| Solr | `solr:9.8` | 2-node SolrCloud |

Each service folder also has a thin **Dockerfile** (`FROM <image>`) to satisfy the “create Dockerfiles” deliverable while still using official images.

```bash
docker pull apache/hadoop:3.3.6
docker pull zookeeper:3.9
docker pull apache/kafka:3.9.1
docker pull openeuler/hbase:2.6.5-oe2403sp3
docker pull solr:9.8
```

Kind can also pull images when pods start (`imagePullPolicy: IfNotPresent`).

---

## 4) HDFS — 1 NameNode + 2 DataNodes

### 4.1 Why these configs matter

**`core-site.xml` — `fs.defaultFS`**
- Tells every Hadoop client where the filesystem lives.
- We use **Service DNS**: `hdfs://namenode:9000`  
  (`namenode` resolves inside the `hadoop` namespace)

**`hdfs-site.xml`**
- `dfs.replication=2` for Part 1 (only 2 DataNodes). For Part 2 RF=3, scale to 3 DataNodes first.
- `dfs.namenode.rpc-bind-host=0.0.0.0` → NameNode listens on all interfaces inside the pod (required in containers).
- `dfs.namenode.datanode.registration.ip-hostname-check=false` → avoids hostname/IP mismatch issues in Kubernetes.

### 4.2 Deploy

```bash
# ConfigMap packages XML into Kubernetes
kubectl -n hadoop create configmap hdfs-config \
  --from-file=/opt/hadoop-lab/hdfs/conf/core-site.xml \
  --from-file=/opt/hadoop-lab/hdfs/conf/hdfs-site.xml \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f /opt/hadoop-lab/hdfs/manifests/
kubectl get pods -n hadoop -l 'app in (namenode,datanode)' -o wide
```

### 4.3 Verify (keep this screenshot)

```bash
kubectl exec -n hadoop namenode-0 -- hdfs dfsadmin -report
kubectl exec -n hadoop namenode-0 -- hdfs dfs -ls /
```

**Expected:** Live datanodes = **2**, NameNode Running.

**Evidence folder:** `/opt/hadoop-lab/docs/screenshots/01-hdfs/`

---

## 5) YARN — 1 ResourceManager + 2 NodeManagers

### 5.1 The “IP vs hostname” lesson (important)

Wrong approach: hard-code a NodeManager IP in `yarn-site.xml`.  
Pod IPs change → NodeManagers fail to register after restart.

Correct approach used in this lab:

1. **ResourceManager** is reached by Kubernetes Service name: `resourcemanager:8032`
2. RM **binds** on `0.0.0.0` (listen everywhere in the pod)
3. Each NodeManager injects its **current Pod IP** at startup:

```xml
<property>
  <name>yarn.nodemanager.hostname</name>
  <value>${env.POD_IP}</value>
</property>
```

In the NodeManager pod:

```bash
POD_IP from status.podIP
sed replaces ${env.POD_IP} with the real IP
then: yarn nodemanager
```

So YARN advertises a reachable address without freezing a stale IP in Git.

### 5.2 Key files

- `/opt/hadoop-lab/yarn/conf/yarn-site.xml`
- `/opt/hadoop-lab/yarn/conf/mapred-site.xml`
- `/opt/hadoop-lab/yarn/conf/capacity-scheduler.xml` (production 60%/max80%, development 40%/max100% — ready for Part 3)
- Manifests under `/opt/hadoop-lab/yarn/manifests/`

### 5.3 Deploy + verify

```bash
kubectl apply -f /opt/hadoop-lab/yarn/manifests/
kubectl get pods -n hadoop | grep -E 'resourcemanager|nodemanager|jobhistory'
kubectl exec -n hadoop deploy/resourcemanager -- yarn node -list
```

**Expected:** Total Nodes: **2**, both RUNNING.

**Evidence:** `/opt/hadoop-lab/docs/screenshots/02-yarn/`

---

## 6) ZooKeeper — 3-node ensemble

**Why ZooKeeper exists here:** Kafka (ZK mode), HBase, and SolrCloud need a shared coordination service.

```bash
kubectl apply -f /opt/hadoop-lab/zookeeper/manifests/
kubectl rollout status statefulset/zk -n hadoop --timeout=300s
kubectl get pods -n hadoop -l app=zk
```

**Service discovery names:**
- Headless: `zk-0.zk-hs.hadoop.svc.cluster.local:2181` …
- Client service: `zookeeper:2181`

**Quick health check:**

```bash
kubectl exec -n hadoop zk-0 -- bash -lc 'echo ruok | nc 127.0.0.1 2181'
# expect: imok
```

---

## 7) Kafka — 3 brokers with ZooKeeper

**Design:**
- StatefulSet `kafka` replicas=3
- Each broker gets `broker.id` from pod ordinal (`kafka-0` → 0)
- `advertised.listeners` uses stable DNS: `kafka-<n>.kafka-hs.hadoop.svc.cluster.local:9092`
- `zookeeper.connect` points to the 3 ZK pods

```bash
kubectl apply -f /opt/hadoop-lab/kafka/manifests/
kubectl get pods -n hadoop -l app=kafka
kubectl logs -n hadoop kafka-0 --tail=50
```

Look for: `[KafkaServer id=0] started` and ZK metadata (`ZkMetadataCache`).

**Evidence:** `/opt/hadoop-lab/docs/screenshots/03-kafka/`

---

## 8) HBase — 1 Master + 2 RegionServers (on HDFS)

**Dependencies:** HDFS (`hbase.rootdir=hdfs://namenode:9000/hbase`) + ZooKeeper quorum.

```bash
kubectl apply -f /opt/hadoop-lab/hbase/manifests/
kubectl get pods -n hadoop | grep hbase
kubectl exec -n hadoop deploy/hbase-master -- bash -lc 'echo -e "status\nexit" | hbase shell -n'
```

**Expected:** 1 master active, 2 region servers.

**Evidence:** `/opt/hadoop-lab/docs/screenshots/04-hbase/`

---

## 9) Solr — 2-node SolrCloud with ZooKeeper

```bash
kubectl apply -f /opt/hadoop-lab/solr/manifests/
kubectl get pods -n hadoop -l app=solr
kubectl exec -n hadoop solr-0 -- solr status
```

Collection creation / schema work is Part 7; Part 1 only needs SolrCloud nodes up and talking to ZK.

**Evidence:** `/opt/hadoop-lab/docs/screenshots/05-solr/`

---

## 10) Single bring-up command (deliverable)

After images exist on the host / Kind:

```bash
/opt/hadoop-lab/scripts/bringup-part1.sh
```

This script applies manifests in dependency order:

1. Namespace  
2. HDFS  
3. YARN  
4. ZooKeeper (waits for Ready)  
5. Kafka + HBase + Solr  

Equivalent one-liner style:

```bash
kubectl apply -f /opt/hadoop-lab/hdfs/manifests/ \
  -f /opt/hadoop-lab/yarn/manifests/ \
  -f /opt/hadoop-lab/zookeeper/manifests/ \
  -f /opt/hadoop-lab/kafka/manifests/ \
  -f /opt/hadoop-lab/hbase/manifests/ \
  -f /opt/hadoop-lab/solr/manifests/
```

(Prefer the script because it waits for ZooKeeper before Kafka/HBase/Solr.)

---

## 11) Final health checklist

```bash
kubectl get pods,svc -n hadoop -o wide
kubectl exec -n hadoop namenode-0 -- hdfs dfsadmin -report | head -30
kubectl exec -n hadoop deploy/resourcemanager -- yarn node -list
kubectl exec -n hadoop zk-0 -- bash -lc 'echo ruok | nc 127.0.0.1 2181'
kubectl get pods -n hadoop -l app=kafka
kubectl get pods -n hadoop | grep hbase
kubectl get pods -n hadoop -l app=solr
```

### Target topology

| Component | Count | Status target |
|-----------|------:|---------------|
| NameNode | 1 | Running |
| DataNode | 2 | Running |
| ResourceManager | 1 | Running |
| NodeManager | 2 | Running |
| ZooKeeper | 3 | Running |
| Kafka broker | 3 | Running |
| HBase Master | 1 | Running |
| HBase RegionServer | 2 | Running |
| Solr | 2 | Running |

---

## 12) Interview Q&A cheat sheet

**Q: Why Kind instead of bare metal Hadoop?**  
A: Faster to rebuild, same Kubernetes skills used in production platforms, easy demos for service discovery and StatefulSets.

**Q: Why Service DNS instead of Pod IP?**  
A: Pod IPs are ephemeral. ClusterIP/headless Services give stable names for RPC endpoints (NameNode, RM, ZK, Kafka advertised listeners).

**Q: Why StatefulSet for DataNodes / ZK / Kafka / Solr?**  
A: Stable network identity (`pod-0`, `pod-1`), ordered identity, and PVC per ordinal for durable data.

**Q: Why RF=2 in Part 1 if Part 2 asks RF=3?**  
A: Max useful replication ≤ number of live DataNodes. Scale DataNodes to 3 before setting RF=3.

**Q: How do NodeManagers register correctly in K8s?**  
A: Bind RM on `0.0.0.0`, connect via Service `resourcemanager`, set `yarn.nodemanager.hostname` to the pod’s current IP at start time.

---

## 13) Deliverables map

| Assignment ask | Where it is |
|----------------|-------------|
| Dockerfiles | `/opt/hadoop-lab/*/Dockerfile` |
| K8s manifests (STS/Deploy/Svc/CM) | `/opt/hadoop-lab/*/manifests/` |
| Config XML / properties | `/opt/hadoop-lab/*/conf/` |
| Single bring-up script | `/opt/hadoop-lab/scripts/bringup-part1.sh` |
| This documentation | `/opt/hadoop-lab/docs/PART1-Environment-Setup.md` + screenshots |

---

*Generated for the Hadoop Administrator practical assignment — Part 1.*


---

## 14) Live verification snapshot (cluster evidence)

Captured from the running Kind cluster `hadoop-lab` in namespace `hadoop`.

### Pod topology (all Part 1 services Running)

| Component | Pods | Ready |
|-----------|------|-------|
| HDFS NameNode | `namenode-0` | 1/1 |
| HDFS DataNode | `datanode-0`, `datanode-1` | 1/1 |
| YARN ResourceManager | `resourcemanager-...` | 1/1 |
| YARN NodeManager | 2 pods | 1/1 each |
| ZooKeeper | `zk-0`, `zk-1`, `zk-2` | 1/1 |
| Kafka | `kafka-0`, `kafka-1`, `kafka-2` | 1/1 |
| HBase Master | `hbase-master-...` | 1/1 |
| HBase RegionServer | `hbase-rs-0`, `hbase-rs-1` | 1/1 |
| SolrCloud | `solr-0`, `solr-1` | 1/1 |

### Command outputs (also saved under screenshots/)

**HDFS**
```text
Live datanodes (2)
```

**YARN**
```text
Total Nodes:2
... Node-State RUNNING ...
```

**HBase**
```text
1 active master, 0 backup masters, 2 servers, 0 dead, 1.0000 average load
```

**Kafka**
Brokers respond on `kafka-*.kafka-hs.hadoop.svc.cluster.local:9092` (ZK mode).

**Solr**
Both SolrCloud nodes Ready (`1/1`) with `ZK_HOST` pointing at the ZK ensemble.

### Screenshot / evidence files

On the lab VM:

- `/opt/hadoop-lab/docs/screenshots/00-overview/cluster-status.txt|.png`
- `/opt/hadoop-lab/docs/screenshots/01-hdfs/...`
- `/opt/hadoop-lab/docs/screenshots/02-yarn/...`
- `/opt/hadoop-lab/docs/screenshots/03-zk/...`
- `/opt/hadoop-lab/docs/screenshots/04-kafka/...`
- `/opt/hadoop-lab/docs/screenshots/05-hbase/...`
- `/opt/hadoop-lab/docs/screenshots/06-solr/...`

Local repo copy: `docs/screenshots/`

### Bring-up script

```bash
/opt/hadoop-lab/scripts/bringup-part1.sh
```
