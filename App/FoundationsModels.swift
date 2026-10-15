import Foundation

/// Bounded teaching models; all arguments use SI units. A nil result is undefined or
/// outside numerical range. No parameter is silently replaced by a plausible reading.
enum FoundationsModels {
    static let q = 1.602176634e-19
    static let k = 1.380649e-23
    static let h = 6.62607015e-34
    static let c = 299_792_458.0

    struct CalculusPoint { let current: Double; let charge: Double }
    static func sineCurrent(time: Double, mean: Double, amplitude: Double, frequency: Double) -> CalculusPoint? {
        guard finite(time, mean, amplitude, frequency), time >= 0, frequency > 0 else { return nil }
        let omega = 2 * Double.pi * frequency
        let current = mean + amplitude * sin(omega * time)
        let charge = mean * time + amplitude / omega * (1 - cos(omega * time))
        guard finite(current, charge) else { return nil }
        return .init(current: current, charge: charge)
    }
    static func rampCurrent(time: Double, initial: Double, slope: Double) -> CalculusPoint? {
        guard finite(time, initial, slope), time >= 0 else { return nil }
        let current = initial + slope * time, charge = initial * time + 0.5 * slope * time * time
        guard finite(current, charge) else { return nil }
        return .init(current: current, charge: charge)
    }

    struct NodalPoint {
        let va: Double; let vb: Double; let determinant: Double
        let g11: Double; let g12: Double; let g22: Double; let rhs: Double
        let kclA: Double; let kclB: Double
    }
    /// Vs--R1--Va; R2 from Va to ground; R3 from Va to Vb; R4 from Vb to ground.
    static func twoNode(supply: Double, r1: Double, r2: Double, r3: Double, r4: Double) -> NodalPoint? {
        guard finite(supply, r1, r2, r3, r4), min(r1, r2, r3, r4) > 0 else { return nil }
        let g1 = 1/r1, g2 = 1/r2, g3 = 1/r3, g4 = 1/r4
        let a = g1 + g2 + g3, b = -g3, d = g3 + g4, rhs = g1 * supply
        let determinant = a * d - b * b
        guard determinant > 0, determinant.isFinite else { return nil }
        let va = rhs * d / determinant, vb = -rhs * b / determinant
        let kclA = (va-supply)/r1 + va/r2 + (va-vb)/r3
        let kclB = (vb-va)/r3 + vb/r4
        guard finite(va, vb, kclA, kclB) else { return nil }
        return .init(va: va, vb: vb, determinant: determinant, g11: a, g12: b, g22: d, rhs: rhs, kclA: kclA, kclB: kclB)
    }

    struct ComplexPoint {
        let real: Double; let imaginary: Double
        var magnitude: Double { hypot(real, imaginary) }
        var phase: Double { atan2(imaginary, real) }
    }
    /// RC low-pass H(s)=1/(1+sRC). sigma and omega are real/imaginary parts of s in s^-1.
    static func rcTransfer(resistance: Double, capacitance: Double, sigma: Double, omega: Double) -> ComplexPoint? {
        guard finite(resistance, capacitance, sigma, omega), resistance > 0, capacitance > 0 else { return nil }
        let real = 1 + resistance * capacitance * sigma, imaginary = resistance * capacitance * omega
        let denominator = real * real + imaginary * imaginary
        guard denominator > 0, denominator.isFinite else { return nil }
        let result = ComplexPoint(real: real / denominator, imaginary: -imaginary / denominator)
        return finite(result.real, result.imaginary) ? result : nil
    }

    struct ODETrace {
        let times: [Double]; let exact: [Double]; let forwardEuler: [Double]; let backwardEuler: [Double]
        let forwardMultiplier: Double; let backwardMultiplier: Double
    }
    /// tau*x' + x = target with a specified initial value. Numerical samples include t=0.
    static func firstOrder(initial: Double, target: Double, tau: Double, step: Double, count: Int) -> ODETrace? {
        guard finite(initial, target, tau, step), tau > 0, step > 0, (1...1_000).contains(count) else { return nil }
        let ratio = step / tau, forward = 1 - ratio, backward = 1 / (1 + ratio)
        var times = [0.0], exact = [initial], fe = [initial], be = [initial]
        for index in 1...count {
            let time = Double(index) * step
            let e = target + (initial-target) * exp(-time/tau)
            let f = target + forward * (fe.last! - target)
            let b = target + backward * (be.last! - target)
            guard finite(time, e, f, b) else { return nil }
            times.append(time); exact.append(e); fe.append(f); be.append(b)
        }
        return .init(times: times, exact: exact, forwardEuler: fe, backwardEuler: be, forwardMultiplier: forward, backwardMultiplier: backward)
    }

    struct TolerancePoint {
        let minimumCurrent: Double; let maximumCurrent: Double; let meanCurrent: Double
        let standardDeviation: Double; let probabilityAbove: Double
    }
    /// R is exactly Uniform(Rnom*(1-t), Rnom*(1+t)); supply is deterministic and nonnegative.
    static func tolerance(supply: Double, nominalResistance: Double, fraction: Double, threshold: Double) -> TolerancePoint? {
        guard finite(supply, nominalResistance, fraction, threshold), supply >= 0,
              nominalResistance > 0, fraction >= 0, fraction < 1 else { return nil }
        let a = nominalResistance * (1-fraction), b = nominalResistance * (1+fraction)
        let low = supply/b, high = supply/a
        let mean: Double, variance: Double, probability: Double
        if fraction == 0 {
            mean = supply/nominalResistance
            variance = 0
            probability = mean > threshold ? 1 : 0
        } else {
            mean = supply * (log1p(fraction)-log1p(-fraction)) / (2 * nominalResistance * fraction)
            variance = max(0, supply*supply/(a*b) - mean*mean)
            if threshold < 0 { probability = 1 }
            else if threshold == 0 { probability = supply > 0 ? 1 : 0 }
            else { probability = min(1, max(0, (supply/threshold-a)/(b-a))) }
        }
        guard finite(low, high, mean, variance, probability) else { return nil }
        return .init(minimumCurrent: low, maximumCurrent: high, meanCurrent: mean, standardDeviation: sqrt(variance), probabilityAbove: probability)
    }
    /// Current CDF derived by monotonically transforming the uniform resistance.
    static func currentCDF(current: Double, supply: Double, nominalResistance: Double, fraction: Double) -> Double? {
        guard let result = tolerance(supply: supply, nominalResistance: nominalResistance, fraction: fraction, threshold: current) else { return nil }
        return 1 - result.probabilityAbove
    }

    struct SampleStatistics {
        let measuredCurrents: [Double]; let runningMeans: [Double]; let mean: Double
        let sampleStandardDeviation: Double?; let standardError: Double?; let expectedMeasuredMean: Double
    }
    /// Reproducible SplitMix64 pseudorandom uniform draws, under the independent-R assumption.
    /// The fixed calibration offset changes the mean and cannot be removed by averaging.
    static func resistorSamples(supply: Double, nominalResistance: Double, fraction: Double, count: Int, seed: UInt64, calibrationOffset: Double) -> SampleStatistics? {
        guard calibrationOffset.isFinite, (1...5_000).contains(count),
              let distribution = tolerance(supply: supply, nominalResistance: nominalResistance, fraction: fraction, threshold: 0) else { return nil }
        var state = seed, values: [Double] = [], means: [Double] = []
        var mean = 0.0, m2 = 0.0
        for index in 1...count {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            z ^= z >> 31
            let uniform = Double(z >> 11) / 9_007_199_254_740_992.0
            let resistance = nominalResistance*(1-fraction+2*fraction*uniform)
            let current = supply/resistance+calibrationOffset
            let delta = current-mean
            mean += delta/Double(index)
            m2 += delta*(current-mean)
            guard finite(current, mean, m2) else { return nil }
            values.append(current); means.append(mean)
        }
        let deviation = count > 1 ? sqrt(max(0, m2/Double(count-1))) : nil
        return .init(measuredCurrents: values, runningMeans: means, mean: mean, sampleStandardDeviation: deviation, standardError: deviation.map { $0/sqrt(Double(count)) }, expectedMeasuredMean: distribution.meanCurrent+calibrationOffset)
    }

    struct ConductorPoint { let conductivity: Double; let resistance: Double; let current: Double; let power: Double }
    static func conductor(density: Double, mobility: Double, length: Double, area: Double, voltage: Double) -> ConductorPoint? {
        guard finite(density, mobility, length, area, voltage), min(density, mobility, length, area) > 0 else { return nil }
        let sigma = q * density * mobility, resistance = length/(sigma*area), current = voltage/resistance, power = voltage*current
        guard finite(sigma, resistance, current, power), sigma > 0, resistance > 0 else { return nil }
        return .init(conductivity: sigma, resistance: resistance, current: current, power: power)
    }
    struct HeatingPoint { let energy: Double; let temperature: Double }
    static func heating(power: Double, mass: Double, specificHeat: Double, time: Double, initialTemperature: Double) -> HeatingPoint? {
        guard finite(power, mass, specificHeat, time, initialTemperature), power >= 0,
              mass > 0, specificHeat > 0, time >= 0, initialTemperature > 0 else { return nil }
        let energy = power*time, temperature = initialTemperature + energy/(mass*specificHeat)
        guard finite(energy, temperature) else { return nil }
        return .init(energy: energy, temperature: temperature)
    }
    struct PhotonPoint { let frequency: Double; let energy: Double; var electronVolts: Double { energy / q } }
    static func photon(wavelength: Double) -> PhotonPoint? {
        guard wavelength.isFinite, wavelength > 0 else { return nil }
        let frequency = c/wavelength, energy = h*frequency
        guard finite(frequency, energy), frequency > 0, energy > 0 else { return nil }
        return .init(frequency: frequency, energy: energy)
    }
    static func mechanicalWork(force: Double, displacement: Double, angleDegrees: Double) -> Double? {
        guard finite(force, displacement, angleDegrees), force >= 0, displacement >= 0 else { return nil }
        let work = force*displacement*cos(angleDegrees*Double.pi/180)
        return work.isFinite ? work : nil
    }

    struct RLPoint { let current: Double; let voltage: Double; let energy: Double; let tau: Double; let slope: Double }
    static func rl(time: Double, supply: Double, resistance: Double, inductance: Double, initialCurrent: Double) -> RLPoint? {
        guard finite(time, supply, resistance, inductance, initialCurrent), time >= 0, resistance > 0, inductance > 0 else { return nil }
        let tau = inductance/resistance, final = supply/resistance
        let current = final + (initialCurrent-final)*exp(-time/tau)
        let voltage = supply-resistance*current, slope = voltage/inductance, energy = 0.5*inductance*current*current
        guard finite(tau, current, voltage, slope, energy), tau > 0 else { return nil }
        return .init(current: current, voltage: voltage, energy: energy, tau: tau, slope: slope)
    }

    struct RLCPoint { let voltage: Double; let current: Double; let omega0: Double; let damping: Double; let regime: String }
    /// Series RLC zero-state voltage-step response, measured across C.
    static func rlcStep(time: Double, supply: Double, resistance: Double, inductance: Double, capacitance: Double) -> RLCPoint? {
        guard finite(time, supply, resistance, inductance, capacitance), time >= 0,
              resistance >= 0, inductance > 0, capacitance > 0 else { return nil }
        let omega0 = 1/sqrt(inductance*capacitance), alpha = resistance/(2*inductance), zeta = alpha/omega0
        let voltage: Double, derivative: Double, regime: String
        if abs(zeta-1) < 1e-7 {
            voltage = supply*(1-exp(-omega0*time)*(1+omega0*time))
            derivative = supply*omega0*omega0*time*exp(-omega0*time)
            regime = "Critical"
        } else if zeta < 1 {
            let omega = sqrt(max(0, omega0*omega0-alpha*alpha))
            voltage = supply*(1-exp(-alpha*time)*(cos(omega*time)+alpha/omega*sin(omega*time)))
            derivative = supply*omega0*omega0/omega*exp(-alpha*time)*sin(omega*time)
            regime = "Underdamped"
        } else {
            let root = sqrt(alpha*alpha-omega0*omega0)
            let r1 = -omega0*omega0/(alpha+root), r2 = -alpha-root
            let e1 = exp(r1*time), e2 = exp(r2*time)
            voltage = supply*(1-(r2*e1-r1*e2)/(r2-r1))
            derivative = supply*omega0*omega0*(e1-e2)/(r1-r2)
            regime = "Overdamped"
        }
        let current = capacitance*derivative
        guard finite(omega0, zeta, voltage, current) else { return nil }
        return .init(voltage: voltage, current: current, omega0: omega0, damping: zeta, regime: regime)
    }
    struct SeriesACPoint {
        let currentPeak: Double; let currentPhase: Double; let capacitorPeak: Double
        let resonance: Double; let quality: Double
        /// Difference between the current half-power frequencies, in Hz.
        var bandwidth: Double { resonance/quality }
    }
    static func seriesAC(frequency: Double, voltagePeak: Double, resistance: Double, inductance: Double, capacitance: Double) -> SeriesACPoint? {
        guard finite(frequency, voltagePeak, resistance, inductance, capacitance),
              frequency > 0, voltagePeak >= 0, resistance > 0, inductance > 0, capacitance > 0 else { return nil }
        let omega = 2*Double.pi*frequency, reactance = omega*inductance-1/(omega*capacitance)
        let current = voltagePeak/hypot(resistance, reactance)
        let result = SeriesACPoint(currentPeak: current, currentPhase: -atan2(reactance, resistance), capacitorPeak: current/(omega*capacitance), resonance: 1/(2*Double.pi*sqrt(inductance*capacitance)), quality: sqrt(inductance/capacitance)/resistance)
        return finite(result.currentPeak, result.currentPhase, result.capacitorPeak, result.resonance, result.quality) ? result : nil
    }

    struct TheveninPoint { let openVoltage: Double; let resistance: Double; let loadVoltage: Double; let loadCurrent: Double; let loadPower: Double; let directVoltage: Double; let maximumPower: Double }
    /// An independent-source divider, loaded at its midpoint; dependent sources are not included.
    static func thevenin(supply: Double, top: Double, bottom: Double, load: Double) -> TheveninPoint? {
        guard finite(supply, top, bottom, load), min(top, bottom, load) > 0 else { return nil }
        let open = supply*bottom/(top+bottom), resistance = top*bottom/(top+bottom)
        let current = open/(resistance+load), voltage = current*load
        let parallel = bottom*load/(bottom+load), direct = supply*parallel/(top+parallel)
        let power = current*current*load, maximum = open*open/(4*resistance)
        guard finite(open, resistance, current, voltage, direct, power, maximum) else { return nil }
        return .init(openVoltage: open, resistance: resistance, loadVoltage: voltage, loadCurrent: current, loadPower: power, directVoltage: direct, maximumPower: maximum)
    }

    struct BJTPoint {
        let collector: Double; let base: Double; let emitterOut: Double; let thermalVoltage: Double
        let gm: Double; let outputConductance: Double; let region: String
        var kcl: Double { collector+base-emitterOut }
    }
    /// Reciprocal low-injection Ebers-Moll. alphaF*IES = alphaR*ICS = transportSaturation.
    /// Emitter current is reported out of the device; base and collector currents enter it.
    static func bjt(vbe: Double, vce: Double, transportSaturation: Double = 1e-15, beta: Double = 100, reverseAlpha: Double = 0.5, kelvin: Double = 300) -> BJTPoint? {
        guard finite(vbe, vce, transportSaturation, beta, reverseAlpha, kelvin), transportSaturation > 0,
              beta > 0, reverseAlpha > 0, reverseAlpha < 1, kelvin > 0 else { return nil }
        let vt = k*kelvin/q, alpha = beta/(beta+1), vbc = vbe-vce
        let eF = vbe/vt, eR = vbc/vt
        guard finite(eF, eR), max(eF, eR) < 700 else { return nil }
        let forward = transportSaturation/alpha*expm1(eF), reverse = transportSaturation/reverseAlpha*expm1(eR)
        let collector = alpha*forward-reverse, emitter = forward-reverseAlpha*reverse
        let base = (1-alpha)*forward+(1-reverseAlpha)*reverse
        let gm = transportSaturation/vt*exp(eF)-transportSaturation/(reverseAlpha*vt)*exp(eR)
        let go = transportSaturation/(reverseAlpha*vt)*exp(eR)
        let region = vbe <= 0 ? (vbc <= 0 ? "Cutoff" : "Reverse-active") : (vbc <= 0 ? "Forward-active" : "Saturation")
        guard finite(collector, base, emitter, gm, go) else { return nil }
        return .init(collector: collector, base: base, emitterOut: emitter, thermalVoltage: vt, gm: gm, outputConductance: go, region: region)
    }

    struct MOSPoint { let current: Double; let gm: Double; let outputConductance: Double; let region: String }
    /// Long-channel enhancement NMOS, body tied to source, lambda=0, no subthreshold current.
    /// coefficient = mobility*Cox*W/L, in A/V².
    static func mosfet(vgs: Double, vds: Double, threshold: Double, coefficient: Double) -> MOSPoint? {
        guard finite(vgs, vds, threshold, coefficient), vds >= 0, coefficient > 0 else { return nil }
        let overdrive = vgs-threshold
        let current: Double, gm: Double, go: Double, region: String
        if overdrive <= 0 { current = 0; gm = 0; go = 0; region = "Cutoff" }
        else if vds < overdrive {
            current = coefficient*(overdrive*vds-0.5*vds*vds)
            gm = coefficient*vds; go = coefficient*(overdrive-vds); region = "Triode"
        } else {
            current = 0.5*coefficient*overdrive*overdrive
            gm = coefficient*overdrive; go = 0; region = "Saturation"
        }
        guard finite(current, gm, go) else { return nil }
        return .init(current: current, gm: gm, outputConductance: go, region: region)
    }

    struct AmplifierPoint { let biasVBE: Double; let biasOutput: Double; let output: Double; let deltaOutput: Double; let linearDelta: Double; let gain: Double; let numericalGain: Double; let region: String }
    /// Quasistatic common-emitter stage with an ideal imposed base voltage and collector resistor.
    /// Its nonlinear operating point solves the Ebers-Moll collector current/load-line equation.
    static func commonEmitter(biasForwardCurrent: Double, resistance: Double, supply: Double, input: Double, kelvin: Double = 300) -> AmplifierPoint? {
        guard finite(biasForwardCurrent, resistance, supply, input, kelvin), biasForwardCurrent > 0,
              resistance > 0, supply > 0, kelvin > 0 else { return nil }
        let vt = k*kelvin/q, isat = 1e-15, bias = vt*log1p(biasForwardCurrent/isat)
        func loadedOutput(_ vbe: Double) -> Double? {
            var lo = 0.0, hi = supply
            guard let low = bjt(vbe: vbe, vce: lo, kelvin: kelvin), let high = bjt(vbe: vbe, vce: hi, kelvin: kelvin),
                  low.collector-(supply-lo)/resistance <= 0, high.collector >= 0 else { return nil }
            for _ in 0..<100 {
                let mid = (lo+hi)/2
                guard let point = bjt(vbe: vbe, vce: mid, kelvin: kelvin) else { return nil }
                if point.collector-(supply-mid)/resistance > 0 { hi = mid } else { lo = mid }
            }
            return (lo+hi)/2
        }
        guard let biasOutput = loadedOutput(bias), let output = loadedOutput(bias+input),
              let point = bjt(vbe: bias, vce: biasOutput, kelvin: kelvin),
              let positive = loadedOutput(bias+1e-6), let negative = loadedOutput(bias-1e-6),
              let actual = bjt(vbe: bias+input, vce: output, kelvin: kelvin) else { return nil }
        let gain = -point.gm*resistance/(1+point.outputConductance*resistance)
        let numericalGain = (positive-negative)/2e-6, linear = gain*input
        guard finite(bias, biasOutput, output, gain, numericalGain, linear) else { return nil }
        return .init(biasVBE: bias, biasOutput: biasOutput, output: output, deltaOutput: output-biasOutput, linearDelta: linear, gain: gain, numericalGain: numericalGain, region: actual.region)
    }

    private static func finite(_ values: Double...) -> Bool { values.allSatisfy(\.isFinite) }
}
