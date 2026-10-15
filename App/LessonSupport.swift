import SwiftUI

struct LessonTrace {
    var values: [Double]
    var color: Color
    var name: String
}

/// Shared axes keep comparisons quantitative. Traces share the specified physical scale.
struct LessonPlot: View {
    var traces: [LessonTrace]
    var xRange: ClosedRange<Double>
    var yRange: ClosedRange<Double>
    var xLabel: String
    var yLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(yLabel)
                Spacer()
                Text("\(yRange.lowerBound.formatted(.number.precision(.significantDigits(3)))) … \(yRange.upperBound.formatted(.number.precision(.significantDigits(3))))")
            }.font(.caption.monospaced()).foregroundStyle(BenchTheme.muted)
            Canvas { context, size in
                let span = max(yRange.upperBound - yRange.lowerBound, 1e-15)
                func y(_ value: Double) -> CGFloat { size.height * (1 - (value - yRange.lowerBound) / span) }
                for row in 0...4 {
                    let yy = size.height * Double(row) / 4
                    var grid = Path(); grid.move(to: .init(x: 0, y: yy)); grid.addLine(to: .init(x: size.width, y: yy))
                    context.stroke(grid, with: .color(.white.opacity(0.08)), lineWidth: 1)
                }
                if yRange.contains(0) {
                    var axis = Path(); axis.move(to: .init(x: 0, y: y(0))); axis.addLine(to: .init(x: size.width, y: y(0)))
                    context.stroke(axis, with: .color(.white.opacity(0.25)), lineWidth: 1)
                }
                context.clip(to: Path(CGRect(origin: .zero, size: size)))
                for trace in traces where trace.values.count > 1 {
                    var line = Path(); var connected = false
                    for (index, value) in trace.values.enumerated() {
                        guard value.isFinite else { connected = false; continue }
                        let p = CGPoint(x: size.width * Double(index) / Double(trace.values.count - 1), y: y(value))
                        if connected { line.addLine(to: p) } else { line.move(to: p); connected = true }
                    }
                    context.stroke(line, with: .color(trace.color), style: StrokeStyle(lineWidth: 2.3, lineJoin: .round))
                }
            }.frame(height: 170).accessibilityHidden(true)
            HStack {
                Text(xRange.lowerBound.formatted(.number.precision(.significantDigits(3))))
                Spacer(); Text(xLabel); Spacer()
                Text(xRange.upperBound.formatted(.number.precision(.significantDigits(3))))
            }.font(.caption.monospaced()).foregroundStyle(BenchTheme.muted)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { legend }
                VStack(alignment: .leading, spacing: 6) { legend }
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("\(yLabel) plotted against \(xLabel). Horizontal range \(xRange.lowerBound) to \(xRange.upperBound); vertical range \(yRange.lowerBound) to \(yRange.upperBound). \(traces.map { "\($0.name), final value \($0.values.last ?? 0)" }.joined(separator: "; "))")
    }
    private var legend: some View {
        ForEach(Array(traces.enumerated()), id: \.offset) { _, trace in
            HStack(spacing: 5) { Circle().fill(trace.color).frame(width: 7, height: 7); Text(trace.name).font(.caption).foregroundStyle(BenchTheme.muted) }
        }
    }
}

struct LessonCheck: View {
    var prompt: String
    var answer: String
    @State private var revealed = false
    var body: some View {
        InstrumentPanel(title: "Predict, then check") {
            Text(prompt).font(.subheadline)
            Button(revealed ? "Hide explanation" : "Check the reasoning") { revealed.toggle() }
                .buttonStyle(GlassActionStyle(tint: BenchTheme.green))
                .accessibilityIdentifier("checkLessonReasoning")
            if revealed { Text(answer).font(.subheadline).foregroundStyle(BenchTheme.green).fixedSize(horizontal: false, vertical: true) }
        }.sensoryFeedback(.selection, trigger: revealed)
    }
}

struct LessonModelNote: View {
    var text: String
    var body: some View { InstrumentPanel(title: "Model & assumptions") { Text(text).font(.caption).foregroundStyle(BenchTheme.muted) } }
}
