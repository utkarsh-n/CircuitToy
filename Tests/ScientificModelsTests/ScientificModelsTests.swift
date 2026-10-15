import XCTest
@testable import CircuitScience

final class ScientificModelsTests: XCTestCase {
    func testDiodeThermalVoltageAndZeroBias() throws {
        let zero = try XCTUnwrap(ScientificModels.diode(voltage: 0, saturationCurrent: 1e-12, ideality: 1))
        XCTAssertEqual(zero.current, 0)
        XCTAssertEqual(zero.thermalVoltage, 0.025851999786435535, accuracy: 1e-12)
    }

    func testDiodeForwardBiasAndReverseSaturation() throws {
        let current = try XCTUnwrap(ScientificModels.diode(voltage: 0.5, saturationCurrent: 1e-12, ideality: 1))
        XCTAssertEqual(current.current, 0.00025097491, accuracy: 1e-10)
        let reverse = try XCTUnwrap(ScientificModels.diode(voltage: -1, saturationCurrent: 1e-12, ideality: 1))
        XCTAssertEqual(reverse.current, -1e-12, accuracy: 1e-25)
    }

    func testDiodeRejectsInvalidAndOverflowInputs() {
        XCTAssertNil(ScientificModels.diode(voltage: .infinity, saturationCurrent: 1e-12, ideality: 1))
        XCTAssertNil(ScientificModels.diode(voltage: 1, saturationCurrent: -1e-12, ideality: 1))
        XCTAssertNil(ScientificModels.diode(voltage: 1, saturationCurrent: 1e-12, ideality: 0))
        XCTAssertNil(ScientificModels.diode(voltage: 1, saturationCurrent: 1e-12, ideality: 1, kelvin: 0))
        XCTAssertNil(ScientificModels.diode(voltage: 100, saturationCurrent: 1e-12, ideality: 1))
    }

    func testAmplifierGainPolarityAndRails() throws {
        let linear = try XCTUnwrap(ScientificModels.invertingAmplifier(input: 0.5, inputResistance: 10_000, feedbackResistance: 40_000, rail: 5))
        XCTAssertEqual(linear.gain, -4)
        XCTAssertEqual(linear.output, -2)
        XCTAssertFalse(linear.isClipped)
        let clipped = try XCTUnwrap(ScientificModels.invertingAmplifier(input: -2, inputResistance: 10_000, feedbackResistance: 40_000, rail: 5))
        XCTAssertEqual(clipped.requestedOutput, 8)
        XCTAssertEqual(clipped.output, 5)
        XCTAssertTrue(clipped.isClipped)
        XCTAssertNil(ScientificModels.invertingAmplifier(input: 1, inputResistance: 0, feedbackResistance: 1, rail: 5))
    }

    func testHarmonicSuperposition() throws {
        let signal = try XCTUnwrap(ScientificModels.harmonicSignal(time: 0.25, fundamental: 1, second: 0.5, third: 0.25))
        XCTAssertEqual(signal, 0.75, accuracy: 1e-12)
    }

    func testAliasesPreserveEveryOriginalSample() throws {
        for sampleRate in [7.0, 13.3, 24.0, 64.0] {
            for index in 0...100 {
                let time = Double(index) / sampleRate
                let original = try XCTUnwrap(ScientificModels.harmonicSignal(time: time, fundamental: 11.2, second: 0.35, third: 0.6))
                let alias = try XCTUnwrap(ScientificModels.sampledAliasSignal(time: time, fundamental: 11.2, second: 0.35, third: 0.6, sampleRate: sampleRate))
                XCTAssertEqual(original, alias, accuracy: 1e-11)
            }
        }
        XCTAssertEqual(ScientificModels.signedAlias(frequency: 7, sampleRate: 10), -3)
        XCTAssertEqual(ScientificModels.signedAlias(frequency: 13, sampleRate: 10), 3)
        XCTAssertEqual(ScientificModels.signedAlias(frequency: 20, sampleRate: 10), 0)
        XCTAssertNil(ScientificModels.signedAlias(frequency: 5, sampleRate: 0))
    }

    func testProportionalResponseMatchesTimeConstantAndFinalError() throws {
        let atTau = try XCTUnwrap(ScientificModels.proportionalStep(time: 1, plantTimeConstant: 3, proportionalGain: 2))
        XCTAssertEqual(atTau.closedLoopTimeConstant, 1)
        XCTAssertEqual(atTau.finalValue, 2.0 / 3, accuracy: 1e-12)
        XCTAssertEqual(atTau.value, 2.0 / 3 * (1 - exp(-1)), accuracy: 1e-12)
        XCTAssertEqual(atTau.steadyStateError, 1.0 / 3, accuracy: 1e-12)
        let initial = try XCTUnwrap(ScientificModels.proportionalStep(time: 0, plantTimeConstant: 3, proportionalGain: 2))
        XCTAssertEqual(initial.value, 0)
        let off = try XCTUnwrap(ScientificModels.proportionalStep(time: 3, plantTimeConstant: 3, proportionalGain: 0))
        XCTAssertEqual(off.value, 0)
        XCTAssertNil(ScientificModels.proportionalStep(time: 1, plantTimeConstant: 0, proportionalGain: 2))
        XCTAssertNil(ScientificModels.proportionalStep(time: -1, plantTimeConstant: 3, proportionalGain: 2))
    }

    func testPointChargeInverseSquarePotentialAndSignedField() throws {
        let first = try XCTUnwrap(ScientificModels.pointCharge(charge: 1e-9, distance: 1))
        let farther = try XCTUnwrap(ScientificModels.pointCharge(charge: 1e-9, distance: 2))
        let negative = try XCTUnwrap(ScientificModels.pointCharge(charge: -1e-9, distance: 1))
        XCTAssertEqual(first.radialField, 8.9875517862, accuracy: 1e-8)
        XCTAssertEqual(farther.radialField, first.radialField / 4, accuracy: 1e-12)
        XCTAssertEqual(farther.potential, first.potential / 2, accuracy: 1e-12)
        XCTAssertEqual(negative.radialField, -first.radialField, accuracy: 1e-12)
        XCTAssertEqual(negative.potential, -first.potential, accuracy: 1e-12)
        XCTAssertNil(ScientificModels.pointCharge(charge: 1e-9, distance: 0))
    }

    func testAMCarrierAndModulatedEnvelope() throws {
        let peak = try XCTUnwrap(ScientificModels.amplitudeModulation(time: 0, carrierFrequency: 60, messageFrequency: 4, modulationIndex: 0.65))
        XCTAssertEqual(peak, 1.65)
        let overmodulated = try XCTUnwrap(ScientificModels.amplitudeModulation(time: 0.125, carrierFrequency: 64, messageFrequency: 4, modulationIndex: 1.5))
        XCTAssertEqual(overmodulated, -0.5, accuracy: 1e-12)
        for index in 0...40 {
            let time = Double(index) / 100
            let unmodulated = try XCTUnwrap(ScientificModels.amplitudeModulation(time: time, carrierFrequency: 60, messageFrequency: 4, modulationIndex: 0))
            XCTAssertEqual(unmodulated, cos(2 * .pi * 60 * time), accuracy: 1e-12)
        }
        XCTAssertNil(ScientificModels.amplitudeModulation(time: 0, carrierFrequency: 2, messageFrequency: 4, modulationIndex: 1))
    }

    func testPowerTriangleAndReactiveSign() throws {
        let lagging = try XCTUnwrap(ScientificModels.acPower(voltageRMS: 120, currentRMS: 2, phaseDegrees: 60))
        let leading = try XCTUnwrap(ScientificModels.acPower(voltageRMS: 120, currentRMS: 2, phaseDegrees: -60))
        XCTAssertEqual(lagging.apparent, 240)
        XCTAssertEqual(lagging.real, 120, accuracy: 1e-10)
        XCTAssertEqual(lagging.reactive, 120 * sqrt(3), accuracy: 1e-10)
        XCTAssertEqual(lagging.apparent * lagging.apparent, lagging.real * lagging.real + lagging.reactive * lagging.reactive, accuracy: 1e-8)
        XCTAssertEqual(leading.real, lagging.real, accuracy: 1e-10)
        XCTAssertEqual(leading.reactive, -lagging.reactive, accuracy: 1e-10)
        XCTAssertNil(ScientificModels.acPower(voltageRMS: -120, currentRMS: 2, phaseDegrees: 60))
    }

    func testInstantaneousPowerAverageEqualsRealPower() throws {
        for phase in [-90.0, -35.0, 0.0, 35.0, 90.0] {
            let result = try XCTUnwrap(ScientificModels.acPower(voltageRMS: 120, currentRMS: 2, phaseDegrees: phase))
            var sum = 0.0
            let count = 2_000
            for index in 0..<count {
                sum += try XCTUnwrap(ScientificModels.instantaneousPower(time: 0.02 * Double(index) / Double(count), voltageRMS: 120, currentRMS: 2, phaseDegrees: phase))
            }
            XCTAssertEqual(sum / Double(count), result.real, accuracy: 1e-9)
        }
    }

    func testAllModelsRejectNonfiniteInputs() {
        XCTAssertNil(ScientificModels.harmonicSignal(time: .nan, fundamental: 1, second: 0, third: 0))
        XCTAssertNil(ScientificModels.sampledAliasSignal(time: .infinity, fundamental: 1, second: 0, third: 0, sampleRate: 10))
        XCTAssertNil(ScientificModels.proportionalStep(time: 1, plantTimeConstant: .infinity, proportionalGain: 2))
        XCTAssertNil(ScientificModels.pointCharge(charge: .nan, distance: 1))
        XCTAssertNil(ScientificModels.amplitudeModulation(time: .infinity, carrierFrequency: 10, messageFrequency: 1, modulationIndex: 1))
        XCTAssertNil(ScientificModels.acPower(voltageRMS: 1, currentRMS: .infinity, phaseDegrees: 0))
        XCTAssertNil(ScientificModels.instantaneousPower(time: .nan, voltageRMS: 120, currentRMS: 2, phaseDegrees: 0))
    }
}
