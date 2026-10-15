import Foundation

/// Four-state digital abstraction. X is unknown; Z means an undriven/high-impedance wire.
public enum LogicLevel: String, CaseIterable, Sendable, Codable {
    case zero = "0"
    case one = "1"
    case unknown = "X"
    case highImpedance = "Z"

    public init(_ value: Bool) { self = value ? .one : .zero }
    public var boolValue: Bool? {
        switch self { case .zero: false; case .one: true; case .unknown, .highImpedance: nil }
    }
    public var integerValue: Int? { boolValue.map { $0 ? 1 : 0 } }

    /// Equal-strength ideal drivers: an empty/all-Z set is Z; conflicts and X resolve to X.
    public static func resolve(drivers: [LogicLevel]) -> LogicLevel {
        let active = drivers.filter { $0 != .highImpedance }
        guard let first = active.first else { return .highImpedance }
        guard first != .unknown, active.allSatisfy({ $0 == first }) else { return .unknown }
        return first
    }

    fileprivate var asGateInput: LogicLevel { self == .highImpedance ? .unknown : self }
    fileprivate var inverted: LogicLevel {
        switch self { case .zero: .one; case .one: .zero; case .unknown, .highImpedance: .unknown }
    }
}

public enum LogicError: Error, Equatable, Sendable, LocalizedError {
    case wrongInputCount(gate: LogicGate, expected: Int, actual: Int)
    case mismatchedBitWidths
    case invalidBitWidth
    case valueExceedsBitWidth

    public var errorDescription: String? {
        switch self {
        case let .wrongInputCount(gate, expected, actual): "\(gate.rawValue) requires \(expected) input\(expected == 1 ? "" : "s"); received \(actual)."
        case .mismatchedBitWidths: "Both binary words must have the same width."
        case .invalidBitWidth: "Use a binary word width from 1 to 64 bits."
        case .valueExceedsBitWidth: "The value does not fit in the selected bit width."
        }
    }
}

public enum LogicGate: String, CaseIterable, Sendable, Codable {
    case and = "AND", or = "OR", not = "NOT", nand = "NAND", nor = "NOR", xor = "XOR", xnor = "XNOR"
    public var inputCount: Int { self == .not ? 1 : 2 }

    public func evaluate(_ inputs: [LogicLevel]) throws -> LogicLevel {
        guard inputs.count == inputCount else {
            throw LogicError.wrongInputCount(gate: self, expected: inputCount, actual: inputs.count)
        }
        if self == .not { return inputs[0].inverted }
        let a = inputs[0].asGateInput, b = inputs[1].asGateInput
        switch self {
        case .and: return Self.and(a, b)
        case .or: return Self.or(a, b)
        case .nand: return Self.and(a, b).inverted
        case .nor: return Self.or(a, b).inverted
        case .xor: return Self.xor(a, b)
        case .xnor: return Self.xor(a, b).inverted
        case .not: return a.inverted
        }
    }

    fileprivate static func and(_ a: LogicLevel, _ b: LogicLevel) -> LogicLevel {
        if a == .zero || b == .zero { return .zero }
        if a == .one && b == .one { return .one }
        return .unknown
    }

    fileprivate static func or(_ a: LogicLevel, _ b: LogicLevel) -> LogicLevel {
        if a == .one || b == .one { return .one }
        if a == .zero && b == .zero { return .zero }
        return .unknown
    }

    fileprivate static func xor(_ a: LogicLevel, _ b: LogicLevel) -> LogicLevel {
        guard let av = a.boolValue, let bv = b.boolValue else { return .unknown }
        return LogicLevel(av != bv)
    }
}

public struct AdderResult: Equatable, Sendable {
    public let sum: LogicLevel
    public let carry: LogicLevel
}

public enum HalfAdder {
    public static func output(a: LogicLevel, b: LogicLevel) -> AdderResult {
        AdderResult(sum: LogicGate.xor(a, b), carry: LogicGate.and(a, b))
    }
}

public enum FullAdder {
    public static func output(a: LogicLevel, b: LogicLevel, carryIn: LogicLevel) -> AdderResult {
        let first = HalfAdder.output(a: a, b: b)
        let second = HalfAdder.output(a: first.sum, b: carryIn)
        return AdderResult(sum: second.sum, carry: LogicGate.or(first.carry, second.carry))
    }
}

public struct RippleAdderResult: Equatable, Sendable {
    /// Least-significant bit first, matching the physical carry chain.
    public let bits: [LogicLevel]
    public let carryOut: LogicLevel
    /// Carry entering each bit, followed by carry out. Count = bits.count + 1.
    public let carries: [LogicLevel]

    public var unsignedValue: UInt64? {
        var value: UInt64 = 0
        for (position, bit) in bits.enumerated() {
            guard let boolean = bit.boolValue else { return nil }
            if boolean { value |= UInt64(1) << position }
        }
        return value
    }
}

public enum RippleAdder {
    public static func add(a: [LogicLevel], b: [LogicLevel], carryIn: LogicLevel = .zero) throws -> RippleAdderResult {
        guard a.count == b.count else { throw LogicError.mismatchedBitWidths }
        guard (1...64).contains(a.count) else { throw LogicError.invalidBitWidth }
        var carry = carryIn
        var sums: [LogicLevel] = []
        var carries = [carryIn]
        for index in a.indices {
            let result = FullAdder.output(a: a[index], b: b[index], carryIn: carry)
            sums.append(result.sum); carry = result.carry; carries.append(carry)
        }
        return RippleAdderResult(bits: sums, carryOut: carry, carries: carries)
    }

    public static func add(a: UInt64, b: UInt64, width: Int, carryIn: LogicLevel = .zero) throws -> RippleAdderResult {
        try add(a: bits(of: a, width: width), b: bits(of: b, width: width), carryIn: carryIn)
    }

    public static func bits(of value: UInt64, width: Int) throws -> [LogicLevel] {
        guard (1...64).contains(width) else { throw LogicError.invalidBitWidth }
        if width < 64, value >= UInt64(1) << width { throw LogicError.valueExceedsBitWidth }
        return (0..<width).map { LogicLevel((value & (UInt64(1) << $0)) != 0) }
    }
}

/// Ideal positive-edge storage; Z data becomes X. A possible ambiguous rising edge joins
/// the held and captured states, yielding X if they differ. This is a logical uncertainty
/// policy, not a simulation of analog metastability or setup/hold timing.
public struct DFlipFlop: Equatable, Sendable {
    public private(set) var q: LogicLevel
    public private(set) var previousClock: LogicLevel

    public init(initialQ: LogicLevel = .unknown, initialClock: LogicLevel = .zero) {
        q = initialQ.asGateInput
        previousClock = initialClock
    }

    @discardableResult
    public mutating func tick(data: LogicLevel, clock: LogicLevel) -> LogicLevel {
        let sampled = data.asGateInput
        if previousClock == .zero, clock == .one {
            q = sampled
        } else {
            let previousUncertain = previousClock == .unknown || previousClock == .highImpedance
            let nextUncertain = clock == .unknown || clock == .highImpedance
            let possibleRising = (previousClock == .zero && nextUncertain)
                || (previousUncertain && clock == .one)
                || (previousUncertain && nextUncertain)
            if possibleRising, q != sampled { q = .unknown }
        }
        previousClock = clock
        return q
    }
}
