import SwiftUI

struct ScienceLabView: View {
    let destination: LabDestination

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                switch destination {
                case .semiconductor: SemiconductorBench()
                case .signals: SignalBench()
                case .control: ControlBench()
                case .fields: FieldBench()
                case .communications: CommunicationsBench()
                case .power: PowerBench()
                default: EmptyView()
                }
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(BenchTheme.bg)
        .foregroundStyle(BenchTheme.ink)
    }
}

private struct SemiconductorBench: View {
    @State private var mode = 0
    @State private var voltage = 0.48
    @State private var ideality = 1.5
    @State private var logSaturation = -12.0
    @State private var input = 0.5
    @State private var feedbackKOhms = 40.0

    private var diode: ScientificModels.DiodePoint? {
        ScientificModels.diode(voltage: voltage, saturationCurrent: pow(10, logSaturation), ideality: ideality)
    }

    private var amplifier: ScientificModels.AmplifierPoint? {
        ScientificModels.invertingAmplifier(input: input, inputResistance: 10_000, feedbackResistance: feedbackKOhms * 1_000, rail: 5)
    }

    var body: some View {
        Picker("Semiconductor experiment", selection: $mode) {
            Text("Junction diode").tag(0)
            Text("Op amp").tag(1)
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(.selection, trigger: mode)
        .accessibilityIdentifier("semiconductorExperiment")

        if mode == 0 {
            diodeExperiment
        } else {
            amplifierExperiment
        }
    }

    private var diodeExperiment: some View {
        Group {
            InstrumentPanel(title: "The exponential junction", subtitle: "A tiny voltage change can produce a large current change.") {
                ScienceMeterRow {
                    MeterValue(label: "Junction current", value: ScienceFormat.number(diode?.current ?? 0), unit: ScienceFormat.unit(diode?.current ?? 0, base: "A"), tint: BenchTheme.amber)
                    MeterValue(label: "Thermal voltage", value: ScienceFormat.decimal((diode?.thermalVoltage ?? 0) * 1_000, digits: 2), unit: "mV", tint: BenchTheme.cyan)
                }
                diodePlot
                ScienceStatus(text: voltage < 0 ? "Reverse bias: current approaches −Iₛ." : "Forward bias: current grows exponentially.", tint: voltage < 0 ? BenchTheme.cyan : BenchTheme.amber)
            }
            InstrumentPanel(title: "Junction parameters", subtitle: "Temperature is fixed at 300 K (26.85 °C).") {
                ParameterSlider(title: "Diode voltage", value: $voltage, range: -0.2...0.65, unit: "V", format: "%.3f")
                ParameterSlider(title: "Ideality factor n", value: $ideality, range: 1...2, unit: "", format: "%.2f")
                ParameterSlider(title: "log₁₀ saturation current", value: $logSaturation, range: -14 ... -10, unit: "log₁₀(A)", format: "%.2f")
                Text("Iₛ = \(ScienceFormat.number(pow(10, logSaturation))) \(ScienceFormat.unit(pow(10, logSaturation), base: "A"))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(BenchTheme.muted)
            }
            FormulaNote(equation: "I = Iₛ [exp(Vᴅ / nVₜ) − 1]    Vₜ = kT / q", explanation: "A p–n junction has a barrier. Forward voltage lowers that barrier, increasing carrier flow. There is no universal 0.7 V threshold; the current depends on Iₛ, n, voltage, and temperature.")
            ScienceLimits(text: "Shockley junction model only. Iₛ is a chosen parameter, not a measured device. No series resistance, breakdown, self-heating, capacitance, or high-current effects. The numerical model rejects an exponent above 700 rather than silently clipping current.")
            ScienceReference(title: "Analog Devices · Diode characteristics", url: "https://wiki.analog.com/university/courses/electronics/text/chapter-5")
        }
    }

    private var diodePlot: some View {
        let saturation = pow(10, logSaturation)
        let voltages = (0...200).map { -0.2 + 0.85 * Double($0) / 200 }
        let currents = voltages.map { ScientificModels.diode(voltage: $0, saturationCurrent: saturation, ideality: ideality)?.current ?? 0 }
        let maximum = max(currents.max() ?? 0, 1e-15) * 1.1
        return SciencePlot(
            traces: [.init(values: currents, color: BenchTheme.amber)],
            xRange: -0.2...0.65, yRange: (-maximum * 0.02)...maximum,
            dots: [.init(x: voltage, y: diode?.current ?? 0, color: BenchTheme.ink)],
            xLabel: "Junction voltage · V", yLabel: "Current · A",
            leadingX: "−0.20", trailingX: "0.65", topY: ScienceFormat.quantity(maximum, "A"), bottomY: "≈ 0",
            summary: "Diode current versus voltage. Selected current \(ScienceFormat.quantity(diode?.current ?? 0, "A")). Reverse current is too small to resolve on this linear scale."
        )
    }

    private var amplifierExperiment: some View {
        let result = amplifier
        return Group {
            InstrumentPanel(title: "Feedback sets the gain", subtitle: "A grounded + input and resistor feedback create an inverting amplifier.") {
                ScienceMeterRow {
                    MeterValue(label: "Closed-loop gain", value: ScienceFormat.decimal(result?.gain ?? 0, digits: 2), unit: "V/V", tint: BenchTheme.cyan)
                    MeterValue(label: "Output", value: ScienceFormat.decimal(result?.output ?? 0, digits: 2), unit: "V", tint: BenchTheme.amber)
                }
                SciencePlot(
                    traces: [.init(values: (0...200).map { index in
                        ScientificModels.invertingAmplifier(input: -1.25 + 2.5 * Double(index) / 200, inputResistance: 10_000, feedbackResistance: feedbackKOhms * 1_000, rail: 5)?.output ?? 0
                    }, color: BenchTheme.cyan)],
                    xRange: -1.25...1.25, yRange: -5.5...5.5,
                    dots: [.init(x: input, y: result?.output ?? 0, color: BenchTheme.amber)],
                    xLabel: "Input voltage · V", yLabel: "Output voltage · V",
                    leadingX: "−1.25", trailingX: "+1.25", topY: "+5.5", bottomY: "−5.5",
                    summary: "Inverting amplifier transfer curve, output limited to plus or minus 5 volts. Selected output \(ScienceFormat.decimal(result?.output ?? 0, digits: 2)) volts."
                )
                ScienceStatus(text: result?.isClipped == true ? "Saturated: the requested output exceeds a 5 V rail." : "Linear region: feedback can hold the − input at virtual ground.", tint: result?.isClipped == true ? BenchTheme.amber : BenchTheme.green)
            }
            InstrumentPanel(title: "Set the resistor ratio", subtitle: "Input resistance Rᵢₙ = 10 kΩ. Symmetric output rails = ±5 V.") {
                ParameterSlider(title: "Input voltage", value: $input, range: -1.25...1.25, unit: "V", format: "%.2f")
                ParameterSlider(title: "Feedback resistance", value: $feedbackKOhms, range: 1...100, unit: "kΩ", format: "%.1f")
            }
            FormulaNote(equation: "Vₒᵤₜ = −(R𝒻 / Rᵢₙ) Vᵢₙ", explanation: "In the linear region, the ideal amplifier draws no input current and negative feedback holds its two inputs at equal voltage. Kirchhoff’s current law then makes the feedback current equal the input resistor current.")
            ScienceLimits(text: "Ideal DC model with an idealized hard rail clamp. Once saturated, the virtual-ground assumption no longer holds. Real devices have output headroom, finite gain and bandwidth, input offsets, current limits, and slew-rate limits; none are modeled here.")
            ScienceReference(title: "Texas Instruments · Op amp applications", url: "https://www.ti.com/lit/an/sboa092b/sboa092b.pdf")
        }
    }
}

private struct SignalBench: View {
    @State private var fundamental = 4.0
    @State private var second = 0.35
    @State private var third = 0.15
    @State private var sampleRate = 24.0
    @State private var showAliases = true

    private var highestFrequency: Double {
        fundamental * (third > 0 ? 3 : second > 0 ? 2 : 1)
    }

    private var aliases: Bool { sampleRate <= 2 * highestFrequency }

    var body: some View {
        InstrumentPanel(title: "Build a signal. Sample it.", subtitle: "One second of a 1 V fundamental plus adjustable harmonics.") {
            ScienceMeterRow {
                MeterValue(label: "Nyquist frequency", value: ScienceFormat.decimal(sampleRate / 2, digits: 1), unit: "Hz", tint: BenchTheme.cyan)
                MeterValue(label: "Highest component", value: ScienceFormat.decimal(highestFrequency, digits: 1), unit: "Hz", tint: aliases ? BenchTheme.amber : BenchTheme.green)
            }
            signalPlot
            ScienceLegend(items: [("Continuous", BenchTheme.cyan), ("Samples / alias", BenchTheme.amber)])
            ScienceStatus(text: aliases ? "At least one component is at or above Nyquist." : "All active components are below Nyquist.", tint: aliases ? BenchTheme.amber : BenchTheme.green)
            Text("Fundamental folds to \(ScienceFormat.decimal(abs(ScientificModels.signedAlias(frequency: fundamental, sampleRate: sampleRate) ?? 0), digits: 2)) Hz in the sampled data.")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(BenchTheme.muted)
        }
        InstrumentPanel(title: "Oscillator & sampler") {
            ParameterSlider(title: "Fundamental frequency", value: $fundamental, range: 1...20, unit: "Hz", format: "%.1f")
            ParameterSlider(title: "Second harmonic amplitude", value: $second, range: 0...1, unit: "V", format: "%.2f")
            ParameterSlider(title: "Third harmonic amplitude", value: $third, range: 0...1, unit: "V", format: "%.2f")
            ParameterSlider(title: "Sample rate", value: $sampleRate, range: 2...100, unit: "samples/s", format: "%.1f")
            Toggle("Show a folded signal matching the samples", isOn: $showAliases)
                .tint(BenchTheme.amber)
        }
        FormulaNote(equation: "x(t) = sin(2πft) + a₂sin(4πft) + a₃sin(6πft)", explanation: "Superposition adds components without changing their frequencies. Uniform samples cannot distinguish frequencies separated by a whole sample rate. Above Nyquist, a component folds into the interval from 0 to fₛ/2.")
        ScienceLimits(text: "Ideal point samples, with no anti-alias filter, quantization, jitter, or noise. The amber curve is one low-frequency signal with identical samples, not a reconstruction algorithm. General unique recovery requires every component strictly below fₛ/2; exactly Nyquist is phase-sensitive.")
        ScienceReference(title: "DSP Guide · The sampling theorem", url: "https://www.dspguide.com/ch3/2.htm3")
    }

    private var signalPlot: some View {
        let values = (0...800).map { ScientificModels.harmonicSignal(time: Double($0) / 800, fundamental: fundamental, second: second, third: third) ?? 0 }
        let folded = (0...800).map { ScientificModels.sampledAliasSignal(time: Double($0) / 800, fundamental: fundamental, second: second, third: third, sampleRate: sampleRate) ?? 0 }
        let dots = (0...Int(sampleRate.rounded(.down))).map { index in
            let time = Double(index) / sampleRate
            return SciencePlot.Dot(x: time, y: ScientificModels.harmonicSignal(time: time, fundamental: fundamental, second: second, third: third) ?? 0, color: BenchTheme.amber)
        }
        var traces: [SciencePlot.Trace] = [.init(values: values, color: BenchTheme.cyan)]
        if showAliases { traces.append(.init(values: folded, color: BenchTheme.amber, dashed: true)) }
        return SciencePlot(traces: traces, xRange: 0...1, yRange: -3.2...3.2, dots: dots,
                           xLabel: "Time · s", yLabel: "Voltage · V", leadingX: "0", trailingX: "1", topY: "+3.2", bottomY: "−3.2",
                           summary: "One second of a mixed signal sampled at \(ScienceFormat.decimal(sampleRate, digits: 1)) samples per second. \(aliases ? "Aliasing or a Nyquist boundary occurs." : "All frequencies are below Nyquist.")")
    }
}

private struct ControlBench: View {
    @State private var proportionalGain = 2.0
    @State private var timeConstant = 2.0
    @State private var time = 2.0

    private var result: ScientificModels.ControlPoint? {
        ScientificModels.proportionalStep(time: time, plantTimeConstant: timeConstant, proportionalGain: proportionalGain)
    }

    var body: some View {
        InstrumentPanel(title: "Close the feedback loop", subtitle: "A unit step asks a first-order plant to reach 1.") {
            ScienceMeterRow {
                MeterValue(label: "Output at t", value: ScienceFormat.decimal(result?.value ?? 0, digits: 3), unit: "", tint: BenchTheme.cyan)
                MeterValue(label: "Final error", value: ScienceFormat.decimal((result?.steadyStateError ?? 1) * 100, digits: 1), unit: "%", tint: BenchTheme.amber)
            }
            SciencePlot(
                traces: [
                    .init(values: Array(repeating: 1, count: 301), color: BenchTheme.muted, dashed: true),
                    .init(values: (0...300).map { ScientificModels.proportionalStep(time: 8 * Double($0) / 300, plantTimeConstant: timeConstant, proportionalGain: proportionalGain)?.value ?? 0 }, color: BenchTheme.cyan)
                ],
                xRange: 0...8, yRange: 0...1.1,
                dots: [.init(x: time, y: result?.value ?? 0, color: BenchTheme.amber)],
                xLabel: "Time · s", yLabel: "Unit-step response", leadingX: "0", trailingX: "8", topY: "1.1", bottomY: "0",
                summary: "Closed-loop unit-step response. Final value \(ScienceFormat.decimal(result?.finalValue ?? 0, digits: 3)). Time constant \(ScienceFormat.quantity(result?.closedLoopTimeConstant ?? 0, "s"))."
            )
            ScienceLegend(items: [("Setpoint = 1", BenchTheme.muted), ("Output", BenchTheme.cyan)])
            Text("Closed-loop time constant: \(ScienceFormat.quantity(result?.closedLoopTimeConstant ?? 0, "s"))")
                .font(.subheadline.monospacedDigit()).foregroundStyle(BenchTheme.muted)
        }
        InstrumentPanel(title: "Tune the controller") {
            ParameterSlider(title: "Proportional gain Kₚ", value: $proportionalGain, range: 0...12, unit: "", format: "%.2f")
            ParameterSlider(title: "Plant time constant τ", value: $timeConstant, range: 0.1...5, unit: "s", format: "%.2f")
            ParameterSlider(title: "Inspect time", value: $time, range: 0...8, unit: "s", format: "%.2f")
        }
        FormulaNote(equation: "G(s) = 1/(τs + 1)    T(s) = Kₚ/(τs + 1 + Kₚ)", explanation: "The controller applies u = Kₚ(r − y). With unity negative feedback, y(t) = [Kₚ/(1+Kₚ)] [1 − exp(−(1+Kₚ)t/τ)]. More proportional gain speeds this particular plant and reduces, but never removes, its final error.")
        ScienceLimits(text: "Exact analytical response of a stable, linear, first-order plant with unit DC gain, zero initial state, and an ideal proportional controller. No actuator saturation, delay, noise, integral term, or derivative term. Higher-order plants can overshoot or become unstable; this model cannot.")
        ScienceReference(title: "University of Michigan · Feedback & PID", url: "https://ctms.engin.umich.edu/CTMS/?example=Introduction&section=ControlPID")
    }
}

private struct FieldBench: View {
    @State private var chargeNanoCoulombs = 3.0
    @State private var distance = 1.0

    private var result: ScientificModels.FieldPoint? {
        ScientificModels.pointCharge(charge: chargeNanoCoulombs * 1e-9, distance: distance)
    }

    var body: some View {
        InstrumentPanel(title: "Charge shapes space", subtitle: "Move the probe away from a stationary point charge.") {
            ScienceMeterRow {
                MeterValue(label: "Radial field Eᵣ", value: ScienceFormat.number(result?.radialField ?? 0), unit: ScienceFormat.unit(result?.radialField ?? 0, base: "V/m"), tint: BenchTheme.cyan)
                MeterValue(label: "Potential", value: ScienceFormat.number(result?.potential ?? 0), unit: ScienceFormat.unit(result?.potential ?? 0, base: "V"), tint: BenchTheme.amber)
            }
            PointChargeDiagram(charge: chargeNanoCoulombs, distance: distance)
            ScienceStatus(text: chargeNanoCoulombs == 0 ? "Zero source charge: E and V are zero." : chargeNanoCoulombs > 0 ? "Positive charge: the field points outward." : "Negative charge: the field points inward.", tint: chargeNanoCoulombs < 0 ? BenchTheme.cyan : BenchTheme.amber)
            Text("Arrows show direction only. The probe position scales from 0 to 3 m.")
                .font(.caption).foregroundStyle(BenchTheme.muted)
        }
        InstrumentPanel(title: "Source & probe") {
            ParameterSlider(title: "Source charge", value: $chargeNanoCoulombs, range: -10...10, unit: "nC", format: "%.2f")
            ParameterSlider(title: "Probe distance", value: $distance, range: 0.1...3, unit: "m", format: "%.2f")
        }
        FormulaNote(equation: "Eᵣ = q/(4πε₀r²)    V = q/(4πε₀r)", explanation: "Electric field is force per unit positive test charge. Doubling distance reduces field strength to one quarter, while potential falls to one half. Positive radial field means outward; negative means toward the charge. Potential is defined to be zero at infinity.")
        ScienceLimits(text: "One stationary point charge in vacuum. No conductors, dielectric materials, other charges, magnetic fields, or radiation. The ideal source is singular at r = 0, so the probe stops at 0.10 m. This is an electrostatic model, not a propagation simulation.")
        ScienceReference(title: "Ellingson · Coulomb’s law", url: "https://phys.libretexts.org/Bookshelves/Electricity_and_Magnetism/Electromagnetics_I_(Ellingson)/05:_Electrostatics/5.01:_Coulombs_Law")
    }
}

private struct CommunicationsBench: View {
    @State private var carrierFrequency = 60.0
    @State private var messageFrequency = 4.0
    @State private var modulationIndex = 0.65

    var body: some View {
        InstrumentPanel(title: "Put a message on a carrier", subtitle: "Full-carrier amplitude modulation, with a 1 V carrier amplitude.") {
            ScienceMeterRow {
                MeterValue(label: "Modulation", value: ScienceFormat.decimal(modulationIndex * 100, digits: 0), unit: "%", tint: modulationIndex > 1 ? BenchTheme.amber : BenchTheme.cyan)
                MeterValue(label: "Occupied bandwidth", value: ScienceFormat.decimal(modulationIndex > 0 ? 2 * messageFrequency : 0, digits: 1), unit: "Hz", tint: BenchTheme.green)
            }
            amPlot
            ScienceLegend(items: [("Modulated carrier", BenchTheme.cyan), ("Signed envelope", BenchTheme.amber)])
            ScienceStatus(text: modulationIndex > 1 ? "Overmodulation: the signed envelope crosses zero." : modulationIndex == 1 ? "100% modulation: the envelope just touches zero." : "An ideal envelope detector can recover this message.", tint: modulationIndex > 1 ? BenchTheme.amber : BenchTheme.green)
            Text(modulationIndex == 0 ? "Carrier only; no sidebands at μ = 0." : "Sidebands: \(ScienceFormat.decimal(carrierFrequency - messageFrequency, digits: 1)) Hz and \(ScienceFormat.decimal(carrierFrequency + messageFrequency, digits: 1)) Hz")
                .font(.subheadline.monospacedDigit()).foregroundStyle(BenchTheme.muted)
        }
        InstrumentPanel(title: "Modulator") {
            ParameterSlider(title: "Carrier frequency f𝒸", value: $carrierFrequency, range: 30...100, unit: "Hz", format: "%.1f")
            ParameterSlider(title: "Message frequency fₘ", value: $messageFrequency, range: 1...10, unit: "Hz", format: "%.1f")
            ParameterSlider(title: "Modulation index μ", value: $modulationIndex, range: 0...1.5, unit: "", format: "%.2f")
        }
        FormulaNote(equation: "s(t) = [1 + μ cos(2πfₘt)] cos(2πf𝒸t)", explanation: "Multiplication moves a message to a carrier and creates components at f𝒸 − fₘ and f𝒸 + fₘ. At μ = 0, only the carrier remains. For 0 < μ ≤ 1, its envelope retains the message. Above 1, the carrier phase reverses where the signed envelope becomes negative.")
        ScienceLimits(text: "Ideal single-tone AM in voltage, with a carrier slowed for inspection. Bandwidth 2fₘ describes the sideband spacing; sidebands vanish at μ = 0. No transmitter power stage, receiver dynamics, noise, channel loss, antenna, or RF propagation. A simple envelope detector distorts overmodulated signals.")
        ScienceReference(title: "Analog Devices · AM & envelope detectors", url: "https://ez.analog.com/adiacademy/university-program/a/studentzone-articles/SA1085/adalm2000-amplitude-modulation-envelope-detectors")
    }

    private var amPlot: some View {
        let duration = 0.5
        let waveform = (0...1_200).map { ScientificModels.amplitudeModulation(time: duration * Double($0) / 1_200, carrierFrequency: carrierFrequency, messageFrequency: messageFrequency, modulationIndex: modulationIndex) ?? 0 }
        let envelope = (0...400).map { 1 + modulationIndex * cos(2 * .pi * messageFrequency * duration * Double($0) / 400) }
        return SciencePlot(traces: [.init(values: waveform, color: BenchTheme.cyan), .init(values: envelope, color: BenchTheme.amber, dashed: true), .init(values: envelope.map { -$0 }, color: BenchTheme.amber, dashed: true)],
                           xRange: 0...duration, yRange: -2.6...2.6,
                           xLabel: "Time · s", yLabel: "Voltage · V", leadingX: "0", trailingX: "0.5", topY: "+2.6", bottomY: "−2.6",
                           summary: "Amplitude modulated waveform. Carrier \(ScienceFormat.decimal(carrierFrequency, digits: 1)) hertz, message \(ScienceFormat.decimal(messageFrequency, digits: 1)) hertz, modulation index \(ScienceFormat.decimal(modulationIndex, digits: 2)).")
    }
}

private struct PowerBench: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var voltageRMS = 120.0
    @State private var currentRMS = 2.0
    @State private var phaseDegrees = 35.0

    private var result: ScientificModels.ACPower? {
        ScientificModels.acPower(voltageRMS: voltageRMS, currentRMS: currentRMS, phaseDegrees: phaseDegrees)
    }

    var body: some View {
        InstrumentPanel(title: "Where does AC power go?", subtitle: "Single-phase, sinusoidal voltage and current at 50 Hz.") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), alignment: .leading, spacing: 18) {
                MeterValue(label: "Real P", value: ScienceFormat.number(result?.real ?? 0), unit: ScienceFormat.unit(result?.real ?? 0, base: "W"), tint: BenchTheme.cyan)
                MeterValue(label: "Reactive Q", value: ScienceFormat.number(result?.reactive ?? 0), unit: ScienceFormat.unit(result?.reactive ?? 0, base: "var"), tint: BenchTheme.amber)
                MeterValue(label: "Apparent S", value: ScienceFormat.number(result?.apparent ?? 0), unit: ScienceFormat.unit(result?.apparent ?? 0, base: "VA"), tint: BenchTheme.green)
                MeterValue(label: "Power factor", value: ScienceFormat.decimal(result?.powerFactor ?? 1, digits: 3), unit: "", tint: BenchTheme.ink)
            }
            PowerTriangle(real: result?.real ?? 0, reactive: result?.reactive ?? 0, apparent: result?.apparent ?? 0)
            powerPlot
            ScienceLegend(items: [("Instantaneous p(t)", BenchTheme.cyan), ("Average P", BenchTheme.amber)])
            ScienceStatus(text: abs(phaseDegrees) < 0.01 ? "In phase: all apparent power is real power." : phaseDegrees > 0 ? "Current lags voltage: positive inductive reactive power." : "Current leads voltage: negative capacitive reactive power.", tint: abs(phaseDegrees) < 0.01 ? BenchTheme.green : BenchTheme.amber)
        }
        InstrumentPanel(title: "Load measurements", subtitle: "φ is voltage phase minus current phase.") {
            ParameterSlider(title: "Voltage RMS", value: $voltageRMS, range: 10...240, unit: "V", format: "%.1f")
            ParameterSlider(title: "Current RMS", value: $currentRMS, range: 0.1...10, unit: "A", format: "%.2f")
            ParameterSlider(title: "Phase difference φ", value: $phaseDegrees, range: -90...90, unit: "°", format: "%.1f")
        }
        FormulaNote(equation: "S = VᵣₘₛIᵣₘₛ    P = S cos φ    Q = S sin φ", explanation: "Real power is the average energy delivered per second. Reactive power describes energy exchanged with inductors and capacitors. Apparent power is the product of RMS voltage and current. For these sine waves, S² = P² + Q² and power factor = cos φ.")
        ScienceLimits(text: "Sinusoidal, single-phase steady state with passive sign convention and ideal RMS measurements. No harmonics, transients, losses, or three-phase system. For distorted current, total power factor is not generally cos φ. The triangle preserves the signed Q direction.")
        ScienceReference(title: "NI · Power factor teaching problems", url: "https://download.ni.com/evaluation/academic/ekits/Doering_mydaq_multisim-problems_3rd-printing_optimized.pdf")
    }

    private var powerPlot: some View {
        let apparent = result?.apparent ?? 0
        let real = result?.real ?? 0
        let scale = max(apparent * 2.1, 1)
        return SciencePlot(traces: [
            .init(values: (0...400).map { ScientificModels.instantaneousPower(time: 0.04 * Double($0) / 400, voltageRMS: voltageRMS, currentRMS: currentRMS, phaseDegrees: phaseDegrees) ?? 0 }, color: BenchTheme.cyan),
            .init(values: Array(repeating: real, count: 401), color: BenchTheme.amber, dashed: true)
        ], xRange: 0...0.04, yRange: -scale...scale,
           xLabel: "Time · ms", yLabel: "Power · W", leadingX: "0", trailingX: "40", topY: ScienceFormat.quantity(scale, "W"), bottomY: ScienceFormat.quantity(-scale, "W"),
           summary: "Instantaneous power across 40 milliseconds. Average power \(ScienceFormat.quantity(real, "W")). Negative portions return energy to the source.")
    }
}

// MARK: - Physical plots with visible scales

private struct ScienceMeterRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder var content: Content

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(spacing: 16))
        layout { content }
    }
}

private struct SciencePlot: View {
    struct Trace {
        let values: [Double]
        let color: Color
        var dashed = false
    }

    struct Dot {
        let x: Double
        let y: Double
        let color: Color
    }

    let traces: [Trace]
    let xRange: ClosedRange<Double>
    let yRange: ClosedRange<Double>
    var dots: [Dot] = []
    let xLabel: String
    let yLabel: String
    let leadingX: String
    let trailingX: String
    let topY: String
    let bottomY: String
    let summary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(yLabel).font(.caption).foregroundStyle(BenchTheme.muted)
            HStack(alignment: .top, spacing: 7) {
                VStack(alignment: .trailing) {
                    Text(topY)
                    Spacer()
                    Text(bottomY)
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(BenchTheme.muted)
                .frame(width: 66, height: 168)
                Canvas { context, size in
                    func point(_ x: Double, _ y: Double) -> CGPoint {
                        let xFraction = (x - xRange.lowerBound) / (xRange.upperBound - xRange.lowerBound)
                        let yFraction = (y - yRange.lowerBound) / (yRange.upperBound - yRange.lowerBound)
                        return CGPoint(x: size.width * xFraction, y: size.height * (1 - yFraction))
                    }
                    var grid = Path()
                    for index in 0...4 {
                        let fraction = CGFloat(index) / 4
                        grid.move(to: CGPoint(x: size.width * fraction, y: 0))
                        grid.addLine(to: CGPoint(x: size.width * fraction, y: size.height))
                        grid.move(to: CGPoint(x: 0, y: size.height * fraction))
                        grid.addLine(to: CGPoint(x: size.width, y: size.height * fraction))
                    }
                    context.stroke(grid, with: .color(BenchTheme.muted.opacity(0.18)), lineWidth: 0.7)
                    if yRange.contains(0) {
                        var zero = Path()
                        zero.move(to: point(xRange.lowerBound, 0))
                        zero.addLine(to: point(xRange.upperBound, 0))
                        context.stroke(zero, with: .color(BenchTheme.muted.opacity(0.4)), lineWidth: 1)
                    }
                    for trace in traces where trace.values.count > 1 {
                        var path = Path()
                        var hasPoint = false
                        for (index, value) in trace.values.enumerated() where value.isFinite {
                            let x = xRange.lowerBound + Double(index) / Double(trace.values.count - 1) * (xRange.upperBound - xRange.lowerBound)
                            let position = point(x, value)
                            if hasPoint { path.addLine(to: position) } else { path.move(to: position); hasPoint = true }
                        }
                        context.stroke(path, with: .color(trace.color), style: StrokeStyle(lineWidth: trace.dashed ? 1.3 : 2, lineJoin: .round, dash: trace.dashed ? [5, 4] : []))
                    }
                    for dot in dots where dot.x.isFinite && dot.y.isFinite && xRange.contains(dot.x) {
                        let position = point(dot.x, dot.y)
                        let diameter: CGFloat = dots.count > 2 ? 4 : 9
                        context.fill(Path(ellipseIn: CGRect(x: position.x - diameter / 2, y: position.y - diameter / 2, width: diameter, height: diameter)), with: .color(dot.color))
                    }
                }
                .frame(height: 168)
                .clipped()
                .accessibilityHidden(true)
            }
            HStack {
                Text(leadingX)
                Spacer()
                Text(xLabel)
                Spacer()
                Text(trailingX)
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(BenchTheme.muted)
            .padding(.leading, 73)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
        .padding(.vertical, 8)
    }
}

private struct PointChargeDiagram: View {
    let charge: Double
    let distance: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 0.44, y: size.height * 0.5)
            let scale = min(size.height * 0.42, size.width * 0.43) / 3
            let maximumRadius = 3 * scale
            for radius in [1.0, 2.0, 3.0] {
                context.stroke(Path(ellipseIn: CGRect(x: center.x - radius * scale, y: center.y - radius * scale, width: radius * 2 * scale, height: radius * 2 * scale)), with: .color(BenchTheme.muted.opacity(0.2)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
            if charge != 0 {
                let color = charge > 0 ? BenchTheme.amber : BenchTheme.cyan
                for index in 0..<8 {
                    let angle = Double(index) * .pi / 4
                    let inner = CGPoint(x: center.x + cos(angle) * maximumRadius * 0.32, y: center.y + sin(angle) * maximumRadius * 0.32)
                    let outer = CGPoint(x: center.x + cos(angle) * maximumRadius * 0.84, y: center.y + sin(angle) * maximumRadius * 0.84)
                    ScienceDrawing.arrow(context: &context, from: charge > 0 ? inner : outer, to: charge > 0 ? outer : inner, color: color)
                }
            }
            context.fill(Path(ellipseIn: CGRect(x: center.x - 17, y: center.y - 17, width: 34, height: 34)), with: .color(charge < 0 ? BenchTheme.cyan : BenchTheme.amber))
            let symbol = charge == 0 ? "0" : charge > 0 ? "+" : "−"
            context.draw(Text(symbol).font(.title3.bold()).foregroundStyle(BenchTheme.bg), at: center)
            let probe = CGPoint(x: center.x + distance * scale, y: center.y)
            context.stroke(Path(ellipseIn: CGRect(x: probe.x - 8, y: probe.y - 8, width: 16, height: 16)), with: .color(BenchTheme.ink), lineWidth: 2)
            context.draw(Text("probe").font(.caption).foregroundStyle(BenchTheme.ink), at: CGPoint(x: probe.x, y: probe.y + 25))
            context.draw(Text("3 m").font(.caption).foregroundStyle(BenchTheme.muted), at: CGPoint(x: center.x, y: center.y + maximumRadius + 13))
        }
        .frame(height: 230)
        .accessibilityLabel("Point charge diagram. Charge \(ScienceFormat.decimal(charge, digits: 2)) nanocoulombs. Probe \(ScienceFormat.decimal(distance, digits: 2)) meters from the source. Field \(charge < 0 ? "inward" : charge > 0 ? "outward" : "zero").")
    }
}

private struct PowerTriangle: View {
    let real: Double
    let reactive: Double
    let apparent: Double

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width * 0.68, size.height * 0.45) / max(apparent, 0.001)
            let origin = CGPoint(x: size.width * 0.15, y: size.height / 2)
            let realEnd = CGPoint(x: origin.x + max(0, real) * scale, y: origin.y)
            let tip = CGPoint(x: realEnd.x, y: origin.y - reactive * scale)
            ScienceDrawing.arrow(context: &context, from: origin, to: realEnd, color: BenchTheme.cyan)
            ScienceDrawing.arrow(context: &context, from: realEnd, to: tip, color: BenchTheme.amber)
            var hypotenuse = Path()
            hypotenuse.move(to: origin)
            hypotenuse.addLine(to: tip)
            context.stroke(hypotenuse, with: .color(BenchTheme.green), lineWidth: 2)
            context.draw(Text("P").font(.caption.bold()).foregroundStyle(BenchTheme.cyan), at: CGPoint(x: (origin.x + realEnd.x) / 2, y: origin.y + 15))
            context.draw(Text("Q").font(.caption.bold()).foregroundStyle(BenchTheme.amber), at: CGPoint(x: realEnd.x + 15, y: (origin.y + tip.y) / 2))
            context.draw(Text("S").font(.caption.bold()).foregroundStyle(BenchTheme.green), at: CGPoint(x: (origin.x + tip.x) / 2 - 10, y: (origin.y + tip.y) / 2 - 12))
        }
        .frame(height: 170)
        .accessibilityLabel("Power triangle: horizontal real power \(ScienceFormat.quantity(real, "watts")); signed vertical reactive power \(ScienceFormat.quantity(reactive, "vars")); hypotenuse apparent power \(ScienceFormat.quantity(apparent, "volt-amperes")).")
    }
}

private enum ScienceDrawing {
    static func arrow(context: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        guard hypot(to.x - from.x, to.y - from.y) > 1 else { return }
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        let angle = atan2(to.y - from.y, to.x - from.x)
        for side in [-1.0, 1.0] {
            path.move(to: to)
            path.addLine(to: CGPoint(x: to.x - 7 * cos(angle + side * 0.5), y: to.y - 7 * sin(angle + side * 0.5)))
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }
}

private struct ScienceStatus: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Circle().fill(tint).frame(width: 7, height: 7).padding(.top, 6)
            Text(text).font(.subheadline).foregroundStyle(BenchTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct ScienceLegend: View {
    let items: [(String, Color)]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { legendItems }
            VStack(alignment: .leading, spacing: 8) { legendItems }
        }
    }

    private var legendItems: some View {
        ForEach(items.indices, id: \.self) { index in
            HStack(spacing: 6) {
                Capsule().fill(items[index].1).frame(width: 16, height: 3)
                Text(items[index].0).font(.caption).foregroundStyle(BenchTheme.muted)
            }
        }
    }
}

private struct ScienceLimits: View {
    let text: String

    var body: some View {
        InstrumentPanel(title: "Model boundaries") {
            Text(text).font(.footnote).foregroundStyle(BenchTheme.muted).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ScienceReference: View {
    let title: String
    let url: String

    var body: some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "book.closed")
                    Text(title).font(.footnote).multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                }
                .frame(minHeight: 44)
                .foregroundStyle(BenchTheme.cyan)
            }
            .accessibilityHint("Opens the primary teaching reference in your browser.")
        }
    }
}

private enum ScienceFormat {
    private static func prefix(_ value: Double) -> (scale: Double, symbol: String) {
        let magnitude = abs(value)
        if magnitude == 0 { return (1, "") }
        if magnitude >= 1e9 { return (1e9, "G") }
        if magnitude >= 1e6 { return (1e6, "M") }
        if magnitude >= 1e3 { return (1e3, "k") }
        if magnitude >= 1 { return (1, "") }
        if magnitude >= 1e-3 { return (1e-3, "m") }
        if magnitude >= 1e-6 { return (1e-6, "µ") }
        if magnitude >= 1e-9 { return (1e-9, "n") }
        if magnitude >= 1e-12 { return (1e-12, "p") }
        return (1e-15, "f")
    }

    static func decimal(_ value: Double, digits: Int) -> String {
        guard value.isFinite else { return "—" }
        let cleaned = abs(value) < pow(10, -Double(digits)) / 2 ? 0 : value
        return String(format: "%.*f", digits, cleaned)
    }

    static func number(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return decimal(value / prefix(value).scale, digits: 3)
    }

    static func unit(_ value: Double, base: String) -> String { prefix(value).symbol + base }
    static func quantity(_ value: Double, _ base: String) -> String { number(value) + " " + unit(value, base: base) }
}
