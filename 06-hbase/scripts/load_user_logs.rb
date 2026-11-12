# Part 6. Load 1,000,000 rows into user_logs.
# Run with:  hbase shell load_user_logs.rb
# The shell wrapper copies this file onto hbase-master and runs it.
#
# Row key matches create_user_logs.sh:
#   salt = user_id % 10, then user id, then reverse timestamp.
# Writes go through a BufferedMutator so they are batched.
# WAL stays on. This is one client on the master, which is enough
# for a million short rows and does not need a YARN MapReduce config
# on the HBase pod.

require 'java'

java_import 'org.apache.hadoop.hbase.HBaseConfiguration'
java_import 'org.apache.hadoop.hbase.client.ConnectionFactory'
java_import 'org.apache.hadoop.hbase.client.Put'
java_import 'org.apache.hadoop.hbase.client.BufferedMutatorParams'
java_import 'org.apache.hadoop.hbase.TableName'
java_import 'org.apache.hadoop.hbase.util.Bytes'

ROWS = 1_000_000
BASE_TS = 1_700_000_000_000
TYPES = %w[pickup dropoff payment cancel rating]
CF = Bytes.toBytes('info')

conf = HBaseConfiguration.create
conn = ConnectionFactory.createConnection(conf)
params = BufferedMutatorParams.new(TableName.valueOf('user_logs'))
params.writeBufferSize(8 * 1024 * 1024)
mutator = conn.getBufferedMutator(params)

begin
  ROWS.times do |i|
    user_id = i % 50_000
    salt = user_id % 10
    ts = BASE_TS + i
    rev = 9_999_999_999_999 - ts
    row_key = format('%02d|%08d|%013d', salt, user_id, rev)
    amount = format('%.2f', (i % 5000) / 100.0)

    put = Put.new(Bytes.toBytes(row_key))
    put.addColumn(CF, Bytes.toBytes('user_id'), Bytes.toBytes(user_id.to_s))
    put.addColumn(CF, Bytes.toBytes('event_type'), Bytes.toBytes(TYPES[i % TYPES.length]))
    put.addColumn(CF, Bytes.toBytes('ts'), Bytes.toBytes(ts.to_s))
    put.addColumn(CF, Bytes.toBytes('amount'), Bytes.toBytes(amount))
    mutator.mutate(put)

    if i > 0 && (i % 100_000).zero?
      mutator.flush
      puts format('flushed %d', i)
    end
  end
  mutator.flush
  puts format('RESULT loaded=%d table=user_logs', ROWS)
ensure
  mutator.close
  conn.close
end
