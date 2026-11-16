import Foundation

// Number and time text shared by every screen.

// 1,234,567 in every language, so amounts read the same on every device.
func formatCount(_ n: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "en_US")
    return formatter.string(from: NSNumber(value: n)) ?? String(n)
}

// Minutes and seconds, rounding a part second up: 61000 is 1:01, 0 is 0:00.
func mmss(_ ms: Int) -> String {
    let seconds = max(0, (ms + 999) / 1000)
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}
