# ScreenOCR (screentext)

Native macOS menu bar app: region capture → on-device Vision OCR → clipboard.

**Cursor:** project rules, architecture, and build notes live in [`cursor.md`](./cursor.md). Cursor loads [`.cursor/rules/`](./.cursor/rules/) automatically.

## Agent skills

### Issue tracker

Work lives under `.scratch/<feature>/` as markdown (specs + numbered issue files). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `GLOSSARY.md` (when present) and `docs/adr/`. See `docs/agents/domain.md`.
