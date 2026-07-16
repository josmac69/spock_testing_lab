# pgEdge Spock Logical Replication Testing Lab

Welcome to the pgEdge Spock Logical Replication Testing Lab! This repository is designed to demonstrate multi-master active-active replication setups using pgEdge's **Spock** extension for PostgreSQL. Here you will find step-by-step laboratories, starting from a basic 2-node bi-directional replication up to advanced 3-node mesh configurations, conflict resolution handling, and network partition troubleshooting.

---

## ⚡ What is Spock?

**Spock** is an open-source PostgreSQL extension developed by **pgEdge**. It is based on `pglogical` but brings significant improvements, especially in:
- **Active-Active (Multi-Master) Replication**: Allows writing to any node in the cluster with changes propagating to all other nodes.
- **Asymmetric Topology Support**: Setup nodes as mesh, hub-and-spoke, read-replicas, etc.
- **Conflict Detection and Resolution**: Built-in resolution engines (such as *last update wins*, *first update wins*, and *error/abort*) to handle concurrent writes safely.
- **Conflict-Free Delta-Apply**: Custom CRDT-like mathematical resolution for fields such as counters.
- **DDL Replication**: Built-in mechanisms to replicate database schema modifications.

---

## 🔬 Lab Catalog

Each lab is located in its own subdirectory and contains a self-contained Docker Compose setup, automation `Makefile`, helper SQL scripts, and dedicated README instructions:

| Lab | Directory | Topology | Key Focus Areas |
| :--- | :--- | :--- | :--- |
| **Lab 01** | [`lab01_basic_2_node`](./lab01_basic_2_node/) | 2-Master (Bi-directional) | Logical replication basics, registration, subscription, loop prevention using `forward_origins := '{}'`. |
| **Lab 02** | [`lab02_mesh_3_node`](./lab02_mesh_3_node/) | 3-Master (Full Mesh) | Scaling replication, mesh topology, avoiding loops across 3 nodes. |
| **Lab 03** | [`lab03_conflicts_troubleshooting`](./lab03_conflicts_troubleshooting/) | 2-Master (Conflict Focus) | Conflict detection, `spock.resolutions` querying, network partition simulation (`docker network disconnect`), lag monitoring, reconciliation. |

---

## 🛠️ Prerequisites

To run these labs, ensure you have the following installed on your machine:
- **Docker** (v20.10+)
- **Docker Compose** (v2.0+)
- **Make** (standard build tool)
- **psql** CLI client (for local testing, though the automation scripts run inside the containers)

---

## 🚀 Quick Start (All Labs)

You can run commands from the root directory to clean up or run individual labs.

### Clean All Labs
To ensure there are no conflicting containers, volumes, or networks running:
```bash
make clean-all
```

### Run Lab 01 (Basic 2-Node)
```bash
# Start containers and bootstrap replication
make lab01-up

# Execute replication test
make lab01-test

# Tear down the lab
make lab01-down
```

### Run Lab 02 (3-Node Full Mesh)
```bash
make lab02-up
make lab02-test
make lab02-down
```

### Run Lab 03 (Conflicts & Troubleshooting)
```bash
make lab03-up
# Run timestamp conflict tests
make lab03-test-conflict-timestamp
# Run error conflict tests
make lab03-test-conflict-error
# Run network partition tests
make lab03-test-partition
make lab03-down
```

---

## 🔍 How Spock Prevents Replication Loops
In standard logical replication, setting up bi-directional streams without loop prevention leads to infinite loops: `node1` replicates to `node2`, which sees a new write, and replicates it back to `node1`.
Spock tracks the **origin** of each transaction. By creating subscriptions with `forward_origins := '{}'`, we instruct the subscriber apply worker:
> *"Only apply changes that originated locally on the provider node. Do not apply changes that the provider received from other replication streams."*

This allows seamless bi-directional and mesh active-active clusters.