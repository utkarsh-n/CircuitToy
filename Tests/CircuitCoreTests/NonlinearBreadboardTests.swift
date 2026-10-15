import Foundation
import Testing
@testable import CircuitCore

private func deviceHole(_ column: BreadboardColumn, _ row: Int) -> BreadboardHole {
    .init(row: row - 1, column: column)
}

private func deviceVoltage(_ solution: CircuitSolution, _ topology: BreadboardTopology,
                           at hole: BreadboardHole) throws -> Double {
    let node = try #require(topology.node(for: hole))
    return try #require(solution.voltage(at: node))
}

private func expectDeviceConservation(_ solution: CircuitSolution) {
    #expect(solution.maximumKCLResidual < 1e-8)
    #expect(abs(solution.powerBalance) < 1e-7)
    for currents in solution.terminalCurrents.values {
        #expect(currents.allSatisfy { $0.isFinite })
        #expect(abs(currents.reduce(0, +)) < 1e-8)
    }
}

@Test func nonlinearBreadboardCompilesEveryTerminalAndDevicePolarity() throws {
    let kinds: [BreadboardComponentKind] = [.diode, .led, .npn, .pnp, .nmos, .pmos, .opAmp]
    for kind in kinds {
        let pins = (1...kind.pinCount).map { deviceHole(.a, $0) }
        let document = BreadboardDocument(components: [.init(id: "Device", kind: kind, pins: pins, value: 0)])
        let topology = try BreadboardTopology(document: document)
        let circuit = try document.makeCircuit()
        let element = try #require(circuit.elements.first)
        let expectedNodes = try pins.map { try #require(topology.node(for: $0)) }
        #expect(kind.isAnalog)
        #expect(kind.hasDeviceModel)
        #expect(element.terminalNodes == expectedNodes)
        #expect(circuit.nodes.count == pins.count)
        #expect(try JSONDecoder().decode(BreadboardDocument.self, from: JSONEncoder().encode(document)) == document)
        switch element {
        case let .diode(_, _, _, model):
            #expect(model == (kind == .led ? .redLED : .silicon))
        case let .bjt(_, _, _, _, polarity, _):
            #expect(polarity == (kind == .npn ? .npn : .pnp))
        case let .mosfet(_, _, _, _, polarity, _):
            #expect(polarity == (kind == .nmos ? .nChannel : .pChannel))
        case .opAmp:
            #expect(kind == .opAmp)
            #expect(kind.pinLabels == ["+In", "−In", "Out", "V+", "V−"])
            #expect(kind.primaryCurrentTerminal == 2)
        default: Issue.record("A modeled breadboard device compiled as a different element")
        }
    }
}

@Test func nonlinearBreadboardPresetsUseDistinctContactsAndActualPoweredReferences() throws {
    for document in [BreadboardDocument.diodeClipper, .ledResistor, .npnSwitch, .mosfetSwitch, .opAmpFollower] {
        try document.validate()
        let contacts = document.components.flatMap(\.pins)
        #expect(Set(contacts).count == contacts.count)
        let topology = try BreadboardTopology(document: document)
        let circuit = try document.makeCircuit()
        #expect(circuit.nodes.contains(0))
        #expect(circuit.elements.count == document.components.count)
        for component in document.components {
            let element = try #require(circuit.elements.first { $0.id == component.id })
            #expect(element.terminalNodes == component.pins.compactMap { topology.node(for: $0) })
        }
    }
    let follower = BreadboardDocument.opAmpFollower
    let topology = try BreadboardTopology(document: follower)
    let amplifier = try #require(follower.components.first { $0.id == "U1" })
    #expect(topology.node(for: amplifier.pins[1]) == topology.node(for: amplifier.pins[2]))
    #expect(amplifier.pins[1] != amplifier.pins[2])
    #expect(topology.node(for: amplifier.pins[4]) == 0)
    #expect(topology.node(for: amplifier.pins[3]) != 0)
}

@Test func nonlinearBreadboardDiodeClipperObeysShockleyAndLoadKCL() throws {
    let document = BreadboardDocument.diodeClipper
    let topology = try BreadboardTopology(document: document)
    let solution = try CircuitSolver.solveDC(document.makeCircuit())
    let voltage = try deviceVoltage(solution, topology, at: deviceHole(.a, 3))
    let diode = try #require(document.components.first { $0.id == "D1" })
    let current = try #require(solution.current(through: diode.id))
    #expect(voltage > 0.45 && voltage < 0.8)
    #expect(current > 0.003 && current < 0.005)
    let thermalVoltage = 8.617333262145e-5 * diode.diodeModel.temperatureKelvin
    let junctionVoltage = voltage - current * diode.diodeModel.seriesResistance
    let expected = diode.diodeModel.saturationCurrent * expm1(junctionVoltage / (diode.diodeModel.idealityFactor * thermalVoltage))
    #expect(abs(current - expected) < 1e-8)
    #expect(abs((5 - voltage) / 1_000 - voltage / 10_000 - current) < 1e-8)
    let terminals = try #require(solution.terminalCurrents[diode.id])
    #expect(terminals.count == 2)
    #expect(abs(terminals[0] - current) < 1e-12)
    #expect(abs(terminals[1] + current) < 1e-12)
    expectDeviceConservation(solution)
}

@Test func nonlinearBreadboardDiodeReverseBiasRetainsTheResistorLoadRatherThanClipping() throws {
    var document = BreadboardDocument.diodeClipper
    document.components[0].value = -5
    let topology = try BreadboardTopology(document: document)
    let solution = try CircuitSolver.solveDC(document.makeCircuit())
    let voltage = try deviceVoltage(solution, topology, at: deviceHole(.a, 3))
    #expect(abs(voltage - (-5 * 10_000.0 / 11_000)) < 1e-6)
    #expect(abs(try #require(solution.current(through: "D1"))) < 1e-9)
    expectDeviceConservation(solution)
}

@Test func nonlinearBreadboardTinyCurrentDiodeLoadLineStillDeterminesItsVoltage() throws {
    for saturation in [1e-12, 1e-18] {
        let model = DiodeModel(saturationCurrent: saturation, idealityFactor: 1.4)
        let document = BreadboardDocument(components: [
            .init(id: "I1", kind: .currentSource,
                  pins: [deviceHole(.leftNegative, 1), deviceHole(.a, 1)], value: saturation),
            .init(id: "D1", kind: .diode,
                  pins: [deviceHole(.c, 1), deviceHole(.leftNegative, 3)], value: 0, diodeModel: model)
        ])
        let topology = try BreadboardTopology(document: document)
        let solution = try CircuitSolver.solveDC(document.makeCircuit())
        // At I = Is, the physical load line is V = n Vt ln(2), however small Is is.
        // An absolute ampere tolerance must not silently accept V=0 and I_D=0.
        let expected = model.idealityFactor * model.thermalVoltage * log(2)
        #expect(abs(try deviceVoltage(solution, topology, at: deviceHole(.e, 1)) - expected) < 1e-9)
        let current = try #require(solution.current(through: "D1"))
        #expect(abs(current / saturation - 1) < 1e-8)
        #expect(solution.maximumKCLResidual < saturation * 1e-8)
        #expect(abs(solution.powerBalance) < saturation * expected * 1e-8)
    }
}

@Test func nonlinearBreadboardLEDUsesItsOwnJunctionAndSeriesResistanceProfile() throws {
    var document = BreadboardDocument.ledResistor
    let topology = try BreadboardTopology(document: document)
    let solution = try CircuitSolver.solveDC(document.makeCircuit())
    let voltage = try deviceVoltage(solution, topology, at: deviceHole(.a, 3))
    let current = try #require(solution.current(through: "LED1"))
    let model = try #require(document.components.first { $0.id == "LED1" }).diodeModel
    #expect(model == .redLED)
    #expect(voltage > 1.5 && voltage < 3)
    #expect(current > 0.005 && current < 0.015)
    let thermalVoltage = 8.617333262145e-5 * model.temperatureKelvin
    let expected = model.saturationCurrent * expm1((voltage - current * model.seriesResistance) / (model.idealityFactor * thermalVoltage))
    #expect(abs(current - expected) < 1e-8)
    expectDeviceConservation(solution)
    document.components[1].value = 680
    let limited = try CircuitSolver.solveDC(document.makeCircuit())
    #expect(try #require(limited.current(through: "LED1")) < current)
    expectDeviceConservation(limited)
}

@Test func nonlinearBreadboardNPNDriveChangesLoadedCollectorWithoutIdealSwitchSubstitution() throws {
    var document = BreadboardDocument.npnSwitch
    let topology = try BreadboardTopology(document: document)
    let on = try CircuitSolver.solveDC(document.makeCircuit())
    let collectorVoltage = try deviceVoltage(on, topology, at: deviceHole(.a, 3))
    #expect(collectorVoltage >= 0 && collectorVoltage < 0.3)
    let currents = try #require(on.terminalCurrents["Q1"])
    #expect(currents.count == 3)
    #expect(currents[0] > 0.004)
    #expect(currents[1] > 0 && currents[2] < 0)
    #expect(abs(try #require(on.current(through: "Q1")) - currents[0]) < 1e-12)
    expectDeviceConservation(on)
    document.components[1].value = 0
    let off = try CircuitSolver.solveDC(document.makeCircuit())
    #expect(abs(try deviceVoltage(off, topology, at: deviceHole(.a, 3)) - 5) < 1e-5)
    #expect(abs(try #require(off.current(through: "Q1"))) < 1e-8)
    expectDeviceConservation(off)
}

@Test func nonlinearBreadboardMOSGateDriveChangesDrainAndHasNoFabricatedGateCurrent() throws {
    var document = BreadboardDocument.mosfetSwitch
    let topology = try BreadboardTopology(document: document)
    let on = try CircuitSolver.solveDC(document.makeCircuit())
    let drainVoltage = try deviceVoltage(on, topology, at: deviceHole(.a, 3))
    #expect(drainVoltage > 0 && drainVoltage < 0.2)
    let currents = try #require(on.terminalCurrents["M1"])
    #expect(currents.count == 3)
    #expect(currents[0] > 0.004)
    #expect(currents[1] == 0)
    #expect(abs(try #require(on.current(through: "M1")) - currents[0]) < 1e-12)
    expectDeviceConservation(on)
    document.components[1].value = 0
    let off = try CircuitSolver.solveDC(document.makeCircuit())
    #expect(abs(try deviceVoltage(off, topology, at: deviceHole(.a, 3)) - 5) < 1e-5)
    #expect(abs(try #require(off.current(through: "M1"))) < 1e-8)
    expectDeviceConservation(off)
}

@Test func nonlinearBreadboardFollowerUsesFiveTerminalsAndSupplyInclusivePower() throws {
    var document = BreadboardDocument.opAmpFollower
    let topology = try BreadboardTopology(document: document)
    let solution = try CircuitSolver.solveDC(document.makeCircuit())
    let output = try deviceVoltage(solution, topology, at: deviceHole(.f, 5))
    #expect(abs(output - 2.5) < 0.001)
    let currents = try #require(solution.terminalCurrents["U1"])
    #expect(currents.count == 5)
    #expect(currents[0] == 0 && currents[1] == 0)
    #expect(currents[2] < -0.002)
    #expect(currents[3] > 0.003)
    #expect(currents[4] < 0)
    #expect(abs(try #require(solution.current(through: "U1")) - currents[2]) < 1e-12)
    expectDeviceConservation(solution)
    document.components[1].value = 1
    let changed = try CircuitSolver.solveDC(document.makeCircuit())
    #expect(abs(try deviceVoltage(changed, topology, at: deviceHole(.f, 5)) - 1) < 0.001)
    expectDeviceConservation(changed)
}

@Test func nonlinearBreadboardFollowerRespectsOutputCurrentLimitUnderHeavyLoad() throws {
    var document = BreadboardDocument.opAmpFollower
    document.components[2].value = 10
    let topology = try BreadboardTopology(document: document)
    let solution = try CircuitSolver.solveDC(document.makeCircuit())
    let output = try deviceVoltage(solution, topology, at: deviceHole(.f, 5))
    #expect(output > 0 && output <= 0.20001)
    #expect(abs(try #require(solution.current(through: "U1"))) <= 0.0200001)
    expectDeviceConservation(solution)
}

private func externallyDrivenAmplifier(output: Double) -> BreadboardDocument {
    var document = BreadboardDocument.opAmpFollower
    // Both ideal inputs are tied to the real 2.5 V source through distinct strip contacts.
    // Remove feedback so output overdrive cannot be mistaken for an input-range violation.
    document.components[3].pins[1] = deviceHole(.e, 3)
    document.wires.removeAll()
    document.components.append(.init(id: "V3", kind: .voltageSource,
        pins: [deviceHole(.i, 5), deviceHole(.leftNegative, 8)], value: output))
    return document
}

@Test func nonlinearBreadboardExternallyDrivenOutputWithinRailsAccountsForSourceAndSinkPower() throws {
    for voltage in [1.0, 4.0] {
        let document = externallyDrivenAmplifier(output: voltage)
        let solution = try CircuitSolver.solveDC(document.makeCircuit())
        let currents = try #require(solution.terminalCurrents["U1"])
        let output = currents[2], positiveRail = currents[3], negativeRail = currents[4]
        #expect(abs(abs(output) - 0.02) < 1e-10)
        if voltage < 2.5 {
            #expect(output < 0)
            #expect(abs(positiveRail - 0.021) < 1e-10)
            #expect(abs(negativeRail + 0.001) < 1e-10)
        } else {
            #expect(output > 0)
            #expect(abs(positiveRail - 0.001) < 1e-10)
            #expect(abs(negativeRail + 0.021) < 1e-10)
        }
        #expect(try #require(solution.branchPowers["U1"]) > 0)
        expectDeviceConservation(solution)
    }
}

@Test func nonlinearBreadboardUnsupportedOutputOverdriveProducesAnExplicitDiagnostic() throws {
    for voltage in [-1.0, 6.0] {
        let document = externallyDrivenAmplifier(output: voltage)
        #expect(throws: CircuitError.invalidOperatingPoint("U1")) {
            try CircuitSolver.solveDC(document.makeCircuit())
        }
    }
}

@Test func nonlinearBreadboardActualFloatingGateAndIdealInputsAcquireNoFakeConductance() throws {
    var mosfet = BreadboardDocument.mosfetSwitch
    mosfet.components.removeAll { $0.id == "V2" || $0.id == "R2" }
    let mosfetTopology = try BreadboardTopology(document: mosfet)
    let gate = try #require(mosfetTopology.node(for: deviceHole(.c, 5)))
    #expect(throws: CircuitError.floatingNodes([gate])) { try CircuitSolver.solveDC(mosfet.makeCircuit()) }

    var follower = BreadboardDocument.opAmpFollower
    follower.components.removeAll { $0.id == "V2" }
    let inputTopology = try BreadboardTopology(document: follower)
    let nonInverting = try #require(inputTopology.node(for: deviceHole(.c, 3)))
    #expect(throws: CircuitError.floatingNodes([nonInverting])) { try CircuitSolver.solveDC(follower.makeCircuit()) }

    follower = .opAmpFollower
    follower.wires.removeAll()
    let feedbackTopology = try BreadboardTopology(document: follower)
    let inverting = try #require(feedbackTopology.node(for: deviceHole(.c, 5)))
    #expect(throws: CircuitError.floatingNodes([inverting])) { try CircuitSolver.solveDC(follower.makeCircuit()) }
}

@Test func nonlinearBreadboardUnpoweredAmplifierAndInputOutsideActualRailsAreRejected() {
    var follower = BreadboardDocument.opAmpFollower
    follower.components[0].value = 0
    #expect(throws: CircuitError.unpoweredDevice("U1")) { try CircuitSolver.solveDC(follower.makeCircuit()) }
    follower = .opAmpFollower
    follower.components[1].value = 6
    #expect(throws: CircuitError.inputCommonModeRange("U1")) { try CircuitSolver.solveDC(follower.makeCircuit()) }
}

@Test func nonlinearBreadboardOldSavedBoardsDecodeWithDefaultDeviceProfiles() throws {
    for document in [BreadboardDocument.divider, .rc, .andGate, .ledResistor] {
        let data = try JSONEncoder().encode(document)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var components = try #require(object["components"] as? [[String: Any]])
        for index in components.indices {
            for key in ["diodeModel", "bjtModel", "mosfetModel", "opAmpModel"] {
                components[index].removeValue(forKey: key)
            }
        }
        object["components"] = components
        let oldData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(BreadboardDocument.self, from: oldData)
        #expect(decoded == document)
        for component in decoded.components {
            #expect(component.diodeModel == (component.kind == .led ? .redLED : .silicon))
            #expect(component.bjtModel == BJTModel())
            #expect(component.mosfetModel == MOSFETModel())
            #expect(component.opAmpModel == OpAmpModel())
        }
    }
}

@Test func nonlinearBreadboardEditedProfilesSurviveCodableRoundTrip() throws {
    var document = BreadboardDocument.opAmpFollower
    let index = try #require(document.components.firstIndex { $0.id == "U1" })
    document.components[index].diodeModel = .init(saturationCurrent: 7e-13, idealityFactor: 1.4, temperatureKelvin: 320, seriesResistance: 22)
    document.components[index].bjtModel = .init(saturationCurrent: 4e-15, forwardBeta: 123, reverseBeta: 3, temperatureKelvin: 310)
    document.components[index].mosfetModel = .init(thresholdVoltage: 1.7, transconductance: 0.035, channelLengthModulation: 0.03, bodyDiode: .redLED)
    document.components[index].opAmpModel = .init(openLoopGain: 20_000, outputResistance: 30, currentLimit: 0.03, railHeadroom: 0.2, quiescentCurrent: 0.0007)
    let decoded = try JSONDecoder().decode(BreadboardDocument.self, from: JSONEncoder().encode(document))
    #expect(decoded == document)
    #expect(decoded.components[index].modelSummary.contains("20000") || decoded.components[index].modelSummary.contains("2e+04"))
}

@Test func nonlinearBreadboardRejectsEveryNonfiniteDeviceParameter() {
    let corruptions: [(BreadboardComponentKind, (inout BreadboardComponent) -> Void)] = [
        (.diode, { $0.diodeModel.saturationCurrent = .nan }),
        (.diode, { $0.diodeModel.idealityFactor = .nan }),
        (.diode, { $0.diodeModel.temperatureKelvin = .nan }),
        (.diode, { $0.diodeModel.seriesResistance = .nan }),
        (.npn, { $0.bjtModel.saturationCurrent = .nan }),
        (.npn, { $0.bjtModel.forwardBeta = .nan }),
        (.npn, { $0.bjtModel.reverseBeta = .nan }),
        (.npn, { $0.bjtModel.temperatureKelvin = .nan }),
        (.nmos, { $0.mosfetModel.thresholdVoltage = .nan }),
        (.nmos, { $0.mosfetModel.transconductance = .nan }),
        (.nmos, { $0.mosfetModel.channelLengthModulation = .nan }),
        (.nmos, { $0.mosfetModel.bodyDiode.saturationCurrent = .nan }),
        (.nmos, { $0.mosfetModel.bodyDiode.idealityFactor = .nan }),
        (.nmos, { $0.mosfetModel.bodyDiode.temperatureKelvin = .nan }),
        (.nmos, { $0.mosfetModel.bodyDiode.seriesResistance = .nan }),
        (.opAmp, { $0.opAmpModel.openLoopGain = .nan }),
        (.opAmp, { $0.opAmpModel.outputResistance = .nan }),
        (.opAmp, { $0.opAmpModel.currentLimit = .nan }),
        (.opAmp, { $0.opAmpModel.railHeadroom = .nan }),
        (.opAmp, { $0.opAmpModel.quiescentCurrent = .nan })
    ]
    for (kind, corrupt) in corruptions {
        var component = BreadboardComponent(id: "Device", kind: kind,
            pins: (1...kind.pinCount).map { deviceHole(.a, $0) }, value: 0)
        corrupt(&component)
        let document = BreadboardDocument(components: [component])
        #expect(throws: CircuitError.self) { try document.validate() }
    }
}

@Test func nonlinearBreadboardRejectsMalformedSavedProfilesEvenWhenUnused() throws {
    var document = BreadboardDocument.divider
    document.components[0].opAmpModel.currentLimit = -1
    #expect(throws: CircuitError.self) { try document.validate() }
    let data = try JSONEncoder().encode(document)
    #expect(throws: CircuitError.self) { try JSONDecoder().decode(BreadboardDocument.self, from: data) }
    document = .mosfetSwitch
    document.components[4].mosfetModel.bodyDiode.seriesResistance = -1
    #expect(throws: CircuitError.self) { try document.makeCircuit() }
}

@Test func nonlinearBreadboardRejectsMissingSupplyContactAndRepeatedDevicePins() {
    var document = BreadboardDocument.opAmpFollower
    document.components[3].pins.removeLast()
    #expect(throws: BreadboardError.invalidPins(id: "U1", expected: 5, actual: 4)) { try document.makeCircuit() }
    document = .npnSwitch
    document.components[5].pins[2] = document.components[5].pins[0]
    #expect(throws: BreadboardError.repeatedPin("Q1")) { try document.makeCircuit() }
    document = .mosfetSwitch
    document.components[4].pins[2] = .init(row: Int.max, column: .a)
    #expect(throws: BreadboardError.invalidHole(document.components[4].pins[2])) { try document.makeCircuit() }
}
