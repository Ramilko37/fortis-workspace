# Task 5 — final verification report

Date: 2026-07-23

Frontend baseline HEAD: `767b6928b6f6f1f39e38970ba629fcbc5ead9554`

Historical visual baseline: `49bc1e1` (`feat: migrate GIS workspace to Fortis UI Kit`)

## Result

Stage 5 is verified. The current implementation passes the consolidated
behavioral, accessibility, geometry, visual-regression and isolated browser
smoke suite at all four required desktop viewports. The production build and
the relevant component/domain and inspector regression suites also pass.

The final verification added the missing collapsible context-panel behavior
and preserved persisted conflict diagnostics on project import. The conflict
change is hydration-only: it does not introduce or alter conflict derivation
during editing.

## State coverage

| # | Required state | Evidence |
|---:|---|---|
| 1 | Nothing selected | Explicit inspector empty state; visible and in viewport |
| 2 | Echelon selected | Semantic tree selection and visible echelon inspector |
| 3 | Object selected | Object inspector and canonical selected-object state |
| 4 | Empty echelon | Explicit zero-object/empty-echelon content |
| 5 | Library loading | Visible loading status and disabled refresh action |
| 6 | Library error | Visible local-catalog fallback alert after mocked 503 |
| 7 | Empty library search | Visible no-results state after an unmatched query |
| 8 | Long library list | Scrollable list, first/last items reachable in the library region |
| 9 | Create form | Create view replaces catalog and first input is visible/focused |
| 10 | Create validation/cancel | Inline validation is visible; cancel restores catalog |
| 11 | Library collapsed | Collapse action and collapsed tray state are visible |
| 12 | Context panel collapsed | Accessible collapse/expand controls; map width increases |
| 13 | Bottom drawer collapsed | Compact echelon summary/action is visible |
| 14 | Bottom drawer expanded | Expanded drawer content is visible and inside viewport |
| 15 | Basemap menu | Accessible dialog and current local basemap option are visible |
| 16 | Long names | Long echelon/object names remain visible without viewport clipping |
| 17 | Conflicts | Persisted coverage conflict is visible in inspector and drawer |

The consolidated suite asserts role/name-based accessibility, visibility,
`toBeInViewport`, bounding boxes, map-width priority, viewport boundaries and
`document.documentElement.scrollWidth <= clientWidth`; it does not rely on
DOM-existence checks alone.

## Commands and exact results

### TDD evidence

Context panel:

```text
pnpm exec playwright test --config test/playwright/workspace-inspector.config.ts --grep 'collapses and restores'
RED: 2 failed — no "Свернуть панель контекста" control
GREEN: 2 passed (16.8s) — 1024x768 and 1280x800
```

Persisted conflict hydration:

```text
pnpm exec tsx --test src/shared/lib/defense-project-conflict-hydration.test.ts
RED: 0/1 — persisted `true` became `false`
GREEN: 1 passed, 0 failed
```

### Final test runs

```text
pnpm exec playwright test --config test/playwright/stage-5.config.ts
11 passed (1.6m)
```

This final run contains six state-matrix/smoke tests plus four viewport visual
tests and the isolated `/prototype` smoke. A preceding complete run also passed
11/11. One later rerun exposed a timing-only 5-second assertion while the UI
was still in its valid library-loading state; its trace showed the mocked asset
response completed with 503 in 108 ms. The assertion now waits for the
terminal error state, and the exact case passed three repeated runs:

```text
pnpm exec playwright test --config test/playwright/stage-5.config.ts \
  --grep 'library error and empty search' --repeat-each=3
3 passed (23.3s)
```

Inspector regression:

```text
pnpm exec playwright test --config test/playwright/workspace-inspector.config.ts
6 passed (39.6s)
```

Component/domain/layout coverage:

```text
pnpm exec tsx --test \
  src/shared/lib/defense-project-conflict-hydration.test.ts \
  src/modules/drone-defense/ui/gis-workspace-panels.test.tsx \
  src/modules/drone-defense/ui/asset-library-layout.test.ts \
  src/modules/drone-defense/ui/gis-responsive-contract.test.ts
7 passed, 0 failed
```

Repository hygiene:

```text
git diff --check
exit 0
```

### Production build

```text
pnpm build
exit 0
Compiled successfully in 7.1s
TypeScript finished in 10.3s
27/27 static pages generated
```

The first build-time type pass caught and corrected two verification changes:
an unsupported `IconButton` variant and an unsupported Playwright config key.
A later sandboxed attempt could not reach Google Fonts; the required rerun with
network access completed successfully as shown above.

The pre-existing user `tsconfig.json` was not edited or staged. Its SHA-1
before and after verification is identical:

```text
07b72d1e983a98a5f2c87069de0c3199203cdd4d  tsconfig.json
```

## Visual regression artifacts

All counts were verified:

```text
24 before PNGs
24 after PNGs
24 committed-test baseline PNGs
```

Viewports:

- `1280x800`
- `1366x768`
- `1440x900`
- `1920x1080`

States in every viewport:

- `primary`
- `selected-echelon`
- `create-form`
- `collapsed-library`
- `expanded-bottom-drawer`
- `basemap-menu`

Exact artifact roots:

```text
/Users/rr/Documents/Fortis/frontend/output/playwright/stage-5-767b692/before-49bc1e1/<viewport>/<state>-<viewport>.png
/Users/rr/Documents/Fortis/frontend/output/playwright/stage-5-767b692/after/<viewport>/<state>-<viewport>.png
/Users/rr/Documents/Fortis/frontend/test/playwright/stage-5.spec.ts-snapshots/<state>-<viewport>-darwin.png
```

The historical commit was built successfully with `pnpm build` and served with
`pnpm start` for the before capture. Its development runtime was not usable:
Turbopack returned `Expected workUnitAsyncStorage to have a store`, and the
webpack fallback rejected the historical CSS-module selector
`:global(:root)`. Production serving avoided both historical dev-runtime
incompatibilities. The before interaction also reproduced the original
inspector pointer overlap on the bottom-drawer control.

Representative after images were manually inspected at 1280x800 and
1920x1080. The map remains the dominant workspace, panels and menus stay
inside the viewport, and no horizontal overflow or clipped primary action was
observed.

## Browser smoke and warnings

Console evidence:

```text
/Users/rr/Documents/Fortis/frontend/output/playwright/stage-5-767b692/browser-console.json
```

The isolated smoke records:

- HTTP 200 for `/prototype`
- zero `pageErrors`
- zero console messages of type `error`
- only React DevTools informational text and `[HMR] connected`

Known non-fatal development-server warnings observed outside the isolated
browser-console error filter:

- deck.gl reports missing glyphs for Cyrillic characters
  `З, а, в, о, д, А, л, ь, ф`;
- Node 26 reports `[DEP0205] module.register() is deprecated`;
- the runner reports that `NO_COLOR` is ignored while `FORCE_COLOR` is set.

These warnings did not produce a page error, browser console error, failed
visual comparison or failed production build.

## Files added or changed by Task 5

Product/runtime:

- `src/app/globals.css`
- `src/modules/drone-defense/ui/drone-defense-prototype.tsx`
- `src/modules/drone-defense/ui/gis-workspace-panels.tsx`
- `src/shared/config/prototype-ru.ts`
- `src/shared/lib/defense-project.ts`

Tests and verification:

- `src/modules/drone-defense/ui/gis-workspace-panels.test.tsx`
- `src/shared/lib/defense-project-conflict-hydration.test.ts`
- `test/playwright/workspace-inspector.spec.ts`
- `test/playwright/stage-5.config.ts`
- `test/playwright/stage-5.spec.ts`
- `test/playwright/capture-stage-5-before.mjs`
- `test/playwright/stage-5.spec.ts-snapshots/*.png`

Generated screenshots, traces and JSON results remain untracked under the
unique Stage 5 output root. Pre-existing `.playwright-cli/`,
`debug-storybook.log`, other `output/` content and `tsconfig.json` were left
unstaged.
