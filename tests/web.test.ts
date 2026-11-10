import assert from "node:assert/strict";
import test from "node:test";
import { existsSync, readFileSync } from "node:fs";
import { FakeElement, installFakeDocument } from "./fake-dom.ts";
import {
  DEFAULT_KEYS, cardSide, createTour, parseEnabled, parseLessons, ringFor, validateLessons,
} from "../implementation/web/tour-model.ts";
import type { LessonSet, TourStorage, TourView } from "../implementation/web/tour-model.ts";
import { mountTour } from "../implementation/web/tour-view.ts";
import type { ControlsLike } from "../implementation/web/tour-view.ts";
import { build as buildFixtures, buildKotlin } from "./make-fixtures.ts";
import { memoryStorage, sampleTour } from "../examples/consumer.ts";

installFakeDocument();
const el = (x: unknown) => x as unknown as FakeElement;
const read = (name: string) => readFileSync(new URL(`fixtures/${name}`, import.meta.url), "utf8");
const lessonText = read("lessons.json");
const messages: Record<string, string> = JSON.parse(read("messages.json"));
const lookup = (key: string) => (Object.hasOwn(messages, key) ? messages[key] : key);

function setup(extra: { allowed?: () => boolean; enabled?: boolean | null } = {}) {
  const storage = memoryStorage();
  if (extra.enabled !== null) storage.setItem("beginner", extra.enabled === false ? "false" : "true");
  const tour = createTour({ lessons: parseLessons(lessonText), storage, translate: lookup, allowed: extra.allowed });
  const events: (TourView | null)[] = [];
  tour.onChange((v) => events.push(v));
  return { storage, tour, events };
}

test("the sample lessons are valid and every fault is reported", () => {
  assert.deepEqual(validateLessons(JSON.parse(lessonText)), []);
  const bad = (change: (s: any) => void) => { const s = JSON.parse(lessonText); change(s); return validateLessons(s).join("; "); };
  assert.deepEqual(validateLessons(null), ["lessons file must be an object"]);
  assert.match(bad((s) => { s.format = 2; }), /format/);
  assert.match(bad((s) => { s.lessons = []; }), /at least one lesson/);
  assert.match(bad((s) => { s.lessons[0].id = "Welcome"; }), /id must be/);
  assert.match(bad((s) => { s.lessons[1].id = "welcome"; }), /used twice/);
  assert.match(bad((s) => { s.lessons[0].screen = "Home Page"; }), /screen must be/);
  assert.match(bad((s) => { s.lessons[0].steps = []; }), /at least one step/);
  assert.match(bad((s) => { s.lessons[0].steps[0].title = ""; }), /title key/);
  assert.match(bad((s) => { delete s.lessons[0].steps[0].text; }), /text key/);
  assert.match(bad((s) => { s.lessons[0].steps[0].anchor = "a b"; }), /anchor/);
  assert.throws(() => parseLessons("{"), /not JSON/);
  assert.throws(() => parseLessons('{"format":1,"lessons":[]}'), /at least one lesson/);
  assert.throws(() => createTour({ lessons: { format: 1, lessons: [] } as LessonSet, storage: memoryStorage(), translate: lookup }), /at least one lesson/);
});

test("being guided is a choice that starts unasked", () => {
  assert.deepEqual(["true", "false"].map(parseEnabled), [true, false]);
  assert.deepEqual(["yes", "no", "1", "0", "TRUE", " true", "maybe", ""].map(parseEnabled), [null, null, null, null, null, null, null, null]);
  assert.deepEqual([null, "", "maybe"].map(parseEnabled), [null, null, null]);
  const { tour, storage } = setup({ enabled: null });
  assert.equal(tour.enabled(), null);
  assert.equal(tour.want("welcome"), false, "nothing is shown until the person has said yes");
  tour.setEnabled(true);
  assert.equal(storage.getItem("beginner"), "true");
  assert.equal(tour.want("welcome"), true);
  tour.setEnabled(false);
  assert.equal(storage.getItem("beginner"), "false");
  assert.equal(tour.current(), null, "saying no closes what is open");
  assert.equal(tour.holding(), false);
  assert.equal(setup({ enabled: false }).tour.want("welcome"), false);
});

test("a lesson shows step by step, ends on the last step and is remembered", () => {
  const { tour, storage, events } = setup();
  assert.equal(tour.want("welcome"), true);
  assert.deepEqual(tour.current(), { lessonId: "welcome", step: 0, count: 3, title: "Welcome", text: "The menu lists everything you can open.", anchor: "menu", first: true, last: false });
  assert.equal(tour.holding(), true, "play is held while a lesson is open");
  tour.next();
  assert.equal(tour.current()?.anchor, "search");
  tour.next();
  assert.deepEqual([tour.current()?.step, tour.current()?.last], [2, true]);
  assert.equal(storage.getItem("tut.welcome"), null, "not yet remembered");
  tour.next();
  assert.equal(tour.current(), null);
  assert.equal(storage.getItem("tut.welcome"), "1");
  assert.equal(tour.seen("welcome"), true);
  assert.equal(tour.holding(), false);
  assert.deepEqual(events.map((e) => e && `${e.lessonId}:${e.step}`), ["welcome:0", "welcome:1", "welcome:2", null]);
  assert.equal(tour.want("welcome"), false, "shown once ever");
  tour.next();
  assert.equal(events.length, 4, "next with nothing open does nothing");
});

test("skip closes a lesson for good from any step", () => {
  const { tour, storage } = setup();
  tour.want("welcome");
  tour.next();
  tour.skip();
  assert.equal(tour.current(), null);
  assert.equal(storage.getItem("tut.welcome"), "1");
  tour.skip();
  assert.equal(tour.current(), null);
});

test("lessons wait their turn and are not asked for twice", () => {
  const { tour, events } = setup();
  assert.equal(tour.want("welcome"), true);
  assert.equal(tour.want("first-share"), true);
  assert.equal(tour.want("first-share"), false, "already waiting");
  assert.equal(tour.want("welcome"), false);
  assert.equal(tour.want("no-such-lesson"), false);
  assert.deepEqual(tour.queued(), ["welcome", "first-share"]);
  assert.equal(tour.current()?.lessonId, "welcome");
  tour.skip();
  assert.equal(tour.current()?.lessonId, "first-share");
  assert.equal(tour.current()?.title, "Sharing");
  assert.equal(events.filter((e) => e === null).length, 0, "the next lesson opens straight away");
  tour.next();
  assert.equal(tour.current(), null);
});

test("leaving a screen drops its lessons, even the one showing; others stay", () => {
  const { tour, events } = setup();
  tour.want("welcome");
  tour.next();
  tour.want("first-share");
  tour.screenChanged("home");
  assert.equal(tour.current()?.step, 1, "still on its own screen");
  tour.screenChanged("editor");
  assert.equal(tour.current()?.lessonId, "first-share", "the home lesson went; the screenless one stays");
  assert.equal(tour.current()?.step, 0, "and starts at its first step");
  assert.deepEqual(tour.queued(), ["first-share"]);
  tour.screenChanged("editor");
  const count = events.length;
  tour.screenChanged("editor");
  assert.equal(events.length, count, "no change, no news");
  tour.want("editing");
  assert.deepEqual(tour.queued(), ["first-share", "editing"]);
  tour.skip();
  assert.equal(tour.current()?.lessonId, "editing");
  tour.screenChanged("home");
  assert.equal(tour.current(), null, "the last lesson went with its screen");
  assert.equal(tour.seen("editing"), false, "a dropped lesson is not marked seen, so it can come again");
});

test("a lesson dropped when the one before it ends leaves nothing behind", () => {
  const { tour } = setup();
  tour.want("first-share");
  tour.want("editing");
  tour.next();
  assert.equal(tour.current()?.lessonId, "editing", "the screenless lesson ended, the editor lesson is next");
  tour.screenChanged("home");
  assert.deepEqual(tour.queued(), [], "the editor lesson went with its screen");
  assert.equal(tour.current(), null);
});

test("the host can forbid the tour, which also clears what is waiting", () => {
  let allowed = true;
  const { tour } = setup({ allowed: () => allowed });
  assert.equal(tour.want("welcome"), true);
  allowed = false;
  assert.equal(tour.want("first-share"), false);
  tour.screenChanged("home");
  assert.equal(tour.current(), null);
  assert.deepEqual(tour.queued(), []);
  allowed = true;
  assert.equal(tour.want("welcome"), true, "forbidden lessons were not marked seen");
});

test("reset shows every lesson again and turns guidance on", () => {
  const { tour, storage } = setup({ enabled: false });
  storage.setItem("tut.welcome", "1");
  storage.setItem("tut.editing", "1");
  storage.setItem("unrelated", "keep");
  tour.reset();
  assert.equal(tour.enabled(), true);
  assert.equal(tour.seen("welcome") || tour.seen("editing"), false);
  assert.equal(storage.getItem("unrelated"), "keep");
  assert.equal(tour.want("welcome"), true);
});

test("keys can follow another application's names", () => {
  const storage = memoryStorage();
  storage.setItem("guided", "true");
  const tour = createTour({ lessons: parseLessons(lessonText), storage, translate: lookup, keys: { prefix: "seen-", enabled: "guided" } });
  assert.equal(tour.enabled(), true);
  tour.want("first-share");
  tour.next();
  assert.equal(storage.getItem("seen-first-share"), "1");
  assert.deepEqual(DEFAULT_KEYS, { prefix: "tut.", enabled: "beginner" });
});

test("a missing message shows its key, so a gap is visible", () => {
  const storage = memoryStorage();
  storage.setItem("beginner", "true");
  const tour = createTour({ lessons: parseLessons(lessonText), storage, translate: (k) => (k === "share_title" ? "Teilen" : lookup(k === "share_button" ? "missing_key" : k)) });
  tour.want("first-share");
  assert.deepEqual([tour.current()?.title, tour.current()?.text], ["Teilen", "missing_key"]);
});

test("the circle round an element is clipped to the screen and sized to it", () => {
  const view = { width: 400, height: 800 };
  assert.deepEqual(ringFor({ left: 100, top: 100, right: 200, bottom: 160 }, view), { x: 150, y: 130, r: Math.hypot(100, 60) / 2 + 8 });
  assert.equal(ringFor({ left: 100, top: 100, right: 110, bottom: 110 }, view)?.r, 28, "never smaller than 28");
  assert.deepEqual(ringFor({ left: -50, top: -50, right: 50, bottom: 50 }, view), { x: 25, y: 25, r: Math.hypot(50, 50) / 2 + 8 }, "clipped at the corner");
  assert.equal(ringFor({ left: 500, top: 0, right: 600, bottom: 50 }, view), null, "off the right edge");
  assert.equal(ringFor({ left: 0, top: 900, right: 50, bottom: 950 }, view), null, "below the screen");
  assert.equal(ringFor({ left: 10, top: 10, right: 10, bottom: 50 }, view), null, "no width");
  assert.equal(cardSide({ x: 10, y: 100, r: 30 }, 800), "below", "a circle in the top half puts the card below");
  assert.equal(cardSide({ x: 10, y: 600, r: 30 }, 800), "above");
  assert.equal(cardSide(null, 800), "below");
  assert.equal(cardSide({ x: 0, y: 400, r: 1 }, 800), "above", "exactly half way counts as the bottom half");
});

// ---- The overlay ----

const ui: ControlsLike = {
  panel: (o, ...children) => { const p = new FakeElement("div"); p.className = `panel ${o.className ?? ""}`; if (o.title) { const t = new FakeElement("div"); t.className = "title"; t.append(o.title); p.append(t); } for (const c of children) if (c) p.append(c as FakeElement | string); return p as unknown as HTMLElement; },
  button: (o) => { const b = new FakeElement("button"); b.className = `btn ${o.variant ?? "primary"} ${o.attrs?.class ?? ""}`; b.append(o.label); b.addEventListener("click", o.onClick); return b as unknown as HTMLElement; },
};

function mounted(rects: Record<string, { left: number; top: number; right: number; bottom: number } | null> = {}) {
  const body = new FakeElement("body");
  const frames: (() => void)[] = [];
  const actions: string[] = [];
  const { tour, storage, events } = setup();
  const view = mountTour({
    tour, ui, translate: lookup, parent: body as never, viewport: () => ({ width: 400, height: 800 }), onAction: (a) => actions.push(a),
    anchorRect: (a) => rects[a] ?? null, requestFrame: (fn) => frames.push(fn), cancelFrame: () => {},
  });
  return { body, tour, storage, view, frames, actions, events };
}

test("the overlay appears with a lesson, rings the element and puts the card on the other half", () => {
  const m = mounted({ menu: { left: 20, top: 40, right: 120, bottom: 100 }, search: { left: 20, top: 700, right: 380, bottom: 760 } });
  assert.equal(m.view.element(), null, "nothing open, nothing drawn");
  m.tour.want("welcome");
  const overlay = el(m.view.element());
  assert.equal(overlay.dataset.id, "welcome");
  assert.equal(m.body.children.length, 1);
  const spot = overlay.byClass("gspot")[0];
  assert.equal(spot.style.left, `${70 - (Math.hypot(100, 60) / 2 + 8)}px`);
  assert.ok(overlay.byClass("gcard")[0].classes().includes("below"), "the ring is in the top half, so the card is below");
  assert.equal(overlay.byClass("title")[0].text, "Welcome");
  assert.equal(overlay.byClass("gtext")[0].text, "The menu lists everything you can open.");
  assert.deepEqual(overlay.byClass("gpages")[0].children.map((c) => (c as FakeElement).className), ["on", "", ""]);
  assert.deepEqual(overlay.byClass("gbuttons")[0].find((e) => e.tagName === "button").map((b) => b.text), ["Skip", "Next"]);
  m.tour.next();
  const second = el(m.view.element());
  assert.ok(second.byClass("gcard")[0].classes().includes("above"), "the second ring is in the bottom half");
  assert.deepEqual(second.byClass("gpages")[0].children.map((c) => (c as FakeElement).className), ["", "on", ""]);
  assert.equal(m.body.children.length, 1, "one overlay at a time");
});

test("with no element on the page the whole screen is dimmed", () => {
  const m = mounted();
  m.tour.want("welcome");
  const overlay = el(m.view.element());
  assert.ok(overlay.classes().includes("nospot"));
  assert.ok(overlay.byClass("gcard")[0].classes().includes("below"));
});

test("the circle follows its element and the overlay stays last on the page", () => {
  const rects: Record<string, { left: number; top: number; right: number; bottom: number } | null> = { menu: { left: 20, top: 40, right: 120, bottom: 100 } };
  const m = mounted(rects);
  m.tour.want("welcome");
  const overlay = el(m.view.element());
  const spot = overlay.byClass("gspot")[0];
  const before = spot.style.left;
  rects.menu = { left: 220, top: 40, right: 320, bottom: 100 };
  m.frames.pop()!();
  assert.notEqual(spot.style.left, before, "the circle moved with the element");
  const later = new FakeElement("div");
  m.body.append(later);
  m.frames.pop()!();
  assert.equal(m.body.lastElementChild, overlay, "brought back over the banner added later");
  rects.menu = null;
  m.frames.pop()!();
  assert.ok(overlay.classes().includes("nospot"), "the element left the page");
});

test("buttons drive the tour, report the action, and the overlay closes at the end", () => {
  const m = mounted();
  m.tour.want("editing");
  m.tour.screenChanged("editor");
  const button = (label: string) => el(m.view.element()).find((e) => e.tagName === "button" && e.text === label)[0];
  button("Next").click();
  assert.equal(m.tour.current()?.step, 1);
  assert.equal(button("Skip"), undefined, "no Skip on the last step");
  button("Got it").click();
  assert.equal(m.tour.current(), null);
  assert.equal(m.view.element(), null);
  assert.equal(m.body.children.length, 0);
  assert.deepEqual(m.actions, ["next", "done"]);
  assert.equal(m.storage.getItem("tut.editing"), "1");
  m.tour.want("welcome");
  button("Skip").click();
  assert.deepEqual(m.actions, ["next", "done", "skip"]);
  assert.equal(m.view.element(), null);
});

test("an overlay for a lesson already open is drawn at once, and destroy removes it", () => {
  const storage = memoryStorage();
  storage.setItem("beginner", "true");
  const tour = createTour({ lessons: parseLessons(lessonText), storage, translate: lookup });
  tour.want("first-share");
  const body = new FakeElement("body");
  const view = mountTour({ tour, ui, translate: lookup, parent: body as never, viewport: () => ({ width: 400, height: 800 }), anchorRect: () => null, requestFrame: () => 0, cancelFrame: () => {} });
  assert.equal(body.children.length, 1);
  view.destroy();
  assert.equal(body.children.length, 0);
  tour.skip();
  tour.want("welcome");
  assert.equal(body.children.length, 0, "a destroyed overlay stays gone");
});

test("the real controls component works as the card's builders, when it is next to this one", () => {
  const candidates = ["../../controls/implementation/web/controls.ts", "../../controls/web/controls.ts"];
  const found = candidates.map((p) => new URL(p, import.meta.url)).find((u) => existsSync(u));
  if (!found) return;
  return import(found.href).then((controls) => {
    const body = new FakeElement("body");
    const { tour } = setup();
    // controls' builders use the page's document; the fake gives them elements that act alike.
    (globalThis as any).document.createElementNS = (_: string, tag: string) => new FakeElement(tag);
    const view = mountTour({ tour, ui: controls, translate: lookup, parent: body as never, viewport: () => ({ width: 400, height: 800 }), anchorRect: () => null, requestFrame: () => 0, cancelFrame: () => {} });
    tour.want("welcome");
    const overlay = el(view.element());
    assert.ok(overlay.byClass("panel").length >= 1 && overlay.find((e) => e.tagName === "button").length === 2);
    overlay.find((e) => e.tagName === "button" && e.text === "Next")[0].click();
    assert.equal(tour.current()?.step, 1);
    view.destroy();
  });
});

test("the native fixtures are the TypeScript model", () => {
  assert.equal(read("tour.json"), buildFixtures());
  assert.equal(readFileSync(new URL("android/Expected.kt", import.meta.url), "utf8"), buildKotlin());
});

test("a consumer runs a sample tour without any application", () => {
  const storage = memoryStorage();
  storage.setItem("beginner", "true");
  const tour = sampleTour(storage);
  tour.want("first-share");
  assert.equal(tour.current()?.text, "Share sends a copy to a friend.");
  tour.next();
  assert.deepEqual([...storage.data.keys()].sort(), ["beginner", "tut.first-share"]);
});

test("the OpenRPC interface describes the lessons file, the tour and the exported functions", async () => {
  const doc = JSON.parse(readFileSync(new URL("../interfaces/guided-tour.json", import.meta.url), "utf8"));
  assert.equal(doc.openrpc, "1.3.2");
  assert.deepEqual([doc.info.title, doc.info.version], ["ae/guided-tour", "1.0.0"]);
  const { Lesson, Step, TourKeys, TourView: viewShape } = doc.components.schemas;
  const id = new RegExp(Lesson.properties.id.pattern), anchor = new RegExp(Step.properties.anchor.pattern);
  for (const lesson of parseLessons(lessonText).lessons) {
    assert.match(lesson.id, id);
    for (const step of lesson.steps) assert.match(step.anchor, anchor);
  }
  for (const bad of ["Welcome", "1st", "a b"]) {
    assert.doesNotMatch(bad, id);
    assert.ok(validateLessons({ format: 1, lessons: [{ id: bad, steps: [{ title: "t", text: "x", anchor: "a" }] }] }).length > 0, bad);
  }
  assert.deepEqual({ prefix: TourKeys.properties.prefix.default, enabled: TourKeys.properties.enabled.default }, DEFAULT_KEYS);
  const { tour } = setup();
  tour.want("welcome");
  assert.deepEqual(Object.keys(tour.current()!).sort(), [...viewShape.required].sort());
  const web: Record<string, unknown> = { ...(await import("../implementation/web/tour-model.ts")), ...(await import("../implementation/web/tour-view.ts")) };
  for (const method of doc.methods) {
    const [owner, member] = method.name.split(".");
    if (member) assert.equal(typeof (tour as unknown as Record<string, unknown>)[member], "function", method.name);
    else assert.equal(typeof web[owner], "function", method.name);
  }
});
