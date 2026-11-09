package ae.tour

import ae.controls.LocalControlsTheme
import androidx.compose.animation.core.animateRectAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.hypot

// Where each element a step can ring sits on screen, in root coordinates. Mark an element with
// `Modifier.tourAnchor("name")`; the host provides one `TourAnchors` for the tree.
class TourAnchors {
    val rects = mutableStateMapOf<String, Rect>()
}

val LocalTourAnchors = staticCompositionLocalOf { TourAnchors() }

fun Modifier.tourAnchor(name: String, on: Boolean = true): Modifier = if (!on) this else composed {
    val anchors = LocalTourAnchors.current
    DisposableEffect(name) { onDispose { anchors.rects.remove(name) } }
    onGloballyPositioned { anchors.rects[name] = it.boundsInRoot() }
}

// The three button texts, already translated.
class TourButtons(val next: String, val skip: String, val done: String)

// A lesson over the screen, one step at a time: a circle of light on the step's element with the
// rest dimmed, and a card on the other half with the sentence, Skip and Next, or the done text at the end.
@Composable
fun TourOverlay(view: TourView, buttons: TourButtons, onNext: () -> Unit, onSkip: () -> Unit) {
    val theme = LocalControlsTheme.current
    val primary = Color(theme.colour.primary)
    val anchors = LocalTourAnchors.current
    val density = LocalDensity.current
    key(view.lessonId) {
        var size by remember { mutableStateOf(IntSize.Zero) }
        val screen = Rect(Offset.Zero, Size(size.width.toFloat(), size.height.toFloat()))
        val target = anchors.rects[view.anchor]?.intersect(screen)?.takeIf { it.width > 0f && it.height > 0f }
        val circle = target?.let {
            val r = maxOf(with(density) { 28.dp.toPx() }, hypot(it.width, it.height) / 2 + with(density) { 8.dp.toPx() })
            Rect(it.center, r)
        }
        val shown by animateRectAsState(circle ?: Rect(screen.center, 0f), label = "tour circle")
        val below = circle == null || circle.center.y < size.height / 2f
        Box(
            Modifier.fillMaxSize().onSizeChanged { size = it }
                .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null) {},
        ) {
            Canvas(Modifier.fillMaxSize()) {
                val dim = Path().apply {
                    fillType = PathFillType.EvenOdd
                    addRect(Rect(Offset.Zero, this@Canvas.size))
                    if (circle != null) addOval(shown)
                }
                drawPath(dim, Color.Black.copy(alpha = 0.65f))
                if (circle != null) drawCircle(primary.copy(alpha = 0.85f), radius = shown.width / 2, center = shown.center, style = Stroke(width = 2.dp.toPx()))
            }
            Column(
                Modifier.align(if (below) Alignment.BottomCenter else Alignment.TopCenter).safeDrawingPadding().padding(16.dp)
                    .widthIn(max = 420.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color(theme.colour.surface).copy(alpha = 0.97f)).background(Color.Black.copy(alpha = 0.8f))
                    .border(1.dp, Color(theme.colour.edge), RoundedCornerShape(16.dp)).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(view.title, color = primary, fontWeight = FontWeight.Bold, fontSize = 17.sp)
                Text(view.text, fontSize = 15.sp)
                if (view.count > 1) Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
                    for (i in 0 until view.count) Box(Modifier.size(6.dp).clip(CircleShape).background(if (i == view.step) primary else Color.White.copy(alpha = 0.3f)))
                }
                Row(Modifier.fillMaxWidth().padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (!view.last) TextButton(onClick = onSkip) { Text(buttons.skip, color = primary) }
                    Button(onClick = onNext, modifier = Modifier.weight(1f)) { Text(if (view.last) buttons.done else buttons.next) }
                }
            }
        }
    }
}

// Shows the tour's current step over the content it is placed in and keeps itself up to date.
@Composable
fun TourHost(tour: Tour, buttons: TourButtons, content: @Composable () -> Unit) {
    var view by remember { mutableStateOf(tour.current) }
    DisposableEffect(tour) {
        view = tour.current
        val stop = tour.onChange { view = it }
        onDispose { stop() }
    }
    Box(Modifier.fillMaxSize()) {
        content()
        view?.let { TourOverlay(it, buttons, onNext = { tour.next() }, onSkip = { tour.skip() }) }
    }
}
