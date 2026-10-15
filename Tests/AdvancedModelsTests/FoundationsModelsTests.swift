import Foundation
import Testing
@testable import CircuitAdvanced

private func foundationClose(_ a: Double, _ b: Double, absolute: Double = 1e-12, relative: Double = 1e-8) -> Bool {
    abs(a-b) <= absolute + relative*max(abs(a), abs(b))
}

@Test func foundationsCalculusDerivativeAndIndependentQuadrature() throws {
    let t = 0.37, delta = 1e-6
    let p = try #require(FoundationsModels.sineCurrent(time: t, mean: 0.001, amplitude: 0.002, frequency: 1.7))
    let a = try #require(FoundationsModels.sineCurrent(time: t-delta, mean: 0.001, amplitude: 0.002, frequency: 1.7))
    let b = try #require(FoundationsModels.sineCurrent(time: t+delta, mean: 0.001, amplitude: 0.002, frequency: 1.7))
    #expect(foundationClose((b.charge-a.charge)/(2*delta), p.current))
    let count = 10_000, width = t/Double(count)
    let area = (0..<count).reduce(0.0) { sum, index in
        let time = (Double(index)+0.5)*width
        return sum + (0.001+0.002*sin(2*Double.pi*1.7*time))*width
    }
    #expect(foundationClose(area, p.charge, absolute: 1e-11))
}

@Test func foundationsCalculusPeriodAndRampScaling() throws {
    let period = try #require(FoundationsModels.sineCurrent(time: 0.5, mean: 0.001, amplitude: 0.003, frequency: 2))
    #expect(foundationClose(period.charge, 0.0005))
    let first = try #require(FoundationsModels.rampCurrent(time: 1, initial: 0, slope: 0.002))
    let second = try #require(FoundationsModels.rampCurrent(time: 2, initial: 0, slope: 0.002))
    #expect(first.charge == 0.001)
    #expect(second.charge == 4*first.charge)
    #expect(FoundationsModels.sineCurrent(time: 1, mean: 0, amplitude: 1, frequency: 0) == nil)
    #expect(FoundationsModels.rampCurrent(time: -1, initial: 1, slope: 1) == nil)
}

@Test func foundationsNodalMatchesIndependentSeriesParallelReduction() throws {
    let point = try #require(FoundationsModels.twoNode(supply: 12, r1: 1_000, r2: 1_000, r3: 1_000, r4: 1_000))
    // R2 in parallel with (R3+R4) = 2/3 kΩ, then a simple voltage divider.
    #expect(foundationClose(point.va, 4.8))
    #expect(foundationClose(point.vb, 2.4))
    #expect(abs(point.kclA) < 1e-12)
    #expect(abs(point.kclB) < 1e-12)
    let doubled = try #require(FoundationsModels.twoNode(supply: 24, r1: 1_000, r2: 1_000, r3: 1_000, r4: 1_000))
    #expect(foundationClose(doubled.va, 2*point.va))
    #expect(FoundationsModels.twoNode(supply: 1, r1: 0, r2: 1, r3: 1, r4: 1) == nil)
}

@Test func foundationsRCComplexCutoffAndPole() throws {
    let point = try #require(FoundationsModels.rcTransfer(resistance: 1_000, capacitance: 1e-6, sigma: 0, omega: 1_000))
    #expect(foundationClose(point.real, 0.5))
    #expect(foundationClose(point.imaginary, -0.5))
    #expect(foundationClose(point.magnitude, 1/sqrt(2.0)))
    #expect(foundationClose(point.phase, -Double.pi/4))
    #expect(FoundationsModels.rcTransfer(resistance: 1_000, capacitance: 1e-6, sigma: -1_000, omega: 0) == nil)
    let dc = try #require(FoundationsModels.rcTransfer(resistance: 1_000, capacitance: 1e-6, sigma: 0, omega: 0))
    #expect(dc.real == 1 && dc.imaginary == 0)
}

@Test func foundationsODEExactForwardBackwardReferences() throws {
    let point = try #require(FoundationsModels.firstOrder(initial: 0, target: 1, tau: 1, step: 1, count: 1))
    #expect(foundationClose(point.exact.last!, 1-exp(-1.0)))
    #expect(point.forwardEuler.last == 1)
    #expect(point.backwardEuler.last == 0.5)
    let unstable = try #require(FoundationsModels.firstOrder(initial: 0, target: 1, tau: 1, step: 2.5, count: 4))
    #expect(foundationClose(unstable.forwardEuler.last!, -4.0625))
    #expect(unstable.backwardEuler.allSatisfy { $0 >= 0 && $0 <= 1 })
}

@Test func foundationsODEConvergesAndPreservesEquilibrium() throws {
    let coarse = try #require(FoundationsModels.firstOrder(initial: 0, target: 1, tau: 1, step: 0.1, count: 10))
    let fine = try #require(FoundationsModels.firstOrder(initial: 0, target: 1, tau: 1, step: 0.01, count: 100))
    #expect(abs(fine.backwardEuler.last!-fine.exact.last!) < abs(coarse.backwardEuler.last!-coarse.exact.last!)/8)
    #expect(abs(fine.forwardEuler.last!-fine.exact.last!) < abs(coarse.forwardEuler.last!-coarse.exact.last!)/8)
    let equilibrium = try #require(FoundationsModels.firstOrder(initial: 2, target: 2, tau: 1, step: 3, count: 5))
    #expect(equilibrium.exact == Array(repeating: 2.0, count: 6))
    #expect(equilibrium.forwardEuler == equilibrium.exact)
    #expect(FoundationsModels.firstOrder(initial: 0, target: 1, tau: 0, step: 0.1, count: 1) == nil)
}

@Test func foundationsToleranceMeanMatchesIndependentIntegration() throws {
    let point = try #require(FoundationsModels.tolerance(supply: 5, nominalResistance: 1_000, fraction: 0.1, threshold: 0.005))
    let count = 10_000
    let currents = (0..<count).map { 5/(900+(Double($0)+0.5)*200/Double(count)) }
    let mean = currents.reduce(0, +)/Double(count)
    let variance = currents.reduce(0) { $0+pow($1-mean, 2) }/Double(count)
    #expect(foundationClose(point.meanCurrent, mean, absolute: 1e-11))
    #expect(foundationClose(point.standardDeviation, sqrt(variance), absolute: 1e-11))
    #expect(foundationClose(point.probabilityAbove, 0.5))
    #expect(point.meanCurrent > 0.005)
    #expect(foundationClose(point.minimumCurrent, 5/1100))
    #expect(foundationClose(point.maximumCurrent, 5/900))
}

@Test func foundationsToleranceDegenerateAndCDFEdges() throws {
    let deterministic = try #require(FoundationsModels.tolerance(supply: 5, nominalResistance: 1_000, fraction: 0, threshold: 0.005))
    #expect(deterministic.meanCurrent == 0.005)
    #expect(deterministic.standardDeviation == 0)
    #expect(deterministic.probabilityAbove == 0)
    #expect(FoundationsModels.currentCDF(current: 0.005, supply: 5, nominalResistance: 1_000, fraction: 0) == 1)
    #expect(FoundationsModels.currentCDF(current: -1, supply: 0, nominalResistance: 1_000, fraction: 0.1) == 0)
    #expect(FoundationsModels.currentCDF(current: 1, supply: 5, nominalResistance: 1_000, fraction: 0.1) == 1)
    #expect(FoundationsModels.tolerance(supply: 5, nominalResistance: 1_000, fraction: 1, threshold: 0) == nil)
}

@Test func foundationsSamplingIsRepeatableAndBiasSurvivesAveraging() throws {
    let first = try #require(FoundationsModels.resistorSamples(supply: 5, nominalResistance: 1_000, fraction: 0.1, count: 500, seed: 17, calibrationOffset: 0))
    let repeated = try #require(FoundationsModels.resistorSamples(supply: 5, nominalResistance: 1_000, fraction: 0.1, count: 500, seed: 17, calibrationOffset: 0))
    let biased = try #require(FoundationsModels.resistorSamples(supply: 5, nominalResistance: 1_000, fraction: 0.1, count: 500, seed: 17, calibrationOffset: 0.0005))
    #expect(first.measuredCurrents == repeated.measuredCurrents)
    #expect(first.measuredCurrents.allSatisfy { $0 >= 5/1100 && $0 <= 5/900 })
    #expect(foundationClose(biased.mean-first.mean, 0.0005))
    #expect(foundationClose(biased.sampleStandardDeviation!, first.sampleStandardDeviation!))
    let directMean = first.measuredCurrents.reduce(0, +)/500
    let directVariance = first.measuredCurrents.reduce(0) { $0+pow($1-directMean, 2) }/499
    #expect(foundationClose(first.mean, directMean))
    #expect(foundationClose(first.sampleStandardDeviation!, sqrt(directVariance)))
    #expect(foundationClose(first.standardError!, sqrt(directVariance/500)))
    let single = try #require(FoundationsModels.resistorSamples(supply: 5, nominalResistance: 1_000, fraction: 0.1, count: 1, seed: 17, calibrationOffset: 0))
    #expect(single.sampleStandardDeviation == nil && single.standardError == nil)
}

@Test func foundationsMechanicalWorkProjectionAndSign() throws {
    #expect(FoundationsModels.mechanicalWork(force: 5, displacement: 2, angleDegrees: 0) == 10)
    #expect(FoundationsModels.mechanicalWork(force: 5, displacement: 2, angleDegrees: 180) == -10)
    #expect(abs(try #require(FoundationsModels.mechanicalWork(force: 5, displacement: 2, angleDegrees: 90))) < 1e-12)
    #expect(FoundationsModels.mechanicalWork(force: -1, displacement: 2, angleDegrees: 0) == nil)
}

@Test func foundationsCarrierGeometryAndJouleConservation() throws {
    let point = try #require(FoundationsModels.conductor(density: 1e22, mobility: 0.1, length: 0.01, area: 1e-6, voltage: -1))
    #expect(foundationClose(point.conductivity, 160.2176634))
    #expect(point.current < 0)
    #expect(point.power > 0)
    #expect(foundationClose(point.power, point.current*point.current*point.resistance))
    let twice = try #require(FoundationsModels.conductor(density: 2e22, mobility: 0.1, length: 0.01, area: 1e-6, voltage: -1))
    #expect(foundationClose(twice.resistance, point.resistance/2))
}

@Test func foundationsHeatEnergyAndPhotonReference() throws {
    let heat = try #require(FoundationsModels.heating(power: 10, mass: 0.05, specificHeat: 900, time: 30, initialTemperature: 300))
    #expect(heat.energy == 300)
    #expect(foundationClose((heat.temperature-300)*0.05*900, heat.energy))
    let photon = try #require(FoundationsModels.photon(wavelength: 500e-9))
    #expect(foundationClose(photon.frequency, 599_584_916_000_000))
    #expect(foundationClose(photon.electronVolts, 2.479683968664005, absolute: 1e-12))
    #expect(FoundationsModels.heating(power: 10, mass: 0, specificHeat: 900, time: 30, initialTemperature: 300) == nil)
    #expect(FoundationsModels.photon(wavelength: 0) == nil)
}

@Test func foundationsRLContinuityKVLAndEnergyDerivative() throws {
    let t = 0.001, delta = 1e-8
    let first = try #require(FoundationsModels.rl(time: 0, supply: 5, resistance: 100, inductance: 0.1, initialCurrent: 0))
    #expect(first.current == 0 && first.voltage == 5)
    let point = try #require(FoundationsModels.rl(time: t, supply: 5, resistance: 100, inductance: 0.1, initialCurrent: 0))
    #expect(foundationClose(point.current, 0.05*(1-exp(-1.0))))
    #expect(foundationClose(point.voltage+100*point.current, 5))
    let a = try #require(FoundationsModels.rl(time: t-delta, supply: 5, resistance: 100, inductance: 0.1, initialCurrent: 0))
    let b = try #require(FoundationsModels.rl(time: t+delta, supply: 5, resistance: 100, inductance: 0.1, initialCurrent: 0))
    #expect(foundationClose((b.energy-a.energy)/(2*delta), point.voltage*point.current, absolute: 1e-10))
    let release = try #require(FoundationsModels.rl(time: 0, supply: 0, resistance: 100, inductance: 0.1, initialCurrent: 0.05))
    #expect(release.current == 0.05 && release.voltage == -5)
}

@Test func foundationsRLCInitialAndCriticalReference() throws {
    let initial = try #require(FoundationsModels.rlcStep(time: 0, supply: 5, resistance: 2, inductance: 1, capacitance: 1))
    #expect(initial.voltage == 0 && initial.current == 0)
    let critical = try #require(FoundationsModels.rlcStep(time: 1, supply: 5, resistance: 2, inductance: 1, capacitance: 1))
    #expect(critical.regime == "Critical")
    #expect(foundationClose(critical.voltage, 5*(1-2*exp(-1.0))))
    #expect(foundationClose(critical.current, 5*exp(-1.0)))
    let lossless = try #require(FoundationsModels.rlcStep(time: Double.pi, supply: 5, resistance: 0, inductance: 1, capacitance: 1))
    #expect(foundationClose(lossless.voltage, 10))
    #expect(abs(lossless.current) < 1e-12)
}

@Test func foundationsRLCConstitutiveODEAcrossAllDampingRegimes() throws {
    let delta = 1e-5, t = 0.7
    for resistance in [0.5, 2, 5] {
        let a = try #require(FoundationsModels.rlcStep(time: t-delta, supply: 3, resistance: resistance, inductance: 1, capacitance: 1))
        let p = try #require(FoundationsModels.rlcStep(time: t, supply: 3, resistance: resistance, inductance: 1, capacitance: 1))
        let b = try #require(FoundationsModels.rlcStep(time: t+delta, supply: 3, resistance: resistance, inductance: 1, capacitance: 1))
        #expect(foundationClose((b.voltage-a.voltage)/(2*delta), p.current, absolute: 1e-9))
        #expect(foundationClose((b.current-a.current)/(2*delta)+resistance*p.current+p.voltage, 3, absolute: 1e-8))
    }
}

@Test func foundationsACResonanceAndQualityFactor() throws {
    let point = try #require(FoundationsModels.seriesAC(frequency: 1/(2*Double.pi), voltagePeak: 5, resistance: 0.5, inductance: 1, capacitance: 1))
    #expect(foundationClose(point.currentPeak, 10))
    #expect(abs(point.currentPhase) < 1e-12)
    #expect(point.quality == 2)
    #expect(foundationClose(point.bandwidth, 0.5/(2*Double.pi)))
    let omegaLow = sqrt(1+0.25*0.25)-0.25
    let omegaHigh = sqrt(1+0.25*0.25)+0.25
    for omega in [omegaLow, omegaHigh] {
        let halfPower = try #require(FoundationsModels.seriesAC(frequency: omega/(2*Double.pi), voltagePeak: 5, resistance: 0.5, inductance: 1, capacitance: 1))
        #expect(foundationClose(halfPower.currentPeak*halfPower.currentPeak, 50))
    }
    #expect(foundationClose(point.capacitorPeak, 10))
    #expect(FoundationsModels.seriesAC(frequency: 0, voltagePeak: 5, resistance: 1, inductance: 1, capacitance: 1) == nil)
}

@Test func foundationsTheveninLoadEquivalenceAndMaximumPower() throws {
    for load in [100.0, 500, 1_000, 10_000] {
        let p = try #require(FoundationsModels.thevenin(supply: 10, top: 1_000, bottom: 1_000, load: load))
        #expect(foundationClose(p.openVoltage, 5))
        #expect(foundationClose(p.resistance, 500))
        #expect(foundationClose(p.loadVoltage, p.directVoltage))
        #expect(foundationClose(p.loadPower, p.loadVoltage*p.loadCurrent))
        #expect(p.loadPower <= p.maximumPower+1e-12)
        if load == 500 { #expect(foundationClose(p.loadPower, p.maximumPower)) }
    }
}

@Test func foundationsBJTTerminalKCLAndReciprocityAtZeroVCE() throws {
    for vce in [0.0, 0.2, 0.8, 2] {
        let p = try #require(FoundationsModels.bjt(vbe: 0.65, vce: vce))
        #expect(abs(p.kcl) < 1e-12)
    }
    let p = try #require(FoundationsModels.bjt(vbe: 0.65, vce: 0))
    // At VBC=VBE and αR=0.5, IC = IS*expm1(x) - 2IS*expm1(x).
    let vt = 1.380649e-23*300/1.602176634e-19
    #expect(foundationClose(p.collector, -1e-15*expm1(0.65/vt)))
    #expect(p.region == "Saturation")
}

@Test func foundationsBJTForwardGainAndDerivative() throws {
    let p = try #require(FoundationsModels.bjt(vbe: 0.65, vce: 2, beta: 100))
    #expect(p.region == "Forward-active")
    #expect(foundationClose(p.collector/p.base, 100, relative: 1e-6))
    let delta = 1e-6
    let a = try #require(FoundationsModels.bjt(vbe: 0.65-delta, vce: 2))
    let b = try #require(FoundationsModels.bjt(vbe: 0.65+delta, vce: 2))
    #expect(foundationClose((b.collector-a.collector)/(2*delta), p.gm, relative: 1e-6))
    #expect(FoundationsModels.bjt(vbe: 100, vce: 2) == nil)
}

@Test func foundationsMOSRegionsBoundaryAndDerivative() throws {
    let cutoff = try #require(FoundationsModels.mosfet(vgs: 1, vds: 2, threshold: 1, coefficient: 0.001))
    #expect(cutoff.current == 0 && cutoff.gm == 0 && cutoff.region == "Cutoff")
    let triode = try #require(FoundationsModels.mosfet(vgs: 3, vds: 1, threshold: 1, coefficient: 0.001))
    #expect(foundationClose(triode.current, 0.0015))
    #expect(triode.region == "Triode")
    let saturation = try #require(FoundationsModels.mosfet(vgs: 3, vds: 2, threshold: 1, coefficient: 0.001))
    #expect(foundationClose(saturation.current, 0.002))
    #expect(foundationClose(saturation.gm, 0.002))
    let nearBoundary = try #require(FoundationsModels.mosfet(vgs: 3, vds: 2-1e-6, threshold: 1, coefficient: 0.001))
    #expect(foundationClose(nearBoundary.current, saturation.current))
    #expect(FoundationsModels.mosfet(vgs: 3, vds: -1, threshold: 1, coefficient: 0.001) == nil)
}

@Test func foundationsMOSFourfoldCurrentAndTwofoldGM() throws {
    let first = try #require(FoundationsModels.mosfet(vgs: 2, vds: 5, threshold: 1, coefficient: 0.001))
    let second = try #require(FoundationsModels.mosfet(vgs: 3, vds: 5, threshold: 1, coefficient: 0.001))
    #expect(second.current == 4*first.current)
    #expect(second.gm == 2*first.gm)
}

@Test func foundationsAnalogDerivativeAndLocalTangentConvergence() throws {
    let small = try #require(FoundationsModels.commonEmitter(biasForwardCurrent: 0.0005, resistance: 2_000, supply: 5, input: 1e-5))
    let large = try #require(FoundationsModels.commonEmitter(biasForwardCurrent: 0.0005, resistance: 2_000, supply: 5, input: 0.01))
    #expect(foundationClose(small.biasOutput, 4, absolute: 1e-8))
    #expect(foundationClose(small.gain, small.numericalGain, relative: 1e-6))
    #expect(small.gain < 0)
    #expect(abs(small.deltaOutput-small.linearDelta)/abs(small.linearDelta) < 0.001)
    #expect(abs(large.deltaOutput-large.linearDelta)/abs(large.linearDelta) > 0.1)
}

@Test func foundationsAnalogLoadedSaturationSatisfiesLoadLine() throws {
    let p = try #require(FoundationsModels.commonEmitter(biasForwardCurrent: 0.002, resistance: 5_000, supply: 5, input: 0))
    let bjt = try #require(FoundationsModels.bjt(vbe: p.biasVBE, vce: p.output))
    #expect(p.region == "Saturation")
    #expect(p.output >= 0 && p.output <= 5)
    #expect(foundationClose(bjt.collector, (5-p.output)/5_000))
    #expect(foundationClose(p.gain, p.numericalGain, relative: 1e-5))
}

@Test func foundationsRejectsNonfiniteAndInvalidParameters() {
    #expect(FoundationsModels.sineCurrent(time: .nan, mean: 1, amplitude: 1, frequency: 1) == nil)
    #expect(FoundationsModels.twoNode(supply: .infinity, r1: 1, r2: 1, r3: 1, r4: 1) == nil)
    #expect(FoundationsModels.tolerance(supply: 5, nominalResistance: 1, fraction: .nan, threshold: 1) == nil)
    #expect(FoundationsModels.conductor(density: -1, mobility: 1, length: 1, area: 1, voltage: 1) == nil)
    #expect(FoundationsModels.rl(time: 1, supply: 1, resistance: 1, inductance: 0, initialCurrent: 0) == nil)
    #expect(FoundationsModels.rlcStep(time: 1, supply: 1, resistance: -1, inductance: 1, capacitance: 1) == nil)
    #expect(FoundationsModels.thevenin(supply: 1, top: 1, bottom: 1, load: 0) == nil)
    #expect(FoundationsModels.bjt(vbe: 0.65, vce: 1, kelvin: 0) == nil)
    #expect(FoundationsModels.mosfet(vgs: 2, vds: 1, threshold: 1, coefficient: 0) == nil)
    #expect(FoundationsModels.commonEmitter(biasForwardCurrent: 1, resistance: 1, supply: 0, input: 0) == nil)
}
