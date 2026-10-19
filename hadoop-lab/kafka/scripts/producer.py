#!/usr/bin/env python3
"""Part 5. Publish 100,000 messages to the Kafka topic app-events.

  python producer.py
  python producer.py --count 100000

Run it from a pod that can resolve the Kafka DNS names.
"""
import argparse
import json
import os
import sys
import time

from kafka import KafkaProducer
from kafka.errors import KafkaError

DEFAULT_BOOTSTRAP = ",".join(
    [
        "kafka-0.kafka-hs.hadoop.svc.cluster.local:9092",
        "kafka-1.kafka-hs.hadoop.svc.cluster.local:9092",
        "kafka-2.kafka-hs.hadoop.svc.cluster.local:9092",
    ]
)
EVENT_TYPES = ("click", "view", "purchase", "login", "logout")


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bootstrap", default=os.environ.get("KAFKA_BOOTSTRAP", DEFAULT_BOOTSTRAP))
    parser.add_argument("--topic", default="app-events")
    parser.add_argument("--count", type=int, default=100000)
    return parser.parse_args()


def main():
    args = parse_args()
    if args.count < 1:
        raise SystemExit("--count must be >= 1")

    servers = [s.strip() for s in args.bootstrap.split(",") if s.strip()]
    errors = []

    def on_error(exc):
        errors.append(exc)

    producer = KafkaProducer(
        bootstrap_servers=servers,
        acks="all",
        retries=5,
        linger_ms=20,
        batch_size=32768,
        key_serializer=lambda k: k.encode("utf-8"),
        value_serializer=lambda v: json.dumps(v).encode("utf-8"),
    )

    started = time.time()
    try:
        for i in range(args.count):
            user_id = i % 10000
            payload = {
                "event_id": i,
                "user_id": user_id,
                "event_type": EVENT_TYPES[i % len(EVENT_TYPES)],
                "ts": int(time.time() * 1000),
                "amount": round((i % 500) / 10.0, 2),
            }
            # Key is the user id so one user's events stay on one
            # partition, while 10,000 users still spread across 6 partitions.
            producer.send(args.topic, key=str(user_id), value=payload).add_errback(on_error)
            if i and i % 10000 == 0:
                producer.flush()
                print("sent %s" % i, flush=True)
        producer.flush()
    except KafkaError as exc:
        print("producer failed: %s" % exc, file=sys.stderr)
        return 1
    finally:
        producer.close()

    elapsed = time.time() - started
    print(
        "RESULT sent=%s errors=%s seconds=%.1f topic=%s"
        % (args.count, len(errors), elapsed, args.topic)
    )
    if errors:
        print("first error: %s" % errors[0], file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
