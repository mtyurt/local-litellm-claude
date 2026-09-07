# ABOUTME: Build targets for running a local LiteLLM proxy with selectable providers.
# ABOUTME: Master and salt keys are generated once as UUIDs and persisted in .env.

VENV := .venv-litellm
LITELLM := $(VENV)/bin/litellm
PIP := $(VENV)/bin/pip
ENV_FILE := .env
COMPAT_PATH := $(CURDIR)/litellm_compat

HOST ?= 127.0.0.1
PORT ?= 4000
MODEL ?= claude-sonnet-5
LLM_PROVIDER ?= chatgpt
SUPPORTED_PROVIDERS := chatgpt copilot anthropic
CONFIG := $(LLM_PROVIDER)-litellm-config.yml

LITELLM_VERSION := 1.97.0
FASTAPI_VERSION := 0.140.1

COPILOT_TOKEN_DIR := $(HOME)/.config/litellm/github_copilot

ifeq ($(filter $(LLM_PROVIDER),$(SUPPORTED_PROVIDERS)),)
$(error Unsupported LLM_PROVIDER '$(LLM_PROVIDER)'. Choose one of: $(SUPPORTED_PROVIDERS))
endif

-include $(ENV_FILE)
export

.DEFAULT_GOAL := help

.PHONY: help install run keys test models health clean auth-reset

help:
	@echo "make install                         Create $(VENV) and generate $(ENV_FILE) keys"
	@echo "make run LLM_PROVIDER=chatgpt         Start the ChatGPT proxy on $(HOST):$(PORT)"
	@echo "make run LLM_PROVIDER=copilot         Start the GitHub Copilot proxy"
	@echo "make run LLM_PROVIDER=anthropic       Start the Anthropic proxy"
	@echo "make keys                            Print the master and salt keys"
	@echo "make test                            Send a chat completion (MODEL=$(MODEL))"
	@echo "make models                          List models served by the proxy"
	@echo "make health                          Check proxy liveliness"
	@echo "make auth-reset                      Delete stored GitHub Copilot tokens"
	@echo "make clean                           Remove $(VENV)"

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
	@test -f "$(CONFIG)" || { echo "Missing provider config: $(CONFIG)" >&2; exit 1; }
	@echo "Starting $(LLM_PROVIDER) proxy with $(CONFIG) on $(HOST):$(PORT)"
	PYTHONPATH="$(COMPAT_PATH)$${PYTHONPATH:+:$$PYTHONPATH}" \
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
