// Draws the tour over a page: the screen dimmed except a circle of light round the step's element,
// and a card on the other half with the heading, the sentence, progress dots and Skip and Next (Got
// it at the last step). The card is built with the controls component's panel and button.
import { cardSide, ringFor } from "./tour-model.ts";
import type { Circle, Rect, Tour, TourView, Translate } from "./tour-model.ts";

type Child = Node | string | null | undefined | false;

// The parts of the controls component the tour uses; the real `panel` and `button` fit.
export type ControlsLike = {
  panel(o: { title?: string; active?: boolean; className?: string; attrs?: Record<string, string> }, ...children: Child[]): HTMLElement;
  button(o: { label: string; onClick: () => void; variant?: "primary" | "ghost" | "link"; attrs?: Record<string, string> }): HTMLElement;
};

export type TourViewOptions = {
  tour: Tour;
  ui: ControlsLike;
  translate: Translate;
  /** translation keys of the three buttons */
  strings?: { next: string; skip: string; done: string };
  /** where the element marked with this anchor name is, in viewport pixels; null if it is not on the page */
  anchorRect?: (anchor: string) => Rect | null;
  viewport?: () => { width: number; height: number };
  /** called with each tap on a button, such as to play a click */
  onAction?: (action: "next" | "skip" | "done") => void;
  /** where the overlay goes; the page body by default */
  parent?: { append(node: Node): void; lastElementChild: Element | null };
  requestFrame?: (fn: () => void) => number;
  cancelFrame?: (id: number) => void;
};

export const DEFAULT_STRINGS = { next: "tour_next", skip: "tour_skip", done: "tour_done" };

function make<K extends keyof HTMLElementTagNameMap>(tag: K, className: string, ...children: Child[]): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  node.className = className;
  for (const c of children) if (c) node.append(c);
  return node;
}

// The page for a flat element marked data-guide="name", as the recipe marks them.
export function domAnchorRect(anchor: string): Rect | null {
  const el = document.querySelector(`[data-guide="${anchor}"]`);
  if (!el) return null;
  const b = el.getBoundingClientRect();
  return { left: b.left, top: b.top, right: b.right, bottom: b.bottom };
}

export type MountedTour = { destroy(): void; element(): HTMLElement | null };

// Shows the tour whenever a lesson is open and keeps the circle on its element as the page changes.
export function mountTour(o: TourViewOptions): MountedTour {
  const strings = o.strings ?? DEFAULT_STRINGS;
  const anchorRect = o.anchorRect ?? domAnchorRect;
  const viewport = o.viewport ?? (() => ({ width: (globalThis as any).innerWidth, height: (globalThis as any).innerHeight }));
  const frame = o.requestFrame ?? ((fn) => (globalThis as any).requestAnimationFrame(fn));
  const cancel = o.cancelFrame ?? ((id) => (globalThis as any).cancelAnimationFrame(id));
  const parent = o.parent ?? (document as any).body;
  let overlay: HTMLElement | null = null;
  let follow = 0;

  const close = () => {
    cancel(follow);
    overlay?.remove();
    overlay = null;
  };

  const open = (view: TourView) => {
    close();
    const spot = make("div", "gspot");
    const dots = view.count > 1 ? make("div", "gpages", ...Array.from({ length: view.count }, (_, i) => make("i", i === view.step ? "on" : ""))) : null;
    const buttons = make("div", "row gbuttons",
      !view.last ? o.ui.button({ label: o.translate(strings.skip), variant: "link", onClick: () => { o.onAction?.("skip"); o.tour.skip(); } }) : null,
      o.ui.button({ label: o.translate(view.last ? strings.done : strings.next), onClick: () => { o.onAction?.(view.last ? "done" : "next"); o.tour.next(); }, attrs: { class: "grow" } }));
    const card = o.ui.panel({ title: view.title, className: "gcard" }, make("div", "gtext", view.text), dots, buttons);
    const node = make("div", "guide", spot, card);
    node.dataset.id = view.lessonId;
    overlay = node;
    parent.append(node);
    let previous = "";
    const place = () => {
      const rect = anchorRect(view.anchor);
      const circle: Circle | null = rect ? ringFor(rect, viewport()) : null;
      const key = circle ? `${circle.x}|${circle.y}|${circle.r}` : "none";
      if (key !== previous) {
        previous = key;
        node.classList.toggle("nospot", !circle);
        if (circle) Object.assign(spot.style, { left: `${circle.x - circle.r}px`, top: `${circle.y - circle.r}px`, width: `${2 * circle.r}px`, height: `${2 * circle.r}px` });
        const below = cardSide(circle, viewport().height) === "below";
        card.classList.toggle("below", below);
        card.classList.toggle("above", !below);
      }
      // Kept last on the page, so it stays over anything added later.
      if (parent.lastElementChild !== node) parent.append(node);
      follow = frame(place);
    };
    place();
  };

  const stop = o.tour.onChange((view) => (view ? open(view) : close()));
  const now = o.tour.current();
  if (now) open(now);
  return { destroy() { stop(); close(); }, element: () => overlay };
}
