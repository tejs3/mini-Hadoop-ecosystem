# Part 7 — Solr Administration

SolrCloud collection `app_logs`, 2 shards, 2 replicas, schema for id / timestamp / level / message, 50,000 log documents, and three queries with timings.

## Documentation

Open [Part7-Solr-Administration.docx](Part7-Solr-Administration.docx). Admin UI screenshots and CLI timings are in that file and in `screenshots/`.

## Scripts

| File | What it does |
|------|----------------|
| `scripts/app_logs_schema.json` | Schema fields, including `id` |
| `scripts/add_fields.json` | The payload that was posted (`id` already exists, so it is not posted again) |
| `scripts/create_app_logs.sh` | Creates the collection. It deletes `app_logs` first |
| `scripts/index_app_logs.py` | Indexes 50,000 documents |
| `scripts/queries.sh` | Time range, message search, facet, and one variation of each |

`timestamp` is type `pdate`, class `solr.DatePointField`. `message` is `text_general` with `multiValued: false`.

The VM copy is [../hadoop-lab/solr/](../hadoop-lab/solr/) (`conf/`, `manifests/solr.yaml`, `scripts/`). That is `/opt/hadoop-lab/solr` on the lab host. Admin UI: `http://10.1.0.213:8983/solr/`.

Do not re-run `create_app_logs.sh` unless you mean to drop the indexed documents.
