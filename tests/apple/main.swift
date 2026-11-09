import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
    exit(1)
}
func check(_ condition: Bool, _ message: @autoclosure () -> String) { if !condition { fail(message()) } }
func near(_ a: Double, _ b: Double, _ what: String) { check(abs(a - b) < 1e-9, "\(what): \(a) vs \(b)") }
func read(_ path: String) -> Data {
    guard let data = FileManager.default.contents(atPath: path) else { fail("cannot read \(path)") }
    return data
}
func problems(_ json: String) -> [String] {
    do { _ = try TourModel.parseLessons(Data(json.utf8)); return [] } catch TourError.invalid(let p) { return p } catch { return ["other"] }
}

let lessons = try! TourModel.parseLessons(read("tests/fixtures/lessons.json"))
let fixtures = try! JSONSerialization.jsonObject(with: read("tests/fixtures/tour.json")) as! [String: Any]
check(lessons.count == 3 && lessons[0].steps.count == 3 && lessons[0].screen == "home" && lessons[2].screen == nil, "lessons")

// Faults are refused with their reasons.
let good = "{\"id\":\"a\",\"steps\":[{\"title\":\"t\",\"text\":\"x\",\"anchor\":\"z\"}]}"
check(problems("{\"format\":1,\"lessons\":[\(good)]}").isEmpty, "a small lesson set is fine")
check(problems("{\"format\":2,\"lessons\":[\(good)]}").contains("format must be 1"), "format")
check(problems("{\"format\":1,\"lessons\":[]}").first?.contains("at least one lesson") == true, "no lessons")
check(problems("{\"format\":1,\"lessons\":[\(good),\(good)]}").contains { $0.contains("used twice") }, "duplicate id")
check(problems("{\"format\":1,\"lessons\":[{\"id\":\"A\",\"steps\":[]}]}").contains { $0.contains("id must be") }, "bad id")
check(problems("{\"format\":1,\"lessons\":[{\"id\":\"a\",\"screen\":\"Home Page\",\"steps\":[{\"title\":\"t\",\"text\":\"x\",\"anchor\":\"z\"}]}]}").contains { $0.contains("screen must be") }, "bad screen")
check(problems("{\"format\":1,\"lessons\":[{\"id\":\"a\",\"steps\":[]}]}").contains { $0.contains("at least one step") }, "no steps")
check(problems("{\"format\":1,\"lessons\":[{\"id\":\"a\",\"steps\":[{\"title\":\"\",\"text\":\"x\",\"anchor\":\"z\"}]}]}").contains { $0.contains("title key") }, "no title")
check(problems("{\"format\":1,\"lessons\":[{\"id\":\"a\",\"steps\":[{\"title\":\"t\",\"text\":\"x\",\"anchor\":\"a b\"}]}]}").contains { $0.contains("anchor") }, "bad anchor")
check((try? TourModel.parseLessons(Data("{".utf8))) == nil, "not JSON")

// Enabled values.
for item in fixtures["enabled"] as! [[String: Any]] {
    let expected = item["value"] as? Bool
    check(TourModel.parseEnabled(item["raw"] as? String) == expected, "enabled \(item["raw"]!)")
}
check(TourModel.parseEnabled(nil) == nil, "nothing stored")

// Geometry equals the TypeScript's.
for item in fixtures["rings"] as! [[String: Any]] {
    let r = item["rect"] as! [String: Double]
    let rect = TourRect(left: r["left"]!, top: r["top"]!, right: r["right"]!, bottom: r["bottom"]!)
    let got = TourModel.ring(rect, width: 400, height: 800)
    if let e = item["circle"] as? [String: Double] {
        guard let got else { fail("ring missing for \(r)") }
        near(got.x, e["x"]!, "x"); near(got.y, e["y"]!, "y"); near(got.r, e["r"]!, "r")
    } else {
        check(got == nil, "ring should be nil for \(r)")
    }
    check(TourModel.cardBelow(got, viewportHeight: 800) == ((item["side"] as! String) == "below"), "card side for \(r)")
}

// The scripted run equals the TypeScript's, step by step.
@MainActor func runScript() {
    let storage = MemoryTourStorage()
    let tour = Tour(lessons: lessons, storage: storage, translate: { $0 })
    var events = 0
    tour.onChange { _ in events += 1 }
    for row in fixtures["run"] as! [[String: Any]] {
        let action = row["action"] as! String, arg = row["arg"] as? String
        switch action {
        case "enable": tour.setEnabled(true)
        case "want": tour.want(arg!)
        case "next": tour.next()
        case "skip": tour.skip()
        case "screen": tour.screenChanged(arg!)
        case "reset": tour.reset()
        default: fail("unknown action \(action)")
        }
        let c = tour.current
        let current = c.map { "\($0.lessonId):\($0.step):\($0.last ? 1 : 0)" } ?? "none"
        check(current == row["current"] as! String, "after \(action) \(arg ?? ""): \(current) vs \(row["current"]!)")
        check(tour.queued == row["queued"] as! [String], "queue after \(action)")
        check(tour.holding == row["holding"] as! Bool, "holding after \(action)")
        check(["welcome", "editing", "first-share"].filter { tour.seen($0) } == row["seen"] as! [String], "seen after \(action)")
    }
    check(events > 5, "listeners were told")
    // Nothing is shown before the person says yes, and forbidding clears the queue.
    let fresh = Tour(lessons: lessons, storage: MemoryTourStorage(), translate: { $0 })
    check(fresh.enabled == nil && fresh.want("welcome") == false, "unasked")
    var allowed = true
    let guarded = Tour(lessons: lessons, storage: { let s = MemoryTourStorage(); s.data["beginner"] = "true"; return s }(), translate: { "T:" + $0 }, allowed: { allowed })
    check(guarded.want("welcome") && guarded.current?.title == "T:welcome_title", "translated")
    allowed = false
    guarded.screenChanged("home")
    check(guarded.current == nil && guarded.queued.isEmpty, "forbidden clears the queue")
}
MainActor.assumeIsolated { runScript() }

print("\((fixtures["run"] as! [Any]).count) script steps, \((fixtures["rings"] as! [Any]).count) rings matched the TypeScript model")
