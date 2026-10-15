import Foundation
import Observation
import CircuitCore

enum PartKind: String, Codable, CaseIterable, Identifiable {
    case resistor = "Resistor", voltage = "Voltage source", current = "Current source"
    var id: String { rawValue }
    var prefix: String { switch self { case .resistor: "R"; case .voltage: "V"; case .current: "I" } }
    var unit: String { switch self { case .resistor: "Ω"; case .voltage: "V"; case .current: "mA" } }
    var range: ClosedRange<Double> { switch self { case .resistor: 10...10000; case .voltage: -12...12; case .current: -20...20 } }
}

struct BoardPart: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var name: String
    var kind: PartKind
    var a: Int
    var b: Int
    var value: Double
    var element: CircuitElement {
        switch kind {
        case .resistor: .resistor(id: id, a: a, b: b, ohms: value)
        case .voltage: .voltageSource(id: id, a: a, b: b, volts: value)
        case .current: .currentSource(id: id, a: a, b: b, amps: value / 1000)
        }
    }
    var displayValue: String { engineering(kind == .current ? value / 1000 : value, unit: kind == .current ? "A" : kind.unit) }
}

enum BenchPreset: String, CaseIterable, Identifiable {
    case divider = "Divider", series = "Series", parallel = "Parallel", bridge = "Bridge"
    var id: String { rawValue }
    var parts: [BoardPart] {
        let source = BoardPart(name: "V1", kind: .voltage, a: 1, b: 0, value: 5)
        switch self {
        case .divider: return [source, .init(name: "R1", kind: .resistor, a: 1, b: 2, value: 1000), .init(name: "R2", kind: .resistor, a: 2, b: 0, value: 1000)]
        case .series: return [source, .init(name: "R1", kind: .resistor, a: 1, b: 2, value: 1000), .init(name: "R2", kind: .resistor, a: 2, b: 3, value: 1000), .init(name: "R3", kind: .resistor, a: 3, b: 0, value: 1000)]
        case .parallel: return [source, .init(name: "R1", kind: .resistor, a: 1, b: 0, value: 1000), .init(name: "R2", kind: .resistor, a: 1, b: 0, value: 2000)]
        case .bridge: return [source, .init(name: "R1", kind: .resistor, a: 1, b: 2, value: 1000), .init(name: "R2", kind: .resistor, a: 2, b: 0, value: 1000), .init(name: "R3", kind: .resistor, a: 1, b: 3, value: 1000), .init(name: "R4", kind: .resistor, a: 3, b: 0, value: 1000), .init(name: "R5", kind: .resistor, a: 2, b: 3, value: 1000)]
        }
    }
}

@MainActor @Observable final class BenchStore {
    var parts: [BoardPart]
    var selectedNode = 2
    var preset = BenchPreset.divider
    private var history: [[BoardPart]] = []
    private let key = "CircuitToy.bench.v1"
    init() {
        if let data = UserDefaults.standard.data(forKey: key), let decoded = try? JSONDecoder().decode([BoardPart].self, from: data),
           decoded.count <= 20, decoded.allSatisfy({ $0.a != $0.b && (0...3).contains($0.a) && (0...3).contains($0.b) && $0.value.isFinite && $0.kind.range.contains($0.value) }) {
            parts = decoded
        } else { parts = BenchPreset.divider.parts }
    }
    var solution: Result<CircuitSolution, Error> { Result { try CircuitSolver.solveDC(Circuit(elements: parts.map(\.element))) } }
    var canUndo: Bool { !history.isEmpty }
    func load(_ preset: BenchPreset) { self.preset = preset; change(preset.parts) }
    func save(_ part: BoardPart) {
        var next = parts
        if let index = next.firstIndex(where: { $0.id == part.id }) { next[index] = part } else { next.append(part) }
        change(next)
    }
    func remove(_ id: String) { change(parts.filter { $0.id != id }) }
    func undo() { guard let old = history.popLast() else { return }; parts = old; persist() }
    private func change(_ next: [BoardPart]) {
        history.append(parts); if history.count > 30 { history.removeFirst() }
        parts = next; persist()
    }
    private func persist() { if let data = try? JSONEncoder().encode(parts) { UserDefaults.standard.set(data, forKey: key) } }
    func newPart() -> BoardPart {
        var number = 1; while parts.contains(where: { $0.name == "R\(number)" }) { number += 1 }
        return BoardPart(name: "R\(number)", kind: .resistor, a: 2, b: 0, value: 1000)
    }
}
