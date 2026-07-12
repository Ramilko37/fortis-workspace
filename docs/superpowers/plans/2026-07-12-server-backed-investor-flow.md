# Server-backed Investor Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the investor journey persist a GIS project on the backend, explain its financial outcome, compare two saved variants and print a backend-backed report.

**Architecture:** Keep `useDefenseProjectStore` as the editing model and extend `useDefenseVariantsStore` with the persisted snapshot, recovery draft and explicit sync lifecycle. Use the existing same-origin project routes for save/load and existing `/api/v1` rewrites for cost, comparison and report; add a client report page only, not a PDF service or backend endpoint.

**Tech Stack:** Next.js 16.2.5 App Router, React 19, TypeScript, Zustand 5, Ant Design 6, Playwright 1.60, `tsx` contract tests, Go backend API.

## Global Constraints

- Start from frontend `origin/develop` commit `c75bba1`; do not inspect, merge or modify the remediation worktree.
- `DefenseProject` remains the one local source of truth; a saved backend response owns its `projectId`, `version` and canonical snapshot.
- Server status is exactly `clean | dirty | saving | conflict | error`; browser storage is recovery only.
- Save sends the full serialized project plus current version; a 409 never overwrites a server project.
- Backend project cost/report errors are visible and retryable; a backend project never silently uses local financial values.
- Comparison uses two distinct saved project IDs and renders every top-level and per-echelon backend delta.
- Report is an HTML page and uses `window.print()` for print/save-PDF.
- No new dependencies, staging changes, production data or secrets.
- Preserve Russian product copy and desktop support at `1280×720` and `1440×960`.
- Before the new `/report` route, re-read `frontend/node_modules/next/dist/docs/01-app/01-getting-started/02-project-structure.md` and `05-server-and-client-components.md` in the execution worktree.

---

## File Map

- `frontend/src/modules/drone-defense/domain/project-sync.ts` — pure sync-status and recovery envelope functions.
- `frontend/src/modules/drone-defense/domain/project-sync.test.ts` — `tsx` tests for canonical snapshots and recovery data.
- `frontend/src/modules/drone-defense/domain/use-defense-variants-store.ts` — server save/load, conflict and retry state.
- `frontend/src/modules/drone-defense/domain/use-defense-variants-store.test.ts` — store-level version, 409 and recovery contracts.
- `frontend/src/modules/drone-defense/infra/api-client.ts` — separate create/update payloads and versioned update serialization.
- `frontend/src/modules/drone-defense/ui/variant-selector.tsx` — explicit state labels and save/conflict actions.
- `frontend/src/modules/drone-defense/ui/variants-modal.tsx` — accessible load-server/save-as-new conflict dialog actions.
- `frontend/src/modules/defense-calculator/infra/backend-project-api.ts` — exact report and comparison DTOs.
- `frontend/src/modules/defense-calculator/infra/backend-project-api.test.ts` — JSON mapping and URL contracts.
- `frontend/src/modules/defense-calculator/ui/calculator-page.tsx` — backend financial state, source label and retry.
- `frontend/src/modules/workspace/ui/project-workspace-page.tsx` — full decision-ready A/B comparison card.
- `frontend/src/modules/defense-calculator/ui/backend-project-report.tsx` — printable server-report presentation.
- `frontend/src/modules/defense-calculator/ui/backend-project-report.test.tsx` — report rendering unit contract.
- `frontend/src/app/(defense-studio)/report/page.tsx` — `/report` route entry point.
- `frontend/test/playwright/investor-flow.spec.ts` — rendered desktop flow regression.
- `knowledge-base/03_Architecture/ADR-0012-explicit-server-save-and-recovery.md` — accepted cross-repository contract after verification.

---

### Task 1: Establish Canonical Sync and Recovery Primitives

**Files:**
- Create: `frontend/src/modules/drone-defense/domain/project-sync.ts`
- Create: `frontend/src/modules/drone-defense/domain/project-sync.test.ts`
- Modify: `frontend/src/modules/drone-defense/infra/api-client.ts`
- Test: `frontend/src/modules/drone-defense/domain/use-defense-variants-store.test.ts`

**Interfaces:**
- Produces `ProjectSyncStatus`, `ProjectRecoveryDraft`, `serializeProjectForSync`, `readRecoveryDraft`, `writeRecoveryDraft`, `clearRecoveryDraft`.
- Produces `projectCreatePayload({ name, project })` without `version` and `projectUpdatePayload({ name, project })` with `version` when present.
- Consumed by the variants store and its UI in Tasks 2–3.

- [ ] **Step 1: Write failing pure recovery tests**

```ts
import assert from "node:assert/strict";
import { clearRecoveryDraft, readRecoveryDraft, syncStatusFor, writeRecoveryDraft } from "./project-sync";

const storage = new Map<string, string>();
const project = { schemaVersion: 1, projectId: "alpha", projectName: "A", baseObject: { id: "o", name: "O", center: { lat: 55, lng: 37 } }, layers: [], assetLibrary: [], placedObjects: [], mode: "view", updatedAt: "2026-07-12T00:00:00.000Z" } as const;

assert.equal(syncStatusFor(JSON.stringify(project), JSON.stringify(project)), "clean");
assert.equal(syncStatusFor(JSON.stringify(project), JSON.stringify({ ...project, projectName: "B" })), "dirty");
writeRecoveryDraft(storage, project, "dirty");
assert.equal(readRecoveryDraft(storage, "alpha")?.project.projectName, "A");
clearRecoveryDraft(storage, "alpha");
assert.equal(readRecoveryDraft(storage, "alpha"), null);
console.log("project-sync: OK");
```

- [ ] **Step 2: Run the test and observe the missing module failure**

Run: `pnpm exec tsx src/modules/drone-defense/domain/project-sync.test.ts`

Expected: fails because `./project-sync` does not exist.

- [ ] **Step 3: Implement the smallest canonical recovery API**

```ts
export type ProjectSyncStatus = "clean" | "dirty" | "saving" | "conflict" | "error";

export type ProjectRecoveryDraft = {
  schemaVersion: 1;
  projectId: string;
  status: Extract<ProjectSyncStatus, "dirty" | "error" | "conflict">;
  savedAt: string;
  project: DefenseProject;
};

export const recoveryKey = (projectId: string) => `fortis-project-recovery:${projectId}`;
export const serializeProjectForSync = (project: DefenseProject) => JSON.stringify(project);
export const syncStatusFor = (canonical: string | null, current: string) => canonical === current ? "clean" : "dirty";
```

`writeRecoveryDraft` stores only dirty/error/conflict projects, and `readRecoveryDraft` validates the envelope shape before returning it. Invalid JSON and a mismatched `projectId` return `null` and remove the invalid value.

- [ ] **Step 4: Split create and update payload builders**

```ts
export function projectCreatePayload({ name, project }: { name: string; project: DefenseProject }) {
  return { name, enterpriseId: project.enterpriseId ?? project.baseObject.id, projectJson: exportDefenseProjectJson(project) };
}

export function projectUpdatePayload({ name, project }: { name: string; project: DefenseProject }) {
  return { ...projectCreatePayload({ name, project }), ...(typeof project.version === "number" ? { version: project.version } : {}) };
}
```

`saveVariantAsNew` uses the create payload; `overwriteVariant` uses the update payload.

- [ ] **Step 5: Re-run focused tests**

Run: `pnpm exec tsx src/modules/drone-defense/domain/project-sync.test.ts`

Expected: exits 0 and prints `project-sync: OK`.

- [ ] **Step 6: Commit the isolated primitives**

```bash
git add src/modules/drone-defense/domain/project-sync.ts src/modules/drone-defense/domain/project-sync.test.ts src/modules/drone-defense/infra/api-client.ts
git commit -m "feat: add project sync recovery primitives"
```

### Task 2: Make Server Save, Load, Retry and 409 Actions Explicit

**Files:**
- Modify: `frontend/src/modules/drone-defense/domain/use-defense-variants-store.ts`
- Modify: `frontend/src/modules/drone-defense/domain/use-defense-variants-store.test.ts`
- Modify: `frontend/src/shared/lib/use-defense-project-store.ts`

**Interfaces:**
- Consumes Task 1 recovery functions and `DefenseProject` mutations.
- Produces `syncStatus`, `retrySave`, `loadServerVersion`, `saveConflictAsNewVariant`, and `recordProjectEdit`.
- `loadServerVersion()` replaces local state only after a successful server export; `saveConflictAsNewVariant(name)` creates a new project without carrying the stale version.

- [ ] **Step 1: Add failing store tests for the user-visible lifecycle**

```ts
await useDefenseVariantsStore.getState().overwriteActiveVariant();
assert.equal(useDefenseVariantsStore.getState().syncStatus, "clean");
const current = useDefenseProjectStore.getState().project;
useDefenseProjectStore.getState().replaceProject({ ...current, projectName: "Изменённый вариант", updatedAt: "2026-07-12T01:00:00.000Z" });
assert.equal(useDefenseVariantsStore.getState().syncStatus, "dirty");
await useDefenseVariantsStore.getState().overwriteActiveVariant();
assert.equal(useDefenseVariantsStore.getState().syncStatus, "conflict");
await useDefenseVariantsStore.getState().saveConflictAsNewVariant("Вариант B");
assert.equal(useDefenseVariantsStore.getState().syncStatus, "clean");
assert.equal(useDefenseProjectStore.getState().project.version, 1);
```

The fetch stub must return a 409 on update and a new `projectId`/`version: 1` on the subsequent POST. Assert that the POST body has no `version` field.

- [ ] **Step 2: Run the focused store test and observe the expected missing state failure**

Run: `pnpm exec tsx src/modules/drone-defense/domain/use-defense-variants-store.test.ts`

Expected: fails because `syncStatus` and conflict actions do not exist.

- [ ] **Step 3: Extend the store with explicit state transitions**

```ts
type VariantsState = {
  syncStatus: ProjectSyncStatus;
  canonicalSnapshot: string | null;
  retrySave: () => Promise<void>;
  loadServerVersion: () => Promise<void>;
  saveConflictAsNewVariant: (name: string) => Promise<void>;
  recordProjectEdit: () => void;
  // existing members remain
};
```

On successful `loadVariant`, `saveAsNewVariant`, `overwriteActiveVariant` and `loadServerVersion`, call one helper that replaces the project, stores `serializeProjectForSync(project)` as canonical, sets `syncStatus: "clean"`, and clears the project recovery key. On update failure, preserve the local project and write the recovery draft: 409 sets `syncStatus: "conflict"`, all other failures set `syncStatus: "error"`.

- [ ] **Step 4: Connect local project mutation persistence to dirty/recovery state**

Add an explicit `subscribe` in the variants-store module that compares the current project serialization with `canonicalSnapshot`. It must only call `recordProjectEdit` after a backend project has a canonical snapshot, and must not set `dirty` while `syncStatus === "saving"`. `recordProjectEdit` writes a recovery envelope and sets `dirty` only when the canonical snapshot differs.

- [ ] **Step 5: Verify the full lifecycle contract**

Run: `pnpm exec tsx src/modules/drone-defense/domain/use-defense-variants-store.test.ts`

Expected: every existing test plus save/retry/409/load-server/save-as-new assertions passes.

- [ ] **Step 6: Commit the sync lifecycle**

```bash
git add src/modules/drone-defense/domain/use-defense-variants-store.ts src/modules/drone-defense/domain/use-defense-variants-store.test.ts src/shared/lib/use-defense-project-store.ts
git commit -m "feat: add explicit server project sync lifecycle"
```

### Task 3: Expose Server Sync State and Safe Conflict Decisions in the GIS UI

**Files:**
- Modify: `frontend/src/modules/drone-defense/ui/variant-selector.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/variants-modal.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/defense-studio-shell.tsx`
- Create: `frontend/test/playwright/investor-flow.spec.ts`

**Interfaces:**
- Consumes `syncStatus`, `retrySave`, `loadServerVersion`, `saveConflictAsNewVariant` from Task 2.
- Produces `role="status"` text for all sync states and actionable conflict UI.

- [ ] **Step 1: Write a failing rendered sync-state test**

```ts
test("server-backed editor shows dirty, save and conflict actions", async ({ page }) => {
  await page.goto("/prototype");
  await expect(page.getByRole("status")).toContainText("Есть изменения");
  await page.getByRole("button", { name: "Сохранить текущий вариант" }).click();
  await expect(page.getByRole("status")).toContainText("Сохранено");
  await page.route("**/api/defense/projects/*", (route) => route.fulfill({ status: 409, body: JSON.stringify({ error: { code: "version_conflict", message: "stale" } }) }));
  await page.getByRole("button", { name: "Сохранить текущий вариант" }).click();
  await expect(page.getByRole("status")).toContainText("Конфликт версии");
  await expect(page.getByRole("button", { name: "Загрузить серверную версию" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Сохранить как новый вариант" })).toBeVisible();
});
```

- [ ] **Step 2: Run the browser test and observe the missing status/action failure**

Run: `PLAYWRIGHT_BASE_URL=http://127.0.0.1:3000 pnpm exec playwright test test/playwright/investor-flow.spec.ts --grep "sync"`

Expected: fails because the five sync labels and conflict actions are absent.

- [ ] **Step 3: Replace the draft/success dot with an accessible state label**

```tsx
const syncCopy: Record<ProjectSyncStatus, string> = {
  clean: "Сохранено",
  dirty: "Есть изменения",
  saving: "Сохранение",
  conflict: "Конфликт версии",
  error: "Ошибка",
};

<span role="status" aria-live="polite">{syncCopy[syncStatus]}</span>
```

`VariantSaveButton` is disabled only for `saving` and calls `retrySave` when status is `error`; it keeps the existing new-variant dialog for an unsaved draft. The desktop shell replaces the hard-coded `Завод Альфа · Вариант A` text with current project and active variant names.

- [ ] **Step 4: Add a conflict panel in `VariantsModal`**

The panel renders only for `syncStatus === "conflict"`, retains the local project, and uses the exact accessible labels `Загрузить серверную версию` and `Сохранить как новый вариант`. The latter reuses the existing variant-name input and calls `saveConflictAsNewVariant` only with a non-empty trimmed name.

- [ ] **Step 5: Re-run the rendered sync test**

Run: `PLAYWRIGHT_BASE_URL=http://127.0.0.1:3000 pnpm exec playwright test test/playwright/investor-flow.spec.ts --grep "sync"`

Expected: passes with no browser console error.

- [ ] **Step 6: Commit the editor actions**

```bash
git add src/modules/drone-defense/ui/variant-selector.tsx src/modules/drone-defense/ui/variants-modal.tsx src/modules/drone-defense/ui/defense-studio-shell.tsx test/playwright/investor-flow.spec.ts
git commit -m "feat: expose explicit GIS server save states"
```

### Task 4: Type and Render Backend Financial and Comparison Results

**Files:**
- Modify: `frontend/src/modules/defense-calculator/infra/backend-project-api.ts`
- Create: `frontend/src/modules/defense-calculator/infra/backend-project-api.test.ts`
- Modify: `frontend/src/modules/defense-calculator/ui/calculator-page.tsx`
- Modify: `frontend/src/modules/workspace/ui/project-workspace-page.tsx`

**Interfaces:**
- Replaces all `unknown` fields in `BackendProjectReport` and `BackendProjectCompare` with backend DTO shapes.
- Produces `BackendConfigSnapshot`, `BackendStructuralProfile`, `BackendEchelonDiff` and `BackendReportObjectLine`.
- Calculator renders `backendStatus: loading | ready | error` and a retry button; workspace comparison renders snapshot cards and `diff.byEchelon` rows.

- [ ] **Step 1: Write failing DTO mapping and comparison tests**

```ts
const comparison: BackendProjectCompare = {
  projectA: { projectId: "a", projectName: "A", structuralProfile: { objectCount: 2, unitCount: 3, echelonCount: 2, categoryCount: 2, conflictCount: 1, coveredObjCount: 2, totalMln: 100, byEchelon: [] }, costCalculation: { totalMln: 100, byEchelon: [], byType: [], byObject: [] } },
  projectB: { projectId: "b", projectName: "B", structuralProfile: { objectCount: 3, unitCount: 4, echelonCount: 3, categoryCount: 2, conflictCount: 0, coveredObjCount: 3, totalMln: 120, byEchelon: [] }, costCalculation: { totalMln: 120, byEchelon: [], byType: [], byObject: [] } },
  diff: { objectCountDelta: 1, unitCountDelta: 1, echelonCountDelta: 1, categoryCountDelta: 0, conflictCountDelta: -1, coveredObjCountDelta: 1, costDeltaMln: 20, byEchelon: [] },
};
assert.equal(comparison.projectB.structuralProfile.coveredObjCount, 3);
console.log("backend project DTOs: OK");
```

- [ ] **Step 2: Run the DTO test and observe the current `unknown` incompatibility**

Run: `pnpm exec tsx src/modules/defense-calculator/infra/backend-project-api.test.ts`

Expected: fails because the current type cannot access `structuralProfile.coveredObjCount`.

- [ ] **Step 3: Define the frontend mirrors of the Go DTOs**

Implement exact named fields from `backend/internal/modules/budget/ui/dto.go` and `backend/internal/modules/report/ui/dto.go`. Do not widen response fields to `unknown`; use optional nested MOG summaries only where backend marks them `omitempty`.

- [ ] **Step 4: Remove silent calculator fallback for a backend project**

When `project.source === "backend"`, render server total and report only after both requests succeed. On failure render:

```tsx
<div role="alert">
  Не удалось получить серверный расчёт. Локальные цифры не показаны.
  <button type="button" onClick={() => void loadBackendFinancials()}>Повторить</button>
</div>
```

For a project that is not backend-backed, retain the existing local calculator with the explicit label `Локальный черновик: сохраните проект, чтобы получить серверный расчёт.`

- [ ] **Step 5: Render full A/B evidence**

Reject identical IDs before the API request with `Выберите два разных варианта.`. Render both snapshot cards (`стоимость`, `объекты`, `единицы`, `конфликты`, `покрытые объекты`, `эшелоны`) and a table for each `diff.byEchelon` member. Each delta displays `+` for positive values and a typographic minus for negative values.

- [ ] **Step 6: Run focused tests**

Run:

```bash
pnpm exec tsx src/modules/defense-calculator/infra/backend-project-api.test.ts
pnpm exec tsx src/modules/drone-defense/infra/backend-integration-contract.test.ts
```

Expected: both commands exit 0.

- [ ] **Step 7: Commit financial and A/B rendering**

```bash
git add src/modules/defense-calculator/infra/backend-project-api.ts src/modules/defense-calculator/infra/backend-project-api.test.ts src/modules/defense-calculator/ui/calculator-page.tsx src/modules/workspace/ui/project-workspace-page.tsx
git commit -m "feat: render typed backend financial comparison"
```

### Task 5: Add the Printable Server-backed Report Route

**Files:**
- Create: `frontend/src/modules/defense-calculator/ui/backend-project-report.tsx`
- Create: `frontend/src/modules/defense-calculator/ui/backend-project-report.test.tsx`
- Create: `frontend/src/app/(defense-studio)/report/page.tsx`
- Modify: `frontend/src/modules/defense-calculator/ui/calculator-page.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/defense-studio-shell.tsx`
- Modify: `frontend/test/playwright/investor-flow.spec.ts`

**Interfaces:**
- Consumes typed `BackendProjectReport` from Task 4.
- `BackendProjectReportPage` fetches only a saved backend project ID and calls `window.print()`.
- `/report?id=<projectId>` is a client route to allow browser printing and authenticated same-origin requests.

- [ ] **Step 1: Re-read the local Next.js route/component guidance**

Run:

```bash
sed -n '1,220p' node_modules/next/dist/docs/01-app/01-getting-started/02-project-structure.md
sed -n '1,260p' node_modules/next/dist/docs/01-app/01-getting-started/05-server-and-client-components.md
```

Expected: confirms that an App Router `page.tsx` owns the route and browser APIs require a client component.

- [ ] **Step 2: Write a failing report component test**

```tsx
import assert from "node:assert/strict";
import { renderToStaticMarkup } from "react-dom/server";
import { BackendProjectReportView } from "./backend-project-report";

const html = renderToStaticMarkup(<BackendProjectReportView report={reportFixture} onPrint={() => undefined} />);
assert.match(html, /Отчёт по проекту Вариант B/);
assert.match(html, /МОГ — пост №2/);
assert.match(html, /Печать \/ сохранить PDF/);
```

- [ ] **Step 3: Run the report test and observe the missing component failure**

Run: `pnpm exec tsx src/modules/defense-calculator/ui/backend-project-report.test.tsx`

Expected: fails because `BackendProjectReportView` is missing.

- [ ] **Step 4: Implement the report view and client route**

```tsx
"use client";

export default function Page() {
  return <BackendProjectReportPage />;
}
```

`BackendProjectReportPage` obtains `id` through `useSearchParams`, fetches `getBackendProjectReport(id)`, renders loading/error/retry states and does not derive cost from the local store. `BackendProjectReportView` renders project/base-object identity, server estimate, structural profile, layer summary and placed-object/MOG rows. Its only export action is:

```tsx
<button type="button" onClick={onPrint}>Печать / сохранить PDF</button>
```

The calculator and shell link to `/report?id=${encodeURIComponent(project.projectId)}` only for a backend project; an unsaved draft shows a disabled explanatory action instead.

- [ ] **Step 5: Add a rendered print-route test**

```ts
test("saved project opens a printable backend report", async ({ page }) => {
  await page.goto("/report?id=variant-b");
  await expect(page.getByRole("heading", { name: /Отчёт по проекту/ })).toBeVisible();
  await expect(page.getByRole("button", { name: "Печать / сохранить PDF" })).toBeVisible();
});
```

- [ ] **Step 6: Run report tests**

Run:

```bash
pnpm exec tsx src/modules/defense-calculator/ui/backend-project-report.test.tsx
PLAYWRIGHT_BASE_URL=http://127.0.0.1:3000 pnpm exec playwright test test/playwright/investor-flow.spec.ts --grep "printable"
```

Expected: both pass.

- [ ] **Step 7: Commit the printable report**

```bash
git add src/modules/defense-calculator/ui/backend-project-report.tsx src/modules/defense-calculator/ui/backend-project-report.test.tsx src/app/'(defense-studio)'/report/page.tsx src/modules/defense-calculator/ui/calculator-page.tsx src/modules/drone-defense/ui/defense-studio-shell.tsx test/playwright/investor-flow.spec.ts
git commit -m "feat: add printable backend project report"
```

### Task 6: Verify the Complete Flow and Record the Decision

**Files:**
- Create: `knowledge-base/03_Architecture/ADR-0012-explicit-server-save-and-recovery.md`
- Modify: `knowledge-base/00_Index.md`
- Modify: `knowledge-base/Продуктовый_план_Fortis.md`

**Interfaces:**
- Documents the exact save/recovery/409 contract implemented in Tasks 1–5.
- Does not state staging readiness or deployment configuration.

- [ ] **Step 1: Add a rendered end-to-end test with server fixtures**

The test must intercept projects, cost, report and compare responses and execute this route sequence: open saved variant → make one GIS edit → explicit save → reload → calculator confirms server source → workspace compares A/B → report opens. Run it at `1280×720` and `1440×960`.

- [ ] **Step 2: Run focused red/green evidence**

Run:

```bash
pnpm exec tsx src/modules/drone-defense/domain/project-sync.test.ts
pnpm exec tsx src/modules/drone-defense/domain/use-defense-variants-store.test.ts
pnpm exec tsx src/modules/defense-calculator/infra/backend-project-api.test.ts
PLAYWRIGHT_BASE_URL=http://127.0.0.1:3000 pnpm exec playwright test test/playwright/investor-flow.spec.ts
```

Expected: all exit 0.

- [ ] **Step 3: Write and commit the ADR in knowledge-base**

Record that backend saves use full `projectJson` plus version, localStorage is recovery only, server financial results are authoritative for saved projects, and 409 offers reload or save-as-new without overwrite. Add it to the index and update the product roadmap’s actual status.

```bash
git -C ../knowledge-base add 03_Architecture/ADR-0012-explicit-server-save-and-recovery.md 00_Index.md Продуктовый_план_Fortis.md
git -C ../knowledge-base commit -m "docs: record explicit project sync contract"
```

- [ ] **Step 4: Run the frontend gate**

Run:

```bash
pnpm exec playwright test test/playwright/prototype.spec.ts test/playwright/investor-flow.spec.ts
pnpm exec eslint src/modules/drone-defense src/modules/defense-calculator src/app/'(defense-studio)'/report test/playwright/investor-flow.spec.ts
pnpm build
git status --short
```

Expected: no test failures, lint errors, build failures or unexpected modified files. Inspect the browser console on both desktop viewports during the end-to-end flow.

- [ ] **Step 5: Commit verification-only frontend changes and parent pointers**

```bash
git add test/playwright/investor-flow.spec.ts
git commit -m "test: cover server-backed investor flow"
cd ..
git add frontend knowledge-base
git commit -m "chore: update investor flow submodules"
```

## Plan Self-review

- Scope coverage: explicit save/reload/retry/409, recovery-only local storage, server calculator, typed comparison, A/B deltas and printable report are mapped to Tasks 1–5; tests and durable documentation are Task 6.
- No backend change is planned because current routes expose every required operation; a contract-test failure is the trigger for a separately reviewed backend task.
- No staging, remediation integration, mobile work or PDF service is included.
