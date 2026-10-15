import Foundation

/// A virtual, unsplit 12-row breadboard. Its center channel separates E and F.
public enum BreadboardColumn: Int, CaseIterable, Codable, Sendable, Identifiable {
    case leftPositive, leftNegative, a, b, c, d, e, f, g, h, i, j, rightPositive, rightNegative

    public var id: Int { rawValue }
    public var label: String {
        switch self {
        case .leftPositive: "L+"
        case .leftNegative: "L−"
        case .rightPositive: "R+"
        case .rightNegative: "R−"
        default: String(UnicodeScalar(65 + rawValue - 2)!)
        }
    }
    public var isRail: Bool { rawValue < 2 || rawValue > 11 }
}

public struct BreadboardHole: Codable, Hashable, Sendable, Identifiable {
    public var row: Int
    public var column: BreadboardColumn

    public init(row: Int, column: BreadboardColumn) {
        self.row = row
        self.column = column
    }
    public var label: String {
        let displayedRow = row.addingReportingOverflow(1)
        return displayedRow.overflow
            ? "\(column.label)(row \(row))"
            : "\(column.label)\(displayedRow.partialValue)"
    }
    public var id: String { label }
    public var isValid: Bool { (0..<12).contains(row) }
    public static let all: [BreadboardHole] = (0..<12).flatMap { row in
        BreadboardColumn.allCases.map { BreadboardHole(row: row, column: $0) }
    }
}

public enum BreadboardMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case analog, logic
    public var id: String { rawValue }
    public var title: String { self == .analog ? "Analog" : "Logic" }
}

public enum BreadboardComponentKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case resistor, voltageSource, currentSource, capacitor, inductor
    case diode, led, npn, pnp, nmos, pmos, opAmp
    case logicInput, and, or, xor, not, nand, nor, xnor

    public var id: String { rawValue }
    public var isAnalog: Bool {
        switch self {
        case .resistor, .voltageSource, .currentSource, .capacitor, .inductor,
             .diode, .led, .npn, .pnp, .nmos, .pmos, .opAmp: true
        default: false
        }
    }
    public var hasDeviceModel: Bool {
        switch self {
        case .diode, .led, .npn, .pnp, .nmos, .pmos, .opAmp: true
        default: false
        }
    }
    public var title: String {
        switch self {
        case .resistor: "Resistor"
        case .voltageSource: "Voltage source"
        case .currentSource: "Current source"
        case .capacitor: "Capacitor"
        case .inductor: "Inductor"
        case .diode: "Silicon diode"
        case .led: "LED"
        case .npn: "NPN transistor"
        case .pnp: "PNP transistor"
        case .nmos: "N-channel MOSFET"
        case .pmos: "P-channel MOSFET"
        case .opAmp: "Operational amplifier"
        case .logicInput: "Logic input"
        case .and: "AND"
        case .or: "OR"
        case .xor: "XOR"
        case .not: "NOT"
        case .nand: "NAND"
        case .nor: "NOR"
        case .xnor: "XNOR"
        }
    }
    public var pinCount: Int { pinLabels.count }
    /// The final digital gate pin is its output. Device terminal current is positive into a pin.
    /// For two-terminal elements, branch current flows from pin 0 to pin 1.
    public var pinLabels: [String] {
        switch self {
        case .voltageSource, .capacitor: ["+", "−"]
        case .resistor, .currentSource, .inductor: ["a", "b"]
        case .diode, .led: ["A", "K"]
        case .npn, .pnp: ["C", "B", "E"]
        case .nmos, .pmos: ["D", "G", "S"]
        case .opAmp: ["+In", "−In", "Out", "V+", "V−"]
        case .logicInput: ["Out"]
        case .not: ["In", "Out"]
        default: ["A", "B", "Out"]
        }
    }
    /// The terminal represented by the legacy single-current probe for a modeled device.
    public var primaryCurrentTerminal: Int { self == .opAmp ? 2 : 0 }
    public var defaultValue: Double {
        switch self {
        case .resistor: 1_000
        case .voltageSource: 5
        case .currentSource: 0.001
        case .capacitor: 0.001
        case .inductor: 1
        default: 0
        }
    }
    public var unit: String {
        switch self {
        case .resistor: "Ω"
        case .voltageSource: "V"
        case .currentSource: "A"
        case .capacitor: "F"
        case .inductor: "H"
        default: ""
        }
    }
    public var gate: LogicGate? {
        switch self {
        case .and: .and
        case .or: .or
        case .xor: .xor
        case .not: .not
        case .nand: .nand
        case .nor: .nor
        case .xnor: .xnor
        default: nil
        }
    }
}

public struct BreadboardComponent: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var kind: BreadboardComponentKind
    public var pins: [BreadboardHole]
    public var value: Double
    public var initialValue: Double
    public var logicValue: LogicLevel
    public var diodeModel: DiodeModel
    public var bjtModel: BJTModel
    public var mosfetModel: MOSFETModel
    public var opAmpModel: OpAmpModel

    public init(id: String, kind: BreadboardComponentKind, pins: [BreadboardHole], value: Double,
                initialValue: Double = 0, logicValue: LogicLevel = .zero,
                diodeModel: DiodeModel? = nil, bjtModel: BJTModel = .init(),
                mosfetModel: MOSFETModel = .init(), opAmpModel: OpAmpModel = .init()) {
        self.id = id
        self.kind = kind
        self.pins = pins
        self.value = value
        self.initialValue = initialValue
        self.logicValue = logicValue
        self.diodeModel = diodeModel ?? (kind == .led ? .redLED : .silicon)
        self.bjtModel = bjtModel
        self.mosfetModel = mosfetModel
        self.opAmpModel = opAmpModel
    }

    public var modelSummary: String {
        func number(_ value: Double) -> String { String(format: "%.3g", value) }
        switch kind {
        case .diode, .led:
            return "Shockley · Is \(number(diodeModel.saturationCurrent)) A · n \(number(diodeModel.idealityFactor)) · Rs \(number(diodeModel.seriesResistance)) Ω · \(number(diodeModel.temperatureKelvin)) K"
        case .npn, .pnp:
            return "Ebers–Moll · Is \(number(bjtModel.saturationCurrent)) A · βF \(number(bjtModel.forwardBeta)) · βR \(number(bjtModel.reverseBeta)) · \(number(bjtModel.temperatureKelvin)) K"
        case .nmos, .pmos:
            return "Long-channel · Vth \(number(mosfetModel.thresholdVoltage)) V · β \(number(mosfetModel.transconductance)) A/V² · λ \(number(mosfetModel.channelLengthModulation)) V⁻¹ · body diode"
        case .opAmp:
            return "Finite gain \(number(opAmpModel.openLoopGain)) · Rout \(number(opAmpModel.outputResistance)) Ω · limit \(number(opAmpModel.currentLimit)) A · headroom \(number(opAmpModel.railHeadroom)) V · Iq \(number(opAmpModel.quiescentCurrent)) A"
        default: return ""
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, pins, value, initialValue, logicValue
        case diodeModel, bjtModel, mosfetModel, opAmpModel
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(BreadboardComponentKind.self, forKey: .kind)
        pins = try container.decode([BreadboardHole].self, forKey: .pins)
        value = try container.decode(Double.self, forKey: .value)
        initialValue = try container.decodeIfPresent(Double.self, forKey: .initialValue) ?? 0
        logicValue = try container.decodeIfPresent(LogicLevel.self, forKey: .logicValue) ?? .zero
        diodeModel = try container.decodeIfPresent(DiodeModel.self, forKey: .diodeModel) ?? (kind == .led ? .redLED : .silicon)
        bjtModel = try container.decodeIfPresent(BJTModel.self, forKey: .bjtModel) ?? .init()
        mosfetModel = try container.decodeIfPresent(MOSFETModel.self, forKey: .mosfetModel) ?? .init()
        opAmpModel = try container.decodeIfPresent(OpAmpModel.self, forKey: .opAmpModel) ?? .init()
    }

    fileprivate func element(nodes: [Int]) -> CircuitElement? {
        guard kind.isAnalog, nodes.count == kind.pinCount else { return nil }
        return switch kind {
        case .resistor: .resistor(id: id, a: nodes[0], b: nodes[1], ohms: value)
        case .voltageSource: .voltageSource(id: id, a: nodes[0], b: nodes[1], volts: value)
        case .currentSource: .currentSource(id: id, a: nodes[0], b: nodes[1], amps: value)
        case .capacitor: .capacitor(id: id, a: nodes[0], b: nodes[1], farads: value, initialVoltage: initialValue)
        case .inductor: .inductor(id: id, a: nodes[0], b: nodes[1], henrys: value, initialCurrent: initialValue)
        case .diode, .led: .diode(id: id, a: nodes[0], b: nodes[1], model: diodeModel)
        case .npn, .pnp: .bjt(id: id, collector: nodes[0], base: nodes[1], emitter: nodes[2], polarity: kind == .npn ? .npn : .pnp, model: bjtModel)
        case .nmos, .pmos: .mosfet(id: id, drain: nodes[0], gate: nodes[1], source: nodes[2], polarity: kind == .nmos ? .nChannel : .pChannel, model: mosfetModel)
        case .opAmp: .opAmp(id: id, nonInverting: nodes[0], inverting: nodes[1], output: nodes[2], positiveSupply: nodes[3], negativeSupply: nodes[4], model: opAmpModel)
        default: nil
        }
    }
}

public struct BreadboardWire: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var a: BreadboardHole
    public var b: BreadboardHole

    public init(id: String, a: BreadboardHole, b: BreadboardHole) {
        self.id = id
        self.a = a
        self.b = b
    }
}

public enum BreadboardError: Error, Equatable, Sendable, LocalizedError {
    case invalidHole(BreadboardHole)
    case invalidPins(id: String, expected: Int, actual: Int)
    case repeatedPin(String)
    case incompatibleComponent(id: String, mode: BreadboardMode)
    case incompatibleAnalysis(BreadboardMode)
    case emptyIdentifier
    case duplicateIdentifier(String)
    case tooManyComponents
    case tooManyWires
    case invalidUnusedValue(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidHole(hole): "\(hole.label) is outside this 12-row breadboard."
        case let .invalidPins(id, expected, actual): "\(id) requires \(expected) pins; received \(actual)."
        case let .repeatedPin(id): "\(id) has two pins in the same hole. Choose distinct holes."
        case let .incompatibleComponent(id, mode): "\(id) cannot be placed in \(mode.title.lowercased()) mode."
        case let .incompatibleAnalysis(mode): "This analysis requires \(mode.title.lowercased()) mode."
        case .emptyIdentifier: "Components and wires need nonempty identifiers."
        case let .duplicateIdentifier(id): "The identifier \(id) is used more than once."
        case .tooManyComponents: "This sandbox supports up to 32 components."
        case .tooManyWires: "This sandbox supports up to 64 jumpers."
        case let .invalidUnusedValue(id): "\(id) contains a nonfinite value."
        }
    }
}

public struct BreadboardDocument: Codable, Equatable, Sendable {
    public var mode: BreadboardMode
    public var components: [BreadboardComponent]
    public var wires: [BreadboardWire]
    public var ground: BreadboardHole

    public init(mode: BreadboardMode = .analog, components: [BreadboardComponent] = [],
                wires: [BreadboardWire] = [], ground: BreadboardHole = .init(row: 0, column: .leftNegative)) {
        self.mode = mode
        self.components = components
        self.wires = wires
        self.ground = ground
    }

    /// Mutable editing can form a temporarily incomplete document. Compilation always validates it.
    public func validate() throws {
        guard components.count <= 32 else { throw BreadboardError.tooManyComponents }
        guard wires.count <= 64 else { throw BreadboardError.tooManyWires }
        guard ground.isValid else { throw BreadboardError.invalidHole(ground) }
        var identifiers = Set<String>()
        func checkID(_ id: String) throws {
            guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw BreadboardError.emptyIdentifier
            }
            guard identifiers.insert(id).inserted else { throw BreadboardError.duplicateIdentifier(id) }
        }
        for component in components {
            try checkID(component.id)
            guard component.kind.isAnalog == (mode == .analog) else {
                throw BreadboardError.incompatibleComponent(id: component.id, mode: mode)
            }
            guard component.pins.count == component.kind.pinCount else {
                throw BreadboardError.invalidPins(id: component.id, expected: component.kind.pinCount, actual: component.pins.count)
            }
            for hole in component.pins where !hole.isValid { throw BreadboardError.invalidHole(hole) }
            guard Set(component.pins).count == component.pins.count else { throw BreadboardError.repeatedPin(component.id) }
            // The shared Circuit validator sees the complete terminal list, rather than a
            // misleading two-node representation of a transistor or powered amplifier.
            if let element = component.element(nodes: Array(1...component.kind.pinCount)) {
                try Circuit(elements: [element]).validate()
            }
            // Keep every saved profile valid, including profiles not used by the current kind.
            try component.diodeModel.validate(id: component.id)
            try component.bjtModel.validate(id: component.id)
            try component.mosfetModel.validate(id: component.id)
            try component.opAmpModel.validate(id: component.id)
            guard component.value.isFinite, component.initialValue.isFinite else {
                throw BreadboardError.invalidUnusedValue(component.id)
            }
        }
        for wire in wires {
            try checkID(wire.id)
            guard wire.a.isValid else { throw BreadboardError.invalidHole(wire.a) }
            guard wire.b.isValid else { throw BreadboardError.invalidHole(wire.b) }
        }
    }

    /// Reuses the same MNA, DC limits, initial-condition checks and transient integrator as the lessons.
    public func makeCircuit() throws -> Circuit {
        guard mode == .analog else { throw BreadboardError.incompatibleAnalysis(.analog) }
        let topology = try BreadboardTopology(document: self)
        let elements = try components.map { component in
            let nodes = try component.pins.map { hole in
                guard let node = topology.node(for: hole) else { throw BreadboardError.invalidHole(hole) }
                return node
            }
            guard let element = component.element(nodes: nodes) else {
                throw BreadboardError.incompatibleComponent(id: component.id, mode: mode)
            }
            return element
        }
        let circuit = Circuit(elements: elements)
        try circuit.validate()
        return circuit
    }

    public func solveLogic() throws -> BreadboardLogicResult {
        try BreadboardLogicSolver.solve(self)
    }

    private enum CodingKeys: String, CodingKey { case mode, components, wires, ground }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(BreadboardMode.self, forKey: .mode)
        components = try container.decode([BreadboardComponent].self, forKey: .components)
        wires = try container.decode([BreadboardWire].self, forKey: .wires)
        ground = try container.decode(BreadboardHole.self, forKey: .ground)
        try validate()
    }

    public static func empty(mode: BreadboardMode = .analog) -> BreadboardDocument { .init(mode: mode) }

    public static var divider: BreadboardDocument {
        let supply = BreadboardHole(row: 0, column: .a)
        let middle = BreadboardHole(row: 2, column: .a)
        let ground = BreadboardHole(row: 0, column: .leftNegative)
        return .init(components: [
            .init(id: "V1", kind: .voltageSource, pins: [supply, ground], value: 5),
            .init(id: "R1", kind: .resistor, pins: [.init(row: 0, column: .c), middle], value: 1_000),
            .init(id: "R2", kind: .resistor, pins: [.init(row: 2, column: .c), .init(row: 4, column: .a)], value: 1_000)
        ], wires: [
            .init(id: "W1", a: .init(row: 4, column: .c), b: .init(row: 4, column: .leftNegative))
        ])
    }

    public static var rc: BreadboardDocument {
        var document = divider
        document.components[2] = .init(id: "C1", kind: .capacitor, pins: document.components[2].pins,
                                       value: 0.001, initialValue: 0)
        return document
    }

    /// A resistor-limited positive clipper with a 10 kΩ output load.
    /// Its junction voltage follows the diode profile, rather than a fixed 0.7 V threshold.
    public static var diodeClipper: BreadboardDocument {
        .init(components: [
            .init(id: "V1", kind: .voltageSource, pins: [contact(.a, 1), contact(.leftNegative, 1)], value: 5),
            .init(id: "R1", kind: .resistor, pins: [contact(.c, 1), contact(.a, 3)], value: 1_000),
            .init(id: "D1", kind: .diode, pins: [contact(.c, 3), contact(.a, 5)], value: 0),
            .init(id: "R2", kind: .resistor, pins: [contact(.e, 3), contact(.c, 5)], value: 10_000)
        ], wires: [.init(id: "W1", a: contact(.e, 5), b: contact(.leftNegative, 5))])
    }

    /// An editable generic red LED profile, with a 330 Ω current-limiting resistor.
    public static var ledResistor: BreadboardDocument {
        var document = diodeClipper
        document.components[1].value = 330
        document.components[2].id = "LED1"
        document.components[2].kind = .led
        document.components[2].diodeModel = .redLED
        return document
    }

    /// A low-side NPN switch. V2 drives the base through 4.7 kΩ; R1 is the collector load.
    /// A 100 kΩ base pull-down remains physically present when the drive source is edited.
    public static var npnSwitch: BreadboardDocument {
        .init(components: [
            .init(id: "V1", kind: .voltageSource, pins: [contact(.a, 1), contact(.leftNegative, 1)], value: 5),
            .init(id: "V2", kind: .voltageSource, pins: [contact(.a, 7), contact(.leftNegative, 7)], value: 5),
            .init(id: "R1", kind: .resistor, pins: [contact(.c, 1), contact(.a, 3)], value: 1_000),
            .init(id: "R2", kind: .resistor, pins: [contact(.c, 7), contact(.a, 5)], value: 4_700),
            .init(id: "R3", kind: .resistor, pins: [contact(.e, 5), contact(.leftNegative, 5)], value: 100_000),
            .init(id: "Q1", kind: .npn, pins: [contact(.c, 3), contact(.c, 5), contact(.a, 9)], value: 0)
        ], wires: [.init(id: "W1", a: contact(.c, 9), b: contact(.leftNegative, 9))])
    }

    /// A low-side N-channel switch with a resistor load and a gate pull-down.
    /// V2 is a separate, editable gate drive; no analog-to-logic threshold bridge is involved.
    public static var mosfetSwitch: BreadboardDocument {
        .init(components: [
            .init(id: "V1", kind: .voltageSource, pins: [contact(.a, 1), contact(.leftNegative, 1)], value: 5),
            .init(id: "V2", kind: .voltageSource, pins: [contact(.a, 5), contact(.leftNegative, 5)], value: 5),
            .init(id: "R1", kind: .resistor, pins: [contact(.c, 1), contact(.a, 3)], value: 1_000),
            .init(id: "R2", kind: .resistor, pins: [contact(.e, 5), contact(.leftNegative, 6)], value: 100_000),
            .init(id: "M1", kind: .nmos, pins: [contact(.c, 3), contact(.c, 5), contact(.a, 9)], value: 0)
        ], wires: [.init(id: "W1", a: contact(.c, 9), b: contact(.leftNegative, 9))])
    }

    /// A powered, loaded voltage follower. The feedback jumper crosses the center channel.
    /// U1 has actual V+ and V− contacts, finite gain, output resistance and supply currents.
    public static var opAmpFollower: BreadboardDocument {
        .init(components: [
            .init(id: "V1", kind: .voltageSource, pins: [contact(.a, 1), contact(.leftNegative, 1)], value: 5),
            .init(id: "V2", kind: .voltageSource, pins: [contact(.a, 3), contact(.leftNegative, 3)], value: 2.5),
            .init(id: "R1", kind: .resistor, pins: [contact(.h, 5), contact(.leftNegative, 5)], value: 1_000),
            .init(id: "U1", kind: .opAmp,
                  pins: [contact(.c, 3), contact(.c, 5), contact(.f, 5), contact(.c, 1), contact(.leftNegative, 6)], value: 0)
        ], wires: [.init(id: "W1", a: contact(.e, 5), b: contact(.g, 5))])
    }

    private static func contact(_ column: BreadboardColumn, _ row: Int) -> BreadboardHole {
        .init(row: row - 1, column: column)
    }

    public static var andGate: BreadboardDocument {
        .init(mode: .logic, components: [
            .init(id: "A", kind: .logicInput, pins: [.init(row: 0, column: .a)], value: 0, logicValue: .zero),
            .init(id: "B", kind: .logicInput, pins: [.init(row: 2, column: .a)], value: 0, logicValue: .one),
            .init(id: "G1", kind: .and,
                  pins: [.init(row: 0, column: .c), .init(row: 2, column: .c), .init(row: 4, column: .f)], value: 0)
        ])
    }
}

/// Wires and internal metal strips are ideal edges; components never merge nets.
public struct BreadboardTopology: Sendable {
    private let nodesByHole: [BreadboardHole: Int]
    private let holesByNode: [Int: [BreadboardHole]]
    public var nodes: [Int] { holesByNode.keys.sorted() }

    public init(document: BreadboardDocument) throws {
        try document.validate()
        let holes = BreadboardHole.all
        let indices = Dictionary(uniqueKeysWithValues: holes.enumerated().map { ($0.element, $0.offset) })
        var parents = Array(holes.indices)
        func root(_ index: Int) -> Int {
            var current = index
            while parents[current] != current { current = parents[current] }
            return current
        }
        func join(_ a: Int, _ b: Int) {
            let first = root(a), second = root(b)
            if first != second { parents[max(first, second)] = min(first, second) }
        }
        for row in 0..<12 {
            for rawColumn in 3...6 { join(indices[.init(row: row, column: .a)]!, indices[.init(row: row, column: BreadboardColumn(rawValue: rawColumn)!)]!) }
            for rawColumn in 8...11 { join(indices[.init(row: row, column: .f)]!, indices[.init(row: row, column: BreadboardColumn(rawValue: rawColumn)!)]!) }
        }
        for column in BreadboardColumn.allCases where column.isRail {
            for row in 1..<12 { join(indices[.init(row: 0, column: column)]!, indices[.init(row: row, column: column)]!) }
        }
        for wire in document.wires { join(indices[wire.a]!, indices[wire.b]!) }
        let groundedRoot = root(indices[document.ground]!)
        var nodeByRoot = [groundedRoot: 0]
        var nextNode = 1
        var mapping: [BreadboardHole: Int] = [:]
        var members: [Int: [BreadboardHole]] = [:]
        for (index, hole) in holes.enumerated() {
            let group = root(index)
            if nodeByRoot[group] == nil { nodeByRoot[group] = nextNode; nextNode += 1 }
            let node = nodeByRoot[group]!
            mapping[hole] = node
            members[node, default: []].append(hole)
        }
        nodesByHole = mapping
        holesByNode = members
    }

    public func node(for hole: BreadboardHole) -> Int? { nodesByHole[hole] }
    public func connectedHoles(to hole: BreadboardHole) -> [BreadboardHole] {
        guard let node = nodesByHole[hole] else { return [] }
        return holesByNode[node, default: []]
    }
}

public struct BreadboardLogicDiagnostic: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable { case feedback, conflictingDrivers, unknownDriver }
    public let kind: Kind
    public let componentIDs: [String]
    public let node: Int?
    public let message: String
    public var id: String { "\(kind.rawValue):\(node.map(String.init) ?? componentIDs.joined(separator: ","))" }
}

public struct BreadboardLogicResult: Sendable {
    public let topology: BreadboardTopology
    public let netValues: [Int: LogicLevel]
    public let componentOutputs: [String: LogicLevel]
    public let diagnostics: [BreadboardLogicDiagnostic]
    public func logic(at hole: BreadboardHole) -> LogicLevel? {
        topology.node(for: hole).flatMap { netValues[$0] }
    }
}

public enum BreadboardLogicSolver {
    /// Combinational, equal-strength four-state evaluation. Cyclic gates are explicitly X.
    public static func solve(_ document: BreadboardDocument) throws -> BreadboardLogicResult {
        guard document.mode == .logic else { throw BreadboardError.incompatibleAnalysis(.logic) }
        let topology = try BreadboardTopology(document: document)
        let byID = Dictionary(uniqueKeysWithValues: document.components.map { ($0.id, $0) })
        let gates = document.components.filter { $0.kind.gate != nil }
        var drivers: [Int: [String]] = [:]
        for component in document.components {
            let output = component.pins.last!
            drivers[topology.node(for: output)!, default: []].append(component.id)
        }
        var dependencies: [String: [String]] = [:]
        for gate in gates {
            let inputNodes = gate.pins.dropLast().map { topology.node(for: $0)! }
            dependencies[gate.id] = Set(inputNodes.flatMap { drivers[$0, default: []] }.filter { byID[$0]?.kind.gate != nil }).sorted()
        }

        // A gate is in a feedback cycle exactly when its dependency graph can reach itself.
        // At this small board limit, per-gate reachability is simpler than carrying an SCC algorithm.
        var cyclic = Set<String>()
        for gate in gates {
            var pending = dependencies[gate.id, default: []]
            var visited = Set<String>()
            while let id = pending.popLast() {
                if id == gate.id { cyclic.insert(gate.id); break }
                if visited.insert(id).inserted { pending.append(contentsOf: dependencies[id, default: []]) }
            }
        }
        var outputs: [String: LogicLevel] = [:]
        for component in document.components where component.kind == .logicInput { outputs[component.id] = component.logicValue }
        for id in cyclic { outputs[id] = .unknown }
        func evaluate(_ id: String) throws -> LogicLevel {
            if let known = outputs[id] { return known }
            let component = byID[id]!
            let inputs = try component.pins.dropLast().map { hole in
                let node = topology.node(for: hole)!
                return LogicLevel.resolve(drivers: try drivers[node, default: []].map { try evaluate($0) })
            }
            let value = try component.kind.gate!.evaluate(inputs)
            outputs[id] = value
            return value
        }
        for gate in gates { _ = try evaluate(gate.id) }
        var values: [Int: LogicLevel] = [:]
        var diagnostics: [BreadboardLogicDiagnostic] = []
        if !cyclic.isEmpty {
            let ids = cyclic.sorted()
            diagnostics.append(.init(kind: .feedback, componentIDs: ids, node: nil,
                                     message: "Feedback through \(ids.joined(separator: ", ")) is marked X. This combinational model does not simulate storage, oscillation, or propagation delay."))
        }
        for node in topology.nodes {
            let ids = drivers[node, default: []].sorted()
            let levels = ids.map { outputs[$0]! }
            values[node] = LogicLevel.resolve(drivers: levels)
            let active = levels.filter { $0 != .highImpedance }
            if active.contains(.zero) && active.contains(.one) {
                diagnostics.append(.init(kind: .conflictingDrivers, componentIDs: ids, node: node,
                                         message: "Net \(node) has opposing 0 and 1 drivers and resolves to X."))
            } else if active.contains(.unknown) {
                diagnostics.append(.init(kind: .unknownDriver, componentIDs: ids, node: node,
                                         message: "Net \(node) has an unknown driver and resolves to X."))
            }
        }
        return .init(topology: topology, netValues: values, componentOutputs: outputs, diagnostics: diagnostics)
    }
}
