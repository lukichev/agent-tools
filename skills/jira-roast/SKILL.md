---
name: jira-roast
description: Critically re-verify a Jira ticket before anyone builds it. Checks every claim in the ticket against the code, tests each AC for testability and for regressions, and audits ticket hygiene against jira-create conventions. Use when the user asks whether a ticket is real, whether it is still needed, whether the AC hold up, or wants a ticket challenged before it enters a sprint.
argument-hint: "<ticket ID>"
disable-model-invocation: true
---

# Jira Roast

Target: $ARGUMENTS

Decide whether the ticket should be built as written. Back the decision with evidence that the reader can check.

A roast that always ends in "close it" carries no information, because the reader knows the verdict before reading it. Confirm the ticket when it holds. The value is the evidence, not the negativity.

## Workflow

### 1. Load the ticket

Fetch the ticket through the Atlassian MCP. Request the description, comments, issue links, parent, issue type, priority, status and reporter.

Fetch every linked issue as well. A wrong link is a common defect, and only the target's summary settles it.

Read the comments. An unanswered question in a comment is often the same defect you are about to find.

### 2. List the claims before you check any of them

Write the list first. Coverage must not depend on what the code happens to show you.

A ticket makes claims in four places:

- The Summary states current behavior.
- Each step in Steps to Reproduce asserts an observable result.
- Dev Notes state a root cause, often with a `path:line`.
- Each AC asserts that the current behavior is wrong. That assertion is a claim.

### 3. Verify each claim in the repository

Give each claim one verdict and one piece of evidence at `path:line`:

- **Confirmed** - the code says what the ticket says.
- **False** - the code contradicts the ticket.
- **Unverified** - the repository cannot settle it. Name what would settle it: a deploy config, a log, a request against the environment, or a person.

Two failure modes cause most wrong roasts:

**Code truth is not runtime truth.** A guard that reads a header is code truth. Whether a caller can set that header depends on the edge proxy, the framework's proxy-trust setting and the deploy config. A ticket that read the code and reported an exploit reproduced nothing. If the repository holds no deploy config, that claim is Unverified, not Confirmed.

**Read the history of the code that the ticket blames.** Run `git log -- <file>` and read the commit that introduced the behavior. A ticket that calls a deliberate fix a bug is a strong finding, and the commit message usually names the reason for the behavior.

### 4. Check whether the work is already done

For each AC, look for the behavior that it asks for. Partial coverage is the common case, and it shrinks the ticket.

Trace which fields, values or steps already resolve the way the AC wants, and which do not. State the residual gap exactly.

### 5. Judge each AC

Ask six questions per AC:

1. **Testable?** A reader must be able to verify it without asking the author what it means.
2. **Behavior, not task or wish?** "Add a guard" is a task. "Users should be able to export" is a wish. Both hide the finished behavior.
3. **In scope?** It must follow from the Summary. An AC that introduces a new problem belongs in a new ticket.
4. **Already true?** See step 4.
5. **Safe?** Trace the change through the code. An AC that names a mechanism, such as "read X instead of Y", can be correct in theory and wrong for this deployment. An AC that breaks a working path is the most valuable finding in the pass.
6. **Sufficient?** Judge the set as a whole. If every AC passes and the Summary problem stays open, say which part stays open.

### 6. Audit hygiene

Audit against the conventions in `~/.claude/skills/jira-create/SKILL.md`. Read that file when you need the exact limits.

- Title format and length.
- Issue type matches the content. A hardening idea filed as a Bug is a type defect.
- Steps to Reproduce present for a Bug, and performed rather than inferred from the code.
- Dev Notes present only when the root cause is known, and the stated root cause verified.
- Priority supported by evidence: a report, a frequency, or a blast radius.
- Every issue link relates to the target that you fetched.
- One component and one owner. A second app or service bundled into the Dev Notes is a separate ticket.

### 7. Challenge your own findings before you report

Try to refute each finding. Drop or downgrade the findings that fail.

Look hardest at these three:

- A control that you cited as coverage. Read what it actually covers: which records it selects, how often it runs, what it skips, and whether an error path skips it. A periodic job that covers a subset of records is not coverage.
- A `path:line` that supports something narrower than the finding claims.
- An assumption about the deployment that you never verified.

A finding that survives this pass is worth the reporter's time. A finding that does not costs your credibility on the findings that do.

## Report

Print the report in the terminal. Use this structure:

1. **Verdict** - one line from the table below. List any secondary verdicts after it.
2. **Findings** - numbered, strongest first. Each finding gives the claim, the evidence at `path:line`, and the conclusion. Max 3 sentences.
3. **AC** - one line per AC with its verdict.
4. **Unverified** - each open claim, and what settles it.
5. **Hygiene** - the defects only. Skip the checks that pass.

| Verdict | Meaning |
|---------|---------|
| Valid | The defect is real and the AC hold. Build it. |
| Valid, AC wrong | The defect is real. At least one AC is untestable, out of scope or harmful. |
| Already done | The code already does what the AC describe. |
| Premise unverified | Nobody reproduced the central claim, and the repository cannot settle it. |
| Premise false | The code contradicts the ticket. |
| Wrong type | The observation is real, but the issue type or the priority is wrong. |
| Harmful | The AC as written cause a regression. |

Pick the verdict that decides what happens to the ticket. List the rest as secondary.

**Example finding:**

> **2. AC 2 breaks the endpoint.** The service never calls `app.set('trust proxy', ...)`, so `request.ip` returns the ingress pod address (`src/main.ts:14`). A guard that reads the socket hop compares an internal address against the vendor allowlist and rejects every real request.

## Boundaries

- **Print the report in the terminal. Never write to Jira.** No comment, no edit, no transition, no label, no assignee, no status change, on this ticket or on any other. The report is a conversation with the user, not a public verdict on somebody's ticket. The user decides what reaches the reporter, and posts it themselves.
- **Do not rewrite the ticket.** Name the defect and stop. The reporter owns the fix, and a rewrite buries the disagreement that you just surfaced.
- If the ticket has no code in the current repository, run steps 1, 2, 5, 6 and 7, and say which checks you skipped.

## Style

Read `~/.claude/guides/asd-ste100.md` and write the report to those rules.

Extra limits for this report: one claim per finding, evidence before the conclusion, and no verdict without a `path:line`, a command or a named document.

## Related Skills

- `/atlassian-research` gathers the context of an unfamiliar ticket. Run it first.
- `/jira-create` holds the conventions that step 6 audits against.
- `/mr-review` reviews the change after somebody implements the ticket.
