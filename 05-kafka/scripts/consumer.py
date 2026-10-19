#!/usr/bin/env python3
"""Part 5. Read app-events and print consumer lag while reading.

  python consumer.py
  python consumer.py --max-messages 100000

Group id is app-events-lag.
"""
import argparse
import json
import os
import sys
import time

from kafka import KafkaConsumer, TopicPartition

DEFAULT_BOOTSTRAP = ",".join(
    [
        "kafka-0.kafka-hs.hadoop.svc.cluster.local:9092",
        "kafka-1.kafka-hs.hadoop.svc.cluster.local:9092",
        "kafka-2.kafka-hs.hadoop.svc.cluster.local:9092",
    ]
)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bootstrap", default=os.environ.get("KAFKA_BOOTSTRAP", DEFAULT_BOOTSTRAP))
    parser.add_argument("--topic", default="app-events")
    parser.add_argument("--group", default="app-events-lag")
    parser.add_argument("--max-messages", type=int, default=100000)
    parser.add_argument("--report-every", type=int, default=5000)
    parser.add_argument(
        "--lag-only",
        action="store_true",
        help="print lag once and exit, without consuming the backlog",
    )
    return parser.parse_args()


def servers_of(raw):
    return [s.strip() for s in raw.split(",") if s.strip()]


def lag_total(consumer):
    assignment = consumer.assignment()
    if not assignment:
        return None, {}
    ends = consumer.end_offsets(list(assignment))
    per_partition = {}
    total = 0
    for tp, end_off in ends.items():
        current = consumer.position(tp)
        lag = max(0, end_off - current)
        per_partition[tp.partition] = lag
        total += lag
    return total, per_partition


def lag_only(args, servers):
    # Read committed offsets for the group. Do not join the group and
    # do not consume, so this can be run while the real consumer is down
    # during the broker-failure test.
    probe = KafkaConsumer(
        bootstrap_servers=servers,
        group_id=args.group,
        enable_auto_commit=False,
    )
    try:
        parts = probe.partitions_for_topic(args.topic)
        if not parts:
            raise SystemExit("topic %s has no partitions (is it created?)" % args.topic)
        tps = [TopicPartition(args.topic, p) for p in sorted(parts)]
        ends = probe.end_offsets(tps)
        begins = probe.beginning_offsets(tps)
        print("topic=%s group=%s" % (args.topic, args.group))
        total = 0
        for tp in tps:
            committed = probe.committed(tp)
            current = committed.offset if committed is not None else begins[tp]
            lag = max(0, ends[tp] - current)
            total += lag
            print(
                "partition=%s committed=%s end=%s lag=%s"
                % (tp.partition, current, ends[tp], lag)
            )
        print("RESULT group=%s total_lag=%s" % (args.group, total))
    finally:
        probe.close()


def main():
    args = parse_args()
    servers = servers_of(args.bootstrap)
    if args.lag_only:
        lag_only(args, servers)
        return 0

    consumer = KafkaConsumer(
        args.topic,
        bootstrap_servers=servers,
        group_id=args.group,
        enable_auto_commit=False,
        auto_offset_reset="earliest",
        consumer_timeout_ms=15000,
        value_deserializer=lambda b: json.loads(b.decode("utf-8")),
    )
    read = 0
    started = time.time()
    try:
        while read < args.max_messages:
            batch = consumer.poll(timeout_ms=2000, max_records=500)
            if not batch:
                total, per_part = lag_total(consumer)
                print("idle read=%s lag=%s per_partition=%s" % (read, total, per_part), flush=True)
                break
            for _tp, records in batch.items():
                read += len(records)
            consumer.commit()
            if read % args.report_every < 500 or read >= args.max_messages:
                total, per_part = lag_total(consumer)
                print(
                    "read=%s lag=%s per_partition=%s" % (read, total, per_part),
                    flush=True,
                )
    finally:
        consumer.close()

    elapsed = time.time() - started
    print("RESULT group=%s read=%s seconds=%.1f" % (args.group, read, elapsed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
