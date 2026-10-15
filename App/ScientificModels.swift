import Foundation

/// Closed-form teaching models. Inputs and outputs use SI units unless named otherwise.
/// Each function rejects nonfinite or physically invalid parameters rather than inventing a result.
enum ScientificModels {
    static let boltzmannConstant = 1.380649e-23
    static let elementaryCharge = 1.602176634e-19
    static let vacuumPermittivity = 8.8541878188e-12
    static let coulombConstant = 1 / (4 * Double.pi * vacuumPermittivity)

    struct DiodePoint: Equatable {
        let current: Double
        let thermalVoltage: Double
        let exponent: Double
    }

    /// Shockley junction law at a specified fixed saturation current.
    /// Does not model reverse breakdown, series resistance, high injection, or self-heating.
    static func diode(voltage: Double, saturationCurrent: Double, ideality: Double, kelvin: Double = 300) -> DiodePoint? {
        guard [voltage, saturationCurrent, ideality, kelvin].allSatisfy(\.isFinite),
              saturationCurrent > 0, ideality > 0, kelvin > 0 else { return nil }
        let thermal = boltzmannConstant * kelvin / elementaryCharge
        let exponent = voltage / (ideality * thermal)
        guard exponent.isFinite, exponent <= 700 else { return nil }
        let current = saturationCurrent * expm1(exponent)
        guard current.isFinite else { return nil }
        return DiodePoint(current: current, thermalVoltage: thermal, exponent: exponent)
    }

    struct AmplifierPoint: Equatable {
        let gain: Double
        let requestedOutput: Double
        let output: Double
        var isClipped: Bool { abs(requestedOutput) > abs(output) }
    }

    /// Ideal negative-feedback inverting amplifier, with an explicitly idealized hard rail limit.
    static func invertingAmplifier(input: Double, inputResistance: Double, feedbackResistance: Double, rail: Double) -> AmplifierPoint? {
        guard [input, inputResistance, feedbackResistance, rail].allSatisfy(\.isFinite),
              inputResistance > 0, feedbackResistance >= 0, rail > 0 else { return nil }
        let gain = -feedbackResistance / inputResistance
        let requested = gain * input
        guard gain.isFinite, requested.isFinite else { return nil }
        return AmplifierPoint(gain: gain, requestedOutput: requested, output: min(rail, max(-rail, requested)))
    }

    static func harmonicSignal(time: Double, fundamental: Double, second: Double, third: Double) -> Double? {
        guard [time, fundamental, second, third].allSatisfy(\.isFinite), fundamental >= 0 else { return nil }
        let phase = 2 * Double.pi * fundamental * time
        guard phase.isFinite else { return nil }
        let value = sin(phase) + second * sin(2 * phase) + third * sin(3 * phase)
        return value.isFinite ? value : nil
    }

    /// Signed principal-zone frequency: sign preserves the phase of a sampled sine.
    static func signedAlias(frequency: Double, sampleRate: Double) -> Double? {
        guard frequency.isFinite, sampleRate.isFinite, sampleRate > 0 else { return nil }
        var folded = frequency.truncatingRemainder(dividingBy: sampleRate)
        if folded > sampleRate / 2 { folded -= sampleRate }
        if folded < -sampleRate / 2 { folded += sampleRate }
        return folded
    }

    static func sampledAliasSignal(time: Double, fundamental: Double, second: Double, third: Double, sampleRate: Double) -> Double? {
        guard [time, fundamental, second, third].allSatisfy(\.isFinite), fundamental >= 0,
              let first = signedAlias(frequency: fundamental, sampleRate: sampleRate),
              let secondFrequency = signedAlias(frequency: 2 * fundamental, sampleRate: sampleRate),
              let thirdFrequency = signedAlias(frequency: 3 * fundamental, sampleRate: sampleRate) else { return nil }
        let value = sin(2 * .pi * first * time) + second * sin(2 * .pi * secondFrequency * time) + third * sin(2 * .pi * thirdFrequency * time)
        return value.isFinite ? value : nil
    }

    struct ControlPoint: Equatable {
        let finalValue: Double
        let closedLoopTimeConstant: Double
        let value: Double
        var steadyStateError: Double { 1 - finalValue }
    }

    /// Unit step response of G(s)=1/(τs+1) with proportional gain Kp and unity negative feedback.
    static func proportionalStep(time: Double, plantTimeConstant: Double, proportionalGain: Double) -> ControlPoint? {
        guard [time, plantTimeConstant, proportionalGain].allSatisfy(\.isFinite),
              time >= 0, plantTimeConstant > 0, proportionalGain >= 0 else { return nil }
        let factor = 1 + proportionalGain
        let finalValue = proportionalGain / factor
        let closedTau = plantTimeConstant / factor
        let value = finalValue * -expm1(-time / closedTau)
        guard value.isFinite, closedTau.isFinite, closedTau > 0 else { return nil }
        return ControlPoint(finalValue: finalValue, closedLoopTimeConstant: closedTau, value: value)
    }

    struct FieldPoint: Equatable {
        /// Signed outward radial component of E; a negative result points toward the source.
        let radialField: Double
        let potential: Double
    }

    static func pointCharge(charge: Double, distance: Double) -> FieldPoint? {
        guard charge.isFinite, distance.isFinite, distance > 0 else { return nil }
        let field = coulombConstant * charge / (distance * distance)
        let potential = coulombConstant * charge / distance
        guard field.isFinite, potential.isFinite else { return nil }
        return FieldPoint(radialField: field, potential: potential)
    }

    /// Full-carrier double-sideband AM. Overmodulation is represented mathematically, without clipping.
    static func amplitudeModulation(time: Double, carrierFrequency: Double, messageFrequency: Double, modulationIndex: Double, carrierAmplitude: Double = 1) -> Double? {
        guard [time, carrierFrequency, messageFrequency, modulationIndex, carrierAmplitude].allSatisfy(\.isFinite),
              carrierFrequency > 0, messageFrequency >= 0, messageFrequency < carrierFrequency,
              modulationIndex >= 0, carrierAmplitude >= 0 else { return nil }
        let envelope = carrierAmplitude * (1 + modulationIndex * cos(2 * .pi * messageFrequency * time))
        let value = envelope * cos(2 * .pi * carrierFrequency * time)
        return value.isFinite ? value : nil
    }

    struct ACPower: Equatable {
        let apparent: Double
        let real: Double
        let reactive: Double
        let powerFactor: Double
    }

    /// Single-phase sinusoidal steady state, passive sign convention. φ = voltage phase minus current phase.
    static func acPower(voltageRMS: Double, currentRMS: Double, phaseDegrees: Double) -> ACPower? {
        guard [voltageRMS, currentRMS, phaseDegrees].allSatisfy(\.isFinite),
              voltageRMS >= 0, currentRMS >= 0, abs(phaseDegrees) <= 180 else { return nil }
        let phase = phaseDegrees * .pi / 180
        let apparent = voltageRMS * currentRMS
        guard apparent.isFinite else { return nil }
        return ACPower(apparent: apparent, real: apparent * cos(phase), reactive: apparent * sin(phase), powerFactor: cos(phase))
    }

    static func instantaneousPower(time: Double, voltageRMS: Double, currentRMS: Double, phaseDegrees: Double, frequency: Double = 50) -> Double? {
        guard time.isFinite, frequency.isFinite, frequency > 0,
              acPower(voltageRMS: voltageRMS, currentRMS: currentRMS, phaseDegrees: phaseDegrees) != nil else { return nil }
        let phase = phaseDegrees * .pi / 180
        let angle = 2 * .pi * frequency * time
        let value = 2 * voltageRMS * currentRMS * cos(angle) * cos(angle - phase)
        return value.isFinite ? value : nil
    }
}
