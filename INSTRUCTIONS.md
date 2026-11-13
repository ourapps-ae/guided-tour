# Guided tour instructions

## For the agent
Select `ourapps-ae/guided-tour` when the recipe offers lessons (the lessons question); connect `controls` to the controls component, `preferences` to the preferences component and `language` to the translations component's `language` output. The lessons themselves, their translation keys and the element names come from the recipe; do not write lessons here.

- Select package `ourapps-ae/guided-tour` version `0.5.0`.
- No installer settings.
- Connect the provided `guided-tour` (ae/guided-tour 1.0.0, OpenRPC 1.3.2 document `interfaces/guided-tour.json`; its `LessonSet` schema is the shape of the lessons file) to the consumer that needs it.
- Supply `controls` (ae/controls 1.0.0) from the component that provides it.
- Supply `preferences` (ae/preferences 1.0.0) from the component that provides it.
- Supply `language` (ae/language 1.0.0) from the component that provides it.
- No accounts or keys are needed.

## For the developer
Write a lessons file and its messages (one title key and one text key per step) in every language the application supports. Mark the elements to ring with `data-guide="name"` (web), `.tourAnchor("name")` (Apple) or `Modifier.tourAnchor("name")` (Android). Pass the storage keys the application already uses for its hints if it has any. Ask the guidance question yourself and call `setEnabled` with the answer.

## How to check
From the component directory:

- `node --test tests/web.test.ts` (web, required-local; tools: node 26.5)
- `python3 tests/native.py apple` (apple, platform; tools: python3 3.12, swiftc 6.4)
- `python3 tests/native.py android` (android, platform; tools: python3 3.12, kotlinc 2.2, java 26.0)
- `python3 -m aepm review <digest> --store STORE --policy POLICY --trusted --allow-network` checks an archive fetched with `python3 -m aepm fetch ourapps-ae/guided-tour@VERSION --store STORE --from https://ourapps.app` and runs its suites.
