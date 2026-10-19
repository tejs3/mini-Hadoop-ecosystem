#!/bin/bash
# Skew demo. Creates a 90% hot pickup zone, times the plain groupBy,
# then times the salted + repartitioned groupBy and an AQE skew join.
# Same executor/driver/dynamic-allocation settings as the groupBy job.
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
spark_submit_common nyc-taxi-skew "$DIR/taxi_skew.py"
