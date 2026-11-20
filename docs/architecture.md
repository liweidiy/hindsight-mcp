# Architecture: one Hindsight process, two DSH channels

## The server

`hindsight-api` (0.10.1 on this host) runs as a **single systemd user service** and
listens on `0.0.0.0:18888`. That one process exposes both interfaces:

- the **REST API** (`/...`) used by the coding-agents plugin,
- the **MCP endpoint** `/mcp` (Streamable HTTP transport) used by DSH's MCP manager.

The MCP identity reported by the endpoint is `hindsight-mcp-server 0.10.1` — the same
version as the API, because it is the same package and the same process. There is no
separate MCP gateway, no second port, and no reverse proxy in front of it.

## Persistence

Postgres is managed by `pg0`, not by a system package:

```
instance name : hindsight
cluster data  : ~/.pg0/instances/hindsight/data
binary        : ~/.pg0/installation/18.1.0/bin/postgres
runtime       : postgres -D ~/.pg0/instances/hindsight/data -F -p 5433
database/user : hindsight / hindsight
```

`DATABASE_URL` is **not** set in the environment file: the API discovers the pg0
instance itself. That also means the `hindsight-admin` CLI works without exporting any
database settings.

## Model and LLM wiring

| Role | Provider | Model |
|---|---|---|
| Embeddings | `local` | `Qwen/Qwen3-Embedding-0.6B` |
| Reranker | `local` | `Qwen/Qwen3-Reranker-0.6B` |
| Reflect / consolidation LLM | `openai` (OpenAI-compatible) | `qwen3.8-flash-next-iq3_xxs` @ `http://127.0.0.1:11370/v1` |

`HF_HUB_OFFLINE=1` and `TRANSFORMERS_OFFLINE=1` keep the server runnable without
network access to the Hugging Face hub; the models are served from the local cache.
`CUDA_VISIBLE_DEVICES=` (empty) in the unit keeps the small embedding/reranker models on
CPU so VRAM stays available for the LLM inference server.

## The two DSH channels

Both are installed in the same DSH profile, and both are pointed at the same bank.

| | Native channel | MCP channel |
|---|---|---|
| Plugin | `@vectorize-io/hindsight-coding-agents` | `@deepseek-ai/dsh-mcp-manager` |
| Transport | REST against `apiUrl` | MCP `streamable-http` against `/mcp` |
| Config file | `~/.hindsight/coding-agent.json` | `$DSH_HOME/profiles/<profile>/cordis.patch.yml` |
| Tools it adds | the `hindsight_*` tools (`hindsight_reflect`, `hindsight_recall`-equivalents, knowledge-page tools, `hindsight_diagnose`, …) | the `mcp__hindsight__*` tools (`recall`, `reflect`, `retain`, `create_knowledge_page`, `list_banks`, …) |
| Auth | `apiToken` field | `Authorization: Bearer ${credential:HINDSIGHT_API_KEY}` |
| Bank selection | `bankId` field, `dynamicBankId: false` | `bank_id` argument per call, else server default |

Because the two channels hit the same process and database, a fact retained through one
is visible to the other. That is the property the whole configuration is built around —
and the reason the bank default on the MCP side had to be pinned (see [banks.md](banks.md)).

## Network exposure

`--host 0.0.0.0` alone would expose the API to the whole LAN, so exposure is deliberately
split on this host:

- **loopback** — the host's own clients (including the local LLM endpoint on `11370`),
- **tailnet** — the Tailscale interface, with ACL grants that include `tcp:18888`
  (and `tcp:2223` for SSH, `tcp:11370`, `tcp:8642`),
- **LAN** — only an allow-listed subset of the local subnet, via an nftables allow-list.

The unit orders itself after `tailscaled.service` (`After=` + `Wants=`) so a boot does not
start the API before the tailnet interface exists.
