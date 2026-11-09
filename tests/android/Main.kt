import ae.tour.*
import kotlin.math.abs

// Mirrors tests/apple/main.swift: the scripted run and the ring geometry are compared with rows the TypeScript produced (Expected.kt).
fun check(condition: Boolean, message: String) { if (!condition) { System.err.println("FAIL: $message"); System.exit(1) } }
fun near(a: Double, b: Double, what: String) = check(abs(a - b) < 1e-9, "$what: $a vs $b")

fun lessons(): List<Lesson> = listOf(
    Lesson("welcome", "home", listOf(TourStep("welcome_title", "welcome_menu", "menu"), TourStep("welcome_title", "welcome_search", "search"), TourStep("welcome_title", "welcome_profile", "profile"))),
    Lesson("editing", "editor", listOf(TourStep("editing_title", "editing_save", "save"), TourStep("editing_title", "editing_undo", "undo"))),
    Lesson("first-share", null, listOf(TourStep("share_title", "share_button", "share"))),
)

fun main() {
    check(TourModel.validate(lessons()).isEmpty(), "the sample lessons are valid")
    check(TourModel.validate(emptyList()) == listOf("lessons must list at least one lesson"), "no lessons")
    check(TourModel.validate(listOf(Lesson("A", null, emptyList()))).size == 2, "bad id and no steps")
    check(TourModel.validate(lessons() + lessons()[0]).any { it.contains("used twice") }, "duplicate id")
    check(TourModel.validate(listOf(Lesson("a", "Home Page", listOf(TourStep("t", "x", "z"))))).any { it.contains("screen must be") }, "bad screen")
    check(TourModel.validate(listOf(Lesson("a", null, listOf(TourStep("", "x", "z"))))).any { it.contains("title key") }, "no title")
    check(TourModel.validate(listOf(Lesson("a", null, listOf(TourStep("t", "x", "a b"))))).any { it.contains("anchor") }, "bad anchor")
    check(TourModel.parseEnabled("true") == true && TourModel.parseEnabled("false") == false && listOf("yes", "no", "1", "0", "TRUE", "").all { TourModel.parseEnabled(it) == null }, "enabled values")
    check(listOf(null, "", "maybe").all { TourModel.parseEnabled(it) == null }, "not asked")

    for (row in EXPECTED_RINGS) {
        val rect = TourRect((row[0] as Double), row[1] as Double, row[2] as Double, row[3] as Double)
        val got = TourModel.ring(rect, 400.0, 800.0)
        if (row[4] == null) check(got == null, "ring should be null for $rect")
        else {
            check(got != null, "ring missing for $rect")
            near(got!!.x, (row[4] as Number).toDouble(), "x"); near(got.y, (row[5] as Number).toDouble(), "y"); near(got.r, (row[6] as Number).toDouble(), "r")
        }
        check(TourModel.cardBelow(got, 800.0) == (row[7] == "below"), "card side for $rect")
    }

    val storage = MemoryTourStorage()
    val tour = Tour(lessons(), storage, { it })
    var events = 0
    tour.onChange { events++ }
    for (row in EXPECTED_RUN) {
        val action = row[0] as String
        val arg = row[1] as String
        when (action) {
            "enable" -> tour.setEnabled(true)
            "want" -> tour.want(arg)
            "next" -> tour.next()
            "skip" -> tour.skip()
            "screen" -> tour.screenChanged(arg)
            "reset" -> tour.reset()
            else -> check(false, "unknown action $action")
        }
        val c = tour.current
        val current = c?.let { "${it.lessonId}:${it.step}:${if (it.last) 1 else 0}" } ?: "none"
        check(current == row[2], "after $action $arg: $current vs ${row[2]}")
        check(tour.queued.joinToString(",") == row[3], "queue after $action")
        check(tour.holding == row[4], "holding after $action")
        check(listOf("welcome", "editing", "first-share").filter { tour.seen(it) }.joinToString(",") == row[5], "seen after $action")
    }
    check(events > 5, "listeners were told")
    val fresh = Tour(lessons(), MemoryTourStorage(), { it })
    check(fresh.enabled == null && !fresh.want("welcome"), "unasked")
    var allowed = true
    val guarded = Tour(lessons(), MemoryTourStorage().apply { data["beginner"] = "true" }, { "T:$it" }, allowed = { allowed })
    check(guarded.want("welcome") && guarded.current?.title == "T:welcome_title", "translated")
    allowed = false
    guarded.screenChanged("home")
    check(guarded.current == null && guarded.queued.isEmpty(), "forbidden clears the queue")
    println("android tour checks passed (${EXPECTED_RUN.size} script steps, ${EXPECTED_RINGS.size} rings)")
}
