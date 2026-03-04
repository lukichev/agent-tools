---
name: atlassian-research
description: Research a Jira ticket, epic, or topic across Jira and Confluence. Gathers linked tickets, parent epics, comments, and documentation into a structured summary. Use when the user wants to look up a ticket, understand an epic, or says "what's PROJ-1234 about?" or "research this ticket".
argument-hint: "<ticket ID or topic>"
context: fork
agent: atlassian-researcher
---

# Atlassian Research

Research: $ARGUMENTS

By default skip Confluence search — include it only if the user said "include Confluence", "check docs", or "full research".
