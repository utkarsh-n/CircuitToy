import XCTest
@testable import CircuitAdvanced

final class SystemsModelsTests: XCTestCase {
    func testConvolutionKnownSequenceIdentityAndSum() throws {
        XCTAssertEqual(try XCTUnwrap(SystemsModels.convolution([1, 2, 3], [1, 1])), [1, 3, 5, 3])
        XCTAssertEqual(try XCTUnwrap(SystemsModels.convolution([1, -2, 3], [1])), [1, -2, 3])
        let x = [1.0, 2, -1], h = [0.5, -0.25, 1]
        let output = try XCTUnwrap(SystemsModels.convolution(x, h))
        XCTAssertEqual(output, try XCTUnwrap(SystemsModels.convolution(h, x)))
        XCTAssertEqual(output.reduce(0, +), x.reduce(0, +) * h.reduce(0, +), accuracy: 1e-12)
        XCTAssertNil(SystemsModels.convolution([], [1]))
        XCTAssertNil(SystemsModels.convolution([.nan], [1]))
    }

    func testDFTAmplitudeDCNyquistAndParseval() throws {
        let dc = try XCTUnwrap(SystemsModels.spectrum(Array(repeating: 2, count: 64), sampleRate: 64, window: .rectangular))
        XCTAssertEqual(dc.amplitudes[0], 2, accuracy: 1e-12)
        XCTAssertEqual(dc.binSpacing, 1)
        XCTAssertEqual(dc.coherentGain, 1)
        let nyquist = (0..<64).map { $0.isMultiple(of: 2) ? 1.0 : -1.0 }
        XCTAssertEqual(try XCTUnwrap(SystemsModels.spectrum(nyquist, sampleRate: 64, window: .rectangular)).amplitudes[32], 1, accuracy: 1e-12)
        let samples: [Double] = (0..<64).map { index -> Double in
            let time: Double = Double(index) / 64.0
            let firstAngle: Double = 2.0 * Double.pi * 8.0 * time
            let secondAngle: Double = 2.0 * Double.pi * 13.0 * time
            let firstTone: Double = sin(firstAngle)
            let secondTone: Double = 0.5 * cos(secondAngle)
            return 0.3 + firstTone + secondTone
        }
        let spectrum = try XCTUnwrap(SystemsModels.spectrum(samples, sampleRate: 64, window: .rectangular))
        XCTAssertEqual(spectrum.amplitudes[8], 1, accuracy: 1e-12)
        XCTAssertEqual(spectrum.amplitudes[13], 0.5, accuracy: 1e-12)
        let spectralEnergy = pow(spectrum.amplitudes[0], 2) + pow(spectrum.amplitudes[32], 2) + spectrum.amplitudes[1..<32].map { $0 * $0 / 2 }.reduce(0, +)
        XCTAssertEqual(spectralEnergy, samples.map { $0 * $0 }.reduce(0, +) / 64, accuracy: 1e-12)
        let hann = try XCTUnwrap(SystemsModels.spectrum(samples, sampleRate: 64, window: .hann))
        XCTAssertEqual(hann.coherentGain, 63.0 / 128, accuracy: 1e-12)
        XCTAssertNil(SystemsModels.spectrum([1, 2, 3], sampleRate: 64, window: .hann))
    }

    func testFIRImpulseAndFrequencyZeros() throws {
        let taps = [0.25, 0.5, 0.25]
        XCTAssertEqual(try XCTUnwrap(SystemsModels.fir([1, 0, 0, 0], taps: taps)), [0.25, 0.5, 0.25, 0])
        XCTAssertEqual(try XCTUnwrap(SystemsModels.firMagnitude(taps: taps, normalizedFrequency: 0)), 1, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(SystemsModels.firMagnitude(taps: taps, normalizedFrequency: 0.5)), 0, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(SystemsModels.firMagnitude(taps: taps, normalizedFrequency: 0.25)), 0.5, accuracy: 1e-12)
        let input = (0..<64).map { sin(.pi / 2 * Double($0)) }
        let filtered = try XCTUnwrap(SystemsModels.fir(input, taps: taps))
        for index in 2..<64 { XCTAssertEqual(filtered[index], 0.5 * sin(.pi / 2 * Double(index - 1)), accuracy: 1e-12) }
        XCTAssertNil(SystemsModels.firMagnitude(taps: taps, normalizedFrequency: 0.6))
    }

    func testPoleStepStableMarginalUnstableAndRepeatedPole() throws {
        XCTAssertEqual(try XCTUnwrap(SystemsModels.poleStep(time: 0, real: -0.6, imaginary: 2)), 0)
        XCTAssertEqual(try XCTUnwrap(SystemsModels.poleStep(time: 30, real: -0.6, imaginary: 2)), 1, accuracy: 1e-7)
        XCTAssertEqual(try XCTUnwrap(SystemsModels.poleStep(time: .pi / 2, real: 0, imaginary: 2)), 2, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(SystemsModels.poleStep(time: 1, real: -1, imaginary: 0)), 1 - 2 / exp(1), accuracy: 1e-12)
        let growing = try XCTUnwrap(SystemsModels.poleStep(time: .pi, real: 0.2, imaginary: 2))
        XCTAssertLessThan(growing, -0.8)
        XCTAssertNil(SystemsModels.poleStep(time: -1, real: -1, imaginary: 2))
    }

    func testSampledProportionalControllerHasKnownClosedLoopRecurrence() throws {
        let run = try XCTUnwrap(SystemsModels.pid(.init(proportional: 2, integral: 0, derivative: 0, actuatorLimit: 5, disturbance: 0)))
        let eigenvalue = 3 * exp(-0.01) - 2
        for index in [1, 10, 100, 300] {
            XCTAssertEqual(run.output[index], 2.0 / 3 * (1 - pow(eigenvalue, Double(index))), accuracy: 1e-12)
        }
    }

    func testPIDLimitsAntiWindupAndTimeStepConvergence() throws {
        var config = SystemsModels.PIDConfiguration(proportional: 2, integral: 5, derivative: 0, actuatorLimit: 0.3, disturbance: 0)
        let protected = try XCTUnwrap(SystemsModels.pid(config))
        config.antiWindup = false
        let unprotected = try XCTUnwrap(SystemsModels.pid(config))
        XCTAssertTrue(protected.command.allSatisfy { abs($0) <= 0.3 })
        XCTAssertGreaterThan(unprotected.integralTerm[399], protected.integralTerm[399] + 5)
        let coarse = try XCTUnwrap(SystemsModels.pid(.init()))
        var fineConfig = SystemsModels.PIDConfiguration(); fineConfig.step = 0.005
        let fine = try XCTUnwrap(SystemsModels.pid(fineConfig))
        XCTAssertLessThan(zip(coarse.output, stride(from: 0, to: fine.output.count, by: 2).map { fine.output[$0] }).map { abs($0 - $1) }.max() ?? 1, 0.03)
        var invalid = config; invalid.step = 0
        XCTAssertNil(SystemsModels.pid(invalid))
    }

    func testLQRGainsSatisfyRiccatiEquation() throws {
        let unit = try XCTUnwrap(SystemsModels.lqrGains(effortWeight: 1))
        XCTAssertEqual(unit.position, 1)
        XCTAssertEqual(unit.velocity, sqrt(3), accuracy: 1e-12)
        for r in [0.05, 0.5, 1.0, 5.0] {
            let gains = try XCTUnwrap(SystemsModels.lqrGains(effortWeight: r))
            let p12 = r * gains.position, p22 = r * gains.velocity, p11 = p12 * p22 / r
            XCTAssertEqual(1 - p12 * p12 / r, 0, accuracy: 1e-12)
            XCTAssertEqual(p11 - p12 * p22 / r, 0, accuracy: 1e-12)
            XCTAssertEqual(2 * p12 + 1 - p22 * p22 / r, 0, accuracy: 1e-12)
        }
        XCTAssertNil(SystemsModels.lqrGains(effortWeight: 0))
    }

    func testObserverErrorMatchesIndependentRepeatedPoleSolution() throws {
        let run = try XCTUnwrap(SystemsModels.observer(effortWeight: 1, observerSpeed: 4, sensorRipple: 0, initialVelocity: 0))
        let index = 200 // t = 1 s
        XCTAssertEqual(run.position[index] - run.estimatedPosition[index], -3 * exp(-4), accuracy: 1e-8)
        XCTAssertEqual(run.velocity[index] - run.estimatedVelocity[index], -16 * exp(-4), accuracy: 1e-8)
        let fine = try XCTUnwrap(SystemsModels.observer(effortWeight: 1, observerSpeed: 4, sensorRipple: 0, initialVelocity: 0, step: 0.0025))
        XCTAssertEqual(run.position.last ?? 1, fine.position.last ?? 0, accuracy: 1e-7)
        XCTAssertEqual(run.cost, fine.cost, accuracy: 1e-6)
    }

    func testPlaneWaveEnergyAndSpeedIdentities() throws {
        let wave = try XCTUnwrap(SystemsModels.planeWave(amplitude: 10, frequency: 10e6, position: 0, time: 0))
        XCTAssertEqual(wave.electric / wave.magnetic, SystemsModels.lightSpeed, accuracy: 1e-6)
        XCTAssertEqual(wave.wavelength, 29.9792458, accuracy: 1e-9)
        XCTAssertEqual(wave.poynting, SystemsModels.lightSpeed * wave.energyDensity, accuracy: 1e-12)
        let doubled = try XCTUnwrap(SystemsModels.planeWave(amplitude: 20, frequency: 10e6, position: 0, time: 0))
        XCTAssertEqual(doubled.averageIntensity, 4 * wave.averageIntensity, accuracy: 1e-12)
        let samples = try (0..<1_000).map { try XCTUnwrap(SystemsModels.planeWave(amplitude: 10, frequency: 10e6, position: 0, time: Double($0) / 1_000 / 10e6)).poynting }
        XCTAssertEqual(samples.reduce(0, +) / 1_000, wave.averageIntensity, accuracy: 1e-12)
        XCTAssertNil(SystemsModels.planeWave(amplitude: 10, frequency: 0, position: 0, time: 0))
    }

    func testFaradayEMFEqualsNegativeFluxDerivative() throws {
        let time = 0.006, delta = 1e-7
        let now = try XCTUnwrap(SystemsModels.faraday(time: time, turns: 20, area: 0.01, fieldAmplitude: 0.02, frequency: 20))
        let before = try XCTUnwrap(SystemsModels.faraday(time: time - delta, turns: 20, area: 0.01, fieldAmplitude: 0.02, frequency: 20))
        let after = try XCTUnwrap(SystemsModels.faraday(time: time + delta, turns: 20, area: 0.01, fieldAmplitude: 0.02, frequency: 20))
        XCTAssertEqual(now.emf, -20 * (after.fluxPerTurn - before.fluxPerTurn) / (2 * delta), accuracy: 1e-9)
        let peak = try XCTUnwrap(SystemsModels.faraday(time: 1.0 / 80, turns: 20, area: 0.01, fieldAmplitude: 0.02, frequency: 20))
        XCTAssertEqual(peak.emf, 0.5026548245743669, accuracy: 1e-12)
    }

    func testReflectionBoundariesAndPowerConservation() throws {
        XCTAssertEqual(try XCTUnwrap(SystemsModels.reflection(characteristic: 50, load: nil)).coefficient, 1)
        XCTAssertEqual(try XCTUnwrap(SystemsModels.reflection(characteristic: 50, load: 0)).coefficient, -1)
        XCTAssertEqual(try XCTUnwrap(SystemsModels.reflection(characteristic: 50, load: 50)).coefficient, 0)
        for load in [0.0, 20, 50, 100, 300] {
            let result = try XCTUnwrap(SystemsModels.reflection(characteristic: 50, load: load))
            let loadCurrent = (1 - result.coefficient) / 50
            XCTAssertEqual(result.loadVoltage * loadCurrent, result.absorbedFraction / 50, accuracy: 1e-12)
        }
        let before = try XCTUnwrap(SystemsModels.linePulse(position: 0.5, time: 12e-9, length: 1, speed: 1e8, width: 20e-9, characteristic: 50, load: 100))
        XCTAssertEqual(before.incident, 1); XCTAssertEqual(before.reflected, 0)
        let overlap = try XCTUnwrap(SystemsModels.linePulse(position: 0.5, time: 18e-9, length: 1, speed: 1e8, width: 20e-9, characteristic: 50, load: 100))
        XCTAssertEqual(overlap.total, 4.0 / 3, accuracy: 1e-12)
        XCTAssertNil(SystemsModels.reflection(characteristic: 0, load: 50))
        XCTAssertEqual(try XCTUnwrap(SystemsModels.reflection(characteristic: Double.greatestFiniteMagnitude / 2, load: Double.greatestFiniteMagnitude)).coefficient, 1.0 / 3, accuracy: 1e-12)
    }

    func testBPSKTheorySeedAndGaussianVariance() throws {
        let first = try XCTUnwrap(SystemsModels.bpsk(ebN0DB: 0, count: 10_000, seed: 23))
        XCTAssertEqual(first.theoreticalBER, 0.07864960352514257, accuracy: 1e-14)
        let repeated = try XCTUnwrap(SystemsModels.bpsk(ebN0DB: 0, count: 10_000, seed: 23))
        XCTAssertEqual(first.symbols.map(\.inPhase), repeated.symbols.map(\.inPhase))
        let noise = first.symbols.map { $0.inPhase - ($0.bit == 1 ? 1 : -1) }
        XCTAssertEqual(noise.reduce(0, +) / 10_000, 0, accuracy: 0.03)
        XCTAssertEqual(noise.map { $0 * $0 }.reduce(0, +) / 10_000, 0.5, accuracy: 0.03)
        XCTAssertEqual(Double(first.errors) / 10_000, first.theoreticalBER, accuracy: 0.02)
        XCTAssertEqual(try XCTUnwrap(SystemsModels.bpsk(ebN0DB: 40, count: 512)).errors, 0)
        XCTAssertNil(SystemsModels.bpsk(ebN0DB: .nan))
    }

    func testCapacityAndExhaustiveHammingSingleErrorCorrection() throws {
        XCTAssertEqual(try XCTUnwrap(SystemsModels.capacity(bandwidth: 10_000, snrDB: 0)), 10_000)
        XCTAssertEqual(try XCTUnwrap(SystemsModels.capacity(bandwidth: 10_000, snrDB: 10)), 34_594.31618637298, accuracy: 1e-8)
        for data in 0...15 {
            let encoded = try XCTUnwrap(SystemsModels.hammingEncode(data))
            XCTAssertEqual(try XCTUnwrap(SystemsModels.hammingDecode(encoded)).syndrome, 0)
            for error in 1...7 {
                let decoded = try XCTUnwrap(SystemsModels.hammingDecode(encoded ^ (1 << (error - 1))))
                XCTAssertEqual(decoded.syndrome, error)
                XCTAssertEqual(decoded.correctedWord, encoded)
                XCTAssertEqual(decoded.data, data)
            }
        }
        let miscorrected = try XCTUnwrap(SystemsModels.hammingDecode(3))
        XCTAssertEqual(miscorrected.syndrome, 3)
        XCTAssertNotEqual(miscorrected.data, 0) // two errors on the all-zero word are not correctable
        XCTAssertNil(SystemsModels.hammingEncode(16))
        XCTAssertNil(SystemsModels.hammingDecode(128))
    }

    func testNetworkDelayAccountingConservationAndPropagationIndependence() throws {
        let run = try XCTUnwrap(SystemsModels.network(arrivalRate: 50, payloadBytes: 1_000, bitRate: 500_000, distance: 100_000, capacity: 8, lossProbability: 0))
        XCTAssertEqual(run.transmissionDelay, 0.016, accuracy: 1e-12)
        XCTAssertEqual(run.propagationDelay, 0.0005, accuracy: 1e-12)
        XCTAssertEqual(run.averageQueueDelay, 0, accuracy: 1e-12)
        XCTAssertEqual(run.averageDeliveryDelay, 0.0165, accuracy: 1e-12)
        let overloaded = try XCTUnwrap(SystemsModels.network(arrivalRate: 100, payloadBytes: 1_000, bitRate: 100_000, distance: 100_000, capacity: 4, lossProbability: 0.2))
        XCTAssertGreaterThan(overloaded.overflow, 0)
        XCTAssertEqual(overloaded.delivered + overloaded.linkLoss + overloaded.overflow, overloaded.arrivals)
        XCTAssertLessThanOrEqual(overloaded.queue.max() ?? 10, 4)
        let farther = try XCTUnwrap(SystemsModels.network(arrivalRate: 100, payloadBytes: 1_000, bitRate: 100_000, distance: 200_000, capacity: 4, lossProbability: 0.2))
        XCTAssertEqual(overloaded.packets.map(\.start), farther.packets.map(\.start))
        XCTAssertEqual(overloaded.overflow, farther.overflow)
        XCTAssertEqual(overloaded.averageDeliveryDelay + 0.0005, farther.averageDeliveryDelay, accuracy: 1e-12)
        let allLost = try XCTUnwrap(SystemsModels.network(arrivalRate: 50, payloadBytes: 1_000, bitRate: 500_000, distance: 0, capacity: 8, lossProbability: 1))
        XCTAssertEqual(allLost.delivered, 0)
        XCTAssertNil(SystemsModels.network(arrivalRate: 50, payloadBytes: 1_000, bitRate: 500_000, distance: 0, capacity: 0, lossProbability: 0))
    }
}
