# The native channel: `@vectorize-io/hindsight-coding-agents`

Upstream plugin (MIT, Copyright (c) 2025 Vectorize AI, Inc.), shipped as the npm package
`@vectorize-io/hindsight-coding-agents` and developed in the `hindsight-integrations/coding-agents`
directory of <https://github.com/vectorize-io/hindsight>. Install it through DSH's plugin
manager, not by copying files.

Its configuration is a single JSON file, **outside** the DSH profile directory:

```
$HOME/.hindsight/coding-agent.json          # Windows: C:\Users\<you>\.hindsight\coding-agent.json
```

`dsh/coding-agent.json.example` in this repository is that file with the token replaced.
Field meanings as used here:

| Field | Value on this host | Effect |
|---|---|---|
| `serverMode` | `self-hosted` | talk to my own `apiUrl` instead of the hosted service |
| `apiUrl` | `http://<HINDSIGHT_HOST>:18888` | the REST side of the same process that serves `/mcp` |
| `apiToken` | `<REDACTED>` | tenant API key |
| `bankId` | `sylw` | the bank this channel reads and writes |
| `dynamicBankId` | `false` | do **not** derive a per-repository bank from the workspace; pin to `bankId` |
| `retainTags` | `device:{project}`, `env:win` | tags stamped on retained facts; `{project}` is expanded per workspace |
| `retainMetadata` | `device: {project}` | metadata stamped on retained facts |
| `codebaseSurvey` | `false` | do not scan the repository into memory |
| `autoInject` | `pages` | inject knowledge pages (not raw memories) into the agent context |
| `injectTimeoutMs` | `20000` | a slow server must not stall the first turn |
| `reflectToolTimeoutMs` | `300000` | `reflect` is a multi-minute operation on a large bank |
| `pageTriggerCron` | `H 4 * * *` | refresh knowledge pages around 04:00 |
| `gitIngest` | `message` | feed commit messages into memory (not full diffs) |
| `retainSessions` | `true` | retain the conversation itself as experience |
| `logLevel` | `info` | diagnostics land in `~/.hindsight/coding-agents-logs/diag.jsonl` |

`dynamicBankId` is the setting most likely to surprise you. Left enabled, the plugin
derives a bank per project, and the MCP channel — which defaults to
`HINDSIGHT_MCP_BANK_ID` — ends up in a different bank. Pin both sides to one id, then
verify with `hindsight_diagnose` (native) and `mcp__hindsight__get_bank` (MCP).
