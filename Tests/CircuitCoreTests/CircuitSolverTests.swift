import Foundation
import Testing
@testable import CircuitCore

private func close(_ actual: Double?, _ expected: Double, tolerance: Double = 1e-10) -> Bool {
    guard let actual else { return false }
    return abs(actual - expected) <= tolerance * max(1, abs(expected))
}

@Test func dividerObeysOhmKirchhoffAndPowerLaws() throws {
    let solution = try CircuitSolver.solveDC(CircuitPresets.voltageDivider(supplyVolts: 9, topOhms: 1_000, bottomOhms: 2_000))
    #expect(close(solution.voltage(at: 1), 9))
    #expect(close(solution.voltage(at: 2), 6))
    #expect(close(solution.current(through: "R1"), 0.003))
    #expect(close(solution.current(through: "R2"), 0.003))
    #expect(close(solution.current(through: "Vsupply"), -0.003))
    #expect(solution.maximumKCLResidual < 1e-12)
    #expect(abs(solution.powerBalance) < 1e-12)
    #expect(close(solution.branchPowers["R1"], 0.009))
    #expect(solution.voltage(at: 99) == nil)
    #expect(solution.current(through: "missing") == nil)
}

@Test func parallelSplitsCurrentByConductance() throws {
    let solution = try CircuitSolver.solveDC(CircuitPresets.parallel(supplyVolts: 12, firstOhms: 3_000, secondOhms: 6_000))
    #expect(close(solution.current(through: "R1"), 0.004))
    #expect(close(solution.current(through: "R2"), 0.002))
    #expect(close(solution.current(through: "Vsupply"), -0.006))
    #expect(solution.maximumKCLResidual < 1e-12)
}

@Test func currentSourcePolarityAndNonconsecutiveNodes() throws {
    let circuit = Circuit(elements: [
        .currentSource(id: "I", a: 0, b: 42, amps: 0.002),
        .resistor(id: "R", a: 42, b: 0, ohms: 1_000)
    ])
    let solution = try CircuitSolver.solveDC(circuit)
    #expect(close(solution.voltage(at: 42), 2))
    #expect(close(solution.current(through: "I"), 0.002))
    #expect(close(solution.branchPowers["I"], -0.004))
    #expect(abs(solution.powerBalance) < 1e-12)
}

@Test func bridgeSymmetryAndKCLAtEveryNode() throws {
    let circuit = Circuit(elements: [
        .voltageSource(id: "V", a: 7, b: 0, volts: 10),
        .resistor(id: "R1", a: 7, b: 2, ohms: 100),
        .resistor(id: "R2", a: 2, b: 0, ohms: 200),
        .resistor(id: "R3", a: 7, b: 3, ohms: 150),
        .resistor(id: "R4", a: 3, b: 0, ohms: 300),
        .resistor(id: "Bridge", a: 2, b: 3, ohms: 47)
    ])
    let solution = try CircuitSolver.solveDC(circuit)
    #expect(close(solution.voltage(at: 2), 20 / 3))
    #expect(close(solution.voltage(at: 3), 20 / 3))
    #expect(close(solution.current(through: "Bridge"), 0))
    #expect(solution.kclResiduals.values.allSatisfy { abs($0) < 1e-12 })
    #expect(abs(solution.powerBalance) < 1e-12)
}

@Test func reversedResistorPinsReverseCurrent() throws {
    let circuit = Circuit(elements: [
        .voltageSource(id: "V", a: 1, b: 0, volts: 5),
        .resistor(id: "R", a: 0, b: 1, ohms: 100)
    ])
    let solution = try CircuitSolver.solveDC(circuit)
    #expect(close(solution.current(through: "R"), -0.05))
    #expect(close(solution.branchPowers["R"], 0.25))
}

@Test func dcCapacitorIsOpenAndInductorIsShort() throws {
    let rc = try CircuitSolver.solveDC(CircuitPresets.rcCharge(supplyVolts: 5))
    #expect(close(rc.voltage(at: 2), 5))
    #expect(close(rc.current(through: "C1"), 0))
    #expect(close(rc.current(through: "R1"), 0))
    let rl = try CircuitSolver.solveDC(CircuitPresets.rlEnergize(supplyVolts: 5, ohms: 100))
    #expect(close(rl.voltage(at: 2), 0))
    #expect(close(rl.current(through: "L1"), 0.05))
}

@Test func tinyConductanceDoesNotBecomeAnArtificialOpen() throws {
    let circuit = Circuit(elements: [
        .currentSource(id: "I", a: 0, b: 1, amps: 2e-12),
        .resistor(id: "R", a: 1, b: 0, ohms: 1e12)
    ])
    #expect(close(try CircuitSolver.solveDC(circuit).voltage(at: 1), 2))
}

@Test func rejectsInvalidValuesRatherThanClamping() {
    for resistance in [0.0, -1, .infinity, .nan] {
        let circuit = Circuit(elements: [.resistor(id: "R", a: 1, b: 0, ohms: resistance)])
        #expect(throws: CircuitError.invalidValue(id: "R", quantity: "Resistance", requiresPositive: true)) {
            try CircuitSolver.solveDC(circuit)
        }
    }
    #expect(throws: CircuitError.invalidValue(id: "V", quantity: "Voltage", requiresPositive: false)) {
        try CircuitSolver.solveDC(Circuit(elements: [.voltageSource(id: "V", a: 1, b: 0, volts: .nan)]))
    }
}

@Test func rejectsEmptyDuplicateAndNegativeNodes() {
    #expect(throws: CircuitError.emptyCircuit) { try CircuitSolver.solveDC(Circuit(elements: [])) }
    #expect(throws: CircuitError.emptyElementID) {
        try CircuitSolver.solveDC(Circuit(elements: [.resistor(id: " ", a: 1, b: 0, ohms: 10)]))
    }
    #expect(throws: CircuitError.invalidNode("R")) {
        try CircuitSolver.solveDC(Circuit(elements: [.resistor(id: "R", a: -1, b: 0, ohms: 10)]))
    }
    #expect(throws: CircuitError.duplicateElementID("R")) {
        try CircuitSolver.solveDC(Circuit(elements: [.resistor(id: "R", a: 1, b: 0, ohms: 10), .resistor(id: "R", a: 1, b: 0, ohms: 20)]))
    }
}

@Test func rejectsFloatingNetworksAndOpenCapacitorNode() {
    #expect(throws: CircuitError.floatingNodes([1, 2])) {
        try CircuitSolver.solveDC(Circuit(elements: [.resistor(id: "R", a: 1, b: 2, ohms: 10)]))
    }
    #expect(throws: CircuitError.floatingNodes([1])) {
        try CircuitSolver.solveDC(Circuit(elements: [.capacitor(id: "C", a: 1, b: 0, farads: 1e-6)]))
    }
}

@Test func distinguishesContradictoryAndRedundantSources() {
    let contradictory = Circuit(elements: [
        .voltageSource(id: "V1", a: 1, b: 0, volts: 1),
        .voltageSource(id: "V2", a: 1, b: 0, volts: 2)
    ])
    #expect(throws: CircuitError.inconsistentCircuit) { try CircuitSolver.solveDC(contradictory) }
    let redundant = Circuit(elements: [
        .voltageSource(id: "V1", a: 1, b: 0, volts: 1),
        .voltageSource(id: "V2", a: 1, b: 0, volts: 1)
    ])
    #expect(throws: CircuitError.singularCircuit) { try CircuitSolver.solveDC(redundant) }
}

@Test func capacitorBackwardEulerMatchesDiscreteAnalyticSolution() throws {
    var simulator = try TransientSimulator(circuit: CircuitPresets.rcCharge(supplyVolts: 5, ohms: 1_000, farads: 0.001))
    let dt = 0.05
    for step in 1...40 {
        let solution = try simulator.step(timeStep: dt)
        let expected = 5 * (1 - pow(1 + dt, -Double(step)))
        #expect(close(solution.voltage(at: 2), expected))
        #expect(solution.maximumKCLResidual < 1e-12)
        #expect(abs(solution.powerBalance) < 1e-12)
    }
    #expect(close(simulator.time, 2))
}

@Test func capacitorTransientConvergesAsTimeStepShrinks() throws {
    func atOneTimeConstant(step: Double, count: Int) throws -> Double {
        var simulator = try TransientSimulator(circuit: CircuitPresets.rcCharge(supplyVolts: 5, ohms: 1_000, farads: 0.001))
        for _ in 0..<count { _ = try simulator.step(timeStep: step) }
        return simulator.capacitorVoltages["C1"]!
    }
    let analytic = 5 * (1 - exp(-1.0))
    let coarseError = abs(try atOneTimeConstant(step: 0.1, count: 10) - analytic)
    let fineError = abs(try atOneTimeConstant(step: 0.01, count: 100) - analytic)
    #expect(fineError < coarseError / 8)
}

@Test func chargedCapacitorDischargesFromExplicitInitialVoltage() throws {
    var simulator = try TransientSimulator(circuit: CircuitPresets.rcCharge(supplyVolts: 0, ohms: 1_000, farads: 0.001, initialVoltage: 5))
    let solution = try simulator.step(timeStep: 0.1)
    #expect(close(solution.voltage(at: 2), 5 / 1.1))
    #expect(solution.current(through: "C1")! < 0)
}

@Test func inductorBackwardEulerMatchesDiscreteAnalyticSolution() throws {
    var simulator = try TransientSimulator(circuit: CircuitPresets.rlEnergize(supplyVolts: 10, ohms: 100, henrys: 1))
    let dt = 0.001
    for step in 1...40 {
        let solution = try simulator.step(timeStep: dt)
        let expected = 0.1 * (1 - pow(1 + dt * 100, -Double(step)))
        #expect(close(solution.current(through: "L1"), expected))
        #expect(solution.maximumKCLResidual < 1e-12)
        #expect(abs(solution.powerBalance) < 1e-12)
    }
}

@Test func passiveLCBackwardEulerDoesNotCreateEnergy() throws {
    let circuit = Circuit(elements: [
        .capacitor(id: "C", a: 1, b: 0, farads: 1, initialVoltage: 1),
        .inductor(id: "L", a: 1, b: 0, henrys: 1)
    ])
    var simulator = try TransientSimulator(circuit: circuit)
    var previousEnergy = 0.5
    for _ in 0..<100 {
        let solution = try simulator.step(timeStep: 0.01)
        let voltage = solution.voltage(at: 1)!, current = solution.current(through: "L")!
        let energy = 0.5 * voltage * voltage + 0.5 * current * current
        #expect(energy <= previousEnergy + 1e-12)
        #expect(solution.maximumKCLResidual < 1e-12)
        previousEnergy = energy
    }
    #expect(previousEnergy > 0.49)
}

@Test func invalidStepDoesNotAdvanceState() throws {
    var simulator = try TransientSimulator(circuit: CircuitPresets.rcCharge())
    for step in [0.0, -1, .infinity, .nan] {
        #expect(throws: CircuitError.invalidTimeStep) { try simulator.step(timeStep: step) }
        #expect(simulator.time == 0)
        #expect(simulator.capacitorVoltages["C1"] == 0)
    }
}

@Test func rejectsImpossibleReactiveInitialConditions() {
    let voltageConflict = Circuit(elements: [
        .voltageSource(id: "V", a: 1, b: 0, volts: 5),
        .capacitor(id: "C", a: 1, b: 0, farads: 0.001, initialVoltage: 0)
    ])
    #expect(throws: CircuitError.self) { try TransientSimulator(circuit: voltageConflict) }
    let currentConflict = Circuit(elements: [.inductor(id: "L", a: 1, b: 0, henrys: 1, initialCurrent: 1)])
    #expect(throws: CircuitError.inconsistentInitialConditions("L")) { try TransientSimulator(circuit: currentConflict) }
}
