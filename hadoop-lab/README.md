# Hadoop Lab — Part 1 Environment (Docker + Kubernetes / Kind)

This is the **root README** for `/opt/hadoop-lab`.

If you have this folder (configs + manifests + scripts + sample data), you can rebuild the Part 1 mini Hadoop ecosystem on a VM with Docker and Kind.

---

## Table of contents

1. [What this folder is](#1-what-this-folder-is)
2. [Folder structure](#2-folder-structure)
3. [Requirements (install before setup)](#3-requirements-install-before-setup)
4. [How to install Docker / kubectl / Kind](#4-how-to-install-docker--kubectl--kind)
5. [Create Kind cluster + namespace](#5-create-kind-cluster--namespace)
6. [Docker images needed](#6-docker-images-needed)
7. [Service-by-service: configs + manifests](#7-service-by-service-configs--manifests)
8. [Bring the stack up (exact order)](#8-bring-the-stack-up-exact-order)
9. [Verify everything is Running](#9-verify-everything-is-running)
10. [Sample data (HDFS upload later)](#10-sample-data-hdfs-upload-later)
11. [Common issues we fixed](#11-common-issues-we-fixed)

---

## 1) What this folder is

`/opt/hadoop-lab` is the **project working directory** for the Hadoop Administrator assignment (Part 1).

It contains:

| Content | Purpose |
|---------|---------|
| Per-service `conf/` | Hadoop / YARN / ZK / Kafka / HBase / Solr configuration |
| Per-service `manifests/` | Kubernetes YAML (ConfigMaps, Services, StatefulSets/Deployments) |
| Per-service `Dockerfile` | Thin Dockerfile (`FROM` official image) for assignment deliverable |
| `scripts/` | Helper scripts (bring-up / start scripts) |
| `docs/` | Lab notes + screenshots / evidence |
| `hdfs/data/` | Local copy of NYC taxi parquet files (500MB+) for Part 2 upload |

It does **not** store the live Kind cluster itself. The live cluster is created with Kind; this folder has everything needed to **re-apply** the services.

---

## 2) Folder structure

```text
/opt/hadoop-lab/
├── README.md                 ← this file
├── docs/                     ← documentation + screenshots
├── scripts/                  ← bring-up helpers
├── hdfs/
│   ├── Dockerfile
│   ├── conf/                 ← core-site.xml, hdfs-site.xml, ...
│   ├── manifests/            ← namenode/datanode YAML + configmap
│   └── data/                 ← yellow_tripdata_2019-*.parquet (Part 2 dataset)
├── yarn/
│   ├── Dockerfile
│   ├── conf/                 ← yarn-site.xml, mapred-site.xml, capacity-scheduler.xml
│   ├── manifests/            ← RM, NM, JobHistory
│   └── scripts/              ← NodeManager start script
├── zookeeper/
│   ├── Dockerfile
│   ├── conf/                 ← zoo.cfg
│   └── manifests/
├── kafka/
│   ├── Dockerfile
│   ├── conf/                 ← server.properties / client.properties
│   ├── manifests/
│   └── scripts/
├── hbase/
│   ├── Dockerfile
│   ├── conf/                 ← hbase-site.xml (+ core/hdfs copies)
│   ├── manifests/
│   └── scripts/              ← start-master.sh, start-rs.sh
├── solr/
│   ├── Dockerfile
│   ├── conf/                 ← solr.xml, schema, solrconfig
│   ├── manifests/
│   └── scripts/              ← start-solr.sh
└── spark/                    ← configs prepared for Part 4 (optional for Part 1)
```

---

## 3) Requirements (install before setup)

### Hardware (lab VM we used)
- About **8 vCPU / 32 GiB RAM** (shared by Kind nodes)
- Linux (RHEL/CentOS-like; we used `dnf`)
- Root (or sudo) access
- Internet access to pull images

### Software
1. **Docker** — runs containers (Kind nodes + service images)
2. **kubectl** — talk to Kubernetes API
3. **Kind** — Kubernetes-in-Docker cluster
4. This folder: **`/opt/hadoop-lab`**

---

## 4) How to install Docker / kubectl / Kind

### 4.1 Docker

```bash
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
docker --version
docker run --rm hello-world
```

### 4.2 kubectl

```bash
cd /tmp
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

### 4.3 Kind

```bash
cd /tmp
curl -Lo kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
chmod +x kind
install -o root -g root -m 0755 kind /usr/local/bin/kind
kind --version
```

---

## 5) Create Kind cluster + namespace

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

kubectl create namespace hadoop
kubectl get namespaces
```

Notes:
- Cluster name: `hadoop-lab`
- Namespace for all services: `hadoop`
- Kind nodes share host CPU/RAM — keep resource requests modest

---

## 6) Docker images needed

Pull on the host (Kind can also pull when pods start):

```bash
docker pull apache/hadoop:3.3.6
docker pull zookeeper:3.9
docker pull apache/kafka:3.9.1
docker pull openeuler/hbase:2.6.5-oe2403sp3
docker pull solr:9.8
# optional for later parts
docker pull apache/spark:3.5.5
```

| Service | Image |
|---------|-------|
| HDFS + YARN | `apache/hadoop:3.3.6` |
| ZooKeeper | `zookeeper:3.9` |
| Kafka | `apache/kafka:3.9.1` |
| HBase | `openeuler/hbase:2.6.5-oe2403sp3` |
| Solr | `solr:9.8` |

Each service folder also has a `Dockerfile` (`FROM <image>`).

---

## 7) Service-by-service: configs + manifests

### 7.1 HDFS — 1 NameNode + 2 DataNodes

**Path:** `/opt/hadoop-lab/hdfs/`

| Type | Files | What they do |
|------|-------|--------------|
| Config | `conf/core-site.xml` | `fs.defaultFS=hdfs://namenode:9000` (Service DNS) |
| Config | `conf/hdfs-site.xml` | replication, name/data dirs, bind hosts |
| Config | `conf/hadoop-env.sh` | JAVA/HADOOP env helpers |
| Manifest | `manifests/configmap.yaml` | packs XML into K8s ConfigMap |
| Manifest | `manifests/namenode.yaml` | Service + StatefulSet NameNode + PVC |
| Manifest | `manifests/datanode.yaml` | headless Service + StatefulSet DataNodes (2) |
| Data | `data/yellow_tripdata_2019-*.parquet` | local dataset for Part 2 |

### 7.2 YARN — 1 ResourceManager + 2 NodeManagers

**Path:** `/opt/hadoop-lab/yarn/`

| Type | Files | What they do |
|------|-------|--------------|
| Config | `conf/yarn-site.xml` | RM hostname/ports, NM settings, scheduler |
| Config | `conf/mapred-site.xml` | MapReduce on YARN |
| Config | `conf/capacity-scheduler.xml` | queues: production / development |
| Config | `conf/core-site.xml`, `hdfs-site.xml` | copies so YARN talks to HDFS |
| Manifest | `manifests/configmap.yaml` | yarn ConfigMap |
| Manifest | `manifests/resourcemanager.yaml` | RM Service + Deployment |
| Manifest | `manifests/nodemanager.yaml` | headless Service + StatefulSet (2 NMs) |
| Manifest | `manifests/jobhistory.yaml` | JobHistory server |
| Script | `scripts/start-nm.sh` | sets NM FQDN DNS name at start |

Important: NodeManagers advertise  
`nodemanager-0.nodemanager.hadoop.svc.cluster.local`  
so ResourceManager can resolve them (needed for MapReduce jobs).

### 7.3 ZooKeeper — 3-node ensemble

**Path:** `/opt/hadoop-lab/zookeeper/`

| Type | Files | What they do |
|------|-------|--------------|
| Config | `conf/zoo.cfg` | ensemble members, clientPort 2181 |
| Manifest | `manifests/configmap.yaml` | zoo.cfg ConfigMap |
| Manifest | `manifests/zookeeper.yaml` | headless + client Service, StatefulSet zk (3) |

Used by Kafka, HBase, SolrCloud.

### 7.4 Kafka — 3 brokers (ZooKeeper mode)

**Path:** `/opt/hadoop-lab/kafka/`

| Type | Files | What they do |
|------|-------|--------------|
| Config | `conf/server.properties` / template in ConfigMap | broker.id, listeners, zookeeper.connect |
| Config | `conf/client.properties` | bootstrap servers |
| Manifest | `manifests/configmap.yaml` | broker config template |
| Manifest | `manifests/kafka.yaml` | headless + client Service, StatefulSet (3) |
| Script | `scripts/create-topic-app-events.sh` | Part 5 helper |

### 7.5 HBase — 1 Master + 2 RegionServers (on HDFS)

**Path:** `/opt/hadoop-lab/hbase/`

| Type | Files | What they do |
|------|-------|--------------|
| Config | `conf/hbase-site.xml` | rootdir on HDFS, ZK quorum, master hostname=`hbase-master` |
| Config | `conf/core-site.xml`, `hdfs-site.xml` | HDFS client settings |
| Manifest | `manifests/configmap.yaml` | hbase ConfigMap |
| Manifest | `manifests/hbase.yaml` | master Service/Deploy + RS StatefulSet |
| Script | `scripts/start-master.sh`, `start-rs.sh` | copy conf + start daemons |

### 7.6 Solr — 2-node SolrCloud

**Path:** `/opt/hadoop-lab/solr/`

| Type | Files | What they do |
|------|-------|--------------|
| Config | `conf/solr.xml` + `conf/app_logs_config/...` | SolrCloud + schema for Part 7 |
| Manifest | `manifests/solr.yaml` | Services + StatefulSet (2), `enableServiceLinks: false` |
| Script | `scripts/start-solr.sh` | wait for ZK, start SolrCloud |

---

## 8) Bring the stack up (exact order)

> Order matters: **HDFS → YARN → ZooKeeper → (wait) → Kafka / HBase / Solr**

### 8.1 Refresh ConfigMaps (if you changed XML/scripts)

```bash
NS=hadoop
BASE=/opt/hadoop-lab

kubectl get ns $NS >/dev/null 2>&1 || kubectl create namespace $NS

kubectl -n $NS create configmap hdfs-config \
  --from-file=$BASE/hdfs/conf/core-site.xml \
  --from-file=$BASE/hdfs/conf/hdfs-site.xml \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n $NS create configmap yarn-config \
  --from-file=$BASE/yarn/conf/ \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n $NS create configmap yarn-nm-scripts \
  --from-file=$BASE/yarn/scripts/start-nm.sh \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n $NS create configmap hbase-config \
  --from-file=$BASE/hbase/conf/hbase-site.xml \
  --from-file=$BASE/hdfs/conf/core-site.xml \
  --from-file=$BASE/hdfs/conf/hdfs-site.xml \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n $NS create configmap hbase-scripts \
  --from-file=$BASE/hbase/scripts/start-master.sh \
  --from-file=$BASE/hbase/scripts/start-rs.sh \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n $NS create configmap solr-scripts \
  --from-file=$BASE/solr/scripts/start-solr.sh \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 8.2 Apply manifests

```bash
BASE=/opt/hadoop-lab

kubectl apply -f $BASE/hdfs/manifests/
kubectl apply -f $BASE/yarn/manifests/
kubectl apply -f $BASE/zookeeper/manifests/
kubectl rollout status statefulset/zk -n hadoop --timeout=300s

kubectl apply -f $BASE/kafka/manifests/
kubectl apply -f $BASE/hbase/manifests/
kubectl apply -f $BASE/solr/manifests/
```

Optional helper script (same idea):

```bash
/opt/hadoop-lab/scripts/bringup-part1.sh
```

---

## 9) Verify everything is Running

```bash
kubectl get pods,svc -n hadoop -o wide

# HDFS
kubectl exec -n hadoop namenode-0 -- hdfs dfsadmin -report | head -30

# YARN
kubectl exec -n hadoop deploy/resourcemanager -- yarn node -list

# ZooKeeper
kubectl exec -n hadoop zk-0 -- bash -lc 'echo ruok | nc 127.0.0.1 2181'

# Kafka / HBase / Solr
kubectl get pods -n hadoop -l app=kafka
kubectl get pods -n hadoop | grep hbase
kubectl get pods -n hadoop -l app=solr
```

### Expected topology

| Component | Count |
|-----------|------:|
| NameNode | 1 |
| DataNode | 2 |
| ResourceManager | 1 |
| NodeManager | 2 |
| ZooKeeper | 3 |
| Kafka broker | 3 |
| HBase Master | 1 |
| HBase RegionServer | 2 |
| Solr | 2 |

### Quick WordCount test (production queue)

```bash
kubectl exec -n hadoop namenode-0 -- bash -lc '
  hdfs dfs -mkdir -p /user/root/wordcount-input
  echo "hadoop yarn mapreduce wordcount production queue test" | hdfs dfs -put -f - /user/root/wordcount-input/sample.txt
  hdfs dfs -rm -r -f /user/root/wordcount-output-prod
'

kubectl exec -n hadoop deploy/resourcemanager -- bash -lc '
  hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar wordcount \
    -Dmapreduce.job.queuename=production \
    /user/root/wordcount-input /user/root/wordcount-output-prod
'
```

---

## 10) Sample data (HDFS upload later)

Local files (already in this repo folder on the VM):

```text
/opt/hadoop-lab/hdfs/data/yellow_tripdata_2019-01.parquet
/opt/hadoop-lab/hdfs/data/yellow_tripdata_2019-02.parquet
...
/opt/hadoop-lab/hdfs/data/yellow_tripdata_2019-06.parquet
```

Source: NYC TLC Yellow Taxi trip data (public).  
Total size is 500MB+ (used for Part 2: upload into HDFS).

Example later (Part 2):

```bash
# copy host files into a pod, then hdfs dfs -put ...
kubectl cp /opt/hadoop-lab/hdfs/data namenode-0:/tmp/taxi-data -n hadoop
kubectl exec -n hadoop namenode-0 -- hdfs dfs -mkdir -p /datasets/taxi
kubectl exec -n hadoop namenode-0 -- hdfs dfs -put /tmp/taxi-data /datasets/taxi/
```

---

## 11) Common issues we fixed

1. **YARN NM not resolvable** → use StatefulSet + headless Service DNS (`nodemanager-N.nodemanager.hadoop.svc.cluster.local`)
2. **HBase RS can’t find master** → set `hbase.master.hostname=hbase-master` (Service name)
3. **Solr crash on start** → `enableServiceLinks: false` + start with `--force`
4. **Replication factor** → Part 1 uses RF=2 (2 DataNodes). For Part 2 RF=3, scale DataNodes to 3 first.

More notes/screenshots: `/opt/hadoop-lab/docs/`

---

## Quick reference — important DNS names inside the cluster

| Service | DNS / address used in configs |
|---------|--------------------------------|
| HDFS | `hdfs://namenode:9000` |
| YARN RM | `resourcemanager:8032` |
| ZooKeeper | `zk-0.zk-hs.hadoop.svc.cluster.local:2181` (and zk-1, zk-2) |
| Kafka | `kafka-0.kafka-hs.hadoop.svc.cluster.local:9092` … |
| HBase master | `hbase-master:16000` |
| Solr | `solr-0.solr-hs.hadoop.svc.cluster.local:8983` |

We use **Kubernetes Service DNS**, not hard-coded Pod IPs (Pod IPs change on restart).

---

**Lab host example:** `10.1.0.213`  
**Kind cluster:** `hadoop-lab`  
**Namespace:** `hadoop`  
**Root path:** `/opt/hadoop-lab`
