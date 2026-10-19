#!/bin/bash
# Three queries against app_logs, then the same three with one change each.
# QTime in the response header is the number to write down.
#
#   BASE=http://127.0.0.1:8983/solr/app_logs ./queries.sh
# message-timeout uses rows=2 so the response shows sample documents.
# Compare QTime with rows=0 on every query, or the stored-field fetch
# dominates the number.

set -u
BASE="${BASE:-http://127.0.0.1:8983/solr/app_logs}"

run() {
  local name="$1"
  shift
  echo "===== ${name} ====="
  curl -sG "$BASE/select" "$@"
  echo
}

# 1. Last 7 days. The range sits in q, so it is scored with the match.
run "time-range-in-q" \
  --data-urlencode "q=timestamp:[NOW-7DAYS TO NOW]" \
  --data-urlencode "rows=0" \
  --data-urlencode "wt=json"

# 1b. Same range as a filter. Filters are cached and are not scored.
run "time-range-in-fq" \
  --data-urlencode "q=*:*" \
  --data-urlencode "fq=timestamp:[NOW-7DAYS TO NOW]" \
  --data-urlencode "rows=0" \
  --data-urlencode "wt=json"

# 2. Full text on message. text_general has already split the field into words.
run "message-timeout" \
  --data-urlencode "q=message:timeout" \
  --data-urlencode "rows=2" \
  --data-urlencode "fl=id,level,timestamp,message" \
  --data-urlencode "wt=json"

# 2b. A leading wildcard cannot use the word index.
run "message-leading-wildcard" \
  --data-urlencode "q=message:*timeout*" \
  --data-urlencode "rows=0" \
  --data-urlencode "wt=json"

# 3. Facet on level with the default method.
run "facet-level" \
  --data-urlencode "q=*:*" \
  --data-urlencode "rows=0" \
  --data-urlencode "facet=true" \
  --data-urlencode "facet.field=level" \
  --data-urlencode "wt=json"

# 3b. enum is the method for a field with a handful of values.
run "facet-level-enum" \
  --data-urlencode "q=*:*" \
  --data-urlencode "rows=0" \
  --data-urlencode "facet=true" \
  --data-urlencode "facet.field=level" \
  --data-urlencode "facet.method=enum" \
  --data-urlencode "wt=json"
