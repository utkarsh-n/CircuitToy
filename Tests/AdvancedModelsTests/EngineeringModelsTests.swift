import XCTest
@testable import CircuitAdvanced

final class EngineeringModelsTests: XCTestCase {
    func testRegisterOnlyCapturesOnRisingEdgeAndCounterCanHold() {
        var board = EngineeringModels.Sequential()
        board.setClock(false, data: 15, enable: true, bit: false)
        XCTAssertEqual(board.register, 0)
        board.setClock(true, data: 5, enable: true, bit: true)
        XCTAssertEqual(board.register, 5)
        XCTAssertEqual(board.counter, 1)
        board.setClock(true, data: 12, enable: true, bit: false)
        XCTAssertEqual(board.register, 5)
        XCTAssertEqual(board.counter, 1)
        board.setClock(false, data: 12, enable: true, bit: false)
        board.setClock(true, data: 12, enable: false, bit: false)
        XCTAssertEqual(board.register, 12)
        XCTAssertEqual(board.counter, 1)
        XCTAssertEqual(board.edges, 2)
    }

    func testFourBitCounterWrapAndDetectorOverlaps() {
        var board = EngineeringModels.Sequential()
        for _ in 0..<16 {
            board.setClock(false, data: 31, enable: true, bit: false)
            board.setClock(true, data: 31, enable: true, bit: false)
        }
        XCTAssertEqual(board.counter, 0)
        XCTAssertEqual(board.register, 15)
        var state = 0
        var hits: [Int] = []
        for (index, bit) in [true, false, true, false, true].enumerated() {
            let result = EngineeringModels.sequence101(state: state, bit: bit)
            state = result.state
            if result.detected { hits.append(index) }
        }
        XCTAssertEqual(hits, [2, 4])
    }

    func testSetupHoldSkewAndClockPeriodHaveDifferentEffects() throws {
        func result(period: Double, skew: Double) throws -> EngineeringModels.Timing {
            try EngineeringModels.timing(periodNS: period, clockToQMaxNS: 0.8, clockToQMinNS: 0.2,
                logicMaxNS: 4, logicMinNS: 0.5, setupNS: 0.3, holdNS: 0.15, skewNS: skew)
        }
        let base = try result(period: 6, skew: 0)
        XCTAssertEqual(base.setupMargin, 0.9, accuracy: 1e-12)
        XCTAssertEqual(base.holdMargin, 0.55, accuracy: 1e-12)
        let laterClock = try result(period: 6, skew: 0.6)
        XCTAssertEqual(laterClock.setupMargin - base.setupMargin, 0.6, accuracy: 1e-12)
        XCTAssertEqual(laterClock.holdMargin - base.holdMargin, -0.6, accuracy: 1e-12)
        XCTAssertFalse(laterClock.passes)
        let slower = try result(period: 10, skew: 0.6)
        XCTAssertEqual(slower.holdMargin, laterClock.holdMargin, accuracy: 1e-12)
        XCTAssertFalse(slower.passes, "Slowing the clock does not repair hold.")
    }

    func testTimingConstraintBoundaryAndInvalidDelayOrdering() throws {
        let exact = try EngineeringModels.timing(periodNS: 5, clockToQMaxNS: 1, clockToQMinNS: 1,
            logicMaxNS: 3, logicMinNS: 1, setupNS: 1, holdNS: 2, skewNS: 0)
        XCTAssertEqual(exact.setupMargin, 0)
        XCTAssertEqual(exact.holdMargin, 0)
        XCTAssertTrue(exact.passes)
        XCTAssertThrowsError(try EngineeringModels.timing(periodNS: 5, clockToQMaxNS: 1, clockToQMinNS: 2,
            logicMaxNS: 3, logicMinNS: 1, setupNS: 1, holdNS: 2, skewNS: 0))
    }

    func testHazardPulseTransportDelayAndConsensusTerm() {
        // A rises at 2 ns. Falling old term arrives at 4.2; rising new term at 7.2.
        XCTAssertEqual(EngineeringModels.hazard(timeNS: 4.19, riseDelayNS: 5, fallDelayNS: 2, consensus: false), 1)
        XCTAssertEqual(EngineeringModels.hazard(timeNS: 4.2, riseDelayNS: 5, fallDelayNS: 2, consensus: false), 0)
        XCTAssertEqual(EngineeringModels.hazard(timeNS: 7.19, riseDelayNS: 5, fallDelayNS: 2, consensus: false), 0)
        XCTAssertEqual(EngineeringModels.hazard(timeNS: 7.2, riseDelayNS: 5, fallDelayNS: 2, consensus: false), 1)
        for step in 0...120 {
            let time = Double(step) / 10
            XCTAssertEqual(EngineeringModels.hazard(timeNS: time, riseDelayNS: 5, fallDelayNS: 2, consensus: true), 1)
            XCTAssertEqual(EngineeringModels.hazard(timeNS: time, riseDelayNS: 1, fallDelayNS: 3, consensus: false), 1)
        }
        // Independently enumerate the steady truth table to verify consensus preserves the function.
        for a in [false, true] { for b in [false, true] { for c in [false, true] {
            let original = (a && b) || (!a && c)
            let withConsensus = original || (b && c)
            XCTAssertEqual(original, withConsensus)
        } } }
    }

    func testTransformerPowerAndReflectedResistance() throws {
        for turns in [25.0, 100, 200, 400] {
            let t = try EngineeringModels.transformer(primaryRMS: 24, primaryTurns: 100, secondaryTurns: turns, loadOhms: 50)
            XCTAssertEqual(t.secondaryRMS / 24, turns / 100, accuracy: 1e-12)
            XCTAssertEqual(t.inputPower, t.outputPower, accuracy: 1e-10)
            XCTAssertEqual(24 / t.primaryCurrentRMS, t.reflectedResistance, accuracy: 1e-10)
            XCTAssertEqual(t.secondaryCurrentRMS * t.secondaryRMS, t.inputPower, accuracy: 1e-10)
        }
    }

    func testMotorIndependentPowerBalanceAndNoLoad() throws {
        for volts in [6.0, 12, 24] { for resistance in [0.5, 2, 5] { for torque in [0.0, 0.1, 0.2] {
            let m = try EngineeringModels.motor(volts: volts, resistance: resistance, constant: 0.1, loadTorque: torque)
            XCTAssertEqual(m.inputPower, m.mechanicalPower + m.copperLoss, accuracy: 1e-10)
            XCTAssertEqual(m.backEMF, m.speed * 0.1, accuracy: 1e-12)
            XCTAssertEqual(torque, m.current * 0.1, accuracy: 1e-12)
        } } }
        let noLoad = try EngineeringModels.motor(volts: 12, resistance: 2, constant: 0.1, loadTorque: 0)
        XCTAssertEqual(noLoad.current, 0)
        XCTAssertEqual(noLoad.speed, 120)
        XCTAssertNil(noLoad.efficiency, "Zero input/output power has no efficiency ratio.")
    }

    func testMotorStallBoundaryAndBeyondStallIsNotClamped() throws {
        let stalled = try EngineeringModels.motor(volts: 12, resistance: 2, constant: 0.1, loadTorque: 0.6)
        XCTAssertEqual(stalled.stallTorque, 0.6, accuracy: 1e-12)
        XCTAssertEqual(stalled.speed, 0, accuracy: 1e-12)
        XCTAssertEqual(stalled.mechanicalPower, 0, accuracy: 1e-12)
        let beyond = try EngineeringModels.motor(volts: 12, resistance: 2, constant: 0.1, loadTorque: 0.8)
        XCTAssertFalse(beyond.motoring)
        XCTAssertLessThan(beyond.speed, 0)
        XCTAssertNil(beyond.efficiency)
    }

    func testBuckVoltSecondsRippleEnergyAndMeanCurrent() throws {
        let input = 12.0, duty = 0.4, inductance = 200e-6, frequency = 100e3
        let b = try EngineeringModels.buck(input: input, duty: duty, inductance: inductance, frequency: frequency, load: 8)
        XCTAssertTrue(b.continuousConduction)
        // The independently computed inductor volt-seconds over a full cycle sum to zero.
        let onVoltSeconds = (input - b.output) * duty / frequency
        let offVoltSeconds = -b.output * (1 - duty) / frequency
        XCTAssertEqual(onVoltSeconds + offVoltSeconds, 0, accuracy: 1e-15)
        XCTAssertEqual(b.ripple, onVoltSeconds / inductance, accuracy: 1e-12)
        XCTAssertEqual(b.inputPower, b.outputPower, accuracy: 1e-12)
        let samples = 10_000
        let mean = (0..<samples).reduce(0.0) { $0 + b.current(at: (Double($1) + 0.5) / Double(samples), duty: duty) } / Double(samples)
        XCTAssertEqual(mean, b.averageCurrent, accuracy: 1e-9)
        XCTAssertEqual(b.current(at: 0, duty: duty), b.minimumCurrent, accuracy: 1e-12)
        XCTAssertEqual(b.current(at: duty, duty: duty), b.maximumCurrent, accuracy: 1e-12)
        XCTAssertEqual(b.current(at: 1, duty: duty), b.minimumCurrent, accuracy: 1e-12)
        let twiceL = try EngineeringModels.buck(input: input, duty: duty, inductance: inductance * 2, frequency: frequency, load: 8)
        XCTAssertEqual(twiceL.ripple * 2, b.ripple, accuracy: 1e-12)
    }

    func testBuckConductionBoundaryAndDCMCandidateIsFlagged() throws {
        // Rcrit = 2Lf/(1-D) = 20 ohm. Strict CCM excludes Imin == 0.
        let boundary = try EngineeringModels.buck(input: 12, duty: 0.5, inductance: 100e-6, frequency: 50e3, load: 20)
        XCTAssertEqual(boundary.minimumCurrent, 0, accuracy: 1e-12)
        XCTAssertFalse(boundary.continuousConduction)
        let dcm = try EngineeringModels.buck(input: 12, duty: 0.5, inductance: 100e-6, frequency: 50e3, load: 40)
        XCTAssertLessThan(dcm.minimumCurrent, 0)
        XCTAssertFalse(dcm.continuousConduction)
        XCTAssertThrowsError(try EngineeringModels.buck(input: 12, duty: 1, inductance: 100e-6, frequency: 50e3, load: 10))
    }

    func testBalancedThreePhaseHasConstantInstantaneousPowerAndZeroNeutral() throws {
        let t = try EngineeringModels.threePhase(phaseRMS: 120, resistances: [40, 40, 40])
        XCTAssertEqual(t.neutralRMS, 0, accuracy: 1e-12)
        XCTAssertEqual(t.averagePower, 1080, accuracy: 1e-10)
        for index in 0..<361 {
            let angle = Double(index) * .pi / 180
            let v = EngineeringModels.phaseVoltages(angle: angle, phaseRMS: 120)
            XCTAssertEqual(v.reduce(0, +), 0, accuracy: 1e-10)
            XCTAssertEqual(v.reduce(0) { $0 + $1 * $1 / 40 }, t.averagePower, accuracy: 1e-9)
        }
    }

    func testUnbalancedNeutralMatchesIndependentTimeDomainRMS() throws {
        let loads = [20.0, 40, 80], voltage = 120.0
        let t = try EngineeringModels.threePhase(phaseRMS: voltage, resistances: loads)
        let samples = 10_000
        let meanSquare = (0..<samples).reduce(0.0) { total, index in
            let angle = (Double(index) + 0.5) * 2 * .pi / Double(samples)
            let sum = (0..<3).reduce(0.0) { $0 + sqrt(2) * voltage * sin(angle - Double($1) * 2 * .pi / 3) / loads[$1] }
            return total + sum * sum / Double(samples)
        }
        XCTAssertEqual(t.neutralRMS, sqrt(meanSquare), accuracy: 1e-10)
        XCTAssertEqual(t.averagePower, loads.reduce(0) { $0 + voltage * voltage / $1 }, accuracy: 1e-10)
    }

    func testCPUFetchAndDecodeDoNotExecuteTheInstruction() throws {
        var cpu = EngineeringModels.CPU(inputA: 7, inputB: 5)
        try cpu.step()
        XCTAssertEqual(cpu.instruction, .loadA(0))
        XCTAssertEqual(cpu.pc, 1)
        XCTAssertEqual(cpu.phase, .decode)
        XCTAssertEqual(cpu.a, 0)
        try cpu.step()
        XCTAssertEqual(cpu.phase, .execute)
        XCTAssertEqual(cpu.a, 0)
        try cpu.step()
        XCTAssertEqual(cpu.a, 7)
        XCTAssertEqual(cpu.instructionsExecuted, 1)
        XCTAssertEqual(cpu.cycles, 3)
    }

    func testCPUAddOverflowAndANDProgramsStoreActualResults() throws {
        var add = EngineeringModels.CPU(inputA: 250, inputB: 10)
        try run(&add)
        XCTAssertEqual(add.memory[2], 4)
        XCTAssertTrue(add.carry)
        XCTAssertFalse(add.zero)
        XCTAssertEqual(add.cycles, 15)
        XCTAssertEqual(add.instructionsExecuted, 5)
        let stopped = add
        try add.step()
        XCTAssertEqual(add, stopped)
        var and = EngineeringModels.CPU(inputA: 0b11001010, inputB: 0b10110000, mode: 1)
        try run(&and)
        XCTAssertEqual(and.memory[2], 0b10000000)
        XCTAssertFalse(and.carry)
    }

    func testCPUConditionalBranchCountdownAndZeroFlag() throws {
        var cpu = EngineeringModels.CPU(inputA: 3, inputB: 0, mode: 2)
        try run(&cpu)
        XCTAssertEqual(cpu.memory[2], 0)
        XCTAssertTrue(cpu.zero)
        // Load + three repeated (DEC, STORE, JNZ) + HALT, all three-phase.
        XCTAssertEqual(cpu.instructionsExecuted, 11)
        XCTAssertEqual(cpu.cycles, 33)
    }

    func testADCBinCentersErrorBoundMonotonicityAndEndpoints() throws {
        for bits in [1, 4, 8, 12, 16] {
            let levels = 1 << bits, lsb = 3.3 / Double(levels)
            var previous = -1
            for index in 0...1000 {
                let input = Double(index) / 1000 * 3.3
                let a = try EngineeringModels.adc(input: input, reference: 3.3, bits: bits)
                XCTAssertEqual(a.levels, levels)
                XCTAssertEqual(a.lsb, lsb, accuracy: 1e-14)
                XCTAssertGreaterThanOrEqual(a.code, previous)
                XCTAssertGreaterThanOrEqual(a.code, 0)
                XCTAssertLessThan(a.code, levels)
                XCTAssertLessThanOrEqual(abs(a.error), lsb / 2 + 1e-14)
                XCTAssertFalse(a.clipped)
                previous = a.code
            }
            let zero = try EngineeringModels.adc(input: 0, reference: 3.3, bits: bits)
            XCTAssertEqual(zero.code, 0)
            XCTAssertEqual(zero.reconstructed, lsb / 2, accuracy: 1e-14)
            let top = try EngineeringModels.adc(input: 3.3, reference: 3.3, bits: bits)
            XCTAssertEqual(top.code, levels - 1)
        }
    }

    func testADCClippingAndNumericalUnderflowAreExplicit() throws {
        let below = try EngineeringModels.adc(input: -1, reference: 3.3, bits: 8)
        let above = try EngineeringModels.adc(input: 5, reference: 3.3, bits: 8)
        XCTAssertTrue(below.clipped)
        XCTAssertTrue(above.clipped)
        XCTAssertEqual(below.code, 0)
        XCTAssertEqual(above.code, 255)
        XCTAssertGreaterThan(abs(above.error), above.lsb / 2)
        XCTAssertThrowsError(try EngineeringModels.adc(input: 0, reference: .leastNonzeroMagnitude, bits: 16))
        XCTAssertThrowsError(try EngineeringModels.adc(input: .nan, reference: 3.3, bits: 8))
    }

    func testInterruptStartFinishAndDeadlineAccounting() throws {
        let jobs = try EngineeringModels.interrupts(period: 200e-6, clockHz: 10e6, entryCycles: 12, handlerCycles: 500, blocking: 20e-6)
        for job in jobs {
            XCTAssertEqual(job.start - job.release, 21.2e-6, accuracy: 1e-15)
            XCTAssertEqual(job.finish - job.start, 50e-6, accuracy: 1e-15)
            XCTAssertEqual(job.deadline - job.release, 200e-6, accuracy: 1e-15)
            XCTAssertEqual(job.slack, 128.8e-6, accuracy: 1e-15)
        }
    }

    func testInterruptBacklogAndZeroWork() throws {
        let jobs = try EngineeringModels.interrupts(period: 50e-6, clockHz: 1e6, entryCycles: 10, handlerCycles: 100, blocking: 20e-6)
        XCTAssertLessThan(jobs[0].slack, 0)
        for index in 1..<jobs.count {
            XCTAssertEqual(jobs[index].start - jobs[index - 1].finish, 30e-6, accuracy: 1e-15)
            XCTAssertEqual(jobs[index].slack - jobs[index - 1].slack, -80e-6, accuracy: 1e-15)
        }
        let zero = try EngineeringModels.interrupts(period: 1, clockHz: 1, entryCycles: 0, handlerCycles: 0, blocking: 0)
        XCTAssertTrue(zero.allSatisfy { $0.start == $0.release && $0.finish == $0.release && $0.slack == 1 })
        XCTAssertThrowsError(try EngineeringModels.interrupts(period: 1, clockHz: 0, entryCycles: 0, handlerCycles: 1, blocking: 0))
    }

    func testReachableStateSafetyAndMinimalFaultWitness() {
        XCTAssertNil(EngineeringModels.safetyWitness(injectedFault: false))
        let witness = EngineeringModels.safetyWitness(injectedFault: true)
        XCTAssertEqual(witness, [true, true])
        var state = 0
        for input in witness ?? [] { state = EngineeringModels.trafficNext(state: state, advance: input) }
        let faulty = EngineeringModels.trafficOutput(state: state, injectedFault: true)
        XCTAssertTrue(faulty.aGreen && faulty.bGreen)
        // Exhaustively check all input traces of length <= 5 independently of the BFS checker.
        for length in 0...5 { for encoded in 0..<(1 << length) {
            var q = 0
            for index in 0..<length { q = EngineeringModels.trafficNext(state: q, advance: encoded & (1 << index) != 0) }
            let safe = EngineeringModels.trafficOutput(state: q, injectedFault: false)
            XCTAssertFalse(safe.aGreen && safe.bGreen)
            if length < 2 {
                let out = EngineeringModels.trafficOutput(state: q, injectedFault: true)
                XCTAssertFalse(out.aGreen && out.bGreen, "No shorter witness exists.")
            }
        } }
    }

    func testDynamicPowerEnergyAndVoltageSquaredScaling() throws {
        let base = try EngineeringModels.dynamicPower(capacitance: 10e-12, volts: 1.2, frequency: 100e6, alpha: 0.25)
        XCTAssertEqual(base, 0.00036, accuracy: 1e-15)
        let twiceVoltage = try EngineeringModels.dynamicPower(capacitance: 10e-12, volts: 2.4, frequency: 100e6, alpha: 0.25)
        XCTAssertEqual(twiceVoltage, 4 * base, accuracy: 1e-15)
        let risingEventsPerSecond = 0.25 * 100e6
        XCTAssertEqual(base / risingEventsPerSecond, 10e-12 * 1.2 * 1.2, accuracy: 1e-22)
        XCTAssertEqual(try EngineeringModels.dynamicPower(capacitance: 10e-12, volts: 1.2, frequency: 100e6, alpha: 0), 0)
        XCTAssertThrowsError(try EngineeringModels.dynamicPower(capacitance: 10e-12, volts: 1.2, frequency: 100e6, alpha: 1.1))
    }

    func testElectricalModelsRejectNonphysicalAndOverflowingInputs() {
        XCTAssertThrowsError(try EngineeringModels.transformer(primaryRMS: 24, primaryTurns: 0, secondaryTurns: 100, loadOhms: 10))
        XCTAssertThrowsError(try EngineeringModels.transformer(primaryRMS: .greatestFiniteMagnitude, primaryTurns: 1, secondaryTurns: 2, loadOhms: 10))
        XCTAssertThrowsError(try EngineeringModels.motor(volts: 12, resistance: -1, constant: 0.1, loadTorque: 0.1))
        XCTAssertThrowsError(try EngineeringModels.motor(volts: 12, resistance: 1, constant: .leastNonzeroMagnitude, loadTorque: 1))
        XCTAssertThrowsError(try EngineeringModels.buck(input: 12, duty: 0.5, inductance: .leastNonzeroMagnitude, frequency: 1, load: 10))
        XCTAssertThrowsError(try EngineeringModels.threePhase(phaseRMS: 120, resistances: [40, 40]))
        XCTAssertThrowsError(try EngineeringModels.threePhase(phaseRMS: .greatestFiniteMagnitude, resistances: [1, 1, 1]))
        XCTAssertThrowsError(try EngineeringModels.interrupts(period: .greatestFiniteMagnitude, clockHz: 1, entryCycles: 1, handlerCycles: 1, blocking: 1))
    }

    private func run(_ cpu: inout EngineeringModels.CPU) throws {
        for _ in 0..<10_000 {
            if cpu.halted { return }
            try cpu.step()
        }
        XCTFail("Teaching program failed to halt.")
    }
}
