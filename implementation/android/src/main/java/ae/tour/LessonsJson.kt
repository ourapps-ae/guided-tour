package ae.tour

import org.json.JSONException
import org.json.JSONObject

// Reads a lessons file (see tests/fixtures/lessons.json) with Android's JSON classes and a
// SharedPreferences-backed store. Throws IllegalArgumentException with the problems when the file is unusable.
object LessonsJson {
    fun parse(text: String): List<Lesson> {
        val root = try { JSONObject(text) } catch (e: JSONException) { throw IllegalArgumentException("lessons are not JSON: ${e.message}") }
        require(root.optInt("format", 0) == 1) { "format must be 1" }
        val array = root.optJSONArray("lessons") ?: throw IllegalArgumentException("lessons must list at least one lesson")
        val lessons = (0 until array.length()).map { i ->
            val l = array.getJSONObject(i)
            val steps = l.optJSONArray("steps")
            Lesson(
                id = l.optString("id", ""),
                screen = if (l.has("screen") && !l.isNull("screen")) l.optString("screen") else null,
                steps = (0 until (steps?.length() ?: 0)).map { j ->
                    val s = steps!!.getJSONObject(j)
                    TourStep(s.optString("title", ""), s.optString("text", ""), s.optString("anchor", ""))
                },
            )
        }
        val problems = TourModel.validate(lessons)
        require(problems.isEmpty()) { problems.joinToString("; ") }
        return lessons
    }
}

class PreferencesTourStorage(private val prefs: android.content.SharedPreferences) : TourStorage {
    override fun getString(key: String): String? = when (val v = prefs.all[key]) {
        null -> null
        is Boolean -> if (v) "true" else "false"
        else -> v.toString()
    }
    override fun putString(key: String, value: String) { prefs.edit().putString(key, value).apply() }
    override fun remove(key: String) { prefs.edit().remove(key).apply() }
}
