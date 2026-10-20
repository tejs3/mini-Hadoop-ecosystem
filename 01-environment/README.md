# Part 1 — Environment Setup

Kind cluster `hadoop-lab` on the lab VM, namespace `hadoop`. HDFS, YARN, ZooKeeper, Kafka, HBase, and Solr talk to each other by Kubernetes Service DNS.

## Documentation

| File | What it is |
|------|------------|
| [Part1-Lab-Notes.pdf](Part1-Lab-Notes.pdf) | The report, with the steps I ran |
| [PART1-Lab-Notes.md](PART1-Lab-Notes.md) | Same notes in Markdown |
| [PART1-Environment-Setup.md](PART1-Environment-Setup.md) | Setup notes with the interview-style explanation of each step |

Screenshots of the running cluster are in `screenshots/` (overview, HDFS report, YARN nodes, ZooKeeper ruok, Kafka brokers, HBase, Solr).

## Cluster files

Dockerfiles, configs, and manifests are the copy of `/opt/hadoop-lab` in [../hadoop-lab/](../hadoop-lab/README.md):

- `hdfs`, `yarn`, `zookeeper`, `kafka`, `hbase`, `solr`, `spark`
- Bring-up script: `hadoop-lab/scripts/bringup-part1.sh`
- Bring-up commands: `hadoop-lab/README.md`
