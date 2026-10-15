import Testing
@testable import CircuitCore

@Test func exhaustiveBooleanGateTruthTables() throws {
    for a in [false, true] {
        for b in [false, true] {
            let inputs = [LogicLevel(a), LogicLevel(b)]
            #expect(try LogicGate.and.evaluate(inputs) == LogicLevel(a && b))
            #expect(try LogicGate.or.evaluate(inputs) == LogicLevel(a || b))
            #expect(try LogicGate.nand.evaluate(inputs) == LogicLevel(!(a && b)))
            #expect(try LogicGate.nor.evaluate(inputs) == LogicLevel(!(a || b)))
            #expect(try LogicGate.xor.evaluate(inputs) == LogicLevel(a != b))
            #expect(try LogicGate.xnor.evaluate(inputs) == LogicLevel(a == b))
        }
        #expect(try LogicGate.not.evaluate([LogicLevel(a)]) == LogicLevel(!a))
    }
}

@Test func controllingLogicValuesResolveUncertainty() throws {
    for uncertain in [LogicLevel.unknown, .highImpedance] {
        #expect(try LogicGate.and.evaluate([.zero, uncertain]) == .zero)
        #expect(try LogicGate.or.evaluate([.one, uncertain]) == .one)
        #expect(try LogicGate.and.evaluate([.one, uncertain]) == .unknown)
        #expect(try LogicGate.or.evaluate([.zero, uncertain]) == .unknown)
        #expect(try LogicGate.xor.evaluate([.zero, uncertain]) == .unknown)
        #expect(try LogicGate.not.evaluate([uncertain]) == .unknown)
    }
}

@Test func gateRejectsWrongArity() {
    #expect(throws: LogicError.wrongInputCount(gate: .and, expected: 2, actual: 1)) {
        try LogicGate.and.evaluate([.one])
    }
    #expect(throws: LogicError.wrongInputCount(gate: .not, expected: 1, actual: 2)) {
        try LogicGate.not.evaluate([.one, .zero])
    }
}

@Test func driverResolutionPreservesHighImpedanceAndShowsConflicts() {
    #expect(LogicLevel.resolve(drivers: []) == .highImpedance)
    #expect(LogicLevel.resolve(drivers: [.highImpedance, .highImpedance]) == .highImpedance)
    #expect(LogicLevel.resolve(drivers: [.one, .highImpedance, .one]) == .one)
    #expect(LogicLevel.resolve(drivers: [.zero, .one]) == .unknown)
    #expect(LogicLevel.resolve(drivers: [.unknown, .zero]) == .unknown)
}

@Test func halfAndFullAddersExhaustiveArithmetic() {
    for a in 0...1 {
        for b in 0...1 {
            let half = HalfAdder.output(a: LogicLevel(a == 1), b: LogicLevel(b == 1))
            #expect(half.sum.integerValue == (a + b) % 2)
            #expect(half.carry.integerValue == (a + b) / 2)
            for carry in 0...1 {
                let full = FullAdder.output(a: LogicLevel(a == 1), b: LogicLevel(b == 1), carryIn: LogicLevel(carry == 1))
                #expect(full.sum.integerValue == (a + b + carry) % 2)
                #expect(full.carry.integerValue == (a + b + carry) / 2)
            }
        }
    }
}

@Test func rippleAdderEveryFourBitPairAndCarry() throws {
    for a: UInt64 in 0...15 {
        for b: UInt64 in 0...15 {
            for carry: UInt64 in 0...1 {
                let result = try RippleAdder.add(a: a, b: b, width: 4, carryIn: LogicLevel(carry == 1))
                let expected = a + b + carry
                #expect(result.unsignedValue == expected % 16)
                #expect(result.carryOut == LogicLevel(expected >= 16))
                #expect(result.carries.count == 5)
            }
        }
    }
}

@Test func rippleAdderCarriesUnknownsAndSupports64BitOverflow() throws {
    let uncertain = try RippleAdder.add(a: [.unknown, .zero], b: [.zero, .zero])
    #expect(uncertain.bits == [.unknown, .zero])
    #expect(uncertain.unsignedValue == nil)
    let overflow = try RippleAdder.add(a: UInt64.max, b: 1, width: 64)
    #expect(overflow.unsignedValue == 0)
    #expect(overflow.carryOut == .one)
}

@Test func rippleAdderRejectsWidthAndValueErrors() {
    #expect(throws: LogicError.invalidBitWidth) { try RippleAdder.add(a: 1, b: 1, width: 0) }
    #expect(throws: LogicError.invalidBitWidth) { try RippleAdder.add(a: 1, b: 1, width: 65) }
    #expect(throws: LogicError.valueExceedsBitWidth) { try RippleAdder.add(a: 16, b: 1, width: 4) }
    #expect(throws: LogicError.mismatchedBitWidths) { try RippleAdder.add(a: [.zero], b: [.zero, .one]) }
}

@Test func flipFlopCapturesOnlyRisingEdgeAndHoldsBetweenEdges() {
    var flipFlop = DFlipFlop(initialQ: .zero)
    #expect(flipFlop.tick(data: .one, clock: .zero) == .zero)
    #expect(flipFlop.tick(data: .one, clock: .one) == .one)
    #expect(flipFlop.tick(data: .zero, clock: .one) == .one)
    #expect(flipFlop.tick(data: .zero, clock: .zero) == .one)
    #expect(flipFlop.tick(data: .zero, clock: .one) == .zero)
}

@Test func flipFlopReportsLogicalUncertaintyOnAmbiguousClock() {
    var flipFlop = DFlipFlop(initialQ: .zero)
    #expect(flipFlop.tick(data: .one, clock: .unknown) == .unknown)
    #expect(flipFlop.tick(data: .one, clock: .one) == .unknown)
    #expect(flipFlop.tick(data: .zero, clock: .zero) == .unknown)
    #expect(flipFlop.tick(data: .highImpedance, clock: .one) == .unknown)
    var stable = DFlipFlop(initialQ: .one)
    #expect(stable.tick(data: .one, clock: .unknown) == .one)
}
