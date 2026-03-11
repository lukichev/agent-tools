---
name: escalation-research
description: Research an escalation or issue ticket, find related historical tickets and Confluence docs, and surface investigation recommendations and tickets to link. Use when the user mentions an escalation, a customer issue, or wants deep investigation of a complex ticket with historical context.
argument-hint: "<ticket ID, e.g. PROJ-1234>"
context: fork
agent: escalation-researcher
disable-model-invocation: true
---

# Escalation Research

Investigate: $ARGUMENTS
Research date: !`date +%Y-%m-%d`

Run a multi-phase investigation: gather ticket context, search historical tickets, check recent releases, optionally search codebase, and produce a structured report with recommendations and tickets to link.
