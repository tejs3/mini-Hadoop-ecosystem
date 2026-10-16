#!/bin/bash
# Part 6: user_logs with CF info, pre-split >=10 regions
# Row key design: reverse(userId) + "#" + reverse(ts)  -> avoids hotspotting
hbase shell <<'HBASE'
create 'user_logs',
  {NAME => 'info', VERSIONS => 1, COMPRESSION => 'SNAPPY'},
  SPLITS => ['0','1','2','3','4','5','6','7','8','9']
describe 'user_logs'
HBASE
