// A very small stand-in for the browser page: elements with classes, styles, data attributes, children and a body.
export class FakeElement {
  tagName: string;
  children: (FakeElement | string)[] = [];
  className = "";
  style: Record<string, string> = {};
  dataset: Record<string, string> = {};
  parent: FakeElement | null = null;
  listeners: Record<string, (() => void)[]> = {};
  constructor(tagName: string) { this.tagName = tagName; }
  append(...nodes: (FakeElement | string)[]) {
    for (const n of nodes) {
      if (typeof n !== "string") { n.remove(); n.parent = this; }
      this.children.push(n);
    }
  }
  remove() { if (this.parent) this.parent.children = this.parent.children.filter((c) => c !== this); this.parent = null; }
  get lastElementChild(): FakeElement | null { const els = this.children.filter((c): c is FakeElement => typeof c !== "string"); return els[els.length - 1] ?? null; }
  addEventListener(type: string, fn: () => void) { (this.listeners[type] ??= []).push(fn); }
  click() { for (const fn of this.listeners.click ?? []) fn(); }
  get classList() {
    const self = this;
    return {
      toggle: (c: string, on?: boolean) => {
        const has = self.classes().includes(c);
        const want = on === undefined ? !has : on;
        if (want && !has) self.className = [...self.classes(), c].join(" ");
        if (!want && has) self.className = self.classes().filter((x) => x !== c).join(" ");
      },
      contains: (c: string) => self.classes().includes(c),
    };
  }
  classes(): string[] { return this.className.split(/\s+/).filter(Boolean); }
  get text(): string { return this.children.map((c) => (typeof c === "string" ? c : c.text)).join(""); }
  find(predicate: (e: FakeElement) => boolean): FakeElement[] {
    const out: FakeElement[] = [];
    for (const c of this.children) if (typeof c !== "string") { if (predicate(c)) out.push(c); out.push(...c.find(predicate)); }
    return out;
  }
  byClass(name: string): FakeElement[] { return this.find((e) => e.classes().includes(name)); }
}
export function installFakeDocument() {
  (globalThis as any).document = { createElement: (tag: string) => new FakeElement(tag) };
}
