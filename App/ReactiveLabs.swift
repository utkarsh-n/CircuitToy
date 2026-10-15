import SwiftUI
import CircuitCore

struct TransientLabView: View {
    @State private var resistance = 1000.0
    @State private var capacitance = 100.0
    @State private var supply = 5.0
    @State private var elapsedTau = 1.0
    @State private var discharging = false
    private var tau: Double { resistance * capacitance * 1e-6 }
    private var voltage: Double { supply * (discharging ? exp(-elapsedTau) : -expm1(-elapsedTau)) }
    private var current: Double { (discharging ? -voltage : supply - voltage) / resistance }
    private var numerical: [Double]? {
        let circuit = Circuit(elements: [
            .voltageSource(id: "V1", a: 1, b: 0, volts: discharging ? 0 : supply),
            .resistor(id: "R1", a: 1, b: 2, ohms: resistance),
            .capacitor(id: "C1", a: 2, b: 0, farads: capacitance * 1e-6, initialVoltage: discharging ? supply : 0)
        ])
        guard var simulator = try? TransientSimulator(circuit: circuit) else { return nil }
        var values = [discharging ? supply : 0]
        for _ in 0..<120 {
            guard let solution = try? simulator.step(timeStep: tau / 24), let v = solution.voltage(at: 2) else { return nil }
            values.append(v)
        }
        return values
    }
    var body: some View {
        let numerical = numerical
        BenchScreen {
            BenchHeader(eyebrow: "02 / energy has memory", title: "Charge & release", subtitle: "A capacitor stores charge. Resistance sets how quickly it can change.")
            Picker("Experiment", selection: $discharging) { Text("Charge").tag(false); Text("Discharge").tag(true) }.pickerStyle(.segmented)
            InstrumentPanel(title: "RC step response", subtitle: "Cyan: exact law · amber: numerical solver") {
                RCTracePlot(supply: supply, discharge: discharging, numerical: numerical ?? [], cursor: elapsedTau)
                    .frame(height: 190)
                HStack { Text("0 s"); Spacer(); Text("5τ = \(engineering(5 * tau, unit: "s"))") }.font(.caption).foregroundStyle(BenchTheme.muted)
                ParameterSlider(title: "Scrub time", value: $elapsedTau, range: 0...5, unit: "τ")
                HStack {
                    MeterValue(label: "Capacitor", value: String(format: "%.3f", voltage), unit: "V")
                    MeterValue(label: "Into capacitor", value: String(format: "%.3f", current * 1000), unit: "mA", tint: BenchTheme.amber)
                }
                Text("Time \(engineering(elapsedTau * tau, unit: "s")) · stored energy \(engineering(0.5 * capacitance * 1e-6 * voltage * voltage, unit: "J"))").font(.caption).foregroundStyle(BenchTheme.muted)
            }
            InstrumentPanel(title: "Change the components") {
                ParameterSlider(title: "Resistance", value: $resistance, range: 100...10000, unit: "Ω", format: "%.0f")
                ParameterSlider(title: "Capacitance", value: $capacitance, range: 1...1000, unit: "µF", format: "%.0f")
                ParameterSlider(title: "Initial / supply voltage", value: $supply, range: 1...12, unit: "V")
                Text("τ = RC = \(engineering(tau, unit: "s"))").font(.system(.headline, design: .monospaced)).foregroundStyle(BenchTheme.green)
            }
            InstrumentPanel(title: "Why the curve bends") {
                FormulaNote(equation: discharging ? "V₍C₎(t) = V₀e^(−t/RC)" : "V₍C₎(t) = Vₛ(1 − e^(−t/RC))", explanation: "I = C dV/dt and I = (Vₛ − V₍C₎)/R describe the same current. As the voltage difference shrinks, so does the rate of change. At one time constant, a charging capacitor reaches 63.2% of its final voltage.")
                Text("Try it: double R. The normalized curve stays the same, but the real time doubles.").font(.subheadline)
                Text("Model: ideal linear R and C, instantaneous source step, fixed initial charge. Amber uses backward Euler at Δt = τ/24; its finite-timestep approximation decays more slowly than the exact RC solution. The meters use the exact analytical solution.").font(.caption).foregroundStyle(BenchTheme.muted)
                if numerical == nil { Text("Numerical solver could not evaluate this model.").foregroundStyle(BenchTheme.amber) }
            }
        }.onChange(of: discharging) { _, _ in elapsedTau = 0 }
    }
}

private struct RCTracePlot: View {
    var supply: Double
    var discharge: Bool
    var numerical: [Double]
    var cursor: Double
    var body: some View {
        Canvas { context, size in
            func point(_ t: Double, _ v: Double) -> CGPoint { CGPoint(x: size.width * t / 5, y: size.height * (0.95 - 0.9 * v / supply)) }
            for row in 0...4 {
                let y = size.height * CGFloat(row) / 4
                var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(.white.opacity(0.1)), lineWidth: 1)
            }
            var exact = Path()
            for index in 0...200 {
                let t = Double(index) / 40
                let p = point(t, supply * (discharge ? exp(-t) : -expm1(-t)))
                if index == 0 { exact.move(to: p) } else { exact.addLine(to: p) }
            }
            context.stroke(exact, with: .color(BenchTheme.cyan), lineWidth: 3)
            var approximation = Path()
            for (index, v) in numerical.enumerated() {
                let p = point(Double(index) / 24, v)
                if index == 0 { approximation.move(to: p) } else { approximation.addLine(to: p) }
            }
            context.stroke(approximation, with: .color(BenchTheme.amber), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            let p = point(cursor, supply * (discharge ? exp(-cursor) : -expm1(-cursor)))
            context.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(BenchTheme.ink))
            context.draw(Text(String(format: "%.1f V", supply)).font(.caption).foregroundStyle(BenchTheme.muted), at: CGPoint(x: 25, y: 10))
            context.draw(Text("0 V").font(.caption).foregroundStyle(BenchTheme.muted), at: CGPoint(x: 18, y: size.height - 6))
        }
        .accessibilityLabel("Capacitor voltage over five time constants. Exact exponential curve and backward Euler approximation.")
    }
}

struct ACLabView: View {
    @State private var resistance = 1000.0
    @State private var capacitance = 1.0
    @State private var frequency = 160.0
    @State private var amplitude = 5.0
    private var ratio: Double { 2 * .pi * frequency * resistance * capacitance * 1e-6 }
    private var gain: Double { 1 / sqrt(1 + ratio * ratio) }
    private var phase: Double { -atan(ratio) }
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "03 / follow a changing voltage", title: "The low-pass filter", subtitle: "Slow signals pass. Fast signals lose amplitude and lag behind.")
            InstrumentPanel(title: "Sinusoidal steady state", subtitle: "RC series circuit · output across capacitor") {
                ACScope(gain: gain, phase: phase).frame(height: 170)
                HStack { Text("0 s"); Spacer(); Text("3 cycles · \(engineering(3 / frequency, unit: "s"))") }.font(.caption).foregroundStyle(BenchTheme.muted)
                HStack {
                    MeterValue(label: "Output peak", value: String(format: "%.2f", amplitude * gain), unit: "V")
                    MeterValue(label: "Gain", value: String(format: "%.2f", 20 * log10(gain)), unit: "dB", tint: BenchTheme.green)
                    MeterValue(label: "Phase", value: String(format: "%.1f", phase * 180 / .pi), unit: "°", tint: BenchTheme.amber)
                }
                Text("Amber input ±\(String(format: "%.1f", amplitude)) V · cyan output on the same scale").font(.caption).foregroundStyle(BenchTheme.muted)
            }
            InstrumentPanel(title: "Tune the circuit") {
                VStack(alignment: .leading, spacing: 3) {
                    HStack { Text("Frequency"); Spacer(); Text(engineering(frequency, unit: "Hz")).monospacedDigit().foregroundStyle(BenchTheme.cyan) }.font(.subheadline)
                    Slider(value: Binding(get: { log10(frequency) }, set: { frequency = pow(10, $0) }), in: 0...log10(20000)).tint(BenchTheme.cyan)
                        .accessibilityLabel("Frequency, logarithmic scale").accessibilityValue(engineering(frequency, unit: "Hz"))
                }
                ParameterSlider(title: "Resistance", value: $resistance, range: 100...10000, unit: "Ω", format: "%.0f")
                ParameterSlider(title: "Capacitance", value: $capacitance, range: 0.1...10, unit: "µF")
                ParameterSlider(title: "Input peak", value: $amplitude, range: 0.5...10, unit: "V")
                let cutoff = 1 / (2 * .pi * resistance * capacitance * 1e-6)
                Button("Set frequency to cutoff") { frequency = cutoff }.buttonStyle(GlassActionStyle())
                Text("f₍c₎ = \(engineering(cutoff, unit: "Hz"))").font(.system(.headline, design: .monospaced)).foregroundStyle(BenchTheme.green)
            }
            InstrumentPanel(title: "From charge to frequency") {
                FormulaNote(equation: "H(jω) = 1 / (1 + jωRC)", explanation: "The capacitor's impedance is 1/(jωC). Voltage division produces this transfer function. At cutoff, amplitude is 1/√2 of input (−3.01 dB) and phase is −45°.")
                Text("Model: ideal linear RC, unloaded output, sinusoidal steady state. Startup transients and source resistance are excluded. Peak voltage and RMS voltage are different; RMS = peak/√2 for a sine.").font(.caption).foregroundStyle(BenchTheme.muted)
            }
        }
    }
}

private struct ACScope: View {
    var gain: Double
    var phase: Double
    var body: some View {
        Canvas { context, size in
            for row in 0...4 {
                var grid = Path(); let y = CGFloat(row) * size.height / 4
                grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(grid, with: .color(.white.opacity(0.1)), lineWidth: 1)
            }
            for output in [false, true] {
                var path = Path()
                for index in 0...300 {
                    let t = Double(index) / 300
                    let v = (output ? gain : 1) * sin(6 * .pi * t + (output ? phase : 0))
                    let p = CGPoint(x: size.width * t, y: size.height * (0.5 - 0.43 * v))
                    if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                context.stroke(path, with: .color(output ? BenchTheme.cyan : BenchTheme.amber.opacity(0.6)), lineWidth: output ? 2.5 : 1.5)
            }
        }.accessibilityLabel("Three-cycle scope. Output magnitude \(gain) times input, with phase \(phase * 180 / .pi) degrees.")
    }
}
