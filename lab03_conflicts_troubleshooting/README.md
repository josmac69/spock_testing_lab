# Lab 03: Conflicts & Troubleshooting

This lab demonstrates how to configure, monitor, and troubleshoot common scenarios in a pgEdge Spock active-active cluster:
1. **Timestamp-based conflict resolution** (`last_update_wins`).
2. **Error-based conflict handling** (causing replication to halt, and how to recover).
3. **Network partition simulation** (disconnecting nodes, verifying they queue changes locally, and seeing them self-heal when reconnected).

---

## ⚙️ Configuration Parameters for Conflict Resolution

To manage conflicts effectively, specific settings are defined in the PostgreSQL command/configuration:

- `track_commit_timestamp = on`: **Mandatory.** Instructs PostgreSQL to store the transaction commit timestamp in the system catalog. Spock relies on this to compare timestamps of conflicting modifications.
- `spock.conflict_resolution = 'last_update_wins'`: (Options: `'last_update_wins'`, `'first_update_wins'`, `'error'`). Defines the default resolution policy when two writes target the same row.
- `spock.save_resolutions = on`: **Mandatory for logging.** Enables logging resolved conflicts to the `spock.resolutions` table for administrative review.

---

## 🛠️ Step-by-Step Execution

First, launch the containers and bootstrap the Spock replication (bidirectional between Node 1 and Node 2):
```bash
make up
make bootstrap
```

### Scenario 1: Timestamp-based Conflict Resolution (Last Update Wins)

In this scenario:
1. We pause replication by disabling the subscriptions.
2. We make a change to task ID 1 on Node 1 (committed at time $T_1$).
3. We sleep 2 seconds, and make a change to task ID 1 on Node 2 (committed at time $T_2$ where $T_2 > T_1$).
4. We resume replication.
5. Because $T_2 > T_1$, Node 2's change is newer. Spock automatically overwrites Node 1's local change, while Node 2 discards the incoming older change from Node 1. Both databases converge on Node 2's value.
6. The event is recorded in `spock.resolutions`.

Run the test:
```bash
make test-conflict-timestamp
```

---

### Scenario 2: Error Policy on Conflict (Halting Replication & Recovering)

In this scenario:
1. We set the conflict policy to `'error'` on Node 1.
2. We pause replication.
3. We insert conflicting primary keys (`id = 100`) on both nodes.
4. We resume replication.
5. Node 1 fails to apply Node 2's insertion because they conflict. Because the policy is set to `'error'`, Node 1 halts replication to prevent data corruption.
6. We inspect the subscription status on Node 1 (shows as `down` or `error`) and review database error logs.
7. **Recovery**: We change the policy back to `'last_update_wins'`, resume/enable the subscription, and show that replication recovers automatically and converges.

Run the test:
```bash
make test-conflict-error
```

---

### Scenario 3: Network Partition Simulation (Self-Healing)

In this scenario:
1. We simulate a network partition by disconnecting `node2` from the Docker bridge network.
2. We write to Node 1 (`id = 301`) and Node 2 (`id = 302`) in their respective partitions.
3. We verify that they do not replicate to each other.
4. We check subscription status (shows connection failures).
5. We reconnect `node2` to the Docker network.
6. The replication workers automatically reconnect, process the queued WAL, and both nodes converge, showing both rows.

Run the test:
```bash
make test-partition
```

---

## 🧹 Cleaning Up

Once all tests are completed, run:
```bash
make down
```

---

## 🔎 Important Diagnostic Commands

- **Check Resolutions Log**:
  ```sql
  SELECT * FROM spock.resolutions;
  ```
- **Check Subscription Health & Lag**:
  ```sql
  SELECT * FROM spock.sub_show_status('sub_node1_node2');
  ```
- **Check Replication Slot State**:
  ```sql
  SELECT slot_name, active, wal_status FROM pg_replication_slots;
  ```
