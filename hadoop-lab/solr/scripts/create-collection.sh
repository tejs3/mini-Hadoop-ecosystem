#!/bin/bash
# Part 7: app_logs with 2 shards, 2 replicas
solr create_collection -c app_logs -shards 2 -replicationFactor 2 \
  -d /opt/solr/server/solr/configsets/app_logs_config || \
solr zk upconfig -n app_logs_config -d /opt/solr/server/solr/configsets/app_logs_config -z zk-0.zk.hadoop.svc.cluster.local:2181
