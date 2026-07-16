#!/usr/bin/env bash
set -euo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}       SPOCK LAB 02: 3-NODE FULL MESH TEST        ${NC}"
echo -e "${BLUE}==================================================${NC}"

# Check if containers are running
for service in node1 node2 node3; do
    if ! docker ps | grep -q "spock_lab2_${service}"; then
        echo -e "${RED}Error: spock_lab2_${service} container is not running.${NC}"
        exit 1
    fi
done

# Function to run query on node
run_query() {
    local node=$1
    local query=$2
    docker exec -i "$node" psql -U spock_user -d spock_db -t -A -c "$query" | tr -d '\r\n'
}

# Clean existing data to start fresh
echo -e "${YELLOW}Cleaning existing data from all nodes...${NC}"
run_query spock_lab2_node1 "TRUNCATE TABLE devices;"

# Test 1: Insert on Node 1 -> Verify on Node 2 & Node 3
echo -e "\n${YELLOW}[Test 1] Writing 'device-alpha' on Node 1...${NC}"
run_query spock_lab2_node1 "INSERT INTO devices (name, status) VALUES ('device-alpha', 'online');"
sleep 1.5

for node in spock_lab2_node2 spock_lab2_node3; do
    echo -e "Checking $node..."
    count=$(run_query "$node" "SELECT count(*) FROM devices WHERE name = 'device-alpha';")
    if [ "$count" -eq 1 ]; then
        echo -e "  ${GREEN}SUCCESS: Replicated to $node!${NC}"
    else
        echo -e "  ${RED}FAILURE: 'device-alpha' not found on $node!${NC}"
        exit 1
    fi
done

# Test 2: Insert on Node 2 -> Verify on Node 1 & Node 3
echo -e "\n${YELLOW}[Test 2] Writing 'device-beta' on Node 2...${NC}"
run_query spock_lab2_node2 "INSERT INTO devices (name, status) VALUES ('device-beta', 'maintenance');"
sleep 1.5

for node in spock_lab2_node1 spock_lab2_node3; do
    echo -e "Checking $node..."
    count=$(run_query "$node" "SELECT count(*) FROM devices WHERE name = 'device-beta';")
    if [ "$count" -eq 1 ]; then
        echo -e "  ${GREEN}SUCCESS: Replicated to $node!${NC}"
    else
        echo -e "  ${RED}FAILURE: 'device-beta' not found on $node!${NC}"
        exit 1
    fi
done

# Test 3: Insert on Node 3 -> Verify on Node 1 & Node 2
echo -e "\n${YELLOW}[Test 3] Writing 'device-gamma' on Node 3...${NC}"
run_query spock_lab2_node3 "INSERT INTO devices (name, status) VALUES ('device-gamma', 'offline');"
sleep 1.5

for node in spock_lab2_node1 spock_lab2_node2; do
    echo -e "Checking $node..."
    count=$(run_query "$node" "SELECT count(*) FROM devices WHERE name = 'device-gamma';")
    if [ "$count" -eq 1 ]; then
        echo -e "  ${GREEN}SUCCESS: Replicated to $node!${NC}"
    else
        echo -e "  ${RED}FAILURE: 'device-gamma' not found on $node!${NC}"
        exit 1
    fi
done

# Show final records
echo -e "\n${BLUE}==================================================${NC}"
for service in node1 node2 node3; do
    echo -e "${BLUE}Final Records on Node $service:${NC}"
    docker exec -t "spock_lab2_${service}" psql -U spock_user -d spock_db -c "SELECT id, name, status FROM devices ORDER BY id;"
done

echo -e "${GREEN}ALL 3-NODE MESH REPLICATION TESTS PASSED!${NC}"
echo -e "${BLUE}==================================================${NC}"
