# Part 3 — YARN Capacity Scheduler

Two queues: `production` 60% capacity, max 80%, and `development` 40% capacity, max 100%. WordCount on production, a second job on development, ResourceManager UI, and preemption.

## Documentation

Open [Part3-YARN-Capacity-Scheduler.pdf](Part3-YARN-Capacity-Scheduler.pdf). The UI screenshots are inside that file.

## Config

[capacity-scheduler.xml](capacity-scheduler.xml) is the scheduler file for this part. The same file is what the cluster uses, at `hadoop-lab/yarn/conf/capacity-scheduler.xml`.

The YARN copy from `/opt/hadoop-lab/yarn` is in [../hadoop-lab/yarn/](../hadoop-lab/yarn/) (`conf/`, `manifests/`, `scripts/start-nm.sh`). There is no `default` queue. Spark jobs in Part 4 use `--queue development`.

Run MapReduce clients from the NameNode pod. Running them inside the ResourceManager pod OOM-kills that pod. See `TROUBLESHOOTING.md`.
