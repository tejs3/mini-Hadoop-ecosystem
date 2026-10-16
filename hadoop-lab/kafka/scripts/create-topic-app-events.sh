#!/bin/bash
# Part 5: topic app-events, 6 partitions, RF=3
kafka-topics.sh --bootstrap-server kafka-0.kafka.hadoop.svc.cluster.local:9092 \
  --create --if-not-exists \
  --topic app-events \
  --partitions 6 \
  --replication-factor 3
kafka-topics.sh --bootstrap-server kafka-0.kafka.hadoop.svc.cluster.local:9092 \
  --describe --topic app-events
