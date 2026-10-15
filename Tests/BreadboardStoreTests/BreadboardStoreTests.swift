import Foundation
import Testing
import CircuitCore
@testable import CircuitBreadboardStore

@MainActor private func withStore(_ body: (BreadboardStore, UserDefaults, String) throws -> Void) throws {
    let suite = "CircuitToy.BreadboardStoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    try body(BreadboardStore(defaults: defaults), defaults, suite)
}

private func near(_ value: Double?, _ expected: Double) -> Bool {
    guard let value else { return false }
    return abs(value - expected) < 1e-10 * max(1, abs(expected))
}

private let analogKey = "CircuitToy.breadboard.analog.v1"
private let logicKey = "CircuitToy.breadboard.logic.v1"

@MainActor @Suite struct BreadboardStoreTests {
    @Test func dcEditsProbeRealSignedCurrentsAndUndoRestoresCircuit() throws {
        try withStore { store, defaults, _ in
            store.selectedComponentID = "R1"
            #expect(near(store.probeVoltage, 2.5))
            #expect(near(store.probeCurrent, 0.0025))
            let original = store.document
            var resistor = try #require(store.selectedComponent)
            resistor.value = 2_000
            store.save(resistor)
            #expect(near(store.probeVoltage, 5 / 3))
            #expect(near(store.probeCurrent, 5 / 3_000))
            #expect(store.solution!.maximumKCLResidual < 1e-12)
            #expect(abs(store.solution!.powerBalance) < 1e-12)
            #expect(store.canUndo)
            store.undo()
            #expect(store.document == original)
            #expect(near(store.probeVoltage, 2.5))
            #expect(near(store.probeCurrent, 0.0025))
            let data = try #require(defaults.data(forKey: analogKey))
            #expect(try JSONDecoder().decode(BreadboardDocument.self, from: data) == original)
            store.selectedComponentID = "W1"
            #expect(store.probeCurrent == nil)
        }
    }

    @Test func unchangedTimeStepAndEditsPreserveTransientTimeSamplesAndPlayback() throws {
        try withStore { store, _, _ in
            store.load(.rc)
            store.setTimeStep(0.1)
            store.setAnalysis(.transient)
            store.selectedComponentID = "R1"
            store.advance(steps: 2)
            store.isRunning = true
            let solution = store.solution
            let samples = store.samples
            let document = store.document
            store.setTimeStep(0.1)
            store.save(try #require(store.selectedComponent))
            store.setGround(document.ground)
            #expect(store.solution == solution)
            #expect(store.samples == samples)
            #expect(store.document == document)
            #expect(store.isRunning)
            #expect(near(store.elapsedTime, 0.2))
            #expect(near(store.probeVoltage, 5 * (1 - pow(1.1, -2))))
        }
    }

    @Test func changedTimeStepAndResetRestartExplicitReactiveInitialState() throws {
        try withStore { store, _, _ in
            store.load(.rc)
            store.setAnalysis(.transient)
            store.setTimeStep(0.1)
            #expect(store.solution == nil)
            store.advance(steps: 2)
            store.isRunning = true
            store.setTimeStep(0.01)
            #expect(!store.isRunning)
            #expect(store.elapsedTime == 0)
            #expect(store.solution == nil)
            #expect(store.samples.isEmpty)
            #expect(store.probeVoltage == nil)
            store.advance()
            #expect(near(store.elapsedTime, 0.01))
            #expect(near(store.probeVoltage, 5 * 0.01 / 1.01))
            let first = store.solution
            store.reset()
            #expect(store.solution == nil)
            #expect(store.samples.isEmpty)
            store.advance()
            #expect(store.solution == first)
        }
    }

    @Test func editingCapacitorInitialStateAndResistanceUsesNewBackwardEulerCircuit() throws {
        try withStore { store, _, _ in
            store.load(.rc)
            store.setAnalysis(.transient)
            store.setTimeStep(0.1)
            store.advance(steps: 2)
            var capacitor = try #require(store.document.components.first { $0.id == "C1" })
            capacitor.initialValue = 2
            store.isRunning = true
            store.save(capacitor)
            #expect(!store.isRunning)
            #expect(store.elapsedTime == 0)
            #expect(store.probeVoltage == nil)
            #expect(store.samples.isEmpty)
            store.selectedComponentID = "C1"
            store.advance()
            #expect(near(store.probeVoltage, (2 + 0.1 * 5) / 1.1))
            #expect(near(store.probeCurrent, (5 - (2 + 0.1 * 5) / 1.1) / 1_000))
            var resistor = try #require(store.document.components.first { $0.id == "R1" })
            resistor.value = 2_000
            store.save(resistor)
            #expect(store.probeCurrent == nil)
            store.advance()
            #expect(near(store.probeVoltage, (2 * 2 + 0.1 * 5) / 2.1))
            #expect(store.samples.count == 1)
            #expect(store.solution!.maximumKCLResidual < 1e-12)
        }
    }

    @Test func rejectedSaveAddAndWireLeaveDocumentSelectionAndReactiveStateUntouched() throws {
        try withStore { store, defaults, _ in
            store.load(.rc)
            store.setAnalysis(.transient)
            store.selectedComponentID = "R1"
            store.advance()
            store.isRunning = true
            let document = store.document
            let solution = store.solution
            let samples = store.samples
            let data = defaults.data(forKey: analogKey)
            var resistor = try #require(store.selectedComponent)
            resistor.value = 0
            store.save(resistor)
            #expect(store.diagnostic != nil)
            store.add(.logicInput, pins: [.init(row: 6, column: .a)])
            store.add(.resistor, pins: [.init(row: 6, column: .a), .init(row: 6, column: .a)])
            store.addWire(from: .init(row: 6, column: .a), to: .init(row: 12, column: .a))
            #expect(store.document == document)
            #expect(store.solution == solution)
            #expect(store.samples == samples)
            #expect(store.selectedComponentID == "R1")
            #expect(store.isRunning)
            #expect(defaults.data(forKey: analogKey) == data)
        }
    }

    @Test func rejectedCrossModeLoadDoesNotSwitchModesOrDiscardMeasurements() throws {
        try withStore { store, defaults, _ in
            store.load(.rc)
            store.setAnalysis(.transient)
            store.setTimeStep(0.1)
            store.selectedComponentID = "R1"
            store.advance()
            store.isRunning = true
            let document = store.document
            let solution = store.solution
            let samples = store.samples
            let data = defaults.data(forKey: analogKey)
            var malformed = BreadboardDocument.andGate
            malformed.ground = .init(row: Int.max, column: .a)
            store.load(malformed)
            #expect(store.diagnostic != nil)
            #expect(store.document == document)
            #expect(store.document.mode == .analog)
            #expect(store.analysis == .transient)
            #expect(store.timeStep == 0.1)
            #expect(store.solution == solution)
            #expect(store.samples == samples)
            #expect(store.selectedComponentID == "R1")
            #expect(store.isRunning)
            #expect(defaults.data(forKey: analogKey) == data)
        }
    }

    @Test func analogAndLogicDocumentsPersistIndependentlyAndRestoreThroughActualDefaults() throws {
        try withStore { store, _, suite in
            var resistor = try #require(store.document.components.first { $0.id == "R1" })
            resistor.value = 2_000
            store.save(resistor)
            let analog = store.document
            store.switchMode(.logic)
            store.toggleInput("A")
            store.toggleInput("B")
            store.addWire(from: .init(row: 0, column: .b), to: .init(row: 2, column: .b))
            let logic = store.document
            #expect(store.logic!.logic(at: .init(row: 4, column: .f)) == .unknown)
            let reopened = try #require(UserDefaults(suiteName: suite))
            let restored = BreadboardStore(defaults: reopened)
            #expect(restored.document == analog)
            #expect(near(restored.probeVoltage, 5 / 3))
            restored.switchMode(.logic)
            #expect(restored.document == logic)
            #expect(restored.logic!.logic(at: .init(row: 4, column: .f)) == .unknown)
            #expect(restored.solution == nil)
            #expect(restored.probeCurrent == nil)
        }
    }

    @Test func malformedOrWrongModePersistedDocumentsFallBackWithoutAcceptingInvalidPins() throws {
        try withStore { _, defaults, _ in
            defaults.set(try JSONEncoder().encode(BreadboardDocument.andGate), forKey: analogKey)
            var malformed = BreadboardDocument.andGate
            malformed.components[2].pins.removeLast()
            defaults.set(try JSONEncoder().encode(malformed), forKey: logicKey)
            let restored = BreadboardStore(defaults: defaults)
            #expect(restored.document == .divider)
            #expect(near(restored.probeVoltage, 2.5))
            restored.switchMode(.logic)
            #expect(restored.document == .andGate)
            #expect(restored.logic!.logic(at: .init(row: 4, column: .f)) == .zero)
        }
    }

    @Test func inductorInitialCurrentEditDCAndUndoRespectConstitutiveLaw() throws {
        try withStore { store, _, _ in
            var document = BreadboardDocument.rc
            document.components[1].value = 100
            document.components[2] = .init(id: "L1", kind: .inductor, pins: document.components[2].pins, value: 1, initialValue: 0.01)
            store.load(document)
            store.setTimeStep(0.001)
            store.setAnalysis(.transient)
            store.selectedComponentID = "L1"
            store.advance()
            #expect(near(store.probeCurrent, (0.01 + 0.001 * 5) / 1.1))
            #expect(near(store.probeVoltage, 5 - 100 * (0.01 + 0.001 * 5) / 1.1))
            var inductor = try #require(store.selectedComponent)
            inductor.initialValue = -0.01
            store.save(inductor)
            #expect(store.solution == nil)
            store.advance()
            #expect(near(store.probeCurrent, (-0.01 + 0.001 * 5) / 1.1))
            #expect(store.solution!.branchPowers["L1"]! < 0)
            store.undo()
            #expect(store.solution == nil)
            store.advance()
            #expect(near(store.probeCurrent, (0.01 + 0.001 * 5) / 1.1))
            store.setAnalysis(.dc)
            #expect(near(store.probeCurrent, 0.05))
            #expect(near(store.probeVoltage, 0))
        }
    }

    @Test func modeUndoHistoriesRemainSeparate() throws {
        try withStore { store, _, _ in
            var resistor = try #require(store.document.components.first { $0.id == "R1" })
            resistor.value = 2_000
            store.save(resistor)
            let analog = store.document
            store.switchMode(.logic)
            store.toggleInput("A")
            store.undo()
            #expect(store.document == .andGate)
            store.switchMode(.analog)
            #expect(store.document == analog)
            store.undo()
            #expect(store.document == .divider)
            #expect(near(store.probeVoltage, 2.5))
        }
    }

    @Test func contradictoryReactiveInitialConditionsNeverProduceFakeMeasurement() throws {
        try withStore { store, _, _ in
            var document = BreadboardDocument.rc
            document.wires.append(.init(id: "ShortR", a: .init(row: 0, column: .a), b: .init(row: 2, column: .a)))
            store.load(document)
            store.setAnalysis(.transient)
            #expect(store.diagnostic != nil)
            store.advance()
            #expect(store.solution == nil)
            #expect(store.samples.isEmpty)
            var capacitor = try #require(store.document.components.first { $0.id == "C1" })
            capacitor.initialValue = 5
            store.save(capacitor)
            #expect(store.diagnostic == nil)
            store.advance()
            #expect(near(store.probeVoltage, 5))
            #expect(near(store.solution!.current(through: "C1"), 0))
        }
    }

    @Test func generatedComponentAndWireIdentifiersAvoidTheEntireDocumentNamespace() throws {
        try withStore { store, _, _ in
            var document = BreadboardDocument.divider
            document.components[1].id = "W1"
            document.wires[0].id = "R1"
            store.load(document)
            store.add(.resistor, pins: [.init(row: 0, column: .d), .init(row: 2, column: .d)])
            #expect(store.selectedComponentID == "R3")
            #expect(store.document.components.last!.id == "R3")
            store.addWire(from: .init(row: 6, column: .a), to: .init(row: 6, column: .f))
            #expect(store.document.wires.last!.id == "W2")
            try store.document.validate()
        }
    }
}
