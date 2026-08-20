# ABOUTME: Build targets for running the LiteLLM proxy locally against GitHub Copilot models.
# ABOUTME: Master and salt keys are generated once as UUIDs and persisted in .env.

VENV := .venv-litellm
LITELLM := $(VENV)/bin/litellm
PIP := $(VENV)/bin/pip
CONFIG := litellm-config.yaml
ENV_FILE := .env

HOST ?= 127.0.0.1
PORT ?= 4000
MODEL ?= claude-sonnet-5

LITELLM_VERSION := 1.97.0
FASTAPI_VERSION := 0.140.1

COPILOT_TOKEN_DIR := $(HOME)/.config/litellm/github_copilot

-include $(ENV_FILE)
export

.DEFAULT_GOAL := help

.PHONY: help install run keys test models health clean auth-reset

help:
	@echo "make install     Create $(VENV) and generate $(ENV_FILE) keys"
	@echo "make run         Start the proxy on $(HOST):$(PORT)"
	@echo "make keys        Print the master and salt keys"
	@echo "make test        Send a chat completion (MODEL=$(MODEL))"
	@echo "make models      List models served by the proxy"
	@echo "make health      Check proxy liveliness"
	@echo "make auth-reset  Delete stored GitHub Copilot tokens"
	@echo "make clean       Remove $(VENV)"

$(ENV_FILE):
	@echo "LITELLM_MASTER_KEY=sk-$$(uuidgen | tr 'A-Z' 'a-z')" > $@
	@echo "LITELLM_SALT_KEY=sk-$$(uuidgen | tr 'A-Z' 'a-z')" >> $@
	@echo "generated $@"

# fastapi is pinned because 0.141+ breaks litellm proxy startup on import.
$(LITELLM):
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install "litellm[proxy]==$(LITELLM_VERSION)" "fastapi==$(FASTAPI_VERSION)"

install: $(LITELLM) $(ENV_FILE)

run: install
	$(LITELLM) --config $(CONFIG) --host $(HOST) --port $(PORT)

keys: $(ENV_FILE)
	@echo "LITELLM_MASTER_KEY=$(LITELLM_MASTER_KEY)"
	@echo "LITELLM_SALT_KEY=$(LITELLM_SALT_KEY)"

health:
	@curl -sS http://$(HOST):$(PORT)/health/liveliness; echo

models:
	@curl -sS http://$(HOST):$(PORT)/models \
		-H "Authorization: Bearer $(LITELLM_MASTER_KEY)"; echo

test:
	@curl -sS http://$(HOST):$(PORT)/chat/completions \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $(LITELLM_MASTER_KEY)" \
		-d '{"model":"$(MODEL)","messages":[{"role":"user","content":"Reply with exactly: LiteLLM is working"}]}'; echo

auth-reset:
	rm -rf $(COPILOT_TOKEN_DIR)

clean:
	rm -rf $(VENV)
