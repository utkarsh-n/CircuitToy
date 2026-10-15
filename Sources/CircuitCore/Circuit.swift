import Foundation

/// All quantities use SI units: V, A, Ω, F, H, and seconds. Node 0 is ground.
/// An element's voltage is V(a) − V(b); positive branch current flows a → b.
public enum CircuitElement: Equatable, Sendable {
    case resistor(id: String, a: Int, b: Int, ohms: Double)
    case voltageSource(id: String, a: Int, b: Int, volts: Double)
    case currentSource(id: String, a: Int, b: Int, amps: Double)
    case capacitor(id: String, a: Int, b: Int, farads: Double, initialVoltage: Double = 0)
    case inductor(id: String, a: Int, b: Int, henrys: Double, initialCurrent: Double = 0)
    case diode(id: String, a: Int, b: Int, model: DiodeModel)
    case bjt(id: String, collector: Int, base: Int, emitter: Int, polarity: BJTPolarity, model: BJTModel)
    case mosfet(id: String, drain: Int, gate: Int, source: Int, polarity: MOSFETPolarity, model: MOSFETModel)
    case opAmp(id: String, nonInverting: Int, inverting: Int, output: Int, positiveSupply: Int, negativeSupply: Int, model: OpAmpModel)

    public var id: String {
        switch self {
        case let .resistor(id, _, _, _), let .voltageSource(id, _, _, _),
             let .currentSource(id, _, _, _), let .capacitor(id, _, _, _, _),
             let .inductor(id, _, _, _, _), let .diode(id, _, _, _),
             let .bjt(id, _, _, _, _, _), let .mosfet(id, _, _, _, _, _),
             let .opAmp(id, _, _, _, _, _, _): id
        }
    }

    public var a: Int {
        switch self {
        case let .resistor(_, a, _, _), let .voltageSource(_, a, _, _),
             let .currentSource(_, a, _, _), let .capacitor(_, a, _, _, _),
             let .inductor(_, a, _, _, _), let .diode(_, a, _, _),
             let .bjt(_, a, _, _, _, _), let .mosfet(_, a, _, _, _, _),
             let .opAmp(_, _, _, a, _, _, _): a
        }
    }

    public var b: Int {
        switch self {
        case let .resistor(_, _, b, _), let .voltageSource(_, _, b, _),
             let .currentSource(_, _, b, _), let .capacitor(_, _, b, _, _),
             let .inductor(_, _, b, _, _), let .diode(_, _, b, _),
             let .bjt(_, _, _, b, _, _), let .mosfet(_, _, _, b, _, _),
             let .opAmp(_, _, _, _, _, b, _): b
        }
    }

    /// Pin order used for terminal currents. Currents are positive INTO each element.
    public var terminalNodes: [Int] {
        switch self {
        case let .bjt(_, c, b, e, _, _), let .mosfet(_, c, b, e, _, _): [c,b,e]
        case let .opAmp(_, p, n, out, vp, vn, _): [p,n,out,vp,vn]
        default: [a,b]
        }
    }
}

public struct Circuit: Equatable, Sendable {
    public var elements: [CircuitElement]

    public init(elements: [CircuitElement]) { self.elements = elements }

    public var nodes: [Int] { Set(elements.flatMap(\.terminalNodes)).sorted() }

    /// Validates values only. Solvability also depends on DC versus transient analysis.
    public func validate() throws {
        guard !elements.isEmpty else { throw CircuitError.emptyCircuit }
        var ids = Set<String>()
        for element in elements {
            guard !element.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CircuitError.emptyElementID
            }
            guard ids.insert(element.id).inserted else { throw CircuitError.duplicateElementID(element.id) }
            guard element.terminalNodes.allSatisfy({ $0 >= 0 }) else { throw CircuitError.invalidNode(element.id) }
            switch element {
            case let .resistor(id, _, _, value): try positive(value, id: id, quantity: "Resistance")
            case let .voltageSource(id, _, _, value): try finite(value, id: id, quantity: "Voltage")
            case let .currentSource(id, _, _, value): try finite(value, id: id, quantity: "Current")
            case let .capacitor(id, _, _, value, initial):
                try positive(value, id: id, quantity: "Capacitance")
                try finite(initial, id: id, quantity: "Initial voltage")
            case let .inductor(id, _, _, value, initial):
                try positive(value, id: id, quantity: "Inductance")
                try finite(initial, id: id, quantity: "Initial current")
            case let .diode(id, _, _, model): try model.validate(id: id)
            case let .bjt(id, _, _, _, _, model): try model.validate(id: id)
            case let .mosfet(id, _, _, _, _, model): try model.validate(id: id)
            case let .opAmp(id, _, _, _, _, _, model): try model.validate(id: id)
            }
        }
        guard nodes.count <= 128, elements.count <= 256 else { throw CircuitError.circuitTooLarge }
    }

    private func positive(_ value: Double, id: String, quantity: String) throws {
        guard value.isFinite, value > 0 else {
            throw CircuitError.invalidValue(id: id, quantity: quantity, requiresPositive: true)
        }
    }

    private func finite(_ value: Double, id: String, quantity: String) throws {
        guard value.isFinite else {
            throw CircuitError.invalidValue(id: id, quantity: quantity, requiresPositive: false)
        }
    }
}

public enum CircuitError: Error, Equatable, Sendable, LocalizedError {
    case emptyCircuit
    case emptyElementID
    case duplicateElementID(String)
    case invalidNode(String)
    case invalidValue(id: String, quantity: String, requiresPositive: Bool)
    case floatingNodes([Int])
    case singularCircuit
    case inconsistentCircuit
    case invalidTimeStep
    case inconsistentInitialConditions(String)
    case numericalRange
    case circuitTooLarge
    case invalidModelParameter(id: String, parameter: String, requirement: String)
    case nonlinearConvergence(iterations: Int)
    case unpoweredDevice(String)
    case inputCommonModeRange(String)
    case invalidOperatingPoint(String)

    public var errorDescription: String? {
        switch self {
        case .emptyCircuit: "Add at least one circuit element."
        case .emptyElementID: "Each element needs a nonempty identifier."
        case let .duplicateElementID(id): "The identifier \(id) is used more than once."
        case let .invalidNode(id): "\(id) has a negative node number. Use node 0 for ground."
        case let .invalidValue(id, quantity, positive):
            "\(id): \(quantity.lowercased()) must be finite\(positive ? " and greater than zero" : "")."
        case let .floatingNodes(nodes): "Nodes \(nodes.map(String.init).joined(separator: ", ")) have no voltage reference to ground in this analysis."
        case .singularCircuit: "This ideal circuit does not have a unique solution. Check redundant ideal voltage sources or shorts."
        case .inconsistentCircuit: "This ideal circuit has contradictory constraints. Check ideal voltage sources and shorts."
        case .invalidTimeStep: "The time step must be finite and greater than zero."
        case let .inconsistentInitialConditions(id): "The initial condition on \(id) conflicts with ideal voltage or current constraints."
        case .numericalRange: "The circuit exceeds the numerical range of this solver. Check values and the time step."
        case .circuitTooLarge: "This educational solver supports up to 128 nodes and 256 elements."
        case let .invalidModelParameter(id, parameter, requirement): "\(id): \(parameter.lowercased()) must be \(requirement)."
        case let .nonlinearConvergence(iterations): "The nonlinear circuit did not converge after \(iterations) iterations. Check connections, supplies, and model values."
        case let .unpoweredDevice(id): "\(id) needs correctly ordered supply rails separated by more than twice its output headroom."
        case let .inputCommonModeRange(id): "\(id): the generic amplifier's input voltages must stay within its actual supply rails."
        case let .invalidOperatingPoint(id): "\(id) has an operating point outside this model's physical range."
        }
    }
}

public struct CircuitSolution: Equatable, Sendable {
    public let time: Double
    public let nodeVoltages: [Int: Double]
    public let branchCurrents: [String: Double]
    /// Signed sum of outgoing currents at each node, including ground, in A.
    public let kclResiduals: [Int: Double]
    /// Passive sign convention: positive power is absorbed; negative is supplied.
    public let branchPowers: [String: Double]
    /// In terminalNodes order, positive INTO the element, including all supply pins.
    public let terminalCurrents: [String: [Double]]

    public init(time: Double, nodeVoltages: [Int: Double], branchCurrents: [String: Double],
                kclResiduals: [Int: Double], branchPowers: [String: Double],
                terminalCurrents: [String: [Double]] = [:]) {
        self.time=time; self.nodeVoltages=nodeVoltages; self.branchCurrents=branchCurrents
        self.kclResiduals=kclResiduals; self.branchPowers=branchPowers; self.terminalCurrents=terminalCurrents
    }

    public func voltage(at node: Int) -> Double? { nodeVoltages[node] }
    public func current(through id: String) -> Double? { branchCurrents[id] }
    public var maximumKCLResidual: Double { kclResiduals.values.map(abs).max() ?? 0 }
    public var powerBalance: Double { branchPowers.values.reduce(0, +) }
}

/// Explicit model boundaries for the UI's fidelity disclosure.
public enum CircuitModel {
    public static let units = "SI units: volts, amperes, ohms, farads, henrys, seconds."
    public static let dcLimits = "Lumped R/L/C and constant sources, plus generic Shockley diodes/LEDs, Ebers–Moll BJTs, long-channel square-law MOSFETs with source-tied body diodes, and supplied finite-gain/current-limited amplifier macromodels. DC capacitors are open; inductors are shorts. Device parameters define these models, not a specific manufactured part. No junction/gate capacitance, breakdown, self-heating, amplifier bandwidth, or wire parasitics. Guided circuit lessons retain their stated model scope."
    public static let transientLimits = "Fixed-step backward Euler solves R/L/C from explicit reactive initial conditions while nonlinear device equations are solved at each step. Semiconductor/amplifier models are memoryless: no charge storage, gate capacitance, slew rate, or propagation delay. This first-order approximation has finite-timestep error; decrease the time step to check convergence. Sources stay constant."
    public static let logicLimits = "Four-state ideal Boolean logic (0, 1, X, Z). No analog thresholds, propagation delay, transistor model, or metastability timing."
}
