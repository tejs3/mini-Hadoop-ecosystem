# Part 2 — HDFS Administration

NYC yellow taxi parquet (Feb–Jun 2019) on HDFS, replication 3 on `/datasets/nyc-taxi`, DataNode failure and re-replication, balancer, and a snapshot.

## Documentation

Open [Part2-HDFS-Administration.pdf](Part2-HDFS-Administration.pdf). The screenshots sit next to the explanation inside that file. The same PNG files are in `screenshots/`.

## Data

`data/README.md` describes the NYC TLC files. The parquet files stay on the VM at `/opt/hadoop-lab/hdfs/data/`. February through June are each over 100 MB, so they are not in this folder. January was truncated and was not loaded. Spark reads February through June.

HDFS configs and manifests copied from the VM: [../hadoop-lab/hdfs/](../hadoop-lab/hdfs/). `conf/core-site.xml` and `conf/hdfs-site.xml` are there. Cluster default replication is 2. Replication 3 is set only on the taxi directory, after the third DataNode was added.
