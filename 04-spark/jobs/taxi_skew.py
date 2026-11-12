#!/usr/bin/env python3
"""Part 4 skew demo.

The real pickup zones are not skewed enough to show the problem, so this
job creates the skew on purpose and then removes it.

How the skew is created
-----------------------
Read the same NYC yellow-taxi parquet as the groupBy job
(hdfs://namenode:9000/datasets/nyc-taxi/*.parquet).
Then replace the pickup zone:

  90 percent of rows are forced to PULocationID 1
  the other 10 percent keep their real PULocationID

One key now owns almost every row. A normal groupBy shuffle puts that
key in a single task, so one task does almost all the work.

How it is fixed
---------------
1. Salting. The hot zone (key 1) gets a random bucket 0-31. Other zones
   keep a stable bucket from the zone id.
2. Repartition into 32 salt buckets before the partial aggregate, so
   the hot zone is split across many tasks.
3. Add the salted partial totals back together by pickup_key.
4. AQE. Join the same skewed rows to a small zone table. First with AQE
   off, then with adaptive execution and skew-join splitting on.
   Coalesce is off so AQE splits the hot partition instead of merging
   the small ones into it.

Prints RESULT lines with the timings for the write-up.
"""
import time

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

INPUT_PATH = "hdfs://namenode:9000/datasets/nyc-taxi/*.parquet"
SKEW_PATH = "hdfs://namenode:9000/output/nyc-taxi/skew-input"
BEFORE_PATH = "hdfs://namenode:9000/output/nyc-taxi/skew-before"
AFTER_PATH = "hdfs://namenode:9000/output/nyc-taxi/skew-after"
SALT_BUCKETS = 32


def agg(frame):
    return frame.groupBy("pickup_key").agg(
        F.count(F.lit(1)).alias("trip_count"),
        F.round(F.sum("total_amount"), 2).alias("total_fare"),
        F.round(F.avg("trip_distance"), 3).alias("avg_distance"),
    )


def main():
    spark = SparkSession.builder.appName("nyc-taxi-skew").getOrCreate()
    spark.sparkContext.setLogLevel("WARN")

    raw = spark.read.parquet(INPUT_PATH).select(
        "PULocationID", "payment_type", "total_amount", "trip_distance"
    )
    # Intentional skew: 90% of trips are stamped onto zone 1.
    skewed = raw.withColumn(
        "pickup_key",
        F.when(F.rand(seed=7) < F.lit(0.90), F.lit(1)).otherwise(
            F.col("PULocationID").cast("int")
        ),
    )
    skewed.write.mode("overwrite").parquet(SKEW_PATH)
    skewed = spark.read.parquet(SKEW_PATH)

    total = skewed.count()
    hot = skewed.filter(F.col("pickup_key") == 1).count()
    print("SKEW total_rows=%s hot_key=1 hot_rows=%s hot_pct=%.1f" % (total, hot, 100.0 * hot / total))

    # Before: one groupBy, AQE off. The hot key stays in one task.
    spark.conf.set("spark.sql.adaptive.enabled", "false")
    spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "false")
    spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "-1")
    started = time.time()
    agg(skewed).write.mode("overwrite").parquet(BEFORE_PATH)
    before_s = time.time() - started
    before_rows = spark.read.parquet(BEFORE_PATH).count()

    # After: salt the hot key into 32 buckets and repartition on the salt
    # before the partial aggregate. AQE is off so this comparison is the
    # salt and the repartition, not an adaptive plan.
    spark.conf.set("spark.sql.adaptive.enabled", "false")
    salted = skewed.withColumn(
        "salt",
        F.when(
            F.col("pickup_key") == 1,
            (F.rand(seed=11) * F.lit(SALT_BUCKETS)).cast("int"),
        ).otherwise(F.pmod(F.col("pickup_key"), F.lit(SALT_BUCKETS))),
    )
    started = time.time()
    partial = (
        salted.repartition(SALT_BUCKETS, "salt")
        .groupBy("pickup_key", "salt")
        .agg(
            F.count(F.lit(1)).alias("trip_count"),
            F.sum("total_amount").alias("total_fare"),
            F.sum("trip_distance").alias("sum_distance"),
        )
    )
    fixed = partial.groupBy("pickup_key").agg(
        F.sum("trip_count").alias("trip_count"),
        F.round(F.sum("total_fare"), 2).alias("total_fare"),
        F.round(F.sum("sum_distance") / F.sum("trip_count"), 3).alias("avg_distance"),
    )
    fixed.write.mode("overwrite").parquet(AFTER_PATH)
    after_s = time.time() - started
    after_rows = spark.read.parquet(AFTER_PATH).count()

    # Same skewed rows joined to a tiny zone table.
    # Broadcast is off, so Spark shuffle-joins. The hot key piles onto
    # one partition. The second run lets AQE split that partition.
    zones = (
        skewed.select("pickup_key")
        .distinct()
        .withColumn("zone_name", F.concat(F.lit("zone-"), F.col("pickup_key").cast("string")))
    )
    spark.conf.set("spark.sql.adaptive.enabled", "false")
    spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "false")
    started = time.time()
    join_before_n = skewed.join(zones, "pickup_key", "inner").count()
    join_before_s = time.time() - started

    # The hot shuffle partition is only about 7 MB once it is compressed,
    # so the split target has to be smaller than that or AQE leaves it whole.
    # Coalesce stays off so the small keys are not folded into the hot one.
    spark.conf.set("spark.sql.adaptive.enabled", "true")
    spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
    spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "false")
    spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionFactor", "2")
    spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256KB")
    spark.conf.set("spark.sql.adaptive.advisoryPartitionSizeInBytes", "512KB")
    started = time.time()
    join_after_n = skewed.join(zones, "pickup_key", "inner").count()
    join_after_s = time.time() - started

    print(
        "RESULT job=skew_before rows=%s seconds=%.1f output=%s"
        % (before_rows, before_s, BEFORE_PATH)
    )
    print(
        "RESULT job=skew_after salt=%s rows=%s seconds=%.1f output=%s"
        % (SALT_BUCKETS, after_rows, after_s, AFTER_PATH)
    )
    print(
        "RESULT job=join_no_aqe rows=%s seconds=%.1f" % (join_before_n, join_before_s)
    )
    print(
        "RESULT job=join_aqe rows=%s seconds=%.1f" % (join_after_n, join_after_s)
    )
    print(
        "RESULT comparison groupby_before_s=%.1f groupby_after_s=%.1f join_before_s=%.1f join_after_s=%.1f"
        % (before_s, after_s, join_before_s, join_after_s)
    )
    spark.stop()


if __name__ == "__main__":
    main()
