.PHONY: pin build scan test all

pin:
	./scripts/pin-deps.sh

build:
	./scripts/build.sh

scan:
	./scripts/scan.sh

test:
	docker run --rm -d -p 8000:8000 --name forge-app-test $$ACR_LOGIN_SERVER/forge-app:0.1.0 ; \
	sleep 5 ; \
	curl -s -o /dev/null -w "app HTTP %{http_code}\n" http://localhost:8000/ ; \
	docker rm -f forge-app-test

all: pin build scan

# ── Fase 3 · Gate de admisión ────────────────────────────────
.PHONY: kyverno-install deploy policy-audit policy-enforce demo-blocked clean-k8s

kyverno-install:
	helm repo add kyverno https://kyverno.github.io/kyverno/ && helm repo update
	helm install kyverno kyverno/kyverno --version 3.8.2 -n kyverno --create-namespace --wait

deploy:
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/deployment.yaml
	kubectl apply -f k8s/service.yaml

policy-audit:
	kubectl apply --dry-run=server -f policies/verify-image-signature-audit.yaml
	kubectl apply -f policies/verify-image-signature-audit.yaml

policy-enforce:
	kubectl apply --dry-run=server -f policies/verify-image-signature.yaml
	kubectl apply -f policies/verify-image-signature.yaml

demo-blocked:
	@echo "Desplegando imagen NO firmada (debe fallar)..."
	-kubectl -n forge run vulnerable-test --image=$$ACR_LOGIN_SERVER/forge-app:v0-vulnerable --restart=Never
	@kubectl -n forge delete pod vulnerable-test --ignore-not-found

clean-k8s:
	kubectl delete namespace forge --ignore-not-found
