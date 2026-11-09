import Foundation

// A guided tour as a mechanism: lessons made of steps, each step ringing one element of the screen;
// shown once ever each, one after another; the screen they belong to; play held while one is open;
// progress and the person's choice to be guided remembered on the device. What the lessons say, and
// which element each step rings, belongs to the application (lessons are data); nothing here knows
// any application. Pure, no UI framework; matches web/tour-model.ts.
struct TourStep: Equatable {
    let title: String
    let text: String
    let anchor: String
}

struct Lesson: Equatable {
    let id: String
    let screen: String?
    let steps: [TourStep]
}

// The key-value store lessons are remembered in (UserDefaults fits: see UserDefaultsTourStorage).
protocol TourStorage: AnyObject {
    func string(forKey key: String) -> String?
    func set(_ value: String, forKey key: String)
    func remove(forKey key: String)
}

final class UserDefaultsTourStorage: TourStorage {
    private let defaults: UserDefaults
    init(_ defaults: UserDefaults = .standard) { self.defaults = defaults }
    func string(forKey key: String) -> String? {
        guard let value = defaults.object(forKey: key) else { return nil }
        if let text = value as? String { return text }
        if let flag = value as? Bool { return flag ? "true" : "false" }
        return String(describing: value)
    }
    func set(_ value: String, forKey key: String) { defaults.set(value, forKey: key) }
    func remove(forKey key: String) { defaults.removeObject(forKey: key) }
}

final class MemoryTourStorage: TourStorage {
    var data: [String: String] = [:]
    func string(forKey key: String) -> String? { data[key] }
    func set(_ value: String, forKey key: String) { data[key] = value }
    func remove(forKey key: String) { data[key] = nil }
}

struct TourKeys {
    var prefix = "tut."
    var enabled = "beginner"
}

struct TourView: Equatable {
    let lessonId: String
    let step: Int
    let count: Int
    let title: String
    let text: String
    let anchor: String
    var first: Bool { step == 0 }
    var last: Bool { step == count - 1 }
}

struct TourRect {
    var left: Double, top: Double, right: Double, bottom: Double
}

struct TourCircle: Equatable {
    var x: Double, y: Double, r: Double
}

enum TourError: Error, Equatable {
    case invalid([String])
}

enum TourModel {
    private static func matches(_ pattern: String, _ s: String) -> Bool { s.range(of: pattern, options: .regularExpression) != nil }

    // Parses and checks a lessons file; throws with the list of problems.
    static func parseLessons(_ data: Data) throws -> [Lesson] {
        guard let any = try? JSONSerialization.jsonObject(with: data) else { throw TourError.invalid(["lessons are not JSON"]) }
        guard let root = any as? [String: Any] else { throw TourError.invalid(["lessons file must be an object"]) }
        var problems: [String] = []
        if (root["format"] as? Int) != 1 { problems.append("format must be 1") }
        guard let raw = root["lessons"] as? [[String: Any]], !raw.isEmpty else { throw TourError.invalid(problems + ["lessons must list at least one lesson"]) }
        var seen = Set<String>()
        var out: [Lesson] = []
        for (i, l) in raw.enumerated() {
            let where_ = "lesson \(i + 1)"
            let id = l["id"] as? String ?? ""
            if !matches("^[a-z][a-z0-9-]{0,47}$", id) { problems.append("\(where_): id must be lower-case letters, digits and hyphens") }
            else if !seen.insert(id).inserted { problems.append("\(where_): id \(id) is used twice") }
            var screen: String?
            if let s = l["screen"], !(s is NSNull) {
                if let text = s as? String, matches("^[a-z][a-z0-9-]{0,47}$", text) { screen = text } else { problems.append("\(where_): screen must be lower-case letters, digits and hyphens") }
            }
            guard let steps = l["steps"] as? [[String: Any]], !steps.isEmpty else { problems.append("\(where_): steps must list at least one step"); continue }
            var parsed: [TourStep] = []
            for (j, s) in steps.enumerated() {
                let title = s["title"] as? String ?? "", text = s["text"] as? String ?? "", anchor = s["anchor"] as? String ?? ""
                if title.isEmpty { problems.append("\(where_) step \(j + 1): title key is required") }
                if text.isEmpty { problems.append("\(where_) step \(j + 1): text key is required") }
                if !matches("^[A-Za-z][A-Za-z0-9_-]{0,47}$", anchor) { problems.append("\(where_) step \(j + 1): anchor must be letters, digits, hyphens and underscores") }
                parsed.append(TourStep(title: title, text: text, anchor: anchor))
            }
            out.append(Lesson(id: id, screen: screen, steps: parsed))
        }
        if !problems.isEmpty { throw TourError.invalid(problems) }
        return out
    }

    // "true" means guided and "false" means not; anything else means not yet asked.
    static func parseEnabled(_ raw: String?) -> Bool? {
        switch raw {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    // The circle round an element, clipped to the screen; nil when the element is not on screen.
    static func ring(_ rect: TourRect, width: Double, height: Double) -> TourCircle? {
        let left = max(0, rect.left), right = min(width, rect.right)
        let top = max(0, rect.top), bottom = min(height, rect.bottom)
        guard right > left, bottom > top else { return nil }
        return TourCircle(x: (left + right) / 2, y: (top + bottom) / 2, r: max(28, hypot(right - left, bottom - top) / 2 + 8))
    }

    // The text card takes the half of the screen the circle is not in.
    static func cardBelow(_ circle: TourCircle?, viewportHeight: Double) -> Bool {
        circle.map { $0.y < viewportHeight / 2 } ?? true
    }
}

@MainActor
final class Tour {
    private let lessons: [String: Lesson]
    private let storage: TourStorage
    private let translate: (String) -> String
    private let keys: TourKeys
    private let allowed: () -> Bool
    private var queue: [String] = []
    private var step = 0
    private var listeners: [Int: (TourView?) -> Void] = [:]
    private var nextListener = 0
    private var lastSignature = "none"

    init(lessons list: [Lesson], storage: TourStorage, translate: @escaping (String) -> String, keys: TourKeys = TourKeys(), allowed: @escaping () -> Bool = { true }) {
        lessons = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        self.storage = storage
        self.translate = translate
        self.keys = keys
        self.allowed = allowed
    }

    // Whether the person wants to be guided: true, false, or nil if not yet asked.
    var enabled: Bool? { TourModel.parseEnabled(storage.string(forKey: keys.enabled)) }

    func setEnabled(_ on: Bool) {
        storage.set(on ? "true" : "false", forKey: keys.enabled)
        if !on { queue.removeAll(); step = 0; notify() }
    }

    func seen(_ id: String) -> Bool { storage.string(forKey: keys.prefix + id) != nil }

    // Ask for a lesson: it is shown once ever, after any already waiting; returns whether it was queued.
    @discardableResult
    func want(_ id: String) -> Bool {
        guard lessons[id] != nil, allowed(), enabled == true, !seen(id), !queue.contains(id) else { return false }
        queue.append(id)
        notify()
        return true
    }

    // The step on show, or nil.
    var current: TourView? {
        guard let id = queue.first, let lesson = lessons[id] else { return nil }
        let i = min(step, lesson.steps.count - 1)
        let s = lesson.steps[i]
        return TourView(lessonId: id, step: i, count: lesson.steps.count, title: translate(s.title), text: translate(s.text), anchor: s.anchor)
    }

    var queued: [String] { queue }
    // True while a lesson is open: the host holds play for everyone.
    var holding: Bool { !queue.isEmpty }

    func next() {
        guard let view = current else { return }
        if view.last { finish() } else { step += 1; notify() }
    }

    // Closes the lesson on show for good, without finishing its steps.
    func skip() { if !queue.isEmpty { finish() } }

    private func finish() {
        let id = queue.removeFirst()
        storage.set("1", forKey: keys.prefix + id)
        step = 0
        notify()
    }

    // The screen changed: lessons that belong to another screen are dropped, even the one showing.
    func screenChanged(_ screen: String) {
        if !allowed() { queue.removeAll(); step = 0; notify(); return }
        for i in queue.indices.reversed() {
            if let own = lessons[queue[i]]?.screen, own != screen {
                queue.remove(at: i)
                if i == 0 { step = 0 }
            }
        }
        notify()
    }

    // Every lesson shows again, and guidance is on.
    func reset() {
        for id in lessons.keys { storage.remove(forKey: keys.prefix + id) }
        storage.set("true", forKey: keys.enabled)
        queue.removeAll()
        step = 0
        notify()
    }

    // Told whenever the step on show changes, a lesson opens, or the last one closes.
    @discardableResult
    func onChange(_ listener: @escaping (TourView?) -> Void) -> () -> Void {
        let id = nextListener
        nextListener += 1
        listeners[id] = listener
        return { [weak self] in self?.listeners[id] = nil }
    }

    private func notify() {
        let view = current
        let signature = view.map { "\($0.lessonId)|\($0.step)" } ?? "none"
        if signature == lastSignature { return }
        lastSignature = signature
        for l in listeners.values { l(view) }
    }
}
