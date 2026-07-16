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
	@echo "Nodes are healthy."

bootstrap:
	@echo "=== Initializing Database Schemas ==="
	docker compose exec -T node1 psql -U spock_user -d spock_db < scripts/init.sql
	docker compose exec -T node2 psql -U spock_user -d spock_db < scripts/init.sql
	@echo "=== Registering Spock Nodes ==="
	docker compose exec -T node1 psql -U spock_user -d spock_db < scripts/bootstrap_node1.sql
	docker compose exec -T node2 psql -U spock_user -d spock_db < scripts/bootstrap_node2.sql
	@echo "=== Establishing Subscriptions (Active-Active) ==="
	docker compose exec -T node1 psql -U spock_user -d spock_db < scripts/subscribe_node1.sql
	docker compose exec -T node2 psql -U spock_user -d spock_db < scripts/subscribe_node2.sql
	@echo "=== Waiting for initial sync ==="
	docker compose exec -T node1 psql -U spock_user -d spock_db -c "SELECT spock.sub_wait_for_sync('sub_node1_node2');"
	docker compose exec -T node2 psql -U spock_user -d spock_db -c "SELECT spock.sub_wait_for_sync('sub_node2_node1');"
	@echo "=== Bootstrap Complete ==="

test:
	./scripts/test.sh

status:
	@echo "=== Node 1 Subscription Status ==="
	docker compose exec -T node1 psql -U spock_user -d spock_db -c "SELECT * FROM spock.sub_show_status('sub_node1_node2');"
	@echo "=== Node 2 Subscription Status ==="
	docker compose exec -T node2 psql -U spock_user -d spock_db -c "SELECT * FROM spock.sub_show_status('sub_node2_node1');"

down:
	docker compose down -v
