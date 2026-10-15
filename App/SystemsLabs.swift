import SwiftUI

struct SystemsLessonLab: View {
    let lessonID: String
    var body: some View {
        BenchScreen {
            switch lessonID {
            case "systems": ConvolutionLesson()
            case "transforms": TransformLesson()
            case "dsp": FIRLesson()
            case "stability": StabilityLesson()
            case "pid": PIDLesson()
            case "state-space": StateSpaceLesson()
            case "maxwell": MaxwellLesson()
            case "rf": TransmissionLineLesson()
            case "digital-comms": DigitalCommunicationLesson()
            case "information": InformationLesson()
            case "networks": NetworksLesson()
            default: Text("This systems experiment is unavailable.")
            }
        }
    }
}

private struct ConvolutionLesson: View {
    @State private var amplitude = 1.0
    @State private var pulseLength = 3.0
    @State private var impulseGain = 1.0
    @State private var decay = 0.5
    @State private var inspect = 3.0
    private var input: [Double] { (0..<8).map { $0 < Int(pulseLength.rounded()) ? amplitude : 0 } }
    private var impulse: [Double] { (0..<8).map { impulseGain * pow(decay, Double($0)) } }
    private var output: [Double] { SystemsModels.convolution(input, impulse) ?? [] }
    var body: some View {
        let result = output, index = Int(inspect.rounded())
        InstrumentPanel(title: "Convolution adds shifted responses", subtitle: "Finite sequences. All samples outside the shown sequences are zero.") {
            SystemsMeters {
                MeterValue(label: "Inspected sample", value: "y[\(index)]", unit: "")
                MeterValue(label: "Convolution sum", value: sx(result[safe: index] ?? 0), unit: "amplitude", tint: BenchTheme.amber)
            }
            LessonPlot(traces: [
                LessonTrace(values: input + Array(repeating: 0, count: 7), color: BenchTheme.muted, name: "Input x[n]"),
                LessonTrace(values: impulse + Array(repeating: 0, count: 7), color: BenchTheme.amber, name: "Impulse h[n]"),
                LessonTrace(values: result, color: BenchTheme.cyan, name: "Output y[n]")
            ], xRange: 0...14, yRange: SystemsUI.range(input + impulse + result), xLabel: "Sample index n", yLabel: "Amplitude")
            Text("Terms at n = \(index): " + (0..<8).map { k in sx(input[k] * (impulse[safe: index - k] ?? 0)) }.joined(separator: " + "))
                .font(.footnote.monospaced()).foregroundStyle(BenchTheme.muted).fixedSize(horizontal: false, vertical: true)
        }
        InstrumentPanel(title: "Input and impulse response") {
            ParameterSlider(title: "Input amplitude", value: $amplitude, range: -1...1, unit: "", format: "%.2f")
            ParameterSlider(title: "Input pulse length", value: $pulseLength, range: 1...8, unit: "samples", format: "%.0f")
            ParameterSlider(title: "First impulse tap", value: $impulseGain, range: -1...1, unit: "", format: "%.2f")
            ParameterSlider(title: "Tap decay ratio", value: $decay, range: 0...0.95, unit: "", format: "%.2f")
            ParameterSlider(title: "Inspect output sample", value: $inspect, range: 0...14, unit: "n", format: "%.0f")
        }
        SystemsNotes(equation: "y[n] = Σₖ x[k] h[n − k]", explanation: "Every input sample scales and shifts a copy of the impulse response. Adding those copies produces the output. The displayed term list shows the actual sum at the inspected sample.", assumptions: "Discrete, linear, time-invariant, zero-state model with eight input samples and eight impulse taps. The decaying impulse is truncated at tap 7. Connecting samples in the plot does not imply continuous-time reconstruction.", predict: "Set the input to a one-sample pulse of amplitude 1. Predict whether the output will equal h[n].", worked: "For x = [1, 1, 1] and h = [1, 0.5, 0.25, …], y[2] = 0.25 + 0.5 + 1 = 1.75.", source: "DSP Guide · Convolution", url: "https://www.dspguide.com/ch6.htm")
    }
}

private struct TransformLesson: View {
    @State private var frequency = 7.35
    @State private var amplitude = 1.0
    @State private var window = SystemsModels.Window.rectangular
    private var samples: [Double] { (0..<64).map { amplitude * sin(2 * .pi * frequency * Double($0) / 64) } }
    var body: some View {
        let result = SystemsModels.spectrum(samples, sampleRate: 64, window: window)
        let amplitudes = result?.amplitudes ?? []
        let peak = amplitudes.enumerated().max { $0.element < $1.element }?.offset ?? 0
        InstrumentPanel(title: "A finite signal has a spectrum", subtitle: "64 samples at 64 samples/s. Frequency bins are 1 Hz apart.") {
            SystemsMeters {
                MeterValue(label: "Largest bin", value: "\(peak)", unit: "Hz")
                MeterValue(label: "Window coherent gain", value: sx(result?.coherentGain ?? 1), unit: "", tint: BenchTheme.amber)
            }
            LessonPlot(traces: [LessonTrace(values: samples, color: BenchTheme.cyan, name: "Input samples")], xRange: 0...(63.0 / 64), yRange: -1.1...1.1, xLabel: "Time · s", yLabel: "Voltage · V")
            LessonPlot(traces: [LessonTrace(values: amplitudes, color: BenchTheme.amber, name: "One-sided DFT amplitude")], xRange: 0...32, yRange: 0...1.15, xLabel: "Frequency · Hz", yLabel: "Amplitude · V")
        }
        InstrumentPanel(title: "Observe spectral leakage") {
            ParameterSlider(title: "Tone frequency", value: $frequency, range: 1...28, unit: "Hz", format: "%.2f")
            ParameterSlider(title: "Tone amplitude", value: $amplitude, range: 0.1...1, unit: "V", format: "%.2f")
            Picker("DFT window", selection: $window) {
                Text("Rectangular").tag(SystemsModels.Window.rectangular)
                Text("Hann").tag(SystemsModels.Window.hann)
            }.pickerStyle(.segmented)
        }
        SystemsNotes(equation: "X[k] = Σₙ x[n]w[n] exp(−j2πkn/N)", explanation: "A finite observation multiplies a signal by a window. A tone between DFT bins spreads across bins. The Hann window reduces distant sidelobes while broadening the main lobe. Amplitudes are divided by the window sum; non-DC/non-Nyquist bins are doubled.", assumptions: "Direct 64-point DFT of a real sampled sine, not an FFT approximation or a continuous spectrum. The Hann window is symmetric, w[n] = 0.5 − 0.5cos(2πn/63). Coherent-gain normalization does not remove off-bin scalloping. This experiment covers Fourier analysis; it is not a general Laplace/z-transform solver.", predict: "Compare 7.00 Hz with 7.35 Hz using both windows. Predict which has energy confined to one rectangular-window bin.", worked: "At 8 Hz and amplitude 1 V with a rectangular window, bin 8 has amplitude 1 V; other bins are zero up to floating-point roundoff.", source: "DSP Guide · The discrete Fourier transform", url: "https://www.dspguide.com/ch8.htm")
    }
}

private struct FIRLesson: View {
    @State private var first = 0.25
    @State private var middle = 0.5
    @State private var last = 0.25
    @State private var tone = 8.0
    @State private var interference = 0.6
    private var taps: [Double] { [first, middle, last] }
    private var input: [Double] { (0..<96).map { sin(2 * .pi * tone * Double($0) / 64) + interference * sin(2 * .pi * 24 * Double($0) / 64) } }
    var body: some View {
        let filtered = SystemsModels.fir(input, taps: taps) ?? []
        let magnitudes = (0...128).map { SystemsModels.firMagnitude(taps: taps, normalizedFrequency: Double($0) / 256) ?? 0 }
        InstrumentPanel(title: "Filter by weighting delayed samples", subtitle: "Three causal FIR taps, zero initial samples, 64 samples/s.") {
            SystemsMeters {
                MeterValue(label: "DC gain", value: sx(taps.reduce(0, +)), unit: "V/V")
                MeterValue(label: "24 Hz magnitude", value: sx(SystemsModels.firMagnitude(taps: taps, normalizedFrequency: 24.0 / 64) ?? 0), unit: "V/V", tint: BenchTheme.amber)
            }
            LessonPlot(traces: [LessonTrace(values: input, color: BenchTheme.muted, name: "Input"), LessonTrace(values: filtered, color: BenchTheme.cyan, name: "FIR output")], xRange: 0...(95.0 / 64), yRange: SystemsUI.range(input + filtered), xLabel: "Time · s", yLabel: "Voltage · V")
            LessonPlot(traces: [LessonTrace(values: magnitudes, color: BenchTheme.amber, name: "|H(f)|")], xRange: 0...32, yRange: 0...max(1.1, (magnitudes.max() ?? 1) * 1.1), xLabel: "Frequency · Hz", yLabel: "Magnitude · V/V")
            LessonPlot(traces: [LessonTrace(values: taps + Array(repeating: 0, count: 5), color: BenchTheme.green, name: "Impulse response b[n]")], xRange: 0...7, yRange: -1.1...1.1, xLabel: "Sample index n", yLabel: "Impulse-response tap")
        }
        InstrumentPanel(title: "Design the taps") {
            ParameterSlider(title: "b₀ · current sample", value: $first, range: -1...1, unit: "", format: "%.2f")
            ParameterSlider(title: "b₁ · one-sample delay", value: $middle, range: -1...1, unit: "", format: "%.2f")
            ParameterSlider(title: "b₂ · two-sample delay", value: $last, range: -1...1, unit: "", format: "%.2f")
            ParameterSlider(title: "Desired tone", value: $tone, range: 2...16, unit: "Hz", format: "%.1f")
            ParameterSlider(title: "24 Hz interference", value: $interference, range: 0...1, unit: "V", format: "%.2f")
            Button("Restore smoothing taps") { first = 0.25; middle = 0.5; last = 0.25 }.buttonStyle(GlassActionStyle())
        }
        SystemsNotes(equation: "y[n] = b₀x[n] + b₁x[n−1] + b₂x[n−2]", explanation: "The frequency response is H(f) = Σbₖexp(−j2πfk/fₛ). Taps are the impulse response. Equal outer taps give this three-tap filter linear phase; changing them can change phase as well as amplitude.", assumptions: "Finite double-precision FIR with zero prehistory. No quantization, IIR feedback, or analog anti-alias filter. The displayed output stops at sample 95; the two-sample convolution tail is omitted. Interference is a known deterministic sine, not random noise.", predict: "Set [b₀,b₁,b₂] to [1,0,0]. Predict the output and the complete magnitude response.", worked: "For [0.25,0.5,0.25], H(0) = 1 and H(fₛ/2) = 0.25 − 0.5 + 0.25 = 0. The filter rejects the Nyquist-frequency component.", source: "DSP Guide · FIR filters", url: "https://www.dspguide.com/ch14.htm")
    }
}

private struct StabilityLesson: View {
    @State private var real = -0.6
    @State private var imaginary = 2.0
    private var response: [Double] { (0...400).map { SystemsModels.poleStep(time: Double($0) / 50, real: real, imaginary: imaginary) ?? 0 } }
    var body: some View {
        InstrumentPanel(title: "Move a pole pair through the imaginary axis", subtitle: "Exact unit-step response, zero initial state, normalized DC gain 1.") {
            SystemsMeters {
                MeterValue(label: "Poles", value: "\(sx(real)) ± j\(sx(imaginary))", unit: "s⁻¹")
                MeterValue(label: "Natural frequency", value: sx(hypot(real, imaginary)), unit: "rad/s", tint: BenchTheme.amber)
            }
            Text(real < 0 ? "Asymptotically stable: natural modes decay." : real == 0 ? "Marginal natural modes: sustained oscillation; not BIBO stable." : "Unstable: natural modes grow exponentially.")
                .font(.subheadline).foregroundStyle(real < 0 ? BenchTheme.green : BenchTheme.amber)
            LessonPlot(traces: [LessonTrace(values: response, color: BenchTheme.cyan, name: "Step response"), LessonTrace(values: Array(repeating: 1, count: 401), color: BenchTheme.muted, name: "Unit input")], xRange: 0...8, yRange: SystemsUI.range(response + [1]), xLabel: "Time · s", yLabel: "Normalized output")
        }
        InstrumentPanel(title: "Pole location") {
            ParameterSlider(title: "Real part a", value: $real, range: -1...0.35, unit: "s⁻¹", format: "%.3f")
            ParameterSlider(title: "Imaginary magnitude b", value: $imaginary, range: 0.3...4, unit: "rad/s", format: "%.2f")
            HStack {
                Button("Stable") { real = -0.6 }.buttonStyle(GlassActionStyle())
                Button("Axis") { real = 0 }.buttonStyle(GlassActionStyle(tint: BenchTheme.amber))
                Button("Growing") { real = 0.2 }.buttonStyle(GlassActionStyle(tint: BenchTheme.amber))
            }
        }
        SystemsNotes(equation: "T(s) = (a²+b²)/(s²−2as+a²+b²)", explanation: "The poles a ± jb create modes exp(at)cos(bt) and exp(at)sin(bt). The real part controls growth or decay; the imaginary part controls oscillation. For b > 0, y(t) = 1 − exp(at)[cos(bt) − (a/b)sin(bt)].",
                     assumptions: "One linear second-order transfer function. Moving a into the right half-plane corresponds to negative damping in this mathematical model. There is no saturating physical amplifier, nonlinear limit cycle, feedback delay, or cancellation. Imaginary-axis poles are not generally BIBO stable even though this step remains bounded.", predict: "Set a = 0. Predict whether the oscillation envelope shrinks, stays constant, or grows.", worked: "At a = 0 and b = 2, y(t) = 1 − cos(2t): y(π/2) = 2 and y(π) = 0.", source: "University of Michigan · System analysis", url: "https://ctms.engin.umich.edu/CTMS/index.php?example=Introduction&section=SystemAnalysis")
    }
}

private struct PIDLesson: View {
    @State private var proportional = 2.0
    @State private var integral = 1.0
    @State private var derivative = 0.1
    @State private var limit = 1.5
    @State private var disturbance = -0.4
    @State private var ripple = 0.0
    @State private var antiWindup = true
    private var run: SystemsModels.PIDRun? {
        SystemsModels.pid(.init(proportional: proportional, integral: integral, derivative: derivative, actuatorLimit: limit, disturbance: disturbance, measurementRipple: ripple, antiWindup: antiWindup))
    }
    var body: some View {
        let result = run
        InstrumentPanel(title: "Tune a sampled PID controller", subtitle: "Reference is 1 until 4 s, then 0. A load step enters at 6 s.") {
            SystemsMeters {
                MeterValue(label: "Final error", value: sx(-(result?.output.last ?? 0)), unit: "")
                MeterValue(label: "Saturated updates", value: "\(result?.saturatedSamples ?? 0)", unit: "samples", tint: BenchTheme.amber)
            }
            LessonPlot(traces: [LessonTrace(values: result?.reference ?? [], color: BenchTheme.muted, name: "Reference"), LessonTrace(values: result?.output ?? [], color: BenchTheme.cyan, name: "Plant output")], xRange: 0...12, yRange: SystemsUI.range((result?.output ?? []) + [0, 1]), xLabel: "Time · s", yLabel: "Normalized output")
            LessonPlot(traces: [LessonTrace(values: result?.command ?? [], color: BenchTheme.amber, name: "Applied u"), LessonTrace(values: result?.integralTerm ?? [], color: BenchTheme.green, name: "Integral contribution")], xRange: 0...12, yRange: SystemsUI.range((result?.command ?? []) + (result?.integralTerm ?? []) + [-limit, limit]), xLabel: "Time · s", yLabel: "Normalized input")
        }
        InstrumentPanel(title: "Controller and actuator") {
            ParameterSlider(title: "Proportional Kₚ", value: $proportional, range: 0...6, unit: "", format: "%.2f")
            ParameterSlider(title: "Integral Kᵢ", value: $integral, range: 0...6, unit: "s⁻¹", format: "%.2f")
            ParameterSlider(title: "Derivative Kᴅ", value: $derivative, range: 0...1, unit: "s", format: "%.2f")
            ParameterSlider(title: "Symmetric actuator limit", value: $limit, range: 0.3...3, unit: "", format: "%.2f")
            ParameterSlider(title: "Load disturbance after 6 s", value: $disturbance, range: -1...1, unit: "", format: "%.2f")
            ParameterSlider(title: "12 Hz sensor ripple", value: $ripple, range: 0...0.1, unit: "", format: "%.3f")
            Toggle("Conditional-integration anti-windup", isOn: $antiWindup).tint(BenchTheme.green)
        }
        SystemsNotes(equation: "ẏ = −y + u + d    u = clamp(Kₚe + I − KᴅDᶠ)", explanation: "At each 10 ms sample, I accumulates KᵢeΔt. The derivative uses measurement change, filtered with a 50 ms first-order filter, so the reference step does not create derivative kick. Conditional integration stops accumulation while the error would drive an already-saturated request further into saturation.", assumptions: "Digital PID on a normalized plant with time constant 1 s. The plant update is exact for held u and d between samples. Controller integration is sampled forward accumulation; derivative is exponentially filtered. Sensor ripple is deterministic, not Gaussian noise. Anti-windup improves this implementation but is not a universal stability guarantee.", predict: "Set the actuator limit to 0.3 and increase Kᵢ. Compare integral buildup and recovery at 4 s with anti-windup on and off.", worked: "With y = 0, r = 1, Kₚ = 2 and limit = 0.5, the requested proportional command is 2, but applied u is 0.5. Integration pauses when anti-windup sees positive error pushing that saturation further.", source: "MathWorks · Anti-windup controller methods", url: "https://www.mathworks.com/help/simulink/slref/anti-windup-control-using-a-pid-controller.html")
    }
}

private struct StateSpaceLesson: View {
    @State private var effort = 1.0
    @State private var observerSpeed = 4.0
    @State private var sensorRipple = 0.0
    @State private var initialVelocity = 0.0
    private var run: SystemsModels.ObserverRun? { SystemsModels.observer(effortWeight: effort, observerSpeed: observerSpeed, sensorRipple: sensorRipple, initialVelocity: initialVelocity) }
    var body: some View {
        let result = run
        InstrumentPanel(title: "Estimate hidden velocity. Regulate position.", subtitle: "A double integrator begins at x = 1 m. Only position is measured; the observer begins at zero.") {
            SystemsMeters {
                MeterValue(label: "LQR kₓ", value: sx(result?.gains.position ?? 0), unit: "scaled")
                MeterValue(label: "LQR kᵥ", value: sx(result?.gains.velocity ?? 0), unit: "scaled", tint: BenchTheme.amber)
                MeterValue(label: "8 s normalized cost", value: sx(result?.cost ?? 0), unit: "", tint: BenchTheme.green)
            }
            LessonPlot(traces: [LessonTrace(values: result?.position ?? [], color: BenchTheme.cyan, name: "Actual position"), LessonTrace(values: result?.estimatedPosition ?? [], color: BenchTheme.amber, name: "Estimated position")], xRange: 0...8, yRange: SystemsUI.range((result?.position ?? []) + (result?.estimatedPosition ?? [])), xLabel: "Time · s", yLabel: "Position · m")
            LessonPlot(traces: [LessonTrace(values: result?.velocity ?? [], color: BenchTheme.cyan, name: "Actual velocity"), LessonTrace(values: result?.estimatedVelocity ?? [], color: BenchTheme.amber, name: "Estimated velocity")], xRange: 0...8, yRange: SystemsUI.range((result?.velocity ?? []) + (result?.estimatedVelocity ?? [])), xLabel: "Time · s", yLabel: "Velocity · m/s")
            Text("Peak acceleration demand: \(engineering((result?.acceleration ?? []).map(abs).max() ?? 0, unit: "m/s²"))").font(.subheadline).foregroundStyle(BenchTheme.muted)
        }
        InstrumentPanel(title: "Feedback and observer tradeoffs") {
            ParameterSlider(title: "Relative effort penalty R", value: $effort, range: 0.05...5, unit: "", format: "%.2f")
            ParameterSlider(title: "Observer pole magnitude ω", value: $observerSpeed, range: 0.5...12, unit: "s⁻¹", format: "%.2f")
            ParameterSlider(title: "5 Hz position-sensor ripple", value: $sensorRipple, range: 0...0.1, unit: "m", format: "%.3f")
            ParameterSlider(title: "Initial actual velocity", value: $initialVelocity, range: -1...1, unit: "m/s", format: "%.2f")
        }
        SystemsNotes(equation: "ẋ = Ax + Bu    ẋ̂ = Ax̂ + Bu + L(y − Cx̂)", explanation: "Here x = [position, velocity], A = [[0,1],[0,0]], B = [0,1]ᵀ and C = [1,0]. A position-only Luenberger observer uses L = [2ω,ω²]ᵀ. The controller applies u = −[kₓ,kᵥ]x̂. The normalized infinite-horizon LQR problem uses Q = I and R > 0, giving kₓ = 1/√R and kᵥ = √(2/√R + 1/R).",
                     assumptions: "Linear double integrator, ideal unlimited acceleration, exact plant parameters, RK4 with 5 ms steps. LQR gains are optimal for full, exact state feedback with the stated normalized quadratic cost, not a claim that this noisy observer loop is optimal. Position, velocity and acceleration are normalized by 1 m, 1 m/s and 1 m/s² for cost. No Kalman filter, actuator saturation, or model mismatch.", predict: "Increase observer speed while adding sensor ripple. Predict how rapidly initial estimate error falls and how much measurement ripple enters the velocity estimate.", worked: "With R = 1, gains are [1, √3]. With ω = 4, L = [8,16]ᵀ and both observer error poles are −4 s⁻¹.", source: "MIT · LQR for the double integrator", url: "https://underactuated.mit.edu/lqr.html")
    }
}

private struct MaxwellLesson: View {
    @State private var mode = 0
    @State private var amplitude = 10.0
    @State private var frequencyMHz = 10.0
    @State private var phase = 0.0
    @State private var area = 0.01
    @State private var field = 0.02
    @State private var coilFrequency = 20.0
    @State private var turns = 20.0
    var body: some View {
        Picker("Maxwell experiment", selection: $mode) {
            Text("Plane wave").tag(0)
            Text("Faraday coil").tag(1)
        }.pickerStyle(.segmented)
        if mode == 0 { wave } else { induction }
    }
    private var wave: some View {
        let frequency = frequencyMHz * 1e6, wavelength = SystemsModels.lightSpeed / frequency
        let result = SystemsModels.planeWave(amplitude: amplitude, frequency: frequency, position: 0, time: phase / frequency)
        let profile = (0...300).map { SystemsModels.planeWave(amplitude: amplitude, frequency: frequency, position: 2 * wavelength * Double($0) / 300, time: phase / frequency)?.electric ?? 0 }
        return Group {
            InstrumentPanel(title: "A traveling electromagnetic wave", subtitle: "E points along x, B along y, and energy travels in +z. The plotted values are signed components.") {
                SystemsMeters {
                    MeterValue(label: "Magnetic amplitude", value: String(format: "%.3g", amplitude / SystemsModels.lightSpeed * 1e9), unit: "nT")
                    MeterValue(label: "Average intensity", value: String(format: "%.3g", result?.averageIntensity ?? 0), unit: "W/m²", tint: BenchTheme.amber)
                }
                LessonPlot(traces: [LessonTrace(values: profile, color: BenchTheme.cyan, name: "Eₓ"), LessonTrace(values: profile, color: BenchTheme.amber, name: "cBᵧ · same phase")], xRange: 0...(2 * wavelength), yRange: (-amplitude * 1.1)...(amplitude * 1.1), xLabel: "Position z · m", yLabel: "E and cB · V/m")
                Text("At z = 0: energy density = \(engineering(result?.energyDensity ?? 0, unit: "J/m³")); Poynting flux = \(engineering(result?.poynting ?? 0, unit: "W/m²")). S = cu at every phase.")
                    .font(.footnote).foregroundStyle(BenchTheme.muted)
            }
            InstrumentPanel(title: "Wave parameters") {
                ParameterSlider(title: "Electric-field amplitude", value: $amplitude, range: 0.1...100, unit: "V/m", format: "%.2f")
                ParameterSlider(title: "Frequency", value: $frequencyMHz, range: 1...100, unit: "MHz", format: "%.2f")
                ParameterSlider(title: "Inspect time within one cycle", value: $phase, range: 0...1, unit: "cycles", format: "%.3f")
            }
            SystemsNotes(equation: "B₀ = E₀/c    λ = c/f    S = ε₀cE²    ⟨S⟩ = ε₀cE₀²/2", explanation: "Maxwell’s source-free vacuum equations admit transverse waves. Electric and magnetic components are in phase and perpendicular. Their energy densities are equal, giving total u = ε₀E² and energy flux S = cu. Advancing time moves this wave toward +z.", assumptions: "Ideal infinite sinusoidal plane wave in vacuum; no sources, boundaries, material dispersion, attenuation, or near-field behavior. The magnetic trace is multiplied by c to use the electric-field scale. Constants use CODATA vacuum permittivity and exact c.", predict: "Double electric amplitude. Predict whether average intensity doubles or quadruples.", worked: "At E₀ = 10 V/m, B₀ ≈ 33.36 nT and average intensity ≈ 0.1327 W/m². Doubling E₀ multiplies intensity by 4.", source: "OpenStax · Electromagnetic energy transport", url: "https://openstax.org/books/university-physics-volume-2/pages/16-3-energy-carried-by-electromagnetic-waves")
        }
    }
    private var induction: some View {
        let count = Int(turns.rounded()), duration = 2 / coilFrequency
        let result = SystemsModels.faraday(time: phase / coilFrequency, turns: count, area: area, fieldAmplitude: field, frequency: coilFrequency)
        let points = (0...300).map { SystemsModels.faraday(time: duration * Double($0) / 300, turns: count, area: area, fieldAmplitude: field, frequency: coilFrequency) }
        return Group {
            InstrumentPanel(title: "Changing flux induces circulation", subtitle: "Uniform B perpendicular to a stationary coil. Φ is flux through one turn.") {
                SystemsMeters {
                    MeterValue(label: "Flux at inspected phase", value: sx((result?.fluxPerTurn ?? 0) * 1e3), unit: "mWb")
                    MeterValue(label: "Induced EMF", value: sx(result?.emf ?? 0), unit: "V", tint: BenchTheme.amber)
                }
                LessonPlot(traces: [LessonTrace(values: points.map { ($0?.fluxPerTurn ?? 0) * 1e3 }, color: BenchTheme.cyan, name: "Per-turn flux")], xRange: 0...duration, yRange: (-area * field * 1_100)...(area * field * 1_100), xLabel: "Time · s", yLabel: "Flux · mWb")
                LessonPlot(traces: [LessonTrace(values: points.map { $0?.emf ?? 0 }, color: BenchTheme.amber, name: "Induced EMF")], xRange: 0...duration, yRange: SystemsUI.range(points.map { $0?.emf ?? 0 }), xLabel: "Time · s", yLabel: "EMF · V")
            }
            InstrumentPanel(title: "Coil and applied field") {
                ParameterSlider(title: "Turns N", value: $turns, range: 1...100, unit: "", format: "%.0f")
                ParameterSlider(title: "Area per turn", value: $area, range: 0.001...0.05, unit: "m²", format: "%.3f")
                ParameterSlider(title: "Magnetic-field amplitude", value: $field, range: 0.001...0.1, unit: "T", format: "%.3f")
                ParameterSlider(title: "Field frequency", value: $coilFrequency, range: 1...100, unit: "Hz", format: "%.1f")
                ParameterSlider(title: "Inspect time within one cycle", value: $phase, range: 0...1, unit: "cycles", format: "%.3f")
            }
            SystemsNotes(equation: "Φ = AB₀cos(2πft)    ℰ = −N dΦ/dt", explanation: "For the chosen positive area normal, EMF is N A B₀ 2πf sin(2πft). The minus sign is Lenz’s law: the induced circulation opposes the change in linked flux. EMF is zero when flux is at a maximum, and largest when flux crosses zero.", assumptions: "Uniform imposed sinusoidal magnetic field, stationary turns with equal area and no loading. EMF is circulation around a loop; it is not a current prediction. Self-inductance, resistance, eddy currents, and the field’s generating apparatus are omitted.", predict: "Compare the flux and EMF at a quarter-cycle. Predict the result of doubling the number of turns.", worked: "For N = 20, A = 0.01 m², B₀ = 0.02 T and f = 20 Hz, peak EMF is 0.5027 V.", source: "OpenStax · Faraday’s law", url: "https://openstax.org/books/university-physics-volume-2/pages/13-1-faradays-law")
        }
    }
}

private struct TransmissionLineLesson: View {
    @State private var characteristic = 50.0
    @State private var load = 100.0
    @State private var isOpen = false
    @State private var length = 4.0
    @State private var widthNS = 20.0
    @State private var timeNS = 30.0
    private var speed: Double { 0.66 * SystemsModels.lightSpeed }
    private var boundary: SystemsModels.LineReflection? { SystemsModels.reflection(characteristic: characteristic, load: isOpen ? nil : load) }
    var body: some View {
        let samples = (0...400).map { SystemsModels.linePulse(position: length * Double($0) / 400, time: timeNS * 1e-9, length: length, speed: speed, width: widthNS * 1e-9, characteristic: characteristic, load: isOpen ? nil : load) }
        InstrumentPanel(title: "Launch a pulse into a mismatch", subtitle: "Incident amplitude 1 V, lossless line, velocity 0.66c. The source is matched to Z₀.") {
            SystemsMeters {
                MeterValue(label: "Load reflection Γ", value: sx(boundary?.coefficient ?? 0), unit: "")
                MeterValue(label: "Absorbed incident power", value: sx((boundary?.absorbedFraction ?? 0) * 100), unit: "%", tint: BenchTheme.amber)
            }
            LessonPlot(traces: [LessonTrace(values: samples.map { $0?.incident ?? 0 }, color: BenchTheme.muted, name: "Incident V⁺"), LessonTrace(values: samples.map { $0?.reflected ?? 0 }, color: BenchTheme.amber, name: "Reflected V⁻"), LessonTrace(values: samples.map { $0?.total ?? 0 }, color: BenchTheme.cyan, name: "Total voltage")], xRange: 0...length, yRange: -1.1...2.1, xLabel: "Distance from source · m", yLabel: "Voltage · V")
            Text("One-way delay = \(sx(length / speed * 1e9)) ns. Load voltage during the incident pulse = \(sx(boundary?.loadVoltage ?? 0)) V. Sinusoidal VSWR = \(boundary?.standingWaveRatio.isFinite == true ? sx(boundary?.standingWaveRatio ?? 1) : "∞").")
                .font(.footnote).foregroundStyle(BenchTheme.muted)
        }
        InstrumentPanel(title: "Line and termination") {
            ParameterSlider(title: "Characteristic impedance Z₀", value: $characteristic, range: 20...120, unit: "Ω", format: "%.1f")
            Toggle("Open-circuit load", isOn: $isOpen).tint(BenchTheme.amber)
            ParameterSlider(title: "Resistive load Rᴸ", value: $load, range: 0...300, unit: "Ω", format: "%.1f").disabled(isOpen)
            ParameterSlider(title: "Line length", value: $length, range: 1...10, unit: "m", format: "%.2f")
            ParameterSlider(title: "Pulse width", value: $widthNS, range: 5...50, unit: "ns", format: "%.1f")
            ParameterSlider(title: "Inspect time", value: $timeNS, range: 0...200, unit: "ns", format: "%.1f")
            Button("Match the load") { isOpen = false; load = characteristic }.buttonStyle(GlassActionStyle())
        }
        SystemsNotes(equation: "Γᴸ = (Rᴸ−Z₀)/(Rᴸ+Z₀)    Vᴸ = V⁺(1+Γᴸ)", explanation: "The incident pulse moves toward the load; the reflected pulse moves back toward the source. The reflected current has the opposite traveling-wave sign. For a resistive load, absorbed power fraction is 1−Γ². The matched source absorbs the returning pulse, so there are no further reflections.", assumptions: "Ideal lossless line with real Z₀, frequency-independent velocity, a rectangular 1 V incident pulse, and a purely resistive/open/short load. Edges have unlimited bandwidth. No attenuation, dispersion, reactive load, antenna, or source mismatch. VSWR is the equivalent sinusoidal value; this view shows pulses.", predict: "Compare an open load, a 0 Ω short, and a matched load. Predict the reflection sign and load voltage.", worked: "At Z₀ = 50 Ω and Rᴸ = 100 Ω, Γ = 1/3, Vᴸ = 4/3 V, and the load absorbs 8/9 of incident power.", source: "Ellingson · Voltage reflection coefficient", url: "https://eng.libretexts.org/Bookshelves/Electrical_Engineering/Electro-Optics/Book%3A_Electromagnetics_I_(Ellingson)/03%3A_Transmission_Lines/3.12%3A_Voltage_Reflection_Coefficient")
    }
}

private struct DigitalCommunicationLesson: View {
    @State private var ebN0 = 3.0
    @State private var seed: UInt64 = 23
    var body: some View {
        let result = SystemsModels.bpsk(ebN0DB: ebN0, seed: seed)
        InstrumentPanel(title: "Detect BPSK in Gaussian noise", subtitle: "128 independent symbols; bit 0 maps to −1, bit 1 to +1. Decision boundary: I = 0.") {
            SystemsMeters {
                MeterValue(label: "Errors in this draw", value: "\(result?.errors ?? 0)", unit: "/ 128", tint: BenchTheme.amber)
                MeterValue(label: "Theoretical BER", value: String(format: "%.3g", result?.theoreticalBER ?? 0), unit: "per bit")
            }
            BPSKConstellation(symbols: result?.symbols ?? [])
            Text("First 32 sent: " + (result?.symbols.prefix(32).map { String($0.bit) }.joined() ?? ""))
                .font(.footnote.monospaced()).fixedSize(horizontal: false, vertical: true)
            Text("First 32 read: " + (result?.symbols.prefix(32).map { String($0.decoded) }.joined() ?? ""))
                .font(.footnote.monospaced()).foregroundStyle(BenchTheme.amber).fixedSize(horizontal: false, vertical: true)
        }
        InstrumentPanel(title: "Channel quality") {
            ParameterSlider(title: "Eᵦ/N₀", value: $ebN0, range: -3...12, unit: "dB", format: "%.1f")
            Button("Draw another 128 noisy symbols") { seed &+= 1 }.buttonStyle(GlassActionStyle())
        }
        SystemsNotes(equation: "Pᵦ = ½ erfc(√(Eᵦ/N₀))", explanation: "After ideal coherent matched filtering, a BPSK symbol is ±1 plus Gaussian noise. With Eᵦ = 1, each I/Q noise component has variance N₀/2. The receiver chooses bit 1 when I ≥ 0. Amber points are incorrect decisions; cyan points are correct.", assumptions: "Independent additive white Gaussian noise at ideal matched-filter outputs, known phase/timing, no fading, coding, synchronization error, or pulse-shaping simulation. Random draws use a reproducible seeded generator and Box–Muller transform. A 128-symbol error fraction is a small sample, not the exact theoretical BER.", predict: "Increase Eᵦ/N₀ by 6 dB. Predict whether the spread around ±1 grows or shrinks before drawing again.", worked: "At Eᵦ/N₀ = 0 dB, σ = √(1/2) and theoretical BER ≈ 0.07865. At 10 dB, BER ≈ 3.87×10⁻⁶.", source: "MathWorks · Analytical AWGN error rates", url: "https://www.mathworks.com/help/comm/ug/analytical-expressions-used-in-berawgn-function-and-bit-error-rate-analysis-app.html")
    }
}

private struct InformationLesson: View {
    @State private var bandwidthKHz = 10.0
    @State private var snrDB = 10.0
    @State private var data = 11.0
    @State private var errorMask = 0
    var body: some View {
        let encoded = SystemsModels.hammingEncode(Int(data.rounded())) ?? 0
        let received = encoded ^ errorMask
        let decoded = SystemsModels.hammingDecode(received)
        InstrumentPanel(title: "A noisy channel has a capacity", subtitle: "Theoretical AWGN limit, not a promised modem data rate.") {
            MeterValue(label: "Shannon capacity", value: sx((SystemsModels.capacity(bandwidth: bandwidthKHz * 1e3, snrDB: snrDB) ?? 0) / 1e3), unit: "kbit/s")
            LessonPlot(traces: [LessonTrace(values: (0...160).map { (SystemsModels.capacity(bandwidth: bandwidthKHz * 1e3, snrDB: -10 + Double($0) / 4) ?? 0) / 1e3 }, color: BenchTheme.cyan, name: "AWGN capacity")], xRange: -10...30, yRange: 0...max(1, bandwidthKHz * log2(1_001) * 1.1), xLabel: "S/N · dB", yLabel: "Capacity · kbit/s")
            ParameterSlider(title: "Bandwidth", value: $bandwidthKHz, range: 1...100, unit: "kHz", format: "%.1f")
            ParameterSlider(title: "Signal/noise ratio", value: $snrDB, range: -10...30, unit: "dB", format: "%.1f")
        }
        InstrumentPanel(title: "Actually correct a single bit", subtitle: "Hamming(7,4), even parity. Toggle received positions to inject errors.") {
            ParameterSlider(title: "Four-bit data value", value: $data, range: 0...15, unit: "", format: "%.0f")
            Text("Data: \(SystemsUI.binary(Int(data.rounded()), width: 4)) · encoded positions 1 → 7: \(SystemsUI.positions(encoded))")
                .font(.subheadline.monospaced()).fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 10) {
                ForEach(1...7, id: \.self) { position in
                    Button {
                        errorMask ^= 1 << (position - 1)
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(position): \((received >> (position - 1)) & 1)").font(.headline.monospaced())
                            Text([1, 2, 4].contains(position) ? "parity" : "data").font(.caption)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(GlassActionStyle(tint: errorMask & (1 << (position - 1)) != 0 ? BenchTheme.amber : BenchTheme.cyan))
                    .accessibilityLabel("Received position \(position), bit \((received >> (position - 1)) & 1)")
                    .accessibilityValue(errorMask & (1 << (position - 1)) != 0 ? "Error injected" : "Original bit")
                }
            }
            SystemsMeters {
                MeterValue(label: "Syndrome", value: "\(decoded?.syndrome ?? 0)", unit: "position", tint: BenchTheme.amber)
                MeterValue(label: "Decoded data", value: SystemsUI.binary(decoded?.data ?? 0, width: 4), unit: "")
            }
            Text(errorMask.nonzeroBitCount <= 1 ? "With zero or one error, data is recovered exactly." : "Two or more injected errors: correction is not guaranteed. This decoder can miscorrect.")
                .font(.subheadline).foregroundStyle(errorMask.nonzeroBitCount <= 1 ? BenchTheme.green : BenchTheme.amber)
            Button("Clear injected errors") { errorMask = 0 }.buttonStyle(GlassActionStyle())
        }
        SystemsNotes(equation: "C = B log₂(1+S/N)    syndrome = XOR of failed parity positions", explanation: "The capacity formula uses linear power ratio S/N, converted from dB. Hamming(7,4) adds parity positions 1, 2 and 4; data occupies 3, 5, 6 and 7. Each parity checks positions containing its corresponding binary index bit. For one error, the syndrome identifies its position and the decoder flips it.", assumptions: "AWGN capacity assumes a band-limited channel, average received-power constraint, and arbitrarily long ideal coding; the small Hamming example does not attain that limit. Basic Hamming(7,4) corrects one bit but does not reliably detect two errors. Its code rate is 4/7. The displayed code uses position 1 first, not integer bit-order notation.", predict: "Inject one error at each of the seven positions. Predict the syndrome. Then inject two errors and inspect the misleading correction.", worked: "At B = 10 kHz and S/N = 1 (0 dB), C = 10 kbit/s. If encoded data 1011 suffers one error at position 5, the syndrome is 5 and correction restores 1011.", source: "MIT · Hamming codes and parity syndromes", url: "https://web.mit.edu/6.02/www/f2010/handouts/lectures/L6.pdf")
        SystemsReference(title: "MIT · Shannon capacity lecture", url: "https://ocw.mit.edu/courses/6-451-principles-of-digital-communication-ii-spring-2005/147cf944eeb88d98e97f2d8c76f7fcc9_8HvTaOrTokc.pdf")
    }
}

private struct NetworksLesson: View {
    @State private var arrivalRate = 50.0
    @State private var payload = 1_000.0
    @State private var bitRateMbps = 0.5
    @State private var distanceKM = 100.0
    @State private var buffer = 8.0
    @State private var lossProbability = 0.05
    @State private var seed: UInt64 = 71
    private var run: SystemsModels.NetworkRun? {
        SystemsModels.network(arrivalRate: arrivalRate, payloadBytes: Int(payload.rounded()), bitRate: bitRateMbps * 1e6, distance: distanceKM * 1e3, capacity: Int(buffer.rounded()), lossProbability: lossProbability, seed: seed)
    }
    var body: some View {
        let result = run
        InstrumentPanel(title: "Separate queue, transmit, and propagate", subtitle: "Periodic arrivals during 1 s. Accepted packets are then drained through one FIFO link.") {
            SystemsMeters {
                MeterValue(label: "Serialization", value: sx((result?.transmissionDelay ?? 0) * 1e3), unit: "ms")
                MeterValue(label: "Propagation", value: sx((result?.propagationDelay ?? 0) * 1e3), unit: "ms", tint: BenchTheme.amber)
                MeterValue(label: "Mean queue wait", value: sx((result?.averageQueueDelay ?? 0) * 1e3), unit: "ms", tint: BenchTheme.green)
            }
            LessonPlot(traces: [LessonTrace(values: result?.queue ?? [], color: BenchTheme.cyan, name: "FIFO occupancy, including service")], xRange: 0...max(1, result?.duration ?? 1), yRange: 0...(buffer.rounded() + 1), xLabel: "Time · s", yLabel: "Packets in system")
            Text("\(result?.arrivals ?? 0) offered · \(result?.overflow ?? 0) buffer drops · \(result?.linkLoss ?? 0) channel erasures · \(result?.delivered ?? 0) eventual deliveries")
                .font(.subheadline.monospacedDigit()).fixedSize(horizontal: false, vertical: true)
            Text("Offered load λL/R = \(sx(result?.offeredLoad ?? 0)). Mean delay of delivered packets = \(sx((result?.averageDeliveryDelay ?? 0) * 1e3)) ms.")
                .font(.footnote).foregroundStyle(BenchTheme.muted)
            DisclosureGroup("First six packet events · ms") {
                ForEach(Array((result?.packets ?? []).prefix(6).enumerated()), id: \.offset) { index, packet in
                    Text("Packet \(index + 1): arrive \(sx(packet.arrival * 1e3)) → start \(sx(packet.start * 1e3)) → finish \(sx(packet.finish * 1e3)) → \(packet.lost ? "erased" : "deliver " + sx(packet.delivery * 1e3))")
                        .font(.footnote.monospacedDigit()).fixedSize(horizontal: false, vertical: true).padding(.vertical, 4)
                }
            }.tint(BenchTheme.cyan)
        }
        InstrumentPanel(title: "Traffic and link") {
            ParameterSlider(title: "Periodic arrival rate", value: $arrivalRate, range: 5...500, unit: "packets/s", format: "%.1f")
            ParameterSlider(title: "Packet length", value: $payload, range: 64...1_500, unit: "bytes", format: "%.0f")
            ParameterSlider(title: "Link bit rate", value: $bitRateMbps, range: 0.1...10, unit: "Mbit/s", format: "%.2f")
            ParameterSlider(title: "Link distance", value: $distanceKM, range: 1...1_000, unit: "km", format: "%.1f")
            ParameterSlider(title: "Buffer slots including service", value: $buffer, range: 1...20, unit: "packets", format: "%.0f")
            ParameterSlider(title: "Independent channel erasure probability", value: $lossProbability, range: 0...0.4, unit: "", format: "%.2f")
            Button("Draw another loss pattern") { seed &+= 1 }.buttonStyle(GlassActionStyle())
        }
        SystemsNotes(equation: "tₜₓ = 8Lᵦᵧₜₑₛ/R    tₚᵣₒₚ = d/v    delay = wait + tₜₓ + tₚᵣₒₚ", explanation: "A packet waits until all earlier accepted packets finish transmission. A full finite FIFO drops new arrivals. Propagation begins for each bit as it is transmitted; final delivery occurs one propagation delay after serialization completes. Independent erasure is applied after accepted packets use link service.", assumptions: "One deterministic FIFO server, constant packet size and bit rate, periodic arrivals for 1 s, speed 2×10⁸ m/s, finite buffer including service, seeded independent erasures, and complete draining. No routing, contention, processing overhead, ACKs, retransmissions, TCP, or wireless PHY. This is a queueing model, not an Internet stack.", predict: "Keep traffic and link rate fixed, then double distance. Predict which delay component changes and whether the queue changes.", worked: "A 1,000-byte packet on a 0.5 Mbit/s link takes 16 ms to serialize. Over 100 km at 2×10⁸ m/s, propagation adds 0.5 ms. With no queue, final delivery delay is 16.5 ms.", source: "MIT · Packet sharing and queues", url: "https://web.mit.edu/6.02/www/s2012/handouts/16.pdf")
    }
}

private struct BPSKConstellation: View {
    let symbols: [SystemsModels.BPSKSymbol]
    var body: some View {
        let extent = max(2, ceil((symbols.map { max(abs($0.inPhase), abs($0.quadrature)) }.max() ?? 2) * 1.1))
        Canvas { context, size in
            let scale = min(size.width, size.height) / (2 * extent)
            func point(_ i: Double, _ q: Double) -> CGPoint { CGPoint(x: size.width / 2 + i * scale, y: size.height / 2 - q * scale) }
            var axes = Path()
            axes.move(to: point(-extent, 0)); axes.addLine(to: point(extent, 0))
            axes.move(to: point(0, -extent)); axes.addLine(to: point(0, extent))
            context.stroke(axes, with: .color(BenchTheme.muted.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            for symbol in symbols {
                let position = point(symbol.inPhase, symbol.quadrature)
                context.fill(Path(ellipseIn: CGRect(x: position.x - 2.5, y: position.y - 2.5, width: 5, height: 5)), with: .color(symbol.bit == symbol.decoded ? BenchTheme.cyan : BenchTheme.amber))
            }
            for ideal in [-1.0, 1.0] {
                let position = point(ideal, 0)
                context.stroke(Path(ellipseIn: CGRect(x: position.x - 8, y: position.y - 8, width: 16, height: 16)), with: .color(BenchTheme.ink), lineWidth: 2)
                context.draw(Text(ideal > 0 ? "+1" : "−1").font(.caption).foregroundStyle(BenchTheme.ink), at: CGPoint(x: position.x, y: position.y + 20))
            }
            context.draw(Text("Q").font(.caption).foregroundStyle(BenchTheme.muted), at: point(0.15, extent - 0.25))
            context.draw(Text("I").font(.caption).foregroundStyle(BenchTheme.muted), at: point(extent - 0.25, -0.25))
        }
        .frame(height: 240)
        .accessibilityLabel("BPSK constellation in normalized matched-filter units. \(symbols.filter { $0.bit != $0.decoded }.count) incorrect decisions out of \(symbols.count) symbols. I and Q axes range from minus \(Int(extent)) to plus \(Int(extent)).")
        Text("Normalized I/Q axes: −\(Int(extent)) to +\(Int(extent)). Cyan: correct; amber: incorrect.")
            .font(.caption).foregroundStyle(BenchTheme.muted)
    }
}

private struct SystemsMeters<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder var content: Content
    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(spacing: 14))
        layout { content }
    }
}

private struct SystemsNotes: View {
    let equation: String
    let explanation: String
    let assumptions: String
    let predict: String
    let worked: String
    let source: String
    let url: String
    var body: some View {
        FormulaNote(equation: equation, explanation: explanation)
        InstrumentPanel(title: "Predict, then check") {
            Text(predict).font(.subheadline)
            DisclosureGroup("Worked example") { Text(worked).font(.subheadline).fixedSize(horizontal: false, vertical: true).padding(.vertical, 8) }
                .tint(BenchTheme.cyan)
        }
        InstrumentPanel(title: "Physical and numerical assumptions") {
            Text(assumptions).font(.footnote).foregroundStyle(BenchTheme.muted).fixedSize(horizontal: false, vertical: true)
        }
        SystemsReference(title: source, url: url)
    }
}

private struct SystemsReference: View {
    let title: String
    let url: String
    var body: some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                Label(title, systemImage: "book.closed").font(.footnote).frame(minHeight: 44)
            }.foregroundStyle(BenchTheme.cyan)
        }
    }
}

private enum SystemsUI {
    static func range(_ values: [Double]) -> ClosedRange<Double> {
        let finite = values.filter(\.isFinite)
        let minimum = min(0, finite.min() ?? 0), maximum = max(0, finite.max() ?? 1)
        let padding = max(0.05, (maximum - minimum) * 0.08)
        return (minimum - padding)...(maximum + padding)
    }
    static func binary(_ value: Int, width: Int) -> String { String(repeating: "0", count: max(0, width - String(value, radix: 2).count)) + String(value, radix: 2) }
    static func positions(_ value: Int) -> String { (1...7).map { String((value >> ($0 - 1)) & 1) }.joined() }
}

private func sx(_ value: Double) -> String {
    guard value.isFinite else { return "—" }
    return String(format: "%.3f", abs(value) < 0.0005 ? 0 : value)
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
