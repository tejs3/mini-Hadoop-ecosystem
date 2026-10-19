#!/bin/bash
# One Spark job.
# Reads  hdfs://namenode:9000/datasets/nyc-taxi
# Writes hdfs://namenode:9000/output/nyc-taxi/groupby
# Executor memory 1g, driver memory 512m, dynamic allocation on.
#
# Run this inside a pod that has spark-submit and the Hadoop client config.

set -euo pipefail

DIR=$(cd "$(dirname "$0")" && pwd)
export PATH="/opt/spark/bin:${PATH}"
# shellcheck source=spark-common.sh
source "$DIR/spark-common.sh"

if command -v hdfs >/dev/null 2>&1; then
  hdfs dfs -mkdir -p /spark-logs /output/nyc-taxi
else
  /opt/spark/bin/spark-class org.apache.hadoop.fs.FsShell -mkdir -p /spark-logs /output/nyc-taxi
fi
spark_submit_common nyc-taxi-groupby "$DIR/taxi_groupby.py"
