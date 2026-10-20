# Part 5 — Kafka Administration

Topic `app-events`, 6 partitions, replication factor 3, `min.insync.replicas=2`. Producer of 100,000 messages, consumer lag, broker failure, and partition reassignment.

## Documentation

Open [Part5-Kafka-Administration.pdf](Part5-Kafka-Administration.pdf). CLI figures are in the document and in `screenshots/`. Raw command output is in `screenshots/raw/`.

## Scripts

| File | What it does |
|------|----------------|
| `scripts/producer.py` | Publishes messages to `app-events` |
| `scripts/consumer.py` | Reads the topic and prints lag |
| `scripts/reassign-app-events.json` | Partition reassignment used after recovery |

Bootstrap servers: `kafka-0.kafka-hs.hadoop.svc.cluster.local:9092` and the same host for kafka-1 and kafka-2.

The VM copy is [../hadoop-lab/kafka/](../hadoop-lab/kafka/) (`conf/`, `manifests/`, `scripts/`). That is `/opt/hadoop-lab/kafka` on the lab host.
