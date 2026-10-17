.DEFAULT_GOAL := help
ENV ?= dev
AWS_REGION ?= eu-west-1
TF_DIR := terraform/environments/$(ENV)

.PHONY: help bootstrap destroy plan apply fmt lint test build push port-forward-grafana cost-report docs

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Provision infra + bootstrap ArgoCD end-to-end (dev by default)
	./scripts/bootstrap.sh $(ENV)

destroy: ## Tear down everything to avoid AWS charges
	./scripts/destroy.sh $(ENV)

plan: ## terraform plan for $(ENV)
	cd $(TF_DIR) && terraform init -upgrade && terraform plan -out=tfplan

apply: ## terraform apply for $(ENV)
	cd $(TF_DIR) && terraform apply tfplan

fmt: ## Format terraform + python
	terraform fmt -recursive terraform/
	cd app && ruff format src tests

lint: ## Lint terraform + python + yaml
	terraform fmt -check -recursive terraform/
	cd app && ruff check src tests
	yamllint -c .yamllint.yml .

test: ## Run application unit tests
	cd app && python -m pytest tests/ -v --cov=src --cov-report=term-missing

build: ## Build the app container image
	docker build -t eks-demo-app:local ./app

push: ## Push the app container image to ECR (expects ECR_REPO env var)
	@test -n "$(ECR_REPO)" || (echo "Set ECR_REPO=<account>.dkr.ecr.<region>.amazonaws.com/eks-demo-app"; exit 1)
	docker tag eks-demo-app:local $(ECR_REPO):latest
	docker push $(ECR_REPO):latest

port-forward-grafana: ## Port-forward Grafana locally and print credentials
	./scripts/port-forward-grafana.sh

cost-report: ## Print AWS cost per namespace/tag
	python3 scripts/cost-report.py

docs: ## Regenerate terraform-docs for all modules
	terraform-docs markdown table --output-file README.md --output-mode inject terraform/modules/vpc
	terraform-docs markdown table --output-file README.md --output-mode inject terraform/modules/eks
	terraform-docs markdown table --output-file README.md --output-mode inject terraform/modules/iam-irsa
	terraform-docs markdown table --output-file README.md --output-mode inject terraform/modules/ecr
	terraform-docs markdown table --output-file README.md --output-mode inject terraform/modules/karpenter
	terraform-docs markdown table --output-file README.md --output-mode inject terraform/modules/addons
