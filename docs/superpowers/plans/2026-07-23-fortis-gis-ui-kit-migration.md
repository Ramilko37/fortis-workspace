# Fortis GIS UI Kit Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the migration of the 2D `/prototype` GIS workspace from legacy Ant Design, Ant Icons and route-local generic controls to the Fortis UI Kit demonstrated in Storybook.

**Architecture:** Keep `DefenseProject`, Zustand stores, MapLibre/deck.gl and existing GIS behavior unchanged. Extend only reusable Fortis primitives first, then migrate the product shell and responsive workspace, the map surfaces, and finally nested editors and dialogs. Shared appearance belongs to `src/shared/ui/fortis`; GIS modules retain domain composition and map positioning.

**Tech Stack:** Next.js 16, React 19, TypeScript, Zustand, MapLibre, deck.gl, Fortis UI Kit, Storybook 10, Node test runner, Playwright.

## Global Constraints

- Work in `frontend/` for runtime changes; update `knowledge-base/` only after frontend behavior is verified.
- Preserve `DefenseProject.layers`, `DefenseProject.placedObjects` and `DefenseProject.assetLibrary` as the only project sources of truth.
- Preserve `/prototype?view=scenario-modeling`, `/calculator`, backend contracts and all persistence semantics.
- Do not add dependencies or remove Ant packages while other routes still use them.
- Use the documented responsive boundaries: 768px, 1024px and 1280px.
- Use test-first RED → GREEN cycles for every component/API or behavior change.
- Do not touch `.playwright-cli/` or `debug-storybook.log`.

---

### Task 1: Fortis GIS component contracts

**Files:**
- Modify: `frontend/src/shared/ui/fortis/icon.tsx`
- Modify: `frontend/src/shared/ui/fortis/core.tsx`
- Modify: `frontend/src/shared/ui/fortis/data-navigation-domain.tsx`
- Modify: `frontend/src/shared/ui/fortis/overlays.tsx`
- Test: `frontend/src/shared/ui/fortis/gis-runtime-contract.test.tsx`
- Modify: `frontend/src/shared/ui/fortis/individual-components.stories.tsx`

- [x] Write a failing contract test for semantic GIS icons and reusable runtime variants.
- [x] Run the focused test and verify the expected missing-API failure.
- [x] Add the minimal backward-compatible public APIs.
- [x] Add Storybook states for each new API and re-run the test green.

### Task 2: Responsive Defense Studio shell and workspace

**Files:**
- Modify: `frontend/src/modules/drone-defense/ui/defense-studio-shell.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/gis-workspace-panels.tsx`
- Modify: `frontend/src/app/globals.css`
- Test: `frontend/src/modules/drone-defense/ui/gis-workspace-panels.test.tsx`

- [x] Extend rendered-component contracts for UI-kit navigation, tree and inspector states.
- [x] Replace Ant icons and legacy shell controls with Fortis primitives.
- [x] Implement mobile-first drawers and progressive docking at 768/1024/1280.
- [x] Keep save/version state wired to `useDefenseVariantsStore`.

### Task 3: Map canvas, project library and layer controls

**Files:**
- Modify: `frontend/src/modules/drone-defense/ui/gis-board.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/drone-defense-prototype.tsx`
- Modify: focused 2D GIS child components under `frontend/src/modules/drone-defense/ui/`
- Test: focused domain/source contracts and `frontend/test/playwright/prototype.spec.ts`

- [x] Add failing contracts for Fortis map controls and removal of legacy generic controls.
- [x] Migrate object selector, basemap, zoom/navigation, measurement, legend, warnings and status overlays.
- [x] Migrate asset search/cards, echelon/object actions and floating panels.
- [x] Verify map pan/zoom, selection, drag/drop, coordinate placement and visibility remain unchanged.

### Task 4: Nested editors, overlays and legacy cleanup

**Files:**
- Modify: `frontend/src/modules/drone-defense/ui/variants-modal.tsx`
- Modify: GIS asset manager, geometry wizard, coordinate placement and MOG editor components
- Test: component contracts plus `frontend/test/playwright/prototype.spec.ts`

- [x] Add failing tests for Fortis forms, modal/drawer focus and safe destructive actions.
- [x] Replace remaining 2D Ant components/icons with Fortis forms and overlays.
- [x] Add a static import guard proving the 2D GIS dependency surface does not import `antd` or `@ant-design/icons`.
- [x] Preserve all save, conflict, retry, cancel, delete and undo behavior.

### Task 5: Verification and durable project memory

- [x] Run focused component/domain tests and scoped ESLint.
- [x] Run `pnpm exec tsc --noEmit`.
- [x] Run `pnpm build-storybook`.
- [x] Run Playwright at 390, 768, 1024 and 1440 widths.
- [x] Run `pnpm build` and `git diff --check`.
- [x] Add ADR-0013 and update the knowledge-base index and product plan.
- [x] Commit frontend and knowledge-base separately, then update the parent submodule pointers if requested.
