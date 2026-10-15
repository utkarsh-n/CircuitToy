import SwiftUI

enum BenchTheme {
    static let bg = Color(red: 0.025, green: 0.043, blue: 0.061)
    static let panel = Color(red: 0.065, green: 0.090, blue: 0.111)
    static let ink = Color(red: 0.93, green: 0.97, blue: 0.98)
    static let muted = Color(red: 0.63, green: 0.72, blue: 0.77)
    static let cyan = Color(red: 0.30, green: 0.91, blue: 0.96)
    static let amber = Color(red: 1.0, green: 0.73, blue: 0.32)
    static let green = Color(red: 0.47, green: 0.95, blue: 0.69)
}

struct BenchScreen<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
                .frame(maxWidth: 720).padding(20).padding(.bottom, 20)
                .frame(maxWidth: .infinity)
        }
        .background(BenchTheme.bg.ignoresSafeArea())
        .foregroundStyle(BenchTheme.ink)
    }
}

struct BenchHeader: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased()).font(.system(.caption, design: .monospaced, weight: .semibold))
                .tracking(2).foregroundStyle(BenchTheme.cyan)
            Text(title).font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text(subtitle).font(.subheadline).foregroundStyle(BenchTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct InstrumentPanel<Content: View>: View {
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !title.isEmpty {
                Text(title.uppercased()).font(.system(.caption, design: .monospaced, weight: .semibold))
                    .tracking(1.2).foregroundStyle(BenchTheme.muted)
            }
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(BenchTheme.muted) }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .background(BenchTheme.panel, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.09)))
    }
}

struct MeterValue: View {
    var label: String
    var value: String
    var unit: String
    var tint: Color = BenchTheme.cyan
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(BenchTheme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(.title2, design: .monospaced, weight: .semibold)).monospacedDigit()
                Text(unit).font(.caption)
            }
            .foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct ParameterSlider: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var unit: String
    var format: String = "%.2f"
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text("\(String(format: format, value)) \(unit)").font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(BenchTheme.cyan).monospacedDigit()
            }
            Slider(value: $value, in: range).tint(BenchTheme.cyan)
                .accessibilityLabel(title).accessibilityValue("\(String(format: format, value)) \(unit)")
            HStack(spacing: 16) {
                Button { value = max(range.lowerBound, value - (range.upperBound - range.lowerBound) / 100) } label: {
                    Image(systemName: "minus").frame(minWidth: 44, minHeight: 44)
                }.disabled(value <= range.lowerBound).accessibilityLabel("Decrease \(title)")
                Spacer()
                Button { value = min(range.upperBound, value + (range.upperBound - range.lowerBound) / 100) } label: {
                    Image(systemName: "plus").frame(minWidth: 44, minHeight: 44)
                }.disabled(value >= range.upperBound).accessibilityLabel("Increase \(title)")
            }.buttonStyle(.bordered).tint(BenchTheme.cyan)
        }
    }
}

struct FormulaNote: View {
    var equation: String
    var explanation: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(equation).font(.system(.headline, design: .monospaced)).foregroundStyle(BenchTheme.amber)
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            Text(explanation).font(.subheadline).foregroundStyle(BenchTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct WaveformView: View {
    var points: [Double]
    var tint: Color
    var height: CGFloat = 140
    var body: some View {
        Canvas { context, size in
            let maximum = max(points.map { abs($0) }.max() ?? 1, 0.00001)
            for row in 0...4 {
                var path = Path(); let y = size.height * CGFloat(row) / 4
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.white.opacity(0.09)), lineWidth: 1)
            }
            guard points.count > 1 else { return }
            var path = Path()
            for (index, value) in points.enumerated() {
                let p = CGPoint(x: size.width * Double(index) / Double(points.count - 1), y: size.height * (0.5 - value / maximum * 0.44))
                if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            context.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        }
        .frame(height: height).accessibilityLabel("Waveform, autoscaled to peak \(points.map { abs($0) }.max() ?? 0)")
    }
}

struct GlassActionStyle: ButtonStyle {
    var tint: Color = BenchTheme.cyan
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        if reduceTransparency {
            configuration.label.padding(.horizontal, 15).frame(minHeight: 44)
                .background(BenchTheme.panel, in: Capsule()).overlay(Capsule().stroke(tint.opacity(0.5)))
                .opacity(isEnabled ? 1 : 0.4)
        } else {
            configuration.label.padding(.horizontal, 15).frame(minHeight: 44)
                .glassEffect(.regular.tint(tint.opacity(0.13)).interactive(isEnabled), in: .capsule)
                .opacity(isEnabled ? 1 : 0.4)
        }
    }
}

func engineering(_ value: Double, unit: String) -> String {
    guard value.isFinite else { return "—" }
    let magnitude = abs(value)
    if magnitude == 0 { return "0 \(unit)" }
    for (scale, prefix) in [(1e9, "G"), (1e6, "M"), (1e3, "k"), (1.0, ""), (1e-3, "m"), (1e-6, "µ"), (1e-9, "n"), (1e-12, "p")] {
        if magnitude >= scale { return String(format: "%.3g %@%@", value / scale, prefix, unit) }
    }
    return String(format: "%.3g %@", value, unit)
}
