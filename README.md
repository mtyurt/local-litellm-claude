# local-litellm

Run a local [LiteLLM](https://github.com/BerriAI/litellm) proxy with a ChatGPT, GitHub Copilot,
or Anthropic provider configuration, and point [Claude Code](https://docs.anthropic.com/en/docs/claude-code) at it.

## Requirements

- macOS with `python3` (3.10+)
- A subscription or API key for the selected provider
- `claude` CLI installed (`npm i -g @anthropic-ai/claude-code`)

## Provider configuration

Select a provider with `LLM_PROVIDER` when starting the proxy:

```bash
make run LLM_PROVIDER=chatgpt
make run LLM_PROVIDER=copilot
make run LLM_PROVIDER=anthropic
```

`chatgpt` is the default. The corresponding provider configuration is loaded from
`<provider>-litellm-config.yml`. The Anthropic provider requires `ANTHROPIC_API_KEY` in the shell
environment before running the proxy. ChatGPT and GitHub Copilot authenticate through LiteLLM's
provider-specific flows.

## 1. Install

```bash
make install
```

This creates the `.venv-litellm` virtualenv with `litellm[proxy]==1.97.0` and
`fastapi==0.140.1` (FastAPI is pinned because 0.141+ breaks proxy startup), and generates
`.env` with a random `LITELLM_MASTER_KEY` and `LITELLM_SALT_KEY`. `.env` is gitignored.

## 2. Run the proxy

```bash
make run LLM_PROVIDER=chatgpt
```

Serves on `127.0.0.1:4000` by default. Override with
`make run LLM_PROVIDER=copilot HOST=0.0.0.0 PORT=4100`.

On the **first GitHub Copilot run** you will be prompted for GitHub device auth:

```text
Please visit https://github.com/login/device and enter code XXXX-XXXX
```

Tokens are cached in `~/.config/litellm/github_copilot/`. Use `make auth-reset` to clear them.

## 3. Verify

From another terminal:

```bash
make health          # proxy liveliness
make models          # list served models
make test            # send a chat completion
make test MODEL=claude-opus-5
```

## 4. Run Claude Code against the proxy

```bash
./claude.sh
```

`claude.sh` sources `.env` and launches `claude` with:

| Variable | Value |
| --- | --- |
| `ANTHROPIC_BASE_URL` | `http://localhost:4000` |
| `ANTHROPIC_AUTH_TOKEN` | `$LITELLM_MASTER_KEY` |
| `ANTHROPIC_MODEL` | `claude-sonnet-5` |
| `ANTHROPIC_SMALL_FAST_MODEL` | `claude-haiku-4-5` |

Any arguments are passed through, e.g. `./claude.sh --help`.

## Configured models

- `chatgpt-litellm-config.yml` maps the three GPT models and Claude model aliases to ChatGPT.
- `copilot-litellm-config.yml` exposes the GPT and Claude models available through GitHub Copilot.
- `anthropic-litellm-config.yml` exposes Claude Opus, Sonnet, and Haiku directly through Anthropic.

Add a model to the matching provider configuration by appending an entry that maps a `model_name`
to the appropriate LiteLLM provider target.

## Make targets

| Target | Description |
| --- | --- |
| `install` | Create the virtualenv and generate `.env` keys |
| `run` | Start the proxy (`LLM_PROVIDER=chatgpt`, `copilot`, or `anthropic`) |
| `keys` | Print the master and salt keys |
| `health` | Check proxy liveliness |
| `models` | List models served by the proxy |
| `test` | Send a chat completion (`MODEL=` to choose) |
| `auth-reset` | Delete stored GitHub Copilot tokens |
| `clean` | Remove the virtualenv |

## Troubleshooting

- **Proxy fails on startup with a FastAPI import error** — the pin was lost. Run `make clean install`.
- **401 from `make test`** — `.env` and the running proxy disagree; restart `make run`.
- **Device auth prompt loops** — `make auth-reset`, then `make run` again.
