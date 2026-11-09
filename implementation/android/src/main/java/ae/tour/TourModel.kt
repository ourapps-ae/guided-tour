package ae.tour

import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

// A guided tour as a mechanism: lessons made of steps, each step ringing one element of the screen;
// shown once ever each, one after another; the screen they belong to; play held while one is open;
// progress and the person's choice to be guided remembered on the device. What the lessons say, and
// which element each step rings, belongs to the application (lessons are data); nothing here knows
// any application. Pure, no Android classes; matches web/tour-model.ts.
data class TourStep(val title: String, val text: String, val anchor: String)
data class Lesson(val id: String, val screen: String?, val steps: List<TourStep>)

// The key-value store lessons are remembered in (SharedPreferences fits: see PreferencesTourStorage).
interface TourStorage {
    fun getString(key: String): String?
    fun putString(key: String, value: String)
    fun remove(key: String)
}

class MemoryTourStorage : TourStorage {
    val data = mutableMapOf<String, String>()
    override fun getString(key: String) = data[key]
    override fun putString(key: String, value: String) { data[key] = value }
    override fun remove(key: String) { data.remove(key) }
}

data class TourKeys(val prefix: String = "tut.", val enabled: String = "beginner")

data class TourView(val lessonId: String, val step: Int, val count: Int, val title: String, val text: String, val anchor: String) {
    val first: Boolean get() = step == 0
    val last: Boolean get() = step == count - 1
}

data class TourRect(val left: Double, val top: Double, val right: Double, val bottom: Double)
data class TourCircle(val x: Double, val y: Double, val r: Double)

object TourModel {
    private val ID = Regex("^[a-z][a-z0-9-]{0,47}$")
    private val ANCHOR = Regex("^[A-Za-z][A-Za-z0-9_-]{0,47}$")

    // Checks lessons; the list of problems, empty when they are usable.
    fun validate(lessons: List<Lesson>): List<String> {
        val problems = mutableListOf<String>()
        if (lessons.isEmpty()) return listOf("lessons must list at least one lesson")
        val seen = mutableSetOf<String>()
        lessons.forEachIndexed { i, l ->
            val where = "lesson ${i + 1}"
            if (!ID.matches(l.id)) problems += "$where: id must be lower-case letters, digits and hyphens"
            else if (!seen.add(l.id)) problems += "$where: id ${l.id} is used twice"
            if (l.screen != null && !ID.matches(l.screen)) problems += "$where: screen must be lower-case letters, digits and hyphens"
            if (l.steps.isEmpty()) problems += "$where: steps must list at least one step"
            l.steps.forEachIndexed { j, s ->
                if (s.title.isEmpty()) problems += "$where step ${j + 1}: title key is required"
                if (s.text.isEmpty()) problems += "$where step ${j + 1}: text key is required"
                if (!ANCHOR.matches(s.anchor)) problems += "$where step ${j + 1}: anchor must be letters, digits, hyphens and underscores"
            }
        }
        return problems
    }

    // "true" means guided and "false" means not; anything else means not yet asked.
    fun parseEnabled(raw: String?): Boolean? = when (raw) {
        "true" -> true
        "false" -> false
        else -> null
    }

    // The circle round an element, clipped to the screen; null when the element is not on screen.
    fun ring(rect: TourRect, width: Double, height: Double): TourCircle? {
        val left = max(0.0, rect.left)
        val right = min(width, rect.right)
        val top = max(0.0, rect.top)
        val bottom = min(height, rect.bottom)
        if (right <= left || bottom <= top) return null
        return TourCircle((left + right) / 2, (top + bottom) / 2, max(28.0, hypot(right - left, bottom - top) / 2 + 8))
    }

    // The text card takes the half of the screen the circle is not in.
    fun cardBelow(circle: TourCircle?, viewportHeight: Double): Boolean = circle == null || circle.y < viewportHeight / 2
}

class Tour(
    lessons: List<Lesson>,
    private val storage: TourStorage,
    private val translate: (String) -> String,
    private val keys: TourKeys = TourKeys(),
    private val allowed: () -> Boolean = { true },
) {
    private val byId = lessons.associateBy { it.id }
    private val queue = mutableListOf<String>()
    private var step = 0
    private val listeners = mutableMapOf<Int, (TourView?) -> Unit>()
    private var nextListener = 0
    private var lastSignature = "none"

    init {
        val problems = TourModel.validate(lessons)
        require(problems.isEmpty()) { problems.joinToString("; ") }
    }

    // Whether the person wants to be guided: true, false, or null if not yet asked.
    val enabled: Boolean? get() = TourModel.parseEnabled(storage.getString(keys.enabled))

    fun setEnabled(on: Boolean) {
        storage.putString(keys.enabled, if (on) "true" else "false")
        if (!on) { queue.clear(); step = 0; notifyListeners() }
    }

    fun seen(id: String): Boolean = storage.getString(keys.prefix + id) != null

    // Ask for a lesson: it is shown once ever, after any already waiting; returns whether it was queued.
    fun want(id: String): Boolean {
        if (id !in byId || !allowed() || enabled != true || seen(id) || id in queue) return false
        queue += id
        notifyListeners()
        return true
    }

    // The step on show, or null.
    val current: TourView?
        get() {
            val lesson = queue.firstOrNull()?.let { byId[it] } ?: return null
            val i = min(step, lesson.steps.size - 1)
            val s = lesson.steps[i]
            return TourView(lesson.id, i, lesson.steps.size, translate(s.title), translate(s.text), s.anchor)
        }

    val queued: List<String> get() = queue.toList()

    // True while a lesson is open: the host holds play for everyone.
    val holding: Boolean get() = queue.isNotEmpty()

    fun next() {
        val view = current ?: return
        if (view.last) finish() else { step += 1; notifyListeners() }
    }

    // Closes the lesson on show for good, without finishing its steps.
    fun skip() { if (queue.isNotEmpty()) finish() }

    private fun finish() {
        val id = queue.removeAt(0)
        storage.putString(keys.prefix + id, "1")
        step = 0
        notifyListeners()
    }

    // The screen changed: lessons that belong to another screen are dropped, even the one showing.
    fun screenChanged(screen: String) {
        if (!allowed()) { queue.clear(); step = 0; notifyListeners(); return }
        for (i in queue.indices.reversed()) {
            val own = byId[queue[i]]?.screen
            if (own != null && own != screen) {
                queue.removeAt(i)
                if (i == 0) step = 0
            }
        }
        notifyListeners()
    }

    // Every lesson shows again, and guidance is on.
    fun reset() {
        for (id in byId.keys) storage.remove(keys.prefix + id)
        storage.putString(keys.enabled, "true")
        queue.clear()
        step = 0
        notifyListeners()
    }

    // Told whenever the step on show changes, a lesson opens, or the last one closes. Returns how to stop listening.
    fun onChange(listener: (TourView?) -> Unit): () -> Unit {
        val id = nextListener++
        listeners[id] = listener
        return { listeners.remove(id) }
    }

    private fun notifyListeners() {
        val view = current
        val signature = view?.let { "${it.lessonId}|${it.step}" } ?: "none"
        if (signature == lastSignature) return
        lastSignature = signature
        for (l in listeners.values.toList()) l(view)
    }
}
