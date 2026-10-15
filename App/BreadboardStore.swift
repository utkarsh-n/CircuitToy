import Foundation
import Observation
import CircuitCore

@MainActor @Observable final class BreadboardStore {
    enum Analysis: String, CaseIterable { case dc = "DC", transient = "Transient" }
    private(set) var document: BreadboardDocument
    private(set) var topology: BreadboardTopology?
    private(set) var solution: CircuitSolution?
    private(set) var logic: BreadboardLogicResult?
    private(set) var diagnostic: String?
    private(set) var samples: [CircuitSolution] = []
    var selectedHole: BreadboardHole? = BreadboardHole(row: 2, column: .a)
    var selectedComponentID: String? {
        didSet {
            if oldValue != selectedComponentID {
                selectedTerminalIndex = selectedComponent?.kind.primaryCurrentTerminal ?? 0
            }
        }
    }
    var selectedTerminalIndex = 0
    private(set) var analysis: Analysis = .dc
    var isRunning = false
    private(set) var timeStep = 0.001
    private var simulator: TransientSimulator?
    private var histories: [BreadboardMode: [BreadboardDocument]] = [:]
    private var documents: [BreadboardMode: BreadboardDocument] = [:]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var restored: [BreadboardMode: BreadboardDocument] = [:]
        for mode in [BreadboardMode.analog, .logic] {
            let fallback: BreadboardDocument = mode == .analog ? .divider : .andGate
            if let data = defaults.data(forKey: Self.key(mode)),
               let decoded = try? JSONDecoder().decode(BreadboardDocument.self, from: data),
               decoded.mode == mode, (try? BreadboardTopology(document: decoded)) != nil {
                restored[mode] = decoded
            } else { restored[mode] = fallback }
        }
        document = restored[.analog] ?? .divider
        documents = restored
        rebuild()
    }

    var canUndo: Bool { !(histories[document.mode] ?? []).isEmpty }
    var elapsedTime: Double { solution?.time ?? 0 }
    var connected: Set<BreadboardHole> {
        guard let selectedHole, let topology else { return [] }
        return Set(topology.connectedHoles(to: selectedHole))
    }
    var selectedComponent: BreadboardComponent? { document.components.first { $0.id == selectedComponentID } }
    var probeVoltage: Double? {
        guard let selectedHole, let topology, let node = topology.node(for: selectedHole) else { return nil }
        return solution?.voltage(at: node)
    }
    var probeCurrent: Double? {
        guard let selectedComponentID else { return nil }
        if let terminals = solution?.terminalCurrents[selectedComponentID] {
            return terminals.indices.contains(selectedTerminalIndex) ? terminals[selectedTerminalIndex] : nil
        }
        guard selectedTerminalIndex == 0 else { return nil }
        return solution?.current(through: selectedComponentID)
    }
    var probeCurrentLabel: String {
        guard let component = selectedComponent,
              component.kind.pinLabels.indices.contains(selectedTerminalIndex) else { return "Current" }
        return "\(component.id) · \(component.kind.pinLabels[selectedTerminalIndex])"
    }
    func selectCurrentProbe(_ id: String, terminalIndex: Int? = nil) {
        selectedComponentID = id
        selectedTerminalIndex = terminalIndex ?? selectedComponent?.kind.primaryCurrentTerminal ?? 0
    }
    var probeLogic: LogicLevel? {
        guard let selectedHole else { return nil }
        return logic?.logic(at: selectedHole)
    }
    var voltageSamples: [Double] {
        guard let hole = selectedHole, let node = topology?.node(for: hole) else { return [] }
        return samples.compactMap { $0.voltage(at: node) }
    }
    var currentSamples: [Double] {
        guard let id = selectedComponentID else { return [] }
        return samples.compactMap {
            if let currents = $0.terminalCurrents[id] {
                return currents.indices.contains(selectedTerminalIndex) ? currents[selectedTerminalIndex] : nil
            }
            return selectedTerminalIndex == 0 ? $0.current(through: id) : nil
        }
    }

    func switchMode(_ mode: BreadboardMode) {
        guard mode != document.mode else { return }
        isRunning = false
        documents[document.mode] = document
        document = documents[mode] ?? .empty(mode: mode)
        selectedComponentID = nil
        selectedHole = BreadboardHole(row: 2, column: .a)
        analysis = .dc
        rebuild()
    }
    func load(_ next: BreadboardDocument) {
        do { try next.validate() }
        catch { diagnostic = error.localizedDescription; return }
        if next.mode != document.mode { switchMode(next.mode) }
        guard change(next) else { return }
        selectedHole = BreadboardHole(row: 2, column: .a)
        selectedComponentID = nil
    }
    func add(_ kind: BreadboardComponentKind, pins: [BreadboardHole]) {
        var index = 1
        let prefix: String = switch kind {
        case .resistor: "R"
        case .voltageSource: "V"
        case .currentSource: "I"
        case .capacitor: "C"
        case .inductor: "L"
        case .diode: "D"
        case .led: "LED"
        case .npn, .pnp: "Q"
        case .nmos, .pmos: "M"
        case .opAmp: "U"
        case .logicInput: "IN"
        default: "G"
        }
        let identifiers = Set(document.components.map(\.id) + document.wires.map(\.id))
        while identifiers.contains("\(prefix)\(index)") { index += 1 }
        let id = "\(prefix)\(index)"
        var next = document
        next.components.append(.init(id: id, kind: kind, pins: pins, value: kind.defaultValue))
        if change(next) { selectedComponentID = id }
    }
    func save(_ component: BreadboardComponent) {
        var next = document
        guard let index = next.components.firstIndex(where: { $0.id == component.id }) else { return }
        next.components[index] = component
        change(next)
    }
    func removeComponent(_ id: String) {
        var next = document; next.components.removeAll { $0.id == id }; change(next)
        if selectedComponentID == id { selectedComponentID = nil }
    }
    func toggleInput(_ id: String) {
        guard var component = document.components.first(where: { $0.id == id }), component.kind == .logicInput else { return }
        component.logicValue = component.logicValue == .one ? .zero : .one
        save(component)
    }
    func addWire(from a: BreadboardHole, to b: BreadboardHole) {
        guard a != b else { return }
        var next = document; var index = 1
        let identifiers = Set(next.components.map(\.id) + next.wires.map(\.id))
        while identifiers.contains("W\(index)") { index += 1 }
        next.wires.append(.init(id: "W\(index)", a: a, b: b)); change(next)
    }
    func removeWire(_ id: String) {
        var next = document; next.wires.removeAll { $0.id == id }; change(next)
    }
    func setGround(_ hole: BreadboardHole) {
        var next = document; next.ground = hole; change(next)
    }
    func undo() {
        guard let previous = histories[document.mode]?.popLast() else { return }
        document = previous; persist(); rebuild()
        if !document.components.contains(where: { $0.id == selectedComponentID }) { selectedComponentID = nil }
    }
    func setAnalysis(_ next: Analysis) {
        guard analysis != next else { return }; analysis = next; rebuild()
    }
    func setTimeStep(_ next: Double) {
        guard next.isFinite, next > 0, next != timeStep else { return }; timeStep = next; rebuild()
    }
    func reset() { rebuild() }
    func advance(steps: Int = 1) {
        guard analysis == .transient, document.mode == .analog, var simulation = simulator else { return }
        do {
            for _ in 0..<min(max(steps, 1), 20) {
                let next = try simulation.step(timeStep: timeStep)
                simulator = simulation; solution = next; samples.append(next)
            }
            if samples.count > 240 { samples.removeFirst(samples.count - 240) }
            simulator = simulation; diagnostic = nil
        } catch { diagnostic = error.localizedDescription; isRunning = false }
    }
    @discardableResult private func change(_ next: BreadboardDocument) -> Bool {
        do { _ = try BreadboardTopology(document: next) }
        catch { diagnostic = error.localizedDescription; return false }
        guard next != document else { return true }
        histories[document.mode, default: []].append(document)
        if histories[document.mode, default: []].count > 30 { histories[document.mode]?.removeFirst() }
        document = next; persist(); rebuild()
        return true
    }
    private func persist() {
        documents[document.mode] = document
        if let data = try? JSONEncoder().encode(document) { defaults.set(data, forKey: Self.key(document.mode)) }
    }
    private func rebuild() {
        isRunning = false; simulator = nil; solution = nil; logic = nil; samples = []; diagnostic = nil
        do {
            topology = try BreadboardTopology(document: document)
            if document.mode == .logic {
                logic = try document.solveLogic()
            } else if !document.components.isEmpty {
                let circuit = try document.makeCircuit()
                if analysis == .dc { solution = try CircuitSolver.solveDC(circuit) }
                else { simulator = try TransientSimulator(circuit: circuit) }
            }
        } catch { diagnostic = error.localizedDescription }
    }
    private static func key(_ mode: BreadboardMode) -> String { "CircuitToy.breadboard.\(mode.rawValue).v1" }
}
