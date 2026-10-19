#!/usr/bin/env python3
"""Index 50,000 sample log documents into the SolrCloud collection app_logs.

  python3 index_app_logs.py --url http://127.0.0.1:8983/solr/app_logs

Timestamps are spread over the last 30 days so a 7-day range does not match
every document. Every 5th message contains the word "timeout".
"""
import argparse
import json
import time
import urllib.request
from datetime import datetime, timedelta, timezone

LEVELS = ("INFO", "WARN", "ERROR")
WORDS = ("started", "stopped", "retry", "disk", "connection", "refused", "healthy", "queue")


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True, help="collection base, no trailing slash")
    parser.add_argument("--count", type=int, default=50000)
    parser.add_argument("--batch", type=int, default=2000)
    return parser.parse_args()


def level_of(i):
    if i % 10 == 0:
        return "ERROR"
    if i % 10 == 1:
        return "WARN"
    return "INFO"


def timestamp_of(i, now):
    # 4 of every 10 documents fall inside the last 7 days.
    if i % 10 < 4:
        age_days = (i % 7)
    else:
        age_days = 8 + (i % 22)
    when = now - timedelta(days=age_days, minutes=i % 60)
    return when.strftime("%Y-%m-%dT%H:%M:%SZ")


def message_of(i):
    if i % 5 == 0:
        return "connection timeout while talking to broker %s" % (i % 3)
    return "%s service %s on node %s" % (WORDS[i % len(WORDS)], i % 7, i % 3)


def post(url, docs, commit):
    target = url + "/update" + ("?commit=true" if commit else "")
    body = json.dumps(docs).encode("utf-8")
    req = urllib.request.Request(target, data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
    status = payload.get("responseHeader", {}).get("status", 1)
    if status != 0:
        raise SystemExit("update failed: %s" % payload)


def main():
    args = parse_args()
    now = datetime.now(timezone.utc).replace(microsecond=0)
    started = time.time()
    batch = []
    for i in range(args.count):
        batch.append(
            {
                "id": "log-%06d" % i,
                "timestamp": timestamp_of(i, now),
                "level": level_of(i),
                "message": message_of(i),
            }
        )
        if len(batch) >= args.batch:
            post(args.url, batch, commit=False)
            print("sent %s" % (i + 1), flush=True)
            batch = []
    if batch:
        post(args.url, batch, commit=False)
    post(args.url, [], commit=True)
    elapsed = time.time() - started
    print("RESULT indexed=%s seconds=%.1f url=%s" % (args.count, elapsed, args.url))
    print("NOW %s" % now.strftime("%Y-%m-%dT%H:%M:%SZ"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
