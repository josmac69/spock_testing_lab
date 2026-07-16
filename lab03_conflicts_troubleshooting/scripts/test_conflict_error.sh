#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}    SPOCK LAB 03: CONFLICT REPLICATION ERROR      ${NC}"
echo -e "${BLUE}==================================================${NC}"

run_query() {
    local node=$1
    local query=$2
    docker exec -i "$node" psql -U spock_user -d spock_db -t -A -c "$query" | tr -d '\r\n'
}

# 1. Set conflict resolution to 'error' on Node 1
echo -e "${YELLOW}Configuring spock.conflict_resolution='error' on Node 1...${NC}"
run_query spock_lab3_node1 "ALTER SYSTEM SET spock.conflict_resolution = 'error'; SELECT pg_reload_conf();"
sleep 1

# Check setting
setting=$(run_query spock_lab3_node1 "SHOW spock.conflict_resolution;")
echo -e "Node 1 conflict resolution policy: ${GREEN}$setting${NC}"

# 2. Reset data
echo -e "${YELLOW}Resetting data...${NC}"
run_query spock_lab3_node1 "TRUNCATE TABLE tasks;"
sleep 1

# 3. Disable subscriptions to perform concurrent conflicting inserts
echo -e "${YELLOW}Pausing subscriptions...${NC}"
run_query spock_lab3_node1 "SELECT spock.sub_disable('sub_node1_node2');"
run_query spock_lab3_node2 "SELECT spock.sub_disable('sub_node2_node1');"
sleep 1

# 4. Insert conflicting keys (ID 100) on both nodes
echo -e "${YELLOW}Inserting conflicting ID 100 on Node 1...${NC}"
run_query spock_lab3_node1 "INSERT INTO tasks (id, title, status) VALUES (100, 'Insert on Node 1', 'todo');"

echo -e "${YELLOW}Inserting conflicting ID 100 on Node 2...${NC}"
run_query spock_lab3_node2 "INSERT INTO tasks (id, title, status) VALUES (100, 'Insert on Node 2', 'todo');"

# 5. Enable subscriptions to trigger error
echo -e "\n${YELLOW}Resuming subscriptions to trigger replication error...${NC}"
run_query spock_lab3_node1 "SELECT spock.sub_enable('sub_node1_node2');"
run_query spock_lab3_node2 "SELECT spock.sub_enable('sub_node2_node1');"

echo -e "Waiting for replication workers to process (4s)..."
sleep 4

# 6. Check subscription status on Node 1 (which receives changes from Node 2)
echo -e "\n${YELLOW}Checking subscription status on Node 1...${NC}"
sub_status=$(run_query spock_lab3_node1 "SELECT status FROM spock.sub_show_status('sub_node1_node2');" | tr -d '\r\n')

echo -e "Subscription status of Node 1 to Node 2: ${RED}$sub_status${NC}"
echo -e "Check database logs on Node 1 to see the replication error details:"
docker compose logs node1 | tail -n 15

# 7. Recovery Phase
echo -e "\n${YELLOW}==================================================${NC}"
echo -e "${YELLOW}              RECOVERY PHASE                      ${NC}"
echo -e "${YELLOW}==================================================${NC}"
echo -e "We will recover by setting the conflict policy back to 'last_update_wins' and enabling the subscription."

run_query spock_lab3_node1 "ALTER SYSTEM SET spock.conflict_resolution = 'last_update_wins'; SELECT pg_reload_conf();"
sleep 1

echo -e "Enabling subscription again..."
run_query spock_lab3_node1 "SELECT spock.sub_enable('sub_node1_node2');"

echo -e "Waiting for synchronization (3s)..."
sleep 3

# Verify database converges
title_n1=$(run_query spock_lab3_node1 "SELECT title FROM tasks WHERE id = 100;" | tr -d '\r\n')
title_n2=$(run_query spock_lab3_node2 "SELECT title FROM tasks WHERE id = 100;" | tr -d '\r\n')

echo -e "Final Title on Node 1: '${GREEN}$title_n1${NC}'"
echo -e "Final Title on Node 2: '${GREEN}$title_n2${NC}'"

# Check subscription status
sub_status_after=$(run_query spock_lab3_node1 "SELECT status FROM spock.sub_show_status('sub_node1_node2');" | tr -d '\r\n')
echo -e "Post-recovery subscription status: ${GREEN}$sub_status_after${NC}"

if [ "$sub_status_after" = "replicating" ] && [ "$title_n1" = "$title_n2" ]; then
    echo -e "${GREEN}SUCCESS: Cluster successfully recovered and synchronized!${NC}"
else
    echo -e "${RED}FAILURE: Recovery failed or data has not converged!${NC}"
    exit 1
fi

echo -e "${BLUE}==================================================${NC}"
