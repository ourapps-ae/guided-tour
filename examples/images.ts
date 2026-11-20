// The package's example images: the tour from createTour and mountTour over a small sample page, with the sample lessons
// of tests/fixtures. The card is built by panel and button functions that give the controls component's class names, so
// the controls stylesheet draws it as it does in an application. Rendered by classes/render_images.py in headless Chrome.
import lessons from "../tests/fixtures/lessons.json" with { type: "json" };
import messages from "../tests/fixtures/messages.json" with { type: "json" };
import { createTour, parseLessons } from "../implementation/web/tour-model.ts";
import { mountTour } from "../implementation/web/tour-view.ts";
import type { ControlsLike } from "../implementation/web/tour-view.ts";

type Scene = { name: string; caption: string; width: number; height: number; look?: string; render: (root: HTMLElement) => void };

export const uses = ["controls"];

const translate = (key: string) => (messages as Record<string, string>)[key] ?? key;

function element(tag: string, className: string, ...children: (Node | string | null | undefined | false)[]): HTMLElement {
  const node = document.createElement(tag);
  node.className = className;
  for (const child of children) if (child) node.append(child);
  return node;
}

const ui: ControlsLike = {
  panel: (o, ...children) => element("div", ["panel", o.className ?? ""].join(" "), o.title ? element("div", "title", o.title) : null, ...children),
  button: (o) => {
    const node = element("button", ["btn", o.variant && o.variant !== "primary" ? o.variant : "", o.attrs?.class ?? ""].filter(Boolean).join(" "), o.label);
    node.addEventListener("click", o.onClick);
    return node;
  },
};

// A plain application page whose parts carry the anchors the sample lessons name.
function page(root: HTMLElement): void {
  const bar = element("div", "");
  Object.assign(bar.style, { display: "flex", alignItems: "center", gap: "16px", padding: "18px 24px", borderBottom: "1px solid var(--edge)" });
  const part = (anchor: string, text: string, grow = false) => {
    const node = element("div", "", text);
    node.dataset.guide = anchor;
    Object.assign(node.style, { padding: "10px 16px", borderRadius: "999px", background: "var(--surface)", border: "1px solid var(--edge)", flex: grow ? "1" : "none" });
    return node;
  };
  bar.append(part("menu", "☰ Menu"), part("search", "Search recipes"), element("div", ""), part("profile", "Ana"));
  (bar.children[2] as HTMLElement).style.flex = "1";
  const body = element("div", "");
  Object.assign(body.style, { display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "16px", padding: "24px" });
  for (const title of ["Recipes", "Shopping list", "Week plan", "Pantry", "Favourites", "Shared"]) {
    const card = element("div", "", title);
    Object.assign(card.style, { height: "120px", borderRadius: "16px", background: "var(--surface)", border: "1px solid var(--edge)", padding: "16px", fontWeight: "600" });
    body.append(card);
  }
  root.append(bar, body);
}

function step(index: number) {
  return (root: HTMLElement) => {
    page(root);
    const store = new Map<string, string>();
    const tour = createTour({ lessons: parseLessons(JSON.stringify(lessons)), translate,
      storage: { getItem: (k) => store.get(k) ?? null, setItem: (k, v) => void store.set(k, v), removeItem: (k) => void store.delete(k) } });
    tour.setEnabled(true);
    tour.want("welcome");
    for (let i = 0; i < index; i++) tour.next();
    mountTour({ tour, ui, translate, parent: root, requestFrame: () => 0, cancelFrame: () => {} });
  };
}

export const scenes: Scene[] = [
  { name: "first-step", caption: "The first step of a lesson: the menu in a circle of light and the card below with Skip and Next", width: 1100, height: 700, look: "night", render: step(0) },
  { name: "second-step-lounge", caption: "The second step on the search field, in the lounge look", width: 1100, height: 700, look: "lounge", render: step(1) },
  { name: "last-step", caption: "The last step on the profile, with Got it in place of Next", width: 1100, height: 700, look: "night", render: step(2) },
];
