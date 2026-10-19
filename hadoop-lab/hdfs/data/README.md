# Dataset for Part 2 (HDFS upload)

**Source:** NYC TLC Yellow Taxi Trip Records (public)  
**URL base:** https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page  
**Files:** `yellow_tripdata_2019-01.parquet` … `2019-06.parquet`  
**Total size:** ~624 MB (over the 500 MB requirement)

Next step (on the lab VM): copy these files up, then upload into HDFS.

The parquet files themselves are on the VM at `/opt/hadoop-lab/hdfs/data/`. They are not in git. February through June are each larger than GitHub's 100 MB file limit. January is truncated and was not used by Spark.
