import Foundation
import Testing
import CircuitCore

private let vt = 1.380649e-23 / 1.602176634e-19 * 300
private func close(_ actual: Double?, _ expected: Double, tolerance: Double = 1e-9) -> Bool {
    guard let actual else { return false }
    return abs(actual-expected) <= tolerance*max(abs(expected),1e-12)
}
private func conserved(_ solution: CircuitSolution) {
    #expect(solution.maximumKCLResidual < 1e-9)
    #expect(abs(solution.powerBalance) < 1e-8)
    for terminals in solution.terminalCurrents.values {
        #expect(abs(terminals.reduce(0,+)) < 1e-12)
    }
}
private func bias(_ node: Int, _ volts: Double) -> CircuitElement {
    .voltageSource(id:"V\(node)",a:node,b:0,volts:volts)
}
private func bjtBias(collector: Double, base: Double, emitter: Double = 0,
                     polarity: BJTPolarity = .npn, model: BJTModel = .init()) -> Circuit {
    Circuit(elements:[bias(1,collector),bias(2,base),bias(3,emitter),
        .bjt(id:"Q",collector:1,base:2,emitter:3,polarity:polarity,model:model)])
}
private func mosBias(drain: Double, gate: Double, source: Double = 0,
                     polarity: MOSFETPolarity = .nChannel, model: MOSFETModel = .init()) -> Circuit {
    Circuit(elements:[bias(1,drain),bias(2,gate),bias(3,source),
        .mosfet(id:"M",drain:1,gate:2,source:3,polarity:polarity,model:model)])
}
private func follower(load: Double = 1_000, input: Double = 2.5,
                      model: OpAmpModel = .init()) -> Circuit {
    Circuit(elements:[bias(1,5),bias(2,input),.resistor(id:"RL",a:3,b:0,ohms:load),
        .opAmp(id:"U",nonInverting:2,inverting:3,output:3,positiveSupply:1,negativeSupply:0,model:model)])
}

@Test func diodeCurrentBiasInvertsShockleyWithoutFixedThreshold() throws {
    let current=0.001, model=DiodeModel.silicon
    let solution=try CircuitSolver.solveDC(Circuit(elements:[
        .currentSource(id:"I",a:0,b:1,amps:current),.diode(id:"D",a:1,b:0,model:model)]))
    #expect(close(solution.voltage(at:1),vt*log1p(current/model.saturationCurrent)))
    #expect(close(solution.current(through:"D"),current))
    #expect(solution.terminalCurrents["D"] == [solution.current(through:"D")!, -solution.current(through:"D")!])
    conserved(solution)
}

@Test func ledSeriesResistanceMatchesIndependentImplicitVoltageEquation() throws {
    let model=DiodeModel.redLED, current=0.005
    let voltage=model.idealityFactor*vt*log1p(current/model.saturationCurrent)+current*model.seriesResistance
    let solution=try CircuitSolver.solveDC(Circuit(elements:[bias(1,voltage),.diode(id:"LED",a:1,b:0,model:model)]))
    #expect(close(solution.current(through:"LED"),current))
    #expect(close(solution.branchPowers["LED"],voltage*current))
    conserved(solution)
}

@Test func resistorDiodeLoadLineMatchesIndependentBisectionAndReversal() throws {
    let model=DiodeModel.silicon
    var low=0.0, high=5.0
    for _ in 0..<100 {
        let middle=(low+high)/2
        let diode=model.saturationCurrent*expm1(middle/vt)
        if diode > (5-middle)/1_000 { high=middle } else { low=middle }
    }
    let solution=try CircuitSolver.solveDC(Circuit(elements:[bias(1,5),
        .resistor(id:"R",a:1,b:2,ohms:1_000),.diode(id:"D",a:2,b:0,model:model)]))
    #expect(close(solution.voltage(at:2),(low+high)/2))
    #expect(close(solution.current(through:"D"),(5-(low+high)/2)/1_000))
    conserved(solution)
    let reverse=try CircuitSolver.solveDC(Circuit(elements:[bias(1,-5),.diode(id:"D",a:1,b:0,model:model)]))
    #expect(close(reverse.current(through:"D"),-model.saturationCurrent))
    #expect(reverse.branchPowers["D"]! > 0)
    conserved(reverse)
}

@Test func verySmallDiodeCurrentsAreSolvedWithoutAbsoluteCurrentFloor() throws {
    let model=DiodeModel(saturationCurrent:1e-20), current=1e-18
    let solution=try CircuitSolver.solveDC(Circuit(elements:[
        .currentSource(id:"I",a:0,b:1,amps:current),.diode(id:"D",a:1,b:0,model:model)]))
    #expect(close(solution.voltage(at:1),vt*log1p(current/model.saturationCurrent)))
    #expect(abs(solution.current(through:"D")!/current-1)<1e-8)
    conserved(solution)
}

@Test func weakReverseJunctionRequiresAccurateVoltageAsWellAsSmallCurrentResidual() throws {
    let model=DiodeModel.silicon, fraction=1e-6
    let current = -model.saturationCurrent*(1-fraction)
    let solution=try CircuitSolver.solveDC(Circuit(elements:[
        .currentSource(id:"I",a:0,b:1,amps:current),.diode(id:"D",a:1,b:0,model:model)]))
    #expect(close(solution.voltage(at:1),vt*log(fraction),tolerance:1e-8))
    #expect(close(solution.current(through:"D"),current))
    conserved(solution)
}

@Test func impossibleReverseJunctionCurrentHasExplicitConvergenceFailure() throws {
    var failure:CircuitError?
    do {
        _ = try CircuitSolver.solveDC(Circuit(elements:[
            .currentSource(id:"I",a:0,b:1,amps:-2e-12),.diode(id:"D",a:1,b:0,model:.silicon)]))
    } catch { failure=error as? CircuitError }
    if case .nonlinearConvergence? = failure {} else { #expect(Bool(false), "An impossible reverse current must not produce a solved reading.") }
}

@Test func ebersMollForwardActiveIncludesBaseAndEmitterCurrents() throws {
    let model=BJTModel(), transport=0.001
    let base=vt*log1p(transport/model.saturationCurrent)
    let solution=try CircuitSolver.solveDC(bjtBias(collector:2,base:base))
    let reverse=model.saturationCurrent*expm1((base-2)/vt)
    let collector=transport-(1+1/model.reverseBeta)*reverse
    let baseCurrent=transport/model.forwardBeta+reverse/model.reverseBeta
    #expect(close(solution.terminalCurrents["Q"]?[0],collector))
    #expect(close(solution.terminalCurrents["Q"]?[1],baseCurrent))
    #expect(close(solution.terminalCurrents["Q"]?[2],-collector-baseCurrent))
    #expect(solution.current(through:"Q") == solution.terminalCurrents["Q"]?[0])
    conserved(solution)
}

@Test func ebersMollSaturationAndReverseActiveUseBothJunctions() throws {
    let model=BJTModel()
    for (collector,base,emitter) in [(0.1,0.7,0.0),(0.0,0.65,2.0)] {
        let f=model.saturationCurrent*expm1((base-emitter)/vt)
        let r=model.saturationCurrent*expm1((base-collector)/vt)
        let solution=try CircuitSolver.solveDC(bjtBias(collector:collector,base:base,emitter:emitter))
        #expect(close(solution.terminalCurrents["Q"]?[0],f-(1+1/model.reverseBeta)*r))
        #expect(close(solution.terminalCurrents["Q"]?[1],f/model.forwardBeta+r/model.reverseBeta))
        conserved(solution)
    }
}

@Test func pnpMirrorsNpnVoltageAndAllTerminalCurrents() throws {
    let npn=try CircuitSolver.solveDC(bjtBias(collector:2,base:0.65))
    let pnp=try CircuitSolver.solveDC(bjtBias(collector:-2,base:-0.65,polarity:.pnp))
    for pin in 0..<3 { #expect(close(pnp.terminalCurrents["Q"]?[pin],-npn.terminalCurrents["Q"]![pin])) }
    #expect(close(pnp.branchPowers["Q"],npn.branchPowers["Q"]!))
    conserved(npn); conserved(pnp)
}

@Test func mosfetTriodeAndSaturationMatchSquareLawAndZeroGateCurrent() throws {
    let model=MOSFETModel()
    for drain in [0.2,5.0] {
        let overdrive=3-model.thresholdVoltage
        let channel=(drain<overdrive ? model.transconductance*(overdrive*drain-drain*drain/2) : model.transconductance*overdrive*overdrive/2)*(1+model.channelLengthModulation*drain)
        let body=model.bodyDiode.saturationCurrent*expm1(-drain/vt)
        let solution=try CircuitSolver.solveDC(mosBias(drain:drain,gate:3))
        #expect(close(solution.current(through:"M"),channel-body))
        #expect(solution.terminalCurrents["M"]?[1] == 0)
        conserved(solution)
    }
}

@Test func mosfetReverseOperationRetainsBodyAtLabelledSource() throws {
    let model=MOSFETModel(channelLengthModulation:0), drain = -0.6, gate=3.0
    let overdrive=gate-drain-model.thresholdVoltage
    let channel=model.transconductance*(overdrive*(-drain)-drain*drain/2)
    let body=model.bodyDiode.saturationCurrent*expm1(-drain/vt)
    let solution=try CircuitSolver.solveDC(mosBias(drain:drain,gate:gate,model:model))
    #expect(close(solution.current(through:"M"),-channel-body))
    let off=try CircuitSolver.solveDC(mosBias(drain:drain,gate:-5,model:model))
    #expect(close(off.current(through:"M"),-body))
    conserved(solution); conserved(off)
}

@Test func pChannelMirrorsNChannelAndOffStateRetainsJunctionLeakage() throws {
    let n=try CircuitSolver.solveDC(mosBias(drain:5,gate:3))
    let p=try CircuitSolver.solveDC(mosBias(drain:-5,gate:-3,polarity:.pChannel))
    #expect(close(p.current(through:"M"),-n.current(through:"M")!))
    #expect(close(p.branchPowers["M"],n.branchPowers["M"]!))
    let off=try CircuitSolver.solveDC(mosBias(drain:5,gate:0))
    #expect(close(off.current(through:"M"),1e-12))
    conserved(n); conserved(p); conserved(off)
}

@Test func opAmpFollowerUsesFiniteGainOutputResistanceAndRealSupplyCurrents() throws {
    let model=OpAmpModel(openLoopGain:100)
    let solution=try CircuitSolver.solveDC(follower(input:2,model:model))
    let expected=(2.5+model.openLoopGain*2)/(model.openLoopGain+1+model.outputResistance/1_000)
    #expect(close(solution.voltage(at:3),expected))
    let pins=try #require(solution.terminalCurrents["U"])
    #expect(pins[0] == 0 && pins[1] == 0)
    #expect(close(pins[2],-expected/1_000))
    #expect(close(pins[3],model.quiescentCurrent+expected/1_000))
    #expect(close(pins[4],-model.quiescentCurrent))
    #expect(solution.current(through:"U") == pins[2])
    #expect(solution.branchPowers["U"]! > 0)
    conserved(solution)
}

@Test func opAmpOverloadAndRailSaturationRespectLimitsAndPower() throws {
    let overloaded=try CircuitSolver.solveDC(follower(load:100))
    #expect(close(overloaded.voltage(at:3),2))
    #expect(close(overloaded.terminalCurrents["U"]?[2],-0.02))
    #expect(close(overloaded.terminalCurrents["U"]?[3],0.021))
    conserved(overloaded)
    let saturated=try CircuitSolver.solveDC(Circuit(elements:[bias(1,5),bias(2,4),
        .resistor(id:"RL",a:3,b:0,ohms:1_000),
        .opAmp(id:"U",nonInverting:2,inverting:0,output:3,positiveSupply:1,negativeSupply:0,model:.init())]))
    #expect(close(saturated.voltage(at:3),4.9/1.05))
    conserved(saturated)
}

@Test func externallyDrivenOpAmpOutputBeyondSuppliesIsExplicitlyUnsupported() throws {
    for output in [-2.0,7.0] {
        #expect(throws:CircuitError.invalidOperatingPoint("U")) {
            try CircuitSolver.solveDC(Circuit(elements:[bias(1,5),bias(2,2.5),bias(3,output),
                .opAmp(id:"U",nonInverting:2,inverting:0,output:3,positiveSupply:1,negativeSupply:0,model:.init())]))
        }
    }
    let sinking=try CircuitSolver.solveDC(Circuit(elements:[bias(1,5),bias(2,1),bias(3,3),bias(4,4),
        .opAmp(id:"U",nonInverting:2,inverting:4,output:3,positiveSupply:1,negativeSupply:0,model:.init())]))
    #expect(close(sinking.terminalCurrents["U"]?[2],0.02))
    #expect(close(sinking.terminalCurrents["U"]?[3],0.001))
    #expect(close(sinking.terminalCurrents["U"]?[4],-0.021))
    #expect(sinking.branchPowers["U"]! > 0)
    conserved(sinking)
}

@Test func nonlinearFloatingInputsAndUnpoweredOrInvalidCommonModeAreExplicitErrors() throws {
    let floatingGate=Circuit(elements:[bias(1,5),.mosfet(id:"M",drain:1,gate:2,source:0,polarity:.nChannel,model:.init())])
    #expect(throws:CircuitError.floatingNodes([2])) { try CircuitSolver.solveDC(floatingGate) }
    let floatingInput=Circuit(elements:[bias(1,5),.resistor(id:"RL",a:3,b:0,ohms:1_000),
        .opAmp(id:"U",nonInverting:2,inverting:0,output:3,positiveSupply:1,negativeSupply:0,model:.init())])
    #expect(throws:CircuitError.floatingNodes([2])) { try CircuitSolver.solveDC(floatingInput) }
    #expect(throws:CircuitError.unpoweredDevice("U")) {
        try CircuitSolver.solveDC(Circuit(elements:[.opAmp(id:"U",nonInverting:0,inverting:0,output:0,positiveSupply:0,negativeSupply:0,model:.init())]))
    }
    #expect(throws:CircuitError.inputCommonModeRange("U")) { try CircuitSolver.solveDC(follower(input:6)) }
}

@Test func nonlinearModelsRejectInvalidParametersAndRoundTripProfiles() throws {
    var diode=DiodeModel(); diode.seriesResistance = -1
    #expect(throws:(any Error).self) { try diode.validate(id:"D") }
    var bjt=BJTModel(); bjt.reverseBeta=0
    #expect(throws:(any Error).self) { try bjt.validate(id:"Q") }
    var mos=MOSFETModel(); mos.transconductance = .nan
    #expect(throws:(any Error).self) { try mos.validate(id:"M") }
    var amp=OpAmpModel(); amp.currentLimit=0
    #expect(throws:(any Error).self) { try amp.validate(id:"U") }
    let model=MOSFETModel(thresholdVoltage:1.2,transconductance:0.05,channelLengthModulation:0,bodyDiode:.redLED)
    #expect(try JSONDecoder().decode(MOSFETModel.self,from:JSONEncoder().encode(model)) == model)
    #expect(throws:CircuitError.invalidNode("M")) { try Circuit(elements:[.mosfet(id:"M",drain:1,gate:-1,source:0,polarity:.nChannel,model:.init())]).validate() }
}

@Test func nonlinearDiodeCapacitorStepSatisfiesIndependentBackwardEulerEquation() throws {
    let model=DiodeModel.silicon, initial=0.2, expected=0.5, capacitance=1e-6, dt=0.001
    let current=capacitance/dt*(expected-initial)+model.saturationCurrent*expm1(expected/vt)
    var simulator=try TransientSimulator(circuit:Circuit(elements:[
        .currentSource(id:"I",a:0,b:1,amps:current),
        .capacitor(id:"C",a:1,b:0,farads:capacitance,initialVoltage:initial),
        .diode(id:"D",a:1,b:0,model:model)]))
    let first=try simulator.step(timeStep:dt)
    #expect(close(first.voltage(at:1),expected))
    #expect(close(first.current(through:"C"),capacitance/dt*(expected-initial)))
    conserved(first)
    #expect(throws:CircuitError.invalidTimeStep) { try simulator.step(timeStep:0) }
    #expect(simulator.time == dt)
    #expect(close(simulator.capacitorVoltages["C"],expected))
}

@Test func opAmpCurrentLimitChargesRealCapacitorAtFiniteStep() throws {
    var circuit=follower()
    circuit.elements.append(.capacitor(id:"C",a:3,b:0,farads:0.001,initialVoltage:0))
    var simulator=try TransientSimulator(circuit:circuit)
    let first=try simulator.step(timeStep:0.001)
    let expected=0.02/(0.001/0.001+1/1_000.0)
    #expect(close(first.voltage(at:3),expected))
    #expect(close(first.current(through:"U"),-0.02))
    conserved(first)
    let second=try simulator.step(timeStep:0.001)
    #expect(close(second.voltage(at:3),(0.02+expected)/(1+1/1_000.0)))
    conserved(second)
}

@Test func nonlinearCircuitDoesNotHideRedundantIdealSources() throws {
    #expect(throws:CircuitError.singularCircuit) {
        try CircuitSolver.solveDC(Circuit(elements:[bias(1,0),.voltageSource(id:"Vx",a:1,b:0,volts:0),
            .diode(id:"D",a:1,b:0,model:.silicon)]))
    }
}
