/// Modified nodal analysis with additional unknown currents for voltage sources and inductors.
/// Every node equation enforces KCL; branch equations enforce each ideal constitutive law.
public enum CircuitSolver {
    public static func solveDC(_ circuit: Circuit) throws -> CircuitSolution {
        try solve(circuit, mode: .dc, time: 0)
    }

    fileprivate enum Mode {
        case dc
        case transient(dt: Double, capacitorVoltages: [String: Double], inductorCurrents: [String: Double])

        var isTransient: Bool {
            if case .transient = self { return true }
            return false
        }
    }

    fileprivate static func checkReference(_ circuit: Circuit, transient: Bool) throws {
        var adjacency: [Int: [Int]] = [:]
        for element in circuit.elements {
            let pinsVoltage: Bool
            switch element {
            case .resistor, .voltageSource, .inductor: pinsVoltage = true
            case .capacitor: pinsVoltage = transient
            case .currentSource: pinsVoltage = false
            case .diode, .bjt, .mosfet, .opAmp: pinsVoltage = true
            }
            if pinsVoltage {
                let pins = element.conductiveTerminalNodes
                for pin in pins.dropFirst() {
                    adjacency[pins[0], default: []].append(pin)
                    adjacency[pin, default: []].append(pins[0])
                }
            }
        }
        var reached: Set<Int> = [0]
        var pending = [0]
        while let node = pending.popLast() {
            for neighbor in adjacency[node, default: []] where reached.insert(neighbor).inserted {
                pending.append(neighbor)
            }
        }
        let floating = circuit.nodes.filter { !reached.contains($0) }
        if !floating.isEmpty { throw CircuitError.floatingNodes(floating) }
    }

    fileprivate static func solve(_ circuit: Circuit, mode: Mode, time: Double, initialGuess: [Int: Double] = [:]) throws -> CircuitSolution {
        try circuit.validate()
        try checkReference(circuit, transient: mode.isTransient)
        let nodes = circuit.nodes.filter { $0 != 0 }
        let nodeIndices = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element, $0.offset) })
        let branches = circuit.elements.filter {
            switch $0 { case .voltageSource, .inductor: true; default: false }
        }
        let branchIndices = Dictionary(uniqueKeysWithValues: branches.enumerated().map { ($0.element.id, nodes.count + $0.offset) })
        let size = nodes.count + branches.count
        var matrix = Array(repeating: Array(repeating: 0.0, count: size), count: size)
        var rhs = Array(repeating: 0.0, count: size)

        func add(_ row: Int?, _ col: Int?, _ value: Double) {
            if let row, let col { matrix[row][col] += value }
        }
        func stampConductance(_ a: Int, _ b: Int, _ g: Double) {
            let ai = nodeIndices[a], bi = nodeIndices[b]
            add(ai, ai, g); add(bi, bi, g)
            add(ai, bi, -g); add(bi, ai, -g)
        }
        func stampCurrent(_ a: Int, _ b: Int, _ current: Double) {
            if let ai = nodeIndices[a] { rhs[ai] -= current }
            if let bi = nodeIndices[b] { rhs[bi] += current }
        }
        func stampVoltageBranch(_ element: CircuitElement, _ voltage: Double, _ resistance: Double = 0) {
            guard let branch = branchIndices[element.id] else { return }
            let ai = nodeIndices[element.a], bi = nodeIndices[element.b]
            add(ai, branch, 1); add(bi, branch, -1)
            add(branch, ai, 1); add(branch, bi, -1)
            add(branch, branch, -resistance)
            rhs[branch] += voltage
        }

        for element in circuit.elements {
            switch element {
            case let .resistor(_, a, b, ohms): stampConductance(a, b, 1 / ohms)
            case let .voltageSource(_, _, _, volts): stampVoltageBranch(element, volts)
            case let .currentSource(_, a, b, amps): stampCurrent(a, b, amps)
            case let .capacitor(id, a, b, farads, _):
                if case let .transient(dt, previous, _) = mode {
                    let g = farads / dt
                    stampConductance(a, b, g)
                    stampCurrent(a, b, -g * previous[id, default: 0])
                }
            case let .inductor(id, _, _, henrys, _):
                switch mode {
                case .dc: stampVoltageBranch(element, 0)
                case let .transient(dt, _, previous):
                    let resistance = henrys / dt
                    // v − (L/h)i = −(L/h)i_previous.
                    stampVoltageBranch(element, -resistance * previous[id, default: 0], resistance)
                }
            case .diode, .bjt, .mosfet, .opAmp: break
            }
        }
        let nonlinear = circuit.elements.filter(\.isNonlinear)
        let unknowns = nonlinear.isEmpty ? try LinearSystem.solve(matrix, rhs) :
            try solveNonlinear(circuit, matrix: matrix, rhs: rhs, nodes: nodes, nodeIndices: nodeIndices,
                               nonlinear: nonlinear, initialGuess: initialGuess)
        var voltages: [Int: Double] = [0: 0]
        for node in nodes { voltages[node] = unknowns[nodeIndices[node]!] }
        var currents: [String: Double] = [:]
        var residuals = Dictionary(uniqueKeysWithValues: circuit.nodes.map { ($0, 0.0) })
        residuals[0] = 0
        var powers: [String: Double] = [:]
        var terminalCurrents: [String: [Double]] = [:]
        var currentScales: [Int: Double] = [:]
        var currentRoundoff: [Int:Double] = [:]
        for element in circuit.elements {
            let voltage = voltages[element.a, default: 0] - voltages[element.b, default: 0]
            let current: Double
            let terminals: [Double]
            let terminalRoundoff:[Double]
            switch element {
            case let .resistor(_, _, _, ohms):
                current = voltage / ohms; terminals = [current,-current]
                let error=(voltages[element.a,default:0].ulp+voltages[element.b,default:0].ulp)/ohms+current.ulp
                terminalRoundoff=[error,error]
            case .voltageSource, .inductor:
                current = unknowns[branchIndices[element.id]!]; terminals = [current,-current]
                terminalRoundoff=[current.ulp,current.ulp]
            case let .currentSource(_, _, _, amps):
                current = amps; terminals = [current,-current]; terminalRoundoff=[amps.ulp,amps.ulp]
            case let .capacitor(id, _, _, farads, _):
                switch mode {
                case .dc: current = 0
                case let .transient(dt, previous, _): current = farads / dt * (voltage - previous[id, default: 0])
                }
                terminals = [current,-current]
                if case let .transient(dt,previous,_) = mode {
                    let error=farads/dt*(voltages[element.a,default:0].ulp+voltages[element.b,default:0].ulp+previous[id,default:0].ulp)+current.ulp
                    terminalRoundoff=[error,error]
                } else { terminalRoundoff=[0,0] }
            case .diode, .bjt, .mosfet, .opAmp:
                let pinVoltages = element.terminalNodes.map { voltages[$0,default:0] }
                try element.validateOperatingPoint(pinVoltages)
                let evaluated=try element.deviceCurrents(pinVoltages)
                terminals = evaluated.map(\.value)
                terminalRoundoff=evaluated.map { terminal in
                    zip(terminal.derivatives,pinVoltages).reduce(terminal.value.ulp) { $0+abs($1.0)*$1.1.ulp }
                }
                if case .opAmp = element { current = terminals[2] } else { current = terminals[0] }
            }
            let power = element.isNonlinear ? zip(element.terminalNodes,terminals).reduce(0.0) { $0 + voltages[$1.0,default:0]*$1.1 } : voltage*current
            guard current.isFinite, voltage.isFinite, power.isFinite else { throw CircuitError.numericalRange }
            currents[element.id] = current
            powers[element.id] = power
            terminalCurrents[element.id] = terminals
            for (pin,node) in element.terminalNodes.enumerated() {
                let terminalCurrent=terminals[pin]
                residuals[node,default:0] += terminalCurrent
                currentScales[node,default:0] += abs(terminalCurrent)
                currentRoundoff[node,default:0] += terminalRoundoff[pin]
            }
        }
        guard residuals.values.allSatisfy(\.isFinite) else { throw CircuitError.numericalRange }
        if !nonlinear.isEmpty {
            // Ground's eliminated KCL equation inherits the rounding budgets of all
            // non-ground equations, including remote resistors at nearly equal voltages.
            currentRoundoff[0,default:0] += currentRoundoff.filter { $0.key != 0 }.values.reduce(0,+)
            for (node,residual) in residuals {
                let tolerance=1e-9*max(currentScales[node,default:0],Double.leastNormalMagnitude)+32*currentRoundoff[node,default:0]
                guard abs(residual) <= tolerance else { throw CircuitError.nonlinearConvergence(iterations:200) }
            }
            let powerScale=powers.values.reduce(0) { $0+abs($1) }
            let roundoffPower=currentRoundoff.reduce(0.0) { $0+32*abs(voltages[$1.key,default:0])*$1.value }
            guard abs(powers.values.reduce(0,+)) <= 1e-9*max(powerScale,Double.leastNormalMagnitude)+roundoffPower else { throw CircuitError.numericalRange }
        }
        return CircuitSolution(time: time, nodeVoltages: voltages, branchCurrents: currents, kclResiduals: residuals, branchPowers: powers, terminalCurrents:terminalCurrents)
    }

    /// Damped Newton on the original MNA equations. Step limiting is only a search
    /// strategy: accepted solutions are checked against unclamped device equations.
    private static func solveNonlinear(_ circuit: Circuit, matrix: [[Double]], rhs: [Double],
                                       nodes: [Int], nodeIndices: [Int:Int], nonlinear: [CircuitElement],
                                       initialGuess: [Int:Double]) throws -> [Double] {
        let size=rhs.count
        var x=Array(repeating:0.0,count:size)
        var seed=initialGuess; seed[0]=0
        // Exact source constraints provide a useful initial guess, not an extra source.
        for _ in 0..<circuit.elements.count {
            var changed=false
            for element in circuit.elements {
                guard case let .voltageSource(_,a,b,volts)=element else { continue }
                if let va=seed[a], seed[b]==nil { seed[b]=va-volts; changed=true }
                if let vb=seed[b], seed[a]==nil { seed[a]=vb+volts; changed=true }
            }
            if !changed { break }
        }
        for node in nodes { x[nodeIndices[node]!] = seed[node,default:0] }
        let voltageScale=max(1,seed.values.map(abs).max() ?? 0)
        let currentScale=max(1e-3,circuit.elements.compactMap { element -> Double? in
            switch element {
            case let .currentSource(_,_,_,i): abs(i)
            case let .resistor(_,_,_,r): voltageScale/r
            default: nil
            }
        }.max() ?? 0)

        func evaluate(_ values: [Double]) throws -> (f:[Double], j:[[Double]], scale:[Double], roundoff:[Double]) {
            guard values.allSatisfy(\.isFinite) else { throw CircuitError.numericalRange }
            var f=rhs.map { -$0 }, j=matrix, scale=rhs.map(abs)
            for row in 0..<size {
                for col in 0..<size {
                    let term=matrix[row][col]*values[col]
                    f[row]+=term; scale[row]+=abs(term)
                }
            }
            for element in nonlinear {
                let pins=element.terminalNodes
                let currents=try element.deviceCurrents(pins.map { nodeIndices[$0].map { values[$0] } ?? 0 })
                for pin in pins.indices {
                    guard let row=nodeIndices[pins[pin]] else { continue }
                    f[row]+=currents[pin].value; scale[row]+=abs(currents[pin].value)
                    for terminal in pins.indices {
                        if let col=nodeIndices[pins[terminal]] { j[row][col]+=currents[pin].derivatives[terminal] }
                    }
                }
            }
            guard f.allSatisfy(\.isFinite), scale.allSatisfy(\.isFinite) else { throw CircuitError.numericalRange }
            let roundoff=j.map { row in zip(row,values).reduce(0.0) { $0+abs($1.0)*$1.1.ulp } }
            return (f,j,scale,roundoff)
        }
        func converged(_ evaluation:(f:[Double],j:[[Double]],scale:[Double],roundoff:[Double])) -> Bool {
            evaluation.f.indices.allSatisfy { row in
                abs(evaluation.f[row]) <= 1e-11*max(evaluation.scale[row],Double.leastNormalMagnitude)+32*evaluation.roundoff[row]
            }
        }
        func merit(_ f:[Double]) -> Double {
            f.indices.map { abs(f[$0]) / ($0<nodes.count ? currentScale : voltageScale) }.max() ?? 0
        }
        for iteration in 0..<200 {
            let evaluation=try evaluate(x)
            // Both physical residuals and a small Newton voltage correction are needed:
            // small junction leakage residuals alone do not determine a weakly biased voltage.
            let delta=try LinearSystem.solve(evaluation.j,evaluation.f.map { -$0 },roundoffAware:true)
            let voltageCorrectionSmall=nodes.indices.allSatisfy { abs(delta[$0]) <= 1e-9*max(1,abs(x[$0])) }
            if converged(evaluation), voltageCorrectionSmall {
                return x
            }
            var alpha=1.0
            for element in nonlinear {
                let pins=element.terminalNodes
                let changes=pins.map { nodeIndices[$0].map { delta[$0] } ?? 0 }
                let junctionChanges:[Double]
                switch element {
                case .diode: junctionChanges=[changes[0]-changes[1]]
                case .bjt: junctionChanges=[changes[1]-changes[0],changes[1]-changes[2]]
                case .mosfet: junctionChanges=[changes[0]-changes[2]]
                default: junctionChanges=[]
                }
                let largest=junctionChanges.map(abs).max() ?? 0
                if largest>0.2 { alpha=min(alpha,0.2/largest) }
            }
            let before=merit(evaluation.f)
            var accepted=false
            for _ in 0..<35 {
                let trial=zip(x,delta).map { $0+$1*alpha }
                if let next=try? evaluate(trial), merit(next.f)<before || converged(next) {
                    x=trial; accepted=true; break
                }
                alpha*=0.5
            }
            if !accepted { throw CircuitError.nonlinearConvergence(iterations:iteration+1) }
        }
        throw CircuitError.nonlinearConvergence(iterations:200)
    }
}

public struct TransientSimulator: Sendable {
    public let circuit: Circuit
    public private(set) var time: Double = 0
    public private(set) var capacitorVoltages: [String: Double] = [:]
    public private(set) var inductorCurrents: [String: Double] = [:]
    private var previousVoltages: [Int:Double] = [:]

    /// Uses explicit initial values rather than silently finding a DC operating point.
    public init(circuit: Circuit) throws {
        try circuit.validate()
        try CircuitSolver.checkReference(circuit, transient: true)
        try Self.checkInitialConditions(circuit)
        self.circuit = circuit
        for element in circuit.elements {
            switch element {
            case let .capacitor(id, _, _, _, initial): capacitorVoltages[id] = initial
            case let .inductor(id, _, _, _, initial): inductorCurrents[id] = initial
            default: break
            }
        }
    }

    /// State advances only after a successful solve. The first result is at t = timeStep.
    public mutating func step(timeStep: Double) throws -> CircuitSolution {
        guard timeStep.isFinite, timeStep > 0 else { throw CircuitError.invalidTimeStep }
        let nextTime = time + timeStep
        guard nextTime.isFinite, nextTime > time else { throw CircuitError.numericalRange }
        let solution = try CircuitSolver.solve(circuit, mode: .transient(dt: timeStep, capacitorVoltages: capacitorVoltages, inductorCurrents: inductorCurrents), time: nextTime, initialGuess:previousVoltages)
        var nextCapacitorVoltages = capacitorVoltages
        var nextInductorCurrents = inductorCurrents
        for element in circuit.elements {
            switch element {
            case let .capacitor(id, a, b, _, _):
                nextCapacitorVoltages[id] = solution.nodeVoltages[a]! - solution.nodeVoltages[b]!
            case let .inductor(id, _, _, _, _): nextInductorCurrents[id] = solution.branchCurrents[id]!
            default: break
            }
        }
        capacitorVoltages = nextCapacitorVoltages
        inductorCurrents = nextInductorCurrents
        time = nextTime
        previousVoltages=solution.nodeVoltages
        return solution
    }

    private static func checkInitialConditions(_ circuit: Circuit) throws {
        // Voltage-source / capacitor loops cannot demand two different initial voltages.
        var constraints: [Int: [(node: Int, delta: Double, id: String)]] = [:]
        for element in circuit.elements {
            let voltage: Double
            switch element {
            case let .voltageSource(_, _, _, volts): voltage = volts
            case let .capacitor(_, _, _, _, initial): voltage = initial
            default: continue
            }
            constraints[element.a, default: []].append((element.b, -voltage, element.id))
            constraints[element.b, default: []].append((element.a, voltage, element.id))
        }
        var potentials: [Int: Double] = [:]
        for root in circuit.nodes where potentials[root] == nil {
            potentials[root] = 0
            var pending = [root]
            while let node = pending.popLast() {
                for edge in constraints[node, default: []] {
                    let proposed = potentials[node]! + edge.delta
                    guard proposed.isFinite else { throw CircuitError.numericalRange }
                    if let existing = potentials[edge.node] {
                        let tolerance = 1e-10 * max(Double.leastNormalMagnitude, abs(proposed), abs(existing))
                        if abs(existing - proposed) > tolerance { throw CircuitError.inconsistentInitialConditions(edge.id) }
                    } else {
                        potentials[edge.node] = proposed
                        pending.append(edge.node)
                    }
                }
            }
        }
        // A cutset containing only specified current sources / inductors must satisfy KCL at t=0.
        var adjacency: [Int: [Int]] = [:]
        for element in circuit.elements {
            switch element {
            case .resistor, .voltageSource, .capacitor:
                adjacency[element.a, default: []].append(element.b)
                adjacency[element.b, default: []].append(element.a)
            case .inductor, .currentSource: break
            case .diode, .bjt, .mosfet, .opAmp:
                let pins=element.conductiveTerminalNodes
                for pin in pins.dropFirst() {
                    adjacency[pins[0],default:[]].append(pin)
                    adjacency[pin,default:[]].append(pins[0])
                }
            }
        }
        var groupOf: [Int: Int] = [:]
        for root in circuit.nodes where groupOf[root] == nil {
            groupOf[root] = root
            var pending = [root]
            while let node = pending.popLast() {
                for neighbor in adjacency[node, default: []] where groupOf[neighbor] == nil {
                    groupOf[neighbor] = root
                    pending.append(neighbor)
                }
            }
        }
        var outgoing: [Int: Double] = [:]
        var magnitudes: [Int: Double] = [:]
        var identifiers: [Int: String] = [:]
        for element in circuit.elements {
            let current: Double
            switch element {
            case let .inductor(_, _, _, _, initial): current = initial
            case let .currentSource(_, _, _, amps): current = amps
            default: continue
            }
            guard let a = groupOf[element.a], let b = groupOf[element.b], a != b else { continue }
            outgoing[a, default: 0] += current; outgoing[b, default: 0] -= current
            magnitudes[a, default: 0] += abs(current); magnitudes[b, default: 0] += abs(current)
            identifiers[a] = element.id; identifiers[b] = element.id
        }
        for (group, current) in outgoing {
            guard current.isFinite else { throw CircuitError.numericalRange }
            let tolerance = 1e-10 * max(magnitudes[group, default: 0], Double.leastNormalMagnitude)
            if abs(current) > tolerance { throw CircuitError.inconsistentInitialConditions(identifiers[group]!) }
        }
    }
}

private enum LinearSystem {
    /// Equilibrated, complete-pivot Gaussian elimination. No gmin or fabricated ground paths.
    static func solve(_ original: [[Double]], _ originalRHS: [Double], roundoffAware:Bool = false) throws -> [Double] {
        let size = originalRHS.count
        guard size > 0 else { return [] }
        guard original.allSatisfy({ $0.allSatisfy(\.isFinite) }), originalRHS.allSatisfy(\.isFinite) else {
            throw CircuitError.numericalRange
        }
        var matrix = original
        var rhs = originalRHS
        for row in 0..<size {
            let scale = matrix[row].map(abs).max() ?? 0
            if scale > 0 {
                for col in 0..<size { matrix[row][col] /= scale }
                rhs[row] /= scale
            }
        }
        var columnScales = Array(repeating: 1.0, count: size)
        for col in 0..<size {
            let scale = (0..<size).map { abs(matrix[$0][col]) }.max() ?? 0
            if scale > 0 {
                columnScales[col] = scale
                for row in 0..<size { matrix[row][col] /= scale }
            }
        }
        guard rhs.allSatisfy(\.isFinite) else { throw CircuitError.numericalRange }
        var permutation = Array(0..<size)
        let tolerance = 64 * Double.ulpOfOne * Double(max(1, size))
        let rhsScale = max(rhs.map(abs).max() ?? 0, Double.leastNormalMagnitude)
        for pivot in 0..<size {
            var bestRow = pivot, bestCol = pivot, bestMagnitude = 0.0
            for row in pivot..<size {
                for col in pivot..<size where abs(matrix[row][col]) > bestMagnitude {
                    bestMagnitude = abs(matrix[row][col]); bestRow = row; bestCol = col
                }
            }
            if bestMagnitude <= tolerance {
                // A tiny nonzero pivot is an ill-conditioned numeric problem, not proof
                // that the physical topology lacks a solution.
                if bestMagnitude > 0 { throw CircuitError.numericalRange }
                if (pivot..<size).contains(where: { abs(rhs[$0]) > tolerance * rhsScale }) {
                    throw CircuitError.inconsistentCircuit
                }
                throw CircuitError.singularCircuit
            }
            if bestRow != pivot { matrix.swapAt(bestRow, pivot); rhs.swapAt(bestRow, pivot) }
            if bestCol != pivot {
                for row in 0..<size { matrix[row].swapAt(bestCol, pivot) }
                permutation.swapAt(bestCol, pivot)
            }
            if pivot + 1 < size {
                for row in (pivot + 1)..<size {
                    let factor = matrix[row][pivot] / matrix[pivot][pivot]
                    matrix[row][pivot] = 0
                    for col in (pivot + 1)..<size { matrix[row][col] -= factor * matrix[pivot][col] }
                    rhs[row] -= factor * rhs[pivot]
                }
            }
        }
        var permuted = Array(repeating: 0.0, count: size)
        for row in stride(from: size - 1, through: 0, by: -1) {
            var value = rhs[row]
            if row + 1 < size {
                for col in (row + 1)..<size { value -= matrix[row][col] * permuted[col] }
            }
            permuted[row] = value / matrix[row][row]
        }
        var result = Array(repeating: 0.0, count: size)
        for col in 0..<size { result[permutation[col]] = permuted[col] / columnScales[permutation[col]] }
        guard result.allSatisfy(\.isFinite) else { throw CircuitError.numericalRange }
        // Check the original equations so numerical failure cannot masquerade as a solved circuit.
        for row in 0..<size {
            var actual = 0.0, scale = abs(originalRHS[row])
            for col in 0..<size {
                let term = original[row][col] * result[col]
                actual += term; scale += abs(term)
            }
            guard actual.isFinite, scale.isFinite else { throw CircuitError.numericalRange }
            let roundoff=roundoffAware ? 64*Double.ulpOfOne*Double(max(1,size))*(original[row].map(abs).max() ?? 0)*(result.map(abs).max() ?? 0) : 0
            if abs(actual - originalRHS[row]) > 1e-9 * max(scale, Double.leastNormalMagnitude)+roundoff {
                throw CircuitError.numericalRange
            }
        }
        return result
    }
}
