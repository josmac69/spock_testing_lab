.PHONY: build-all clean-all lab01-up lab01-down lab01-test lab02-up lab02-down lab02-test lab03-up lab03-down lab03-test-conflict-timestamp lab03-test-conflict-error lab03-test-partition

build-all:
	docker pull ghcr.io/pgedge/pgedge-postgres:16.11-spock5-standard

clean-all:
	@echo "=== Cleaning up all labs ==="
	-$(MAKE) -C lab01_basic_2_node down
	-$(MAKE) -C lab02_mesh_3_node down
	-$(MAKE) -C lab03_conflicts_troubleshooting down
	@echo "=== All labs cleaned ==="

lab01-up:
	$(MAKE) -C lab01_basic_2_node up
	$(MAKE) -C lab01_basic_2_node bootstrap

lab01-test:
	$(MAKE) -C lab01_basic_2_node test

lab01-down:
	$(MAKE) -C lab01_basic_2_node down

lab02-up:
	$(MAKE) -C lab02_mesh_3_node up
	$(MAKE) -C lab02_mesh_3_node bootstrap

lab02-test:
	$(MAKE) -C lab02_mesh_3_node test

lab02-down:
	$(MAKE) -C lab02_mesh_3_node down

lab03-up:
	$(MAKE) -C lab03_conflicts_troubleshooting up
	$(MAKE) -C lab03_conflicts_troubleshooting bootstrap

lab03-test-conflict-timestamp:
	$(MAKE) -C lab03_conflicts_troubleshooting test-conflict-timestamp

lab03-test-conflict-error:
	$(MAKE) -C lab03_conflicts_troubleshooting test-conflict-error

lab03-test-partition:
	$(MAKE) -C lab03_conflicts_troubleshooting test-partition

lab03-down:
	$(MAKE) -C lab03_conflicts_troubleshooting down
