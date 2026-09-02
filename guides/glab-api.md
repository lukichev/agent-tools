# glab and GitLab API Reference

Shared by `git-rebase`, `git-rebase-all`, `mr-review`, `mr-status-check` and `mr-comment`. Every item here is a rule that produces a wrong result when you ignore it.

`glab` is not `gh`. The flags differ.

## Command and flag limits

| Limit | What to do instead |
| --- | --- |
| `--jq` is unsupported and returns empty | Pipe raw JSON to `jq` or `python3` |
| `glab mr diff <IID>` has no `--name-only` | Take the file list from the diffs API |
| Default page size is 20, so a busy MR truncates in silence | Add `per_page=100` to every list endpoint |

## Fields that need a query parameter

`rebase_in_progress` is omitted unless `?include_rebase_in_progress=true` is in the query string. Without it the field reads `null`, never `false`, so a poll reports success at once.

## Discussions carry activity entries

GitLab returns activity entries as discussions: "changed the description", "added 1 commit". Drop every note where `system == true` before you count or display anything. An MR can consist entirely of these. Unfiltered, the output invents prior feedback that nobody wrote.

## Mergeability is cached in list responses

`glab mr list` returns cached mergeability. It often reports `detailed_merge_status: "unchecked"` with a meaningless `has_conflicts: false`. Never decide anything from those values.

To force GitLab's lazy recompute, call the single-MR GET endpoint and poll until the status leaves `unchecked` and `checking`:

```bash
while :; do
  dms=$(glab api "projects/:fullpath/merge_requests/<iid>" \
    | python3 -c "import json,sys;print(json.load(sys.stdin)['detailed_merge_status'])")
  [ "$dms" != unchecked ] && [ "$dms" != checking ] && break
  sleep 3
done
```

Key off `detailed_merge_status`, not `has_conflicts`:

| Value | Meaning |
| --- | --- |
| `conflict`, or `merge_status: "cannot_be_merged"` | A local worktree rebase is required. Server-side rebase fails. |
| `need_rebase` | Behind the target. Server-side rebase is safe. |
| Clean states | Server-side rebase is safe. |

## Inline comments need the Discussions API

The `-f` form fields of `glab api` do not nest the `position` object. The comment posts as a general MR comment instead of an inline one. Use `curl` against the Discussions API, then confirm `notes[0].type` is `DiffNote`.

## jq breaks on payloads with raw control characters

A description that holds raw control characters makes `jq` fail with "Invalid string: control characters ... must be escaped" and return empty output. A poll loop then reads an empty `rebase_in_progress` and exits with a false "done".

Parse with `python3` when a payload may hold such text:

```bash
glab api "projects/:fullpath/merge_requests/<iid>?include_rebase_in_progress=true" \
  | python3 -c "import json,sys;d=json.load(sys.stdin,strict=False);print(d.get('rebase_in_progress'),d.get('merge_error'),d['sha'])"
```
