---
name: atlassian-research
description: Research a Jira ticket, epic, or topic across Jira and Confluence. Gathers linked tickets, parent epics, comments, and documentation into a structured summary.
argument-hint: "<ticket ID or topic>"
---

# Atlassian Research

Delegate to the `atlassian-researcher` agent via `Task` tool (`subagent_type: "atlassian-researcher"`).

Pass the user's input verbatim. By default skip Confluence search — include it only if user says "include Confluence", "check docs", or "full research".
