# Operations runbook

All server-side commands run as the service user on the host, over SSH on port `2223`.
The CLI lives in the same venv as the API:

```bash
ADMIN=$HOME/.venvs/hindsight/bin/hindsight-admin
"$ADMIN" --help        # subcommands, including backup / restore / run-db-migration /
                       # repair-bank / rename-bank / export-bank / import-bank / worker-status
```

## 1. Backup

Whole-server archive:

```bash
"$ADMIN" backup -o ~/.hermes/backups/hindsight-$(date +%Y%m%d).zip
```

Single bank (what I actually use before touching a bank):

```bash
"$ADMIN" export-bank -b sylw -o ~/.hermes/export-bank-sylw-$(date +%Y%m%d).zip
# extras: --schema (schema-only export), --include-history
```

Exports are ZIPs containing the bank's documents, observations, and an operations log.
I keep them on the server (`~/.hermes/`) and do not copy them to client machines.

> **Critical gotcha.** Do **not** source the EnvironmentFile before calling
> `hindsight-admin`:
>
> ```bash
> set -a; . ~/.hermes/hindsight-api.env; set +a   # BREAKS
> ```
>
> Sourcing it through bash mangles `HINDSIGHT_API_LLM_EXTRA_BODY={"chat_template_kwargs":{...}}`
> (brace expansion / word splitting), and the CLI then dies inside config loading with
> `json.decoder.JSONDecodeError: Expecting property name enclosed in double quotes`.
> The CLI discovers the pg0 instance and its own settings on its own — run it clean.

## 2. Restore / import

```bash
"$ADMIN" restore -i ~/.hermes/backups/hindsight-20261120.zip     # full server
"$ADMIN" import-bank -a ~/.hermes/export-bank-sylw-20261120.zip  # restores bank "sylw"
"$ADMIN" import-bank -a <zip> --target-bank new-name             # import AS a new name
```

**`import-bank` cannot merge.** The target bank must not already exist, and there is no
`--merge` flag. So import is only usable for (a) restoring a bank you deleted, or
(b) moving a bank's content into a *new* name.

## 3. Renaming a bank

```bash
"$ADMIN" rename-bank <old-id> <new-id>
```

Prefer this over export + import whenever the bank is staying on the same server.

## 4. Merging bank A into existing bank B

Because import cannot merge, a merge is a content operation, not a file operation:

```text
1. export-bank -b A -o ...            # safety net, always first
2. list A's facts (mcp__hindsight__list_memories, paged) and re-retain the ones worth
   keeping into B  (mcp__hindsight__retain / sync_retain, or the native channel)
3. soft-retire A's originals with mcp__hindsight__invalidate_memory  (reversible, keeps
   the unit for audit; derived observations are recomputed without them)
4. compare B's counts before and after
5. delete_bank A only after B looks complete
```

Two practical notes:

- **Serialize the `invalidate_memory` calls.** A batch fired concurrently produced
  `deadlock detected ... waits for ShareLock on transaction ...` on Postgres. One call at
  a time is fine.
- `invalidate_memory` only accepts raw `world` / `experience` facts. Observations are
  derived and you cannot invalidate them directly — they change when their sources do.

## 5. Restarting the service

```bash
systemctl --user restart hindsight-api.service
journalctl --user -u hindsight-api.service -n 30 --no-pager   # expect "Application startup complete"
"$ADMIN" worker-status
```

Budget **~20 seconds** of downtime. In-flight worker tasks do not survive it: on the
restart I measured, one task ended in `failed` after `exceeded 3 recovery attempts`, and
`worker-status` is how you notice.

## 6. MCP query habits that avoid timeouts

- The reflect LLM is a local model with `HINDSIGHT_API_LLM_TIMEOUT=300`. A `reflect` or a
  `recall` with a large budget on a big bank can legitimately run for minutes, and
  concurrent MCP calls multiplied that into client-side `Request timed out`. Run heavy
  reasoning calls one at a time, keep `budget` low for checks.
- For "is this fact already stored?" checks, **do not** use `recall` four times in
  parallel. Use `mcp__hindsight__list_memories` with `q=<single token>` — a plain browse,
  fast, no LLM involved.
- `list_memories` filter semantics: `tags_match: any` and `all` **also return untagged**
  units, so a tag filter is not a strict narrowing. Text search via `q=` is more
  predictable for dedup work.
- Query strings must be strings: a bare numeric filter (e.g. `q=18888`) is rejected by
  pydantic (`Input should be a valid string`).

## 7. Repairing a bank

```bash
"$ADMIN" repair-bank -b <bank-id>
"$ADMIN" run-db-migration          # after an engine version bump
"$ADMIN" decommission-workers      # stale worker rows
```
