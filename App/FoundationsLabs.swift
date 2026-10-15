import SwiftUI

struct FoundationsLessonLab: View {
    let lessonID: String
    var body: some View {
        switch lessonID {
        case "calculus": CalculusExperiment()
        case "linear-algebra": AlgebraExperiment()
        case "differential-equations": DifferentialExperiment()
        case "probability": ProbabilityExperiment()
        case "matter": MatterExperiment()
        case "inductors": InductorExperiment()
        case "resonance": ResonanceExperiment()
        case "network-analysis": NetworkExperiment()
        case "bjt": BJTExperiment()
        case "mosfet": MOSExperiment()
        case "analog-design": AnalogExperiment()
        default: BenchScreen { Text("This foundations experiment is unavailable.") }
        }
    }
}

private struct CalculusExperiment: View {
    @State private var mode = 0
    @State private var mean = 1.0
    @State private var amplitude = 1.0
    @State private var frequency = 1.0
    @State private var slope = 0.5
    @State private var time = 1.0
    private func point(_ t: Double) -> FoundationsModels.CalculusPoint? {
        mode == 0 ? FoundationsModels.sineCurrent(time: t, mean: mean*1e-3, amplitude: amplitude*1e-3, frequency: frequency)
            : FoundationsModels.rampCurrent(time: t, initial: mean*1e-3, slope: slope*1e-3)
    }
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "Foundations / calculus", title: "Current is charge's slope", subtitle: "Draw a rate. Watch its signed area accumulate.")
            Picker("Waveform", selection: $mode) { Text("Sine + DC").tag(0); Text("Ramp").tag(1) }.pickerStyle(.segmented)
            if let p = point(time), let currents = foundationSamples(0...3, { point($0).map { $0.current*1e3 } }), let charges = foundationSamples(0...3, { point($0).map { $0.charge*1e3 } }) {
                InstrumentPanel(title: "Rate and accumulation") {
                    LessonPlot(traces: [.init(values: currents, color: BenchTheme.amber, name: "I(t)")], xRange: 0...3, yRange: foundationRange(currents), xLabel: "Time [s]", yLabel: "Current [mA]")
                    LessonPlot(traces: [.init(values: charges, color: BenchTheme.cyan, name: "Q(t) − Q(0)")], xRange: 0...3, yRange: foundationRange(charges), xLabel: "Time [s]", yLabel: "Charge [mC]")
                    HStack { foundationMeter("Current at t", p.current*1e3, "mA"); foundationMeter("Transferred charge", p.charge*1e3, "mC") }
                }
            } else { foundationError }
            InstrumentPanel(title: "Define the waveform") {
                ParameterSlider(title: "Initial / mean current", value: $mean, range: -2...2, unit: "mA")
                if mode == 0 {
                    ParameterSlider(title: "AC amplitude", value: $amplitude, range: 0...2, unit: "mA")
                    ParameterSlider(title: "Frequency", value: $frequency, range: 0.1...5, unit: "Hz")
                } else { ParameterSlider(title: "Current slope", value: $slope, range: -1...1, unit: "mA/s") }
                ParameterSlider(title: "Inspect time", value: $time, range: 0...3, unit: "s")
            }
            FormulaNote(equation: mode == 0 ? "I = I₀ + A sin(ωt)\nQ = I₀t + A(1 − cos ωt)/ω" : "I = I₀ + kt\nQ = I₀t + ½kt²", explanation: "The derivative dQ/dt is current. The integral of signed current is transferred charge. A negative current subtracts charge from the chosen direction; it does not mean charge disappears.")
            LessonCheck(prompt: mode == 0 ? "Before checking: how much charge does the AC part transfer over one full period?" : "If the ramp starts at zero, how does charge change when you double the interval?", answer: mode == 0 ? "The sine's positive and negative areas cancel. At T = 1/f, Q = I₀/f = \(foundationNumber(mean/frequency)) mC; the AC contribution is zero." : "Q = ½kt², so doubling time multiplies the transferred charge by four. With a nonzero I₀, the linear part only doubles.")
            LessonModelNote(text: "An imposed mathematical current waveform, not a circuit solution. Initial transferred charge is zero; no particle trajectories, wire propagation or numerical integration error is modeled.")
            FoundationReference(title: "MIT · Fundamental theorem of calculus", url: "https://ocw.mit.edu/courses/res-18-001-calculus-fall-2023/pages/open-textbook/")
        }
    }
}

private struct AlgebraExperiment: View {
    @State private var mode = 0
    @State private var supply = 5.0
    @State private var r2 = 2.0
    @State private var r3 = 1.0
    @State private var frequency = 100.0
    @State private var capacitance = 1.0
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "Foundations / linear algebra", title: "A circuit becomes a matrix", subtitle: "Solve two unknown voltages, then rotate into complex numbers.")
            Picker("Representation", selection: $mode) { Text("Two nodes").tag(0); Text("RC phasor").tag(1) }.pickerStyle(.segmented)
            if mode == 0 {
                if let p = FoundationsModels.twoNode(supply: supply, r1: 1_000, r2: r2*1_000, r3: r3*1_000, r4: 2_000),
                   let a = foundationSamples(0...12, { FoundationsModels.twoNode(supply: $0, r1: 1_000, r2: r2*1_000, r3: r3*1_000, r4: 2_000)?.va }),
                   let b = foundationSamples(0...12, { FoundationsModels.twoNode(supply: $0, r1: 1_000, r2: r2*1_000, r3: r3*1_000, r4: 2_000)?.vb }) {
                    InstrumentPanel(title: "Vs → R1 → A → R3 → B", subtitle: "R2: A to ground · R4: B to ground · R1 = 1 kΩ · R4 = 2 kΩ") {
                        LessonPlot(traces: [.init(values: a, color: BenchTheme.cyan, name: "VA"), .init(values: b, color: BenchTheme.amber, name: "VB")], xRange: 0...12, yRange: 0...12, xLabel: "Source voltage [V]", yLabel: "Node voltage [V]")
                        HStack { foundationMeter("VA", p.va, "V"); foundationMeter("VB", p.vb, "V") }
                        Text(String(format: "[ %.3f  %.3f ] [ VA ] = [ %.3f ]\n[ %.3f  %.3f ] [ VB ]   [ 0 ]", p.g11*1e3, p.g12*1e3, p.rhs*1e3, p.g12*1e3, p.g22*1e3)).font(.caption.monospaced())
                        Text("Matrix coefficients: mS · right-hand side: mA. Maximum KCL residual \(engineering(max(abs(p.kclA), abs(p.kclB)), unit: "A"))").font(.caption)
                    }
                } else { foundationError }
                InstrumentPanel(title: "Change the matrix") {
                    ParameterSlider(title: "Source", value: $supply, range: 0...12, unit: "V")
                    ParameterSlider(title: "R2", value: $r2, range: 0.2...10, unit: "kΩ")
                    ParameterSlider(title: "R3", value: $r3, range: 0.2...10, unit: "kΩ")
                }
                FormulaNote(equation: "[G]v = i\nG₁₁ = g₁+g₂+g₃ · G₁₂ = −g₃ · G₂₂ = g₃+g₄", explanation: "Each row is a node's KCL equation. The negative off-diagonal entry records current flowing between nodes. Positive resistances and grounded paths make this two-node system uniquely solvable.")
            } else {
                if let p = FoundationsModels.rcTransfer(resistance: 1_000, capacitance: capacitance*1e-6, sigma: 0, omega: 2*Double.pi*frequency),
                   let real = foundationSamples(0...2_000, { FoundationsModels.rcTransfer(resistance: 1_000, capacitance: capacitance*1e-6, sigma: 0, omega: 2*Double.pi*$0)?.real }),
                   let imag = foundationSamples(0...2_000, { FoundationsModels.rcTransfer(resistance: 1_000, capacitance: capacitance*1e-6, sigma: 0, omega: 2*Double.pi*$0)?.imaginary }) {
                    InstrumentPanel(title: "Real and imaginary parts share one scale") {
                        LessonPlot(traces: [.init(values: real, color: BenchTheme.cyan, name: "Re H"), .init(values: imag, color: BenchTheme.amber, name: "Im H")], xRange: 0...2_000, yRange: -1...1, xLabel: "Frequency [Hz]", yLabel: "Transfer [V/V]")
                        HStack { foundationMeter("Magnitude", p.magnitude, "V/V"); foundationMeter("Phase", p.phase*180/Double.pi, "°") }
                        Text("H = \(foundationNumber(p.real)) + j(\(foundationNumber(p.imaginary)))").font(.headline.monospaced())
                    }
                } else { foundationError }
                InstrumentPanel(title: "Rotate the transfer") {
                    ParameterSlider(title: "Frequency", value: $frequency, range: 1...2_000, unit: "Hz")
                    ParameterSlider(title: "Capacitance", value: $capacitance, range: 0.1...10, unit: "µF")
                }
                FormulaNote(equation: "H = 1/(1+jωRC)\n|H| = √(Re²+Im²) · φ = atan2(Im, Re)", explanation: "Complex numbers keep amplitude and phase in one quantity. Imaginary is not an extra voltage source: it records a quarter-cycle basis component of the same sinusoid.")
            }
            LessonCheck(prompt: "Predict what doubles when the source amplitude doubles. Does the RC transfer H itself change?", answer: "The linear nodal voltages double. A transfer is output divided by input, so H stays unchanged; output amplitude doubles while phase stays fixed.")
            LessonModelNote(text: "A fixed grounded four-resistor topology and an unloaded ideal RC filter. No general symbolic matrix editor, nonlinear component, arbitrary AC network or non-sinusoidal phasor calculation.")
            FoundationReference(title: "SpiceSharp · Nodal matrix derivation", url: "https://spicesharp.github.io/SpiceSharp/articles/tutorials/writing_behaviors/modified_nodal_analysis.html")
        }
    }
}

private struct DifferentialExperiment: View {
    @State private var initial = 0.0
    @State private var target = 1.0
    @State private var tau = 1.0
    @State private var stepRatio = 0.25
    var body: some View {
        let count = max(2, Int(ceil(5/stepRatio)))
        let step = stepRatio*tau
        BenchScreen {
            BenchHeader(eyebrow: "Foundations / differential equations", title: "A slope predicts a future", subtitle: "Compare the exact solution with two numerical rules.")
            if let p = FoundationsModels.firstOrder(initial: initial, target: target, tau: tau, step: step, count: count) {
                InstrumentPanel(title: "One shared physical scale", subtitle: "Changing the step changes numerical error, not the differential equation.") {
                    LessonPlot(traces: [.init(values: p.exact, color: BenchTheme.cyan, name: "Exact"), .init(values: p.forwardEuler, color: BenchTheme.amber, name: "Forward Euler"), .init(values: p.backwardEuler, color: BenchTheme.green, name: "Backward Euler")], xRange: 0...p.times.last!, yRange: foundationRange(p.exact+p.forwardEuler+p.backwardEuler), xLabel: "Time [s]", yLabel: "State x [V]")
                    HStack { foundationMeter("Exact final sample", p.exact.last!, "V"); foundationMeter("Forward error", p.forwardEuler.last!-p.exact.last!, "V") }
                    Text("Δt = \(engineering(step, unit: "s")) · forward error multiplier = \(foundationNumber(p.forwardMultiplier))").font(.caption.monospaced())
                    if abs(p.forwardMultiplier) >= 1 { Text("Forward Euler does not decay its error here. The numerical instability is not an unstable physical RC model.").foregroundStyle(BenchTheme.amber).font(.caption) }
                }
            } else { foundationError }
            InstrumentPanel(title: "Initial condition and step") {
                ParameterSlider(title: "Initial voltage", value: $initial, range: 0...2, unit: "V")
                ParameterSlider(title: "Final voltage", value: $target, range: 0...2, unit: "V")
                ParameterSlider(title: "Time constant", value: $tau, range: 0.1...3, unit: "s")
                ParameterSlider(title: "Step / time constant", value: $stepRatio, range: 0.05...2.5, unit: "Δt/τ")
            }
            FormulaNote(equation: "τx′ + x = u\nx(t) = u + (x₀−u)e^(−t/τ)\nForward: eₙ₊₁=(1−h/τ)eₙ\nBackward: eₙ₊₁=eₙ/(1+h/τ)", explanation: "An initial value fixes the trajectory. Forward Euler samples the starting slope; backward Euler uses the ending slope. Both have first-order timestep error, but different stability behavior.")
            LessonCheck(prompt: "Set x₀=0 and u=1. Predict whether a forward step of 2.5τ settles toward the physical final value.", answer: "Its error multiplier is 1−2.5=−1.5. Error changes sign and grows. Forward Euler's decay requires |1−h/τ|<1, or 0<h<2τ. Backward Euler's multiplier remains between zero and one.")
            LessonModelNote(text: "One scalar linear first-order ODE with a constant input and positive τ. The graph uses uniformly spaced numerical samples; no adaptive integrator, nonlinear ODE or arbitrary higher-order equation is implied.")
            FoundationReference(title: "MIT · Forward and backward Euler", url: "https://web.mit.edu/10.001/Web/Course_Notes/Differential_Equations_Notes/node3.html")
        }
    }
}

private struct ProbabilityExperiment: View {
    @State private var supply = 5.0
    @State private var resistance = 1.0
    @State private var tolerance = 10.0
    @State private var threshold = 5.0
    @State private var sampleCount = 100.0
    @State private var seed = 1.0
    @State private var calibration = 0.0
    var body: some View {
        let fraction = tolerance/100
        BenchScreen {
            BenchHeader(eyebrow: "Foundations / probability", title: "One value becomes a distribution", subtitle: "A uniformly distributed resistor does not produce uniformly distributed current.")
            if let p = FoundationsModels.tolerance(supply: supply, nominalResistance: resistance*1_000, fraction: fraction, threshold: threshold*1e-3) {
                let xMax = max(1, p.maximumCurrent*1e3*1.15)
                if let cdf = foundationSamples(0...xMax, { FoundationsModels.currentCDF(current: $0*1e-3, supply: supply, nominalResistance: resistance*1_000, fraction: fraction) }) {
                    InstrumentPanel(title: "Exact cumulative distribution", subtitle: "CDF = probability current is at or below the horizontal value.") {
                        LessonPlot(traces: [.init(values: cdf, color: BenchTheme.cyan, name: "P(I ≤ i)")], xRange: 0...xMax, yRange: 0...1, xLabel: "Current threshold [mA]", yLabel: "Probability [1]")
                        HStack { foundationMeter("Mean current", p.meanCurrent*1e3, "mA"); foundationMeter("Standard deviation", p.standardDeviation*1e3, "mA") }
                        HStack { foundationMeter("Minimum", p.minimumCurrent*1e3, "mA"); foundationMeter("Maximum", p.maximumCurrent*1e3, "mA") }
                        foundationMeter("P(I > selected threshold)", p.probabilityAbove*100, "%")
                    }
                } else { foundationError }
            } else { foundationError }
            if let statistics = FoundationsModels.resistorSamples(supply: supply, nominalResistance: resistance*1_000, fraction: fraction, count: Int(sampleCount.rounded()), seed: UInt64(seed.rounded()), calibrationOffset: calibration*1e-3) {
                let means = statistics.runningMeans.map { $0*1e3 }
                let expected = statistics.expectedMeasuredMean*1e3
                InstrumentPanel(title: "Repeatable virtual measurements", subtitle: "Pseudorandom draws under the same uniform-resistance assumption.") {
                    LessonPlot(traces: [.init(values: means, color: BenchTheme.amber, name: "Running sample mean"), .init(values: Array(repeating: expected, count: means.count), color: BenchTheme.green, name: "Expected measured mean")], xRange: 1...Double(means.count), yRange: foundationRange(means+[expected]), xLabel: "Sample count [1]", yLabel: "Measured mean [mA]")
                    HStack { foundationMeter("Sample mean", statistics.mean*1e3, "mA"); foundationMeter("Model mean + bias", expected, "mA") }
                    if let deviation = statistics.sampleStandardDeviation, let error = statistics.standardError {
                        Text("Sample s = \(foundationNumber(deviation*1e3)) mA · estimated standard error = \(foundationNumber(error*1e3)) mA").font(.caption.monospaced())
                    }
                }
            } else { foundationError }
            InstrumentPanel(title: "State a statistical assumption") {
                ParameterSlider(title: "Source voltage", value: $supply, range: 1...12, unit: "V")
                ParameterSlider(title: "Nominal resistance", value: $resistance, range: 0.5...5, unit: "kΩ")
                ParameterSlider(title: "Uniform half-width", value: $tolerance, range: 0...30, unit: "%")
                ParameterSlider(title: "Current threshold", value: $threshold, range: 0...30, unit: "mA")
                ParameterSlider(title: "Measurement count", value: $sampleCount, range: 5...500, unit: "", format: "%.0f")
                ParameterSlider(title: "Repeatable seed", value: $seed, range: 1...99, unit: "", format: "%.0f")
                ParameterSlider(title: "Fixed calibration offset", value: $calibration, range: -1...1, unit: "mA")
            }
            FormulaNote(equation: "R ∼ Uniform(a,b) · I = V/R\nE[I] = V ln(b/a)/(b−a)\nE[I²] = V²/(ab)", explanation: "Expectation integrates each possible reading weighted by its probability density. Taking a reciprocal changes the distribution's shape; evaluating I at the mean resistance is not generally the mean current.")
            LessonCheck(prompt: "For symmetric resistor tolerance, is the mean current larger than V/Rnom? Will more samples remove a fixed calibration offset?", answer: "For nonzero width the true mean is larger: 1/R is convex. At 5 V, 1 kΩ and ±10%, it is about 5.0168 mA. The measured mean converges toward that value plus the fixed offset, so averaging cannot remove bias. A manufacturer tolerance alone does not establish a uniform law.")
            LessonModelNote(text: "Exact transformed distribution plus reproducible SplitMix64 pseudorandom draws under an independent uniform resistance assumption. Voltage is deterministic; the instrument has one fixed additive bias. No correlated manufacturing data, thermal drift or extra measurement noise is inferred. s uses N−1; s/√N is an estimated standard error, not a guaranteed interval. Zero width is a point distribution.")
            FoundationReference(title: "MIT · Continuous expectation and variance", url: "https://ocw.mit.edu/courses/18-05-introduction-to-probability-and-statistics-spring-2022/resources/mit18_05_s22_class06-prep-a_pdf/")
        }
    }
}

private struct MatterExperiment: View {
    @State private var mode = 0
    @State private var logDensity = 22.0
    @State private var mobility = 0.1
    @State private var voltage = 1.0
    @State private var power = 10.0
    @State private var mass = 50.0
    @State private var specificHeat = 900.0
    @State private var time = 30.0
    @State private var wavelength = 550.0
    @State private var force = 5.0
    @State private var displacement = 1.0
    @State private var angle = 0.0
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "Foundations / matter and energy", title: "The material matters", subtitle: "Connect mobile charge, heating and individual photon energy.")
            Picker("Model", selection: $mode) { Text("Carriers").tag(0); Text("Heat").tag(1); Text("Photons").tag(2); Text("Work").tag(3) }.pickerStyle(.segmented)
            if mode == 0 {
                if let p = FoundationsModels.conductor(density: pow(10, logDensity), mobility: mobility, length: 0.01, area: 1e-6, voltage: voltage),
                   let values = foundationSamples(16...26, { FoundationsModels.conductor(density: pow(10, $0), mobility: mobility, length: 0.01, area: 1e-6, voltage: voltage)?.conductivity }) {
                    InstrumentPanel(title: "One carrier species", subtitle: "Uniform bar: length 1 cm · cross-section 1 mm²") {
                        LessonPlot(traces: [.init(values: values, color: BenchTheme.cyan, name: "σ = qnμ")], xRange: 16...26, yRange: 0...max(1, values.max()!), xLabel: "log₁₀(n / m⁻³) [1]", yLabel: "Conductivity [S/m]")
                        Text("σ = \(engineering(p.conductivity, unit: "S/m")) · R = \(engineering(p.resistance, unit: "Ω"))").font(.headline.monospaced())
                        Text("I = \(engineering(p.current, unit: "A")) · P = \(engineering(p.power, unit: "W"))").font(.caption.monospaced())
                    }
                } else { foundationError }
                InstrumentPanel(title: "Charge and mobility") {
                    ParameterSlider(title: "log₁₀ carrier density", value: $logDensity, range: 16...26, unit: "log₁₀(m⁻³)")
                    ParameterSlider(title: "Mobility", value: $mobility, range: 0.001...0.2, unit: "m²/(V·s)", format: "%.3f")
                    ParameterSlider(title: "Applied voltage", value: $voltage, range: -2...2, unit: "V")
                }
                FormulaNote(equation: "J = σE · σ = qnμ\nR = ℓ/(σA) · P = VI", explanation: "Carrier density and mobility both matter. Conventional current follows the electric field even for negatively charged electrons, because their drift direction and charge sign both reverse.")
            } else if mode == 1 {
                if let p = FoundationsModels.heating(power: power, mass: mass*1e-3, specificHeat: specificHeat, time: time, initialTemperature: 300),
                   let temperatures = foundationSamples(0...60, { FoundationsModels.heating(power: power, mass: mass*1e-3, specificHeat: specificHeat, time: $0, initialTemperature: 300)?.temperature }) {
                    InstrumentPanel(title: "Electrical work becomes internal energy") {
                        LessonPlot(traces: [.init(values: temperatures, color: BenchTheme.amber, name: "Adiabatic temperature")], xRange: 0...60, yRange: 300...max(301, temperatures.max()!), xLabel: "Time [s]", yLabel: "Temperature [K]")
                        HStack { foundationMeter("Temperature", p.temperature, "K"); foundationMeter("Added energy", p.energy, "J") }
                    }
                } else { foundationError }
                InstrumentPanel(title: "Heat capacity") {
                    ParameterSlider(title: "Constant absorbed power", value: $power, range: 1...20, unit: "W")
                    ParameterSlider(title: "Mass", value: $mass, range: 20...200, unit: "g")
                    ParameterSlider(title: "Specific heat", value: $specificHeat, range: 400...4200, unit: "J/(kg·K)", format: "%.0f")
                    ParameterSlider(title: "Inspect time", value: $time, range: 0...60, unit: "s")
                }
                FormulaNote(equation: "W = Pt = mcΔT", explanation: "A watt is a joule per second. Heat capacity connects added internal energy to temperature change; mass and specific heat are separate factors.")
            } else if mode == 2 {
                if let p = FoundationsModels.photon(wavelength: wavelength*1e-9), let energies = foundationSamples(200...1000, { FoundationsModels.photon(wavelength: $0*1e-9)?.electronVolts }) {
                    InstrumentPanel(title: "Energy per photon") {
                        LessonPlot(traces: [.init(values: energies, color: BenchTheme.cyan, name: "hc/λ")], xRange: 200...1000, yRange: 0...7, xLabel: "Wavelength [nm]", yLabel: "Photon energy [eV]")
                        HStack { foundationMeter("Energy", p.electronVolts, "eV"); foundationMeter("Frequency", p.frequency*1e-12, "THz") }
                        Text("One photon: \(engineering(p.energy, unit: "J"))").font(.caption.monospaced())
                    }
                } else { foundationError }
                InstrumentPanel(title: "Choose a wavelength") { ParameterSlider(title: "Wavelength", value: $wavelength, range: 200...1000, unit: "nm", format: "%.0f") }
                FormulaNote(equation: "E = hf = hc/λ", explanation: "Shorter wavelength means more energy per photon. Optical power also depends on how many photons arrive per second; color alone does not determine total power.")
            } else {
                if let work = FoundationsModels.mechanicalWork(force: force, displacement: displacement, angleDegrees: angle),
                   let values = foundationSamples(0...3, { FoundationsModels.mechanicalWork(force: force, displacement: $0, angleDegrees: angle) }) {
                    InstrumentPanel(title: "Only the parallel force does work") {
                        LessonPlot(traces: [.init(values: values, color: BenchTheme.cyan, name: "F·Δx")], xRange: 0...3, yRange: foundationRange(values), xLabel: "Displacement [m]", yLabel: "Mechanical work [J]")
                        foundationMeter("Signed work", work, "J")
                        Text("Parallel force = \(foundationNumber(force*cos(angle*Double.pi/180))) N").font(.caption.monospaced())
                    }
                } else { foundationError }
                InstrumentPanel(title: "Force and motion direction") {
                    ParameterSlider(title: "Force magnitude", value: $force, range: 0...20, unit: "N")
                    ParameterSlider(title: "Displacement", value: $displacement, range: 0...3, unit: "m")
                    ParameterSlider(title: "Force–displacement angle", value: $angle, range: 0...180, unit: "°")
                }
                FormulaNote(equation: "W = F·Δx = F Δx cos θ", explanation: "A force perpendicular to motion does no work. An opposing force does negative work. Joules measure mechanical work and electrical energy using the same unit.")
            }
            LessonCheck(prompt: "Predict the effects of doubling carrier density, doubling mass at fixed heating power, and doubling photon wavelength.", answer: "At fixed mobility, conductivity doubles and resistance halves. Twice the mass gives half the temperature rise. Twice the wavelength gives half the energy per photon.")
            LessonModelNote(text: "Carrier mode uses one uniform low-field species with fixed mobility, no diffusion or band solver. Heat mode is adiabatic with constant specific heat and no phase change or temperature feedback. Photon mode gives one free-space photon's energy, not absorption or band structure. Work mode imposes a constant force and straight displacement; it does not solve a body's motion.")
            FoundationReference(title: "MIT · Drift current and conductivity", url: "https://ocw.mit.edu/courses/6-012-microelectronic-devices-and-circuits-spring-2009/4692cf463514c4f47d8629fab7d41c15_MIT6_012S09_lec03.pdf")
            FoundationReference(title: "OpenStax · Heat capacity", url: "https://openstax.org/books/university-physics-volume-2/pages/1-4-heat-transfer-specific-heat-and-calorimetry")
            FoundationReference(title: "OpenStax · Photon energy", url: "https://openstax.org/books/university-physics-volume-3/pages/6-2-photoelectric-effect")
        }
    }
}

private struct InductorExperiment: View {
    @State private var releasing = false
    @State private var supply = 5.0
    @State private var resistance = 100.0
    @State private var inductance = 100.0
    @State private var elapsed = 1.0
    var body: some View {
        let l = inductance*1e-3, tau = l/resistance, i0 = releasing ? supply/resistance : 0
        let source = releasing ? 0.0 : supply
        BenchScreen {
            BenchHeader(eyebrow: "Stored energy / inductors", title: "Current cannot jump", subtitle: "A continuous resistive loop gives stored magnetic energy a path.")
            Picker("Step", selection: $releasing) { Text("Energize").tag(false); Text("Release").tag(true) }.pickerStyle(.segmented)
            if let p = FoundationsModels.rl(time: elapsed*tau, supply: source, resistance: resistance, inductance: l, initialCurrent: i0),
               let currents = foundationSamples(0...(5*tau), { FoundationsModels.rl(time: $0, supply: source, resistance: resistance, inductance: l, initialCurrent: i0).map { $0.current*1e3 } }),
               let volts = foundationSamples(0...(5*tau), { FoundationsModels.rl(time: $0, supply: source, resistance: resistance, inductance: l, initialCurrent: i0)?.voltage }) {
                InstrumentPanel(title: "Series R–L loop") {
                    LessonPlot(traces: [.init(values: currents, color: BenchTheme.cyan, name: "Inductor current")], xRange: 0...(5*tau), yRange: 0...max(1, supply/resistance*1e3), xLabel: "Time [s]", yLabel: "Current [mA]")
                    LessonPlot(traces: [.init(values: volts, color: BenchTheme.amber, name: "V across L")], xRange: 0...(5*tau), yRange: -supply...supply, xLabel: "Time [s]", yLabel: "Voltage [V]")
                    HStack { foundationMeter("I at t", p.current*1e3, "mA"); foundationMeter("Stored energy", p.energy*1e6, "µJ") }
                    Text("τ = \(engineering(p.tau, unit: "s")) · dI/dt = \(engineering(p.slope, unit: "A/s"))").font(.caption.monospaced())
                }
            } else { foundationError }
            InstrumentPanel(title: "Set the loop") {
                ParameterSlider(title: "Initial / supply voltage", value: $supply, range: 1...12, unit: "V")
                ParameterSlider(title: "Resistance", value: $resistance, range: 10...1000, unit: "Ω", format: "%.0f")
                ParameterSlider(title: "Inductance", value: $inductance, range: 1...500, unit: "mH")
                ParameterSlider(title: "Inspect time", value: $elapsed, range: 0...5, unit: "τ")
            }
            FormulaNote(equation: "L dI/dt + RI = Vₛ\nI = Vₛ/R + (I₀−Vₛ/R)e^(−tR/L)\nW_L = ½LI²", explanation: "The resistor does not consume charge. During release, magnetic energy becomes resistor heat. The negative inductor voltage is the sign required to keep current continuous while it falls.")
            LessonCheck(prompt: "At release, does current instantly become zero? What is the inductor voltage at t=0?", answer: "Current begins at I₀=V/R and decays continuously. V_L(0)=−RI₀=−V. An actually opened ideal loop with nonzero current has no finite-voltage solution; this release model keeps R and L connected.")
            LessonModelNote(text: "Ideal linear inductance, constant R, no magnetic saturation, winding capacitance or losses beyond R. Release shorts the independent source while preserving a closed R–L loop; it does not simulate an open-switch arc.")
            FoundationReference(title: "OpenStax · RL circuits", url: "https://openstax.org/books/university-physics-volume-2/pages/14-5-rl-circuits")
        }
    }
}

private struct ResonanceExperiment: View {
    @State private var mode = 0
    @State private var resistance = 20.0
    @State private var inductance = 10.0
    @State private var capacitance = 10.0
    @State private var supply = 5.0
    @State private var frequencyRatio = 1.0
    var body: some View {
        let l = inductance*1e-3, c = capacitance*1e-6, omega0 = 1/sqrt(l*c), f0 = omega0/(2*Double.pi), end = 12/omega0
        BenchScreen {
            BenchHeader(eyebrow: "Stored energy / resonance", title: "Two stores can exchange energy", subtitle: "Resistance controls damping. A drive can find the resonance.")
            Picker("Experiment", selection: $mode) { Text("Voltage step").tag(0); Text("AC drive").tag(1) }.pickerStyle(.segmented)
            if mode == 0 {
                if let p = FoundationsModels.rlcStep(time: end, supply: supply, resistance: resistance, inductance: l, capacitance: c),
                   let volts = foundationSamples(0...end, { FoundationsModels.rlcStep(time: $0, supply: supply, resistance: resistance, inductance: l, capacitance: c)?.voltage }) {
                    InstrumentPanel(title: "Series RLC · output across C") {
                        LessonPlot(traces: [.init(values: volts, color: BenchTheme.cyan, name: "VC"), .init(values: Array(repeating: supply, count: volts.count), color: BenchTheme.amber, name: "Source step")], xRange: 0...end, yRange: 0...(2.1*supply), xLabel: "Time [s]", yLabel: "Voltage [V]")
                        HStack { foundationMeter("Damping ratio ζ", p.damping, ""); foundationMeter("Natural frequency", f0, "Hz") }
                        Text(p.regime).font(.headline).foregroundStyle(BenchTheme.green)
                    }
                } else { foundationError }
            } else {
                if let p = FoundationsModels.seriesAC(frequency: frequencyRatio*f0, voltagePeak: supply, resistance: resistance, inductance: l, capacitance: c),
                   let currents = foundationSamples((0.1*f0)...(3*f0), count: 2901, { FoundationsModels.seriesAC(frequency: $0, voltagePeak: supply, resistance: resistance, inductance: l, capacitance: c).map { $0.currentPeak*1e3 } }) {
                    InstrumentPanel(title: "Current resonance", subtitle: "The current peak occurs at f₀, where inductive and capacitive reactance cancel.") {
                        LessonPlot(traces: [.init(values: currents, color: BenchTheme.cyan, name: "Current peak")], xRange: (0.1*f0)...(3*f0), yRange: 0...(supply/resistance*1e3*1.05), xLabel: "Drive frequency [Hz]", yLabel: "Current peak [mA]")
                        HStack { foundationMeter("Selected I peak", p.currentPeak*1e3, "mA"); foundationMeter("Current phase", p.currentPhase*180/Double.pi, "°") }
                        HStack { foundationMeter("Q", p.quality, ""); foundationMeter("Capacitor peak", p.capacitorPeak, "V") }
                        foundationMeter("Current half-power bandwidth", p.bandwidth, "Hz")
                        ParameterSlider(title: "Drive / resonance", value: $frequencyRatio, range: 0.1...3, unit: "f/f₀")
                    }
                } else { foundationError }
            }
            InstrumentPanel(title: "Change damping and storage") {
                ParameterSlider(title: "Resistance", value: $resistance, range: 1...200, unit: "Ω")
                ParameterSlider(title: "Inductance", value: $inductance, range: 1...100, unit: "mH")
                ParameterSlider(title: "Capacitance", value: $capacitance, range: 1...100, unit: "µF")
                ParameterSlider(title: "Source / input peak", value: $supply, range: 1...10, unit: "V")
            }
            FormulaNote(equation: "LCV″ + RCV′ + V = Vₛ\nω₀ = 1/√LC · ζ = (R/2)√(C/L)\nZ = R + j(ωL − 1/ωC)\nBW = R/(2πL) = f₀/Q", explanation: "Underdamped, critical and overdamped step responses are distinct regimes of one equation. The series-current resonance remains at ω₀; a capacitor-voltage resonance peak need not be at the same frequency. Half-power means current amplitude is the resonant peak divided by √2.")
            LessonCheck(prompt: "Predict the resistance needed for critical damping, then set it if it falls in the control range.", answer: "Rcrit = 2√(L/C) = \(foundationNumber(2*sqrt(l/c))) Ω for these values. At AC resonance Ipeak = Vpeak/R = \(foundationNumber(supply/resistance*1e3)) mA; reactive element voltages can exceed the source without creating energy.")
            LessonModelNote(text: "Ideal series RLC, zero initial energy for the step, or single-frequency AC steady state. No coil saturation, parasitics, component ratings, nonlinear resonance or frequency-dependent losses.")
            FoundationReference(title: "MIT · RLC damping and impedance", url: "https://ocw.mit.edu/courses/18-03sc-differential-equations-fall-2011/pages/unit-ii-second-order-constant-coefficient-linear-equations/applications-lrc-circuits-damping-ratio/")
        }
    }
}

private struct NetworkExperiment: View {
    @State private var mode = 0
    @State private var supply = 5.0
    @State private var top = 1.0
    @State private var bottom = 2.0
    @State private var load = 1.0
    @State private var capacitance = 100.0
    @State private var sigmaTau = 0.0
    @State private var omegaTau = 1.0
    var body: some View {
        let tau = top*1_000*capacitance*1e-6
        BenchScreen {
            BenchHeader(eyebrow: "Network analysis", title: "Keep the behavior. Simplify the model.", subtitle: "Compare a loaded divider with its Thévenin equivalent, then inspect an RC pole.")
            Picker("Method", selection: $mode) { Text("Thévenin").tag(0); Text("Laplace RC").tag(1) }.pickerStyle(.segmented)
            if mode == 0 {
                if let p = FoundationsModels.thevenin(supply: supply, top: top*1_000, bottom: bottom*1_000, load: load*1_000),
                   let direct = foundationSamples(0.1...10, { FoundationsModels.thevenin(supply: supply, top: top*1_000, bottom: bottom*1_000, load: $0*1_000)?.directVoltage }),
                   let equivalent = foundationSamples(0.1...10, { FoundationsModels.thevenin(supply: supply, top: top*1_000, bottom: bottom*1_000, load: $0*1_000)?.loadVoltage }),
                   let powers = foundationSamples(0.1...10, { FoundationsModels.thevenin(supply: supply, top: top*1_000, bottom: bottom*1_000, load: $0*1_000).map { $0.loadPower*1e3 } }) {
                    InstrumentPanel(title: "Same load, two calculations") {
                        LessonPlot(traces: [.init(values: direct, color: BenchTheme.cyan, name: "Original divider"), .init(values: equivalent, color: BenchTheme.amber, name: "Thévenin")], xRange: 0.1...10, yRange: 0...supply, xLabel: "Load resistance [kΩ]", yLabel: "Load voltage [V]")
                        LessonPlot(traces: [.init(values: powers, color: BenchTheme.green, name: "Load power")], xRange: 0.1...10, yRange: 0...max(0.1, p.maximumPower*1e3*1.05), xLabel: "Load resistance [kΩ]", yLabel: "Power [mW]")
                        HStack { foundationMeter("Vth", p.openVoltage, "V"); foundationMeter("Rth", p.resistance, "Ω") }
                        HStack { foundationMeter("Loaded voltage", p.loadVoltage, "V"); foundationMeter("Loaded power", p.loadPower*1e3, "mW") }
                    }
                } else { foundationError }
                InstrumentPanel(title: "Original network and load") {
                    ParameterSlider(title: "Source", value: $supply, range: 1...12, unit: "V")
                    ParameterSlider(title: "Top resistance", value: $top, range: 0.2...5, unit: "kΩ")
                    ParameterSlider(title: "Bottom resistance", value: $bottom, range: 0.2...5, unit: "kΩ")
                    ParameterSlider(title: "Load", value: $load, range: 0.1...10, unit: "kΩ")
                }
                FormulaNote(equation: "Vth = VₛR₂/(R₁+R₂)\nRth = R₁∥R₂ · VL = Vth RL/(Rth+RL)", explanation: "The equivalent preserves terminal behavior for every load. To find Rth here, zero the independent ideal voltage source by replacing it with a short; this rule needs care when dependent sources are present.")
                LessonCheck(prompt: "Predict where load power is largest. Is that point also maximum efficiency?", answer: "Maximum power occurs at RL=Rth=\(foundationNumber(top*bottom/(top+bottom))) kΩ. The equivalent source then dissipates the same power in Rth as in RL, giving 50% equivalent-source efficiency. This is not the original divider's supply efficiency: equivalent circuits preserve terminal behavior, not internal power losses. Larger loads increase the equivalent-source efficiency while delivered power falls.")
            } else {
                if let p = FoundationsModels.rcTransfer(resistance: top*1_000, capacitance: capacitance*1e-6, sigma: sigmaTau/tau, omega: omegaTau/tau) {
                    InstrumentPanel(title: "Evaluate H(s)", subtitle: "s = σ + jω; the pole is at −1/RC on the real axis.") {
                        HStack { foundationMeter("Re H", p.real, "V/V"); foundationMeter("Im H", p.imaginary, "V/V") }
                        HStack { foundationMeter("σ", sigmaTau/tau, "s⁻¹"); foundationMeter("ω", omegaTau/tau, "rad/s") }
                        Text("Pole = \(foundationNumber(-1/tau)) s⁻¹ · |H| = \(foundationNumber(p.magnitude))").font(.caption.monospaced())
                    }
                } else { InstrumentPanel(title: "Undefined at the pole") { Text("At s = −1/RC the denominator is zero. A finite transfer value does not exist.").foregroundStyle(BenchTheme.amber) } }
                let times = (0...120).map { Double($0)*5*tau/120 }
                let impulse = times.map { exp(-$0/tau)/tau }
                InstrumentPanel(title: "Inverse transform · impulse response") {
                    LessonPlot(traces: [.init(values: impulse, color: BenchTheme.cyan, name: "h(t)")], xRange: 0...(5*tau), yRange: 0...(1/tau*1.05), xLabel: "Time [s]", yLabel: "Impulse response [s⁻¹]")
                }
                InstrumentPanel(title: "Move s and the pole") {
                    ParameterSlider(title: "Resistance", value: $top, range: 0.2...5, unit: "kΩ")
                    ParameterSlider(title: "Capacitance", value: $capacitance, range: 1...500, unit: "µF")
                    ParameterSlider(title: "Real coordinate σRC", value: $sigmaTau, range: -3...1, unit: "[1]")
                    ParameterSlider(title: "Imaginary coordinate ωRC", value: $omegaTau, range: 0...3, unit: "[1]")
                }
                FormulaNote(equation: "H(s) = 1/(1+sRC)\nh(t) = e^(−t/RC)/(RC), t ≥ 0", explanation: "The pole describes the natural exponential rate. On the jω axis H is the sinusoidal transfer. The algebraic continuation exists away from the pole; the Laplace integral of h converges only for Re(s)>−1/RC.")
                LessonCheck(prompt: "Does doubling RC move the pole left or right, and what happens to the impulse area?", answer: "The pole moves toward zero, from −1/RC to −1/(2RC). The response decays twice as slowly. Its integral remains one, matching the unit DC gain; the displayed five-τ interval contains 1−e⁻⁵ ≈ 99.326% of that area.")
            }
            LessonModelNote(text: "Thévenin mode covers one linear independent-source divider with a resistive load. Laplace mode covers a zero-state ideal RC low-pass. No arbitrary symbolic network, dependent-source simplification or inverse-transform engine is claimed.")
            FoundationReference(title: "MIT · Superposition, Thévenin and Norton", url: "https://ocw.mit.edu/courses/6-002-circuits-and-electronics-spring-2007/resources/6002_l3/")
            FoundationReference(title: "MIT · RC transfer and Laplace models", url: "https://ocw.mit.edu/courses/2-003-modeling-dynamics-and-control-i-spring-2005/12904eb02b9e301f891c12c7b26226be_archive.pdf")
        }
    }
}

private struct BJTExperiment: View {
    @State private var vbe = 0.65
    @State private var vce = 1.0
    @State private var beta = 100.0
    @State private var kelvin = 300.0
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "Devices / BJT", title: "Two junctions, one transistor", subtitle: "The reciprocal Ebers–Moll model can cross into saturation without inventing a current clamp.")
            if let p = FoundationsModels.bjt(vbe: vbe, vce: vce, beta: beta, kelvin: kelvin),
               let currents = foundationSamples(-0.2...0.78, { FoundationsModels.bjt(vbe: $0, vce: vce, beta: beta, kelvin: kelvin).map { $0.collector*1e3 } }) {
                InstrumentPanel(title: "Fixed-VCE characteristic", subtitle: "IS = 1 fA · reverse transport αR = 0.5 · emitter at 0 V") {
                    LessonPlot(traces: [.init(values: currents, color: BenchTheme.cyan, name: "Collector current")], xRange: -0.2...0.78, yRange: foundationRange(currents), xLabel: "VBE [V]", yLabel: "IC [mA]")
                    Text(p.region).font(.headline).foregroundStyle(BenchTheme.green)
                    Text("IC in = \(engineering(p.collector, unit: "A"))\nIB in = \(engineering(p.base, unit: "A"))\nIE out = \(engineering(p.emitterOut, unit: "A"))").font(.headline.monospaced())
                    Text("KCL: IC+IB−IE = \(engineering(p.kcl, unit: "A")) · VT = \(foundationNumber(p.thermalVoltage*1e3)) mV").font(.caption.monospaced())
                    Text("∂IC/∂VBE at fixed VCE = \(engineering(p.gm, unit: "S"))").font(.caption.monospaced())
                }
            } else { foundationError }
            InstrumentPanel(title: "Impose the terminal voltages") {
                ParameterSlider(title: "Base–emitter voltage", value: $vbe, range: -0.2...0.78, unit: "V", format: "%.3f")
                ParameterSlider(title: "Collector–emitter voltage", value: $vce, range: 0...2, unit: "V", format: "%.3f")
                ParameterSlider(title: "Forward β", value: $beta, range: 20...300, unit: "", format: "%.0f")
                ParameterSlider(title: "Temperature", value: $kelvin, range: 250...350, unit: "K", format: "%.0f")
            }
            FormulaNote(equation: "IF = (IS/αF)(e^(VBE/VT)−1)\nIR = (IS/αR)(e^(VBC/VT)−1)\nIC = αF IF−IR · IB = (1−αF)IF+(1−αR)IR", explanation: "VBC = VBE−VCE. Forward-active operation has a forward-biased base–emitter junction and a reverse-biased base–collector junction. When both junctions are forward biased, the same model describes saturation.")
            LessonCheck(prompt: "Keep VBE=0.65 V and lower VCE. When does the base–collector junction become forward biased?", answer: "At VCE<0.65 V, VBC becomes positive. The reverse-junction term grows and IC no longer follows the isolated forward-active exponential. β is not a universal constant or a current limiter.")
            LessonModelNote(text: "Low-injection reciprocal Ebers–Moll with fixed transport IS and αR. β and temperature are imposed parameters; changing T changes VT while IS is intentionally held fixed. No Early effect, high injection, breakdown, parasitic resistance or stored-charge timing. Terminal voltages are imposed, not a transistor circuit's load line.")
            FoundationReference(title: "Analog Devices · BJT transistor models", url: "https://wiki.analog.com/university/courses/electronics/text/chapter-8")
        }
    }
}

private struct MOSExperiment: View {
    @State private var vgs = 2.5
    @State private var vds = 2.0
    @State private var threshold = 1.0
    @State private var coefficient = 1.0
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "Devices / MOSFET", title: "Gate control has regions", subtitle: "Find cutoff, triode and saturation in a long-channel NMOS.")
            if let p = FoundationsModels.mosfet(vgs: vgs, vds: vds, threshold: threshold, coefficient: coefficient*1e-3),
               let selected = foundationSamples(0...5, { FoundationsModels.mosfet(vgs: vgs, vds: $0, threshold: threshold, coefficient: coefficient*1e-3).map { $0.current*1e3 } }),
               let lower = foundationSamples(0...5, { FoundationsModels.mosfet(vgs: max(0, vgs-0.5), vds: $0, threshold: threshold, coefficient: coefficient*1e-3).map { $0.current*1e3 } }) {
                InstrumentPanel(title: "Output characteristic") {
                    LessonPlot(traces: [.init(values: selected, color: BenchTheme.cyan, name: "Selected VGS"), .init(values: lower, color: BenchTheme.amber, name: "VGS − 0.5 V (min 0)")], xRange: 0...5, yRange: 0...max(0.1, selected.max()!*1.05), xLabel: "VDS [V]", yLabel: "Drain current [mA]")
                    Text(p.region).font(.headline).foregroundStyle(BenchTheme.green)
                    HStack { foundationMeter("ID", p.current*1e3, "mA"); foundationMeter("gm", p.gm*1e3, "mS") }
                    Text("Vov = \(foundationNumber(vgs-threshold)) V · boundary VDS = max(0, Vov)").font(.caption.monospaced())
                }
            } else { foundationError }
            InstrumentPanel(title: "Ideal device parameters") {
                ParameterSlider(title: "Gate–source voltage", value: $vgs, range: 0...5, unit: "V")
                ParameterSlider(title: "Drain–source voltage", value: $vds, range: 0...5, unit: "V")
                ParameterSlider(title: "Threshold voltage", value: $threshold, range: 0.5...2, unit: "V")
                ParameterSlider(title: "β = μCox W/L", value: $coefficient, range: 0.1...3, unit: "mA/V²")
            }
            FormulaNote(equation: "Vov = VGS−VT\nTriode: ID = β(Vov VDS−½VDS²)\nSaturation: ID = ½βVov² · gm = βVov", explanation: "Cutoff occurs for Vov≤0. Triode applies for 0≤VDS<Vov; saturation applies for VDS≥Vov. The two current formulas meet continuously at the boundary. MOS saturation and BJT saturation describe different physical operating regions.")
            LessonCheck(prompt: "In saturation, if overdrive doubles while β stays fixed, what happens to current and gm?", answer: "ID increases by four and gm doubles. This assumes the new drain voltage still exceeds the new overdrive. Outside that condition, the triode equation applies instead.")
            LessonModelNote(text: "Ideal long-channel square-law enhancement NMOS with body tied to source and λ=0. No subthreshold leakage, body effect, velocity saturation, channel-length modulation, capacitance, temperature drift or breakdown. This model is not a modern-device datasheet predictor.")
            FoundationReference(title: "MIT · MOSFET region equations", url: "https://ocw.mit.edu/courses/6-012-microelectronic-devices-and-circuits-spring-2009/f539d85c15f389afd2290abfc6ca4318_MIT6_012S09_lec10.pdf")
        }
    }
}

private struct AnalogExperiment: View {
    @State private var biasCurrent = 0.5
    @State private var resistance = 2.0
    @State private var supply = 5.0
    @State private var amplitude = 2.0
    @State private var phase = 0.25
    private func point(_ input: Double) -> FoundationsModels.AmplifierPoint? {
        FoundationsModels.commonEmitter(biasForwardCurrent: biasCurrent*1e-3, resistance: resistance*1_000, supply: supply, input: input)
    }
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "Analog design / small signals", title: "A tangent is only local", subtitle: "Compare a real derivative with the nonlinear Ebers–Moll load line.")
            if let p = point(amplitude*1e-3*sin(2*Double.pi*phase)),
               let nonlinear = foundationSamples(0...1, { point(amplitude*1e-3*sin(2*Double.pi*$0))?.deltaOutput }),
               let linear = foundationSamples(0...1, { point(amplitude*1e-3*sin(2*Double.pi*$0))?.linearDelta }) {
                InstrumentPanel(title: "One-period voltage comparison", subtitle: "Both traces share volts; the input is a \(foundationNumber(amplitude)) mV peak sine.") {
                    LessonPlot(traces: [.init(values: nonlinear, color: BenchTheme.cyan, name: "Nonlinear ΔVC"), .init(values: linear, color: BenchTheme.amber, name: "Tangent Av·vin")], xRange: 0...1, yRange: foundationRange(nonlinear+linear), xLabel: "Input phase / cycle [1]", yLabel: "Output change [V]")
                    HStack { foundationMeter("Bias VC", p.biasOutput, "V"); foundationMeter("Small-signal gain", p.gain, "V/V") }
                    HStack { foundationMeter("Numerical derivative", p.numericalGain, "V/V"); foundationMeter("Inspected output", p.output, "V") }
                    Text("VBE bias = \(foundationNumber(p.biasVBE)) V · inspected region: \(p.region)").font(.caption.monospaced())
                }
            } else { foundationError }
            InstrumentPanel(title: "Bias, load and signal") {
                ParameterSlider(title: "Forward-active target IC", value: $biasCurrent, range: 0.05...2, unit: "mA")
                ParameterSlider(title: "Collector resistance", value: $resistance, range: 0.5...5, unit: "kΩ")
                ParameterSlider(title: "Collector supply", value: $supply, range: 5...12, unit: "V")
                ParameterSlider(title: "Input amplitude", value: $amplitude, range: 0.1...25, unit: "mV")
                ParameterSlider(title: "Inspect phase", value: $phase, range: 0...1, unit: "cycle")
            }
            FormulaNote(equation: "IC(VBE,VC) = (VCC−VC)/RC\nAv = −gm RC/(1+go RC)\nΔVC ≈ Av vin", explanation: "The nonlinear output solves the load line with two-junction Ebers–Moll. Differentiating that same equation gives the local gain. A central ±1 µV perturbation independently estimates it. At larger signal amplitude, exponential curvature and saturation invalidate the tangent's global prediction.")
            LessonCheck(prompt: "Reduce the input to 0.1 mV. Why do the traces agree more closely? What changes when the bias consumes most of the collector headroom?", answer: "A differentiable curve agrees with its tangent as the perturbation approaches zero. Headroom must be checked at the actual loaded bias. Saturation changes both the bias and derivative; a requested forward-active current is not guaranteed when VCC and RC cannot support it.")
            LessonModelNote(text: "Quasistatic common-emitter stage, emitter grounded and base voltage ideally imposed. Fixed IS=1 fA, βF=100, αR=0.5, T=300 K. The Ebers–Moll/load-line root is solved by bisection. No input-source loading, Early effect, capacitance, noise or bandwidth; the horizontal phase is not a frequency-performance claim.")
            FoundationReference(title: "Analog Devices · Small-signal transistor parameters", url: "https://wiki.analog.com/university/courses/electronics/text/chapter-8")
            FoundationReference(title: "Analog Devices · Common-emitter stages", url: "https://wiki.analog.com/university/courses/electronics/text/chapter-9")
        }
    }
}

private struct FoundationReference: View {
    let title: String
    let url: String
    var body: some View {
        if let address = URL(string: url) { Link(destination: address) { Label(title, systemImage: "book.closed").font(.caption).frame(minHeight: 44, alignment: .leading) } }
    }
}

private func foundationNumber(_ value: Double) -> String { String(format: "%.4g", value) }
@MainActor private func foundationMeter(_ title: String, _ value: Double, _ unit: String) -> some View {
    MeterValue(label: title, value: foundationNumber(value), unit: unit)
}
@MainActor private var foundationError: some View {
    InstrumentPanel(title: "Model cannot be evaluated") { Text("This configuration has no finite result within the stated model.").foregroundStyle(BenchTheme.amber) }
}
private func foundationSamples(_ range: ClosedRange<Double>, count: Int = 121, _ evaluate: (Double) -> Double?) -> [Double]? {
    var values: [Double] = []
    for index in 0..<count {
        let x = range.lowerBound + (range.upperBound-range.lowerBound)*Double(index)/Double(count-1)
        guard let y = evaluate(x), y.isFinite else { return nil }
        values.append(y)
    }
    return values
}
/// Both compared traces are passed together. The axes print this shared numeric range.
private func foundationRange(_ values: [Double]) -> ClosedRange<Double> {
    let low = min(0, values.min() ?? 0), high = max(0, values.max() ?? 0)
    let span = max(high-low, 1e-6), padding = 0.05*span
    return (low-padding)...(high+padding)
}
