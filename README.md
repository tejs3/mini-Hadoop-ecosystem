# Mini Hadoop Ecosystem

Build, configure, and troubleshoot a multi-service Hadoop ecosystem on Kubernetes (Kind).

Two kinds of folders sit next to each other:

| Folder | What you open it for |
|--------|----------------------|
| [`hadoop-lab/`](hadoop-lab/README.md) | The files that run the cluster. Copied from `/opt/hadoop-lab` on the lab VM. Each service has `conf/`, `manifests/`, and `scripts/`. |
| `01-environment/` … `08-troubleshooting/` | The assignment write-up for that part. The Word file is the lab notes, with the commands and screenshots. The short `README.md` in the same folder says which file to open. |

Lab host: `10.1.0.213` (`alphtatalakehouse6`). Kind cluster name: `hadoop-lab`. Kubernetes namespace: `hadoop`.

## Table of contents

1. [Where to look](#where-to-look)
2. [Configuration files](#configuration-files)
3. [Kubernetes manifests](#kubernetes-manifests)
4. [Scripts](#scripts)
5. [What the documentation contains](#what-the-documentation-contains)
6. [Setup](#setup)
7. [Troubleshooting](#troubleshooting)

## Where to look

```text
submission/
├── README.md                  this file
├── TROUBLESHOOTING.md         problems hit on the lab, and the fix
├── hadoop-lab/                configs, manifests, Dockerfiles, scripts
│   ├── hdfs/conf/             HDFS XML
│   ├── yarn/conf/             YARN XML and capacity-scheduler.xml
│   ├── zookeeper/conf/
│   ├── kafka/conf/
│   ├── hbase/conf/
│   ├── solr/conf/
│   └── spark/conf/
├── 01-environment/            Part 1 write-up + cluster screenshots
├── 02-hdfs/                   Part 2 write-up + HDFS screenshots
├── 03-yarn/                   Part 3 write-up + capacity-scheduler.xml
├── 04-spark/                  Part 4 write-up + Spark jobs
├── 05-kafka/                  Part 5 write-up + producer and consumer
├── 06-hbase/                  Part 6 write-up + table create and load
├── 07-solr/                   Part 7 write-up + schema, index, queries
└── 08-troubleshooting/        Part 8 written scenarios
```

The same script is often in two places. `hadoop-lab/<service>/scripts/` is the copy from the VM. The matching part folder (`04-spark/scripts/`, `05-kafka/scripts/`, and so on) is the copy that belongs with that part’s write-up.

## Configuration files

All of these are under `hadoop-lab/`.

| Service | File | What it sets |
|---------|------|----------------|
| HDFS | [hdfs/conf/core-site.xml](hadoop-lab/hdfs/conf/core-site.xml) | `fs.defaultFS=hdfs://namenode:9000` |
| HDFS | [hdfs/conf/hdfs-site.xml](hadoop-lab/hdfs/conf/hdfs-site.xml) | Name and data directories, bind hosts, cluster replication (2) |
| HDFS | [hdfs/conf/hadoop-env.sh](hadoop-lab/hdfs/conf/hadoop-env.sh) | Hadoop environment |
| YARN | [yarn/conf/yarn-site.xml](hadoop-lab/yarn/conf/yarn-site.xml) | ResourceManager hostname and ports, NodeManager settings |
| YARN | [yarn/conf/mapred-site.xml](hadoop-lab/yarn/conf/mapred-site.xml) | MapReduce on YARN |
| YARN | [yarn/conf/capacity-scheduler.xml](hadoop-lab/yarn/conf/capacity-scheduler.xml) | `production` 60% / max 80%, `development` 40% / max 100% |
| YARN | [yarn/conf/core-site.xml](hadoop-lab/yarn/conf/core-site.xml), [hdfs-site.xml](hadoop-lab/yarn/conf/hdfs-site.xml) | So YARN can talk to HDFS |
| ZooKeeper | [zookeeper/conf/zoo.cfg](hadoop-lab/zookeeper/conf/zoo.cfg) | 3-node ensemble, client port 2181 |
| Kafka | [kafka/conf/server.properties](hadoop-lab/kafka/conf/server.properties) | Broker listeners and ZooKeeper connect |
| Kafka | [kafka/conf/client.properties](hadoop-lab/kafka/conf/client.properties) | Bootstrap servers |
| HBase | [hbase/conf/hbase-site.xml](hadoop-lab/hbase/conf/hbase-site.xml) | HDFS root dir, ZooKeeper quorum, master hostname `hbase-master` |
| HBase | [hbase/conf/core-site.xml](hadoop-lab/hbase/conf/core-site.xml), [hdfs-site.xml](hadoop-lab/hbase/conf/hdfs-site.xml) | HDFS client settings for HBase |
| Solr | [solr/conf/solr.xml](hadoop-lab/solr/conf/solr.xml) | SolrCloud |
| Solr | [solr/conf/app_logs_config/conf/](hadoop-lab/solr/conf/app_logs_config/conf/) | Collection config (`schema.xml`, `solrconfig.xml`) |
| Spark | [spark/conf/spark-defaults.conf](hadoop-lab/spark/conf/spark-defaults.conf) | Spark on YARN defaults |
| Spark | [spark/conf/spark-env.sh](hadoop-lab/spark/conf/spark-env.sh) | Spark environment |
| Spark | [spark/conf/core-site.xml](hadoop-lab/spark/conf/core-site.xml) | So Spark can read HDFS |

A second copy of the YARN scheduler file is in [03-yarn/capacity-scheduler.xml](03-yarn/capacity-scheduler.xml). The Solr fields posted for Part 7 are in [07-solr/scripts/app_logs_schema.json](07-solr/scripts/app_logs_schema.json) and [hadoop-lab/solr/scripts/app_logs_schema.json](hadoop-lab/solr/scripts/app_logs_schema.json).

Each service also has a `Dockerfile` (`FROM` the official image) in its folder.

## Kubernetes manifests

| Service | Path | What it starts |
|---------|------|----------------|
| HDFS | [hadoop-lab/hdfs/manifests/](hadoop-lab/hdfs/manifests/) | 1 NameNode, DataNodes, ConfigMap |
| YARN | [hadoop-lab/yarn/manifests/](hadoop-lab/yarn/manifests/) | ResourceManager, 2 NodeManagers, JobHistory |
| ZooKeeper | [hadoop-lab/zookeeper/manifests/](hadoop-lab/zookeeper/manifests/) | 3-node ensemble |
| Kafka | [hadoop-lab/kafka/manifests/](hadoop-lab/kafka/manifests/) | 3 brokers |
| HBase | [hadoop-lab/hbase/manifests/](hadoop-lab/hbase/manifests/) | 1 Master, 2 RegionServers |
| Solr | [hadoop-lab/solr/manifests/solr.yaml](hadoop-lab/solr/manifests/solr.yaml) | 2 SolrCloud nodes. `enableServiceLinks: false` is in this file |

## Scripts

| Script | What it does |
|--------|----------------|
| [hadoop-lab/scripts/bringup-part1.sh](hadoop-lab/scripts/bringup-part1.sh) | Apply the manifests in order |
| [hadoop-lab/yarn/scripts/start-nm.sh](hadoop-lab/yarn/scripts/start-nm.sh) | Set the NodeManager DNS name at start |
| [hadoop-lab/hbase/scripts/start-master.sh](hadoop-lab/hbase/scripts/start-master.sh), [start-rs.sh](hadoop-lab/hbase/scripts/start-rs.sh) | Start HBase |
| [hadoop-lab/solr/scripts/start-solr.sh](hadoop-lab/solr/scripts/start-solr.sh) | Start SolrCloud against ZooKeeper |
| [04-spark/scripts/](04-spark/scripts/) | `submit-groupby.sh`, `submit-skew.sh`, and the two Python jobs |
| [05-kafka/scripts/](05-kafka/scripts/) | `producer.py`, `consumer.py`, `reassign-app-events.json` |
| [06-hbase/scripts/](06-hbase/scripts/) | Create `user_logs` with 10 regions, load 1,000,000 rows |
| [07-solr/scripts/](07-solr/scripts/) | Create `app_logs`, index 50,000 logs, run the three queries |

## What the documentation contains

Open the Word file. The `README.md` beside it is only a pointer.

| Part | Write-up | What is inside |
|------|----------|----------------|
| 1. Environment | [01-environment/Part1-Lab-Notes.docx](01-environment/Part1-Lab-Notes.docx) | Docker, kubectl, Kind, and bringing up HDFS, YARN, ZooKeeper, Kafka, HBase, and Solr. Markdown copies are in the same folder. Screenshots in `01-environment/screenshots/` show the cluster, the HDFS report, YARN nodes, ZooKeeper `ruok`, Kafka brokers, HBase, and Solr. |
| 2. HDFS | [02-hdfs/Part2-HDFS-Administration.docx](02-hdfs/Part2-HDFS-Administration.docx) | Upload of the NYC yellow taxi parquet, replication 3 on `/datasets/nyc-taxi`, a DataNode failure and how the blocks came back, the balancer, and a snapshot. The 14 screenshots are in the document and in `02-hdfs/screenshots/`. |
| 3. YARN | [03-yarn/Part3-YARN-Capacity-Scheduler.docx](03-yarn/Part3-YARN-Capacity-Scheduler.docx) | The two queues, WordCount on `production`, a second job on `development`, the ResourceManager UI, and preemption. |
| 4. Spark | [04-spark/Part4-Spark-on-YARN.docx](04-spark/Part4-Spark-on-YARN.docx) | GroupBy of the taxi data back to HDFS as Parquet, executor 1 GB, driver 512 MB, dynamic allocation, then the skewed join and the salt fix. History Server screenshots are in `04-spark/screenshots/`. |
| 5. Kafka | [05-kafka/Part5-Kafka-Administration.docx](05-kafka/Part5-Kafka-Administration.docx) | Topic `app-events` (6 partitions, replication 3), 100,000 messages, consumer lag, killing a broker, and the partition reassignment. CLI figures are in `05-kafka/screenshots/`. |
| 6. HBase | [06-hbase/Part6-HBase-Administration.docx](06-hbase/Part6-HBase-Administration.docx) | Table `user_logs`, the salted row key, the 10 pre-split regions, the 1,000,000-row load, major compaction, and hbck2. |
| 7. Solr | [07-solr/Part7-Solr-Administration.docx](07-solr/Part7-Solr-Administration.docx) | Collection `app_logs` with 2 shards and 2 replicas, the schema (`timestamp` is `DatePointField`), 50,000 documents, and the time-range, full-text, and facet queries with timings. |
| 8. Written scenarios | [08-troubleshooting/Part8-Troubleshooting.docx](08-troubleshooting/Part8-Troubleshooting.docx) | NameNode safe mode, Spark streaming lag while tasks still finish, and a rolling upgrade from Hadoop 3.3.4 to 3.3.6. |

The full bring-up guide (install commands, image list, DNS names, and the file map) is [hadoop-lab/README.md](hadoop-lab/README.md).

## Setup

Install Docker, kubectl, and Kind, create the Kind cluster, then apply the manifests. Every command is in [hadoop-lab/README.md](hadoop-lab/README.md). Short version, from the VM where this tree lives at `/opt/hadoop-lab`:

```bash
kind create cluster --name hadoop-lab --config /root/kind-cluster.yaml
kubectl create namespace hadoop

kubectl apply -f /opt/hadoop-lab/hdfs/manifests/
kubectl apply -f /opt/hadoop-lab/yarn/manifests/
kubectl apply -f /opt/hadoop-lab/zookeeper/manifests/
kubectl rollout status statefulset/zk -n hadoop --timeout=300s
kubectl apply -f /opt/hadoop-lab/kafka/manifests/
kubectl apply -f /opt/hadoop-lab/hbase/manifests/
kubectl apply -f /opt/hadoop-lab/solr/manifests/
```

Images: `apache/hadoop:3.3.6`, `zookeeper:3.9`, `apache/kafka:3.9.1`, `openeuler/hbase:2.6.5-oe2403sp3`, `solr:9.8`, `apache/spark:3.5.5`.

```bash
kubectl get pods,svc -n hadoop -o wide
```

Expected: 1 NameNode, 3 DataNodes, 1 ResourceManager, 2 NodeManagers, 3 ZooKeeper, 3 Kafka brokers, 1 HBase Master, 2 RegionServers, 2 Solr. DataNodes were scaled from 2 to 3 so replication 3 on the taxi data can be satisfied.

The taxi parquet files stayed on the VM at `/opt/hadoop-lab/hdfs/data/`. February through June are each over 100 MB, which GitHub rejects. [hadoop-lab/hdfs/data/README.md](hadoop-lab/hdfs/data/README.md) names the files. January is truncated and was not loaded.


