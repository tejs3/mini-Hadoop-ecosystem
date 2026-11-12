# Docker images used

| Service    | Image                         | Tag              | Local Dockerfile        |
|------------|-------------------------------|------------------|-------------------------|
| HDFS/YARN  | apache/hadoop                 | 3.3.6            | hdfs/Dockerfile, yarn/Dockerfile |
| Spark      | apache/spark                  | 3.5.5            | spark/Dockerfile        |
| ZooKeeper  | zookeeper                     | 3.9              | zookeeper/Dockerfile    |
| Kafka      | apache/kafka                  | 3.9.1            | kafka/Dockerfile        |
| HBase      | openeuler/hbase               | 2.6.5-oe2403sp3  | hbase/Dockerfile        |
| Solr       | solr                          | 9.8              | solr/Dockerfile         |

Load into Kind:
  kind load docker-image apache/hadoop:3.3.6 --name hadoop-lab
  kind load docker-image apache/spark:3.5.5 --name hadoop-lab
  kind load docker-image zookeeper:3.9 --name hadoop-lab
  kind load docker-image apache/kafka:3.9.1 --name hadoop-lab
  kind load docker-image openeuler/hbase:2.6.5-oe2403sp3 --name hadoop-lab
  kind load docker-image solr:9.8 --name hadoop-lab
