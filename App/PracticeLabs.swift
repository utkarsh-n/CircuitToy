import SwiftUI

struct PracticeLessonLab: View {
    let lessonID: String
    var body: some View {
        Group {
            switch lessonID {
            case "instrumentation": ProbeLesson()
            case "design": DesignLesson()
            case "ethics": EthicsLesson()
            case "capstone": CapstoneLesson()
            default: ContentUnavailableView("Experiment unavailable", systemImage: "exclamationmark.triangle")
            }
        }.accessibilityIdentifier("experiment_\(lessonID)")
    }
}

private struct ProbeLesson: View {
    @State private var dividerLog = 4.0
    @State private var probeLog = 6.0
    @State private var capacitancePF = 10.0
    @State private var frequencyLog = 5.0
    private var result: PracticeModels.ProbeResult {
        PracticeModels.probe(source: 5, top: pow(10, dividerLog), bottom: pow(10, dividerLog), input: pow(10, probeLog), capacitance: capacitancePF * 1e-12, frequency: pow(10, frequencyLog))!
    }
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "Instrumentation", title: "The probe joins the circuit", subtitle: "A 5 V source drives two equal resistors. Connect a real input impedance.")
            InstrumentPanel(title: "Loading & bandwidth") {
                HStack {
                    MeterValue(label: "Unloaded DC", value: "2.500", unit: "V")
                    MeterValue(label: "Measured DC", value: String(format: "%.3f", result.loaded), unit: "V", tint: BenchTheme.amber)
                }
                HStack {
                    MeterValue(label: "Loading error", value: String(format: "%.2f", result.loadingError * 100), unit: "%")
                    MeterValue(label: "AC output", value: String(format: "%.3f", result.magnitude), unit: "V peak", tint: BenchTheme.amber)
                }
                Text("At \(engineering(pow(10, frequencyLog), unit: "Hz")), phase is \(String(format: "%.2f", result.phase * 180 / .pi))°. Pole time constant: \(engineering(result.timeConstant, unit: "s")).").font(.caption).foregroundStyle(BenchTheme.muted)
                LessonPlot(traces: [.init(values: (0...140).map { index in
                    let p = PracticeModels.probe(source: 5, top: pow(10, dividerLog), bottom: pow(10, dividerLog), input: pow(10, probeLog), capacitance: capacitancePF * 1e-12, frequency: pow(10, Double(index) / 20))!
                    return 20 * log10(p.magnitude / 5)
                }, color: BenchTheme.cyan, name: "Loaded transfer gain")], xRange: 0...7, yRange: -100...0, xLabel: "log₁₀ frequency / Hz", yLabel: "Gain / dB")
            }
            InstrumentPanel(title: "Connect the instrument") {
                ParameterSlider(title: "log₁₀ each divider resistance", value: $dividerLog, range: 3...7, unit: "log₁₀ Ω")
                ParameterSlider(title: "log₁₀ probe resistance", value: $probeLog, range: 4...9, unit: "log₁₀ Ω")
                ParameterSlider(title: "Probe capacitance", value: $capacitancePF, range: 1...100, unit: "pF")
                ParameterSlider(title: "log₁₀ test frequency", value: $frequencyLog, range: 0...7, unit: "log₁₀ Hz")
            }
            FormulaNote(equation: "R_b′ = R_b ∥ R_in\nV_DC = V_s R_b′/(R_a + R_b′)\nH(jω) = H(0)/(1 + jω(R_a ∥ R_b ∥ R_in)C_in)", explanation: "Resistance loads the divider even at DC. Capacitance then shunts changing signals and limits bandwidth. A perfect calculation of the unloaded divider cannot correct a probe that changes the physical system.")
            LessonCheck(prompt: "Raise both divider resistances by a factor of ten. Does a 1 MΩ probe still give the same reading?", answer: "The unloaded ratio stays one half, but the probe becomes a stronger parallel load. The measured DC output falls, and the capacitive pole shifts downward. A buffer can reduce loading, but needs its own nonideal model.")
            LessonModelNote(text: "Ideal source and lumped linear resistors; probe = R_in in parallel with C_in. No input protection, inductive ground lead, calibration drift, noise or distributed cable. Gain graph has explicit shared dB axes; the frequency slider selects an actual measured sinusoid.")
            Link("Analog Devices · Frequency-compensated dividers", destination: URL(string: "https://www.analog.com/en/resources/analog-dialogue/studentzone/2019/07/25/14/50/studentzone-november-2018.html")!).font(.caption)
        }
    }
}

private struct DesignLesson: View {
    @State private var candidate = 0
    @State private var tolerance = 1.0
    @State private var voltageError = 0.1
    @State private var currentLimit = 5.0
    @State private var rating = 0.25
    private let choices = [1_000.0, 10_000, 100_000]
    private var result: PracticeModels.DesignResult {
        PracticeModels.dividerDesign(source: 5, resistance: choices[candidate], load: 100_000, resistorTolerance: tolerance / 100, sourceTolerance: 0.01)!
    }
    private var passes: Bool { result.meets(target: 2.5, error: voltageError, currentLimit: currentLimit / 1000, powerRating: rating) }
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "Engineering design", title: "Requirements choose the circuit", subtitle: "Choose a divider for a 100 kΩ input. Supply is 5 V ±1%.")
            InstrumentPanel(title: "Candidate under bounded tolerances") {
                Picker("Resistance pair", selection: $candidate) { ForEach(choices.indices, id: \.self) { index in Text("\(engineering(choices[index], unit: "Ω")) + \(engineering(choices[index], unit: "Ω"))").tag(index) } }
                HStack {
                    MeterValue(label: "Nominal output", value: String(format: "%.3f", result.nominal), unit: "V")
                    MeterValue(label: "Worst current", value: String(format: "%.3f", result.maximumSourceCurrent * 1000), unit: "mA", tint: BenchTheme.amber)
                }
                Text("Output bound: \(String(format: "%.3f", result.minimum))…\(String(format: "%.3f", result.maximum)) V\nLargest resistor dissipation: \(engineering(result.maximumResistorPower, unit: "W"))\nNominal useful-load power / source power: \(String(format: "%.2f", result.loadEfficiency * 100))%")
                    .font(.subheadline.monospaced()).foregroundStyle(BenchTheme.muted)
                Label(passes ? "All stated requirements pass" : "At least one requirement fails", systemImage: passes ? "checkmark.circle" : "xmark.circle")
                    .foregroundStyle(passes ? BenchTheme.green : BenchTheme.amber).accessibilityIdentifier("designAcceptance")
            }
            InstrumentPanel(title: "Measurable requirements") {
                ParameterSlider(title: "Resistor tolerance", value: $tolerance, range: 0.1...5, unit: "%")
                ParameterSlider(title: "Allowed error from 2.5 V", value: $voltageError, range: 0.02...0.5, unit: "V")
                ParameterSlider(title: "Source current ceiling", value: $currentLimit, range: 0.1...10, unit: "mA")
                ParameterSlider(title: "Each resistor power rating", value: $rating, range: 0.02...1, unit: "W")
            }
            InstrumentPanel(title: "Compare all candidates") {
                ForEach(choices.indices, id: \.self) { index in
                    let point = PracticeModels.dividerDesign(source: 5, resistance: choices[index], load: 100_000, resistorTolerance: tolerance / 100, sourceTolerance: 0.01)!
                    HStack { Text(engineering(choices[index], unit: "Ω")); Spacer(); Text(String(format: "%.3f V · %.3f mA", point.nominal, point.maximumSourceCurrent * 1000)) }.font(.caption.monospaced())
                }
            }
            FormulaNote(equation: "V_o = V_s(R_b ∥ R_L)/(R_a + (R_b ∥ R_L))\nP_R = I_R²R", explanation: "Increasing resistance reduces source current but increases the load's influence. A preferred nominal ratio is insufficient: acceptance must include the load, independent tolerance corners, source variation, and dissipation.")
            LessonCheck(prompt: "Which candidate draws the least current? Does it also meet the voltage requirement?", answer: "The 100 kΩ pair uses the least current, but its lower resistor is heavily loaded by the 100 kΩ input. Its nominal output is only 1.667 V. A design must satisfy all constraints; there is no universal best resistor value.")
            LessonModelNote(text: "Eight combinations of independent bounded source/resistor deviations. These are worst-case bounds, not probabilities or statistical confidence intervals. The meter's 100 kΩ load is exact. Power ratings are ideal comparison thresholds; no thermal derating, failure probability, PCB layout, cost model or regulatory certification is inferred.")
        }.sensoryFeedback(.selection, trigger: candidate)
    }
}

private struct EthicsLesson: View {
    @State private var scenario = 0
    @State private var decision = 0
    @State private var reviewed = false
    @AppStorage("CircuitToy.ethics.notes") private var notes = ""
    private let titles = ["Evidence & disclosure", "Fail-safe design", "Privacy & accessibility"]
    private var story: String {
        switch scenario {
        case 0: "A team has tested a sensor controller only in an ideal simulator. A demonstration is tomorrow. A colleague proposes describing it as verified on physical hardware."
        case 1: "A heater controller's only temperature sensor can fail low. Normal tests passed, but a fault would keep the heater on. Adding an independent cutoff will delay delivery."
        default: "A connected device records high-resolution household activity. A proposed diagnostic feature uploads all recordings by default, and status is communicated only by red/green color."
        }
    }
    private var options: [String] {
        switch scenario {
        case 0: ["Claim hardware verification", "Disclose simulator evidence and schedule hardware tests"]
        case 1: ["Ship with normal tests only", "Add a cutoff and independently test sensor faults"]
        default: ["Upload everything; keep color-only status", "Minimize data, obtain consent, and add readable status"]
        }
    }
    private var analysis: String {
        let chosen = decision == 1
        switch scenario {
        case 0: return chosen ? "This accurately communicates the evidence and the missing test. Record model assumptions, acceptance conditions and the responsible reviewer; a deadline does not turn a simulation into a physical test." : "This claim exceeds the evidence. A stakeholder could rely on untested behavior. Document the gap and correct the claim before the demonstration."
        case 1: return chosen ? "An independent cutoff addresses a different failure path. Verify it without relying on the controller's sensor or code. Record tradeoffs, residual risks, affected users and who has authority to approve release." : "Normal-operation tests cannot establish behavior after a sensor fault. Investigate credible failures, assess consequences, and escalate unresolved safety evidence to a responsible reviewer."
        default: return chosen ? "Data minimization and explicit choices reduce exposure. Text, symbols and accessible announcements make state usable without color discrimination. Test with affected users; consent alone does not justify unnecessary collection." : "The design creates privacy and accessibility concerns unrelated to circuit efficiency. Establish the minimum data needed, retention and access controls, and status cues people can perceive."
        }
    }
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "Professional practice", title: "A decision needs a record", subtitle: "Work through an engineering scenario. Explain evidence, consequences and responsibilities.")
            InstrumentPanel(title: "Choose a case") {
                Picker("Engineering case", selection: $scenario) { ForEach(titles.indices, id: \.self) { Text(titles[$0]).tag($0) } }
                Text(story).font(.subheadline)
                Picker("Proposed action", selection: $decision) { ForEach(options.indices, id: \.self) { Text(options[$0]).tag($0) } }
                Button("Review consequences") { reviewed = true }.buttonStyle(GlassActionStyle())
                if reviewed { Text(analysis).font(.subheadline).foregroundStyle(decision == 1 ? BenchTheme.green : BenchTheme.amber).accessibilityIdentifier("ethicsConsequences") }
            }
            InstrumentPanel(title: "Write the reasoning") {
                Text("Who is affected? What evidence exists? Which assumptions or failures matter? Who must review the decision, and what would change your recommendation?").font(.subheadline).foregroundStyle(BenchTheme.muted)
                TextField("Your decision record", text: $notes, axis: .vertical).lineLimit(4...10).accessibilityIdentifier("ethicsDecisionRecord")
                Text("Saved locally on this device.").font(.caption).foregroundStyle(BenchTheme.muted)
            }
            FormulaNote(equation: "Claim → evidence → limits → affected people → review", explanation: "Ethical reasoning involves judgment and responsibility, not a physical equation or a numeric virtue score. Honest technical communication, public welfare, privacy and fair access belong in the design process.")
            LessonModelNote(text: "Authored hypothetical cases, with explicit consequences under the scenario. The suggested action is a teaching example rather than legal advice or a certification. Discussion, teamwork, peer review and real project experience remain necessary for professional competence.")
            Link("IEEE · Engineering ethics", destination: URL(string: "https://technav.ieee.org/topic/ethics/")!).font(.caption)
        }.onChange(of: scenario) { _, _ in decision = 0; reviewed = false }
            .onChange(of: decision) { _, _ in reviewed = false }
    }
}

private struct CapstoneLesson: View {
    @State private var config = PracticeModels.ThermalConfiguration()
    @State private var tested = false
    @State private var allowedError = 1.0
    @State private var maximumTemperature = 32.0
    @AppStorage("CircuitToy.capstone.requirements") private var requirements = "Hold 28 °C within ±1 °C after settling; remain below 32 °C."
    private var report: PracticeModels.ThermalReport { PracticeModels.thermal(config)! }
    private var passes: Bool { report.settlingError <= allowedError && report.maximumTemperature <= maximumTemperature }
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "Capstone", title: "Sensor → code → heat → sensor", subtitle: "Design a sampled thermostat, then produce a reproducible simulation report.")
            InstrumentPanel(title: "The integrated system") {
                Text("Temperature → linear sensor → ADC → hysteresis controller → resistive heater → thermal plant").font(.subheadline.monospaced()).foregroundStyle(BenchTheme.cyan)
                HStack {
                    MeterValue(label: "Final temperature", value: String(format: "%.2f", report.samples.last!.temperature), unit: "°C")
                    MeterValue(label: "Heater power", value: String(format: "%.2f", report.heaterPower), unit: "W", tint: BenchTheme.amber)
                }
                LessonPlot(traces: [
                    .init(values: report.samples.map(\.temperature), color: BenchTheme.cyan, name: "Physical temperature"),
                    .init(values: report.samples.map(\.measured), color: BenchTheme.amber, name: "ADC estimate"),
                    .init(values: report.samples.map { _ in config.target }, color: BenchTheme.green, name: "Target")
                ], xRange: 0...config.duration, yRange: 10...max(40, report.maximumTemperature + 2), xLabel: "Time / s", yLabel: "Temperature / °C")
                Text("Input energy: \(engineering(report.samples.last!.electricalEnergy, unit: "J"))\nStored energy rise: \(engineering(report.samples.last!.storedEnergy, unit: "J"))\nEnvironmental transfer: \(engineering(report.samples.last!.environmentalEnergy, unit: "J"))\nBalance residual: \(String(format: "%.2e", report.energyResidual)) J")
                    .font(.caption.monospaced()).foregroundStyle(BenchTheme.muted)
            }
            InstrumentPanel(title: "Design variables") {
                ParameterSlider(title: "Supply voltage", value: $config.supply, range: 6...18, unit: "V")
                ParameterSlider(title: "Heater resistance", value: $config.heaterResistance, range: 12...60, unit: "Ω")
                ParameterSlider(title: "Target temperature", value: $config.target, range: 22...35, unit: "°C")
                ParameterSlider(title: "Thermal conductance", value: $config.conductance, range: 0.2...1, unit: "W/K")
                ParameterSlider(title: "Sensor offset", value: $config.sensorOffset, range: -2...2, unit: "°C")
                ParameterSlider(title: "Controller half-deadband", value: $config.hysteresis, range: 0.1...2, unit: "°C")
                Picker("ADC resolution", selection: $config.bits) { ForEach([6, 8, 10, 12], id: \.self) { Text("\($0) bits").tag($0) } }
                Picker("Sample interval", selection: $config.step) { ForEach([0.25, 0.5, 1.0, 2.0], id: \.self) { Text("\($0.formatted()) s").tag($0) } }
                Text("Fixed heat capacity 20 J/K, ambient 20 °C, duration 180 s. Sensor voltage = 0.5 V + (0.01 V/°C)T; ADC range 0…3.3 V.").font(.caption).foregroundStyle(BenchTheme.muted)
            }
            InstrumentPanel(title: "Acceptance conditions & evidence") {
                TextField("Requirements and rationale", text: $requirements, axis: .vertical).lineLimit(3...8)
                ParameterSlider(title: "Maximum late-run target error", value: $allowedError, range: 0.2...3, unit: "°C")
                ParameterSlider(title: "Temperature ceiling", value: $maximumTemperature, range: 28...42, unit: "°C")
                Button("Run acceptance checks") { tested = true }.buttonStyle(GlassActionStyle(tint: BenchTheme.green)).accessibilityIdentifier("runCapstoneChecks")
                if tested {
                    Label(passes ? "Simulation meets these conditions" : "Revise the design", systemImage: passes ? "checkmark.circle" : "xmark.circle").foregroundStyle(passes ? BenchTheme.green : BenchTheme.amber)
                    Text("Largest target error during final 20%: \(String(format: "%.3f", report.settlingError)) °C\nMaximum physical temperature: \(String(format: "%.3f", report.maximumTemperature)) °C\nSampled energy balance |residual| < 10⁻⁸ J: \(abs(report.energyResidual) < 1e-8 ? "pass" : "fail")").font(.caption.monospaced()).accessibilityIdentifier("capstoneResults")
                }
                ShareLink(item: "Circuit Toy capstone simulation\nRequirements: \(requirements)\nAllowed late error: \(allowedError) °C\nCeiling: \(maximumTemperature) °C\n\(report.json())") { Label("Export model & test report", systemImage: "square.and.arrow.up") }.buttonStyle(GlassActionStyle())
            }
            FormulaNote(equation: "P = V²/R\nC_th dT/dt = P − h(T − T_ambient)\nΔV_ADC = V_FS/2ᴺ", explanation: "Each controller sample measures temperature through a quantized sensor, switches the heater using hysteresis, then advances the exact held-input thermal solution. Sensor bias changes regulation even with a perfect digital controller. Insufficient heater power cannot reach a demanding setpoint.")
            LessonCheck(prompt: "Reduce supply voltage to 6 V. Can the 24 Ω heater hold 28 °C with h = 0.5 W/K?", answer: "The heater supplies only 1.5 W, while 28 °C needs 0.5 × (28 − 20) = 4 W at equilibrium. No controller can overcome that power deficit. Its highest steady temperature is 23 °C under this plant model.")
            LessonModelNote(text: "Lumped isothermal plant with constant heat capacity and linear heat transfer; exact evolution between samples. Ideal resistor, switch and voltage source. Bin-centered uniform ADC with clipping, static sensor offset, and sampled hysteresis. No sensor-failure, heater reliability, radiation, spatial gradients or real hardware verification. A passing report establishes these simulation conditions only. Physical prototypes need independent calibration, failure testing and measured evidence.")
            Link("MIT · A Heat Transfer Textbook", destination: URL(string: "https://ahtt.mit.edu/")!).font(.caption)
        }.onChange(of: config) { _, _ in tested = false }
            .onChange(of: allowedError) { _, _ in tested = false }
            .onChange(of: maximumTemperature) { _, _ in tested = false }
    }
}
