// A guided tour as a mechanism: lessons made of steps, each step ringing one element of the screen;
// shown once ever each, one after another; the screen they belong to; play held while one is open;
// progress and the person's choice to be guided remembered on the device. What the lessons say, and
// which element each step rings, belongs to the application (lessons are data); nothing here knows
// any application. Pure and shared by every platform (the user interface is in tour-view.ts).

// A step names its heading and sentence by translation key, and the element it rings by anchor name.
export type Step = { title: string; text: string; anchor: string };
export type Lesson = { id: string; /** the screen it belongs to; it goes when that screen does */ screen?: string | null; steps: Step[] };
export type LessonSet = { format: 1; lessons: Lesson[] };

export type TourStorage = { getItem(key: string): string | null; setItem(key: string, value: string): void; removeItem(key: string): void };
export type TourKeys = { /** progress key is prefix + lesson id */ prefix: string; enabled: string };
export type Translate = (key: string) => string;

export const DEFAULT_KEYS: TourKeys = { prefix: "tut.", enabled: "beginner" };
const ID = /^[a-z][a-z0-9-]{0,47}$/;
const ANCHOR = /^[A-Za-z][A-Za-z0-9_-]{0,47}$/;
const SCREEN = /^[a-z][a-z0-9-]{0,47}$/;

// Returns the list of problems; empty means the lessons are usable.
export function validateLessons(set: unknown): string[] {
  const problems: string[] = [];
  const s = set as LessonSet;
  if (typeof s !== "object" || s === null || Array.isArray(s)) return ["lessons file must be an object"];
  if (s.format !== 1) problems.push("format must be 1");
  if (!Array.isArray(s.lessons) || !s.lessons.length) return [...problems, "lessons must list at least one lesson"];
  const seen = new Set<string>();
  for (const [i, lesson] of s.lessons.entries()) {
    const where = `lesson ${i + 1}`;
    if (typeof lesson?.id !== "string" || !ID.test(lesson.id)) problems.push(`${where}: id must be lower-case letters, digits and hyphens`);
    else if (seen.has(lesson.id)) problems.push(`${where}: id ${lesson.id} is used twice`);
    else seen.add(lesson.id);
    if (lesson?.screen != null && (typeof lesson.screen !== "string" || !SCREEN.test(lesson.screen))) problems.push(`${where}: screen must be lower-case letters, digits and hyphens`);
    if (!Array.isArray(lesson?.steps) || !lesson.steps.length) { problems.push(`${where}: steps must list at least one step`); continue; }
    for (const [j, step] of lesson.steps.entries()) {
      if (typeof step?.title !== "string" || !step.title) problems.push(`${where} step ${j + 1}: title key is required`);
      if (typeof step?.text !== "string" || !step.text) problems.push(`${where} step ${j + 1}: text key is required`);
      if (typeof step?.anchor !== "string" || !ANCHOR.test(step.anchor)) problems.push(`${where} step ${j + 1}: anchor must be letters, digits, hyphens and underscores`);
    }
  }
  return problems;
}

export function parseLessons(text: string): LessonSet {
  let value: unknown;
  try { value = JSON.parse(text); } catch (e) { throw new Error(`lessons are not JSON: ${(e as Error).message}`); }
  const problems = validateLessons(value);
  if (problems.length) throw new Error(problems.join("; "));
  return value as LessonSet;
}

// "true" means guided and "false" means not; anything else means not yet asked.
export function parseEnabled(raw: string | null): boolean | null {
  if (raw === "true") return true;
  if (raw === "false") return false;
  return null;
}

// ---- Highlighting ---------------------------------------------------------------------------

export type Rect = { left: number; top: number; right: number; bottom: number };
export type Circle = { x: number; y: number; r: number };

// The circle round an element, clipped to the screen; null when the element is not on screen.
export function ringFor(rect: Rect, viewport: { width: number; height: number }): Circle | null {
  const left = Math.max(0, rect.left), right = Math.min(viewport.width, rect.right);
  const top = Math.max(0, rect.top), bottom = Math.min(viewport.height, rect.bottom);
  if (right <= left || bottom <= top) return null;
  return { x: (left + right) / 2, y: (top + bottom) / 2, r: Math.max(28, Math.hypot(right - left, bottom - top) / 2 + 8) };
}

// The text card takes the half of the screen the circle is not in.
export function cardSide(circle: Circle | null, viewportHeight: number): "below" | "above" {
  return !circle || circle.y < viewportHeight / 2 ? "below" : "above";
}

// ---- The tour -------------------------------------------------------------------------------

export type TourView = {
  lessonId: string;
  step: number;
  count: number;
  title: string;
  text: string;
  anchor: string;
  first: boolean;
  last: boolean;
};

export type TourOptions = {
  lessons: LessonSet;
  storage: TourStorage;
  /** turns a translation key into text (the language component's lookup over the current messages) */
  translate: Translate;
  keys?: Partial<TourKeys>;
  /** false for now means no lesson is wanted or kept, such as on a shared display */
  allowed?: () => boolean;
};

export type Tour = {
  /** whether the person wants to be guided: true, false, or null if not yet asked */
  enabled(): boolean | null;
  setEnabled(on: boolean): void;
  seen(id: string): boolean;
  /** ask for a lesson: it is shown once ever, after any already waiting; returns whether it was queued */
  want(id: string): boolean;
  /** the step on show, or null */
  current(): TourView | null;
  next(): void;
  /** closes the lesson on show for good, without finishing its steps */
  skip(): void;
  /** the screen changed: lessons that belong to another screen are dropped, even the one showing */
  screenChanged(screen: string): void;
  /** every lesson shows again, and guidance is on */
  reset(): void;
  /** true while a lesson is open: the host holds play for everyone */
  holding(): boolean;
  /** told whenever the step on show changes, a lesson opens, or the last one closes */
  onChange(listener: (view: TourView | null) => void): () => void;
  queued(): string[];
};

export function createTour(o: TourOptions): Tour {
  const keys: TourKeys = { ...DEFAULT_KEYS, ...o.keys };
  const byId = new Map(o.lessons.lessons.map((l) => [l.id, l]));
  const problems = validateLessons(o.lessons);
  if (problems.length) throw new Error(problems.join("; "));
  const queue: string[] = [];
  const listeners = new Set<(view: TourView | null) => void>();
  let step = 0;
  let lastSignature = "none";
  const allowed = () => (o.allowed ? o.allowed() : true);

  const enabled = () => parseEnabled(o.storage.getItem(keys.enabled));
  const seen = (id: string) => o.storage.getItem(keys.prefix + id) !== null;

  const current = (): TourView | null => {
    const lesson = queue.length ? byId.get(queue[0]) : undefined;
    if (!lesson) return null;
    const i = Math.min(step, lesson.steps.length - 1);
    const s = lesson.steps[i];
    return { lessonId: lesson.id, step: i, count: lesson.steps.length, title: o.translate(s.title), text: o.translate(s.text), anchor: s.anchor, first: i === 0, last: i === lesson.steps.length - 1 };
  };
  const notify = () => {
    const view = current();
    const signature = view ? `${view.lessonId}|${view.step}` : "none";
    if (signature === lastSignature) return;
    lastSignature = signature;
    for (const l of [...listeners]) l(view);
  };
  const finish = () => {
    const id = queue.shift();
    if (id !== undefined) o.storage.setItem(keys.prefix + id, "1");
    step = 0;
    notify();
  };

  return {
    enabled,
    setEnabled(on) {
      o.storage.setItem(keys.enabled, on ? "true" : "false");
      if (!on) { queue.length = 0; step = 0; notify(); }
    },
    seen,
    want(id) {
      if (!byId.has(id) || !allowed() || enabled() !== true || seen(id) || queue.includes(id)) return false;
      queue.push(id);
      notify();
      return true;
    },
    current,
    next() {
      const view = current();
      if (!view) return;
      if (view.last) finish(); else { step += 1; notify(); }
    },
    skip() { if (queue.length) finish(); },
    screenChanged(screen) {
      if (!allowed()) { queue.length = 0; step = 0; notify(); return; }
      for (let i = queue.length - 1; i >= 0; i--) {
        const own = byId.get(queue[i])?.screen;
        if (own && own !== screen) {
          queue.splice(i, 1);
          if (i === 0) step = 0;
        }
      }
      notify();
    },
    reset() {
      for (const id of byId.keys()) o.storage.removeItem(keys.prefix + id);
      o.storage.setItem(keys.enabled, "true");
      queue.length = 0;
      step = 0;
      notify();
    },
    holding: () => queue.length > 0,
    onChange(listener) {
      listeners.add(listener);
      return () => void listeners.delete(listener);
    },
    queued: () => [...queue],
  };
}
