import NumoCore
import SwiftUI

/// Drains towards the start, closes at the start, then stays closed and shows elapsed time.
struct CountdownRing: View {
    let secondsSinceStart: TimeInterval
    /// How many seconds the full ring represents before the start.
    let horizon: TimeInterval
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Double {
        guard secondsSinceStart < 0 else { return 1 }
        return min(1, max(0, -secondsSinceStart / horizon))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 6)

            Circle()
                .trim(from: 0, to: secondsSinceStart < 0 ? progress : 1)
                .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)

            Text(ReminderCopy.clock(secondsSinceStart: secondsSinceStart))
                .font(.title3.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
        }
        .frame(width: 96, height: 96)
        .accessibilityHidden(true)  // the eyebrow text already says the same in words
    }
}
