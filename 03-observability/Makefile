.PHONY: up down status baseline fault-error fault-latency fault-cpu clean tf-init tf-plan tf-apply tf-destroy azure-init azure-plan azure-apply azure-destroy

# Local Docker Compose operations
up:
	docker compose -f compose/docker-compose.yml up --build -d

down:
	docker compose -f compose/docker-compose.yml down -v

logs:
	docker compose -f compose/docker-compose.yml logs -f

# Scenario demo runner
status:
	bash demo.sh status

baseline:
	bash demo.sh baseline

fault-error:
	bash demo.sh fault-error

fault-latency:
	bash demo.sh fault-latency

fault-cpu:
	bash demo.sh fault-cpu

clean:
	bash demo.sh clean

# AWS Terraform shortcuts
tf-init:
	terraform -chdir=aws init

tf-plan:
	terraform -chdir=aws plan

tf-apply:
	terraform -chdir=aws apply -auto-approve

tf-destroy:
	terraform -chdir=aws destroy -auto-approve

# Azure Terraform shortcuts
azure-init:
	terraform -chdir=azure init

azure-plan:
	terraform -chdir=azure plan

azure-apply:
	terraform -chdir=azure apply -auto-approve

azure-destroy:
	terraform -chdir=azure destroy -auto-approve
