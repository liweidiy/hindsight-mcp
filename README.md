# hindsight-mcp

Self-hosted [Hindsight](https://github.com/vectorize-io/hindsight) memory server on a home
server, plus the DeepSeek Harness (DSH) client-side wiring that lets two independent
DSH channels share one memory bank — the REST channel of the coding-agents plugin and the
MCP channel of the DSH MCP manager.

> **中文**
> 这是一套**自建 Hindsight 记忆服务的部署配置**（不是 Hindsight 引擎源码）。
> 内容包括：systemd 用户服务单元 + 环境变量模板、Postgres(pg0) 依赖说明、
> 让 DSH 通过 **MCP 通道**和**插件原生通道**共用同一个 bank 的两份配置、
> bank 命名规范，以及 bank 迁移 / 备份 / 清理的实操 runbook（含踩过的坑）。
> 仓库内**不含任何密钥**，所有敏感值均为占位符。

## What this repository is / is not

| | |
|---|---|
| **Is** | My own deployment artifacts: the systemd unit, the environment-file shape, the DSH patch rows, the plugin config shape, bank policy, and an operations runbook. |
| **Is not** | The Hindsight engine, its API, or the DSH integration plugin source. Those are upstream projects — see [Third-party components](#third-party-components). |

## Layout

```
hindsight-deploy/
├── server/
│   ├── hindsight-api.service          # systemd user unit (this host, verified)
│   └── hindsight-api.env.example      # variable names only, secrets as placeholders
├── dsh/
│   ├── cordis.patch.snippet.yml       # DSH profile row: managed MCP server "hindsight"
│   ├── coding-agent.json.example      # @vectorize-io/hindsight-coding-agents config shape
│   └── credentials.example.yaml       # where the API key must live (never in the patch)
├── docs/
│   ├── architecture.md                # one process serving REST + /mcp, DB, ports
│   ├── banks.md                       # bank naming + how the default bank is resolved
│   ├── dsh-integration.md             # field-by-field notes for the native channel
│   └── runbook.md                     # backup / migrate / cleanup / restart, with gotchas
└── scripts/
    ├── export-bank.sh
    ├── import-bank.sh
    └── restart-api.sh
```

## Topology at a glance

```
Windows PC (DSH)                                  Home server (Ubuntu, x86_64 + NVIDIA)
├─ plugin @vectorize-io/hindsight-coding-agents ─┐
│    config: ~/.hindsight/coding-agent.json      │   hindsight-api 0.10.1  (one process)
│    → http://<HOST>:18888  (REST)               ├──→ 0.0.0.0:18888  ── /mcp  (MCP, Streamable HTTP)
└─ plugin @deepseek-ai/dsh-mcp-manager ──────────┘        │
     config: $DSH_HOME/profiles/<profile>/cordis.patch.yml│
     Bearer ${credential:HINDSIGHT_API_KEY}               └── pg0 Postgres 18.1.0, port 5433
```

Both arrows terminate at **the same process and the same database**, so the two DSH
channels read and write the same bank. See [docs/architecture.md](docs/architecture.md).

## Ports

| Port | Service | Exposure |
|---|---|---|
| `18888` | `hindsight-api` — REST **+** `/mcp` | loopback, tailnet, plus an allow-listed LAN subnet (nftables) |
| `5433` | pg0-managed Postgres cluster `hindsight` | loopback only |
| `11370` | local OpenAI-compatible LLM endpoint used as `HINDSIGHT_API_LLM_BASE_URL` | loopback only |
| `2223` | SSH to the host (non-default port) | LAN + tailnet |

## Quick start

```bash
# 1. venv + engine (upstream package, not vendored here)
python -m venv ~/.venvs/hindsight && source ~/.venvs/hindsight/bin/activate
pip install hindsight-api

# 2. config: env file must be readable only by the service user
install -m 600 server/hindsight-api.env.example ~/.hermes/hindsight-api.env
$EDITOR ~/.hermes/hindsight-api.env        # fill the <REDACTED> placeholders

# 3. service
mkdir -p ~/.config/systemd/user
install -m 644 server/hindsight-api.service ~/.config/systemd/user/hindsight-api.service
systemctl --user daemon-reload
systemctl --user enable --now hindsight-api.service
systemctl --user status hindsight-api.service

# 4. DSH side: merge dsh/cordis.patch.snippet.yml into
#    $DSH_HOME/profiles/<profile>/cordis.patch.yml and store the API key
#    as the credential reference HINDSIGHT_API_KEY (see dsh/credentials.example.yaml).
```

`hindsight-api` discovers its database through a `pg0` instance named `hindsight`
(`~/.pg0/instances/hindsight/data`). A cluster can be created/listed with the `pg0` CLI;
no `DATABASE_URL` is set in this deployment.

## Why `HINDSIGHT_MCP_BANK_ID` matters

The MCP connection is the one that needs an explicit default. Upstream
`hindsight_api/api/mcp.py` resolves a bank in this order:

1. the bank id embedded in the URL path (`/mcp/{bank_id}/`, single-bank mode),
2. the `X-Bank-Id` request header,
3. `DEFAULT_BANK_ID = os.environ.get("HINDSIGHT_MCP_BANK_ID", "default")`.

Without the variable, every DSH MCP call that omits `bank_id` silently lands in a bank
named `default`. Setting `HINDSIGHT_MCP_BANK_ID=<my-bank>` in the service's
`EnvironmentFile` makes the MCP channel and the plugin-native channel agree on one bank.
Full details and the verification method: [docs/banks.md](docs/banks.md).

## Security notes

- No secret values are committed. `server/hindsight-api.env.example` keeps variable
  **names** and real non-secret settings; keys/tokens are `<REDACTED>`.
- Keep the real env file at mode `600` and out of git (see `.gitignore`).
- On the DSH side the key lives in `$DSH_HOME/.credentials.yaml` under `refs:` and is
  referenced as `${credential:HINDSIGHT_API_KEY}` inside the patch, so it never enters
  the config tree or diagnostics output.
- Before publishing, review the absolute paths in `server/hindsight-api.service`
  (`/home/<user>/...`) — they name this host's account.

## Client-side configuration

- MCP channel: [dsh/cordis.patch.snippet.yml](dsh/cordis.patch.snippet.yml) +
  [dsh/credentials.example.yaml](dsh/credentials.example.yaml)
- Native channel: [dsh/coding-agent.json.example](dsh/coding-agent.json.example),
  explained in [docs/dsh-integration.md](docs/dsh-integration.md)

## Third-party components

This repository contains **no upstream source code**. The pieces it configures:

| Component | Where it comes from | License |
|---|---|---|
| `hindsight-api` / `hindsight_api` (server, MCP layer, `hindsight-admin` CLI) | <https://github.com/vectorize-io/hindsight> | see upstream repo |
| `@vectorize-io/hindsight-coding-agents` (DSH plugin, native memory channel) | npm; upstream directory `hindsight-integrations/coding-agents` in the same repo | MIT, Copyright (c) 2025 Vectorize AI, Inc. |
| `@deepseek-ai/dsh-mcp-manager` (DSH plugin that owns `config.servers`) | DeepSeek Harness | see its package |
| `pg0` (Postgres cluster manager) | upstream project | see its package |

If you want the engine code, clone or fork the upstream repository rather than copying
files from here — the upstream MIT text and its copyright line must travel with it.

## License

MIT — see [LICENSE](LICENSE) and the scope notice in [NOTICE.md](NOTICE.md). It applies to
**my** configuration files, scripts, and documentation in this repository only, not to the
third-party components above.
