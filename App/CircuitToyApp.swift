import SwiftUI

@main struct CircuitToyApp: App {
    @State private var bench = BenchStore()
    @State private var breadboard: BreadboardStore
    init() {
        var defaults = UserDefaults.standard
        #if DEBUG
        // Native UI checks use the production store and solver in a separate persisted suite.
        // Relaunches keep test boards while leaving the user's saved boards intact.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--breadboard-test-suite"),
           arguments.indices.contains(index + 1),
           arguments[index + 1].hasPrefix("CircuitToy.UITests."),
           let isolated = UserDefaults(suiteName: arguments[index + 1]) {
            defaults = isolated
        }
        #endif
        _breadboard = State(initialValue: BreadboardStore(defaults: defaults))
    }
    #if DEBUG
    private var launchExperiment: AdvancedLessonID? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--lesson"), arguments.indices.contains(index + 1) else { return nil }
        return AdvancedLessonID(rawValue: arguments[index + 1])
    }
    #endif
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--breadboard") {
                NavigationStack { BreadboardSandboxView(store: breadboard) }.tint(BenchTheme.cyan).preferredColorScheme(.dark)
            } else if let experiment = launchExperiment {
                NavigationStack { AdvancedLessonLab(experiment: experiment) }.tint(BenchTheme.cyan).preferredColorScheme(.dark)
            } else {
                mainTabs
            }
            #else
            mainTabs
            #endif
        }
    }
    private var mainTabs: some View {
            TabView {
                Tab("Bench", systemImage: "square.grid.3x3") {
                    NavigationStack { CircuitBenchView(store: bench) }
                }
                Tab("Board", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                    NavigationStack { BreadboardSandboxView(store: breadboard) }
                }
                Tab("Labs", systemImage: "waveform.path") {
                    NavigationStack { LabLibraryView(store: bench) }
                }
                Tab("Learn", systemImage: "point.3.connected.trianglepath.dotted") {
                    NavigationStack { CurriculumView(store: bench) }
                }
            }
            .tint(BenchTheme.cyan).preferredColorScheme(.dark)
    }
}

struct LabHostView: View {
    var destination: LabDestination
    var store: BenchStore
    var body: some View {
        Group {
            switch destination {
            case .circuits: CircuitBenchView(store: store)
            case .logic: LogicLabView()
            case .transient: TransientLabView()
            case .ac: ACLabView()
            case .semiconductor, .signals, .control, .fields, .communications, .power:
                ScienceLabView(destination: destination)
            }
        }
        .navigationTitle(destination.title).navigationBarTitleDisplayMode(.inline)
    }
}

struct LabLibraryView: View {
    var store: BenchStore
    private let columns = [GridItem(.adaptive(minimum: 155), spacing: 12)]
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "A playground of connected ideas", title: "Follow your curiosity", subtitle: "Move one variable. Predict what happens. Measure the result.")
            NavigationLink { AdvancedLibraryView() } label: {
                InstrumentPanel(title: "Go deeper across EE") {
                    Label("33 more experiments", systemImage: "point.3.connected.trianglepath.dotted").font(.title3.weight(.semibold)).foregroundStyle(BenchTheme.cyan)
                    Text("Transistors, transforms, control, RF, coding, machines, computing, and engineering practice.").font(.subheadline).foregroundStyle(BenchTheme.muted)
                }
            }.buttonStyle(.plain).accessibilityIdentifier("openAdvancedLibrary")
            NavigationLink {
                LabHostView(destination: .logic, store: store)
            } label: {
                InstrumentPanel(title: "Start where Flips left off") {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("A bit. A gate. A computer.").font(.title3.weight(.semibold)).foregroundStyle(BenchTheme.ink)
                            Text("Build arithmetic and memory from switches.").font(.subheadline).foregroundStyle(BenchTheme.muted)
                        }
                        Spacer()
                        Image(systemName: "cpu").font(.largeTitle).foregroundStyle(BenchTheme.cyan)
                    }
                }
            }.buttonStyle(.plain)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(LabDestination.allCases) { destination in
                    NavigationLink { LabHostView(destination: destination, store: store) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: destination.symbol).font(.title2).foregroundStyle(BenchTheme.cyan)
                            Text(destination.title).font(.headline).foregroundStyle(BenchTheme.ink)
                            Text(destination.brief).font(.caption).foregroundStyle(BenchTheme.muted).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            HStack { Text("OPEN LAB").font(.system(.caption2, design: .monospaced, weight: .semibold)); Spacer(); Image(systemName: "arrow.up.right") }.foregroundStyle(BenchTheme.cyan)
                        }.frame(maxWidth: .infinity, minHeight: 165, alignment: .leading).padding(16)
                            .background(BenchTheme.panel, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.07)))
                    }.buttonStyle(.plain).accessibilityIdentifier("lab_\(destination.rawValue)")
                }
            }
            Text("Each lab states its assumptions. The Learn map shows how these introductory models grow into an EE curriculum.").font(.caption).foregroundStyle(BenchTheme.muted)
        }.navigationBarTitleDisplayMode(.inline)
    }
}

extension LabDestination {
    var brief: String {
        switch self {
        case .circuits: "Connect components. Probe potentials. Check conservation."
        case .logic: "Gates, a ripple adder, and clocked memory."
        case .transient: "Store energy and explore an exponential response."
        case .ac: "Amplitude, phase, and an RC low-pass filter."
        case .semiconductor: "Junction current and feedback amplification."
        case .signals: "Harmonics, sampling, and aliasing."
        case .control: "Trade response speed against steady-state error."
        case .fields: "Connect charge, distance, field, and potential."
        case .communications: "Put a message onto a carrier."
        case .power: "See where real and reactive power come from."
        }
    }
}
