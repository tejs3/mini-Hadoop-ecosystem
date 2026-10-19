# Part 6 — HBase Administration

Table `user_logs`, column family `info`, 10 pre-split regions, salted row key, 1,000,000 rows, major compaction, and hbck2.

## Documentation

Open [Part6-HBase-Administration.docx](Part6-HBase-Administration.docx). The pre-split command and `major_compact 'user_logs'` are in that file. CLI figures are also in `screenshots/`.

## Scripts

| File | What it does |
|------|----------------|
| `scripts/create_user_logs.sh` | Copies the create script and runs it on the master |
| `scripts/load_user_logs.rb` | BufferedMutator load of 1,000,000 rows |
| `scripts/load_user_logs.sh` | Runs the load |

Run the create as a file on the master: `hbase shell /tmp/create_user_logs.rb`. A kubectl stdin heredoc did not create the table.

Row key: `SS|UUUUUUUU|RRRRRRRRRRRRR` (salt = user id % 10, reversed timestamp). The VM copy is [../hadoop-lab/hbase/](../hadoop-lab/hbase/) (`conf/`, `manifests/`, `scripts/`, including `hbase-hbck2.jar`). That is `/opt/hadoop-lab/hbase` on the lab host.

hbck2 could not open `hdfs://` from its client classpath. The table itself is healthy. Details are in `TROUBLESHOOTING.md`.
