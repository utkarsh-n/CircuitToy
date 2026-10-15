import Foundation
import Testing
import CircuitCore
@testable import CircuitBreadboardStore

@MainActor @Suite struct NonlinearStoreTests {
    private func withStore(_ body: (BreadboardStore, UserDefaults) throws -> Void) throws {
        let suite = "CircuitToy.NonlinearStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(BreadboardStore(defaults: defaults), defaults)
    }

    @Test func nonlinearEditsUndoAndProfilesSurviveRelaunch() throws {
        try withStore { store, defaults in
            store.load(.ledResistor)
            store.selectCurrentProbe("LED1")
            let originalCurrent = try #require(store.probeCurrent)
            #expect(originalCurrent > 0)
            let original = store.document
            var led = try #require(store.selectedComponent)
            led.diodeModel.seriesResistance = 500
            store.save(led)
            let changedCurrent = try #require(store.probeCurrent)
            #expect(changedCurrent < originalCurrent)
            #expect(store.solution!.maximumKCLResidual < 1e-8)
            #expect(abs(store.solution!.powerBalance) < 1e-8)
            let restored = BreadboardStore(defaults: defaults)
            #expect(restored.document == store.document)
            restored.selectCurrentProbe("LED1")
            #expect(abs(try #require(restored.probeCurrent) - changedCurrent) < 1e-9)
            store.undo()
            #expect(store.document == original)
            #expect(abs(try #require(store.probeCurrent) - originalCurrent) < 1e-9)
        }
    }

    @Test func transistorTerminalProbesRespectKCLAndSelection() throws {
        try withStore { store, _ in
            store.load(.npnSwitch)
            let currents = try #require(store.solution?.terminalCurrents["Q1"])
            #expect(currents.count == 3)
            for index in currents.indices {
                store.selectCurrentProbe("Q1", terminalIndex: index)
                #expect(store.probeCurrent == currents[index])
                #expect(store.probeCurrentLabel.contains(["C", "B", "E"][index]))
            }
            #expect(abs(currents.reduce(0, +)) < 1e-10)
            store.selectedComponentID = "R1"
            #expect(store.selectedTerminalIndex == 0)
            store.selectedTerminalIndex = 30
            #expect(store.probeCurrent == nil)
        }
    }

    @Test func opAmpSuppliesCarryLoadAndQuiescentCurrent() throws {
        try withStore { store, _ in
            store.load(.opAmpFollower)
            let currents = try #require(store.solution?.terminalCurrents["U1"])
            #expect(currents.count == 5)
            #expect(currents[0] == 0)
            #expect(currents[1] == 0)
            #expect(currents[2] < 0)
            #expect(currents[3] > 0)
            #expect(currents[4] < 0)
            #expect(abs(currents.reduce(0, +)) < 1e-10)
            store.selectCurrentProbe("U1", terminalIndex: 3)
            #expect(store.probeCurrent == currents[3])
            #expect(store.probeCurrentLabel == "U1 · V+")
            #expect(abs(store.solution!.powerBalance) < 1e-8)
        }
    }

    @Test func invalidDeviceProfileDoesNotReplaceOrPersistValidBoard() throws {
        try withStore { store, defaults in
            store.load(.ledResistor)
            let document = store.document
            let saved = defaults.data(forKey: "CircuitToy.breadboard.analog.v1")
            let solution = store.solution
            var led = try #require(document.components.first { $0.id == "LED1" })
            led.diodeModel.idealityFactor = 0
            store.save(led)
            #expect(store.diagnostic != nil)
            #expect(store.document == document)
            #expect(store.solution == solution)
            #expect(defaults.data(forKey: "CircuitToy.breadboard.analog.v1") == saved)
        }
    }

    @Test func nonlinearTransientSamplesTerminalCurrentAndResetsOnModelEdit() throws {
        try withStore { store, _ in
            var document = BreadboardDocument.ledResistor
            let led = try #require(document.components.first { $0.id == "LED1" })
            document.components.append(.init(id: "C1", kind: .capacitor, pins: led.pins, value: 0.001))
            store.load(document)
            store.setAnalysis(.transient)
            store.setTimeStep(0.001)
            store.selectCurrentProbe("LED1", terminalIndex: 1)
            #expect(store.probeCurrent == nil)
            store.advance(steps: 3)
            #expect(store.diagnostic == nil)
            #expect(store.elapsedTime == 0.003)
            #expect(store.currentSamples.count == 3)
            #expect(store.currentSamples.allSatisfy { $0 <= 0 })
            #expect(store.samples.allSatisfy { $0.maximumKCLResidual < 1e-8 })
            var edited = try #require(store.selectedComponent)
            edited.diodeModel.seriesResistance += 10
            store.save(edited)
            #expect(store.elapsedTime == 0)
            #expect(store.solution == nil)
            #expect(store.samples.isEmpty)
            store.advance()
            #expect(store.diagnostic == nil)
            #expect(store.elapsedTime == 0.001)
        }
    }
}
