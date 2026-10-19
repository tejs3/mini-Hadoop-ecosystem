#!/bin/bash
# Part 6. Create user_logs with column family info and 10 regions.
#
# Row key:  SS|UUUUUUUU|RRRRRRRRRRRRR
#   SS            two-digit salt, user_id % 10  (00 through 09)
#   UUUUUUUU      user id, zero padded
#   RRRRRRRRRRRRR reverse timestamp (9999999999999 - event time)
#
# A plain timestamp or a plain user id as the first bytes would send
# every new write to the last region. The salt is the first bytes, and
# the split points are 01|, 02|, ... 09|, so each salt owns one region.
# Users are spread across 10 regions. Events for one user stay together,
# newest first, because of the reverse timestamp.
#
# 9 split points => 10 regions.

set -euo pipefail

POD=$(kubectl get pods -n hadoop --no-headers | awk '/^hbase-master/ {print $1; exit}')
if [[ -z "$POD" ]]; then
  echo "hbase-master pod not found" >&2
  exit 1
fi

kubectl exec -n hadoop "$POD" -- bash -lc 'cat > /tmp/create_user_logs.rb << "EOF"
create "user_logs", {NAME => "info", VERSIONS => 1}, {SPLITS => ["01|", "02|", "03|", "04|", "05|", "06|", "07|", "08|", "09|"]}
list_regions "user_logs"
EOF
hbase shell /tmp/create_user_logs.rb'
