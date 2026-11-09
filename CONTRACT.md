# Guided tour component

## Purpose and facilities
`guided-tour` teaches a person to use an application a little at a time. A lesson is a short list of steps; each step has a heading, a sentence and the name of the element on screen it is about. When the application asks for a lesson (`want`), it is shown once ever, after any already waiting: the screen is dimmed except a circle of light round the step's element, and a card on the other half of the screen gives the sentence with progress dots and Skip and Next (the last step ends the lesson). While a lesson is open `holding` is true so the host can hold play for everyone. Progress is kept on the device, one flag per lesson, along with whether the person wants to be guided at all (asked once). A lesson belongs to a screen and goes when that screen does. The mechanism is here and tested; the lessons are data the application supplies, and nothing in the component knows what the application is about. A small neutral sample lesson set (`tests/fixtures/lessons.json`) is the test data.

Facilities: `guided-tour` (Lessons of steps that ring an element, shown once each, with progress remembered on the device).

## User inputs
No installer settings. The application supplies a lessons file (`{ "format": 1, "lessons": [ { "id", "screen"?, "steps": [ { "title", "text", "anchor" } ] } ] }`), where `title` and `text` are translation keys, the messages for them, and the storage keys if it wants its own (default `tut.<lesson id>` for each lesson and `beginner` for whether the person wants guidance; the value `true` means guided, `false` means not, anything else means not yet asked).

## Artefacts and dependencies
`component.json` maps every `implementation/` source into `components/guided-tour/`:

- `implementation/android/src/main/java/ae/tour/LessonsJson.kt` -> `components/guided-tour/android/src/main/java/ae/tour/LessonsJson.kt`
- `implementation/android/src/main/java/ae/tour/TourModel.kt` -> `components/guided-tour/android/src/main/java/ae/tour/TourModel.kt`
- `implementation/android/src/main/java/ae/tour/TourOverlay.kt` -> `components/guided-tour/android/src/main/java/ae/tour/TourOverlay.kt`
- `implementation/apple/Sources/TourModel.swift` -> `components/guided-tour/apple/Sources/TourModel.swift`
- `implementation/apple/Sources/TourOverlay.swift` -> `components/guided-tour/apple/Sources/TourOverlay.swift`
- `implementation/web/tour-model.ts` -> `components/guided-tour/web/tour-model.ts`
- `implementation/web/tour-view.ts` -> `components/guided-tour/web/tour-view.ts`
- `implementation/web/tour.css` -> `components/guided-tour/web/tour.css`

Dependencies: none.
`tools.lock.json` pins verification tools: node 26.5.0, python3 3.12.8, swiftc 6.4.2, kotlinc 2.2.0, java 26.0.1. Licence wording remains deferred.

## Provided interfaces
- `interfaces/guided-tour.json` defines `guided-tour` (ae/guided-tour) version 1.0.0.

## Required interfaces
- `controls` (ae/controls) version 1.0.0, supplied by the recipe or application. Operations used: `interfaces/required/controls.json`.
- `preferences` (ae/preferences) version 1.0.0, supplied by the recipe or application. Operations used: `interfaces/required/preferences.json`.
- `language` (ae/language) version 1.0.0, supplied by the recipe or application. Operations used: `interfaces/required/language.json`.

## Integration
Web: `createTour({ lessons: parseLessons(text), storage: localStorage, translate })`, where `translate` is the `language` component's `lookup` over the current messages (a missing key shows as itself, so a gap is visible); `mountTour({ tour, ui: controls, translate })` draws the overlay using the `controls` component's `panel` and `button` and finds elements marked `data-guide="name"`; link `web/tour.css` after the controls' CSS. Ask `tour.setEnabled(true or false)` once, from the application's own question (the recipe asks whether the person is a beginner); call `tour.want(id)` when a lesson's moment comes (a screen shown, an event happened), `tour.screenChanged(name)` when the screen changes, and hold play for everyone while `tour.holding()` (`onChange` tells you). Apple: compile `TourModel.swift` anywhere and `TourOverlay.swift` in UIKit targets with the theme and controls Swift files; mark elements with `.tourAnchor("name")` and put `.tourHost(tour, buttons:)` over the content; `UserDefaultsTourStorage` keeps progress. Android: add `TourModel.kt`, `LessonsJson.kt` and `TourOverlay.kt` to a Compose module with the theme and controls Kotlin files; `LessonsJson.parse`, `PreferencesTourStorage`, `Modifier.tourAnchor` and `TourHost`. Only the storage shape of the `preferences` component (get, set, remove of a string key) is shared today: its fixed list of preference names has no guidance flag, so the tour keeps its two kinds of key through the same storage object (see the report: a `guided` preference name could be added).

## Visual definition and connected examples
`visual/definition.json` maps its ports to the provided and required interfaces. `visual/examples/connected.json` connects the component to an illustrative application consumer. Both image formats and a text description are retained under `visual/output/`.

## Infrastructure
None. Local drawing and device storage only; no accounts, network or deployment.

## Verification
Node tests check lesson validation (every fault), the choice to be guided (unasked, true, false, and nothing shown until true), a lesson running step by step and being remembered when it ends, skip, lessons waiting their turn and not being asked for twice, leaving a screen dropping its lessons even the one showing without marking them seen, the host forbidding the tour, reset, other storage keys, missing messages showing their key, the circle round an element clipped to the screen and which half the card takes, and the overlay itself against a stand-in page: the ring and card placement, following a moving element, staying last on the page, buttons driving the tour and reporting their action, and removal on destroy. When the controls component is installed next to it, its real `panel` and `button` are also used to build the card. The Apple check compiles and runs `tests/apple/main.swift` for macOS, refusing faulty lesson files and replaying a 15 step script and 7 ring geometries identical to the TypeScript output, then type-checks the Swift (with the theme and controls Swift) for the iOS simulator. The Android check replays the same script (`tests/android/Expected.kt`); kotlinc was not available where this was written, so it has not been run, and `TourOverlay.kt`, `LessonsJson.kt` need the Android and Compose libraries and are compiled by the application's Gradle build. Pixels are not compared.

- `node --test tests/web.test.ts` (web, required-local; tools: node 26.5.0)
- `python3 tests/native.py apple` (apple, platform; tools: python3 3.12.8, swiftc 6.4.2)
- `python3 tests/native.py android` (android, platform; tools: python3 3.12.8, kotlinc 2.2.0, java 26.0.1)

## Scenarios and presentation
On first use the application asks whether the person is a beginner; yes turns guidance on and the home lesson shows its steps one at a time, each ringing a different button, until Got it; the same lesson never shows again. At a table the first time something happens (a first bet, the first community cards) a short lesson opens, play is held for everyone while it is open, and it goes if the person leaves the screen. A "reset hints" button calls `reset` and every lesson shows again.

## Updates and removal
Patch updates replace files only. The component keeps device flags only (one per lesson and one for guidance, under keys the application chooses); removal deletes its files and the application's imports, and leaves those flags in the device's storage (the application may remove them).
