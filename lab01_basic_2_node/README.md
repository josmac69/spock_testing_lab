# Lab 01: 2-Node Bidirectional Active-Active Setup

This lab demonstrates how to configure **pgEdge Spock** for a two-node active-active (bidirectional) replication cluster.

---

## 📐 Architecture Overview

```mermaid
graph LR
    subgraph Node 1 (port 5431)
        db1[(spock_db)]
    end
    subgraph Node 2 (port 5432)
        db2[(spock_db)]
    end
    db1 -- "sub_node1_node2 (forward_origins={})" --> db2
    db2 -- "sub_node2_node1 (forward_origins={})" --> db1
```

Both nodes run PostgreSQL 16 with Spock. The application can read or write to **either** node. Changes made on `node1` are replicated to `node2`, and changes on `node2` are replicated to `node1`.

---

## 🔍 Loop Prevention (Crucial Concept)

In standard logical replication, setting up bidirectional streams leads to infinite replication loops:
1. `node1` replicates a write to `node2`.
2. `node2` receives the write, registers it, and treats it as a new change.
3. `node2` replicates it back to `node1`, causing duplicate operations and eventually conflicts or crashes.

Spock tracks the **origin** of each transaction. When we create subscriptions in this lab, we configure them with `forward_origins := '{}'`:
```sql
SELECT spock.sub_create(
    subscription_name := 'sub_node1_node2',
    provider_dsn := 'host=node2 port=5432 dbname=spock_db user=spock_user password=spock_password',
    forward_origins := '{}' -- <--- Loops prevented here!
);
```
Setting `forward_origins` to an empty array tells the subscriber's apply worker: **"Do not forward or apply any changes that did not originate locally on the provider node."** Since the provider node did not generate the replicated transaction locally (it received it from us), the subscriber skips replicating it back.

---

## 🛠️ Step-by-Step Execution

You can run the entire lifecycle using the provided Makefile.

### 1. Start the Containers
Spins up both postgres containers and waits for them to be healthy.
```bash
make up
```

### 2. Bootstrap Spock Replication
This step automates the logical replication configuration:
- Runs `scripts/init.sql` on both nodes to enable Spock and create the `customers` table.
- Runs `scripts/bootstrap_node1.sql` on Node 1 to register it as `node1` and add `customers` to the `default` replication set.
- Runs `scripts/bootstrap_node2.sql` on Node 2 to register it as `node2` and add `customers` to the `default` replication set.
- Runs `scripts/subscribe_node1.sql` and `scripts/subscribe_node2.sql` to establish bidirectional subscriptions.
```bash
make bootstrap
```

### 3. Verify Subscription Status
Run the status command to ensure the replication streams are active and replicating:
```bash
make status
```

### 4. Run the Verification Script
This script inserts a record on Node 1, checks if it appears on Node 2, inserts a record on Node 2, checks if it appears on Node 1, and verifies updates.
```bash
make test
```

### 5. Tear Down the Lab
Stops the containers and wipes associated networks and volumes:
```bash
make down
```

---

## 📖 Key Spock Functions Explored

- `spock.node_create(node_name, dsn)`: Registers the local database instance in the Spock network. The DSN is the connection string that remote nodes will use to connect to this node.
- `spock.repset_add_all_tables(set_name, schemas)`: Adds all tables in the given schema list to a replication set (default is `default`). Only tables inside replication sets are replication targets.
- `spock.sub_create(subscription_name, provider_dsn, [forward_origins])`: Subscribes the local node to a provider node.
- `spock.sub_wait_for_sync(subscription_name)`: Blocks execution until the initial synchronization of structure/data is complete.
