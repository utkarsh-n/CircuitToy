import SwiftUI
import CircuitCore

struct LogicLabView: View {
    @State private var mode = 0
    @State private var gate = LogicGate.and
    @State private var inputA = LogicLevel.one
    @State private var inputB = LogicLevel.zero
    @State private var wordA: UInt64 = 7
    @State private var wordB: UInt64 = 1
    @State private var carryIn = false
    @State private var data = false
    @State private var clock = false
    @State private var flipFlop = DFlipFlop()
    @State private var haptic = 0
    private var output: LogicLevel { (try? gate.evaluate(gate == .not ? [inputA] : [inputA, inputB])) ?? .unknown }
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "04 / from Flips to logic boards", title: "Bits become circuits", subtitle: "A switch becomes a signal. Gates turn signals into decisions, arithmetic, and memory.")
            Picker("Logic experiment", selection: $mode) { Text("Gates").tag(0); Text("Adder").tag(1); Text("Memory").tag(2) }
                .pickerStyle(.segmented).accessibilityIdentifier("logicMode")
            if mode == 0 { gateExperiment }
            if mode == 1 { adderExperiment }
            if mode == 2 { memoryExperiment }
            InstrumentPanel(title: "Model boundary") {
                Text(CircuitModel.logicLimits).font(.caption).foregroundStyle(BenchTheme.muted)
                Text("0 and 1 represent logical levels, not universal voltages. Real CMOS thresholds depend on supply and device family. X is unknown; Z is undriven. A gate treats Z as unknown unless a controlling input determines its output.").font(.subheadline)
            }
        }.sensoryFeedback(.selection, trigger: haptic)
    }
    private var gateExperiment: some View {
        VStack(spacing: 20) {
            InstrumentPanel(title: "Combinational logic") {
                Picker("Gate", selection: $gate) { ForEach(LogicGate.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu)
                    .accessibilityIdentifier("gatePicker")
                HStack(spacing: 16) {
                    VStack(spacing: 12) {
                        signalButton("A", value: inputA) { inputA = inputA == .one ? .zero : .one; haptic += 1 }
                        if gate != .not { signalButton("B", value: inputB) { inputB = inputB == .one ? .zero : .one; haptic += 1 } }
                    }
                    Rectangle().fill(BenchTheme.cyan.opacity(0.6)).frame(height: 2)
                    Text(gate.rawValue).font(.system(.title3, design: .monospaced, weight: .bold))
                        .frame(width: 90, height: 85).background(BenchTheme.bg, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(BenchTheme.cyan.opacity(0.6)))
                    Rectangle().fill(output == .one ? BenchTheme.green : BenchTheme.muted).frame(height: 2)
                    VStack(spacing: 8) {
                        Text("OUT").font(.caption2).foregroundStyle(BenchTheme.muted)
                        Text(output.rawValue).font(.system(.largeTitle, design: .monospaced, weight: .bold)).foregroundStyle(output == .one ? BenchTheme.green : BenchTheme.amber)
                    }.accessibilityElement(children: .combine).accessibilityIdentifier("gateOutput")
                }.padding(.vertical, 12)
                Picker("A state", selection: $inputA) { ForEach(LogicLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                if gate != .not { Picker("B state", selection: $inputB) { ForEach(LogicLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented) }
                Text(gateRule).font(.subheadline).foregroundStyle(BenchTheme.muted)
            }
            InstrumentPanel(title: "Truth table", subtitle: "Tap a row to apply that pair of inputs.") {
                HStack { Text("A"); if gate != .not { Text("B") }; Spacer(); Text(gate.rawValue) }.font(.system(.caption, design: .monospaced)).foregroundStyle(BenchTheme.muted)
                ForEach(0..<(gate == .not ? 2 : 4), id: \.self) { index in
                    let a = LogicLevel(gate == .not ? index == 1 : index / 2 == 1)
                    let b = LogicLevel(index % 2 == 1)
                    let out = (try? gate.evaluate(gate == .not ? [a] : [a, b])) ?? .unknown
                    Button { inputA = a; inputB = b; haptic += 1 } label: {
                        HStack { Text(a.rawValue); if gate != .not { Text(b.rawValue) }; Spacer(); Text(out.rawValue) }
                            .font(.system(.headline, design: .monospaced)).padding(.horizontal, 12).frame(minHeight: 44)
                            .foregroundStyle(BenchTheme.ink)
                            .background(inputA == a && (gate == .not || inputB == b) ? BenchTheme.cyan.opacity(0.13) : BenchTheme.bg.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).accessibilityLabel("A \(a.rawValue)\(gate == .not ? "" : ", B \(b.rawValue)"), output \(out.rawValue)")
                }
            }
        }
    }
    private var gateRule: String {
        switch gate {
        case .and: "AND outputs 1 only when both inputs are 1. A known 0 controls the output even when the other input is unknown."
        case .or: "OR outputs 1 when at least one input is 1. A known 1 controls the output even when the other input is unknown."
        case .not: "NOT inverts a known bit. An unknown or undriven input produces X."
        case .nand: "NAND is an AND followed by inversion. NAND gates alone can construct any Boolean function."
        case .nor: "NOR is an OR followed by inversion. NOR gates alone can construct any Boolean function."
        case .xor: "XOR outputs 1 when the two known bits differ. This is the sum bit of a half adder."
        case .xnor: "XNOR outputs 1 when two known bits match. Unknown inputs leave equality uncertain."
        }
    }
    @ViewBuilder private var adderExperiment: some View {
        let result = try? RippleAdder.add(a: wordA, b: wordB, width: 4, carryIn: LogicLevel(carryIn))
        InstrumentPanel(title: "Four-bit ripple adder", subtitle: "Tap bits. Carry flows from low weight to high weight.") {
            bitWord("A", value: wordA) { wordA ^= UInt64(1) << $0; haptic += 1 }
            bitWord("B", value: wordB) { wordB ^= UInt64(1) << $0; haptic += 1 }
            Toggle("Carry in", isOn: $carryIn).tint(BenchTheme.cyan)
            Divider()
            if let result, let sum = result.unsignedValue {
                Text("\(wordA) + \(wordB) + \(carryIn ? 1 : 0) = \(sum + (result.carryOut == .one ? 16 : 0))")
                    .font(.system(.title2, design: .monospaced, weight: .semibold)).foregroundStyle(BenchTheme.green)
                    .accessibilityIdentifier("adderResult")
                HStack {
                    Text("\(result.carryOut.rawValue) | \(result.bits.reversed().map(\.rawValue).joined())").font(.system(.title, design: .monospaced)).foregroundStyle(BenchTheme.cyan)
                    Spacer()
                    Text("carry | low 4 bits").font(.caption).foregroundStyle(BenchTheme.muted)
                }
                Text(result.carries.enumerated().map { "c\($0.offset)=\($0.element.rawValue)" }.joined(separator: " → "))
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(BenchTheme.amber).fixedSize(horizontal: false, vertical: true)
            }
        }
        InstrumentPanel(title: "One stage at a time") {
            FormulaNote(equation: "S = A ⊕ B ⊕ Cᵢₙ\nCₒᵤₜ = AB + Cᵢₙ(A ⊕ B)", explanation: "Each full adder produces one sum bit and one carry. That carry becomes the next stage's input. This is the circuit underneath the carry behavior in Flips. Here, + means Boolean OR in the carry equation.")
            Text("Try it: set A = 15 and B = 1. All four low bits become 0; carry out records the extra 16.").font(.subheadline)
        }
    }
    private func bitWord(_ title: String, value: UInt64, toggle: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("\(title) · decimal \(value)").font(.system(.subheadline, design: .monospaced)).foregroundStyle(BenchTheme.muted)
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach([3, 2, 1, 0], id: \.self) { index in
                        let isOn = value & (UInt64(1) << index) != 0
                        Button { toggle(index) } label: {
                            VStack(spacing: 4) { Text("\(1 << index)").font(.caption2); Text(isOn ? "1" : "0").font(.system(.title2, design: .monospaced, weight: .semibold)) }
                                .foregroundStyle(isOn ? BenchTheme.cyan : BenchTheme.muted).frame(maxWidth: .infinity).frame(minHeight: 64)
                        }.buttonStyle(GlassActionStyle()).accessibilityLabel("\(title) bit \(index), weight \(1 << index)")
                            .accessibilityValue(isOn ? "1" : "0").accessibilityIdentifier("adder\(title)bit\(index)")
                    }
                }
            }
        }
    }
    private var memoryExperiment: some View {
        VStack(spacing: 20) {
            InstrumentPanel(title: "Positive-edge D flip-flop") {
                HStack {
                    signalButton("D", value: LogicLevel(data)) { data.toggle(); haptic += 1 }
                    Spacer()
                    Text("D → [ ↑CLK ] → Q").font(.system(.headline, design: .monospaced)).foregroundStyle(BenchTheme.muted)
                    Spacer()
                    Text(flipFlop.q.rawValue).font(.system(.largeTitle, design: .monospaced, weight: .bold)).foregroundStyle(BenchTheme.green).accessibilityLabel("Stored Q \(flipFlop.q.rawValue)").accessibilityIdentifier("flipFlopQ")
                }
                Button {
                    clock.toggle(); flipFlop.tick(data: LogicLevel(data), clock: LogicLevel(clock)); haptic += 1
                } label: { Label(clock ? "Clock high · lower clock" : "Clock low · raise clock", systemImage: "waveform.path") }
                    .buttonStyle(GlassActionStyle()).accessibilityIdentifier("clockToggle")
                Button("Reset to unknown") { flipFlop = DFlipFlop(); clock = false; haptic += 1 }.buttonStyle(GlassActionStyle(tint: BenchTheme.amber))
                Text("D = \(data ? 1 : 0) · CLK = \(clock ? 1 : 0) · Q = \(flipFlop.q.rawValue)").font(.system(.subheadline, design: .monospaced))
            }
            InstrumentPanel(title: "A circuit that remembers") {
                FormulaNote(equation: "Qₙ₊₁ = D at the rising clock edge", explanation: "Change D while the clock is already high: Q holds its previous value. Lower the clock, then raise it: Q captures D. Before the first known edge, the stored value is X.")
                Text("Model: ideal edge-triggered storage. Setup time, hold time, metastability, propagation delay, and analog clock behavior are outside this experiment.").font(.caption).foregroundStyle(BenchTheme.muted)
            }
        }
    }
    private func signalButton(_ label: String, value: LogicLevel, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) { Text(label).font(.caption); Text(value.rawValue).font(.system(.title2, design: .monospaced, weight: .bold)) }
                .frame(minWidth: 44, minHeight: 58).foregroundStyle(value == .one ? BenchTheme.cyan : BenchTheme.muted)
        }.buttonStyle(GlassActionStyle()).accessibilityLabel("Input \(label)").accessibilityValue(value.rawValue).accessibilityIdentifier("input\(label)")
    }
}
