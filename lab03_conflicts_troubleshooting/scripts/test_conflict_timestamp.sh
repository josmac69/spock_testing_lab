#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  SPOCK LAB 03: TIMESTAMP CONFLICT RESOLUTION     ${NC}"
echo -e "${BLUE}==================================================${NC}"

run_query() {
    local node=$1
    local query=$2
    docker exec -i "$node" psql -U spock_user -d spock_db -t -A -c "$query" | tr -d '\r\n'
}

# 1. Reset data and ensure conflict_resolution is set to last_update_wins
echo -e "${YELLOW}Resetting data...${NC}"
run_query spock_lab3_node1 "TRUNCATE TABLE tasks;"
sleep 1

# Check conflict resolution setting
resolution_setting=$(run_query spock_lab3_node1 "SHOW spock.conflict_resolution;")
echo -e "Current conflict resolution setting: ${GREEN}$resolution_setting${NC}"

# Insert initial task
echo -e "${YELLOW}Inserting initial task (ID 1) on Node 1...${NC}"
run_query spock_lab3_node1 "INSERT INTO tasks (id, title, status) VALUES (1, 'Initial Task', 'todo');"
sleep 1.5

# Verify replication to Node 2
node2_title=$(run_query spock_lab3_node2 "SELECT title FROM tasks WHERE id = 1;")
node2_title=$(echo "$node2_title" | tr -d '\r\n')
echo -e "Verified Node 2 has task: '${GREEN}$node2_title${NC}'"

# 2. Pause subscriptions to simulate concurrent disconnected updates
echo -e "\n${YELLOW}Pausing subscriptions to simulate network separation...${NC}"
run_query spock_lab3_node1 "SELECT spock.sub_disable('sub_node1_node2');"
run_query spock_lab3_node2 "SELECT spock.sub_disable('sub_node2_node1');"
sleep 1

# 3. Perform conflicting updates on both nodes
echo -e "\n${YELLOW}Performing update on Node 1 (earlier timestamp)...${NC}"
run_query spock_lab3_node1 "UPDATE tasks SET title = 'Title Updated on Node 1' WHERE id = 1;"

# Sleep to ensure distinct commit timestamps
sleep 2

echo -e "${YELLOW}Performing update on Node 2 (later timestamp)...${NC}"
run_query spock_lab3_node2 "UPDATE tasks SET title = 'Title Updated on Node 2' WHERE id = 1;"

# 4. Resume subscriptions and let them sync
echo -e "\n${YELLOW}Resuming subscriptions to trigger conflict resolution...${NC}"
run_query spock_lab3_node1 "SELECT spock.sub_enable('sub_node1_node2');"
run_query spock_lab3_node2 "SELECT spock.sub_enable('sub_node2_node1');"

echo -e "Waiting for sync (3s)..."
sleep 3

# 5. Check outcome
echo -e "\n${YELLOW}Checking final values on both nodes...${NC}"
title_n1=$(run_query spock_lab3_node1 "SELECT title FROM tasks WHERE id = 1;" | tr -d '\r\n')
title_n2=$(run_query spock_lab3_node2 "SELECT title FROM tasks WHERE id = 1;" | tr -d '\r\n')

echo -e "Node 1 Title: '${GREEN}$title_n1${NC}'"
echo -e "Node 2 Title: '${GREEN}$title_n2${NC}'"

if [ "$title_n1" = "Title Updated on Node 2" ] && [ "$title_n2" = "Title Updated on Node 2" ]; then
    echo -e "${GREEN}SUCCESS: Last Update Wins resolved conflict correctly (Node 2's later update won on both nodes)!${NC}"
else
    echo -e "${RED}FAILURE: Conflict resolution did not converge on Node 2's update!${NC}"
    exit 1
fi

# 6. Check spock.resolutions table
echo -e "\n${YELLOW}Checking spock.resolutions logs on Node 1:${NC}"
docker exec -t spock_lab3_node1 psql -U spock_user -d spock_db -c "SELECT * FROM spock.resolutions;" || echo "No resolutions logged"

echo -e "${BLUE}==================================================${NC}"
