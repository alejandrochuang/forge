.PHONY: build scan sign verify all compare

build:
	./scripts/build.sh

scan:
	./scripts/scan.sh

sign:
	./scripts/sign.sh

all: build scan sign

compare:
	@echo "== base antigua (python:3.11-slim) ==" ; trivy image --severity HIGH,CRITICAL --quiet python:3.11-slim | grep -i "Total:"
	@echo "== forge-base (Wolfi) ==" ; trivy image --severity HIGH,CRITICAL --quiet $$ACR_LOGIN_SERVER/forge-base:0.1.0 | grep -i "Total:"
