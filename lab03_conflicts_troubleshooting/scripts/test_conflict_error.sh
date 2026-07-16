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

# 1. Reset data
echo -e "${YELLOW}Resetting data...${NC}"
run_query spock_lab3_node1 "TRUNCATE TABLE tasks;"
sleep 1

# 2. Configure exception behavior to 'sub_disable' on Node 1
echo -e "${YELLOW}Configuring spock.exception_behaviour='sub_disable' on Node 1...${NC}"
run_query spock_lab3_node1 "ALTER SYSTEM SET spock.exception_behaviour = 'sub_disable';"
run_query spock_lab3_node1 "SELECT pg_reload_conf();"
sleep 1

# Check setting
setting=$(run_query spock_lab3_node1 "SHOW spock.exception_behaviour;")
echo -e "Node 1 exception behavior policy: ${GREEN}$setting${NC}"

# 3. Alter column length on Node 1 to be smaller (5 chars) to simulate a schema mismatch
echo -e "${YELLOW}Altering Node 1 'title' column to VARCHAR(5)...${NC}"
run_query spock_lab3_node1 "ALTER TABLE tasks ALTER COLUMN title TYPE VARCHAR(5);"

# 4. Insert a row on Node 2 that exceeds 5 characters (e.g. 'TaskOverLimit')
echo -e "${YELLOW}Inserting a row with a 13-character title on Node 2...${NC}"
run_query spock_lab3_node2 "INSERT INTO tasks (id, title, status) VALUES (200, 'TaskOverLimit', 'todo');"

echo -e "Waiting for replication worker to process and fail (5s)..."
sleep 5

# 5. Check subscription status on Node 1
echo -e "\n${YELLOW}Checking subscription status on Node 1...${NC}"
sub_status=$(run_query spock_lab3_node1 "SELECT status FROM spock.sub_show_status('sub_node1_node2');" | tr -d '\r\n')

echo -e "Subscription status of Node 1 to Node 2: ${RED}$sub_status${NC}"

# 6. Recovery Phase
echo -e "\n${YELLOW}==================================================${NC}"
echo -e "${YELLOW}              RECOVERY PHASE                      ${NC}"
echo -e "${YELLOW}==================================================${NC}"
echo -e "We will recover by fixing the column type on Node 1, resetting the exception policy, enabling the subscription, and force-replicating the skipped row."

# Fix schema mismatch on Node 1
echo -e "${YELLOW}Restoring Node 1 'title' column to VARCHAR(100)...${NC}"
run_query spock_lab3_node1 "ALTER TABLE tasks ALTER COLUMN title TYPE VARCHAR(100);"

# Reset policy
run_query spock_lab3_node1 "ALTER SYSTEM SET spock.exception_behaviour = 'transdiscard';"
run_query spock_lab3_node1 "SELECT pg_reload_conf();"
sleep 1

echo -e "Enabling subscription again..."
run_query spock_lab3_node1 "SELECT spock.sub_enable('sub_node1_node2');"

echo -e "Waiting for exception replay engine to discard the failing transaction (5s)..."
sleep 5

# 7. Force-replicate by deleting and re-inserting on Node 2
echo -e "${YELLOW}Re-triggering replication of the missing row on Node 2 (delete & re-insert)...${NC}"
run_query spock_lab3_node2 "DELETE FROM tasks WHERE id = 200;"
run_query spock_lab3_node2 "INSERT INTO tasks (id, title, status) VALUES (200, 'TaskOverLimit', 'todo');"
sleep 8

# Verify database converges
title_n1=$(run_query spock_lab3_node1 "SELECT title FROM tasks WHERE id = 200;" | tr -d '\r\n')
title_n2=$(run_query spock_lab3_node2 "SELECT title FROM tasks WHERE id = 200;" | tr -d '\r\n')

echo -e "Final Title on Node 1: '${GREEN}$title_n1${NC}'"
echo -e "Final Title on Node 2: '${GREEN}$title_n2${NC}'"

# Check subscription status
sub_status_after=$(run_query spock_lab3_node1 "SELECT status FROM spock.sub_show_status('sub_node1_node2');" | tr -d '\r\n')
echo -e "Post-recovery subscription status: ${GREEN}$sub_status_after${NC}"

if [ "$sub_status_after" = "replicating" ] && [ "$title_n1" = "TaskOverLimit" ] && [ "$title_n2" = "TaskOverLimit" ]; then
    echo -e "${GREEN}SUCCESS: Schema fixed, subscription recovered, and cluster converged!${NC}"
else
    echo -e "${RED}FAILURE: Recovery failed or data has not converged!${NC}"
    exit 1
fi

echo -e "${BLUE}==================================================${NC}"
