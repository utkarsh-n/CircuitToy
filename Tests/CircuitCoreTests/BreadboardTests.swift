import Foundation
import Testing
@testable import CircuitCore

private func hole(_ column: BreadboardColumn, _ row: Int) -> BreadboardHole { .init(row: row - 1, column: column) }
private func approximately(_ actual: Double?, _ expected: Double, tolerance: Double = 1e-10) -> Bool {
    guard let actual else { return false }
    return abs(actual - expected) <= tolerance * max(1, abs(expected))
}

@Test func breadboardLayoutHasDistinctRowStripsAndFourContinuousRails() throws {
    let topology = try BreadboardTopology(document: .empty())
    #expect(BreadboardHole.all.count == 168)
    #expect(Set(BreadboardHole.all.map(\.id)).count == 168)
    #expect(BreadboardColumn.allCases.map(\.rawValue) == Array(0..<14))
    #expect(hole(.a, 1).label == "A1")
    #expect(topology.nodes.count == 28)
    #expect(topology.connectedHoles(to: hole(.c, 2)).count == 5)
    #expect(topology.node(for: hole(.a, 2)) == topology.node(for: hole(.e, 2)))
    #expect(topology.node(for: hole(.a, 2)) != topology.node(for: hole(.a, 1)))
    #expect(topology.node(for: hole(.e, 2)) != topology.node(for: hole(.f, 2)))
    #expect(topology.node(for: hole(.f, 2)) == topology.node(for: hole(.j, 2)))
    for column in BreadboardColumn.allCases where column.isRail {
        #expect(topology.connectedHoles(to: hole(column, 1)).count == 12)
        #expect(topology.node(for: hole(column, 1)) == topology.node(for: hole(column, 12)))
    }
    #expect(Set([BreadboardColumn.leftPositive, .leftNegative, .rightPositive, .rightNegative]
        .compactMap { topology.node(for: hole($0, 1)) }).count == 4)
    #expect(topology.node(for: hole(.leftNegative, 12)) == 0)
}

@Test func breadboardExplicitJumperJoinsAcrossChannelAndRemovalDisconnects() throws {
    var document = BreadboardDocument.empty()
    let a = hole(.d, 3), b = hole(.f, 3)
    document.wires = [.init(id: "W", a: a, b: b)]
    let joined = try BreadboardTopology(document: document)
    #expect(joined.node(for: hole(.a, 3)) == joined.node(for: hole(.j, 3)))
    #expect(joined.connectedHoles(to: a).count == 10)
    document.wires.removeAll()
    let removed = try BreadboardTopology(document: document)
    #expect(removed.node(for: a) != removed.node(for: b))
}

@Test func breadboardGroundIsExplicitAndComponentDoesNotMergeNets() throws {
    var document = BreadboardDocument.empty()
    document.ground = hole(.c, 2)
    document.components = [.init(id: "R", kind: .resistor, pins: [hole(.a, 2), hole(.a, 3)], value: 1_000)]
    let topology = try BreadboardTopology(document: document)
    #expect(topology.node(for: hole(.e, 2)) == 0)
    #expect(topology.node(for: hole(.leftNegative, 1)) != 0)
    #expect(topology.node(for: hole(.a, 2)) != topology.node(for: hole(.a, 3)))
}

@Test func breadboardDividerUsesExistingMNAAndConservesPower() throws {
    let document = BreadboardDocument.divider
    let topology = try BreadboardTopology(document: document)
    let circuit = try document.makeCircuit()
    let solution = try CircuitSolver.solveDC(circuit)
    #expect(approximately(solution.voltage(at: topology.node(for: hole(.d, 3))!), 2.5))
    #expect(approximately(solution.current(through: "R1"), 0.0025))
    #expect(approximately(solution.current(through: "R2"), 0.0025))
    #expect(approximately(solution.current(through: "V1"), -0.0025))
    #expect(solution.maximumKCLResidual < 1e-12)
    #expect(abs(solution.powerBalance) < 1e-12)
    #expect(solution.current(through: "W1") == nil)
    #expect(solution.voltage(at: topology.node(for: hole(.f, 12))!) == nil)
}

@Test func breadboardArbitraryUserDividerAndNewJumperProbeProduceAnalyticVoltage() throws {
    var document = BreadboardDocument(mode: .analog, components: [
        .init(id: "V", kind: .voltageSource, pins: [hole(.a, 1), hole(.a, 2)], value: 5),
        .init(id: "R1", kind: .resistor, pins: [hole(.b, 1), hole(.a, 3)], value: 1_000),
        .init(id: "R2", kind: .resistor, pins: [hole(.b, 3), hole(.b, 2)], value: 1_000)
    ], ground: hole(.c, 2))
    document.wires.append(.init(id: "W", a: hole(.d, 3), b: hole(.f, 3)))
    let topology = try BreadboardTopology(document: document)
    let solution = try CircuitSolver.solveDC(document.makeCircuit())
    #expect(approximately(solution.voltage(at: topology.node(for: hole(.g, 3))!), 2.5))
    #expect(approximately(solution.current(through: "R1"), 0.0025))
}

@Test func breadboardEditingResistanceAndPinOrderChangesRealBranchCurrent() throws {
    var document = BreadboardDocument.divider
    document.components[1].value = 2_000
    let topology = try BreadboardTopology(document: document)
    let first = try CircuitSolver.solveDC(document.makeCircuit())
    #expect(approximately(first.voltage(at: topology.node(for: hole(.a, 3))!), 5 / 3))
    #expect(approximately(first.current(through: "R1"), 5 / 3_000))
    document.components[1].pins.reverse()
    let reversed = try CircuitSolver.solveDC(document.makeCircuit())
    #expect(approximately(reversed.current(through: "R1"), -5 / 3_000))
    #expect(approximately(reversed.branchPowers["R1"], first.branchPowers["R1"]!))
}

@Test func breadboardShortedIdealSourceReportsContradiction() throws {
    var document = BreadboardDocument.divider
    document.wires.append(.init(id: "Short", a: hole(.a, 1), b: document.ground))
    #expect(throws: CircuitError.inconsistentCircuit) { try CircuitSolver.solveDC(document.makeCircuit()) }
}

@Test func breadboardFloatingNetworkHasNoFabricatedReference() throws {
    var document = BreadboardDocument.divider
    document.ground = hole(.f, 12)
    do {
        _ = try CircuitSolver.solveDC(document.makeCircuit())
        Issue.record("Expected floating-node diagnosis")
    } catch let CircuitError.floatingNodes(nodes) {
        #expect(!nodes.isEmpty)
    }
}

@Test func breadboardRedundantIdealSourcesRemainSingular() throws {
    var document = BreadboardDocument.divider
    document.components.append(.init(id: "V2", kind: .voltageSource, pins: [hole(.b, 1), hole(.leftNegative, 2)], value: 5))
    #expect(throws: CircuitError.singularCircuit) { try CircuitSolver.solveDC(document.makeCircuit()) }
}

@Test func breadboardCapacitorReusesFiniteStepBackwardEulerRatherThanAnalyticShortcut() throws {
    let document = BreadboardDocument.rc
    let topology = try BreadboardTopology(document: document)
    var simulator = try TransientSimulator(circuit: document.makeCircuit())
    #expect(simulator.capacitorVoltages["C1"] == 0)
    for step in 1...20 {
        let solution = try simulator.step(timeStep: 0.05)
        let expected = 5 * (1 - pow(1.05, -Double(step)))
        #expect(approximately(solution.voltage(at: topology.node(for: hole(.e, 3))!), expected))
        #expect(solution.maximumKCLResidual < 1e-12)
        #expect(abs(solution.powerBalance) < 1e-12)
    }
    #expect(approximately(simulator.time, 1))
    let dc = try CircuitSolver.solveDC(document.makeCircuit())
    #expect(approximately(dc.voltage(at: topology.node(for: hole(.a, 3))!), 5))
    #expect(dc.current(through: "C1") == 0)
}

@Test func breadboardInductorReusesInitialCurrentAndLessonIntegrator() throws {
    var document = BreadboardDocument.rc
    document.components[1].value = 100
    document.components[2] = .init(id: "L1", kind: .inductor, pins: document.components[2].pins, value: 1, initialValue: 0)
    var simulator = try TransientSimulator(circuit: document.makeCircuit())
    for step in 1...10 {
        let solution = try simulator.step(timeStep: 0.001)
        #expect(approximately(solution.current(through: "L1"), 0.05 * (1 - pow(1.1, -Double(step)))))
    }
}

@Test func breadboardCurrentSourcePolarityUsesExistingCoreConvention() throws {
    let document = BreadboardDocument(components: [
        .init(id: "I", kind: .currentSource, pins: [hole(.leftNegative, 1), hole(.a, 1)], value: 0.002),
        .init(id: "R", kind: .resistor, pins: [hole(.a, 1), hole(.leftNegative, 2)], value: 1_000)
    ])
    let topology = try BreadboardTopology(document: document)
    let solution = try CircuitSolver.solveDC(document.makeCircuit())
    #expect(approximately(solution.voltage(at: topology.node(for: hole(.c, 1))!), 2))
    #expect(approximately(solution.current(through: "I"), 0.002))
}

@Test func breadboardLogicInputChangesEvaluateAllGateTruthTables() throws {
    for kind in BreadboardComponentKind.allCases where kind.gate != nil {
        for a in [LogicLevel.zero, .one, .unknown, .highImpedance] {
            for b in [LogicLevel.zero, .one, .unknown, .highImpedance] {
                var document = BreadboardDocument.andGate
                document.components[0].logicValue = a
                document.components[1].logicValue = b
                document.components[2].kind = kind
                if kind == .not { document.components[2].pins.remove(at: 1) }
                let result = try document.solveLogic()
                let expected = try kind.gate!.evaluate(kind == .not ? [a] : [a, b])
                #expect(result.logic(at: hole(.g, 5)) == expected)
                #expect(result.componentOutputs["G1"] == expected)
            }
        }
    }
}

@Test func breadboardUndrivenLogicNetsAreZAndFloatingGateInputsAreX() throws {
    var document = BreadboardDocument.empty(mode: .logic)
    #expect(try document.solveLogic().logic(at: hole(.a, 1)) == .highImpedance)
    document.components = [.init(id: "G", kind: .not, pins: [hole(.a, 1), hole(.f, 1)], value: 0)]
    let result = try document.solveLogic()
    #expect(result.logic(at: hole(.b, 1)) == .highImpedance)
    #expect(result.logic(at: hole(.g, 1)) == .unknown)
    #expect(result.logic(at: document.ground) == .highImpedance)
}

@Test func breadboardLogicDriverResolutionDetectsConflictAndIgnoresZ() throws {
    var document = BreadboardDocument(mode: .logic, components: [
        .init(id: "A", kind: .logicInput, pins: [hole(.a, 1)], value: 0, logicValue: .zero),
        .init(id: "B", kind: .logicInput, pins: [hole(.b, 1)], value: 0, logicValue: .one)
    ])
    let conflict = try document.solveLogic()
    #expect(conflict.logic(at: hole(.c, 1)) == .unknown)
    #expect(conflict.diagnostics.contains { $0.kind == .conflictingDrivers && $0.componentIDs == ["A", "B"] })
    document.components[1].logicValue = .highImpedance
    #expect(try document.solveLogic().logic(at: hole(.c, 1)) == .zero)
    document.components[0].logicValue = .highImpedance
    #expect(try document.solveLogic().logic(at: hole(.c, 1)) == .highImpedance)
}

@Test func breadboardLogicFanoutAndReorderedComponentsAreIdentical() throws {
    var document = BreadboardDocument(mode: .logic, components: [
        .init(id: "G2", kind: .not, pins: [hole(.b, 1), hole(.a, 3)], value: 0),
        .init(id: "A", kind: .logicInput, pins: [hole(.a, 1)], value: 0, logicValue: .one),
        .init(id: "G1", kind: .not, pins: [hole(.c, 1), hole(.a, 2)], value: 0)
    ])
    let first = try document.solveLogic()
    #expect(first.logic(at: hole(.b, 2)) == .zero)
    #expect(first.logic(at: hole(.b, 3)) == .zero)
    document.components.reverse()
    let second = try document.solveLogic()
    #expect(first.netValues == second.netValues)
    #expect(first.componentOutputs == second.componentOutputs)
}

@Test func breadboardFeedbackCyclesAreConservativelyXWithDiagnostics() throws {
    let selfLoop = BreadboardDocument(mode: .logic, components: [
        .init(id: "G", kind: .not, pins: [hole(.a, 1), hole(.b, 1)], value: 0)
    ])
    let selfResult = try selfLoop.solveLogic()
    #expect(selfResult.logic(at: hole(.c, 1)) == .unknown)
    #expect(selfResult.diagnostics.contains { $0.kind == .feedback && $0.componentIDs == ["G"] })
    let loop = BreadboardDocument(mode: .logic, components: [
        .init(id: "G1", kind: .not, pins: [hole(.a, 1), hole(.a, 2)], value: 0),
        .init(id: "G2", kind: .not, pins: [hole(.b, 2), hole(.b, 1)], value: 0),
        .init(id: "G3", kind: .not, pins: [hole(.c, 2), hole(.a, 3)], value: 0)
    ])
    let result = try loop.solveLogic()
    #expect(result.componentOutputs.values.allSatisfy { $0 == .unknown })
    #expect(result.diagnostics.contains { $0.kind == .feedback && $0.componentIDs == ["G1", "G2"] })
}

@Test func breadboardEditingJumperCreatesAndRemovesLogicContention() throws {
    var document = BreadboardDocument.andGate
    #expect(try document.solveLogic().logic(at: hole(.f, 5)) == .zero)
    document.wires.append(.init(id: "W", a: hole(.b, 1), b: hole(.b, 3)))
    #expect(try document.solveLogic().logic(at: hole(.f, 5)) == .unknown)
    document.wires.removeAll()
    #expect(try document.solveLogic().logic(at: hole(.f, 5)) == .zero)
}

@Test func breadboardRejectsWrongModeMalformedPinsAndInvalidHoles() {
    var analog = BreadboardDocument.divider
    analog.components[0].kind = .logicInput
    #expect(throws: BreadboardError.incompatibleComponent(id: "V1", mode: .analog)) { try analog.validate() }
    var badPins = BreadboardDocument.divider
    badPins.components[0].pins.removeLast()
    #expect(throws: BreadboardError.invalidPins(id: "V1", expected: 2, actual: 1)) { try badPins.validate() }
    badPins.components[0].pins = [hole(.a, 1), hole(.a, 1)]
    #expect(throws: BreadboardError.repeatedPin("V1")) { try badPins.validate() }
    var invalid = BreadboardDocument.empty()
    invalid.ground = .init(row: -1, column: .a)
    #expect(throws: BreadboardError.invalidHole(invalid.ground)) { try invalid.validate() }
    invalid.ground = hole(.a, 1)
    invalid.wires = [.init(id: "W", a: hole(.a, 1), b: .init(row: 12, column: .b))]
    #expect(throws: BreadboardError.invalidHole(invalid.wires[0].b)) { try invalid.validate() }
    #expect(throws: BreadboardError.incompatibleAnalysis(.analog)) { try BreadboardDocument.andGate.makeCircuit() }
    #expect(throws: BreadboardError.incompatibleAnalysis(.logic)) { try BreadboardDocument.divider.solveLogic() }
}

@Test func breadboardRejectsDuplicateIDsAcrossComponentsAndWiresAndBoardLimits() {
    var document = BreadboardDocument.divider
    document.wires[0].id = "R1"
    #expect(throws: BreadboardError.duplicateIdentifier("R1")) { try document.validate() }
    document.wires[0].id = " "
    #expect(throws: BreadboardError.emptyIdentifier) { try document.validate() }
    document = .empty()
    document.components = (0..<33).map { .init(id: "R\($0)", kind: .resistor, pins: [hole(.a, 1), hole(.a, 2)], value: 1_000) }
    #expect(throws: BreadboardError.tooManyComponents) { try document.validate() }
    document.components.removeAll()
    document.wires = (0..<65).map { .init(id: "W\($0)", a: hole(.a, 1), b: hole(.b, 1)) }
    #expect(throws: BreadboardError.tooManyWires) { try document.validate() }
}

@Test func breadboardConstitutiveValueValidationUsesExistingRules() {
    for kind in [BreadboardComponentKind.resistor, .capacitor, .inductor] {
        for invalid in [0.0, -1, .nan, .infinity] {
            let document = BreadboardDocument(components: [.init(id: "E", kind: kind, pins: [hole(.a, 1), hole(.a, 2)], value: invalid)])
            #expect(throws: CircuitError.self) { try document.validate() }
        }
    }
    for kind in [BreadboardComponentKind.voltageSource, .currentSource] {
        let document = BreadboardDocument(components: [.init(id: "E", kind: kind, pins: [hole(.a, 1), hole(.a, 2)], value: .nan)])
        #expect(throws: CircuitError.self) { try document.validate() }
    }
    #expect(throws: CircuitError.emptyCircuit) { try BreadboardDocument.empty().makeCircuit() }
}

@Test func breadboardCodableRoundTripPreservesPinsWiresReferenceAndLogicState() throws {
    for document in [BreadboardDocument.divider, .rc, .andGate, .empty(mode: .logic)] {
        let data = try JSONEncoder().encode(document)
        let decoded = try JSONDecoder().decode(BreadboardDocument.self, from: data)
        #expect(decoded == document)
    }
    var malformed = BreadboardDocument.divider
    malformed.components[1].value = -5
    let invalidData = try JSONEncoder().encode(malformed)
    #expect(throws: CircuitError.self) { try JSONDecoder().decode(BreadboardDocument.self, from: invalidData) }
    malformed = .divider
    malformed.components[0].pins = []
    let missingPins = try JSONEncoder().encode(malformed)
    #expect(throws: BreadboardError.invalidPins(id: "V1", expected: 2, actual: 0)) {
        try JSONDecoder().decode(BreadboardDocument.self, from: missingPins)
    }
}

@Test func breadboardExtremeMalformedRowsAreDiagnosedAndRejectedWithoutOverflow() throws {
    for row in [Int.min, Int.max] {
        let invalidHole = BreadboardHole(row: row, column: .a)
        let expected = BreadboardError.invalidHole(invalidHole)
        #expect(expected.localizedDescription.contains("outside this 12-row breadboard"))
        var document = BreadboardDocument.empty()
        document.ground = invalidHole
        #expect(throws: expected) { try document.validate() }
        let data = try JSONEncoder().encode(document)
        #expect(throws: expected) { try JSONDecoder().decode(BreadboardDocument.self, from: data) }
    }
}
