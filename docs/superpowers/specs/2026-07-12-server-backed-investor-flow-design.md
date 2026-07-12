# Server-backed Investor Flow Design

**Status:** approved direction — implement without staging

## Goal

Deliver the desktop investor path `Workspace → Project → GIS editor → explicit Save → Calculator → A/B comparison → printable report` against the existing backend. A saved backend project is the authoritative source; browser storage is recovery only.

## Scope and constraints

- Work from frontend `origin/develop` (`c75bba1`); do not integrate or modify the remediation worktree.
- Use the existing project, cost, report, compare and same-origin proxy endpoints. Do not add a staging deployment or a PDF service.
- Keep `DefenseProject` as the in-memory editing model. No credentials or project data are committed to Git.
- Use Russian product copy, desktop acceptance at `1280×720` and `1440×960`, existing React, Next.js, Zustand and Ant Design only.

## Existing contract

The backend provides `POST /api/v1/projects`, `GET /api/v1/projects/get`, `PUT /api/v1/projects/update`, cost, report and compare endpoints. Updates accept a full `projectJson` plus optional optimistic-lock `version`; a stale version returns `409`. The frontend already has workspace, variant API helpers and a calculator integration, but it lacks a distinct dirty/recovery lifecycle, complete conflict actions, typed report/compare DTOs, a decision-ready comparison view and a standalone printable report.

## Selected approach

Extend `useDefenseVariantsStore` rather than add a second project-sync authority. The store stays responsible for server identity and save/load operations, while `useDefenseProjectStore` remains responsible for local edits. A small pure sync/recovery helper owns serialization, dirty comparison and browser-storage envelopes.

This is preferable to a new monolithic store because it preserves the existing workspace and proxy boundaries; it is preferable to auto-save because the investor flow requires an unambiguous server-save moment and safe version-conflict handling.

## Sync lifecycle

`ProjectSyncStatus` is exactly `clean | dirty | saving | conflict | error`.

1. Loading or successfully saving a backend project records its canonical serialized snapshot and clears its matching recovery draft.
2. Any later `DefenseProject` mutation is immediately visible locally, recomputes the status as `dirty`, and writes a recovery envelope to localStorage keyed by project ID. The envelope is never presented as a saved server version.
3. **Save** sends the complete `projectJson` and current `version`. A successful response replaces the project identity/version, records the canonical snapshot and changes status to `clean`.
4. A transport or non-409 failure retains the draft and changes status to `error`; the UI offers **Retry**.
5. A `409` retains the draft and changes status to `conflict`. The UI offers exactly two non-destructive actions: **Load server version** (replace local project and discard this recovery draft) and **Save current work as new variant** (create a separate project from the local project with no inherited version).

The app bar exposes all five user-facing states: `Сохранено`, `Есть изменения`, `Сохранение`, `Конфликт версии`, `Ошибка`. It does not describe recovery storage as server persistence.

## Financial data, A/B and report

`backend-project-api.ts` gains exact TypeScript DTOs mirroring backend `CostCalculationDTO`, `StructuralProfileDTO`, `ConfigSnapshotDTO`, `ConfigDiffDTO`, report layers and report object lines. `unknown` is removed from report and comparison contracts.

For a backend project, `/calculator` fetches cost and report after the saved project/version changes and labels their origin. A response failure is rendered as an error with a retry action; it does not silently substitute local calculation figures. Unsaved/local projects remain explicitly labelled as local drafts.

`/workspace` comparison requires two different saved variants. It renders both snapshots, all top-level deltas (cost, objects, units, conflicts, covered objects and echelons), and the per-echelon delta rows. The comparison is unavailable while either side is missing.

`/report` is a browser-rendered HTML route for one saved project. It renders report metadata, cost, structural profile, layers and placed-object/MOG rows from the server report endpoint. `Печать / сохранить PDF` calls `window.print()`; no file-generation service is added.

## Tests and verification

- Pure tests: sync state derivation, draft serialization/recovery, update payload version, 409 actions and typed DTO mapping.
- Contract tests: same-origin requests for project update, cost, compare and report use the exact backend request/response fields.
- Rendered Playwright: explicit save/reload, retry after a failed request, 409 conflict actions, calculator source/error state, A/B card and printable report at both desktop viewports.
- Final gates: focused tests, full `/prototype` Playwright suite, ESLint, production build, browser-console check and `go test -race ./...` if backend code changes prove necessary.

## Repository ownership

- `frontend/`: client state, proxy contracts, workspace, calculator, comparison and report UI/tests.
- `backend/`: only a separately committed change if current API contract testing demonstrates a blocking incompatibility.
- `knowledge-base/`: ADR/status update for the explicit server-save and recovery contract once implementation is verified.
- Parent: this design, later demo fixtures/runbook, and submodule pointer only after child commits.
