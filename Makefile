# devfleet — common workflows. `make help` lists targets.
.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

.PHONY: help lint build build-ubuntu build-debian build-rocky up down destroy status

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

lint: ## Validate all layers (packer/ansible/vagrant)
	scripts/lint.sh

build: build-ubuntu build-debian build-rocky ## Build all OS boxes

build-ubuntu: ## Build the Ubuntu 24.04 box
	scripts/build.sh ubuntu-2404
build-debian: ## Build the Debian 12 box
	scripts/build.sh debian-12
build-rocky: ## Build the Rocky 9 box
	scripts/build.sh rocky-9

up: ## Boot the whole fleet (cd vagrant; vagrant up)
	cd vagrant && vagrant up
down: ## Halt the fleet
	cd vagrant && vagrant halt
destroy: ## Destroy the fleet
	cd vagrant && vagrant destroy -f
status: ## Show fleet status
	cd vagrant && vagrant status
