---
name: jira-roast
description: Critically re-verify a Jira ticket before anyone builds it. Checks every claim in the ticket against the code, tests each AC for testability and for regressions, and audits ticket hygiene against jira-create conventions. Use when the user asks whether a ticket is real, whether it is still needed, whether the AC hold up, or wants a ticket challenged before it enters a sprint.
argument-hint: "<ticket ID>"
disable-model-invocation: true
---

# Jira Roast

Target: $ARGUMENTS

Decide whether the ticket should be built as written. Back the decision with evidence the reader can check. Confirm the ticket when it holds. A roast that always ends in "close it" carries no information.

## Workflow

### 1. Load the ticket

Fetch the ticket through the Atlassian MCP: description, comments, issue links, parent, issue type, priority, status and reporter.

Fetch every linked issue. Only the target's summary settles whether a link is right.

Read the comments. An unanswered question there is often the defect you are about to find.

### 2. List the claims before you check any of them

Write the list first, so coverage does not depend on what the code shows you.

A ticket makes claims in four places:

- The Summary states current behavior.
- Each step in Steps to Reproduce asserts an observable result.
- Dev Notes state a root cause, often with a `path:line`.
- Each AC asserts that the current behavior is wrong.

### 3. Verify each claim in the repository

Give each claim one verdict and one piece of evidence at `path:line`:

- **Confirmed** - the code says what the ticket says.
- **False** - the code contradicts the ticket.
- **Unverified** - the repository cannot settle it. Name what would: a deploy config, a log, a request against the environment, or a person.

**The code does not settle runtime behavior.** The code shows that a guard reads a header. Whether a caller can set that header depends on the edge proxy, the framework's proxy-trust setting and the deploy config. If the repository holds no deploy config, that claim is Unverified, not Confirmed.

**Read the history of the code the ticket blames.** Run `git log -- <file>` and read the commit that introduced the behavior. A ticket that calls a deliberate fix a bug is a strong finding, and the commit message usually names the reason.

### 4. Check whether the work is already done

For each AC, look for the behavior it asks for. Partial coverage is the common case. State which fields, values or steps already resolve the way the AC wants, and state the residual gap exactly.

### 5. Judge each AC

Six questions per AC:

1. **Testable?** A reader can verify it without asking the author what it means.
2. **Behavior, not task or wish?** "Add a guard" is a task. "Users should be able to export" is a wish. Both hide the finished behavior.
3. **In scope?** It follows from the Summary. An AC that introduces a new problem belongs in a new ticket.
4. **Already true?** See step 4.
5. **Safe?** Trace the change through the code. An AC that names a mechanism, such as "read X instead of Y", can be correct in theory and wrong for this deployment. An AC that breaks a working path is the most valuable finding.
6. **Sufficient?** Judge the set as a whole. If every AC passes and the Summary problem stays open, say which part stays open.

### 6. Audit hygiene

Audit against `~/.claude/skills/jira-create/SKILL.md`. Read it when you need the exact limits.

- Title format and length.
- Issue type matches the content. A hardening idea filed as a Bug is a type defect.
- Steps to Reproduce present for a Bug, and performed rather than inferred from the code.
- Dev Notes present only when the root cause is known, and the stated root cause verified.
- Priority supported by evidence: a report, a frequency, or the number of affected users.
- Every issue link relates to the target you fetched.
- One component and one owner. A second app or service in the Dev Notes is a separate ticket.

### 7. Challenge your own findings before you report

Try to refute each finding. Drop or downgrade the ones that fail. Look hardest at:

- A control you cited as coverage. Read which records it selects, how often it runs, what it skips, and whether an error path skips it. A periodic job over a subset of records is not coverage.
- A `path:line` that supports something narrower than the finding claims.
- An assumption about the deployment that you never verified.

## Report

Print the report in the terminal:

1. **Verdict** - one line from the table below. List secondary verdicts after it.
2. **Findings** - numbered, strongest first. Each gives the claim, the evidence at `path:line`, and the conclusion. Max 3 sentences.
3. **AC** - one line per AC with its verdict.
4. **Unverified** - each open claim, and what settles it.
5. **Hygiene** - the defects only.

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

Example finding:

> **2. AC 2 breaks the endpoint.** The service never calls `app.set('trust proxy', ...)`, so `request.ip` returns the ingress pod address (`src/main.ts:14`). A guard that reads the socket hop compares an internal address against the vendor allowlist and rejects every real request.

## Boundaries

- **Print the report in the terminal. Never write to Jira.** No comment, edit, transition, label, assignee or status change, on this ticket or any other. The user decides what reaches the reporter and posts it themselves.
- **Do not rewrite the ticket.** Name the defect and stop. The reporter owns the fix.
- If the ticket has no code in the current repository, run steps 1, 2, 5, 6 and 7, and say which checks you skipped.

## Style

Read `~/.claude/guides/asd-ste100.md` and write the report to those rules. One claim per finding, evidence before the conclusion, and no verdict without a `path:line`, a command or a named document.

## Related Skills

- `/atlassian-research` - context for an unfamiliar ticket. Run it first.
- `/jira-create` - the conventions step 6 audits against.
- `/mr-review` - reviews the change after somebody implements the ticket.
