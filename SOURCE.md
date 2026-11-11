# Source mapping

Reference revision: `19905b75dbea89fbfd424d67fe26c81aaed0e018`. Extracted from the `recipe/` folder of `ourapps-ae/OurPoker`; paths and line ranges are of the files there.

## Mechanism and content

The recipe's guides mix the mechanism with poker lessons. The mechanism is kept here; the lessons (`GuideId`, the `steps(id)` tables with `tut_*` keys and anchors such as `board`, `pot`, `odds`, the table-moment triggers `forTable`/`want("flop")`) stay in the recipe, which supplies them as a lessons file. `tests/fixtures/lessons.json` and `messages.json` are a small neutral sample (welcome, editing, first-share), not the recipe's.

## Web

- `implementation/web/tour-model.ts` <- `web/src/guide.ts:12-14, 16-18` (a `Step` of title, text and anchor; lessons as step lists), `44-100` (the queue; `seen`; `want` shown once ever after any waiting; `resetGuides`; `guideOpen`; `onGuideChange`; the screen a lesson belongs to and `onScreen` dropping lessons for the screen left, even the one showing, resetting the step when the first goes), `102-111` (`ring`: the circle round the element clipped to the screen, radius `max(28, diagonal / 2 + 8)`) and `139-150` (the card takes the half the circle is not in). Generalised: `GuideId` and `steps(id)` became lesson data with `validateLessons`; `L(...)` became a `translate` function; `localStorage` became an injected storage and the `tut.` and `beginner` keys options; `sessionMode() === "board"` became the `allowed` callback; `finish` is the same; `holding` and `onChange` come from the recipe's hold of the play clock while a guide shows (`guideOpen` / `onGuideChange`, used at `web/src/store.ts:116` and `web/src/main.ts:21`). New: `parseEnabled` (the recipe stored only the string "true" and Apple accepted yes and 1), `setEnabled` (the recipe's yes/no question), `createTour` as an object rather than module state, `parseLessons` (`generated-platform`).
- `implementation/web/tour-view.ts` <- `web/src/guide.ts:113-157` (`show`: the spot, the card with title, text, progress dots, Skip and Next or Got it, the loop that follows the element with `requestAnimationFrame`, kept last on the page). Generalised: the card is built by the controls component's `panel` and `button` (the recipe built `div.panel.gcard` and `button.btn` by hand); `play("click")` became an `onAction` callback; element lookup by `data-guide` is the default `anchorRect`, replaceable. Left behind: `dots` / `doubleTapDots` (`guide.ts:14, 159`, a poker hint glyph).
- `implementation/web/tour.css` <- `web/src/style.css:247-258` (`.guide`, `.gspot`, `.gcard`, `.gpages`); `--gold` became `--primary`.

## Apple

- `implementation/apple/Sources/TourModel.swift` <- `ios/OurPoker/Sources/Guide.swift:6-54` (ids, the screen a guide belongs to, steps as data) and `ios/OurPoker/Sources/TableModel.swift:44-56, 69, 78, 97-110` (the queue `guides`, `want`, `guideDone`, dropping guides for the screen left, the hold while a guide shows, `beginner`, `tutorialSeen` / `markTutorial` with the `tut.<key>` keys in `UserDefaults`). The queue, shown-once and screen rules are the same as the web model; `Tour` replaces the parts of `TableModel` that held them. Left behind: `Guides.steps(_:)` and `Guides.forTable(_:)` (`Guide.swift:27-71`, poker lessons and triggers) and the `beginner_title` question view (`ios/OurPoker/Sources/OurPokerApp.swift:88-100`).
- `implementation/apple/Sources/TourOverlay.swift` <- `Guide.swift:73-181` (`GuideAnchorKey`, `guideAnchor`, `GuideAnchorIf`, `GuideOverlay`: the dim with a hole, the ring, the card placed in the safe area on the other half). `Palette.gold` and the card colours come from the controls' theme; `Sound.play(.click)` calls and `L(...)` are the application's (buttons and text are parameters). Left behind: `DoubleTapDots` (`Guide.swift:183-189`).

## Android

- `implementation/android/src/main/java/ae/tour/TourModel.kt` <- `android/app/src/main/java/app/ourapps/ourpoker/ui/Guide.kt:65-106` (ids, steps as resource ids -> translation keys) and the matching queue in `TableViewModel.kt:54-62, 85, 177-190` (`beginner`, `guides`, `want`, `guideDone`); same model as Apple and web.
- `implementation/android/src/main/java/ae/tour/TourOverlay.kt` <- `Guide.kt:108-175` (`GuideAnchors`, `Modifier.guideAnchor`, `GuideOverlay` with `animateRectAsState`). Left behind: `GuideId.forTable` and `steps` (`Guide.kt:65-106`, poker), `DoubleTapDots` (`177-184`).
- `implementation/android/src/main/java/ae/tour/LessonsJson.kt` <- new (`generated-platform`): reads the lessons file; `PreferencesTourStorage` keeps flags in `SharedPreferences` like the recipe's `prefs`.

## Tests

`tests/web.test.ts`, `tests/fake-dom.ts`, `tests/make-fixtures.ts`, `tests/fixtures/{lessons,messages,tour}.json`, `tests/apple/main.swift`, `tests/android/{Main,Expected}.kt`, `tests/native.py`, `examples/consumer.ts` are new. `tour.json` and `Expected.kt` are generated from the TypeScript; the web test fails if they drift.
