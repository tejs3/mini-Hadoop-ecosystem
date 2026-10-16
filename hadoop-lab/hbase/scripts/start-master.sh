#!/bin/bash
set -e
HBASE_HOME=/usr/local/hbase
CONF="$HBASE_HOME/conf"
cp /config/hbase-site.xml "$CONF/hbase-site.xml"
cp /config/core-site.xml "$CONF/core-site.xml"
cp /config/hdfs-site.xml "$CONF/hdfs-site.xml"
export HBASE_MANAGES_ZK=false
for i in $(seq 1 30); do
  if hdfs --config "$CONF" dfs -mkdir -p /hbase 2>/dev/null; then
    break
  fi
  echo "waiting for HDFS"
  sleep 5
done
exec "$HBASE_HOME/bin/hbase" --config "$CONF" master start
