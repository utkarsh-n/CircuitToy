import Foundation

enum PracticeModels {
    struct ProbeResult {
        let unloaded: Double
        let loaded: Double
        let resistance: Double
        let timeConstant: Double
        let magnitude: Double
        let phase: Double
        var loadingError: Double { loaded / unloaded - 1 }
    }
    static func probe(source: Double, top: Double, bottom: Double, input: Double, capacitance: Double, frequency: Double) -> ProbeResult? {
        guard [source, top, bottom, input, capacitance, frequency].allSatisfy(\.isFinite), top > 0, bottom > 0, input > 0, capacitance >= 0, frequency >= 0, source != 0 else { return nil }
        let lower = 1 / (1 / bottom + 1 / input)
        let resistance = 1 / (1 / top + 1 / bottom + 1 / input)
        let loaded = source * lower / (top + lower)
        let tau = resistance * capacitance
        let wTau = 2 * Double.pi * frequency * tau
        return .init(unloaded: source * bottom / (top + bottom), loaded: loaded, resistance: resistance, timeConstant: tau, magnitude: abs(loaded) / sqrt(1 + wTau * wTau), phase: -atan(wTau))
    }

    struct DesignResult {
        let nominal: Double
        let minimum: Double
        let maximum: Double
        let maximumSourceCurrent: Double
        let maximumResistorPower: Double
        let loadEfficiency: Double
        func meets(target: Double, error: Double, currentLimit: Double, powerRating: Double) -> Bool {
            minimum >= target - error && maximum <= target + error && maximumSourceCurrent <= currentLimit && maximumResistorPower <= powerRating
        }
    }
    /// Independent bounded component/source tolerances: all eight monotonic corner combinations.
    static func dividerDesign(source: Double, resistance: Double, load: Double, resistorTolerance: Double, sourceTolerance: Double) -> DesignResult? {
        guard [source, resistance, load, resistorTolerance, sourceTolerance].allSatisfy(\.isFinite), source > 0, resistance > 0, load > 0, (0..<1).contains(resistorTolerance), (0..<1).contains(sourceTolerance) else { return nil }
        let nominal = source * (resistance * load / (resistance + load)) / (resistance + resistance * load / (resistance + load))
        var voltages: [Double] = []; var currents: [Double] = []; var powers: [Double] = []
        for s in [-1.0, 1.0] { for a in [-1.0, 1.0] { for b in [-1.0, 1.0] {
            let v = source * (1 + s * sourceTolerance), r1 = resistance * (1 + a * resistorTolerance), r2 = resistance * (1 + b * resistorTolerance)
            let lower = 1 / (1 / r2 + 1 / load), current = v / (r1 + lower), output = current * lower
            voltages.append(output); currents.append(current)
            powers.append(current * current * r1); powers.append(output * output / r2)
        } } }
        let supplyPower = source * source / (resistance + resistance * load / (resistance + load))
        return .init(nominal: nominal, minimum: voltages.min()!, maximum: voltages.max()!, maximumSourceCurrent: currents.max()!, maximumResistorPower: powers.max()!, loadEfficiency: nominal * nominal / load / supplyPower)
    }

    static func quantize(voltage: Double, fullScale: Double = 3.3, bits: Int) -> (code: Int, voltage: Double)? {
        guard voltage.isFinite, fullScale.isFinite, fullScale > 0, (1...16).contains(bits) else { return nil }
        let levels = 1 << bits, step = fullScale / Double(levels)
        let limited = min(fullScale, max(0, voltage))
        let code = min(levels - 1, Int(floor(limited / step)))
        return (code, (Double(code) + 0.5) * step)
    }

    struct ThermalConfiguration: Codable, Equatable {
        var supply = 12.0
        var heaterResistance = 24.0
        var heatCapacity = 20.0
        var conductance = 0.5
        var ambient = 20.0
        var target = 28.0
        var hysteresis = 0.3
        var sensorOffset = 0.0
        var bits = 12
        var step = 0.5
        var duration = 180.0
    }
    struct ThermalSample: Codable {
        let time: Double
        let temperature: Double
        let measured: Double
        let code: Int
        let heaterOn: Bool
        let electricalEnergy: Double
        let environmentalEnergy: Double
        let storedEnergy: Double
    }
    struct ThermalReport: Codable {
        let configuration: ThermalConfiguration
        let samples: [ThermalSample]
        var heaterPower: Double { configuration.supply * configuration.supply / configuration.heaterResistance }
        var maximumTemperature: Double { samples.map(\.temperature).max() ?? configuration.ambient }
        var finalError: Double { configuration.target - (samples.last?.temperature ?? configuration.ambient) }
        var energyResidual: Double {
            guard let last = samples.last else { return 0 }
            return last.electricalEnergy - last.environmentalEnergy - last.storedEnergy
        }
        var settlingError: Double {
            let tail = samples.filter { $0.time >= configuration.duration * 0.8 }
            return tail.map { abs($0.temperature - configuration.target) }.max() ?? 0
        }
        func json() -> String {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "Unable to encode this report."
        }
    }
    /// Exact solution on each held-input interval: C dT/dt=P-h(T-Ta).
    static func thermalStep(temperature: Double, ambient: Double, power: Double, capacity: Double, conductance: Double, step: Double) -> Double? {
        guard [temperature, ambient, power, capacity, conductance, step].allSatisfy(\.isFinite), capacity > 0, conductance > 0, step > 0, power >= 0 else { return nil }
        let equilibrium = ambient + power / conductance
        let result = temperature + (equilibrium - temperature) * -expm1(-conductance * step / capacity)
        return result.isFinite ? result : nil
    }
    static func thermal(_ c: ThermalConfiguration) -> ThermalReport? {
        guard [c.supply, c.heaterResistance, c.heatCapacity, c.conductance, c.ambient, c.target, c.hysteresis, c.sensorOffset, c.step, c.duration].allSatisfy(\.isFinite), c.supply > 0, c.heaterResistance > 0, c.heatCapacity > 0, c.conductance > 0, c.hysteresis > 0, c.step > 0, c.duration >= c.step, c.duration / c.step <= 10_000, (1...16).contains(c.bits) else { return nil }
        let power = c.supply * c.supply / c.heaterResistance
        guard power.isFinite else { return nil }
        var temperature = c.ambient, on = false, inputEnergy = 0.0, lossEnergy = 0.0
        var samples: [ThermalSample] = []
        let count = Int(ceil(c.duration / c.step))
        for index in 0...count {
            let time = min(Double(index) * c.step, c.duration)
            guard let sensor = quantize(voltage: 0.5 + 0.01 * (temperature + c.sensorOffset), bits: c.bits) else { return nil }
            let measured = (sensor.voltage - 0.5) / 0.01
            if measured < c.target - c.hysteresis { on = true }
            if measured > c.target + c.hysteresis { on = false }
            samples.append(.init(time: time, temperature: temperature, measured: measured, code: sensor.code, heaterOn: on, electricalEnergy: inputEnergy, environmentalEnergy: lossEnergy, storedEnergy: c.heatCapacity * (temperature - c.ambient)))
            guard index < count else { break }
            let dt = min(c.step, c.duration - time), input = on ? power : 0
            guard let next = thermalStep(temperature: temperature, ambient: c.ambient, power: input, capacity: c.heatCapacity, conductance: c.conductance, step: dt) else { return nil }
            inputEnergy += input * dt
            // Integral of h(T-Ta) is exact from energy balance on this interval.
            lossEnergy += input * dt - c.heatCapacity * (next - temperature)
            temperature = next
        }
        return .init(configuration: c, samples: samples)
    }
}
