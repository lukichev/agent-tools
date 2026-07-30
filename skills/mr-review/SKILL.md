---
name: mr-review
description: Review a GitLab MR end to end. Checks the MR head out in a dedicated worktree, pulls the Jira ticket, shows existing discussions, then reports AC coverage, debug artifacts, MR hygiene and numbered code-review findings. Use when the user wants to review an MR, check MR comments, or says "review MR !123".
argument-hint: "<MR number or URL>"
---

# MR Review

Review a merge request end to end, read-only. Mostly used on **other people's MRs**.

Two checks come from `~/.claude/skills/ready-check/references/`: `ac-coverage.md` and `debug-artifacts.md`. Read them where the steps say so. Never read `ready-check/SKILL.md` itself, it reads the local tree and gates on the user.

Needs `glab` authenticated. Atlassian MCP is optional: without it, skip the ticket steps and note the gap.

## 1. Fetch MR metadata

Parse the MR number from `$ARGUMENTS` (bare number or full URL). In parallel:

```bash
glab mr view <IID> --output json
glab api "projects/:fullpath/merge_requests/<IID>/discussions?per_page=100"
glab api "projects/:fullpath/merge_requests/<IID>/diffs?per_page=100"
glab api "projects/:fullpath/merge_requests/<IID>/approvals" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print({k:d[k] for k in ('approved','approvals_required','approvals_left','approved_by','approval_rules_left')})"
```

Keep: `source_branch`, `target_branch`, `author`, `state`, `draft`, `title`, `description`, `changes_count`, `diff_refs.base_sha`, `diff_refs.head_sha`, `detailed_merge_status`, `has_conflicts`, `diverged_commits_count`, `head_pipeline.status`, changed files from `new_path`.

- **Draft: stop.** `draft` true, or a title starting with `Draft:`, cancels the review before the worktree and the agents. Continue only if the user explicitly asked for a draft review.
- **Drop notes where `system == true`.** GitLab returns activity entries as discussions, and an MR can be nothing but those (!7000 is 7 of 7). Unfiltered, the output invents prior feedback.
- `per_page=100` is required, the default is 20. The approvals filter cuts an 11 KB payload of avatars down to 5 fields.
- `glab mr diff <IID>` prints the diff and has **no** `--name-only`. The file list comes from the diffs API.

## 2. Check the MR head out in a worktree

```bash
WT="<scratchpad>/mr-<IID>"          # session scratchpad; /tmp if none
git worktree prune
git fetch origin "refs/merge-requests/<IID>/head:refs/mr-review/<IID>" --force
git worktree add -B "mr-<IID>" "$WT" "refs/mr-review/<IID>"
git -C "$WT" rev-parse HEAD          # must equal diff_refs.head_sha
```

- Fetch the **MR ref**, not `origin/<source_branch>`: the local branch may be stale, and the source may be a fork.
- The worktree carries a real local branch named `mr-<IID>`, so `git branch -v` lists it. Never name it after the author's branch: that name collides with the user's own checkout of the same ticket. `-B` resets the branch when the author pushes.
- If `$WT` exists, reuse it when HEAD matches `head_sha`. Otherwise the author pushed, so `git worktree remove "$WT"` and recreate. If `remove` refuses, someone edited the tree by hand: report it, never force.
- `git -C` is correct here. The project rule against it covers the repo root.
- No `node_modules` in the worktree. No build, lint or tests inside it.

## 3. Detect the ticket ID

First `[A-Z][A-Z0-9]+-[0-9]+` match in `source_branch`, then the title, then the description. No match skips 4b and 5.

## 4. Launch the agents in one message

One message, so they run together. The research does not need the worktree.

Reviewer count scales off `changes_count` (a string, sometimes `"1000+"`):

| Changed files | Reviewers |
| --- | --- |
| ≤ 40 | 1, whole diff |
| 41 - 120 | 2 to 3, split by top-level area |
| > 120 or `1000+` | one per area, cap 6 |

Split on leading path segments (`src/_nest/identity`, `apps/portal`). Each reviewer gets its file subset and the identical rules. Merge findings and drop duplicates afterwards. **Migrations always get a dedicated reviewer** at any size: foreign-key reasoning needs the whole set, not a slice. Declare any capped area in the output, a silent cap reads as full coverage.

**4a. `code-reviewer`**, default model, self-contained prompt carrying:

- MR number, title, author, `source_branch` → `target_branch`, state, its file subset
- The description, labelled as the author's claims
- **The worktree path, which IS the MR state.** Read and grep there, never the primary tree, which holds another branch.
- **Pre-change state is `git show <base_sha>:<path>`**, from `diff_refs.base_sha`. Not `main`, not `<target_branch>`: either can sit hundreds of files from the diff base.
- Unresolved discussions, one line each, so it does not repeat existing feedback
- Focus areas from what the MR touches. Call out migrations, auth, deletes, schema changes.
- Rules: no finding from the diff alone; verify against worktree source; check whether nearby code or tests already cover it; drop false positives; run completeness greps repo-wide **inside the worktree**; skip non-standard style; state which author testing claims you verified and which you could not
- Output: numbered list, each with `file:line`, a category (bug / security / performance / data-safety / testing / style), a one-line failure scenario, a one-line fix. No essays.

**Never pass the ticket to a reviewer.** Independence is the point: they judge the code, the orchestrator judges it against the ACs in step 5.

**4b. `atlassian-researcher`** - the ticket ID. Ask for ACs, dev notes, linked tickets, decisions in comments. Confluence off unless requested.

## 5. AC coverage

Read `ready-check/references/ac-coverage.md` with `TICKET` = the 4b output, `DIFF` = `glab mr diff <IID>`, `TREE` = the worktree path. **Report, do not gate.**

## 6. Debug artifacts

Read `ready-check/references/debug-artifacts.md` with `DIFF` = `glab mr diff <IID>`.

## 7. Hygiene

From step 1 data only. Do not re-fetch.

## Output

Terse: tables and lists, no prose, no preamble, no closing paragraph, no restatement of the description. These blocks, nothing else.

```markdown
## !<IID> <TITLE>
`<author>` · <source> → <target> · <state> · <n> files · pipeline <status>

### Prior comments
- `<file>:<line>` **<author>** <Unresolved|Resolved> - <one-line gist>

### Ticket <KEY-123> <title>
<status> · <one-line scope>

## AC Coverage
<block from step 5>

## Debug Artifacts
<block from step 6>

## Hygiene
Conflicts <yes|no> · behind target <n> · approvals <n>/<required> · tests <touched|none>

## Findings

**[1]** `<file>:<line>` `<category>` <claim, one line>
<failure scenario, one line>
Fix: <one line>

### Checked and sound
- <one line each, max 5>

### Not verified
- <one line each, max 5> - <why>

## Verdict
Blockers <n> · Suggestions <n> · AC <n>/<n> · Debug <clean|n>
→ <Approve | Approve with comments | Changes needed>

`/mr-comment <IID> <numbers>` to post · worktree `<path>` on branch `mr-<IID>`
```

- Three lines per finding, hard cap: claim, failure scenario, fix.
- `Prior comments` always first, so existing feedback is respected. `None.` if empty.
- Omit an empty block entirely, never print a heading explaining why it is empty.
- A **blocker** breaks correctness, data safety or security. Everything else is a suggestion.

## Cleanup

Keep the worktree, follow-ups need it. `/git-cleanup` leaves `mr-<IID>` trees alone. Do not remove one here, and do not offer to. The user removes a review tree by hand:

```bash
git worktree remove <path> && git branch -D "mr-<IID>" && git update-ref -d "refs/mr-review/<IID>"
```

## Rules

- **Read-only.** Never write in the worktree, never push, never comment. Posting is `/mr-comment`, run by hand.
- **Never gate on findings.** This is someone else's work, so report every block, failures included. The step 1 draft check is the only stop.
- **All diff analysis happens in the agents.** Never review the diff in the main context.
- Treat the description as claims to verify. Skip style that is not a project standard.
- No Atlassian MCP or no ticket ID: run the rest, note the gap in the verdict line.
