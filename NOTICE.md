# Scope of this license

The MIT license in `LICENSE` covers **only** the configuration files, scripts, and
documentation authored in this repository:

```
README.md  NOTICE.md  .gitignore  .gitattributes
server/hindsight-api.service          server/hindsight-api.env.example
dsh/cordis.patch.snippet.yml          dsh/coding-agent.json.example
dsh/credentials.example.yaml
docs/architecture.md  docs/banks.md  docs/dsh-integration.md  docs/runbook.md
scripts/export-bank.sh  scripts/import-bank.sh  scripts/restart-api.sh
```

It does **not** cover the software that these files configure or depend on:

| Component | Upstream | License |
|---|---|---|
| Hindsight server, MCP layer, `hindsight-admin` CLI | <https://github.com/vectorize-io/hindsight> | see upstream repository |
| `@vectorize-io/hindsight-coding-agents` (DSH plugin; upstream directory `hindsight-integrations/coding-agents`) | same upstream repository | MIT, Copyright (c) 2025 Vectorize AI, Inc. |
| `@deepseek-ai/dsh-mcp-manager` | DeepSeek Harness | see its package |
| `pg0` (Postgres cluster manager) | its own project | see its package |

This repository vendors none of that code. To obtain it, install the packages or clone the
upstream repositories — the upstream copyright notices and license texts must travel with
any copy or fork of them.
