#!/usr/bin/env bash
set -euo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}       SPOCK LAB 01: BIDIRECTIONAL TEST           ${NC}"
echo -e "${BLUE}==================================================${NC}"

# Check if containers are running
if ! docker ps | grep -q spock_lab1_node1; then
    echo -e "${RED}Error: spock_lab1_node1 container is not running.${NC}"
    exit 1
fi

# Function to run query on node
run_query() {
    local node=$1
    local query=$2
    docker exec -i "$node" psql -U spock_user -d spock_db -t -A -c "$query" | tr -d '\r\n'
}

# Clean existing data to start fresh
echo -e "${YELLOW}Cleaning existing data from both nodes...${NC}"
run_query spock_lab1_node1 "TRUNCATE TABLE customers;"

# Test 1: Insert on Node 1 -> Verify on Node 2
echo -e "\n${YELLOW}[Test 1] Writing to Node 1 and verifying on Node 2...${NC}"
run_query spock_lab1_node1 "INSERT INTO customers (id, name, email) VALUES (1, 'Alice Miller', 'alice@example.com');"

echo -e "Waiting for replication (1s)..."
sleep 1

# Check Node 2
echo -e "Checking Node 2 for Alice..."
node2_count=$(run_query spock_lab1_node2 "SELECT count(*) FROM customers WHERE email = 'alice@example.com';")

if [ "$node2_count" -eq 1 ]; then
    echo -e "${GREEN}SUCCESS: Alice successfully replicated from Node 1 to Node 2!${NC}"
else
    echo -e "${RED}FAILURE: Alice not found on Node 2!${NC}"
    exit 1
fi

# Test 2: Insert on Node 2 -> Verify on Node 1
echo -e "\n${YELLOW}[Test 2] Writing to Node 2 and verifying on Node 1...${NC}"
run_query spock_lab1_node2 "INSERT INTO customers (id, name, email) VALUES (2, 'Bob Jones', 'bob@example.com');"

echo -e "Waiting for replication (1s)..."
sleep 1

# Check Node 1
echo -e "Checking Node 1 for Bob..."
node1_count=$(run_query spock_lab1_node1 "SELECT count(*) FROM customers WHERE email = 'bob@example.com';")

if [ "$node1_count" -eq 1 ]; then
    echo -e "${GREEN}SUCCESS: Bob successfully replicated from Node 2 to Node 1!${NC}"
else
    echo -e "${RED}FAILURE: Bob not found on Node 1!${NC}"
    exit 1
fi

# Test 3: Update on Node 1 -> Verify on Node 2
echo -e "\n${YELLOW}[Test 3] Updating Bob on Node 1 and verifying update on Node 2...${NC}"
run_query spock_lab1_node1 "UPDATE customers SET name = 'Bob Jones Sr.' WHERE email = 'bob@example.com';"

echo -e "Waiting for replication (1s)..."
sleep 1

# Check Node 2
echo -e "Checking Node 2 for Bob's updated name..."
node2_name=$(run_query spock_lab1_node2 "SELECT name FROM customers WHERE email = 'bob@example.com';")

# Trim whitespace
node2_name=$(echo "$node2_name" | tr -d '\r\n')

if [ "$node2_name" = "Bob Jones Sr." ]; then
    echo -e "${GREEN}SUCCESS: Update successfully replicated from Node 1 to Node 2!${NC}"
else
    echo -e "${RED}FAILURE: Bob's name on Node 2 is '$node2_name', expected 'Bob Jones Sr.'!${NC}"
    exit 1
fi

# Show final records
echo -e "\n${BLUE}==================================================${NC}"
echo -e "${BLUE}Final Records on Node 1:${NC}"
docker exec -t spock_lab1_node1 psql -U spock_user -d spock_db -c "SELECT id, name, email FROM customers ORDER BY id;"

echo -e "${BLUE}Final Records on Node 2:${NC}"
docker exec -t spock_lab1_node2 psql -U spock_user -d spock_db -c "SELECT id, name, email FROM customers ORDER BY id;"

echo -e "${GREEN}ALL BIDIRECTIONAL REPLICATION TESTS PASSED!${NC}"
echo -e "${BLUE}==================================================${NC}"
