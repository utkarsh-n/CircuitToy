import SwiftUI
import CircuitCore

struct CircuitBenchView: View {
    @Bindable var store: BenchStore
    @State private var editing: BoardPart?
    @State private var haptic = 0
    @State private var accountingID = ""
    @State private var accountingTime = 1.0
    var body: some View {
        let result = store.solution
        BenchScreen {
            BenchHeader(eyebrow: "01 / connect · measure · understand", title: "Circuit Toy", subtitle: "A little bench. Real electrical laws.")
            GlassEffectContainer {
                HStack {
                    Menu {
                        ForEach(BenchPreset.allCases) { preset in Button(preset.rawValue) { store.load(preset); haptic += 1 } }
                    } label: { Label("Examples", systemImage: "square.stack.3d.up") }
                    Spacer()
                    Button { store.undo(); haptic += 1 } label: { Image(systemName: "arrow.uturn.backward").frame(minWidth: 20) }
                        .disabled(!store.canUndo).accessibilityLabel("Undo circuit edit")
                    Button { editing = store.newPart() } label: { Label("Add", systemImage: "plus") }
                        .disabled(store.parts.count >= 20).accessibilityIdentifier("addComponent")
                }
                .buttonStyle(GlassActionStyle())
            }
            InstrumentPanel(title: "DC schematic", subtitle: "Tap a terminal to probe. Tap a part to edit.") {
                SchematicBoard(parts: store.parts, selectedNode: store.selectedNode, solution: try? result.get(), onNode: { store.selectedNode = $0; haptic += 1 }, onPart: { editing = $0 })
                    .frame(height: 300)
                HStack {
                    Label("Ground = 0 V", systemImage: "arrow.down.to.line")
                    Spacer()
                    Text("Conventional current a → b")
                }.font(.caption2).foregroundStyle(BenchTheme.muted)
            }
            resultPanel(result)
            InstrumentPanel(title: "Parts & branch currents") {
                ForEach(store.parts) { part in
                    Button { editing = part } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(part.name)  ·  \(part.displayValue)").font(.system(.subheadline, design: .monospaced, weight: .semibold))
                                Text("Terminal \(part.a) → \(part.b) · \(part.kind.rawValue)").font(.caption).foregroundStyle(BenchTheme.muted)
                            }
                            Spacer()
                            if let current = (try? result.get())?.current(through: part.id) {
                                Text(engineering(current, unit: "A")).font(.system(.subheadline, design: .monospaced)).foregroundStyle(BenchTheme.cyan)
                            }
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(BenchTheme.muted)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("part_\(part.name)")
                    if part.id != store.parts.last?.id { Divider().overlay(.white.opacity(0.05)) }
                }
            }
            InstrumentPanel(title: "First principles") {
                FormulaNote(equation: "V = IR    ΣI(node) = 0    ΣV(loop) = 0", explanation: "Resistance relates voltage to current. At every junction, charge is conserved. Around any closed loop, potential changes sum to zero. A source may supply or absorb energy; resistors absorb it.")
                Text("Try it: load Divider, then double R2. Predict the voltage at node 2 before tapping it.").font(.subheadline)
                Text("Model: ideal DC lumped circuit; linear resistors and independent sources. No wire resistance, parasitics, temperature, or component tolerances. A floating circuit or conflicting ideal sources has no unique solution.").font(.caption).foregroundStyle(BenchTheme.muted)
            }
            if let solution = try? result.get(), let first = store.parts.first(where: { $0.kind == .resistor }) ?? store.parts.first {
                let selected = store.parts.first(where: { $0.id == accountingID }) ?? first
                InstrumentPanel(title: "Charge & energy accounting", subtitle: "What an amp, a volt, and a watt actually mean.") {
                    Picker("Account for component", selection: Binding(get: { selected.id }, set: { accountingID = $0 })) {
                        ForEach(store.parts) { Text($0.name).tag($0.id) }
                    }.pickerStyle(.menu)
                    ParameterSlider(title: "Time interval", value: $accountingTime, range: 0.1...10, unit: "s")
                    let current = solution.current(through: selected.id) ?? 0
                    let power = solution.branchPowers[selected.id] ?? 0
                    HStack {
                        MeterValue(label: "Signed charge a → b", value: engineering(current * accountingTime, unit: "C"), unit: "")
                        MeterValue(label: "Energy absorbed", value: engineering(power * accountingTime, unit: "J"), unit: "", tint: BenchTheme.amber)
                    }
                    FormulaNote(equation: "Q = IΔt · W = PΔt\n1 A = 1 C/s · 1 V = 1 J/C", explanation: "Current counts charge crossing a terminal each second. Voltage tells you energy transferred per unit charge. Power counts joules per second. Charge is conserved; a resistor transfers electrical energy into heat rather than consuming charge.")
                    Text("Model: constant solved DC quantities over the selected interval. Signs follow a → b and the passive power convention; negative absorbed energy means the component supplies energy. This is charge accounting, not a microscopic animation of electrons.").font(.caption).foregroundStyle(BenchTheme.muted)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { part in PartEditor(part: part, isNew: !store.parts.contains(where: { $0.id == part.id }), onSave: store.save, onDelete: store.remove) }
        .sensoryFeedback(.selection, trigger: haptic)
    }
    @ViewBuilder private func resultPanel(_ result: Result<CircuitSolution, Error>) -> some View {
        switch result {
        case .success(let solution):
            InstrumentPanel(title: "Live instruments") {
                HStack(spacing: 12) {
                    MeterValue(label: "Probe · node \(store.selectedNode)", value: solution.voltage(at: store.selectedNode).map { String(format: "%.3f", $0) } ?? "—", unit: "V")
                    MeterValue(label: "KCL residual", value: String(format: "%.1e", solution.maximumKCLResidual), unit: "A", tint: BenchTheme.green)
                }
                if solution.voltage(at: store.selectedNode) == nil { Text("This terminal is unused. Connect a component to measure it.").font(.caption).foregroundStyle(BenchTheme.muted) }
                Text("Energy balance: \(engineering(solution.powerBalance, unit: "W")) · positive power is absorbed, negative power is supplied.")
                    .font(.caption).foregroundStyle(BenchTheme.muted)
            }.accessibilityIdentifier("liveInstruments")
        case .failure(let error):
            InstrumentPanel(title: "Check your connections") {
                Label("Circuit has no valid unique solution", systemImage: "exclamationmark.triangle").foregroundStyle(BenchTheme.amber)
                Text(error.localizedDescription).font(.caption).foregroundStyle(BenchTheme.muted)
                Text("Give every active node a DC path to ground. Avoid contradictory voltage sources. Undo or load an example to compare.").font(.subheadline)
            }.accessibilityIdentifier("circuitError")
        }
    }
}

private struct PartEditor: View {
    @State var part: BoardPart
    @State private var valueText: String
    var isNew: Bool
    var onSave: (BoardPart) -> Void
    var onDelete: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    init(part: BoardPart, isNew: Bool, onSave: @escaping (BoardPart) -> Void, onDelete: @escaping (String) -> Void) {
        _part = State(initialValue: part)
        _valueText = State(initialValue: String(part.value))
        self.isNew = isNew; self.onSave = onSave; self.onDelete = onDelete
    }
    private var parsedValue: Double? { Double(valueText.trimmingCharacters(in: .whitespaces)) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Component") {
                    TextField("Name", text: $part.name).autocorrectionDisabled()
                    Picker("Type", selection: $part.kind) { ForEach(PartKind.allCases) { Text($0.rawValue).tag($0) } }
                    HStack {
                        Text("Value (\(part.kind.unit))")
                        TextField("Value", text: $valueText)
                            .keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing)
                            .accessibilityLabel("Component value in \(part.kind.unit)").accessibilityIdentifier("componentValue")
                    }
                    ParameterSlider(title: part.kind.rawValue, value: $part.value, range: part.kind.range, unit: part.kind.unit, format: part.kind == .resistor ? "%.0f" : "%.2f")
                    if parsedValue == nil || !part.value.isFinite || !part.kind.range.contains(part.value) {
                        Text("Enter a value from \(part.kind.range.lowerBound.formatted()) to \(part.kind.range.upperBound.formatted()) \(part.kind.unit).").font(.caption).foregroundStyle(BenchTheme.amber)
                    }
                }
                Section("Connections") {
                    Picker("Terminal a", selection: $part.a) { ForEach(0...3, id: \.self) { Text($0 == 0 ? "0 · ground" : "Node \($0)").tag($0) } }
                    Picker("Terminal b", selection: $part.b) { ForEach(0...3, id: \.self) { Text($0 == 0 ? "0 · ground" : "Node \($0)").tag($0) } }
                    Text("Source voltage is V(a) − V(b). Positive branch current flows a → b.").font(.caption)
                    if part.a == part.b { Text("Choose two different terminals.").foregroundStyle(BenchTheme.amber) }
                }
                if !isNew { Section { Button("Remove component", role: .destructive) { onDelete(part.id); dismiss() } } }
            }
            .scrollContentBackground(.hidden).background(BenchTheme.bg)
            .navigationTitle(isNew ? "Add a component" : "Edit \(part.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(part); dismiss() }.disabled(part.a == part.b || part.name.trimmingCharacters(in: .whitespaces).isEmpty || parsedValue == nil || !part.value.isFinite || !part.kind.range.contains(part.value)).accessibilityIdentifier("saveComponent") }
            }
            .onChange(of: part.kind) { _, kind in part.value = kind == .resistor ? 1000 : kind == .voltage ? 5 : 1 }
            .onChange(of: valueText) { _, text in if let value = Double(text.trimmingCharacters(in: .whitespaces)) { part.value = value } }
            .onChange(of: part.value) { _, value in if parsedValue != value { valueText = String(format: "%.6g", value) } }
        }.tint(BenchTheme.cyan).preferredColorScheme(.dark)
    }
}

private struct SchematicBoard: View {
    var parts: [BoardPart]
    var selectedNode: Int
    var solution: CircuitSolution?
    var onNode: (Int) -> Void
    var onPart: (BoardPart) -> Void
    private func node(_ n: Int, _ s: CGSize) -> CGPoint {
        switch n {
        case 0: CGPoint(x: s.width * 0.18, y: s.height * 0.84)
        case 1: CGPoint(x: s.width * 0.18, y: s.height * 0.14)
        case 2: CGPoint(x: s.width * 0.82, y: s.height * 0.14)
        default: CGPoint(x: s.width * 0.82, y: s.height * 0.84)
        }
    }
    private func offset(_ part: BoardPart) -> CGFloat {
        let siblings = parts.filter { min($0.a, $0.b) == min(part.a, part.b) && max($0.a, $0.b) == max(part.a, part.b) }
        let index = siblings.firstIndex(where: { $0.id == part.id }) ?? 0
        return (CGFloat(index) - CGFloat(siblings.count - 1) / 2) * 38
    }
    private func center(_ part: BoardPart, _ size: CGSize) -> CGPoint {
        let a = node(part.a, size), b = node(part.b, size)
        let length = max(hypot(b.x - a.x, b.y - a.y), 1)
        let canonicalSign: CGFloat = part.a < part.b ? 1 : -1
        return CGPoint(x: (a.x + b.x) / 2 - (b.y - a.y) / length * offset(part) * canonicalSign,
                       y: (a.y + b.y) / 2 + (b.x - a.x) / length * offset(part) * canonicalSign)
    }
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                for x in stride(from: 4.0, to: size.width, by: 16) {
                    for y in stride(from: 4.0, to: size.height, by: 16) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.1, height: 1.1)), with: .color(BenchTheme.muted.opacity(0.2)))
                    }
                }
                for part in parts {
                    let a = node(part.a, size), b = node(part.b, size), c = center(part, size)
                    let length = max(hypot(b.x - a.x, b.y - a.y), 1)
                    let ux = (b.x - a.x) / length, uy = (b.y - a.y) / length
                    func local(_ x: CGFloat, _ y: CGFloat = 0) -> CGPoint { CGPoint(x: c.x + ux * x - uy * y, y: c.y + uy * x + ux * y) }
                    var wire = Path(); wire.move(to: a); wire.addLine(to: local(-28)); wire.move(to: local(28)); wire.addLine(to: b)
                    context.stroke(wire, with: .color(BenchTheme.cyan.opacity(0.65)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    var symbol = Path()
                    if part.kind == .resistor {
                        symbol.move(to: local(-28))
                        for index in 0..<9 { symbol.addLine(to: local(-24 + CGFloat(index) * 6, index == 0 || index == 8 ? 0 : index.isMultiple(of: 2) ? -7 : 7)) }
                        symbol.addLine(to: local(28))
                    } else {
                        symbol.addEllipse(in: CGRect(x: c.x - 18, y: c.y - 18, width: 36, height: 36))
                        symbol.move(to: local(-28)); symbol.addLine(to: local(-18)); symbol.move(to: local(18)); symbol.addLine(to: local(28))
                    }
                    context.stroke(symbol, with: .color(part.kind == .resistor ? BenchTheme.ink : BenchTheme.amber), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                    if part.kind == .voltage {
                        context.draw(Text("+").font(.system(size: 13, weight: .bold)).foregroundStyle(BenchTheme.amber), at: local(-8))
                        context.draw(Text("−").font(.system(size: 13, weight: .bold)).foregroundStyle(BenchTheme.amber), at: local(8))
                    } else if part.kind == .current {
                        var arrow = Path(); arrow.move(to: local(-8)); arrow.addLine(to: local(8)); arrow.move(to: local(3, -4)); arrow.addLine(to: local(8)); arrow.addLine(to: local(3, 4))
                        context.stroke(arrow, with: .color(BenchTheme.amber), lineWidth: 1.5)
                    }
                }
            }.accessibilityHidden(true)
            ForEach(parts) { part in
                let c = center(part, geo.size)
                Button { onPart(part) } label: {
                    VStack(spacing: 2) {
                        Text(part.name).font(.system(.caption, design: .monospaced, weight: .bold))
                        Text(part.displayValue).font(.system(.caption2, design: .monospaced))
                    }.padding(5).background(BenchTheme.panel.opacity(0.96), in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(part.kind == .resistor ? BenchTheme.ink : BenchTheme.amber)
                        .frame(minWidth: 44, minHeight: 44)
                }.buttonStyle(.plain).position(x: c.x, y: c.y + 31)
                    .accessibilityLabel("Edit \(part.name), \(part.displayValue), node \(part.a) to \(part.b)")
            }
            ForEach(0...3, id: \.self) { n in
                let p = node(n, geo.size)
                Button { onNode(n) } label: {
                    VStack(spacing: 3) {
                        Text(n == 0 ? "⏚" : "\(n)").font(.system(.subheadline, design: .monospaced, weight: .bold))
                            .frame(width: 26, height: 26).background(selectedNode == n ? BenchTheme.cyan : BenchTheme.bg, in: Circle())
                            .foregroundStyle(selectedNode == n ? BenchTheme.bg : BenchTheme.cyan)
                            .overlay(Circle().stroke(BenchTheme.cyan, lineWidth: 1))
                        if let voltage = solution?.voltage(at: n) { Text(String(format: "%.2f V", voltage)).font(.system(.caption2, design: .monospaced)).foregroundStyle(BenchTheme.cyan) }
                    }.frame(minWidth: 44, minHeight: 44)
                }.buttonStyle(.plain).position(p)
                    .accessibilityLabel("Probe node \(n)").accessibilityValue(solution?.voltage(at: n).map { engineering($0, unit: "V") } ?? "unused")
                    .accessibilityIdentifier("node\(n)")
            }
        }
    }
}
