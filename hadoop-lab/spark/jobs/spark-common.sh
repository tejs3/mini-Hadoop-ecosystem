#!/bin/bash
# Shared spark-submit flags for Part 4.
# Executor 1g, driver 512m, dynamic allocation on.
# Python 3.10 is shipped with the job because the NodeManager image
# has no Python 3.8 (Spark 3.5 needs 3.8+).

SPARK_ARCHIVES="${SPARK_ARCHIVES:-hdfs://namenode:9000/spark/python-3.10.tgz#pyenv}"
SPARK_PYTHON="${SPARK_PYTHON:-./pyenv/python/bin/python3}"

spark_submit_common() {
  local name="$1"
  local script="$2"
  spark-submit \
    --master yarn \
    --deploy-mode cluster \
    --name "$name" \
    --queue development \
    --executor-memory 1g \
    --executor-cores 1 \
    --driver-memory 512m \
    --archives "$SPARK_ARCHIVES" \
    --conf spark.pyspark.python="$SPARK_PYTHON" \
    --conf spark.pyspark.driver.python="$SPARK_PYTHON" \
    --conf spark.executorEnv.PYSPARK_PYTHON="$SPARK_PYTHON" \
    --conf spark.yarn.appMasterEnv.PYSPARK_PYTHON="$SPARK_PYTHON" \
    --conf spark.executor.memoryOverhead=256m \
    --conf spark.driver.memoryOverhead=256m \
    --conf spark.dynamicAllocation.enabled=true \
    --conf spark.dynamicAllocation.shuffleTracking.enabled=true \
    --conf spark.dynamicAllocation.minExecutors=1 \
    --conf spark.dynamicAllocation.initialExecutors=1 \
    --conf spark.dynamicAllocation.maxExecutors=2 \
    --conf spark.sql.shuffle.partitions=8 \
    --conf spark.eventLog.enabled=true \
    --conf spark.eventLog.dir=hdfs://namenode:9000/spark-logs \
    --conf spark.yarn.stagingDir=hdfs://namenode:9000/spark/staging \
    "$script"
}
