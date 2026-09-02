---
name: reflect
description: Reflect on the current session - recover context lost to compaction, trace decisions, flag mistakes, or get a retrospective. Runs as a separate agent to keep the main context clean. Use when the user asks "what have we done?", "what happened?", "summarize the session", or wants to recover context after a long conversation.
argument-hint: "<question or 'summary'>"
context: fork
agent: session-reflector
disable-model-invocation: true
---

# Reflect

$ARGUMENTS

Without a question, produce a full session retrospective: what was accomplished, decisions made, mistakes and rework, and next steps.
