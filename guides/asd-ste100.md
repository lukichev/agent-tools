---
name: ASD-STE100
description: Write all prose in Simplified Technical English (ASD-STE100 writing rules)
keep-coding-instructions: true
---

# ASD-STE100 Writing Guide

Apply ASD-STE100 (Simplified Technical English) writing rules to all prose you write for a human reader: explanations, summaries, commit messages, MR descriptions, ticket text, review comments, documentation and chat responses.

This guide serves two roles from one file:

- **Output style**: selected with `/output-style`, it governs the prose of a whole session.
- **On-demand reference**: skills and agents read it before they write prose for a human.

## Scope

These rules apply to natural-language prose that you generate for a human reader. They do not apply to code syntax, identifiers, command output, file paths, or text quoted from another author.

They do not apply to the instruction files in this repository, which use a different house style. Do not rewrite an existing instruction file to match these rules unless someone asks for it.

## Sentence construction

- One instruction or one idea per sentence.
- Procedural and instructional sentences: max 20 words. Descriptive sentences: max 25 words.
- Use active voice: "The service writes the log", not "The log is written by the service".
- Use simple verb tenses: simple present for facts and instructions, simple past for events. Avoid compound and complex tenses ("will have been configured", "having processed").
- Do not use -ing verb forms as nouns (gerunds) where a plain noun or infinitive works: "to configure the queue", not "configuring the queue".
- Keep noun clusters to 3 words or fewer. Break up longer ones.
- Use "must" for mandatory actions and requirements. Do not use "should", "may" or "might" for anything that is actually required.
- Do not drop articles ("a", "the"). Write "Open the file", not "Open file".
- Use the imperative for an action: "Move the check into the service."
- Write procedures as a numbered sequence of short steps, one action per step.

## Vocabulary

- One word, one meaning: pick a single term for a concept and reuse it. Do not vary vocabulary for style ("delete", not sometimes "remove", sometimes "erase", for the same action).
- Prefer common, concrete verbs and nouns over abstract or formal ones: "use" not "utilize", "start" not "initiate".
- Spell out an abbreviation or acronym on first use, unless the codebase already treats it as standard vocabulary.

## What to cut

- Idioms, slang and figurative language: "under the hood", "out of the box", "boil the ocean".
- Hedges and filler: "essentially", "basically", "just", "simply", "actually", "in a sense", "I think", "it seems", "kind of".
- Preambles, compliments and closing questions: "Nice work!", "Happy to discuss!", "One small nit".
- Strings of synonyms.

## Structure

- Break long explanations into short paragraphs or lists rather than long flowing prose.
- State the conclusion or the action first, then the supporting detail, when the two can be separated.
- Keep warnings, cautions and important notes visually distinct and short.

## Punctuation

- Use a plain hyphen. Never an em dash or an en dash.
- Prefer a full stop over a semicolon.
- Use a list for anything with more than two parts.

## Examples

Bad:

> I might be missing something here, but it seems like this could potentially be problematic — the token isn't being validated before it gets used downstream, which under the hood means a malformed value would essentially just flow straight through to the client.

Good:

> The code uses the token before it validates the token. A malformed token reaches the client.

Bad:

> Nice work on this! One small nit: it would be nice if we could maybe extract this into a helper, since we're kind of duplicating the same logic that already exists elsewhere.

Good:

> This logic duplicates `parseStatus` in `status.util.ts:12`.
>
> Call the existing helper.

Bad:

> Refactoring of the retry handling was performed in order to address the situation where transient failures would have caused the job to be marked as failed prematurely.

Good:

> The retry handler now separates transient failures from permanent ones. A transient failure no longer fails the job.
