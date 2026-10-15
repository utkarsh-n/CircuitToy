import SwiftUI

struct EngineeringLessonLab: View {
    let lessonID: String
    var body: some View {
        BenchScreen {
            switch lessonID {
            case "sequential": EngineeringSequentialLab()
            case "digital-timing": EngineeringTimingLab()
            case "machines": EngineeringMachinesLab()
            case "converters": EngineeringConvertersLab()
            case "architecture": EngineeringArchitectureLab()
            case "embedded": EngineeringEmbeddedLab()
            case "hardware-design": EngineeringHardwareLab()
            default: Text("This engineering experiment is unavailable.")
            }
        }
    }
}

private struct EngPrediction: View {
    let prompt: String
    let choices: [String]
    let correct: Int
    @State private var selection = 0
    @State private var checked = false
    var body: some View {
        InstrumentPanel(title: "Predict, then check") {
            Text(prompt).font(.subheadline)
            Picker("Prediction", selection: $selection) {
                ForEach(choices.indices, id: \.self) { Text(choices[$0]).tag($0) }
            }.pickerStyle(.segmented)
            Button("Check prediction") { checked = true }.buttonStyle(GlassActionStyle()).accessibilityIdentifier("checkLessonReasoning")
            if checked {
                Label(selection == correct ? "Correct for these model settings." : "Try again: the model predicts \(choices[correct]).", systemImage: selection == correct ? "checkmark.circle" : "arrow.clockwise")
                    .font(.subheadline).foregroundStyle(selection == correct ? BenchTheme.green : BenchTheme.amber)
            }
        }.onChange(of: correct) { _, _ in checked = false }
    }
}

private struct EngLimits: View {
    let text: String
    let title: String
    let url: String
    var body: some View {
        InstrumentPanel(title: "Model & reference") {
            Text(text).font(.caption).foregroundStyle(BenchTheme.muted)
            if let link = URL(string: url) { Link(title, destination: link).font(.caption).frame(minHeight: 44) }
        }
    }
}

private struct EngineeringSequentialLab: View {
    @State private var model = EngineeringModels.Sequential()
    @State private var data = 5
    @State private var enable = true
    @State private var serialBit = true
    @State private var history: [String] = []
    var body: some View {
        BenchHeader(eyebrow: "Storage → counter → state machine", title: "One edge changes state", subtitle: "Clock a register and counter while a small machine searches for 101.")
        InstrumentPanel(title: "Synchronous board", subtitle: "D[3:0] → register · enable → counter · serial input → 101 detector") {
            Stepper("Register input D = \(data) · \(String(data, radix: 2))₂", value: $data, in: 0...15)
            Toggle("Counter enabled", isOn: $enable).tint(BenchTheme.cyan)
            Toggle("Serial input bit = \(serialBit ? 1 : 0)", isOn: $serialBit).tint(BenchTheme.amber)
            HStack {
                MeterValue(label: "Stored register", value: "\(model.register)", unit: "")
                MeterValue(label: "Counter mod 16", value: "\(model.counter)", unit: "", tint: BenchTheme.green)
                MeterValue(label: "Rising edges", value: "\(model.edges)", unit: "", tint: BenchTheme.amber)
            }
            Text("Detector: S\(model.detectorState) · \(model.detected ? "101 found on the last rising edge" : "no match on the last rising edge")")
                .font(.headline).foregroundStyle(model.detected ? BenchTheme.green : BenchTheme.muted)
            Button(model.clock ? "Clock HIGH → lower" : "Clock LOW → raise") {
                let wasLow = !model.clock
                model.setClock(!model.clock, data: data, enable: enable, bit: serialBit)
                if wasLow {
                    history.append("edge \(model.edges): D=\(data), Q=\(model.register), count=\(model.counter), input=\(serialBit ? 1 : 0), S\(model.detectorState), match=\(model.detected ? 1 : 0)")
                    history = Array(history.suffix(8))
                }
            }.buttonStyle(GlassActionStyle()).accessibilityIdentifier("sequentialClock")
            Button("Reset state") { model = .init(); history = [] }.buttonStyle(GlassActionStyle(tint: BenchTheme.amber))
            ForEach(Array(history.enumerated()), id: \.offset) { _, line in Text(line).font(.caption.monospaced()).foregroundStyle(BenchTheme.muted) }
        }
        InstrumentPanel(title: "Transition table") {
            Text("S0: no suffix · S1: suffix 1 · S2: suffix 10").font(.caption)
            ForEach(0..<3, id: \.self) { state in
                let zero = EngineeringModels.sequence101(state: state, bit: false)
                let one = EngineeringModels.sequence101(state: state, bit: true)
                Text("S\(state): input 0 → S\(zero.state); input 1 → S\(one.state)\(one.detected ? " + MATCH" : "")").font(.subheadline.monospaced())
            }
            FormulaNote(equation: "Q⁺ = D at ↑CLK · count⁺ = (count + enable) mod 16", explanation: "Changing input while the clock is high does not update state. The detector retains the suffix needed for overlapping matches: 10101 has two matches.")
        }
        EngPrediction(prompt: "If the counter is enabled, will its NEXT rising edge wrap to zero?", choices: ["Yes", "No"], correct: model.counter == 15 ? 0 : 1)
        EngLimits(text: "Ideal binary edge-triggered register, modulo counter and deterministic Mealy machine. Reset initializes known zero state. No gate delays, analog voltages, setup/hold or metastability model.", title: "MIT · Finite state machines", url: "https://ocw.mit.edu/courses/6-004-computation-structures-spring-2009/resources/mit6_004s09_lec06/")
        .sensoryFeedback(.selection, trigger: model.edges)
    }
}

private struct EngineeringTimingLab: View {
    @State private var period = 6.0
    @State private var maximumDelay = 4.0
    @State private var minimumDelay = 0.5
    @State private var skew = 0.0
    @State private var riseDelay = 5.0
    @State private var fallDelay = 2.0
    @State private var consensus = false
    private var margins: EngineeringModels.Timing? {
        try? EngineeringModels.timing(periodNS: period, clockToQMaxNS: 0.8, clockToQMinNS: 0.2, logicMaxNS: maximumDelay, logicMinNS: minimumDelay, setupNS: 0.3, holdNS: 0.15, skewNS: skew)
    }
    var body: some View {
        BenchHeader(eyebrow: "Time is part of a logic design", title: "Margins & hazards", subtitle: "Functional correctness and timing correctness answer different questions.")
        InstrumentPanel(title: "Register → logic → register", subtitle: "tCQ max/min = 0.8/0.2 ns · setup/hold = 0.3/0.15 ns") {
            ParameterSlider(title: "Clock period", value: $period, range: 2...12, unit: "ns")
            ParameterSlider(title: "Maximum logic delay", value: $maximumDelay, range: 2...10, unit: "ns")
            ParameterSlider(title: "Minimum logic delay", value: $minimumDelay, range: 0...2, unit: "ns")
            ParameterSlider(title: "Destination clock skew", value: $skew, range: -1...1, unit: "ns")
            if let margins {
                HStack {
                    MeterValue(label: "Setup margin", value: String(format: "%.2f", margins.setupMargin), unit: "ns", tint: margins.setupMargin >= 0 ? BenchTheme.green : BenchTheme.amber)
                    MeterValue(label: "Hold margin", value: String(format: "%.2f", margins.holdMargin), unit: "ns", tint: margins.holdMargin >= 0 ? BenchTheme.green : BenchTheme.amber)
                }
                Text(margins.passes ? "Both constraints pass in this timing model." : "A negative margin is a timing violation; captured data is not guaranteed.").font(.subheadline)
            }
            FormulaNote(equation: "setup margin = T + skew − tCQ,max − tlogic,max − tsetup\nhold margin = tCQ,min + tlogic,min − skew − thold", explanation: "Positive skew makes the destination edge later: it helps setup but hurts hold. Lengthening the clock period does not fix a hold violation.")
        }
        InstrumentPanel(title: "Static-1 hazard", subtitle: "F = AB + ¬AC · B=C=1 · A rises at 2 ns") {
            ParameterSlider(title: "AB rising path delay", value: $riseDelay, range: 0.5...8, unit: "ns")
            ParameterSlider(title: "¬AC falling path delay", value: $fallDelay, range: 0.5...8, unit: "ns")
            Toggle("Add consensus term BC", isOn: $consensus).tint(BenchTheme.green)
            LessonPlot(traces: [.init(values: (0...240).map { EngineeringModels.hazard(timeNS: Double($0) / 20, riseDelayNS: riseDelay, fallDelayNS: fallDelay, consensus: consensus) }, color: BenchTheme.cyan, name: "F")], xRange: 0...12, yRange: -0.1...1.1, xLabel: "Time · ns", yLabel: "Logic level")
            Text("Low pulse width: \(String(format: "%.2f", consensus ? 0 : max(0, riseDelay - fallDelay))) ns").font(.headline.monospaced())
            FormulaNote(equation: "AB + ¬AC + BC = AB + ¬AC", explanation: "The consensus term does not change the steady Boolean truth table. With B=C=1 it supplies a continuously high path, removing this static-1 hazard.")
        }
        EngPrediction(prompt: "Do the present register-path settings guarantee both setup and hold?", choices: ["Yes", "No"], correct: margins?.passes == true ? 0 : 1)
        EngLimits(text: "Specified min/max propagation constraints and a transport-delay hazard example with 0.2 ns OR delay. Timing failure means lack of guarantee; the app does not fabricate a metastable waveform, failure probability or transistor transition. Real gates can suppress narrow pulses through inertial behavior.", title: "MIT · Sequential logic timing", url: "https://ocw.mit.edu/courses/6-004-computation-structures-spring-2017/pages/c5/c5s1/")
    }
}

private struct EngineeringMachinesLab: View {
    @State private var primaryVoltage = 24.0
    @State private var turns = 200.0
    @State private var load = 50.0
    @State private var motorVoltage = 12.0
    @State private var resistance = 2.0
    @State private var torque = 0.15
    private let constant = 0.1
    private var transformer: EngineeringModels.Transformer? { try? EngineeringModels.transformer(primaryRMS: primaryVoltage, primaryTurns: 100, secondaryTurns: turns, loadOhms: load) }
    private var motor: EngineeringModels.Motor? { try? EngineeringModels.motor(volts: motorVoltage, resistance: resistance, constant: constant, loadTorque: torque) }
    var body: some View {
        BenchHeader(eyebrow: "Conservation connects fields and motion", title: "Transform & turn", subtitle: "An ideal transformer trades voltage for current. A motor trades electrical power for motion and heat.")
        InstrumentPanel(title: "100-turn primary → transformer → resistive load") {
            ParameterSlider(title: "Primary RMS voltage", value: $primaryVoltage, range: 1...120, unit: "V")
            ParameterSlider(title: "Secondary turns", value: $turns, range: 25...400, unit: "turns", format: "%.0f")
            ParameterSlider(title: "Secondary load", value: $load, range: 10...200, unit: "Ω")
            if let t = transformer {
                HStack {
                    MeterValue(label: "Secondary RMS", value: engineering(t.secondaryRMS, unit: "V"), unit: "")
                    MeterValue(label: "Primary RMS current", value: engineering(t.primaryCurrentRMS, unit: "A"), unit: "")
                }
                Text("Secondary current \(engineering(t.secondaryCurrentRMS, unit: "A")) · reflected load \(engineering(t.reflectedResistance, unit: "Ω"))").font(.caption)
                Text("Input \(engineering(t.inputPower, unit: "W")) = output \(engineering(t.outputPower, unit: "W"))").font(.headline.monospaced()).foregroundStyle(BenchTheme.green)
                LessonPlot(traces: [.init(values: (0...120).map { sqrt(2) * primaryVoltage * sin(2 * .pi * Double($0) / 120) }, color: BenchTheme.amber, name: "Primary"), .init(values: (0...120).map { sqrt(2) * t.secondaryRMS * sin(2 * .pi * Double($0) / 120) }, color: BenchTheme.cyan, name: "Secondary")], xRange: 0...1, yRange: (-sqrt(2) * max(primaryVoltage, t.secondaryRMS) * 1.1)...(sqrt(2) * max(primaryVoltage, t.secondaryRMS) * 1.1), xLabel: "One normalized AC cycle", yLabel: "Voltage · V")
            }
            FormulaNote(equation: "V₂/V₁ = N₂/N₁ · I₁/I₂ = N₂/N₁ · Rref = Rload(N₁/N₂)²", explanation: "Current magnitudes use primary input and secondary load directions. With both port currents defined INTO the transformer, the secondary current changes sign and p₁+p₂=0.")
        }
        InstrumentPanel(title: "Steady-state permanent-magnet DC motor", subtitle: "kₜ = kₑ = 0.1 in SI · torque equals load torque") {
            ParameterSlider(title: "Armature supply", value: $motorVoltage, range: 1...24, unit: "V")
            ParameterSlider(title: "Armature resistance", value: $resistance, range: 0.5...5, unit: "Ω")
            ParameterSlider(title: "Load torque", value: $torque, range: 0...0.8, unit: "N·m", format: "%.3f")
            if let m = motor {
                if m.motoring {
                    HStack {
                        MeterValue(label: "Speed", value: String(format: "%.1f", m.speed), unit: "rad/s")
                        MeterValue(label: "Current", value: engineering(m.current, unit: "A"), unit: "", tint: BenchTheme.amber)
                    }
                    Text("Pinput \(engineering(m.inputPower, unit: "W")) = Pshaft \(engineering(m.mechanicalPower, unit: "W")) + Pcopper \(engineering(m.copperLoss, unit: "W"))").font(.caption.monospaced())
                } else { Text("This load exceeds steady motoring stall torque. No positive-speed steady motoring point exists; the app does not clamp speed to create one.").foregroundStyle(BenchTheme.amber) }
                Text("Stall torque \(engineering(m.stallTorque, unit: "N·m")) · back EMF \(engineering(m.backEMF, unit: "V"))").font(.caption)
            }
            FormulaNote(equation: "τ = kI · E = kω · V = RI + E · VI = τω + I²R", explanation: "At zero load this frictionless steady-state model draws zero current. Raising load torque increases current and copper loss while reducing speed.")
        }
        EngPrediction(prompt: "For the CURRENT motor settings, is positive-speed steady motoring possible?", choices: ["Yes", "No"], correct: (motor?.speed ?? -1) > 0 ? 0 : 1)
        EngLimits(text: "Ideal sinusoidal lossless transformer: no saturation, leakage inductance, magnetizing current or winding losses. Motor is an algebraic steady-state PM model with armature copper loss; no inertia, inductive transient, friction, commutation or thermal limits. No induction/synchronous-machine simulation.", title: "MIT · Motor torque and back EMF", url: "https://www.mit.edu/course/2/2.010/www_f00/psets/hw2_dir/tutor2_dir/tut2_h.html")
        Link("MIT · Ideal transformer and AC networks", destination: URL(string: "https://ocw.mit.edu/courses/6-061-introduction-to-electric-power-systems-spring-2011/c6393a58319200a5344752de0cf47ec4_MIT6_061S11_ch3.pdf")!).font(.caption).frame(minHeight: 44)
    }
}

private struct EngineeringConvertersLab: View {
    @State private var mode = 0
    @State private var input = 12.0
    @State private var duty = 0.5
    @State private var inductance = 100.0
    @State private var frequency = 50.0
    @State private var load = 10.0
    @State private var phaseVoltage = 120.0
    @State private var ra = 40.0
    @State private var rb = 40.0
    @State private var rc = 40.0
    private var buck: EngineeringModels.Buck? { try? EngineeringModels.buck(input: input, duty: duty, inductance: inductance * 1e-6, frequency: frequency * 1000, load: load) }
    private var three: EngineeringModels.ThreePhase? { try? EngineeringModels.threePhase(phaseRMS: phaseVoltage, resistances: [ra, rb, rc]) }
    var body: some View {
        BenchHeader(eyebrow: "Switch energy · balance phases", title: "Converters & three phases", subtitle: "Inspect an ideal buck's conduction boundary and a four-wire resistive AC load.")
        Picker("Power experiment", selection: $mode) { Text("Buck").tag(0); Text("Three phase").tag(1) }.pickerStyle(.segmented)
        if mode == 0 { buckPanel } else { phasesPanel }
    }
    private var buckPanel: some View {
        VStack(spacing: 20) {
            InstrumentPanel(title: "Ideal diode buck · steady periodic CCM", subtitle: "Source → PWM switch → L → resistive load; large output capacitor") {
                ParameterSlider(title: "Input voltage", value: $input, range: 3...24, unit: "V")
                ParameterSlider(title: "Duty ratio", value: $duty, range: 0.05...0.95, unit: "")
                ParameterSlider(title: "Inductance", value: $inductance, range: 10...1000, unit: "µH")
                ParameterSlider(title: "Switch frequency", value: $frequency, range: 10...200, unit: "kHz")
                ParameterSlider(title: "Load resistance", value: $load, range: 1...100, unit: "Ω")
                if let b = buck {
                    if b.continuousConduction {
                        HStack {
                            MeterValue(label: "Output DC", value: engineering(b.output, unit: "V"), unit: "")
                            MeterValue(label: "Ripple peak-to-peak", value: engineering(b.ripple, unit: "A"), unit: "", tint: BenchTheme.amber)
                        }
                        LessonPlot(traces: [.init(values: (0...240).map { b.current(at: Double($0) / 80, duty: duty) }, color: BenchTheme.cyan, name: "Inductor current")], xRange: 0...3, yRange: 0...(b.maximumCurrent * 1.1), xLabel: "Switch periods", yLabel: "Current · A")
                        Text("Imin \(engineering(b.minimumCurrent, unit: "A")) > 0 · Pin = Pout = \(engineering(b.outputPower, unit: "W"))").font(.caption.monospaced())
                    } else {
                        Text("CCM condition fails: candidate Imin = \(engineering(b.minimumCurrent, unit: "A")). At/below zero, this diode-buck CCM waveform and D·Vin ratio are not a valid DCM solution. Increase L/f or reduce load resistance.").foregroundStyle(BenchTheme.amber)
                    }
                }
                FormulaNote(equation: "Vout ≈ D·Vin · ΔI = (Vin−Vout)D/(Lfₛ)\nCCM requires Iout > ΔI/2", explanation: "Volt-second balance sets the ideal conversion ratio. Current rises during the on-time and falls during off-time. The large-capacitor approximation neglects output ripple.")
            }
            EngPrediction(prompt: "Do the present settings satisfy the strict CCM condition?", choices: ["Yes", "No"], correct: buck?.continuousConduction == true ? 0 : 1)
            EngLimits(text: "Ideal diode/switch and inductor with nearly constant output voltage. Only CCM is evaluated; DCM, startup, ESR, switch loss, feedback and device ratings are not simulated. A forced synchronous converter allowing reverse current is a different model.", title: "TI · Power topologies handbook", url: "https://www.ti.com/lit/eb/slyu036a/slyu036a.pdf")
        }
    }
    private var phasesPanel: some View {
        VStack(spacing: 20) {
            InstrumentPanel(title: "Balanced source → four-wire wye resistive load", subtitle: "Neutral is solidly connected; source phases differ by 120°") {
                ParameterSlider(title: "Phase-to-neutral RMS", value: $phaseVoltage, range: 10...240, unit: "V")
                ParameterSlider(title: "Phase A resistance", value: $ra, range: 10...100, unit: "Ω")
                ParameterSlider(title: "Phase B resistance", value: $rb, range: 10...100, unit: "Ω")
                ParameterSlider(title: "Phase C resistance", value: $rc, range: 10...100, unit: "Ω")
                Button("Balance the load to phase A") { rb = ra; rc = ra }.buttonStyle(GlassActionStyle())
                if let t = three {
                    HStack { MeterValue(label: "Neutral RMS", value: engineering(t.neutralRMS, unit: "A"), unit: ""); MeterValue(label: "Average total power", value: engineering(t.averagePower, unit: "W"), unit: "", tint: BenchTheme.green) }
                    let power = (0...180).map { index -> Double in
                        let v = EngineeringModels.phaseVoltages(angle: Double(index) / 180 * 2 * .pi, phaseRMS: phaseVoltage)
                        return zip(v, [ra, rb, rc]).reduce(0) { $0 + $1.0 * $1.0 / $1.1 }
                    }
                    LessonPlot(traces: [.init(values: power, color: BenchTheme.green, name: "Total instantaneous power")], xRange: 0...1, yRange: 0...max(1, (power.max() ?? 1) * 1.1), xLabel: "One line cycle", yLabel: "Power · W")
                    Text("IA / IB / IC: \(t.currentsRMS.map { engineering($0, unit: "A") }.joined(separator: " / "))").font(.caption)
                }
                FormulaNote(equation: "vₖ = √2 Vrms sin(ωt − 2πk/3)\np_total = Σ vₖ²/Rₖ · i_neutral = −Σ iₖ", explanation: "Equal resistances give constant total instantaneous power and zero neutral current. Unequal resistances cause a neutral current even with a balanced source.")
            }
            EngPrediction(prompt: "Is neutral RMS current zero to numerical tolerance for this load?", choices: ["Yes", "No"], correct: (three?.neutralRMS ?? 1) < 1e-9 ? 0 : 1)
            EngLimits(text: "Ideal balanced sinusoidal source, three linear resistors and a solid neutral. This is four-wire wye, not a floating-neutral three-wire network. No line impedance, protection, harmonics, generators or grid load-flow solver.", title: "MIT · Three-phase systems", url: "https://ocw.mit.edu/courses/6-622-power-electronics-spring-2023/mit6_622_s23_lec212.pdf")
        }
    }
}

private struct EngineeringArchitectureLab: View {
    @State private var inputA = 7
    @State private var inputB = 5
    @State private var mode = 0
    @State private var cpu = EngineeringModels.CPU(inputA: 7, inputB: 5)
    @State private var error = ""
    @State private var predicted = 12
    private var expected: Int { mode == 1 ? inputA & inputB : mode == 2 ? 0 : (inputA + inputB) & 255 }
    var body: some View {
        BenchHeader(eyebrow: "An instruction changes a machine", title: "Step a tiny CPU", subtitle: "Fetch, decode, execute. Watch registers, flags, program counter and RAM.")
        InstrumentPanel(title: "Load a program") {
            Picker("Program", selection: $mode) { Text("Add").tag(0); Text("AND").tag(1); Text("Countdown").tag(2) }.pickerStyle(.segmented)
            Stepper("RAM[0] initial A = \(inputA)", value: $inputA, in: 1...255)
            if mode != 2 { Stepper("RAM[1] initial B = \(inputB)", value: $inputB, in: 0...255) }
            Button("Load / reset program") { cpu = .init(inputA: UInt8(inputA), inputB: UInt8(inputB), mode: mode); error = "" }.buttonStyle(GlassActionStyle())
            Text("Input edits are staged until Load/reset is pressed.").font(.caption).foregroundStyle(BenchTheme.muted)
        }
        InstrumentPanel(title: "Datapath", subtitle: "PC → instruction ROM → IR → decoder → ALU/registers → data RAM") {
            HStack { MeterValue(label: "PC", value: "\(cpu.pc)", unit: ""); MeterValue(label: "A", value: "\(cpu.a)", unit: ""); MeterValue(label: "B", value: "\(cpu.b)", unit: "") }
            Text("Next phase: \(cpu.halted ? "HALTED" : cpu.phase.rawValue) · IR: \(cpu.instruction?.text ?? "empty")").font(.headline.monospaced())
            Text("Zero=\(cpu.zero ? 1 : 0) · Carry=\(cpu.carry ? 1 : 0) · cycles=\(cpu.cycles) · completed instructions=\(cpu.instructionsExecuted)").font(.caption.monospaced())
            Button("Step one clock phase") { do { try cpu.step() } catch { self.error = error.localizedDescription } }.buttonStyle(GlassActionStyle()).disabled(cpu.halted)
                .accessibilityIdentifier("cpuStep")
            Text(cpu.lastAction).font(.subheadline).foregroundStyle(BenchTheme.cyan)
            if !error.isEmpty { Text(error).foregroundStyle(BenchTheme.amber) }
            ForEach(cpu.program.indices, id: \.self) { index in
                Text("\(index): \(cpu.program[index].text)").font(.subheadline.monospaced()).foregroundStyle(index == cpu.pc && !cpu.halted ? BenchTheme.cyan : BenchTheme.muted)
            }
            Text("RAM: \(cpu.memory.prefix(4).enumerated().map { "[\($0.offset)]=\($0.element)" }.joined(separator: " · "))").font(.headline.monospaced())
            FormulaNote(equation: "ADD: A⁺ = (A+B) mod 256 · C = (A+B ≥ 256)\nJNZ: PC⁺ = target if Z=0", explanation: "ROM and RAM are separate in this toy architecture. An instruction completes only in Execute; fetched data is visible in IR before it affects registers. All instructions take three phases.")
        }
        InstrumentPanel(title: "Predict the final RAM[2]") {
            Stepper("Prediction = \(predicted)", value: $predicted, in: 0...255)
            Button("Check against staged program") { error = predicted == expected ? "Prediction matches the staged program. Load it and verify by stepping." : "Prediction differs from the staged program; apply eight-bit arithmetic or the countdown loop." }.buttonStyle(GlassActionStyle())
            Text("Addition overflow is carried separately; RAM[2] stores the low eight bits.").font(.caption)
        }
        EngLimits(text: "Custom pedagogical 8-bit ISA, two registers, 16-byte data RAM, separate immutable instruction ROM and deterministic three-phase execution. No ARM/x86 emulation, cache, pipeline, memory wait states or electrical gate timing. Countdown uses modulo-256 DEC; its staged input is 1…255.", title: "MIT · Fetch, decode and execute", url: "https://ocw.mit.edu/courses/6-004-computation-structures-spring-2017/pages/c13/c13s1/")
    }
}

private struct EngineeringEmbeddedLab: View {
    @State private var bits = 4
    @State private var input = 1.6
    @State private var period = 200.0
    @State private var clock = 10.0
    @State private var entry = 12.0
    @State private var work = 500.0
    @State private var blocking = 20.0
    private var adc: EngineeringModels.ADC? { try? EngineeringModels.adc(input: input, reference: 3.3, bits: bits) }
    private var jobs: [EngineeringModels.InterruptJob] { (try? EngineeringModels.interrupts(period: period * 1e-6, clockHz: clock * 1e6, entryCycles: entry, handlerCycles: work, blocking: blocking * 1e-6)) ?? [] }
    var body: some View {
        BenchHeader(eyebrow: "Physical input → bits → deadline", title: "Sample & service", subtitle: "An ADC loses resolution; firmware can lose time. Inspect both limits.")
        InstrumentPanel(title: "Ideal unipolar ADC", subtitle: "3.3 V reference · code bins · midpoint reconstruction") {
            Stepper("Resolution = \(bits) bits", value: $bits, in: 1...12)
            ParameterSlider(title: "Analog input", value: $input, range: -0.2...3.5, unit: "V", format: "%.3f")
            if let a = adc {
                HStack { MeterValue(label: "Code", value: "\(a.code)", unit: ""); MeterValue(label: "LSB", value: engineering(a.lsb, unit: "V"), unit: "", tint: BenchTheme.amber) }
                Text("Bin-center estimate \(engineering(a.reconstructed, unit: "V")) · error \(engineering(a.error, unit: "V"))\(a.clipped ? " · outside input range: clipped" : "")").font(.caption)
                LessonPlot(traces: [.init(values: (0...240).map { (try? EngineeringModels.adc(input: Double($0) / 240 * 3.3, reference: 3.3, bits: bits).reconstructed) ?? 0 }, color: BenchTheme.cyan, name: "Quantized bin center")], xRange: 0...3.3, yRange: 0...3.3, xLabel: "Input · V", yLabel: "Estimate · V")
            }
            FormulaNote(equation: "LSB = Vref/2ᴺ · code = floor(Vin/LSB)\nV̂ = (code+½)LSB", explanation: "Codes are clipped to 0…2ᴺ−1. For an in-range ideal input, bin-center error is at most ½ LSB. Out-of-range inputs lose that bound.")
        }
        InstrumentPanel(title: "Timer interrupt → FIFO handler → deadline", subtitle: "Fixed per-job blocking + entry overhead + execution; 8 releases") {
            ParameterSlider(title: "Timer period", value: $period, range: 50...1000, unit: "µs")
            ParameterSlider(title: "Processor clock", value: $clock, range: 1...100, unit: "MHz")
            ParameterSlider(title: "Entry overhead", value: $entry, range: 0...40, unit: "cycles")
            ParameterSlider(title: "Handler execution", value: $work, range: 50...2000, unit: "cycles")
            ParameterSlider(title: "Blocking per release", value: $blocking, range: 0...500, unit: "µs")
            ForEach(jobs) { job in
                Text("IRQ\(job.id): release \(String(format: "%.1f", job.release * 1e6)) → start \(String(format: "%.1f", job.start * 1e6)) → finish \(String(format: "%.1f", job.finish * 1e6)) µs · slack \(String(format: "%.1f", job.slack * 1e6)) µs")
                    .font(.caption.monospaced()).foregroundStyle(job.slack >= 0 ? BenchTheme.green : BenchTheme.amber)
            }
            FormulaNote(equation: "startₙ = max(releaseₙ, finishₙ₋₁) + blocking + entry/fclk\nfinishₙ = startₙ + cycles/fclk · deadlineₙ = releaseₙ + T", explanation: "The backlog persists when work takes longer than the period. Interrupt latency alone does not establish a completed response deadline.")
        }
        EngPrediction(prompt: "Do ALL eight modeled interrupt jobs complete by their deadline?", choices: ["Yes", "No"], correct: !jobs.isEmpty && jobs.allSatisfy { $0.slack >= 0 } ? 0 : 1)
        EngLimits(text: "Ideal uniform mid-rise ADC with explicit clipping; no noise, DNL/INL, sample-and-hold loading or jitter. Scheduling is a deterministic single FIFO nonpreemptive handler with fixed per-release blocking, not a Cortex-M cycle-accurate emulator or general RTOS schedulability proof.", title: "Analog Devices · ADC quantization", url: "https://wiki.analog.com/university/courses/electronics/text/chapter-20")
        Link("Arm · Interrupt latency and software overhead", destination: URL(string: "https://developer.arm.com/community/arm-community-blogs/b/architectures-and-processors-blog/posts/beginner-guide-on-interrupt-latency-and-interrupt-latency-of-the-arm-cortex-m-processors")!).font(.caption).frame(minHeight: 44)
    }
}

private struct EngineeringHardwareLab: View {
    @State private var fault = false
    @State private var state = 0
    @State private var capacitance = 10.0
    @State private var voltage = 1.2
    @State private var frequency = 100.0
    @State private var alpha = 0.25
    private var witness: [Bool]? { EngineeringModels.safetyWitness(injectedFault: fault) }
    private var power: Double? { try? EngineeringModels.dynamicPower(capacitance: capacitance * 1e-12, volts: voltage, frequency: frequency * 1e6, alpha: alpha) }
    var body: some View {
        BenchHeader(eyebrow: "Specify → verify → count switching energy", title: "Verify a controller", subtitle: "A truth table becomes output logic. A property can expose a reachable failure.")
        InstrumentPanel(title: "Four-state traffic controller", subtitle: "00 A-green → 01 all-red → 10 B-green → 11 all-red → 00") {
            Toggle("Inject output-decoder bug at state 10", isOn: $fault).tint(BenchTheme.amber)
            let output = EngineeringModels.trafficOutput(state: state, injectedFault: fault)
            HStack { MeterValue(label: "State", value: String(state, radix: 2), unit: ""); MeterValue(label: "A green", value: output.aGreen ? "1" : "0", unit: "", tint: BenchTheme.green); MeterValue(label: "B green", value: output.bGreen ? "1" : "0", unit: "", tint: BenchTheme.amber) }
            Button("Clock advance = 1") { state = EngineeringModels.trafficNext(state: state, advance: true) }.buttonStyle(GlassActionStyle())
            Button("Clock advance = 0 (hold)") { state = EngineeringModels.trafficNext(state: state, advance: false) }.buttonStyle(GlassActionStyle())
            Button("Reset to 00") { state = 0 }.buttonStyle(GlassActionStyle(tint: BenchTheme.amber))
            ForEach(0..<4, id: \.self) { q in
                let o = EngineeringModels.trafficOutput(state: q, injectedFault: fault)
                Text("q=\(q): A=\(o.aGreen ? 1 : 0), B=\(o.bGreen ? 1 : 0); advance0→\(q), advance1→\((q + 1) % 4)").font(.caption.monospaced())
            }
            if let witness {
                Text("FAIL: reachable simultaneous greens. Minimal witness from reset: \(witness.map { $0 ? "1" : "0" }.joined(separator: " → ")).").font(.subheadline).foregroundStyle(BenchTheme.amber)
            } else { Text("PASS: exhaustive reachable-state search finds no simultaneous greens for either input value.").font(.subheadline).foregroundStyle(BenchTheme.green) }
            FormulaNote(equation: "Safe decoder: A = ¬q₁ ∧ ¬q₀ · B = q₁ ∧ ¬q₀\nProperty: always ¬(A ∧ B)", explanation: "The checker searches all reachable states and both advance inputs, rather than comparing the implementation with itself. It reports an input sequence that reaches the violation.")
        }
        InstrumentPanel(title: "CMOS capacitive switching power") {
            ParameterSlider(title: "Effective load capacitance", value: $capacitance, range: 1...100, unit: "pF")
            ParameterSlider(title: "Supply voltage", value: $voltage, range: 0.5...3.3, unit: "V")
            ParameterSlider(title: "Clock frequency", value: $frequency, range: 1...1000, unit: "MHz")
            ParameterSlider(title: "0→1 transitions per clock α", value: $alpha, range: 0...1, unit: "")
            if let power { MeterValue(label: "Dynamic power", value: engineering(power, unit: "W"), unit: "", tint: BenchTheme.green) }
            FormulaNote(equation: "Pdynamic = α C V² f · Esupply per 0→1 = CV²", explanation: "α counts rising transitions per cycle, not all edges. Half CV² becomes stored capacitor energy; the other half is lost during charging. Stored energy is dissipated on discharge in ordinary CMOS.")
        }
        EngPrediction(prompt: "Does the CURRENT decoder satisfy the no-simultaneous-green property over every reachable state?", choices: ["Yes", "No"], correct: witness == nil ? 0 : 1)
        EngLimits(text: "Exhaustive safety check of a finite synchronous Boolean machine and explicit output equations. This is truth-table mapping, not vendor FPGA synthesis/place-and-route. CMOS power is a capacitive activity model; no leakage, short-circuit current, measured cell library, wiring parasitics or timing closure.", title: "TI · CMOS power and CPD calculation", url: "https://www.ti.com/lit/an/scaa035b/scaa035b.pdf")
    }
}
