# GIS UX Hardening Compliance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Довести desktop `/prototype` до полного соответствия утверждённой спецификации GIS UX Hardening: безопасное редактирование, устойчивый active-layer context, профессиональные map tools, релевантный каталог, понятное сохранение и доступность.

**Architecture:** Поведение, которое можно выразить чистыми функциями, выносится в небольшие domain-модули и покрывается test-first контрактами. Zustand stores остаются источниками project/variant state; `DroneDefensePrototype` оркестрирует диалоги и workspace, а `GisBoard` отвечает только за map interaction/overlay. Backend-контракты не расширяются: реальные запросы проверяются только локально, error/offline/conflict — детерминированными fetch mocks.

**Tech Stack:** Next.js 16.2.5, React 19.2.4, TypeScript 5, Zustand 5, Ant Design 6, deck.gl 9, MapLibre 5, Tailwind/CSS modules, `tsx` contract tests, Playwright 1.60.

## Global Constraints

- Source of truth: `knowledge-base/05_Design/GIS_UX_Hardening_Spec_2026-07-15.md`, status `Approved 2026-07-17`.
- Desktop acceptance viewports: `1280×720` and `1440×960`; separate mobile redesign is out of scope.
- Backend can run only locally at `http://localhost:8090`; no staging dependency may be introduced.
- Network/offline/timeout/HTTP/409 states must be testable without backend through controlled fetch responses.
- Visual visibility never changes calculator/report composition.
- Active selection and visibility are independent state axes.
- Critical interactive targets are at least `44×44px`.
- No new runtime dependency without explicit justification.
- Preserve existing local edits, especially `frontend/src/app/page.tsx`.
- Before any Next.js routing/config/server-client change, read `frontend/node_modules/next/dist/docs/`; this plan does not require such a change.

---

## File Map

### New files

- `frontend/src/modules/drone-defense/domain/catalog-search.ts` — query tokenization, match scoring, compatible-first sort and facets.
- `frontend/src/modules/drone-defense/domain/catalog-search.test.ts` — real ranking/filters contract.
- `frontend/src/modules/drone-defense/domain/map-measurement.ts` — haversine distance, segment total and `м/км` formatting.
- `frontend/src/modules/drone-defense/domain/map-measurement.test.ts` — geometry/format tests.
- `frontend/src/modules/drone-defense/domain/save-status.ts` — normalized user-facing persistence state/copy.
- `frontend/src/modules/drone-defense/domain/save-status.test.ts` — state/copy matrix.
- `frontend/src/modules/drone-defense/ui/gis-legend.tsx` — compact accessible legend disclosure.
- `frontend/src/modules/drone-defense/domain/gis-ux-source-contract.test.mjs` — source-level semantics/target/technical-copy regression.

### Modified files

- `frontend/src/shared/lib/use-defense-project-store.ts` — delete snapshot/undo and hidden-layer placement guard.
- `frontend/src/shared/lib/use-defense-project-store.test.ts` — RED/GREEN store contract.
- `frontend/src/modules/drone-defense/ui/drone-defense-prototype.tsx` — confirmation/undo orchestration, hidden active state, search facets, workspace defaults/live region.
- `frontend/src/modules/drone-defense/ui/echelon-objects-list.tsx` — delete intent, labels and 44px actions.
- `frontend/src/modules/drone-defense/ui/defense-tools-panel.tsx` — compatible reason and blocked placement semantics.
- `frontend/src/modules/drone-defense/ui/coordinate-placement-panel.tsx` — non-deceptive initial coordinate values and field descriptions.
- `frontend/src/modules/drone-defense/ui/gis-board.tsx` — styling, legend, reset extent, measurement and localized basemap copy.
- `frontend/src/modules/drone-defense/ui/drone-defense-prototype.module.css` — fluid/docked workspace and target sizing.
- `frontend/src/modules/drone-defense/domain/use-defense-variants-store.ts` — explicit persistence states, retry intent and localized errors.
- `frontend/src/modules/drone-defense/domain/use-defense-variants-store.test.ts` — success/offline/network/http/409/retry matrix.
- `frontend/src/modules/drone-defense/ui/variant-selector.tsx` — shared save-state label/live region.
- `frontend/src/modules/drone-defense/ui/variants-modal.tsx` — preserve input, retry/details/conflict actions.
- `frontend/src/shared/config/base-map-sources.ts` — user-facing Russian titles/descriptions.
- `frontend/src/shared/config/base-map-sources.test.ts` — no dev/transport/license copy in view model.
- `frontend/test/playwright/prototype.spec.ts` — desktop safety, keyboard and UI-state regression.
- `knowledge-base/05_Design/GIS_UX_Hardening_Spec_2026-07-15.md` — implementation status/evidence.
- `knowledge-base/Продуктовый_план_Fortis.md` — completed scope and local-backend verification note.

---

### Task 1: Establish the Failing Compliance Baseline

**Files:**
- Create: `frontend/src/modules/drone-defense/domain/gis-ux-source-contract.test.mjs`
- Modify: `frontend/test/playwright/prototype.spec.ts`

**Interfaces:**
- Consumes: approved specification and current source files.
- Produces: executable RED evidence for each current violation; later tasks turn individual assertions GREEN.

- [x] **Step 1: Add source-contract assertions for the current violations**

```js
import assert from "node:assert/strict";
import fs from "node:fs";

const prototype = fs.readFileSync(new URL("../ui/drone-defense-prototype.tsx", import.meta.url), "utf8");
const board = fs.readFileSync(new URL("../ui/gis-board.tsx", import.meta.url), "utf8");
const objects = fs.readFileSync(new URL("../ui/echelon-objects-list.tsx", import.meta.url), "utf8");

assert(!prototype.includes("selectLayerWithDefaultSlot(fallback.id)"), "hiding active layer must not select fallback");
assert(prototype.includes("pendingPlacementDeletion"), "placed object delete must require confirmation state");
assert(prototype.includes("undoDeletePlacedObject"), "placed object delete must expose undo");
assert(board.includes("Измерить расстояние"), "map must expose distance measurement");
assert(board.includes("Показать весь объект"), "map must expose reset extent");
assert(board.includes("<GisLegend"), "map must render compact GIS legend");
assert(!board.includes("source.type"), "basemap menu must not expose transport type");
assert(!board.includes("license check"), "basemap menu must not expose licensing implementation flag");
assert(objects.includes("min-h-11"), "object actions must have 44px target height");
```

- [x] **Step 2: Expand Playwright with named but initially failing scenarios**

```ts
test.describe('GIS UX hardening', () => {
  test.use({ viewport: { width: 1280, height: 720 } });

  test('hiding the active layer preserves its selection', async ({ page }) => {
    await page.goto('http://127.0.0.1:3000/prototype');
    await page.getByRole('button', { name: /L5/ }).click();
    await page.getByRole('button', { name: /Скрыть эшелон L5/ }).click();
    await expect(page.getByText('Активный · Скрыт')).toBeVisible();
  });

  test('map exposes reset, measure and legend', async ({ page }) => {
    await page.goto('http://127.0.0.1:3000/prototype');
    await expect(page.getByRole('button', { name: 'Показать весь объект' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Измерить расстояние' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Показать легенду карты' })).toBeVisible();
  });
});
```

- [x] **Step 3: Run source contract and confirm RED**

Run: `cd frontend && node src/modules/drone-defense/domain/gis-ux-source-contract.test.mjs`  
Expected: FAIL first on fallback selection or missing deletion confirmation.

- [x] **Step 4: Record baseline commands without changing production code**

Run: `cd frontend && pnpm exec tsx src/shared/lib/use-defense-project-store.test.ts`  
Expected: PASS existing baseline.

Run: `cd frontend && pnpm exec tsx src/modules/drone-defense/domain/use-defense-variants-store.test.ts`  
Expected: PASS existing baseline.

---

### Task 2: Preserve Hidden Active Layer and Block Invisible Placement (FRT-136)

**Files:**
- Modify: `frontend/src/shared/lib/use-defense-project-store.test.ts`
- Modify: `frontend/src/shared/lib/use-defense-project-store.ts`
- Modify: `frontend/src/modules/drone-defense/ui/drone-defense-prototype.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/defense-tools-panel.tsx`

**Interfaces:**
- Consumes: `DefenseProject.activeLayerId`, `EditableDefenseLayer.isVisible`.
- Produces: `isActiveLayerHidden: boolean`, explicit `showActiveLayer()` UI path, store-level placement validation message.

- [x] **Step 1: Write failing store assertions**

Append after the existing visibility assertion:

```ts
const activeBeforeHide = useDefenseProjectStore.getState().project.activeLayerId;
useDefenseProjectStore.getState().setLayerVisibility(activeBeforeHide!, false);
assert(
  useDefenseProjectStore.getState().project.activeLayerId === activeBeforeHide,
  "hiding active layer must preserve activeLayerId",
);
const hiddenPlacementResult = useDefenseProjectStore.getState().placeObject(
  "mobile-radar",
  activeBeforeHide!,
  { lat: 55.44, lng: 37.1 },
);
assert(!hiddenPlacementResult.isValid, "placement into hidden active layer must be rejected");
assert(hiddenPlacementResult.message?.includes("Покажите эшелон"), "hidden placement must explain recovery");
```

- [x] **Step 2: Verify RED**

Run: `cd frontend && pnpm exec tsx src/shared/lib/use-defense-project-store.test.ts`  
Expected: FAIL because current `placeObject` accepts hidden layers.

- [x] **Step 3: Add the minimal store guard**

In `placeObject`, before geometry validation:

```ts
const layer = get().project.layers.find((item) => item.id === layerId);
if (layer?.isVisible === false) {
  return {
    isValid: false,
    level: "warning" as const,
    message: `Эшелон ${layer.code} скрыт. Покажите эшелон перед размещением.`,
  };
}
```

- [x] **Step 4: Remove implicit fallback selection and expose combined state**

Replace `toggleLayerVisibility` with:

```ts
const toggleLayerVisibility = (layerId: string, isVisible: boolean) => {
  setLayerVisibility(layerId, isVisible);
  const layer = project.layers.find((item) => item.id === layerId);
  setLastPlacementMessage(
    `${layer?.code ?? "Эшелон"} ${isVisible ? "показан" : "скрыт"}. Активный эшелон не изменён.`,
  );
};
```

Derive `const isActiveLayerHidden = selectedLayer?.isVisible === false;`, render `Активный · Скрыт`, and pass a disabled reason to placement cards. The recovery button calls `setLayerVisibility(selectedLayer.id, true)` without changing selection.

- [x] **Step 5: Verify GREEN**

Run: `cd frontend && pnpm exec tsx src/shared/lib/use-defense-project-store.test.ts`  
Expected: PASS.

Run: `cd frontend && node src/modules/drone-defense/domain/gis-ux-source-contract.test.mjs`  
Expected: advances past fallback-selection assertion.

---

### Task 3: Add Confirmed Deletion and Exact Undo (FRT-133)

**Files:**
- Modify: `frontend/src/shared/lib/use-defense-project-store.test.ts`
- Modify: `frontend/src/shared/lib/use-defense-project-store.ts`
- Modify: `frontend/src/modules/drone-defense/ui/drone-defense-prototype.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/echelon-objects-list.tsx`

**Interfaces:**
- Produces: `lastDeletedPlacement`, `deletePlacedObject(id): boolean`, `undoDeletePlacedObject(): boolean`, `clearDeletedPlacementUndo()`.

- [x] **Step 1: Write failing exact-restore test**

```ts
const objectBeforeDelete = structuredClone(useDefenseProjectStore.getState().project.placedObjects[0]);
const deleted = useDefenseProjectStore.getState().deletePlacedObject(objectBeforeDelete.id);
assert(deleted, "deletePlacedObject must report success");
assert(useDefenseProjectStore.getState().lastDeletedPlacement?.object.id === objectBeforeDelete.id, "delete must retain undo snapshot");
assert(useDefenseProjectStore.getState().undoDeletePlacedObject(), "undo must report success");
const restored = useDefenseProjectStore.getState().project.placedObjects.find((item) => item.id === objectBeforeDelete.id);
assert.deepEqual(restored, objectBeforeDelete, "undo must restore exact placement payload");
```

- [x] **Step 2: Verify RED**

Run: `cd frontend && pnpm exec tsx src/shared/lib/use-defense-project-store.test.ts`  
Expected: TypeScript/runtime failure because undo API is absent.

- [x] **Step 3: Implement store snapshot/undo**

Add state:

```ts
type DeletedPlacementSnapshot = { object: PlacedDefenseObject; selectedObjectId?: string };
lastDeletedPlacement: DeletedPlacementSnapshot | null;
deletePlacedObject: (objectId: string) => boolean;
undoDeletePlacedObject: () => boolean;
clearDeletedPlacementUndo: () => void;
```

Implementation:

```ts
deletePlacedObject: (objectId) => {
  const object = get().project.placedObjects.find((item) => item.id === objectId);
  if (!object) return false;
  const selectedObjectId = get().project.selectedObjectId;
  applyProject(deletePlacedObjectInProject(get().project, objectId), set);
  set({ lastDeletedPlacement: { object: structuredClone(object), selectedObjectId } });
  return true;
},
undoDeletePlacedObject: () => {
  const snapshot = get().lastDeletedPlacement;
  if (!snapshot || get().project.placedObjects.some((item) => item.id === snapshot.object.id)) return false;
  const project = {
    ...get().project,
    placedObjects: [...get().project.placedObjects, snapshot.object],
    selectedObjectId: snapshot.selectedObjectId,
    activeLayerId: snapshot.object.layerId,
    updatedAt: new Date().toISOString(),
  };
  applyProject(project, set);
  set({ lastDeletedPlacement: null });
  return true;
},
clearDeletedPlacementUndo: () => set({ lastDeletedPlacement: null }),
```

- [x] **Step 4: Route every placed-object delete through one confirmation**

Add `pendingPlacementDeletionId`, render Ant `Modal` with title `Удалить «{name}»?`, copy about map/echelon/calculation, `okText="Удалить объект"`, danger button, and call the store only from confirm. `EchelonObjectsList.onRemove`, МОГ inspector delete, and catalog remove all set the pending id.

- [x] **Step 5: Add 10-second undo snackbar**

Use an Ant `message`/custom notice with action `Отменить`; set a timeout that calls `clearDeletedPlacementUndo`, clear it on undo/unmount, and keep the text `Объект удалён` in an `aria-live="polite"` region.

- [x] **Step 6: Verify GREEN**

Run: `cd frontend && pnpm exec tsx src/shared/lib/use-defense-project-store.test.ts`  
Expected: PASS including exact restore.

---

### Task 4: Implement Tokenized Search, Facets and Compatible-First (FRT-115/FRT-137)

**Files:**
- Create: `frontend/src/modules/drone-defense/domain/catalog-search.ts`
- Create: `frontend/src/modules/drone-defense/domain/catalog-search.test.ts`
- Modify: `frontend/src/modules/drone-defense/ui/drone-defense-prototype.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/defense-tools-panel.tsx`

**Interfaces:**
- Produces: `filterAndRankCatalog(items, options): AssetCatalogItem[]` and `CatalogFacetState`.

- [x] **Step 1: Write ranking and facet tests first**

```ts
import assert from "node:assert/strict";
import { filterAndRankCatalog } from "./catalog-search";

const items = [
  { assetId: "smoke", title: "Дымогенерация", subtitle: "", categoryLabel: "", rangeLabel: "", priceLabel: "", coverageLabel: "", category: "jamming", roles: [], tags: [], compatibilityStatus: "compatible" },
  { assetId: "mog", title: "МОГ", subtitle: "Мобильная огневая группа", categoryLabel: "", rangeLabel: "", priceLabel: "", coverageLabel: "", category: "kinetic", roles: [], tags: [], compatibilityStatus: "recommended" },
] as any;

assert.deepEqual(filterAndRankCatalog(items, { query: "МОГ", mode: "all" }).map((item) => item.assetId), ["mog"]);
assert.equal(filterAndRankCatalog(items, { query: "", mode: "compatible-first" })[0].assetId, "mog");
assert.deepEqual(filterAndRankCatalog(items, { query: "", mode: "all", categories: new Set(["jamming"]) }).map((item) => item.assetId), ["smoke"]);
```

- [x] **Step 2: Verify RED**

Run: `cd frontend && pnpm exec tsx src/modules/drone-defense/domain/catalog-search.test.ts`  
Expected: module-not-found failure.

- [x] **Step 3: Implement deterministic scoring**

```ts
const normalize = (value: string) => value.toLocaleLowerCase("ru-RU").replace(/[\p{P}\p{S}]+/gu, " ").replace(/\s+/g, " ").trim();
const tokens = (value: string) => normalize(value).split(" ").filter(Boolean);

function score(item: AssetCatalogItem, query: string) {
  const q = normalize(query);
  if (!q) return 0;
  const title = normalize(item.title);
  const titleTokens = tokens(item.title);
  if (title === q) return 500;
  if (titleTokens.includes(q)) return 400;
  if (titleTokens.some((token) => token.startsWith(q))) return 300;
  const secondary = normalize([item.subtitle, item.categoryLabel, ...item.roles, ...item.tags].join(" "));
  if (tokens(secondary).includes(q)) return 200;
  return secondary.includes(q) || title.includes(q) ? 100 : -1;
}
```

`filterAndRankCatalog` filters `score >= 0`, applies facets, then sorts by score and compatibility weight (`recommended > compatible > warning > incompatible`) with original index as stable tie-breaker.

- [x] **Step 4: Add visible facets and useful empty state**

Add a visible/search-associated label, result count, compatibility mode (`Совместимые сначала` / `Все`), category and protection-type controls. Empty state repeats query and offers `Сбросить поиск` and `Сбросить фильтры`.

- [x] **Step 5: Verify GREEN**

Run: `cd frontend && pnpm exec tsx src/modules/drone-defense/domain/catalog-search.test.ts`  
Expected: PASS.

---

### Task 5: Calm Cartography, Localized Basemap and Dynamic Legend (FRT-134)

**Files:**
- Create: `frontend/src/modules/drone-defense/ui/gis-legend.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/gis-board.tsx`
- Modify: `frontend/src/shared/config/base-map-sources.ts`
- Modify: `frontend/src/shared/config/base-map-sources.test.ts`

**Interfaces:**
- `GisLegend` consumes visible `DefenseLayer[]` and booleans for coverage/constraints.
- Basemap model retains technical `type` internally but UI renders only title/description/attribution.

- [x] **Step 1: Add failing base-map copy assertions**

```ts
for (const source of createBaseMapSources({})) {
  assert(!source.description?.match(/demo|dev|license|production dependency/i), `technical copy leaked: ${source.id}`);
  assert(!source.title.match(/Internal|demo/i), `technical title leaked: ${source.id}`);
}
```

- [x] **Step 2: Verify RED**

Run: `cd frontend && pnpm exec tsx src/shared/config/base-map-sources.test.ts`  
Expected: FAIL on OpenFreeMap/OSM/internal technical descriptions.

- [x] **Step 3: Localize source view copy and stop rendering technical badges**

Use titles `Светлая карта`, `OpenStreetMap`, `Топографическая`, `Спутниковая`, `Локальная`; remove `source.type` and technical badge rendering from `GisBoard`. Keep technical fields for `resolveMapStyle` only.

- [x] **Step 4: Set cartographic opacity and border tokens**

In zone layers:

```ts
const zoneFillColor = (item: EchelonZone) => [
  item.fillColor[0], item.fillColor[1], item.fillColor[2],
  isPreview ? 54 : isActive ? 38 : 20,
] as [number, number, number, number];
const zoneLineColor = (item: EchelonZone) => [
  item.lineColor[0], item.lineColor[1], item.lineColor[2],
  isActive ? 235 : 125,
] as [number, number, number, number];
const zoneLineWidth = isPreview ? 3 : isActive ? 2 : 1;
```

- [x] **Step 5: Add accessible dynamic legend**

`GisLegend` renders a `button` with `aria-expanded`, `aria-controls="gis-map-legend"`, min 44px target, visible layer color/code/name rows, marker/coverage/constraints rows only when present. Mount it in the lower-left cluster without covering scale bar.

- [x] **Step 6: Configure Cyrillic text rendering**

For each deck.gl `TextLayer`, provide a font stack available to the current map (`Arial, sans-serif`) and a character set containing Cyrillic or use SDF settings that generate the glyph atlas client-side. Add source regression asserting `characterSet` includes `А` and `я`.

- [x] **Step 7: Verify GREEN**

Run: `cd frontend && pnpm exec tsx src/shared/config/base-map-sources.test.ts`  
Expected: PASS.

Run: `cd frontend && node src/modules/drone-defense/domain/gis-ux-source-contract.test.mjs`  
Expected: advances through legend/technical-copy assertions.

---

### Task 6: Add Reset Extent and Distance Measurement (FRT-135)

**Files:**
- Create: `frontend/src/modules/drone-defense/domain/map-measurement.ts`
- Create: `frontend/src/modules/drone-defense/domain/map-measurement.test.ts`
- Modify: `frontend/src/modules/drone-defense/ui/gis-board.tsx`

**Interfaces:**
- Produces: `measurePathMeters(points)`, `formatMeasuredDistance(meters)`.
- GisBoard owns ephemeral `measurementMode`, `measurementPoints`, `measurementComplete`; none enters `DefenseProject`.

- [x] **Step 1: Write failing geometry tests**

```ts
import assert from "node:assert/strict";
import { formatMeasuredDistance, measurePathMeters } from "./map-measurement";

assert.equal(measurePathMeters([]), 0);
assert.equal(measurePathMeters([{ lat: 55, lng: 37 }]), 0);
const oneKm = measurePathMeters([{ lat: 55, lng: 37 }, { lat: 55.00899, lng: 37 }]);
assert(oneKm > 990 && oneKm < 1010);
assert.equal(formatMeasuredDistance(850), "850 м");
assert.equal(formatMeasuredDistance(1250), "1,25 км");
```

- [x] **Step 2: Verify RED**

Run: `cd frontend && pnpm exec tsx src/modules/drone-defense/domain/map-measurement.test.ts`  
Expected: module-not-found failure.

- [x] **Step 3: Implement haversine path total and formatter**

```ts
const earthRadiusM = 6_371_000;
const radians = (degrees: number) => degrees * Math.PI / 180;

export function measurePathMeters(points: Coordinates[]) {
  return points.slice(1).reduce((sum, point, index) => {
    const previous = points[index];
    const dLat = radians(point.lat - previous.lat);
    const dLng = radians(point.lng - previous.lng);
    const a = Math.sin(dLat / 2) ** 2 + Math.cos(radians(previous.lat)) * Math.cos(radians(point.lat)) * Math.sin(dLng / 2) ** 2;
    return sum + earthRadiusM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }, 0);
}
```

- [x] **Step 4: Add reset control**

`Показать весь объект` calls `setInteractiveViewState(protectedObjectInitialViewState)` and does not call any selection/project action.

- [x] **Step 5: Add measurement interaction/layers**

When mode is active, DeckGL click adds `{lng, lat}` and returns before polygon/tool placement. Enter/double-click marks complete, Escape clears unfinished measurement, `Очистить` clears all. Render one `PathLayer`, point `ScatterplotLayer`, and a result badge. Toggle has `aria-pressed` and 44px target.

- [x] **Step 6: Verify GREEN**

Run: `cd frontend && pnpm exec tsx src/modules/drone-defense/domain/map-measurement.test.ts`  
Expected: PASS.

---

### Task 7: Normalize Save/Offline/Conflict/Error Recovery (FRT-101/FRT-139)

**Files:**
- Create: `frontend/src/modules/drone-defense/domain/save-status.ts`
- Create: `frontend/src/modules/drone-defense/domain/save-status.test.ts`
- Modify: `frontend/src/modules/drone-defense/domain/use-defense-variants-store.ts`
- Modify: `frontend/src/modules/drone-defense/domain/use-defense-variants-store.test.ts`
- Modify: `frontend/src/modules/drone-defense/ui/variant-selector.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/variants-modal.tsx`

**Interfaces:**
- `PersistenceState = "idle" | "saving" | "saved" | "offline-draft" | "conflict" | "error"`.
- Store produces `lastSuccessfulSaveAt`, `lastFailedIntent`, `retryLastFailedIntent()`.

- [x] **Step 1: Write failing copy/state matrix**

```ts
assert.deepEqual(describePersistenceState({ state: "saving" }), { label: "Сохраняем…", tone: "progress" });
assert.equal(describePersistenceState({ state: "offline-draft" }).label, "Офлайн · изменения сохранены на устройстве");
assert.equal(describePersistenceState({ state: "conflict" }).label, "Версия проекта изменилась");
assert.equal(localizeSaveError(new Error("Failed to reach backend"), true), "Не удалось подключиться к локальному серверу");
```

- [x] **Step 2: Extend variants-store RED tests**

Add cases for rejected fetch/network, HTTP 500, 409, retry preserving the exact variant name, and success setting `lastSuccessfulSaveAt`. Verify name reset happens only after success.

- [x] **Step 3: Verify RED**

Run: `cd frontend && pnpm exec tsx src/modules/drone-defense/domain/save-status.test.ts`  
Expected: module-not-found failure.

Run: `cd frontend && pnpm exec tsx src/modules/drone-defense/domain/use-defense-variants-store.test.ts`  
Expected: FAIL on missing explicit states/retry.

- [x] **Step 4: Implement normalized state and retry intent**

Keep a discriminated intent:

```ts
type SaveIntent = { kind: "save-new"; name: string } | { kind: "overwrite"; projectId: string };
```

On failure preserve intent and local project, classify 409 as `conflict`, `navigator.onLine === false` or fetch rejection as `offline-draft`, other HTTP as `error`. Retry dispatches the retained intent once and is disabled during `saving`.

- [x] **Step 5: Preserve modal input and add recovery actions**

Only clear `newName` when `saveAsNewVariant` returns success. Render localized inline alert, `Повторить`, `Подробнее`, and on conflict `Обновить данные` plus `Сохранить копию`. Technical detail is collapsed under `Подробнее`.

- [x] **Step 6: Verify GREEN with mocks**

Run: `cd frontend && pnpm exec tsx src/modules/drone-defense/domain/save-status.test.ts`  
Expected: PASS.

Run: `cd frontend && pnpm exec tsx src/modules/drone-defense/domain/use-defense-variants-store.test.ts`  
Expected: PASS all success/network/http/409/retry cases without a live backend.

- [x] **Step 7: Verify real local backend path**

Run: `cd backend && make up`  
Expected: app and PostgreSQL healthy; backend available at `http://localhost:8090`.

Run in another terminal: `cd frontend && FORTIS_API_BASE_URL=http://localhost:8090 BACKEND_URL=http://localhost:8090/api/v1 pnpm dev`  
Expected: `/prototype` loads; variant request reaches only the local backend.

---

### Task 8: Finish Workspace Density, MOG Inspector and Control Semantics (FRT-49/FRT-66/FRT-93/FRT-114)

**Files:**
- Modify: `frontend/src/modules/drone-defense/ui/drone-defense-prototype.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/mog-composition-editor.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/coordinate-placement-panel.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/drone-defense-prototype.module.css`

**Interfaces:**
- Existing selection remains independent from panel visibility.
- Objects panel opens only for explicit object/list action, never solely because a layer was selected.

- [x] **Step 1: Add RED source assertions**

Assert `selectLayerWithDefaultSlot` does not call `setIsEchelonObjectsPanelOpen(true)`, coordinate fields have example helper text rather than numeric placeholders, active nav has `aria-current`, and relevant buttons have `aria-expanded`/`aria-label`.

- [x] **Step 2: Verify RED**

Run: `cd frontend && node src/modules/drone-defense/domain/gis-ux-source-contract.test.mjs`  
Expected: FAIL on objects-panel or coordinate semantics.

- [x] **Step 3: Stop opening empty objects panel**

Remove panel-open mutation from layer selection. Open it only after selecting an existing placement or explicit `Объекты эшелона` action. Empty state remains available after explicit open.

- [x] **Step 4: Make coordinate examples non-deceptive**

Use placeholders `Например: 55,4400` and `Например: 37,1000`, connect helper with `aria-describedby`, and keep fields empty. Close/check/place actions use min-height `44px`.

- [x] **Step 5: Keep MOG editor map-aware**

At desktop use a right dock with `width: min(32rem, 42vw)`, `max-width: calc(100vw - 2rem)`, internal vertical scroll, no horizontal scroll; at narrow widths use full-width overlay. Do not add a new arbitrary breakpoint; reuse existing project breakpoint.

- [x] **Step 6: Verify GREEN**

Run: `cd frontend && node src/modules/drone-defense/domain/gis-ux-source-contract.test.mjs`  
Expected: all source assertions PASS after Task 9 semantics are added.

---

### Task 9: Desktop Accessibility and End-to-End Regression (FRT-138)

**Files:**
- Modify: `frontend/src/modules/drone-defense/ui/drone-defense-prototype.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/gis-board.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/echelon-objects-list.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/variant-selector.tsx`
- Modify: `frontend/src/modules/drone-defense/ui/drone-defense-prototype.module.css`
- Modify: `frontend/test/playwright/prototype.spec.ts`

**Interfaces:**
- Produces a keyboard-operable main workflow and a polite live region for active/hidden/save states.

- [x] **Step 1: Add semantic states and target sizes**

Use `aria-current="page"` for active navigation, `aria-pressed` for visibility/measure, `aria-expanded` for panels/legend/basemap, meaningful names for every icon-only button, and `.prototypeIconButton { min-width: 2.75rem; min-height: 2.75rem; }`.

- [x] **Step 2: Add live status**

Render one visually hidden `aria-live="polite"` node for active layer/visibility/placement/delete and one in variant status for persistence state. Avoid assertive announcements for routine map movement.

- [x] **Step 3: Add keyboard browser tests**

Playwright covers: focus search → query `МОГ` → coordinate action → cancel panel → layer visibility → measure toggle → legend disclosure → delete confirmation cancel. Run at `1280×720` and a second smoke at `1440×960`.

- [x] **Step 4: Verify source and browser GREEN**

Run: `cd frontend && node src/modules/drone-defense/domain/gis-ux-source-contract.test.mjs`  
Expected: PASS.

Run with frontend dev server active: `cd frontend && pnpm exec playwright test test/playwright/prototype.spec.ts --reporter=line`  
Expected: PASS on Chromium at both desktop viewports.

---

### Task 10: Full Verification, Documentation and Linear Closure

**Files:**
- Modify: `knowledge-base/05_Design/GIS_UX_Hardening_Spec_2026-07-15.md`
- Modify: `knowledge-base/Продуктовый_план_Fortis.md`
- Modify: this plan checkbox state.

**Interfaces:**
- Consumes all task evidence.
- Produces requirement-by-requirement completion matrix and final Linear status updates.

- [x] **Step 1: Run all focused tests**

```bash
cd frontend
pnpm exec tsx src/shared/lib/use-defense-project-store.test.ts
pnpm exec tsx src/modules/drone-defense/domain/catalog-search.test.ts
pnpm exec tsx src/modules/drone-defense/domain/map-measurement.test.ts
pnpm exec tsx src/modules/drone-defense/domain/save-status.test.ts
pnpm exec tsx src/modules/drone-defense/domain/use-defense-variants-store.test.ts
node src/modules/drone-defense/domain/gis-ux-source-contract.test.mjs
```

Expected: all PASS with no warnings.

- [x] **Step 2: Run regression suite and static checks**

Run: `cd frontend && pnpm lint`  
Expected: exit 0.

Run: `cd frontend && pnpm exec tsc --noEmit`  
Expected: exit 0.

Run: `cd frontend && pnpm build`  
Expected: exit 0.

- [x] **Step 3: Run desktop browser verification**

With frontend active and local backend active when checking real save success:

Run: `cd frontend && pnpm exec playwright test test/playwright/prototype.spec.ts --reporter=line`  
Expected: all PASS.

Capture screenshots for `1280×720` and `1440×960`; inspect no overlap, clipped focus, technical basemap copy or missing Cyrillic.

- [x] **Step 4: Audit every approved requirement**

Append a table to the spec with rows 4.1–4.7 and evidence: source file, test command, browser screenshot/state, local-backend or mock proof. Any missing/indirect evidence remains incomplete and keeps the goal active.

- [x] **Step 5: Update Linear from verified evidence only**

- Move FRT-133, 136, 134, 135, 137, 139, 138 to Done only when their own AC and verification pass.
- Update FRT-49, 66, 93, 101, 114, 115 only for the portions implemented here; do not close tickets that retain unrelated scope.
- Keep FRT-118 Duplicate of FRT-12.
- Add a final comment to each completed issue with exact test commands and local-backend limitation.

- [x] **Step 6: Commit repository-owned changes separately**

Commit frontend changes inside `frontend/`, knowledge changes inside `knowledge-base/`, then update the parent submodule pointers and commit parent coordination docs. Do not include unrelated local files or `frontend/src/app/page.tsx` unless its diff belongs to this scope.

---

## Self-Review

- **Spec coverage:** Sections 4.1–4.7 map to Tasks 3, 2, 5, 6, 4, 9 and 7 respectively. Existing-task findings map to Task 8 and Task 9. Local backend constraint appears in Global Constraints, Task 7 and final verification.
- **Placeholder scan:** No `TBD`, implementation placeholder or undefined “appropriate handling” step remains. Each behavior-changing task starts with a concrete failing assertion and exact command.
- **Type consistency:** `AssetCatalogItem` comes from `@/shared/lib/defense-project`; map coordinates use existing `{lat,lng}` `Coordinates`; store undo uses the existing `PlacedDefenseObject`; persistence states are shared by store and UI.
- **Scope boundaries:** No backend schema, Next routing/config, mobile redesign, 3D behavior, geocoder, area measurement or calculation formula change is included.

## Execution Mode

Inline execution is selected by the user’s terminal instruction to continue until full specification compliance. Use `superpowers:executing-plans`; execute task-by-task with RED/GREEN evidence and keep this checklist current.
