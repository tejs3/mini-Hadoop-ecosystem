# Config file index

## HDFS (/opt/hadoop-lab/hdfs)
- conf/core-site.xml
- conf/hdfs-site.xml
- conf/hadoop-env.sh
- manifests/* (already deployed)
- Dockerfile

## YARN (/opt/hadoop-lab/yarn)
- conf/core-site.xml, hdfs-site.xml
- conf/yarn-site.xml
- conf/mapred-site.xml
- conf/capacity-scheduler.xml  (production 60/80, development 40/100)
- Dockerfile

## Spark (/opt/hadoop-lab/spark)
- conf/spark-defaults.conf
- conf/spark-env.sh
- conf/core-site.xml
- Dockerfile

## ZooKeeper (/opt/hadoop-lab/zookeeper)
- conf/zoo.cfg
- conf/log4j.properties
- Dockerfile

## Kafka (/opt/hadoop-lab/kafka)
- conf/server.properties
- conf/client.properties
- scripts/create-topic-app-events.sh
- Dockerfile

## HBase (/opt/hadoop-lab/hbase)
- conf/hbase-site.xml
- conf/core-site.xml, hdfs-site.xml
- conf/hbase-env.sh
- scripts/create-user-logs.sh
- docs-rowkey.txt
- Dockerfile

## Solr (/opt/hadoop-lab/solr)
- conf/solr.xml
- conf/app_logs_config/conf/{schema.xml,managed-schema.xml,solrconfig.xml}
- scripts/create-collection.sh
- scripts/sample-queries.txt
- Dockerfile
