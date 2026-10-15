import Foundation

/// Bounded, reproducible models for the systems lessons; SI units unless documented otherwise.
enum SystemsModels {
    static let lightSpeed = 299_792_458.0
    static let epsilon0 = 8.8541878188e-12

    static func convolution(_ input: [Double], _ impulse: [Double]) -> [Double]? {
        guard !input.isEmpty, !impulse.isEmpty, input.count <= 256, impulse.count <= 256,
              (input + impulse).allSatisfy(\.isFinite) else { return nil }
        var output = Array(repeating: 0.0, count: input.count + impulse.count - 1)
        for i in input.indices { for j in impulse.indices { output[i + j] += input[i] * impulse[j] } }
        return output.allSatisfy(\.isFinite) ? output : nil
    }

    enum Window: String, CaseIterable { case rectangular, hann }
    struct Spectrum {
        let amplitudes: [Double]
        let binSpacing: Double
        let coherentGain: Double
    }

    /// One-sided DFT amplitude, normalized by sum(window); DC and Nyquist are not doubled.
    static func spectrum(_ samples: [Double], sampleRate: Double, window: Window) -> Spectrum? {
        let count = samples.count
        guard count >= 4, count <= 256, count.isMultiple(of: 2), samples.allSatisfy(\.isFinite),
              sampleRate.isFinite, sampleRate > 0 else { return nil }
        let weights = (0..<count).map { index in window == .hann ? 0.5 - 0.5 * cos(2 * .pi * Double(index) / Double(count - 1)) : 1 }
        let total = weights.reduce(0, +)
        let amplitudes = (0...(count / 2)).map { bin -> Double in
            var real = 0.0, imaginary = 0.0
            for index in 0..<count {
                let angle = 2 * .pi * Double(bin * index) / Double(count)
                real += samples[index] * weights[index] * cos(angle)
                imaginary -= samples[index] * weights[index] * sin(angle)
            }
            let multiplier = bin == 0 || bin == count / 2 ? 1.0 : 2.0
            return multiplier * hypot(real, imaginary) / total
        }
        guard amplitudes.allSatisfy(\.isFinite) else { return nil }
        return Spectrum(amplitudes: amplitudes, binSpacing: sampleRate / Double(count), coherentGain: total / Double(count))
    }

    static func fir(_ input: [Double], taps: [Double]) -> [Double]? {
        guard let output = convolution(input, taps) else { return nil }
        return Array(output.prefix(input.count))
    }

    static func firMagnitude(taps: [Double], normalizedFrequency: Double) -> Double? {
        guard !taps.isEmpty, taps.count <= 256, taps.allSatisfy(\.isFinite),
              normalizedFrequency.isFinite, (0...0.5).contains(normalizedFrequency) else { return nil }
        var real = 0.0, imaginary = 0.0
        for (index, tap) in taps.enumerated() {
            let phase = 2 * .pi * normalizedFrequency * Double(index)
            real += tap * cos(phase)
            imaginary -= tap * sin(phase)
        }
        let magnitude = hypot(real, imaginary)
        return magnitude.isFinite ? magnitude : nil
    }

    /// Exact unit-step response of (a²+b²)/(s²−2as+a²+b²), poles a ± jb.
    static func poleStep(time: Double, real: Double, imaginary: Double) -> Double? {
        guard [time, real, imaginary].allSatisfy(\.isFinite), time >= 0,
              time <= 30, abs(real) <= 2, imaginary >= 0, imaginary <= 20 else { return nil }
        if real == 0 && imaginary == 0 { return 0 }
        let value: Double
        if imaginary == 0 {
            value = 1 - exp(real * time) * (1 - real * time)
        } else {
            value = 1 - exp(real * time) * (cos(imaginary * time) - real / imaginary * sin(imaginary * time))
        }
        return value.isFinite ? value : nil
    }

    struct PIDConfiguration {
        var proportional = 2.0
        var integral = 1.0
        var derivative = 0.1
        var actuatorLimit = 1.5
        var disturbance = -0.4
        var measurementRipple = 0.0
        var antiWindup = true
        var step = 0.01
        var duration = 12.0
    }
    struct PIDRun {
        let reference: [Double]
        let output: [Double]
        let command: [Double]
        let integralTerm: [Double]
        let duration: Double
        let saturatedSamples: Int
    }

    /// Sampled controller, exact zero-order-held first-order plant update; derivative on measurement.
    static func pid(_ config: PIDConfiguration) -> PIDRun? {
        guard [config.proportional, config.integral, config.derivative, config.actuatorLimit, config.disturbance, config.measurementRipple, config.step, config.duration].allSatisfy(\.isFinite),
              (0...12).contains(config.proportional), (0...12).contains(config.integral), (0...2).contains(config.derivative),
              (0.1...5).contains(config.actuatorLimit), (-2...2).contains(config.disturbance), (0...0.2).contains(config.measurementRipple),
              (0.001...0.02).contains(config.step), (8...20).contains(config.duration) else { return nil }
        let count = Int((config.duration / config.step).rounded())
        let dt = config.duration / Double(count)
        let decay = exp(-dt), derivativeDecay = exp(-dt / 0.05)
        var y = 0.0, integral = 0.0, filteredDerivative = 0.0, previousMeasurement = 0.0
        var references: [Double] = [], outputs: [Double] = [], commands: [Double] = [], integrals: [Double] = []
        var saturated = 0
        for index in 0...count {
            let time = Double(index) * dt
            let reference = time < 4 ? 1.0 : 0.0
            let measurement = y + config.measurementRipple * sin(2 * .pi * 12 * time)
            let error = reference - measurement
            filteredDerivative = derivativeDecay * filteredDerivative + (1 - derivativeDecay) * (measurement - previousMeasurement) / dt
            previousMeasurement = measurement
            let rawBeforeIntegral = config.proportional * error + integral - config.derivative * filteredDerivative
            let worsensSaturation = (rawBeforeIntegral >= config.actuatorLimit && error > 0) || (rawBeforeIntegral <= -config.actuatorLimit && error < 0)
            if !config.antiWindup || !worsensSaturation { integral += config.integral * error * dt }
            let requested = config.proportional * error + integral - config.derivative * filteredDerivative
            let command = max(-config.actuatorLimit, min(config.actuatorLimit, requested))
            if abs(requested) > config.actuatorLimit { saturated += 1 }
            references.append(reference); outputs.append(y); commands.append(command); integrals.append(integral)
            if index < count {
                let disturbance = time >= 6 ? config.disturbance : 0
                y = decay * y + (1 - decay) * (command + disturbance)
            }
        }
        guard (outputs + commands + integrals).allSatisfy(\.isFinite) else { return nil }
        return PIDRun(reference: references, output: outputs, command: commands, integralTerm: integrals, duration: config.duration, saturatedSamples: saturated)
    }

    struct LQRGains: Equatable { let position: Double; let velocity: Double }
    /// ARE solution for a double integrator, Q = I, R = effortWeight > 0, normalized states.
    static func lqrGains(effortWeight: Double) -> LQRGains? {
        guard effortWeight.isFinite, effortWeight > 0 else { return nil }
        let position = 1 / sqrt(effortWeight)
        let velocity = sqrt(2 / sqrt(effortWeight) + 1 / effortWeight)
        guard position.isFinite, velocity.isFinite else { return nil }
        return LQRGains(position: position, velocity: velocity)
    }
    struct ObserverRun {
        let position: [Double]
        let velocity: [Double]
        let estimatedPosition: [Double]
        let estimatedVelocity: [Double]
        let acceleration: [Double]
        let duration: Double
        let cost: Double
        let gains: LQRGains
    }

    /// RK4 integration of plant + Luenberger observer. L = [2ω, ω²], observer poles both −ω.
    static func observer(effortWeight: Double, observerSpeed: Double, sensorRipple: Double, initialVelocity: Double, step: Double = 0.005, duration: Double = 8) -> ObserverRun? {
        guard [effortWeight, observerSpeed, sensorRipple, initialVelocity, step, duration].allSatisfy(\.isFinite),
              (0.02...10).contains(effortWeight), (0.2...15).contains(observerSpeed), (0...0.2).contains(sensorRipple),
              (-2...2).contains(initialVelocity), (0.001...0.02).contains(step), (1...15).contains(duration),
              let gains = lqrGains(effortWeight: effortWeight) else { return nil }
        let count = Int((duration / step).rounded()), dt = duration / Double(Int((duration / step).rounded()))
        var state = [1.0, initialVelocity, 0.0, 0.0, 0.0]
        var positions: [Double] = [], velocities: [Double] = [], estimates: [Double] = [], estimatedVelocities: [Double] = [], accelerations: [Double] = []
        func derivative(_ x: [Double], _ time: Double) -> [Double] {
            let acceleration = -gains.position * x[2] - gains.velocity * x[3]
            let innovation = x[0] + sensorRipple * sin(2 * .pi * 5 * time) - x[2]
            return [x[1], acceleration, x[3] + 2 * observerSpeed * innovation, acceleration + observerSpeed * observerSpeed * innovation,
                    x[0] * x[0] + x[1] * x[1] + effortWeight * acceleration * acceleration]
        }
        for index in 0...count {
            positions.append(state[0]); velocities.append(state[1]); estimates.append(state[2]); estimatedVelocities.append(state[3])
            accelerations.append(-gains.position * state[2] - gains.velocity * state[3])
            guard index < count else { break }
            let time = Double(index) * dt
            let k1 = derivative(state, time)
            let k2 = derivative(zip(state, k1).map { $0 + dt * $1 / 2 }, time + dt / 2)
            let k3 = derivative(zip(state, k2).map { $0 + dt * $1 / 2 }, time + dt / 2)
            let k4 = derivative(zip(state, k3).map { $0 + dt * $1 }, time + dt)
            state = state.indices.map { state[$0] + dt / 6 * (k1[$0] + 2 * k2[$0] + 2 * k3[$0] + k4[$0]) }
            guard state.allSatisfy(\.isFinite) else { return nil }
        }
        return ObserverRun(position: positions, velocity: velocities, estimatedPosition: estimates, estimatedVelocity: estimatedVelocities, acceleration: accelerations, duration: duration, cost: state[4], gains: gains)
    }

    struct PlaneWave {
        let electric: Double
        let magnetic: Double
        let energyDensity: Double
        let poynting: Double
        let averageIntensity: Double
        let wavelength: Double
    }
    static func planeWave(amplitude: Double, frequency: Double, position: Double, time: Double) -> PlaneWave? {
        guard [amplitude, frequency, position, time].allSatisfy(\.isFinite), amplitude >= 0, frequency > 0 else { return nil }
        let phase = 2 * .pi * frequency * (position / lightSpeed - time)
        let electric = amplitude * cos(phase), magnetic = electric / lightSpeed
        let energy = epsilon0 * electric * electric
        let average = epsilon0 * lightSpeed * amplitude * amplitude / 2
        guard [electric, magnetic, energy, average, lightSpeed / frequency].allSatisfy(\.isFinite) else { return nil }
        return PlaneWave(electric: electric, magnetic: magnetic, energyDensity: energy, poynting: lightSpeed * energy, averageIntensity: average, wavelength: lightSpeed / frequency)
    }
    struct FaradayPoint { let fluxPerTurn: Double; let emf: Double }
    static func faraday(time: Double, turns: Int, area: Double, fieldAmplitude: Double, frequency: Double) -> FaradayPoint? {
        guard [time, area, fieldAmplitude, frequency].allSatisfy(\.isFinite), (1...1_000).contains(turns), area > 0, fieldAmplitude >= 0, frequency >= 0 else { return nil }
        let angularFrequency = 2 * .pi * frequency
        let flux = area * fieldAmplitude * cos(angularFrequency * time)
        let emf = Double(turns) * area * fieldAmplitude * angularFrequency * sin(angularFrequency * time)
        guard flux.isFinite, emf.isFinite else { return nil }
        return FaradayPoint(fluxPerTurn: flux, emf: emf)
    }

    struct LineReflection {
        let coefficient: Double
        let loadVoltage: Double
        let absorbedFraction: Double
        var standingWaveRatio: Double { (1 + abs(coefficient)) / (1 - abs(coefficient)) }
    }
    /// nil load denotes an open circuit; 0 Ω denotes a short. Resistive, lossless line.
    static func reflection(characteristic: Double, load: Double?) -> LineReflection? {
        guard characteristic.isFinite, characteristic > 0 else { return nil }
        if let load, (!load.isFinite || load < 0) { return nil }
        let coefficient = load.map { resistance in
            let scale = max(resistance, characteristic)
            return (resistance / scale - characteristic / scale) / (resistance / scale + characteristic / scale)
        } ?? 1
        guard coefficient.isFinite else { return nil }
        return LineReflection(coefficient: coefficient, loadVoltage: 1 + coefficient, absorbedFraction: 1 - coefficient * coefficient)
    }
    static func linePulse(position: Double, time: Double, length: Double, speed: Double, width: Double, characteristic: Double, load: Double?) -> (incident: Double, reflected: Double, total: Double)? {
        guard [position, time, length, speed, width].allSatisfy(\.isFinite), length > 0, speed > 0, speed <= lightSpeed, width > 0,
              (0...length).contains(position), time >= 0, let boundary = reflection(characteristic: characteristic, load: load) else { return nil }
        func pulse(_ delayedTime: Double) -> Double { delayedTime >= 0 && delayedTime < width ? 1 : 0 }
        let incident = pulse(time - position / speed)
        let reflected = boundary.coefficient * pulse(time - (2 * length - position) / speed)
        return (incident, reflected, incident + reflected)
    }

    struct BPSKSymbol { let bit: Int; let inPhase: Double; let quadrature: Double; let decoded: Int }
    struct BPSKRun {
        let symbols: [BPSKSymbol]
        let theoreticalBER: Double
        var errors: Int { symbols.filter { $0.bit != $0.decoded }.count }
    }
    static func bpsk(ebN0DB: Double, count: Int = 128, seed: UInt64 = 23) -> BPSKRun? {
        guard ebN0DB.isFinite, (-20...40).contains(ebN0DB), (1...10_000).contains(count) else { return nil }
        let ratio = pow(10, ebN0DB / 10), sigma = sqrt(1 / (2 * ratio))
        var random = SeededRandom(seed: seed)
        let symbols = (0..<count).map { _ -> BPSKSymbol in
            let bit = random.uniform() >= 0.5 ? 1 : 0
            let (normalI, normalQ) = random.gaussianPair()
            let inPhase = (bit == 1 ? 1.0 : -1.0) + sigma * normalI
            return BPSKSymbol(bit: bit, inPhase: inPhase, quadrature: sigma * normalQ, decoded: inPhase >= 0 ? 1 : 0)
        }
        return BPSKRun(symbols: symbols, theoreticalBER: 0.5 * erfc(sqrt(ratio)))
    }

    static func capacity(bandwidth: Double, snrDB: Double) -> Double? {
        guard bandwidth.isFinite, bandwidth >= 0, snrDB.isFinite, (-100...100).contains(snrDB) else { return nil }
        let capacity = bandwidth * log2(1 + pow(10, snrDB / 10))
        return capacity.isFinite ? capacity : nil
    }
    static func hammingEncode(_ data: Int) -> Int? {
        guard (0...15).contains(data) else { return nil }
        var word = 0
        for (index, position) in [3, 5, 6, 7].enumerated() {
            word |= ((data >> (3 - index)) & 1) << (position - 1)
        }
        for parityPosition in [1, 2, 4] {
            var parity = 0
            for position in 1...7 where position & parityPosition != 0 { parity ^= (word >> (position - 1)) & 1 }
            word |= parity << (parityPosition - 1)
        }
        return word
    }
    struct HammingDecode { let syndrome: Int; let correctedWord: Int; let data: Int }
    static func hammingDecode(_ received: Int) -> HammingDecode? {
        guard (0...127).contains(received) else { return nil }
        var syndrome = 0
        for position in 1...7 where received & (1 << (position - 1)) != 0 { syndrome ^= position }
        let corrected = syndrome == 0 ? received : received ^ (1 << (syndrome - 1))
        var data = 0
        for position in [3, 5, 6, 7] { data = (data << 1) | ((corrected >> (position - 1)) & 1) }
        return HammingDecode(syndrome: syndrome, correctedWord: corrected, data: data)
    }

    struct Packet {
        let arrival: Double
        let start: Double
        let finish: Double
        let delivery: Double
        let lost: Bool
        var queueDelay: Double { start - arrival }
        var totalDelay: Double { delivery - arrival }
    }
    struct NetworkRun {
        let arrivals: Int
        let overflow: Int
        let packets: [Packet]
        let queue: [Double]
        let duration: Double
        let transmissionDelay: Double
        let propagationDelay: Double
        let offeredLoad: Double
        var linkLoss: Int { packets.filter(\.lost).count }
        var delivered: Int { packets.count - linkLoss }
        var averageQueueDelay: Double { packets.isEmpty ? 0 : packets.map(\.queueDelay).reduce(0, +) / Double(packets.count) }
        var averageDeliveryDelay: Double {
            let delivered = packets.filter { !$0.lost }
            return delivered.isEmpty ? 0 : delivered.map(\.totalDelay).reduce(0, +) / Double(delivered.count)
        }
    }
    /// Deterministic periodic arrivals into a finite FIFO; capacity includes the packet in service.
    /// All accepted packets finish service, then may be independently erased. No retransmissions.
    static func network(arrivalRate: Double, payloadBytes: Int, bitRate: Double, distance: Double, capacity: Int, lossProbability: Double, seed: UInt64 = 71) -> NetworkRun? {
        guard [arrivalRate, bitRate, distance, lossProbability].allSatisfy(\.isFinite), (1...1_000).contains(arrivalRate),
              (1...10_000).contains(payloadBytes), (1_000...100_000_000).contains(bitRate), (0...10_000_000).contains(distance),
              (1...100).contains(capacity), (0...1).contains(lossProbability) else { return nil }
        let transmission = Double(payloadBytes * 8) / bitRate, propagation = distance / 200_000_000
        var random = SeededRandom(seed: seed), packets: [Packet] = [], activeFinishes: [Double] = []
        var overflow = 0, lastFinish = 0.0, arrivalCount = 0
        for index in 0..<Int(ceil(arrivalRate)) {
            let arrival = Double(index) / arrivalRate
            guard arrival < 1 else { break }
            arrivalCount += 1
            activeFinishes.removeAll { $0 <= arrival + 1e-12 }
            if activeFinishes.count >= capacity { overflow += 1; continue }
            let start = max(arrival, lastFinish), finish = start + transmission
            packets.append(Packet(arrival: arrival, start: start, finish: finish, delivery: finish + propagation, lost: random.uniform() < lossProbability))
            activeFinishes.append(finish); lastFinish = finish
        }
        let duration = max(1, lastFinish + propagation)
        let queue = (0...400).map { index -> Double in
            let time = Double(index) / 400 * duration
            return Double(packets.filter { $0.arrival <= time && $0.finish > time }.count)
        }
        return NetworkRun(arrivals: arrivalCount, overflow: overflow, packets: packets, queue: queue, duration: duration,
                          transmissionDelay: transmission, propagationDelay: propagation, offeredLoad: arrivalRate * transmission)
    }

    private struct SeededRandom {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func uniform() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return (Double(state >> 11) + 0.5) / 9_007_199_254_740_992
        }
        mutating func gaussianPair() -> (Double, Double) {
            let radius = sqrt(-2 * log(uniform())), angle = 2 * .pi * uniform()
            return (radius * cos(angle), radius * sin(angle))
        }
    }
}
