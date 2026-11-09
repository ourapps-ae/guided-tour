// A consumer that needs no application: a neutral sample lesson set, an in-memory device store and
// messages looked up the way the translations component does (a missing key shows as itself).
import { readFileSync } from "node:fs";
import { createTour, parseLessons } from "../implementation/web/tour-model.ts";
import type { Tour, TourStorage } from "../implementation/web/tour-model.ts";

export function memoryStorage(): TourStorage & { data: Map<string, string> } {
  const data = new Map<string, string>();
  return { data, getItem: (k) => data.get(k) ?? null, setItem: (k, v) => void data.set(k, v), removeItem: (k) => void data.delete(k) };
}

export function sampleTour(storage: TourStorage = memoryStorage()): Tour {
  const read = (name: string) => readFileSync(new URL(`../tests/fixtures/${name}`, import.meta.url), "utf8");
  const messages: Record<string, string> = JSON.parse(read("messages.json"));
  const lookup = (key: string) => (Object.hasOwn(messages, key) ? messages[key] : key);
  return createTour({ lessons: parseLessons(read("lessons.json")), storage, translate: lookup });
}
