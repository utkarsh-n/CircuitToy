import Foundation

enum AdvancedLessonID: String, CaseIterable, Identifiable {
    case calculus, linearAlgebra = "linear-algebra", differentialEquations = "differential-equations", probability, matter
    case sequential, digitalTiming = "digital-timing"
    case inductors, resonance, networkAnalysis = "network-analysis", bjt, mosfet, analogDesign = "analog-design"
    case systems, transforms, dsp, stability, pid, stateSpace = "state-space", maxwell, rf
    case digitalCommunications = "digital-comms", information, networks, machines, converters, architecture, embedded, hardwareDesign = "hardware-design"
    case instrumentation, design, ethics, capstone
    var id: String { rawValue }
    var title: String { Curriculum.modules.flatMap(\.lessons).first { $0.id == rawValue }?.title ?? rawValue }
    var family: String {
        switch self {
        case .calculus, .linearAlgebra, .differentialEquations, .probability, .matter, .inductors, .resonance, .networkAnalysis, .bjt, .mosfet, .analogDesign: "foundations"
        case .systems, .transforms, .dsp, .stability, .pid, .stateSpace, .maxwell, .rf, .digitalCommunications, .information, .networks: "systems"
        case .sequential, .digitalTiming, .machines, .converters, .architecture, .embedded, .hardwareDesign: "engineering"
        case .instrumentation, .design, .ethics, .capstone: "practice"
        }
    }
}

