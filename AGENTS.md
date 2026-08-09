# Wakaremichi AI Working Agreement

This repository is the portable implementation context for Wakaremichi / まいにちの分かれ道.

- Do not depend on past ChatGPT or Codex conversations. Record durable implementation context in this repository.
- Every new AI session must begin with `docs/START_HERE.md`.
- Treat the following as the sources of truth:
  - Product decisions and progress: Notion
  - Implementation and runtime behavior: Git source and tests
  - Current project state: `docs/PROJECT_STATE.md`
  - Review history: `docs/REVIEW_LOG.md`
- Do not add features unless the current work unit explicitly authorizes them.
- While the project is a Release Candidate, prioritize release blockers over feature work or broad refactoring.
- Preserve existing Git history, project configuration, signing, persistence, assets, and runtime behavior unless the active work unit explicitly requires a change.
