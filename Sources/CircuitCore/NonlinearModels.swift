import Foundation

/// Generic isothermal Shockley junction, optionally with a physical series resistor.
/// Saturation current is specified at temperatureKelvin; no automatic temperature scaling,
/// reverse breakdown, junction capacitance, or self-heating is implied.
public struct DiodeModel: Codable, Equatable, Sendable {
    public var saturationCurrent: Double
    public var idealityFactor: Double
    public var temperatureKelvin: Double
    public var seriesResistance: Double
    public init(saturationCurrent: Double = 1e-12, idealityFactor: Double = 1,
                temperatureKelvin: Double = 300, seriesResistance: Double = 0) {
        self.saturationCurrent = saturationCurrent; self.idealityFactor = idealityFactor
        self.temperatureKelvin = temperatureKelvin; self.seriesResistance = seriesResistance
    }
    public static let silicon = DiodeModel()
    public static let redLED = DiodeModel(saturationCurrent: 1e-20, idealityFactor: 2, seriesResistance: 10)
    public func validate(id: String) throws {
        try modelPositive(saturationCurrent, id, "Saturation current")
        try modelPositive(idealityFactor, id, "Ideality factor")
        try modelPositive(temperatureKelvin, id, "Temperature")
        try modelNonnegative(seriesResistance, id, "Series resistance")
    }
    public var thermalVoltage: Double { 1.380649e-23 / 1.602176634e-19 * temperatureKelvin }
}

public enum BJTPolarity: String, Codable, CaseIterable, Sendable { case npn, pnp }
/// Reciprocal Ebers–Moll model. Is is the transport saturation current, not either
/// junction's Is/alpha. No Early effect, high-injection rolloff, charge storage, or breakdown.
public struct BJTModel: Codable, Equatable, Sendable {
    public var saturationCurrent: Double
    public var forwardBeta: Double
    public var reverseBeta: Double
    public var temperatureKelvin: Double
    public init(saturationCurrent: Double = 1e-15, forwardBeta: Double = 100,
                reverseBeta: Double = 1, temperatureKelvin: Double = 300) {
        self.saturationCurrent = saturationCurrent; self.forwardBeta = forwardBeta
        self.reverseBeta = reverseBeta; self.temperatureKelvin = temperatureKelvin
    }
    public func validate(id: String) throws {
        try modelPositive(saturationCurrent, id, "Saturation current")
        try modelPositive(forwardBeta, id, "Forward beta")
        try modelPositive(reverseBeta, id, "Reverse beta")
        try modelPositive(temperatureKelvin, id, "Temperature")
    }
    public var thermalVoltage: Double { 1.380649e-23 / 1.602176634e-19 * temperatureKelvin }
}

public enum MOSFETPolarity: String, Codable, CaseIterable, Sendable { case nChannel, pChannel }
/// Long-channel square-law model: Id(saturation)=beta/2*(Vgs−Vth)^2*(1+lambda*Vds).
/// Body is physically tied to the labelled source, including during reverse operation.
/// No gate current/capacitance, subthreshold current, body effect, or avalanche breakdown.
public struct MOSFETModel: Codable, Equatable, Sendable {
    public var thresholdVoltage: Double
    public var transconductance: Double
    public var channelLengthModulation: Double
    public var bodyDiode: DiodeModel
    public init(thresholdVoltage: Double = 2, transconductance: Double = 0.02,
                channelLengthModulation: Double = 0.02, bodyDiode: DiodeModel = .silicon) {
        self.thresholdVoltage = thresholdVoltage; self.transconductance = transconductance
        self.channelLengthModulation = channelLengthModulation; self.bodyDiode = bodyDiode
    }
    public func validate(id: String) throws {
        try modelPositive(thresholdVoltage, id, "Threshold magnitude")
        try modelPositive(transconductance, id, "Transconductance parameter")
        try modelNonnegative(channelLengthModulation, id, "Channel-length modulation")
        try bodyDiode.validate(id: id)
    }
}

/// Generic DC amplifier macromodel with ideal zero-current inputs. Its command voltage
/// is supply midpoint + A*(V+input−V−input), clipped at railHeadroom from actual supplies.
/// Ro and the symmetric hard current limit model the output stage; supply pins supply
/// all output current plus Iq. Inputs are valid within the supplies (rail-to-rail input
/// assumption). No bandwidth, slew, offset/noise, protection diode, or startup dynamics.
public struct OpAmpModel: Codable, Equatable, Sendable {
    public var openLoopGain: Double
    public var outputResistance: Double
    public var currentLimit: Double
    public var railHeadroom: Double
    public var quiescentCurrent: Double
    public init(openLoopGain: Double = 100_000, outputResistance: Double = 50,
                currentLimit: Double = 0.02, railHeadroom: Double = 0.1,
                quiescentCurrent: Double = 0.001) {
        self.openLoopGain = openLoopGain; self.outputResistance = outputResistance
        self.currentLimit = currentLimit; self.railHeadroom = railHeadroom
        self.quiescentCurrent = quiescentCurrent
    }
    public func validate(id: String) throws {
        try modelPositive(openLoopGain, id, "Open-loop gain")
        try modelPositive(outputResistance, id, "Output resistance")
        try modelPositive(currentLimit, id, "Output current limit")
        try modelNonnegative(railHeadroom, id, "Rail headroom")
        try modelNonnegative(quiescentCurrent, id, "Quiescent current")
    }
}

private func modelPositive(_ value: Double, _ id: String, _ parameter: String) throws {
    guard value.isFinite, value > 0 else {
        throw CircuitError.invalidModelParameter(id: id, parameter: parameter, requirement: "finite and greater than zero")
    }
}
private func modelNonnegative(_ value: Double, _ id: String, _ parameter: String) throws {
    guard value.isFinite, value >= 0 else {
        throw CircuitError.invalidModelParameter(id: id, parameter: parameter, requirement: "finite and nonnegative")
    }
}

/// Local automatic differentiation makes the stamped Jacobian match the device equations.
struct DeviceScalar {
    var value: Double
    var derivatives: [Double]
    init(_ value: Double, count: Int, pin: Int? = nil) {
        self.value = value; derivatives = Array(repeating: 0, count: count)
        if let pin { derivatives[pin] = 1 }
    }
    static func + (a: Self, b: Self) -> Self { Self(value: a.value + b.value, derivatives: zip(a.derivatives,b.derivatives).map(+)) }
    static func - (a: Self, b: Self) -> Self { Self(value: a.value - b.value, derivatives: zip(a.derivatives,b.derivatives).map(-)) }
    static prefix func - (a: Self) -> Self { a * -1 }
    static func * (a: Self, b: Double) -> Self { Self(value: a.value*b, derivatives: a.derivatives.map { $0*b }) }
    static func * (a: Self, b: Self) -> Self {
        Self(value: a.value*b.value, derivatives: zip(a.derivatives,b.derivatives).map { $0*b.value + $1*a.value })
    }
    static func + (a: Self, b: Double) -> Self { Self(value: a.value+b, derivatives: a.derivatives) }
    static func - (a: Self, b: Double) -> Self { a + -b }
    private init(value: Double, derivatives: [Double]) { self.value=value; self.derivatives=derivatives }
    func clipped(_ low: Self, _ high: Self) -> Self {
        if value < low.value { return low }
        if value > high.value { return high }
        return self
    }
    func clipped(_ low: Double, _ high: Double) -> Self {
        if value < low { return Self(low,count: derivatives.count) }
        if value > high { return Self(high,count: derivatives.count) }
        return self
    }
    func positivePart() -> Self { value > 0 ? self : Self(0,count: derivatives.count) }
    func junction(is saturation: Double, scale: Double) throws -> Self {
        let exponent = value / scale
        let exponentialCurrent = exp(log(saturation) + exponent)
        let current = abs(exponent) < 0.5 ? saturation * expm1(exponent) : exponentialCurrent - saturation
        let derivative = exponentialCurrent / scale
        guard current.isFinite, derivative.isFinite else { throw CircuitError.numericalRange }
        return Self(value: current, derivatives: derivatives.map { $0 * derivative })
    }
    func diode(_ model: DiodeModel) throws -> Self {
        let scale = model.idealityFactor * model.thermalVoltage
        guard scale.isFinite, scale > 0 else { throw CircuitError.numericalRange }
        if model.seriesResistance == 0 { return try junction(is: model.saturationCurrent, scale: scale) }
        // Monotone implicit Rs equation, evaluated without changing the Shockley exponential.
        let rs = model.seriesResistance, saturation = model.saturationCurrent
        var low = min(0, value / scale), high: Double
        if value > 0 {
            let logRatio = log(value) - log(rs) - log(saturation)
            let logOnePlusRatio = logRatio > 40 ? logRatio : log1p(exp(logRatio))
            high = min(value / scale, logOnePlusRatio)
        } else { high = 0 }
        var exponent = (low + high) * 0.5
        for _ in 0..<90 {
            exponent = (low + high) * 0.5
            let current = abs(exponent) < 0.5 ? saturation*expm1(exponent) : exp(log(saturation)+exponent)-saturation
            let residual = scale*exponent + rs*current - value
            if residual > 0 { high = exponent } else { low = exponent }
        }
        let exponentialCurrent = exp(log(saturation) + exponent)
        let current = abs(exponent) < 0.5 ? saturation*expm1(exponent) : exponentialCurrent-saturation
        // This equivalent reciprocal form avoids overflowing Rs*g in a strong junction.
        let derivative = 1 / (scale/exponentialCurrent + rs)
        guard current.isFinite, derivative.isFinite else { throw CircuitError.numericalRange }
        return Self(value: current, derivatives: derivatives.map { $0*derivative })
    }
}

extension CircuitElement {
    var isNonlinear: Bool {
        switch self { case .diode, .bjt, .mosfet, .opAmp: true; default: false }
    }
    /// Voltage-reference topology includes only physical current-bearing terminals.
    /// Insulated gates and ideal amplifier inputs acquire no invented conductance path.
    var conductiveTerminalNodes: [Int] {
        switch self {
        case let .mosfet(_, drain, _, source, _, _): [drain, source]
        case let .opAmp(_, _, _, output, positiveSupply, negativeSupply, _): [output,positiveSupply,negativeSupply]
        default: terminalNodes
        }
    }
    func deviceCurrents(_ values: [Double]) throws -> [DeviceScalar] {
        let count = values.count
        let v = values.enumerated().map { DeviceScalar($0.element,count:count,pin:$0.offset) }
        let zero = DeviceScalar(0,count:count)
        let currents: [DeviceScalar]
        switch self {
        case let .diode(_, _, _, model):
            let i = try (v[0]-v[1]).diode(model); currents=[i,-i]
        case let .bjt(_, _, _, _, polarity, model):
            let sign = polarity == .npn ? 1.0 : -1.0
            let forward = try ((v[1]-v[2])*sign).junction(is:model.saturationCurrent,scale:model.thermalVoltage)
            let reverse = try ((v[1]-v[0])*sign).junction(is:model.saturationCurrent,scale:model.thermalVoltage)
            let collector = (forward - reverse*(1+1/model.reverseBeta))*sign
            let base = (forward*(1/model.forwardBeta) + reverse*(1/model.reverseBeta))*sign
            currents=[collector,base,-collector-base]
        case let .mosfet(_, _, _, _, polarity, model):
            let sign = polarity == .nChannel ? 1.0 : -1.0
            let drain=v[0]*sign, gate=v[1]*sign, source=v[2]*sign
            let forward = drain.value >= source.value
            let low=forward ? source : drain, high=forward ? drain : source
            let overdrive=(gate-low-model.thresholdVoltage).positivePart()
            let vds=high-low
            let channel: DeviceScalar
            if vds.value < overdrive.value {
                channel=(overdrive*vds-vds*vds*0.5)*model.transconductance*(vds*model.channelLengthModulation+1)
            } else {
                channel=overdrive*overdrive*(0.5*model.transconductance)*(vds*model.channelLengthModulation+1)
            }
            let body=try (source-drain).diode(model.bodyDiode)
            let current=(channel*(forward ? 1.0 : -1.0)-body)*sign
            currents=[current,zero,-current]
        case let .opAmp(_, _, _, _, _, _, model):
            let midpoint=(v[3]+v[4])*0.5
            let low=v[4]+model.railHeadroom, high=v[3]-model.railHeadroom
            let raw=midpoint+(v[0]-v[1])*model.openLoopGain
            // Invalid trial supply values are allowed during Newton; the accepted point is checked below.
            let command=low.value <= high.value ? raw.clipped(low,high) : midpoint
            let output=((v[2]-command)*(1/model.outputResistance)).clipped(-model.currentLimit,model.currentLimit)
            // Choose one consistent one-sided derivative at zero output current so
            // all terminal Jacobian columns, as well as currents, obey device KCL.
            let supplyPositive=output.value < 0 ? -output+model.quiescentCurrent : zero+model.quiescentCurrent
            let supplyNegative=output.value < 0 ? zero-model.quiescentCurrent : -output-model.quiescentCurrent
            currents=[zero,zero,output,supplyPositive,supplyNegative]
        default: return []
        }
        guard currents.allSatisfy({ $0.value.isFinite && $0.derivatives.allSatisfy(\.isFinite) }) else { throw CircuitError.numericalRange }
        return currents
    }
    func validateOperatingPoint(_ voltages: [Double]) throws {
        guard case let .opAmp(id, _, _, _, _, _, model) = self else { return }
        let positive=voltages[3], negative=voltages[4]
        guard positive-negative > 2*model.railHeadroom else { throw CircuitError.unpoweredDevice(id) }
        let tolerance=1e-8*max(1,abs(positive),abs(negative))
        guard voltages[0] >= negative-tolerance, voltages[0] <= positive+tolerance,
              voltages[1] >= negative-tolerance, voltages[1] <= positive+tolerance else {
            throw CircuitError.inputCommonModeRange(id)
        }
        guard voltages[2] >= negative-tolerance, voltages[2] <= positive+tolerance else {
            throw CircuitError.invalidOperatingPoint(id)
        }
    }
}
