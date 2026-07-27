.PHONY: help wan-up wan-down lan-up lan-down stop check

help:
	@echo "Targets:"
	@echo "  wan-up    Setup WAN namespace and dnsmasq"
	@echo "  wan-down  Cleanup WAN namespace"
	@echo "  lan-up    Setup LAN STB namespaces"
	@echo "  lan-down  Cleanup LAN namespaces"
	@echo "  stop      Stop active test processes"
	@echo "  check     Run shell syntax checks"

wan-up:
	sudo ./scripts/setup_wan.sh

wan-down:
	sudo ./scripts/cleanup_wan.sh

lan-up:
	sudo ./scripts/setup_lan.sh

lan-down:
	sudo ./scripts/cleanup_lan.sh

stop:
	sudo ./scripts/stop_tests.sh

check:
	bash -n scripts/*.sh
	python3 -m py_compile scripts/*.py
