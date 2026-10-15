import SwiftUI

struct CurriculumView: View {
    var store: BenchStore
    @AppStorage("CircuitToy.explored.v1") private var explored = ""
    private var exploredIDs: Set<String> { Set(explored.split(separator: "|").map(String.init)) }
    private var lessons: [CourseLesson] { Curriculum.modules.flatMap(\.lessons) }
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "The EE learning map", title: "From charge to systems", subtitle: "A degree-wide path, with first-principles experiments along the way.")
            InstrumentPanel(title: "Your map") {
                HStack {
                    MeterValue(label: "Areas", value: "\(Curriculum.modules.count)", unit: "")
                    MeterValue(label: "Live lessons", value: "\(lessons.filter(\.isImplemented).count)", unit: "", tint: BenchTheme.green)
                    MeterValue(label: "Explored", value: "\(exploredIDs.count)", unit: "", tint: BenchTheme.amber)
                }
                Text("All \(lessons.count) lessons include an interactive experiment. Exploring a lesson records practice, not assessed mastery.").font(.caption).foregroundStyle(BenchTheme.muted)
            }
            ForEach(Curriculum.modules) { module in
                NavigationLink {
                    ModuleView(module: module, store: store)
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle().fill(BenchTheme.cyan.opacity(0.1)).frame(width: 44, height: 44)
                            Image(systemName: module.symbol).foregroundStyle(BenchTheme.cyan)
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text("STAGE \(module.stage)").font(.system(.caption2, design: .monospaced, weight: .semibold)).foregroundStyle(BenchTheme.muted)
                            Text(module.title).font(.headline).foregroundStyle(BenchTheme.ink)
                            Text(module.subtitle).font(.caption).foregroundStyle(BenchTheme.muted)
                            Text("\(module.implementedCount) interactive lessons").font(.caption).foregroundStyle(BenchTheme.green)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(BenchTheme.muted).padding(.top, 20)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                        .background(BenchTheme.panel, in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain).accessibilityIdentifier("module_\(module.id)")
            }
            NavigationLink("Models & curriculum sources") { SourcesView() }.font(.subheadline).frame(minHeight: 44)
        }.navigationBarTitleDisplayMode(.inline)
    }
}

private struct ModuleView: View {
    var module: CourseModule
    var store: BenchStore
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "Stage \(module.stage)", title: module.title, subtitle: module.subtitle)
            if !module.prerequisites.isEmpty {
                let names = module.prerequisites.compactMap { id in Curriculum.modules.first { $0.id == id }?.title }
                Text("Builds on: \(names.joined(separator: ", "))").font(.caption).foregroundStyle(BenchTheme.muted)
            }
            ForEach(module.lessons) { lesson in
                NavigationLink { LessonView(lesson: lesson, store: store) } label: {
                    InstrumentPanel(title: "Experiment available") {
                        HStack {
                            Text(lesson.title).font(.headline).foregroundStyle(BenchTheme.ink)
                            Spacer()
                            Image(systemName: lesson.isImplemented ? "play.circle" : "map").foregroundStyle(lesson.isImplemented ? BenchTheme.green : BenchTheme.muted)
                        }
                        Text(lesson.concept).font(.subheadline).foregroundStyle(BenchTheme.muted).lineLimit(3)
                    }
                }.buttonStyle(.plain)
            }
        }.navigationTitle("Learning path").navigationBarTitleDisplayMode(.inline)
    }
}

private struct LessonView: View {
    var lesson: CourseLesson
    var store: BenchStore
    @AppStorage("CircuitToy.explored.v1") private var explored = ""
    private var isExplored: Bool { explored.split(separator: "|").contains(Substring(lesson.id)) }
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "Predict · experiment · explain", title: lesson.title, subtitle: "Explore the model, make a prediction, then check it.")
            InstrumentPanel(title: "The idea") { FormulaNote(equation: lesson.equation, explanation: lesson.concept) }
            InstrumentPanel(title: "Experiment") {
                Text(lesson.experiment).font(.subheadline)
                if let experiment = lesson.advancedExperiment {
                    NavigationLink { AdvancedLessonLab(experiment: experiment) } label: { Label("Open experiment", systemImage: "play.fill") }
                        .buttonStyle(GlassActionStyle()).accessibilityIdentifier("openLessonLab")
                }
                if lesson.isImplemented, let destination = lesson.destination {
                    NavigationLink { LabHostView(destination: destination, store: store) } label: { Label("Open \(destination.title)", systemImage: "play.fill") }
                        .buttonStyle(GlassActionStyle()).accessibilityIdentifier("openLessonLab")
                }
            }
            InstrumentPanel(title: "Make a prediction") {
                Text(lesson.challenge).font(.subheadline)
                if lesson.isImplemented {
                    Button {
                        var ids = Set(explored.split(separator: "|").map(String.init))
                        if ids.contains(lesson.id) { ids.remove(lesson.id) } else { ids.insert(lesson.id) }
                        explored = ids.sorted().joined(separator: "|")
                    } label: { Label(isExplored ? "Explored · tap to undo" : "Mark as explored", systemImage: isExplored ? "checkmark.circle.fill" : "circle") }
                        .buttonStyle(GlassActionStyle(tint: BenchTheme.green))
                }
            }
            InstrumentPanel(title: "Assumptions & scope") { Text(lesson.modelLimit).font(.caption).foregroundStyle(BenchTheme.muted) }
        }.navigationTitle("Lesson").navigationBarTitleDisplayMode(.inline)
    }
}

private struct SourcesView: View {
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "Faithful within stated models", title: "How to trust the toy", subtitle: "Equations, references, validation, and visible limits.")
            InstrumentPanel(title: "Fidelity contract") {
                Text(Curriculum.fidelityStatement).font(.subheadline)
                Text("The DC solver uses modified nodal analysis. Transients use stated analytical or numerical methods. The advanced labs include device equations, convolution, DFTs, sampled control, electromagnetic identities, event simulation and digital state machines. Independent tests check conservation, analytical references, numerical convergence and logic properties.").font(.subheadline).foregroundStyle(BenchTheme.muted)
                Text("Real boards add tolerances, noise, heating, device nonlinearity, parasitics, and timing. No simulation is a 1:1 reproduction of all physical behavior; each lab states what it includes.").font(.caption).foregroundStyle(BenchTheme.muted)
            }
            InstrumentPanel(title: "Degree-wide curriculum") {
                Text("EE programs share foundations and offer different specializations. This map synthesizes the sources below into 54 interactive lessons. Its bounded experiments demonstrate the stated models; university depth, assessed mastery and physical design evidence require further study and practice.").font(.subheadline).foregroundStyle(BenchTheme.muted)
                ForEach(Curriculum.sources) { source in if let url = URL(string: source.url) { Link(source.title, destination: url).font(.subheadline).frame(minHeight: 44, alignment: .leading) } }
            }
        }.navigationTitle("Sources").navigationBarTitleDisplayMode(.inline)
    }
}
