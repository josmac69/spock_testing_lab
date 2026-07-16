#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}       SPOCK LAB 03: NETWORK PARTITION SIM        ${NC}"
echo -e "${BLUE}==================================================${NC}"

run_query() {
    local node=$1
    local query=$2
    docker exec -i "$node" psql -U spock_user -d spock_db -t -A -c "$query" | tr -d '\r\n'
}

# 1. Reset data and ensure health
echo -e "${YELLOW}Resetting data...${NC}"
run_query spock_lab3_node1 "TRUNCATE TABLE tasks;"
sleep 1

# Verify subscriptions are healthy
sub1_status=$(run_query spock_lab3_node1 "SELECT status FROM spock.sub_show_status('sub_node1_node2');" | tr -d '\r\n')
sub2_status=$(run_query spock_lab3_node2 "SELECT status FROM spock.sub_show_status('sub_node2_node1');" | tr -d '\r\n')

echo -e "Node 1 subscription status: ${GREEN}$sub1_status${NC}"
echo -e "Node 2 subscription status: ${GREEN}$sub2_status${NC}"

if [ "$sub1_status" != "replicating" ] || [ "$sub2_status" != "replicating" ]; then
    echo -e "${RED}Warning: Subscriptions are not in 'replicating' state. Attempting recovery...${NC}"
    run_query spock_lab3_node1 "ALTER SYSTEM SET spock.conflict_resolution = 'last_update_wins';"
    run_query spock_lab3_node1 "SELECT pg_reload_conf();"
    run_query spock_lab3_node1 "SELECT spock.sub_enable('sub_node1_node2');"
    run_query spock_lab3_node2 "SELECT spock.sub_enable('sub_node2_node1');"
    sleep 3
fi

# 2. Simulate Network Partition by disconnecting node2 from the docker network
echo -e "\n${RED}>>> SIMULATING NETWORK PARTITION BETWEEN MASTER NODES <<<${NC}"
echo -e "${YELLOW}Disconnecting Node 2 from the Spock network...${NC}"
docker network disconnect spock_net_lab3 spock_lab3_node2
sleep 2

# 3. Perform writes on both nodes in their isolated partitions
echo -e "\n${YELLOW}Writing Task 301 to Node 1...${NC}"
run_query spock_lab3_node1 "INSERT INTO tasks (id, title, status) VALUES (301, 'Insert on Node 1 (Split)', 'todo');"

echo -e "${YELLOW}Writing Task 302 to Node 2...${NC}"
run_query spock_lab3_node2 "INSERT INTO tasks (id, title, status) VALUES (302, 'Insert on Node 2 (Split)', 'todo');"

echo -e "Waiting a moment..."
sleep 2

# 4. Verify replication is blocked
echo -e "\n${YELLOW}Checking if data replicated during partition...${NC}"
node1_has_302=$(run_query spock_lab3_node1 "SELECT count(*) FROM tasks WHERE id = 302;")
node2_has_301=$(run_query spock_lab3_node2 "SELECT count(*) FROM tasks WHERE id = 301;")

node1_has_302=$(echo "$node1_has_302" | tr -d '\r\n')
node2_has_301=$(echo "$node2_has_301" | tr -d '\r\n')

if [ "$node1_has_302" -eq 0 ] && [ "$node2_has_301" -eq 0 ]; then
    echo -e "${GREEN}CONFIRMED: Replication is blocked. Node 1 does not see Task 302, Node 2 does not see Task 301.${NC}"
else
    echo -e "${RED}ERROR: Data leaked between partitions!${NC}"
    exit 1
fi

# Show replication status during partition
echo -e "\n${YELLOW}Subscription status on Node 1 (should show connection errors or down/disabled over time):${NC}"
docker exec -t spock_lab3_node1 psql -U spock_user -d spock_db -c "SELECT * FROM spock.sub_show_status('sub_node1_node2');"

# 5. Heal Network Partition
echo -e "\n${GREEN}>>> HEALING NETWORK PARTITION <<<${NC}"
echo -e "${YELLOW}Reconnecting Node 2 to the Spock network...${NC}"
docker network connect spock_net_lab3 spock_lab3_node2
sleep 5 # Wait for reconnect and catchup

# 6. Verify catch-up and data convergence
echo -e "\n${YELLOW}Checking if nodes caught up and converged...${NC}"
node1_count=$(run_query spock_lab3_node1 "SELECT count(*) FROM tasks WHERE id IN (301, 302);")
node2_count=$(run_query spock_lab3_node2 "SELECT count(*) FROM tasks WHERE id IN (301, 302);")

node1_count=$(echo "$node1_count" | tr -d '\r\n')
node2_count=$(echo "$node2_count" | tr -d '\r\n')

if [ "$node1_count" -eq 2 ] && [ "$node2_count" -eq 2 ]; then
    echo -e "${GREEN}SUCCESS: Both nodes successfully caught up after partition was healed!${NC}"
    echo -e "\nFinal table state on Node 1:"
    docker exec -t spock_lab3_node1 psql -U spock_user -d spock_db -c "SELECT id, title, status FROM tasks ORDER BY id;"
    echo -e "\nFinal table state on Node 2:"
    docker exec -t spock_lab3_node2 psql -U spock_user -d spock_db -c "SELECT id, title, status FROM tasks ORDER BY id;"
else
    echo -e "${RED}FAILURE: Data has not synchronized after healing partition!${NC}"
    echo -e "Node 1 Task Count: $node1_count (Expected 2)"
    echo -e "Node 2 Task Count: $node2_count (Expected 2)"
    exit 1
fi

echo -e "${BLUE}==================================================${NC}"
