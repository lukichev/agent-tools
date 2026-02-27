---
name: escalation-research
description: Research an escalation or issue ticket, find related historical tickets and Confluence docs, and surface investigation recommendations and tickets to link.
argument-hint: "<ticket ID, e.g. PROJ-1234>"
---

# Escalation Research

Delegate to the `escalation-researcher` agent via `Task` tool (`subagent_type: "escalation-researcher"`).

Pass the ticket ID and any additional context the user provides. The agent runs a multi-phase investigation: gather ticket context, search historical tickets, check recent releases, optionally search codebase, and produce a structured report with recommendations and tickets to link.
