import SwiftUI
import CircuitCore

struct BreadboardSandboxView: View {
    @Bindable var store: BreadboardStore
    @State private var tool = Tool.probe
    @State private var placing: BreadboardComponentKind?
    @State private var moving: BreadboardComponent?
    @State private var pins: [BreadboardHole] = []
    @State private var showPalette = false
    @State private var edited: BreadboardComponent?
    @State private var editedWire: BreadboardWire?
    @State private var feedback = 0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private enum Tool { case probe, wire, ground, edit }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                BenchHeader(eyebrow: "Your own circuit", title: "Breadboard", subtitle: "Place parts. Join contacts. Measure what your circuit does.").accessibilityIdentifier("sandboxRoot")
                modeControls
                boardControls
                placementInstruction
                BreadboardBoardView(document: store.document, connected: store.connected, pendingPins: pins,
                    selectedHole: store.selectedHole, selectedComponentID: store.selectedComponentID, holesArePrimary: placing != nil || tool != .edit,
                    solution: store.solution,
                    onHole: tapHole, onComponent: { select($0) }, onWire: { editedWire = $0 })
                Text("Pan the board in either direction. A–E and F–J connect within each row; the four labeled rails run continuously.")
                    .font(.caption).foregroundStyle(BenchTheme.muted)
                probes
                if store.document.mode == .analog { analysisControls }
                if let diagnostic = store.diagnostic {
                    Label(diagnostic, systemImage: "exclamationmark.triangle")
                        .font(.subheadline).foregroundStyle(BenchTheme.amber).accessibilityIdentifier("boardDiagnostic")
                    Text("Check the marked ground reference, open connections and ideal-source constraints.")
                        .font(.caption).foregroundStyle(BenchTheme.muted)
                }
                if let logic = store.logic {
                    ForEach(logic.diagnostics) { item in
                        Label(item.message, systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(BenchTheme.amber)
                    }
                }
                componentList
                modelNote
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .background(BenchTheme.bg.ignoresSafeArea()).foregroundStyle(BenchTheme.ink)
        .accessibilityIdentifier("sandboxScroll")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { liveProbeBar }
        .sheet(isPresented: $showPalette) { palette }
        .sheet(item: $edited) { component in
            BreadboardComponentEditor(component: component,
                onSave: { store.save($0); feedback += 1 },
                onMove: { moving = component; placing = component.kind; pins = []; edited = nil },
                onDelete: { store.removeComponent(component.id); feedback += 1 },
                onProbe: { store.selectCurrentProbe(component.id, terminalIndex: $0) })
        }
        .sheet(item: $editedWire) { wire in wireEditor(wire) }
        .sensoryFeedback(.selection, trigger: feedback)
        .onDisappear { store.isRunning = false }
        .task(id: store.isRunning) {
            guard store.isRunning else { return }
            while !Task.isCancelled && store.isRunning {
                do { try await Task.sleep(for: .milliseconds(50)) } catch { break }
                guard !Task.isCancelled && store.isRunning else { break }
                store.advance(steps: 10)
            }
        }
    }

    private var modeControls: some View {
        Picker("Signal model", selection: Binding(get: { store.document.mode }, set: { mode in
            cancelPlacement(); store.switchMode(mode)
        })) {
            ForEach(BreadboardMode.allCases) { Text($0.title).tag($0) }
        }.pickerStyle(.segmented).accessibilityIdentifier("boardMode")
    }
    private var liveProbeBar: some View {
        GlassEffectContainer {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.selectedHole.map { "\($0.label) · \(store.document.mode == .logic ? "logic" : "V to reference")" } ?? "Tap a contact")
                        .font(.caption2).foregroundStyle(BenchTheme.muted)
                    Text(store.document.mode == .logic ? store.probeLogic?.rawValue ?? "—" : store.probeVoltage.map { engineering($0, unit: "V") } ?? "—")
                        .font(.system(.title3, design: .monospaced, weight: .semibold)).foregroundStyle(BenchTheme.cyan)
                        .accessibilityIdentifier(store.document.mode == .logic ? "liveBoardLogic" : "liveBoardVoltage")
                }
                Spacer(minLength: 0)
                if store.document.mode == .analog {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(store.selectedComponentID == nil ? "Choose a terminal" : store.probeCurrentLabel).font(.caption2).foregroundStyle(BenchTheme.muted)
                        Text(store.probeCurrent.map { engineering($0, unit: "A") } ?? "—")
                            .font(.system(.title3, design: .monospaced, weight: .semibold)).foregroundStyle(BenchTheme.amber)
                            .accessibilityIdentifier("liveBoardCurrent")
                    }
                } else { Text("0 · 1 · X · Z").font(.system(.caption, design: .monospaced)).foregroundStyle(BenchTheme.muted) }
            }.padding(.horizontal, 16).padding(.vertical, 12)
                .background {
                    if reduceTransparency { RoundedRectangle(cornerRadius: 18).fill(BenchTheme.panel) }
                }
                .glassEffect(reduceTransparency ? .identity : .regular, in: .rect(cornerRadius: 18))
                .padding(.horizontal, 20).padding(.vertical, 8)
        }
    }
    private var boardControls: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button { showPalette = true } label: { Label("Add", systemImage: "plus") }
                    .disabled(store.document.components.count >= 32).accessibilityIdentifier("addBoardComponent")
                Menu {
                    Button("Empty board") { cancelPlacement(); store.load(.empty(mode: store.document.mode)) }
                        .accessibilityIdentifier("example_empty")
                    if store.document.mode == .analog {
                        Button("Voltage divider") { cancelPlacement(); store.load(.divider) }.accessibilityIdentifier("example_divider")
                        Button("RC charge") { cancelPlacement(); store.load(.rc); store.setAnalysis(.transient) }.accessibilityIdentifier("example_rc")
                        Button("Diode clipper") { loadDeviceExample(.diodeClipper) }.accessibilityIdentifier("exampleDiode")
                        Button("LED + resistor") { loadDeviceExample(.ledResistor) }.accessibilityIdentifier("exampleLED")
                        Button("NPN switch") { loadDeviceExample(.npnSwitch) }.accessibilityIdentifier("exampleNPN")
                        Button("MOSFET switch") { loadDeviceExample(.mosfetSwitch) }.accessibilityIdentifier("exampleMOSFET")
                        Button("Powered op-amp follower") { loadDeviceExample(.opAmpFollower) }.accessibilityIdentifier("exampleOpAmp")
                    } else {
                        Button("AND gate") { cancelPlacement(); store.load(.andGate) }.accessibilityIdentifier("example_and")
                    }
                } label: { Label("Examples", systemImage: "square.stack") }.accessibilityIdentifier("boardExamples")
                Spacer(minLength: 0)
                Button { cancelPlacement(); store.undo(); feedback += 1 } label: {
                    Image(systemName: "arrow.uturn.backward").frame(minWidth: 24)
                }.disabled(!store.canUndo).accessibilityLabel("Undo board edit").accessibilityIdentifier("undoBoardEdit")
            }.buttonStyle(GlassActionStyle())
        }
    }
    private var placementInstruction: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                toolButton("Probe", symbol: "scope", selected: tool == .probe && placing == nil, id: "probeTool") { cancelPlacement(); tool = .probe }
                toolButton("Wire", symbol: "point.topleft.down.to.point.bottomright.curvepath", selected: tool == .wire && placing == nil, id: "wireTool") { cancelPlacement(); tool = .wire }
                toolButton("Edit", symbol: "cursorarrow", selected: tool == .edit && placing == nil, id: "editBoardTool") { cancelPlacement(); tool = .edit }
                if store.document.mode == .analog {
                    toolButton("Ground", symbol: "arrow.down.to.line", selected: tool == .ground && placing == nil, id: "groundTool") { cancelPlacement(); tool = .ground }
                }
            }
            if let placing {
                HStack {
                    Text("\(moving == nil ? "Place" : "Move") \(placing.title): tap pin \(placing.pinLabels[min(pins.count, placing.pinCount - 1)]) (\(pins.count + 1)/\(placing.pinCount)).")
                        .font(.subheadline).foregroundStyle(BenchTheme.amber).accessibilityIdentifier("boardPlacementInstruction")
                    Spacer()
                    Button("Cancel", action: cancelPlacement).accessibilityIdentifier("cancelBoardPlacement")
                }
            } else if tool == .wire {
                Text(pins.isEmpty ? "Tap the first contact, then the second, to add an ideal jumper." : "Wire from \(pins[0].label): tap the other contact.")
                    .font(.subheadline).foregroundStyle(BenchTheme.amber)
            } else if tool == .ground {
                Text("Tap a contact to make its net the 0 V reference.").font(.subheadline).foregroundStyle(BenchTheme.amber)
            } else if tool == .edit {
                Text("Tap a component or jumper to edit, move or delete it.").font(.subheadline).foregroundStyle(BenchTheme.muted)
            } else {
                Text("Tap a hole to probe its net. Choose Edit or the parts list for branch current.")
                    .font(.subheadline).foregroundStyle(BenchTheme.muted)
            }
        }
    }
    private func toolButton(_ title: String, symbol: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.body)
                Text(title).font(.caption).lineLimit(1)
            }.frame(maxWidth: .infinity, minHeight: 44)
        }.accessibilityLabel(title)
            .buttonStyle(.bordered).tint(selected ? BenchTheme.cyan : BenchTheme.muted)
            .accessibilityAddTraits(selected ? [.isSelected] : []).accessibilityIdentifier(id)
    }
    private var probes: some View {
        InstrumentPanel(title: "Live probes") {
            HStack {
                Text(store.selectedHole.map { "Contact \($0.label)" } ?? "Choose a contact")
                Spacer()
                if store.document.mode == .analog { Text("Ref \(store.document.ground.label)") }
            }.font(.system(.caption, design: .monospaced)).foregroundStyle(BenchTheme.muted)
            if store.document.mode == .logic {
                Text(store.probeLogic?.rawValue ?? "—").font(.system(size: 42, weight: .semibold, design: .monospaced))
                    .foregroundStyle(BenchTheme.green).accessibilityIdentifier("probeLogic")
                    .accessibilityLabel("Logic probe").accessibilityValue(store.probeLogic?.rawValue ?? "unavailable")
                Text("0 / 1 are Boolean values. X is unknown or conflicting; Z is undriven.").font(.caption).foregroundStyle(BenchTheme.muted)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    probeReading("Voltage to reference", value: store.probeVoltage.map { engineering($0, unit: "V") } ?? "—", id: "probeVoltage", tint: BenchTheme.cyan)
                    probeReading(store.selectedComponentID == nil ? "Terminal current" : store.probeCurrentLabel, value: store.probeCurrent.map { engineering($0, unit: "A") } ?? "—", id: "probeCurrent", tint: BenchTheme.amber)
                }
                if let component = store.selectedComponent, component.kind.isAnalog {
                    Text(component.pins.count == 2
                         ? "Positive current: \(component.pins[0].label) → \(component.pins[1].label). Current probes observe a branch without adding impedance."
                         : "Terminal currents are positive into \(component.id). Their sum is zero; the output can source a negative terminal current.")
                        .font(.caption).foregroundStyle(BenchTheme.muted)
                    if component.kind.hasDeviceModel { terminalReadings(component) }
                } else { Text("Select a component for branch current. Current in an ideal jumper is not uniquely defined by this net model.").font(.caption).foregroundStyle(BenchTheme.muted) }
                if let solution = store.solution {
                    Text("KCL residual \(engineering(solution.maximumKCLResidual, unit: "A")) · power balance \(engineering(solution.powerBalance, unit: "W"))")
                        .font(.system(.caption2, design: .monospaced)).foregroundStyle(BenchTheme.muted)
                } else if store.analysis == .transient, store.diagnostic == nil {
                    Text("Initial reactive state is loaded. Step or Run to obtain the first solved measurement.")
                        .font(.caption).foregroundStyle(BenchTheme.muted).accessibilityIdentifier("boardAwaitingStep")
                }
                if store.voltageSamples.count > 1, let first = store.samples.first,
                   let last = store.samples.last, last.time > first.time {
                    LessonPlot(traces: [LessonTrace(values: store.voltageSamples, color: BenchTheme.cyan, name: "Contact voltage")],
                        xRange: first.time...last.time,
                        yRange: plotRange(store.voltageSamples), xLabel: "Simulation time / s", yLabel: "Voltage / V")
                }
            }
        }
    }
    private func probeReading(_ title: String, value: String, id: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(BenchTheme.muted)
            Text(value).font(.system(.title2, design: .monospaced, weight: .semibold)).foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.65).accessibilityIdentifier(id).accessibilityLabel(title).accessibilityValue(value)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var analysisControls: some View {
        InstrumentPanel(title: "Analysis") {
            HStack {
                Button("DC") { store.setAnalysis(.dc) }.accessibilityIdentifier("dcAnalysis")
                Button("Transient") { store.setAnalysis(.transient) }.accessibilityIdentifier("transientAnalysis")
                Spacer()
                Text(store.analysis.rawValue).foregroundStyle(BenchTheme.cyan)
            }.buttonStyle(.bordered)
            if store.analysis == .transient {
                HStack {
                    Text("t = \(String(format: "%.4f", store.elapsedTime)) s").monospacedDigit()
                        .accessibilityIdentifier("boardElapsedTime")
                        .accessibilityValue(String(store.elapsedTime))
                    Spacer()
                    Menu("Δt \(engineering(store.timeStep, unit: "s"))") {
                        ForEach([0.0001, 0.001, 0.01], id: \.self) { dt in
                            Button(engineering(dt, unit: "s")) { store.setTimeStep(dt) }
                                .accessibilityIdentifier("boardTimeStep_\(dt)")
                        }
                    }.accessibilityIdentifier("boardTimeStep")
                }.font(.system(.subheadline, design: .monospaced))
                HStack {
                    Button { store.isRunning.toggle() } label: { Label(store.isRunning ? "Pause" : "Run", systemImage: store.isRunning ? "pause.fill" : "play.fill") }
                        .accessibilityIdentifier("runBoardSimulation").disabled(store.diagnostic != nil || store.document.components.isEmpty)
                    Button("Step") { store.isRunning = false; store.advance() }.accessibilityIdentifier("stepBoardSimulation")
                        .disabled(store.diagnostic != nil || store.document.components.isEmpty)
                    Button("Reset") { store.reset() }.accessibilityIdentifier("resetBoardSimulation")
                }.buttonStyle(GlassActionStyle())
                Text("Fixed-step backward Euler. Simulation time advances independently of wall time. Editing the circuit or Δt resets to the specified initial state; reduce Δt to check convergence.")
                    .font(.caption).foregroundStyle(BenchTheme.muted)
            } else { Text("Steady state: capacitors are open circuits and inductors are ideal shorts. Measurements refresh after each edit.").font(.caption).foregroundStyle(BenchTheme.muted) }
            if store.document.components.contains(where: { $0.kind.hasDeviceModel }) {
                Text("Nonlinear devices are solved together using their terminal equations. A failed operating point is reported as unavailable; it is never replaced by a fixed voltage drop.")
                    .font(.caption).foregroundStyle(BenchTheme.muted)
            }
        }
    }
    private var componentList: some View {
        InstrumentPanel(title: "Parts & jumpers") {
            if store.document.components.isEmpty { Text("Add a part, then choose its contacts on the board.").foregroundStyle(BenchTheme.muted) }
            ForEach(store.document.components) { part in
                HStack {
                    Button { select(part) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(part.id) · \(part.kind.title)").font(.headline)
                            Text(part.pins.map(\.label).joined(separator: " → ") + " · " + partSummary(part))
                                .font(.system(.caption, design: .monospaced)).foregroundStyle(BenchTheme.muted)
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("part_\(part.id)")
                    if part.kind == .logicInput {
                        Button(part.logicValue.rawValue) { store.toggleInput(part.id); feedback += 1 }
                            .frame(minWidth: 44, minHeight: 44).buttonStyle(.bordered).accessibilityIdentifier("toggle_\(part.id)")
                            .accessibilityLabel("Toggle \(part.id)").accessibilityValue(part.logicValue.rawValue)
                    }
                }
            }
            ForEach(store.document.wires) { wire in
                Button { editedWire = wire } label: {
                    Label("\(wire.id) · \(wire.a.label) ↔ \(wire.b.label)", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("jumper_\(wire.id)")
            }
            Text("Autosaved separately for Analog and Logic. Undo restores the previous board edit.").font(.caption).foregroundStyle(BenchTheme.muted)
        }
    }
    private var modelNote: some View {
        FormulaNote(equation: store.document.mode == .analog ? "ΣI = 0 · V = IR · I_C = C dV/dt · V_L = L dI/dt" : "Ideal 0 / 1 / X / Z nets",
            explanation: store.document.mode == .analog
                ? "Modified nodal analysis couples R/L/C, sources, Shockley junctions with series resistance, reciprocal Ebers–Moll BJTs, long-channel MOSFETs with body diodes, and powered finite-gain op-amps. Models disclose omitted breakdown, self-heating, device capacitance and op-amp frequency dynamics. Contacts, jumpers and probes are ideal."
                : "The same Boolean gates and equal-strength driver resolution as the logic lessons. No analog voltage thresholds or propagation timing. Feedback gates are conservatively marked X; this is not a transistor or latch simulation.")
    }
    private var palette: some View {
        NavigationStack {
            List(BreadboardComponentKind.allCases.filter { $0.isAnalog == (store.document.mode == .analog) }) { kind in
                Button { placing = kind; moving = nil; pins = []; showPalette = false } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text(kind.title); Spacer(); Text("\(kind.pinCount) pin\(kind.pinCount == 1 ? "" : "s")").foregroundStyle(.secondary) }
                        Text(kind.pinLabels.joined(separator: " · ")).font(.caption.monospaced()).foregroundStyle(.secondary)
                        if kind == .opAmp { Text("Wire both supply pins and a return path.").font(.caption).foregroundStyle(.secondary) }
                    }.frame(minHeight: 44)
                }.accessibilityIdentifier("palette_\(kind.rawValue)")
            }.accessibilityIdentifier("boardPalette")
                .navigationTitle("Add a component").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showPalette = false } } }
        }.presentationDetents([.medium, .large]).tint(BenchTheme.cyan)
    }
    private func wireEditor(_ wire: BreadboardWire) -> some View {
        NavigationStack {
            Form {
                Text("\(wire.id): \(wire.a.label) ↔ \(wire.b.label)")
                Text("An ideal jumper joins these contacts into one net. Its individual current is not determined after net merging.")
                Button("Delete jumper", role: .destructive) { store.removeWire(wire.id); editedWire = nil; feedback += 1 }.accessibilityIdentifier("deleteBoardWire")
            }.accessibilityIdentifier("boardWireEditorForm")
                .navigationTitle("Jumper").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { editedWire = nil } } }
        }.presentationDetents([.medium]).tint(BenchTheme.cyan)
    }
    private func tapHole(_ hole: BreadboardHole) {
        store.selectedHole = hole
        if let kind = placing {
            guard !pins.contains(hole) else { return }
            pins.append(hole); feedback += 1
            if pins.count == kind.pinCount {
                if var part = moving { part.pins = pins; store.save(part) }
                else { store.add(kind, pins: pins) }
                cancelPlacement()
            }
        } else if tool == .wire {
            if let first = pins.first {
                if first != hole { store.addWire(from: first, to: hole); pins = []; feedback += 1 }
            } else { pins = [hole] }
        } else if tool == .ground { store.setGround(hole); tool = .probe; feedback += 1 }
    }
    private func select(_ part: BreadboardComponent) { store.selectedComponentID = part.id; edited = part }
    private func loadDeviceExample(_ document: BreadboardDocument) {
        cancelPlacement(); store.load(document); store.setAnalysis(.dc)
        if let device = document.components.first(where: { $0.kind.hasDeviceModel }) {
            store.selectCurrentProbe(device.id)
            let index = device.kind.primaryCurrentTerminal
            if device.pins.indices.contains(index) { store.selectedHole = device.pins[index] }
        }
    }
    private func terminalReadings(_ component: BreadboardComponent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(component.kind.pinLabels.enumerated()), id: \.offset) { index, label in
                HStack {
                    Button { store.selectCurrentProbe(component.id, terminalIndex: index) } label: {
                        Text("Probe \(label)").font(.caption).frame(minHeight: 44)
                    }.buttonStyle(.bordered).tint(BenchTheme.cyan)
                        .accessibilityLabel("Probe \(component.id) \(label) terminal current")
                        .accessibilityIdentifier("selectTerminalCurrent_\(component.id)_\(index)")
                    Spacer()
                    Text(terminalCurrent(component.id, index: index).map { engineering($0, unit: "A") } ?? "—")
                        .font(.system(.subheadline, design: .monospaced)).foregroundStyle(BenchTheme.amber)
                        .accessibilityIdentifier("terminalCurrent_\(component.id)_\(index)")
                        .accessibilityLabel("\(component.id) \(label) current")
                        .accessibilityValue(terminalCurrent(component.id, index: index).map { engineering($0, unit: "A") } ?? "unavailable")
                }
            }
            Text(component.modelSummary).font(.caption).foregroundStyle(BenchTheme.muted)
            if component.kind == .led {
                Text("The LED glow follows solved forward current. It illustrates current level and is not a calibrated brightness or lumen model.")
                    .font(.caption).foregroundStyle(BenchTheme.muted)
            }
        }
    }
    private func terminalCurrent(_ id: String, index: Int) -> Double? {
        guard let values = store.solution?.terminalCurrents[id], values.indices.contains(index) else { return nil }
        return values[index]
    }
    private func cancelPlacement() { placing = nil; moving = nil; pins = []; tool = .probe }
    private func partSummary(_ part: BreadboardComponent) -> String {
        part.kind.hasDeviceModel ? part.modelSummary : part.kind == .logicInput ? part.logicValue.rawValue : part.kind.isAnalog ? engineering(part.value, unit: part.kind.unit) : part.kind.pinLabels.joined(separator: ", ")
    }
    private func plotRange(_ values: [Double]) -> ClosedRange<Double> {
        let lower = min(values.min() ?? 0, 0), upper = max(values.max() ?? 0, 0)
        let padding = max((upper - lower) * 0.1, 0.01)
        return (lower - padding)...(upper + padding)
    }
}

private struct BreadboardComponentEditor: View {
    let component: BreadboardComponent
    let onSave: (BreadboardComponent) -> Void
    let onMove: () -> Void
    let onDelete: () -> Void
    let onProbe: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var valueText = ""
    @State private var initialText = ""
    @State private var logicValue = LogicLevel.zero
    @State private var parameterText: [String: String] = [:]
    @State private var error: String?
    @FocusState private var focusedField: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Contacts") {
                    ForEach(component.pins.indices, id: \.self) { index in
                        LabeledContent(component.kind.pinLabels[index], value: component.pins[index].label)
                    }
                    if component.kind == .opAmp {
                        Text("Five independent terminals: both input nets, output and both supplies. V+ must be above V−; feedback and a complete supply return path are required for a follower.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Move: choose new contacts") { onMove(); dismiss() }.accessibilityIdentifier("moveBoardComponent")
                }
                if component.kind.hasDeviceModel {
                    Section("Device profile") {
                        Text(component.modelSummary).font(.subheadline)
                        Text(deviceAssumptions).font(.caption).foregroundStyle(.secondary)
                        Button("Restore default device profile") { restoreProfile() }
                            .accessibilityIdentifier("restoreDeviceProfile_\(component.id)")
                    }
                    Section("Model parameters · SI units") {
                        ForEach(parameters) { parameter in parameterRow(parameter) }
                    }
                } else if component.kind.isAnalog {
                    Section("Value · \(displayUnit)") {
                        TextField("Value", text: $valueText).keyboardType(.numbersAndPunctuation)
                            .focused($focusedField, equals: "value").accessibilityIdentifier("boardComponentValue")
                        HStack {
                            ForEach(commonValues, id: \.self) { value in
                                Button(engineering(value * displayScale, unit: component.kind.unit)) { valueText = String(value) }
                                    .accessibilityIdentifier(presetIdentifier(value))
                            }
                        }.buttonStyle(.bordered)
                    }
                    if component.kind == .capacitor || component.kind == .inductor {
                        Section(component.kind == .capacitor ? "Initial voltage · V" : "Initial current · A") {
                            TextField("Initial state", text: $initialText).keyboardType(.numbersAndPunctuation)
                                .focused($focusedField, equals: "initial").accessibilityIdentifier("boardInitialState")
                        }
                    }
                } else if component.kind == .logicInput {
                    Picker("Drive", selection: $logicValue) { ForEach(LogicLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        .pickerStyle(.segmented).accessibilityIdentifier("boardLogicDrive")
                }
                if component.kind.isAnalog {
                    Section("Current probes") {
                        Button(primaryCurrentLabel) { onProbe(component.kind.primaryCurrentTerminal); dismiss() }
                            .accessibilityIdentifier("probeBranchCurrent_\(component.id)")
                        if component.kind.hasDeviceModel {
                            ForEach(Array(component.kind.pinLabels.enumerated()), id: \.offset) { index, label in
                                Button("Probe \(label) terminal current") { onProbe(index); dismiss() }
                                    .frame(minHeight: 44)
                                    .accessibilityIdentifier("probeTerminalCurrent_\(component.id)_\(index)")
                            }
                        }
                        Text(component.pins.count == 2
                             ? "Positive branch current enters the first contact and leaves the second."
                             : "Each terminal current is positive into the device. Output or supply currents may be negative.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button("Delete component", role: .destructive) { onDelete(); dismiss() }.accessibilityIdentifier("deleteBoardComponent")
            }.accessibilityIdentifier("boardEditorForm")
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if let error {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                            Text(error).font(.subheadline).foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("boardComponentError")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(.red.opacity(0.1))
                    }
                }
                .navigationTitle("\(component.id) · \(component.kind.title)")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.accessibilityIdentifier("cancelBoardComponent") }
                    ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).accessibilityIdentifier("saveBoardComponent") }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { focusedField = nil }.accessibilityIdentifier("doneBoardKeyboard")
                    }
                }
        }.tint(BenchTheme.cyan).presentationDetents([.large]).interactiveDismissDisabled()
            .onAppear {
                valueText = String(component.value / displayScale)
                initialText = String(component.initialValue)
                logicValue = component.logicValue
                parameterText = Dictionary(uniqueKeysWithValues: parameters.map { ($0.field, numericText($0.value)) })
            }
    }

    private func parameterRow(_ parameter: DeviceParameter) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(parameter.title).font(.subheadline)
                Spacer()
                Text(parameter.unit.isEmpty ? "unitless" : parameter.unit).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                TextField(parameter.title, text: Binding(get: { parameterText[parameter.field] ?? numericText(parameter.value) },
                                                        set: { parameterText[parameter.field] = $0; error = nil }))
                    .keyboardType(.numbersAndPunctuation).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($focusedField, equals: parameter.field)
                    .font(.system(.subheadline, design: .monospaced)).frame(minHeight: 44)
                    .accessibilityLabel("\(parameter.title), \(parameter.unit.isEmpty ? "unitless" : parameter.unit)")
                    .accessibilityIdentifier("deviceParameter_\(component.id)_\(parameter.field)")
                Button { adjust(parameter, direction: -1) } label: { Image(systemName: "minus").frame(width: 44, height: 44) }
                    .accessibilityLabel("Decrease \(parameter.title)")
                    .accessibilityIdentifier("decreaseDeviceParameter_\(component.id)_\(parameter.field)")
                Button { adjust(parameter, direction: 1) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .accessibilityLabel("Increase \(parameter.title)")
                    .accessibilityIdentifier("increaseDeviceParameter_\(component.id)_\(parameter.field)")
            }.buttonStyle(.bordered)
            Text(parameter.explanation).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func adjust(_ parameter: DeviceParameter, direction: Double) {
        guard let value = Double(parameterText[parameter.field] ?? numericText(parameter.value)), value.isFinite else { return }
        let step = parameter.absoluteStep ?? (value == 0 ? parameter.zeroStep : abs(value) * 0.1)
        let result = value + direction * step
        guard result.isFinite else { return }
        parameterText[parameter.field] = numericText(max(parameter.allowsZero ? 0 : Double.leastNonzeroMagnitude, result))
        error = nil
    }

    private func restoreProfile() {
        let defaults = BreadboardComponent(id: component.id, kind: component.kind, pins: component.pins, value: component.value)
        parameterText = Dictionary(uniqueKeysWithValues: parameters(for: defaults).map { ($0.field, numericText($0.value)) })
        error = nil
    }

    private var parameters: [DeviceParameter] { parameters(for: component) }
    private func parameters(for part: BreadboardComponent) -> [DeviceParameter] {
        switch part.kind {
        case .diode, .led:
            return diodeParameters(part.diodeModel)
        case .npn, .pnp:
            return [
                .init(field: "saturationCurrent", title: "Transport saturation current Iₛ", unit: "A", value: part.bjtModel.saturationCurrent, explanation: "The reciprocal transport scale is shared by forward and reverse junction equations.", zeroStep: 1e-15),
                .init(field: "forwardBeta", title: "Forward current gain βF", unit: "", value: part.bjtModel.forwardBeta, explanation: "Forward active collector-to-base current ratio.", zeroStep: 1),
                .init(field: "reverseBeta", title: "Reverse current gain βR", unit: "", value: part.bjtModel.reverseBeta, explanation: "Reverse operation uses its own reciprocal gain.", zeroStep: 0.1),
                .init(field: "temperatureKelvin", title: "Junction temperature", unit: "K", value: part.bjtModel.temperatureKelvin, explanation: "Thermal voltage is kT/q; this is a fixed model temperature.", absoluteStep: 5)
            ]
        case .nmos, .pmos:
            return [
                .init(field: "thresholdVoltage", title: "Threshold magnitude |Vth|", unit: "V", value: part.mosfetModel.thresholdVoltage, explanation: "PMOS polarity is handled by the device type; enter a positive threshold magnitude.", absoluteStep: 0.1),
                .init(field: "transconductance", title: "Square-law coefficient β", unit: "A/V²", value: part.mosfetModel.transconductance, explanation: "In saturation, |I| = β(|VGS|−|Vth|)²/2 before channel-length modulation.", zeroStep: 0.001),
                .init(field: "channelLengthModulation", title: "Channel-length modulation λ", unit: "1/V", value: part.mosfetModel.channelLengthModulation, explanation: "Adds finite output conductance to the long-channel model.", allowsZero: true, absoluteStep: 0.01)
            ] + diodeParameters(part.mosfetModel.bodyDiode, prefix: "bodyDiode")
        case .opAmp:
            return [
                .init(field: "openLoopGain", title: "Open-loop voltage gain", unit: "V/V", value: part.opAmpModel.openLoopGain, explanation: "Finite gain relates input difference to the internal commanded output.", zeroStep: 1),
                .init(field: "outputResistance", title: "Output-stage resistance", unit: "Ω", value: part.opAmpModel.outputResistance, explanation: "The load current produces a voltage drop in the output stage.", zeroStep: 1),
                .init(field: "currentLimit", title: "Output current limit", unit: "A", value: part.opAmpModel.currentLimit, explanation: "The output cannot source or sink arbitrary load current.", zeroStep: 0.001),
                .init(field: "railHeadroom", title: "Output rail headroom", unit: "V", value: part.opAmpModel.railHeadroom, explanation: "Keeps the internal output away from each supply rail.", allowsZero: true, absoluteStep: 0.01),
                .init(field: "quiescentCurrent", title: "Supply quiescent current", unit: "A", value: part.opAmpModel.quiescentCurrent, explanation: "Flows from V+ to V− in addition to output-stage supply current.", allowsZero: true, zeroStep: 0.0001)
            ]
        default: return []
        }
    }

    private func diodeParameters(_ model: DiodeModel, prefix: String = "") -> [DeviceParameter] {
        func key(_ field: String) -> String { prefix.isEmpty ? field : prefix + field.prefix(1).uppercased() + String(field.dropFirst()) }
        let titlePrefix = prefix.isEmpty ? "" : "Body diode · "
        return [
            .init(field: key("saturationCurrent"), title: titlePrefix + "Saturation current Iₛ", unit: "A", value: model.saturationCurrent, explanation: "Shockley scale current; enter scientific notation such as 1e-12.", zeroStep: model.saturationCurrent * 0.1),
            .init(field: key("idealityFactor"), title: titlePrefix + "Ideality factor n", unit: "", value: model.idealityFactor, explanation: "Controls the slope of the exponential current–voltage relation.", absoluteStep: 0.1),
            .init(field: key("temperatureKelvin"), title: titlePrefix + "Junction temperature", unit: "K", value: model.temperatureKelvin, explanation: "The electrical model uses thermal voltage kT/q at this fixed temperature.", absoluteStep: 5),
            .init(field: key("seriesResistance"), title: titlePrefix + "Series resistance", unit: "Ω", value: model.seriesResistance, explanation: "Current creates an additional voltage drop inside the device.", allowsZero: true, absoluteStep: 10)
        ]
    }

    private var deviceAssumptions: String {
        switch component.kind {
        case .diode: "Shockley junction plus series resistance. Reverse breakdown, junction capacitance and self-heating are omitted."
        case .led: "A red LED electrical profile, not a fixed forward voltage. Glow indicates solved forward current; optical efficiency and lumens are not modeled."
        case .npn, .pnp: "Reciprocal Ebers–Moll at the specified temperature. Junction capacitance, Early effect, avalanche and self-heating are omitted."
        case .nmos, .pmos: "Long-channel square law with channel-length modulation and a body diode tied to S. Gate DC current is zero; body effect, subthreshold conduction, capacitance and breakdown are omitted."
        case .opAmp: "A powered finite-gain output stage with resistance, current limiting and rail headroom. Inputs must stay within the actual supply rails under a rail-to-rail input assumption. Input currents are zero; bandwidth, slew rate and offset are omitted."
        default: ""
        }
    }

    private var primaryCurrentLabel: String {
        switch component.kind {
        case .opAmp: "Probe output current"
        case .npn, .pnp: "Probe collector current"
        case .nmos, .pmos: "Probe drain current"
        default: "Probe branch current"
        }
    }

    private var displayScale: Double { switch component.kind { case .currentSource: 0.001; case .capacitor: 0.000001; case .inductor: 0.001; default: 1 } }
    private var displayUnit: String { switch component.kind { case .currentSource: "mA"; case .capacitor: "µF"; case .inductor: "mH"; default: component.kind.unit } }
    private var commonValues: [Double] { switch component.kind { case .resistor: [100, 1000, 2000]; case .voltageSource: [1.5, 5, 12]; case .currentSource: [1, 5, 10]; case .capacitor: [1, 100, 1000]; case .inductor: [1, 10, 100]; default: [] } }
    private func presetIdentifier(_ value: Double) -> String {
        let scaled = value * displayScale
        return scaled.rounded() == scaled ? "value_\(Int(scaled))" : "value_\(component.kind.rawValue)_\(value)"
    }
    private func numericText(_ value: Double) -> String { String(value) }

    private func save() {
        var next = component
        if component.kind.hasDeviceModel {
            for parameter in parameters {
                guard let value = Double(parameterText[parameter.field] ?? numericText(parameter.value)), value.isFinite else {
                    error = "Enter a finite value for \(parameter.title)."; return
                }
                setDeviceParameter(parameter.field, value: value, part: &next)
            }
        } else if component.kind.isAnalog {
            guard let value = Double(valueText), value.isFinite,
                  let initial = Double(initialText), initial.isFinite else { error = "Enter finite numeric values."; return }
            let scaled = value * displayScale
            guard scaled.isFinite else { error = "This value exceeds the numeric range."; return }
            if [.resistor, .capacitor, .inductor].contains(component.kind), scaled <= 0 { error = "This component needs a positive value."; return }
            next.value = scaled; next.initialValue = initial
        } else { next.logicValue = logicValue }
        do {
            try BreadboardDocument(mode: next.kind.isAnalog ? .analog : .logic, components: [next]).validate()
            onSave(next); dismiss()
        } catch { self.error = error.localizedDescription }
    }

    private func setDeviceParameter(_ field: String, value: Double, part: inout BreadboardComponent) {
        switch part.kind {
        case .diode, .led: setDiodeParameter(field, value: value, model: &part.diodeModel)
        case .npn, .pnp:
            switch field {
            case "saturationCurrent": part.bjtModel.saturationCurrent = value
            case "forwardBeta": part.bjtModel.forwardBeta = value
            case "reverseBeta": part.bjtModel.reverseBeta = value
            case "temperatureKelvin": part.bjtModel.temperatureKelvin = value
            default: break
            }
        case .nmos, .pmos:
            switch field {
            case "thresholdVoltage": part.mosfetModel.thresholdVoltage = value
            case "transconductance": part.mosfetModel.transconductance = value
            case "channelLengthModulation": part.mosfetModel.channelLengthModulation = value
            default:
                if field.hasPrefix("bodyDiode") {
                    let suffix = String(field.dropFirst("bodyDiode".count))
                    let key = suffix.prefix(1).lowercased() + String(suffix.dropFirst())
                    setDiodeParameter(key, value: value, model: &part.mosfetModel.bodyDiode)
                }
            }
        case .opAmp:
            switch field {
            case "openLoopGain": part.opAmpModel.openLoopGain = value
            case "outputResistance": part.opAmpModel.outputResistance = value
            case "currentLimit": part.opAmpModel.currentLimit = value
            case "railHeadroom": part.opAmpModel.railHeadroom = value
            case "quiescentCurrent": part.opAmpModel.quiescentCurrent = value
            default: break
            }
        default: break
        }
    }

    private func setDiodeParameter(_ field: String, value: Double, model: inout DiodeModel) {
        switch field {
        case "saturationCurrent": model.saturationCurrent = value
        case "idealityFactor": model.idealityFactor = value
        case "temperatureKelvin": model.temperatureKelvin = value
        case "seriesResistance": model.seriesResistance = value
        default: break
        }
    }
}

private struct DeviceParameter: Identifiable {
    var field: String
    var title: String
    var unit: String
    var value: Double
    var explanation: String
    var allowsZero = false
    var absoluteStep: Double? = nil
    var zeroStep: Double = 1
    var id: String { field }
}
