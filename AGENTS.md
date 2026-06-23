# AGENTS.md

This repository uses AI agents as replaceable coding collaborators. Do not rely on prior chat history. Repository files, Git history, issues, pull requests, and project docs are the source of truth.

## Start-of-Task Rule

Before editing files, understand the current project state.

At the start of every new task, fresh conversation, or worktree session:

1. Inspect Git state:

   * `git status`
   * `git branch --show-current`
   * `git log --oneline -10`

2. If `origin/main` is available and network/auth allows, inspect upstream state:

   * `git fetch origin`
   * compare the current branch against `origin/main`
   * summarize whether the branch is ahead, behind, or diverged

3. Read project memory files if they exist:

   * `docs/index.md`
   * `docs/architecture.md`
   * `docs/current_tasks.md`
   * `docs/testing.md`
   * `.codex/session-start.md`

4. Summarize before editing:

   * current branch
   * task goal
   * relevant files/modules
   * recent upstream changes
   * likely conflict risks
   * missing docs that should be created

Do not edit files until this summary is complete.

## Branch and Worktree Rules

Never develop directly on `main`.

Use one branch per feature or fix:

* `codex/<task-name>` for Codex work
* `oc/<task-name>` for OpenCode work
* `mitchell/<task-name>` for manual work
* `friend/<task-name>` for collaborator work

A worktree is only a local working directory. It may or may not already be on a proper feature branch. Always check the current branch before editing.

If the current branch is `main`, do not implement feature work there. Create or switch to a feature branch first.

For feature branches, if the branch is behind `origin/main`, summarize the upstream changes first. Rebase only when explicitly instructed or when the task clearly requires updating the branch.

Do not rebase shared branches that other people are actively using unless explicitly instructed.

## Project Memory

The repository is the long-term memory for the project.

Create and maintain these files as needed:

* `docs/index.md`: documentation index
* `docs/architecture.md`: stable architecture, module boundaries, data flow
* `docs/current_tasks.md`: active work, known risks, next priorities
* `docs/testing.md`: how to run, test, or manually verify the project
* `docs/glossary.md`: project-specific terminology
* `docs/specs/<feature>.md`: feature behavior, scope, non-goals, acceptance criteria
* `docs/decisions/0001-short-title.md`: important design decisions and why they were made

Only preserve information that will help future developers or agents.

Save:

* final design decisions
* stable architecture
* feature specs
* task state
* testing instructions
* known risks
* important implementation constraints
* asset generation metadata when relevant

Do not save:

* full chat logs
* temporary reasoning
* obsolete drafts unless clearly marked deprecated
* debug noise
* local absolute paths
* API keys, tokens, or secrets

## Documentation Maintenance

When starting a non-trivial feature:

1. Check whether a matching spec exists in `docs/specs/`.
2. If no spec exists, create one before implementation.
3. Include:

   * goal
   * scope
   * non-goals
   * acceptance criteria
   * relevant files/modules
   * risks

When finishing a feature:

1. Update `docs/current_tasks.md` if task state changed.
2. Update the feature spec if behavior changed.
3. Update `docs/testing.md` if verification steps changed.
4. Update `docs/architecture.md` only if architecture, module boundaries, or data flow changed.
5. Add a decision record under `docs/decisions/` only for important decisions that affect future work.

Do not update architecture or decision docs for trivial implementation details.

## Godot Project Rules

This is a Godot project unless the repository says otherwise.

Be careful with:

* `.tscn`
* `.tres`
* `project.godot`
* autoload settings
* input map changes
* generated/editor-local files

Avoid unnecessary scene rewrites. Do not re-save or reformat unrelated scenes.

Prefer modular systems:

* UI should call service/module APIs instead of directly mutating unrelated state.
* Feature logic should not depend on specific demo scene paths unless explicitly intended.
* Reusable logic should be separated from UI when practical.
* Demo scenes may wire systems together but should not become the only source of business logic.

## Secrets and Local Config

Never commit:

* API keys
* tokens
* `.env`
* `.env.local`
* private model/provider config
* local absolute paths
* generated Codex session files

If a config example is needed, create `.env.example` with placeholder values only.

## Implementation Style

Keep changes focused.

Do not modify unrelated files.

Do not rewrite working systems unless the task requires it.

Prefer small, understandable modules over large clever abstractions.

When uncertain, inspect existing project patterns before creating new ones.

## End-of-Task Report

Before finishing, provide:

1. Summary of changed files
2. Behavior changes
3. Testing performed, or why testing was not performed
4. Docs updated
5. Known risks or follow-up tasks
6. Whether the branch should be pushed and opened as a PR

Do not claim something was tested unless it was actually tested.
