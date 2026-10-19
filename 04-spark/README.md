# Part 4 — Spark on YARN

Spark 3.5.5 in cluster mode on YARN. GroupBy of the taxi parquet written back to HDFS, then a skewed join and a salted fix. Executor memory 1 GB, driver memory 512 MB, dynamic allocation on, queue `development`.

## Documentation

Open [Part4-Spark-on-YARN.docx](Part4-Spark-on-YARN.docx). History Server screenshots are in the document and in `screenshots/`.

## Scripts

| File | What it does |
|------|----------------|
| `scripts/spark-common.sh` | Shared spark-submit settings |
| `scripts/submit-groupby.sh` | GroupBy job |
| `scripts/taxi_groupby.py` | GroupBy application |
| `scripts/submit-skew.sh` | Skew job |
| `scripts/taxi_skew.py` | Skew, then salt 0–31 and repartition |

The same scripts are in [../hadoop-lab/spark/jobs/](../hadoop-lab/spark/jobs/), copied from `/opt/hadoop-lab/spark/jobs/`. Spark configs are in [../hadoop-lab/spark/conf/](../hadoop-lab/spark/conf/).

History Server: `http://10.1.0.213:18080/`. The event log is `hdfs://namenode:9000/spark-logs`.
