---
name: reflect
description: Reflect on the current session — recover context lost to compaction, trace decisions, flag mistakes, or get a retrospective. Runs as a separate agent to keep the main context clean.
argument-hint: "<question or 'summary'>"
---

# Reflect

Delegate to the `session-reflector` agent via `Task` tool (`subagent_type: "session-reflector"`).

Pass the user's input verbatim. If no specific question (just `/reflect`), request a full session retrospective: what was accomplished, decisions made, mistakes/rework, and next steps.
