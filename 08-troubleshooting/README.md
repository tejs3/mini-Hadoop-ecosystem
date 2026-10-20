# Part 8 — Troubleshooting Scenarios

Written answers for the three scenarios in the assignment:

1. HDFS NameNode stuck in safe mode after a restart.
2. A Spark Structured Streaming job reading Kafka, with lag growing while tasks still finish.
3. Rolling upgrade of Hadoop 3.3.4 to 3.3.6 on Kubernetes with no downtime.

## Documentation

Open [Part8-Troubleshooting.pdf](Part8-Troubleshooting.pdf).

The issues I actually hit on this cluster (Solr crash loop, ResourceManager OOM, hbck2 classpath, replication, and the rest) are listed in [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) at the submission root.
