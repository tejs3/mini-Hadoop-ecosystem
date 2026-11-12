#!/bin/bash
# Part 6. Copy the load script onto hbase-master and run it.
# Creates nothing by itself. Run create_user_logs.sh first.
# One million rows. Expect several minutes. The shell prints
# a line every 100,000 rows.

set -euo pipefail

NS=hadoop
DIR=$(cd "$(dirname "$0")" && pwd)
POD=$(kubectl get pods -n "$NS" --no-headers | awk '/^hbase-master/ {print $1; exit}')
if [[ -z "$POD" ]]; then
  echo "hbase-master pod not found" >&2
  exit 1
fi

kubectl cp "$DIR/load_user_logs.rb" "$NS/$POD:/tmp/load_user_logs.rb"
kubectl exec -n "$NS" "$POD" -- hbase shell /tmp/load_user_logs.rb

echo "Row count (this scans the table):"
kubectl exec -i -n "$NS" "$POD" -- hbase shell <<'EOF'
count 'user_logs', INTERVAL => 200000
EOF
