import Foundation

enum EngineeringModelError: Error, LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { message } else { nil } }
}

/// Deterministic teaching models. Electrical/mechanical quantities are SI; timing names specify ns.
enum EngineeringModels {
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw EngineeringModelError.invalid(message) }
    }

    struct Sequential: Equatable, Sendable {
        var register = 0
        var counter = 0
        var detectorState = 0
        var detected = false
        var clock = false
        var edges = 0
        /// Four-bit register, enabled modulo-16 counter, overlapping Mealy '101' detector.
        mutating func setClock(_ high: Bool, data: Int, enable: Bool, bit: Bool) {
            if !clock && high {
                register = data & 15
                if enable { counter = (counter + 1) & 15 }
                let transition = EngineeringModels.sequence101(state: detectorState, bit: bit)
                detectorState = transition.state
                detected = transition.detected
                edges += 1
            }
            clock = high
        }
    }

    static func sequence101(state: Int, bit: Bool) -> (state: Int, detected: Bool) {
        switch state {
        case 0: return (bit ? 1 : 0, false)
        case 1: return (bit ? 1 : 2, false)
        case 2: return (bit ? 1 : 0, bit)
        default: return (0, false)
        }
    }

    struct Timing: Equatable, Sendable {
        let setupMargin: Double
        let holdMargin: Double
        var passes: Bool { setupMargin >= 0 && holdMargin >= 0 }
    }

    /// Positive skew means the destination clock arrives later than the source clock.
    static func timing(periodNS: Double, clockToQMaxNS: Double, clockToQMinNS: Double,
                       logicMaxNS: Double, logicMinNS: Double, setupNS: Double,
                       holdNS: Double, skewNS: Double) throws -> Timing {
        let values = [periodNS, clockToQMaxNS, clockToQMinNS, logicMaxNS, logicMinNS, setupNS, holdNS, skewNS]
        try require(values.allSatisfy(\.isFinite), "Timing values must be finite.")
        try require(periodNS > 0 && clockToQMinNS >= 0 && clockToQMaxNS >= clockToQMinNS && logicMinNS >= 0 && logicMaxNS >= logicMinNS && setupNS >= 0 && holdNS >= 0, "Use positive clock period and ordered nonnegative minimum/maximum delays.")
        let setupMargin = periodNS + skewNS - clockToQMaxNS - logicMaxNS - setupNS
        let holdMargin = clockToQMinNS + logicMinNS - skewNS - holdNS
        try require(setupMargin.isFinite && holdMargin.isFinite, "Timing exceeds numerical range.")
        return Timing(setupMargin: setupMargin, holdMargin: holdMargin)
    }

    /// Transport-delay static-1 hazard: B=C=1, A rises, AB rises after riseDelay;
    /// !AC falls after fallDelay. The OR adds a fixed 0.2 ns transport delay.
    static func hazard(timeNS: Double, riseDelayNS: Double, fallDelayNS: Double, consensus: Bool) -> Double {
        if consensus { return 1 }
        let start = 2 + fallDelayNS + 0.2, end = 2 + riseDelayNS + 0.2
        return timeNS >= start && timeNS < end ? 0 : 1
    }

    struct Transformer: Sendable {
        let secondaryRMS: Double, primaryCurrentRMS: Double, secondaryCurrentRMS: Double
        let inputPower: Double, outputPower: Double, reflectedResistance: Double
    }
    static func transformer(primaryRMS: Double, primaryTurns: Double, secondaryTurns: Double, loadOhms: Double) throws -> Transformer {
        try require([primaryRMS, primaryTurns, secondaryTurns, loadOhms].allSatisfy(\.isFinite) && primaryRMS >= 0 && primaryTurns > 0 && secondaryTurns > 0 && loadOhms > 0, "Transformer turns/load must be positive and RMS voltage nonnegative.")
        let ratio = secondaryTurns / primaryTurns
        let voltage = primaryRMS * ratio, current = voltage / loadOhms
        let inputCurrent = ratio * current
        let inputPower = primaryRMS * inputCurrent, outputPower = voltage * current
        let reflectedResistance = loadOhms / (ratio * ratio)
        try require([ratio, voltage, current, inputCurrent, inputPower, outputPower, reflectedResistance].allSatisfy(\.isFinite) && ratio > 0 && reflectedResistance > 0, "Transformer exceeds numerical range.")
        return Transformer(secondaryRMS: voltage, primaryCurrentRMS: inputCurrent, secondaryCurrentRMS: current,
                           inputPower: inputPower, outputPower: outputPower,
                           reflectedResistance: reflectedResistance)
    }

    struct Motor: Sendable {
        let current: Double, speed: Double, backEMF: Double
        let inputPower: Double, mechanicalPower: Double, copperLoss: Double, stallTorque: Double
        var motoring: Bool { speed >= 0 }
        var efficiency: Double? { inputPower > 0 && motoring ? mechanicalPower / inputPower : nil }
    }
    /// Steady-state PM DC motor. SI torque/back-EMF constants share the same k by conservation.
    static func motor(volts: Double, resistance: Double, constant: Double, loadTorque: Double) throws -> Motor {
        try require([volts, resistance, constant, loadTorque].allSatisfy(\.isFinite) && volts >= 0 && resistance > 0 && constant > 0 && loadTorque >= 0, "Use nonnegative voltage/load and positive armature resistance/motor constant.")
        let current = loadTorque / constant
        let backEMF = volts - resistance * current, speed = backEMF / constant
        let inputPower = volts * current, mechanicalPower = loadTorque * speed
        let copperLoss = resistance * current * current, stallTorque = volts * constant / resistance
        try require([current, backEMF, speed, inputPower, mechanicalPower, copperLoss, stallTorque].allSatisfy(\.isFinite), "Motor exceeds numerical range.")
        return Motor(current: current, speed: speed, backEMF: backEMF, inputPower: inputPower,
                     mechanicalPower: mechanicalPower, copperLoss: copperLoss,
                     stallTorque: stallTorque)
    }

    struct Buck: Sendable {
        let output: Double, averageCurrent: Double, ripple: Double, minimumCurrent: Double, maximumCurrent: Double
        let inputCurrent: Double, inputPower: Double, outputPower: Double
        var continuousConduction: Bool { minimumCurrent > 0 }
        /// Normalized period [0,1]. Only physically valid for the stated CCM approximation.
        func current(at phase: Double, duty: Double) -> Double {
            let p = phase - floor(phase)
            return p < duty ? minimumCurrent + ripple * p / duty : maximumCurrent - ripple * (p - duty) / (1 - duty)
        }
    }
    /// Small output-ripple, ideal diode buck CCM candidate. DCM is flagged, never silently clamped.
    static func buck(input: Double, duty: Double, inductance: Double, frequency: Double, load: Double) throws -> Buck {
        try require([input, duty, inductance, frequency, load].allSatisfy(\.isFinite) && input > 0 && duty > 0 && duty < 1 && inductance > 0 && frequency > 0 && load > 0, "Buck requires positive V/L/f/R and duty strictly between zero and one.")
        let output = duty * input, average = output / load
        let ripple = (input - output) * duty / (inductance * frequency)
        let minimum = average - ripple / 2, maximum = average + ripple / 2
        let inputCurrent = duty * average, inputPower = input * duty * average, outputPower = output * average
        try require([output, average, ripple, minimum, maximum, inputCurrent, inputPower, outputPower].allSatisfy(\.isFinite) && ripple > 0 && output > 0, "Buck exceeds numerical range.")
        return Buck(output: output, averageCurrent: average, ripple: ripple, minimumCurrent: minimum,
                    maximumCurrent: maximum, inputCurrent: inputCurrent,
                    inputPower: inputPower, outputPower: outputPower)
    }

    struct ThreePhase: Sendable {
        let currentsRMS: [Double], neutralRMS: Double, averagePower: Double
    }
    /// Ideal balanced sinusoidal source, independent resistive wye loads, solid neutral (4 wire).
    static func threePhase(phaseRMS: Double, resistances: [Double]) throws -> ThreePhase {
        try require(phaseRMS.isFinite && phaseRMS >= 0 && resistances.count == 3 && resistances.allSatisfy { $0.isFinite && $0 > 0 }, "Three-phase model needs three positive resistances and nonnegative phase RMS voltage.")
        let currents = resistances.map { phaseRMS / $0 }
        let real = currents[0] - (currents[1] + currents[2]) / 2
        let imaginary = sqrt(3) * (currents[2] - currents[1]) / 2
        let neutral = hypot(real, imaginary), power = currents.reduce(0, +) * phaseRMS
        try require(currents.allSatisfy(\.isFinite) && neutral.isFinite && power.isFinite, "Three-phase values exceed numerical range.")
        return ThreePhase(currentsRMS: currents, neutralRMS: neutral, averagePower: power)
    }
    static func phaseVoltages(angle: Double, phaseRMS: Double) -> [Double] {
        (0..<3).map { sqrt(2) * phaseRMS * sin(angle - Double($0) * 2 * .pi / 3) }
    }

    enum Instruction: Equatable, Sendable {
        case loadA(Int), loadB(Int), add, and, storeA(Int), decrement, jumpNonzero(Int), halt
        var text: String {
            switch self {
            case .loadA(let address): "LDA [\(address)]"
            case .loadB(let address): "LDB [\(address)]"
            case .add: "ADD A,B"
            case .and: "AND A,B"
            case .storeA(let address): "STA [\(address)]"
            case .decrement: "DEC A"
            case .jumpNonzero(let address): "JNZ \(address)"
            case .halt: "HALT"
            }
        }
    }
    enum CPUPhase: String, Sendable { case fetch = "Fetch", decode = "Decode", execute = "Execute" }
    struct CPU: Equatable, Sendable {
        var a: UInt8 = 0, b: UInt8 = 0
        var pc = 0
        var instruction: Instruction?
        var phase = CPUPhase.fetch
        var memory: [UInt8]
        let program: [Instruction]
        var cycles = 0, instructionsExecuted = 0
        var carry = false, zero = true, halted = false
        var lastAction = "Ready to fetch the instruction at PC 0."
        init(inputA: UInt8, inputB: UInt8, mode: Int = 0) {
            memory = [inputA, inputB] + Array(repeating: 0, count: 14)
            if mode == 2 { program = [.loadA(0), .decrement, .storeA(2), .jumpNonzero(1), .halt] }
            else { program = [.loadA(0), .loadB(1), mode == 1 ? .and : .add, .storeA(2), .halt] }
        }
        mutating func step() throws {
            guard !halted else { return }
            switch phase {
            case .fetch:
                try EngineeringModels.require(program.indices.contains(pc), "PC is outside instruction memory.")
                instruction = program[pc]; pc += 1
                lastAction = "ROM → IR: \(instruction!.text); PC advances to \(pc)."
                phase = .decode
            case .decode:
                try EngineeringModels.require(instruction != nil, "No instruction to decode.")
                lastAction = "Decoder selects control signals for \(instruction!.text)."
                phase = .execute
            case .execute:
                guard let instruction else { throw EngineeringModelError.invalid("No decoded instruction.") }
                switch instruction {
                case .loadA(let address):
                    try checkAddress(address); a = memory[address]; zero = a == 0
                case .loadB(let address): try checkAddress(address); b = memory[address]
                case .add:
                    let full = Int(a) + Int(b); a = UInt8(full & 255); carry = full > 255; zero = a == 0
                case .and: a &= b; carry = false; zero = a == 0
                case .storeA(let address): try checkAddress(address); memory[address] = a
                case .decrement: a = a &- 1; zero = a == 0
                case .jumpNonzero(let address):
                    try EngineeringModels.require(program.indices.contains(address), "Branch target outside instruction memory.")
                    if !zero { pc = address }
                case .halt: halted = true
                }
                lastAction = "Execute \(instruction.text): A=\(a), B=\(b), Z=\(zero ? 1 : 0), C=\(carry ? 1 : 0)."
                instructionsExecuted += 1; phase = .fetch
            }
            cycles += 1
        }
        private func checkAddress(_ address: Int) throws {
            try EngineeringModels.require(memory.indices.contains(address), "Data address outside 16-byte RAM.")
        }
    }

    struct ADC: Sendable {
        let code: Int, levels: Int
        let lsb: Double, reconstructed: Double, error: Double
        let clipped: Bool
    }
    /// Mid-rise unipolar quantizer; reconstruction at bin center, not at lower bin edge.
    static func adc(input: Double, reference: Double, bits: Int) throws -> ADC {
        try require(input.isFinite && reference.isFinite && reference > 0 && (1...16).contains(bits), "ADC reference must be positive and resolution 1…16 bits.")
        let levels = 1 << bits, lsb = reference / Double(levels)
        try require(lsb.isFinite && lsb > 0, "ADC resolution exceeds numerical range.")
        let bounded = min(reference, max(0, input))
        let code = min(levels - 1, Int(floor(bounded / lsb)))
        let estimate = (Double(code) + 0.5) * lsb
        try require(estimate.isFinite && (estimate - input).isFinite, "ADC values exceed numerical range.")
        return ADC(code: code, levels: levels, lsb: lsb, reconstructed: estimate, error: estimate - input, clipped: input < 0 || input > reference)
    }
    struct InterruptJob: Identifiable, Sendable {
        let id: Int, release: Double, start: Double, finish: Double, deadline: Double
        var slack: Double { deadline - finish }
    }
    /// FIFO nonpreemptive handler, fixed per-job blocking and entry overhead; times in seconds.
    static func interrupts(period: Double, clockHz: Double, entryCycles: Double, handlerCycles: Double, blocking: Double, jobs: Int = 8) throws -> [InterruptJob] {
        try require([period, clockHz, entryCycles, handlerCycles, blocking].allSatisfy(\.isFinite) && period > 0 && clockHz > 0 && entryCycles >= 0 && handlerCycles >= 0 && blocking >= 0 && (1...64).contains(jobs), "Timer/clock must be positive; execution/blocking finite and nonnegative.")
        var finish = 0.0
        return try (0..<jobs).map { index in
            let release = Double(index) * period
            let start = max(release, finish) + blocking + entryCycles / clockHz
            finish = start + handlerCycles / clockHz
            try require([release, start, finish, release + period].allSatisfy(\.isFinite), "Interrupt schedule exceeds numerical range.")
            return InterruptJob(id: index, release: release, start: start, finish: finish, deadline: release + period)
        }
    }

    struct TrafficOutput: Equatable, Sendable { let aGreen: Bool, bGreen: Bool }
    static func trafficOutput(state: Int, injectedFault: Bool) -> TrafficOutput {
        TrafficOutput(aGreen: state == 0 || (injectedFault && state == 2), bGreen: state == 2)
    }
    static func trafficNext(state: Int, advance: Bool) -> Int { advance ? (state + 1) % 4 : state }
    /// Breadth-first exhaustive reachable-state check. Witness is a minimal input sequence.
    static func safetyWitness(injectedFault: Bool) -> [Bool]? {
        var pending: [(Int, [Bool])] = [(0, [])]
        var visited = Set<Int>()
        while !pending.isEmpty {
            let (state, inputs) = pending.removeFirst()
            if !visited.insert(state).inserted { continue }
            let output = trafficOutput(state: state, injectedFault: injectedFault)
            if output.aGreen && output.bGreen { return inputs }
            for input in [false, true] { pending.append((trafficNext(state: state, advance: input), inputs + [input])) }
        }
        return nil
    }
    /// alpha is the expected number of 0→1 transitions per cycle; excludes leakage/short-circuit.
    static func dynamicPower(capacitance: Double, volts: Double, frequency: Double, alpha: Double) throws -> Double {
        try require([capacitance, volts, frequency, alpha].allSatisfy(\.isFinite) && capacitance >= 0 && volts >= 0 && frequency >= 0 && (0...1).contains(alpha), "CMOS parameters must be nonnegative; rising-transition activity 0…1.")
        let result = alpha * capacitance * volts * volts * frequency
        try require(result.isFinite, "Power exceeds numerical range.")
        return result
    }
}
