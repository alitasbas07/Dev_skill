# Logging schema

Store logs outside repositories at `%USERPROFILE%\.agent-orchestrator\runs\<run-id>\events.jsonl` with a `summary.json`.

Events contain timestamp, run/task IDs, event, state, actor, model, effort, difficulty, risk, retry, error class/fingerprint, evidence references and a small data object. Record plan checks, scoring, routing, worktree and worker lifecycle, implementation, tests, reviews, corrections, user decisions, commit authorization and completion. There is no merge event.

Never log secrets, environment values, card data, personal data, full source or full prompts. Store long evidence separately. Risk 7+ cannot complete without a summary.

