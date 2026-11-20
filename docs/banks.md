# Banks: naming, default resolution, hygiene

A *bank* is an isolated memory store inside one Hindsight server — like a separate brain
that shares the same process, models, and Postgres cluster.

## This host's layout

| Bank | Purpose |
|---|---|
| `sylw` | personal / cross-device memory; the default for **both** DSH channels |
| `ops::field-maintenance` | machine and infrastructure notes (namespaced with `::`) |
| `quant-t0` | trading / research notes |

Naming rule: one unqualified bank per person or agent, and `<domain>::<scope>` for topic
banks. The `::` is just a character — Hindsight does not treat it as a hierarchy — but it
makes a flat bank list readable.

## How the server picks a bank for an MCP request

Observed in `hindsight_api/api/mcp.py` (engine 0.10.1):

```python
DEFAULT_BANK_ID = os.environ.get("HINDSIGHT_MCP_BANK_ID", "default")
```

Resolution order for a request:

1. **Bank in the URL path** — `/mcp/{bank_id}/` pins the connection to one bank
   (single-bank mode; `bank_id` then disappears from the tool schemas).
2. **`X-Bank-Id` request header.**
3. **`DEFAULT_BANK_ID`**, i.e. `HINDSIGHT_MCP_BANK_ID`, falling back to `"default"`.

A request that carries an explicit `bank_id` **argument** on the tool call wins over the
header/default for that call.

Consequence: if you never set `HINDSIGHT_MCP_BANK_ID`, every DSH MCP call that omits
`bank_id` quietly writes into a bank named `default` — while the native plugin channel
uses its own `bankId`. Two channels, two banks, one database. That is exactly the split
this configuration removes:

```
# in ~/.hermes/hindsight-api.env
HINDSIGHT_MCP_BANK_ID=sylw
```

then `systemctl --user restart hindsight-api.service`.

## Verifying which bank a channel actually uses

1. MCP channel, no `bank_id` argument: call `mcp__hindsight__get_bank` and read the bank
   id in the response. `mcp__hindsight__list_banks` shows the whole visible set.
2. Native channel: `hindsight_diagnose` prints the resolved bank, workspace, and endpoint.
3. Cross-check: `hindsight_list_knowledge_pages` on the native side and
   `mcp__hindsight__get_knowledge_base_tree` on the MCP side should list the same pages.

Do not verify via a hand-made REST URL — the REST bank endpoints are not shaped like
`GET /default/banks`, and a 404 there proves nothing.

## Hygiene rules learned the hard way

- **Empty banks accumulate silently.** A few mis-routed calls created `default` and
  `shared`; both looked harmless and both polluted `list_banks`. Export, then delete.
- **`delete_bank` is irreversible** and takes all facts, documents, mental models, and
  directives with it. Always export first (see the runbook) and confirm the export opened.
- **`rename-bank` is the cheap fix** when the bank has content and only the name is wrong;
  it avoids an export/import round trip.
- **Keep the default bank's name stable.** Client-side configs, cron-refreshed mental
  models, and saved knowledge pages all embed the id.
