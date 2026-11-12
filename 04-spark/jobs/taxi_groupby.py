#!/usr/bin/env python3
"""Part 4. Read the NYC taxi parquet from HDFS, aggregate, write Parquet.

Input is the Part 2 dataset: /datasets/nyc-taxi
(yellow trip data, Feb-Jun 2019).

Aggregation: one row per pickup zone + payment type, with trip count,
total fare, and average distance.
"""
import time

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

# snap-test.txt sits in the same directory and is not parquet.
INPUT_PATH = "hdfs://namenode:9000/datasets/nyc-taxi/*.parquet"
OUTPUT_PATH = "hdfs://namenode:9000/output/nyc-taxi/groupby"


def main():
    spark = (
        SparkSession.builder.appName("nyc-taxi-groupby")
        .getOrCreate()
    )
    started = time.time()
    df = spark.read.parquet(INPUT_PATH)
    print("INPUT_COLUMNS " + ",".join(df.columns))

    # 2019 yellow-trip parquet uses these names. Fail here if a file
    # does not match, instead of writing an empty aggregation.
    for required in ("PULocationID", "payment_type", "total_amount", "trip_distance"):
        if required not in df.columns:
            raise SystemExit("missing column %s" % required)

    result = (
        df.groupBy("PULocationID", "payment_type")
        .agg(
            F.count(F.lit(1)).alias("trip_count"),
            F.round(F.sum("total_amount"), 2).alias("total_fare"),
            F.round(F.avg("trip_distance"), 3).alias("avg_distance"),
        )
        .orderBy(F.desc("trip_count"))
    )
    result.write.mode("overwrite").parquet(OUTPUT_PATH)
    elapsed = time.time() - started
    rows = spark.read.parquet(OUTPUT_PATH).count()
    print("RESULT job=groupby rows=%s write_seconds=%.1f output=%s" % (rows, elapsed, OUTPUT_PATH))
    spark.stop()


if __name__ == "__main__":
    main()
