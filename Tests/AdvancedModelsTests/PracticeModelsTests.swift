import XCTest
@testable import CircuitAdvanced

final class PracticeModelsTests: XCTestCase {
    func testProbeLoadingAndCapacitivePole() throws {
        let dc = try XCTUnwrap(PracticeModels.probe(source: 5, top: 1_000_000, bottom: 1_000_000, input: 1_000_000, capacitance: 10e-12, frequency: 0))
        XCTAssertEqual(dc.loaded, 5.0 / 3, accuracy: 1e-12)
        XCTAssertEqual(dc.resistance, 1_000_000.0 / 3, accuracy: 1e-8)
        XCTAssertEqual(dc.phase, 0)
        let corner = try XCTUnwrap(PracticeModels.probe(source: 5, top: 1_000_000, bottom: 1_000_000, input: 1_000_000, capacitance: 10e-12, frequency: 1 / (2 * .pi * dc.timeConstant)))
        XCTAssertEqual(corner.magnitude, dc.loaded / sqrt(2), accuracy: 1e-12)
        XCTAssertEqual(corner.phase, -.pi / 4, accuracy: 1e-12)
        XCTAssertNil(PracticeModels.probe(source: 5, top: 0, bottom: 1, input: 1, capacitance: 1, frequency: 1))
        XCTAssertNil(PracticeModels.probe(source: .nan, top: 1, bottom: 1, input: 1, capacitance: 1, frequency: 1))
    }
    func testDividerCornersContainIndependentGridAndRequirements() throws {
        let bounds = try XCTUnwrap(PracticeModels.dividerDesign(source: 5, resistance: 1_000, load: 100_000, resistorTolerance: 0.01, sourceTolerance: 0.01))
        for s in stride(from: 0.99, through: 1.01, by: 0.005) {
            for a in stride(from: 0.99, through: 1.01, by: 0.005) {
                for b in stride(from: 0.99, through: 1.01, by: 0.005) {
                    let r1 = 1000 * a, r2 = 1000 * b
                    let lower = r2 * 100_000 / (r2 + 100_000)
                    let output = 5 * s * lower / (r1 + lower)
                    XCTAssertGreaterThanOrEqual(output + 1e-12, bounds.minimum)
                    XCTAssertLessThanOrEqual(output - 1e-12, bounds.maximum)
                }
            }
        }
        XCTAssertTrue(bounds.meets(target: 2.5, error: 0.1, currentLimit: 0.005, powerRating: 0.25))
        XCTAssertFalse(bounds.meets(target: 2.5, error: 0.001, currentLimit: 0.005, powerRating: 0.25))
        XCTAssertNil(PracticeModels.dividerDesign(source: 5, resistance: 1000, load: 1000, resistorTolerance: 1, sourceTolerance: 0))
    }
    func testADCBinCenteredQuantizationBoundAndClipping() throws {
        for bits in [2, 6, 12] {
            let step = 3.3 / Double(1 << bits)
            for index in 0...1000 {
                let voltage = 3.3 * Double(index) / 1000
                let sample = try XCTUnwrap(PracticeModels.quantize(voltage: voltage, bits: bits))
                XCTAssertLessThanOrEqual(abs(sample.voltage - voltage), step / 2 + 1e-12)
            }
        }
        XCTAssertEqual(PracticeModels.quantize(voltage: -20, bits: 8)?.code, 0)
        XCTAssertEqual(PracticeModels.quantize(voltage: 20, bits: 8)?.code, 255)
        XCTAssertNil(PracticeModels.quantize(voltage: .infinity, bits: 8))
        XCTAssertNil(PracticeModels.quantize(voltage: 1, bits: 30))
    }
    func testThermalExactStepAndConstantPowerEquilibrium() throws {
        let atTau = try XCTUnwrap(PracticeModels.thermalStep(temperature: 20, ambient: 20, power: 6, capacity: 20, conductance: 0.5, step: 40))
        XCTAssertEqual(atTau, 20 + 12 * (1 - exp(-1)), accuracy: 1e-12)
        let equilibrium = try XCTUnwrap(PracticeModels.thermalStep(temperature: 32, ambient: 20, power: 6, capacity: 20, conductance: 0.5, step: 1))
        XCTAssertEqual(equilibrium, 32, accuracy: 1e-12)
        XCTAssertNil(PracticeModels.thermalStep(temperature: 20, ambient: 20, power: 6, capacity: 0, conductance: 1, step: 1))
    }
    func testCapstoneEnergyConservationAndUnderpoweredFailure() throws {
        let normal = try XCTUnwrap(PracticeModels.thermal(.init()))
        for sample in normal.samples {
            XCTAssertEqual(sample.electricalEnergy, sample.storedEnergy + sample.environmentalEnergy, accuracy: 1e-9)
            XCTAssertGreaterThanOrEqual(sample.environmentalEnergy, -1e-12)
        }
        XCTAssertLessThan(normal.settlingError, 1)
        XCTAssertLessThan(normal.maximumTemperature, 32)
        var weak = PracticeModels.ThermalConfiguration(); weak.supply = 6
        let failed = try XCTUnwrap(PracticeModels.thermal(weak))
        XCTAssertLessThanOrEqual(failed.maximumTemperature, 23)
        XCTAssertGreaterThan(failed.finalError, 5)
        XCTAssertLessThan(abs(failed.energyResidual), 1e-9)
    }
    func testCapstoneReportRoundTripAndInvalidConfiguration() throws {
        let report = try XCTUnwrap(PracticeModels.thermal(.init()))
        let decoded = try JSONDecoder().decode(PracticeModels.ThermalReport.self, from: Data(report.json().utf8))
        XCTAssertEqual(decoded.configuration, report.configuration)
        XCTAssertEqual(decoded.samples.count, report.samples.count)
        var c = PracticeModels.ThermalConfiguration(); c.step = 0
        XCTAssertNil(PracticeModels.thermal(c))
        c.step = 0.5; c.conductance = .nan
        XCTAssertNil(PracticeModels.thermal(c))
    }
}
