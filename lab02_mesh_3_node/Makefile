.PHONY: up bootstrap test down status

up:
	docker compose up -d
	@echo "Waiting for PostgreSQL nodes to be healthy..."
	@until docker compose exec -T node1 pg_isready -U spock_user -d spock_db > /dev/null 2>&1; do \
		echo "Waiting for node1..."; \
		sleep 1; \
	done
	@until docker compose exec -T node2 pg_isready -U spock_user -d spock_db > /dev/null 2>&1; do \
		echo "Waiting for node2..."; \
		sleep 1; \
	done
	@until docker compose exec -T node3 pg_isready -U spock_user -d spock_db > /dev/null 2>&1; do \
		echo "Waiting for node3..."; \
		sleep 1; \
	done
	@echo "Nodes are healthy."

bootstrap:
	@echo "=== Initializing Database Schemas ==="
	docker compose exec -T node1 psql -U spock_user -d spock_db < scripts/init.sql
	docker compose exec -T node2 psql -U spock_user -d spock_db < scripts/init.sql
	docker compose exec -T node3 psql -U spock_user -d spock_db < scripts/init.sql
	@echo "=== Registering Spock Nodes ==="
	docker compose exec -T node1 psql -U spock_user -d spock_db < scripts/bootstrap_node1.sql
	docker compose exec -T node2 psql -U spock_user -d spock_db < scripts/bootstrap_node2.sql
	docker compose exec -T node3 psql -U spock_user -d spock_db < scripts/bootstrap_node3.sql
	@echo "=== Establishing Subscriptions (Full Mesh) ==="
	docker compose exec -T node1 psql -U spock_user -d spock_db < scripts/subscribe_node1.sql
	docker compose exec -T node2 psql -U spock_user -d spock_db < scripts/subscribe_node2.sql
	docker compose exec -T node3 psql -U spock_user -d spock_db < scripts/subscribe_node3.sql
	@echo "=== Waiting for initial sync ==="
	docker compose exec -T node1 psql -U spock_user -d spock_db -c "SELECT spock.sub_wait_for_sync('sub_node1_node2'); SELECT spock.sub_wait_for_sync('sub_node1_node3');"
	docker compose exec -T node2 psql -U spock_user -d spock_db -c "SELECT spock.sub_wait_for_sync('sub_node2_node1'); SELECT spock.sub_wait_for_sync('sub_node2_node3');"
	docker compose exec -T node3 psql -U spock_user -d spock_db -c "SELECT spock.sub_wait_for_sync('sub_node3_node1'); SELECT spock.sub_wait_for_sync('sub_node3_node2');"
	@echo "=== Bootstrap Complete ==="

test:
	./scripts/test.sh

status:
	@echo "=== Node 1 Subscription Status ==="
	docker compose exec -T node1 psql -U spock_user -d spock_db -c "SELECT subscription_name, status FROM spock.sub_show_status();"
	@echo "=== Node 2 Subscription Status ==="
	docker compose exec -T node2 psql -U spock_user -d spock_db -c "SELECT subscription_name, status FROM spock.sub_show_status();"
	@echo "=== Node 3 Subscription Status ==="
	docker compose exec -T node3 psql -U spock_user -d spock_db -c "SELECT subscription_name, status FROM spock.sub_show_status();"

down:
	docker compose down -v
