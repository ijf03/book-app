import SwiftUI

/// Keeps the existing clock at standard sizes and wraps readable units at accessibility sizes.
struct ReadingDurationText: View {
    let seconds: Int
    var defaultSize: CGFloat = 44
    @Environment(\.dynamicTypeSize) private var typeSize

    private var spokenDuration: String {
        Duration.seconds(max(0, seconds)).formatted(
            .units(allowed: [.hours, .minutes, .seconds], width: .wide)
        )
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                Text(spokenDuration)
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScaledClock(seconds: seconds, defaultSize: defaultSize)
            }
        }
        .monospacedDigit()
        .accessibilityLabel("Elapsed reading time")
        .accessibilityValue(spokenDuration)
    }
}

private struct ScaledClock: View {
    let seconds: Int
    @ScaledMetric(relativeTo: .largeTitle) private var fontSize: CGFloat = 44

    init(seconds: Int, defaultSize: CGFloat) {
        self.seconds = seconds
        _fontSize = ScaledMetric(wrappedValue: defaultSize, relativeTo: .largeTitle)
    }

    var body: some View {
        Text(FinishReadingSessionView.formatDuration(seconds))
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
    }
}

#Preview("Duration · largest text") {
    ScrollView {
        ReadingDurationText(seconds: 3661)
            .padding()
    }
    .dynamicTypeSize(.accessibility5)
}
