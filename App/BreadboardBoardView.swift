import SwiftUI
import CircuitCore

/// A physical solderless-board layout. The strips below the holes describe
/// connectivity; colored jumpers describe wires added by the learner.
struct BreadboardBoardView: View {
    var document: BreadboardDocument
    var connected: Set<BreadboardHole>
    var pendingPins: [BreadboardHole]
    var selectedHole: BreadboardHole?
    var selectedComponentID: String?
    var holesArePrimary = true
    var solution: CircuitSolution? = nil
    var onHole: (BreadboardHole) -> Void
    var onComponent: (BreadboardComponent) -> Void
    var onWire: (BreadboardWire) -> Void

    private let boardWidth: CGFloat = 680
    private let boardHeight: CGFloat = 630

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView([.horizontal, .vertical]) {
                board
                    .padding(8)
            }
            .frame(height: 380)
            .background(BenchTheme.bg, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.12)))
            .accessibilityIdentifier("breadboardSurface")

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .foregroundStyle(BenchTheme.cyan)
                Text("Scroll to explore. Each row joins A–E and F–J separately. The four side rails run continuously from row 1 to row 12.")
                    .font(.caption)
                    .foregroundStyle(BenchTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var board: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.085, green: 0.105, blue: 0.123))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.1)))

            boardDrawing
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            columnLabels
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            ForEach(0..<12, id: \.self) { row in
                Text(String(row + 1))
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(BenchTheme.muted)
                    .frame(width: 20, height: 22)
                    .position(x: 101, y: CGFloat(78 + row * 44))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                Text(String(row + 1))
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
                    .foregroundStyle(BenchTheme.muted)
                    .frame(width: 20, height: 22)
                    .position(x: 579, y: CGFloat(78 + row * 44))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            if holesArePrimary {
                accessories
                holes
            } else {
                holes
                accessories
            }

            Text("ISOLATED CENTER GAP")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(BenchTheme.muted.opacity(0.65))
                .rotationEffect(.degrees(-90))
                .position(x: 340, y: 319)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Text("12 ROWS  /  4 INDEPENDENT RAILS")
                .font(.system(.caption2, design: .monospaced, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(BenchTheme.muted)
                .position(x: 340, y: 600)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(width: boardWidth, height: boardHeight)
        .accessibilityElement(children: .contain)
    }

    private var holes: some View {
        ForEach(allHoles) { hole in
            holeButton(hole)
                .position(position(of: hole))
        }
    }

    private var accessories: some View {
        Group {
            ForEach(Array(document.wires.enumerated()), id: \.element.id) { index, wire in
                wireButton(wire, index: index)
            }
            ForEach(document.components) { component in
                componentButton(component)
            }
        }
        .allowsHitTesting(!holesArePrimary)
        .accessibilityHidden(holesArePrimary)
    }

    private var columnLabels: some View {
        ForEach(0..<14, id: \.self) { column in
            VStack(spacing: 4) {
                Text(columnName(column))
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                if column == 0 || column == 1 || column == 12 || column == 13 {
                    Text(column < 2 ? "LEFT" : "RIGHT")
                        .font(.system(size: 7, weight: .semibold, design: .monospaced))
                        .tracking(0.5)
                }
            }
            .foregroundStyle(columnTint(column))
            .frame(width: 40, height: 32)
            .position(x: columnX(column), y: 34)
        }
    }

    private var boardDrawing: some View {
        Canvas { context, _ in
            let gap = CGRect(x: 326, y: 56, width: 28, height: 526)
            context.fill(Path(roundedRect: gap, cornerRadius: 7), with: .color(BenchTheme.bg))

            for column in [0, 1, 12, 13] {
                var rail = Path()
                rail.move(to: CGPoint(x: columnX(column), y: 63))
                rail.addLine(to: CGPoint(x: columnX(column), y: 577))
                context.stroke(rail, with: .color(columnTint(column).opacity(0.25)), lineWidth: 3)
            }

            for row in 0..<12 {
                let y = CGFloat(78 + row * 44)
                for pair in [(2, 6), (7, 11)] {
                    var strip = Path()
                    strip.move(to: CGPoint(x: columnX(pair.0), y: y))
                    strip.addLine(to: CGPoint(x: columnX(pair.1), y: y))
                    context.stroke(strip, with: .color(.white.opacity(0.13)), lineWidth: 3)
                }
            }

            for (index, wire) in document.wires.enumerated() {
                let curve = wireCurve(wire, index: index)
                context.stroke(curve, with: .color(BenchTheme.bg.opacity(0.9)),
                               style: StrokeStyle(lineWidth: 8, lineCap: .round))
                context.stroke(curve, with: .color(wireTint(wire)),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }

            for component in document.components where !component.pins.isEmpty {
                let center = componentPosition(component)
                let tint = componentTint(component)
                for pin in component.pins {
                    var lead = Path()
                    lead.move(to: position(of: pin))
                    lead.addLine(to: center)
                    context.stroke(lead, with: .color(BenchTheme.bg), lineWidth: 5)
                    context.stroke(lead, with: .color(tint.opacity(0.7)), lineWidth: 1.8)
                }
            }

            let point = position(of: document.ground)
            var symbol = Path()
            symbol.move(to: CGPoint(x: point.x, y: point.y + 10))
            symbol.addLine(to: CGPoint(x: point.x, y: point.y + 17))
            for (offset, halfWidth) in [(17.0, 8.0), (21.0, 5.0), (25.0, 2.0)] {
                symbol.move(to: CGPoint(x: point.x - halfWidth, y: point.y + offset))
                symbol.addLine(to: CGPoint(x: point.x + halfWidth, y: point.y + offset))
            }
            context.stroke(symbol, with: .color(BenchTheme.ink), lineWidth: 1.5)
        }
        .frame(width: boardWidth, height: boardHeight)
    }

    private func holeButton(_ hole: BreadboardHole) -> some View {
        let isPending = pendingPins.contains(hole)
        let isSelected = selectedHole == hole
        let isConnected = connected.contains(hole)
        let isGround = document.ground == hole
        let tint = isPending ? BenchTheme.amber : (isSelected ? BenchTheme.cyan : BenchTheme.green)
        return Button { onHole(hole) } label: {
            ZStack {
                if isConnected {
                    Circle().fill(BenchTheme.green.opacity(0.13)).frame(width: 32, height: 32)
                }
                if isSelected || isPending {
                    Circle().strokeBorder(tint, lineWidth: 2).frame(width: 30, height: 30)
                }
                RoundedRectangle(cornerRadius: 3)
                    .fill(BenchTheme.bg)
                    .frame(width: 13, height: 13)
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(isConnected ? BenchTheme.green.opacity(0.7) : .white.opacity(0.27), lineWidth: 1))
                if isGround {
                    Circle().fill(BenchTheme.ink).frame(width: 4, height: 4)
                }
                if let pin = pendingPins.firstIndex(of: hole) {
                    Text(String(pin + 1))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(BenchTheme.bg)
                        .frame(width: 14, height: 14)
                        .background(BenchTheme.amber, in: Circle())
                        .offset(x: 14, y: -12)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hole \(hole.label)\(isGround ? ", ground reference" : "")")
        .accessibilityValue(isPending ? "Pending pin \((pendingPins.firstIndex(of: hole) ?? 0) + 1)" : (isSelected ? "Selected" : (isConnected ? "Connected net highlighted" : "")))
        .accessibilityHint(connectivityDescription(hole))
        .accessibilityIdentifier("hole_\(hole.label)")
    }

    private func wireButton(_ wire: BreadboardWire, index: Int) -> some View {
        Button { onWire(wire) } label: {
            Image(systemName: "link")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(wireTint(wire))
                .frame(width: 26, height: 22)
                .background(BenchTheme.bg.opacity(0.92), in: Capsule())
                .overlay(Capsule().strokeBorder(wireTint(wire).opacity(0.6)))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(wireMidpoint(wire, index: index))
        .accessibilityLabel("Wire \(wire.a.label) to \(wire.b.label)")
        .accessibilityHint("Inspect or remove this jumper.")
        .accessibilityIdentifier("wire_\(wire.id)")
    }

    private func componentButton(_ component: BreadboardComponent) -> some View {
        let selected = selectedComponentID == component.id
        let tint = componentTint(component)
        return Button { onComponent(component) } label: {
            VStack(spacing: 2) {
                HStack(spacing: 3) {
                    if component.kind.hasDeviceModel {
                        BreadboardDeviceSymbol(kind: component.kind, glow: ledGlow(component))
                            .frame(width: 22, height: 16)
                            .accessibilityHidden(true)
                    }
                    Text(componentSymbol(component))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Text(componentValue(component))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(tint)
            .frame(width: component.kind.isAnalog ? 70 : 62, height: 40)
            .background(BenchTheme.bg, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(tint.opacity(selected ? 1 : 0.6), lineWidth: selected ? 2 : 1))
            .shadow(color: Color.red.opacity(ledGlow(component) * 0.6), radius: ledGlow(component) * 9)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(componentPosition(component))
        .overlay {
            ForEach(Array(component.pins.enumerated()), id: \.offset) { index, pin in
                Text(pinCaption(component, index: index))
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 3)
                    .background(BenchTheme.bg.opacity(0.9), in: RoundedRectangle(cornerRadius: 3))
                    .position(x: position(of: pin).x, y: position(of: pin).y - 18)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("\(component.id), \(component.kind.title), \(componentValue(component)), pins \(component.pins.map(\.label).joined(separator: ", "))")
        .accessibilityValue(selected ? "Selected" : "")
        .accessibilityHint("Edit this component or remove it.")
        .accessibilityIdentifier("component_\(component.id)")
    }

    private var allHoles: [BreadboardHole] {
        (0..<12).flatMap { row in
            (0..<14).compactMap { rawColumn in
                BreadboardColumn(rawValue: rawColumn).map { BreadboardHole(row: row, column: $0) }
            }
        }
    }

    private func position(of hole: BreadboardHole) -> CGPoint {
        CGPoint(x: columnX(hole.column.rawValue), y: CGFloat(78 + hole.row * 44))
    }

    private func columnX(_ raw: Int) -> CGFloat {
        let positions: [CGFloat] = [30, 74, 130, 174, 218, 262, 306, 374, 418, 462, 506, 550, 606, 650]
        return positions[min(max(raw, 0), positions.count - 1)]
    }

    private func columnName(_ raw: Int) -> String {
        ["+", "−", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "+", "−"][raw]
    }

    private func columnTint(_ raw: Int) -> Color {
        if raw == 0 || raw == 12 { return BenchTheme.amber }
        if raw == 1 || raw == 13 { return BenchTheme.cyan }
        return BenchTheme.muted
    }

    private func componentPosition(_ component: BreadboardComponent) -> CGPoint {
        guard !component.pins.isEmpty else { return CGPoint(x: 340, y: 34) }
        let points = component.pins.map(position(of:))
        let divisor = CGFloat(points.count)
        let x = points.reduce(CGFloat(0)) { $0 + $1.x } / divisor
        let y = points.reduce(CGFloat(0)) { $0 + $1.y } / divisor
        // Offset a body between rows so most endpoint holes stay exposed.
        return CGPoint(x: min(max(x, 42), boardWidth - 42), y: min(max(y + 20, 60), boardHeight - 50))
    }

    private func wireBend(_ wire: BreadboardWire, index: Int) -> CGPoint {
        let a = position(of: wire.a)
        let b = position(of: wire.b)
        let span = hypot(b.x - a.x, b.y - a.y)
        let offset = min(max(span * 0.15, 18), 58) + CGFloat(index % 3) * 6
        return CGPoint(x: (a.x + b.x) / 2, y: max(48, (a.y + b.y) / 2 - offset))
    }

    private func wireCurve(_ wire: BreadboardWire, index: Int) -> Path {
        var path = Path()
        path.move(to: position(of: wire.a))
        path.addQuadCurve(to: position(of: wire.b), control: wireBend(wire, index: index))
        return path
    }

    private func wireMidpoint(_ wire: BreadboardWire, index: Int) -> CGPoint {
        let a = position(of: wire.a)
        let b = position(of: wire.b)
        let control = wireBend(wire, index: index)
        return CGPoint(x: 0.25 * a.x + 0.5 * control.x + 0.25 * b.x,
                       y: 0.25 * a.y + 0.5 * control.y + 0.25 * b.y)
    }

    private func wireTint(_ wire: BreadboardWire) -> Color {
        let palette = [BenchTheme.cyan, BenchTheme.amber, BenchTheme.green, Color(red: 0.88, green: 0.57, blue: 1)]
        let index = wire.id.utf8.reduce(0) { ($0 + Int($1)) % palette.count }
        return palette[index]
    }

    private func componentTint(_ component: BreadboardComponent) -> Color {
        switch component.kind {
        case .voltageSource, .currentSource: BenchTheme.amber
        case .capacitor, .inductor: BenchTheme.cyan
        case .resistor: BenchTheme.ink
        case .diode: BenchTheme.amber
        case .led: Color(red: 1, green: 0.35, blue: 0.3)
        case .npn, .pnp: BenchTheme.green
        case .nmos, .pmos: BenchTheme.cyan
        case .opAmp: Color(red: 0.88, green: 0.57, blue: 1)
        default: BenchTheme.green
        }
    }

    private func componentSymbol(_ component: BreadboardComponent) -> String {
        switch component.kind {
        case .resistor, .voltageSource, .logicInput: component.id
        case .currentSource: "\(component.id) →"
        case .capacitor: "\(component.id) ┃┃"
        case .inductor: "\(component.id) ∿"
        case .diode, .led, .npn, .pnp, .nmos, .pmos, .opAmp: component.id
        case .and: "\(component.id) AND"
        case .or: "\(component.id) OR"
        case .xor: "\(component.id) XOR"
        case .not: "\(component.id) NOT"
        case .nand: "\(component.id) NAND"
        case .nor: "\(component.id) NOR"
        case .xnor: "\(component.id) XNOR"
        }
    }

    private func componentValue(_ component: BreadboardComponent) -> String {
        switch component.kind {
        case .resistor: engineering(component.value, unit: "Ω")
        case .voltageSource: engineering(component.value, unit: "V")
        case .currentSource: engineering(component.value, unit: "A")
        case .capacitor: engineering(component.value, unit: "F")
        case .inductor: engineering(component.value, unit: "H")
        case .logicInput: component.logicValue.rawValue
        case .diode: "A→K"
        case .led: ledForwardCurrent(component).map { engineering(max($0, 0), unit: "A") } ?? "— A"
        case .npn: "NPN · CBE"
        case .pnp: "PNP · CBE"
        case .nmos: "NMOS · DGS"
        case .pmos: "PMOS · DGS"
        case .opAmp: "V+ / V−"
        default: "IDEAL LOGIC"
        }
    }

    private func ledForwardCurrent(_ component: BreadboardComponent) -> Double? {
        guard component.kind == .led else { return nil }
        return solution?.terminalCurrents[component.id]?.first ?? solution?.current(through: component.id)
    }

    /// The display scale is deliberately not an optical/lumen model.
    private func ledGlow(_ component: BreadboardComponent) -> Double {
        guard let current = ledForwardCurrent(component), current.isFinite, current > 0 else { return 0 }
        return min(log1p(current / 0.001) / log1p(0.02 / 0.001), 1)
    }

    private func pinCaption(_ component: BreadboardComponent, index: Int) -> String {
        let labels = component.kind.pinLabels
        return labels.indices.contains(index) ? labels[index] : String(index + 1)
    }

    private func connectivityDescription(_ hole: BreadboardHole) -> String {
        switch hole.column.rawValue {
        case 0, 1: "Connected to all 12 holes on this left rail."
        case 12, 13: "Connected to all 12 holes on this right rail."
        case 2...6: "Connected to A through E in row \(hole.row + 1)."
        default: "Connected to F through J in row \(hole.row + 1)."
        }
    }
}

/// Conventional terminal symbols, drawn natively rather than raster artwork.
private struct BreadboardDeviceSymbol: View {
    var kind: BreadboardComponentKind
    var glow: Double

    var body: some View {
        Canvas { context, size in
            func point(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: size.width * x / 22, y: size.height * y / 16)
            }
            func draw(_ points: [(Double, Double)], closed: Bool = false, fill: Bool = false) {
                guard let first = points.first else { return }
                var path = Path(); path.move(to: point(first.0, first.1))
                for p in points.dropFirst() { path.addLine(to: point(p.0, p.1)) }
                if closed { path.closeSubpath() }
                if fill { context.fill(path, with: .foreground) }
                else { context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round)) }
            }
            func arrow(from: (Double, Double), to: (Double, Double)) {
                draw([from, to])
                let dx = to.0 - from.0, dy = to.1 - from.1
                let length = max(hypot(dx, dy), 1)
                let ux = dx / length, uy = dy / length
                draw([to, (to.0 - ux * 3 - uy * 1.5, to.1 - uy * 3 + ux * 1.5),
                      (to.0 - ux * 3 + uy * 1.5, to.1 - uy * 3 - ux * 1.5)], closed: true, fill: true)
            }
            switch kind {
            case .diode, .led:
                draw([(0, 8), (5, 8)])
                draw([(5, 3), (12, 8), (5, 13)], closed: true)
                draw([(13, 3), (13, 13)])
                draw([(13, 8), (20, 8)])
                if kind == .led {
                    arrow(from: (12, 4), to: (16, 0))
                    arrow(from: (17, 6), to: (21, 2))
                    let rect = CGRect(x: size.width * 2 / 22, y: size.height * 2 / 16,
                                      width: size.width * 12 / 22, height: size.height * 12 / 16)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.red.opacity(glow * 0.3)))
                }
            case .npn, .pnp:
                draw([(0, 8), (7, 8)])
                draw([(7, 3), (7, 13)])
                draw([(7, 5), (18, 0)])
                draw([(7, 11), (18, 16)])
                if kind == .npn { arrow(from: (10, 12.4), to: (15, 14.8)) }
                else { arrow(from: (15, 14.8), to: (10, 12.4)) }
            case .nmos, .pmos:
                draw([(0, 8), (5, 8)])
                draw([(5, 3), (5, 13)])
                for y in [3.0, 7, 11] { draw([(9, y), (9, y + 2)]) }
                draw([(9, 4), (17, 4), (17, 0)])
                draw([(9, 12), (17, 12), (17, 16)])
                draw([(9, 8), (21, 8)])
                if kind == .nmos { arrow(from: (15, 8), to: (10, 8)) }
                else { arrow(from: (10, 8), to: (15, 8)) }
                draw([(21, 8), (21, 12), (17, 12)])
            case .opAmp:
                draw([(5, 1), (5, 15), (18, 8)], closed: true)
                draw([(0, 5), (5, 5)])
                draw([(0, 11), (5, 11)])
                draw([(18, 8), (22, 8)])
                draw([(10, 0), (10, 4)])
                draw([(10, 12), (10, 16)])
                draw([(7, 5), (10, 5)])
                draw([(8.5, 3.5), (8.5, 6.5)])
                draw([(7, 11), (10, 11)])
            default: break
            }
        }
    }
}
