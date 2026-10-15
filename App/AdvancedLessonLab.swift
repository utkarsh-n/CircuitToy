import SwiftUI

struct AdvancedLessonLab: View {
    let experiment: AdvancedLessonID
    var body: some View {
        Group {
            switch experiment.family {
            case "foundations": FoundationsLessonLab(lessonID: experiment.rawValue)
            case "systems": SystemsLessonLab(lessonID: experiment.rawValue)
            case "engineering": EngineeringLessonLab(lessonID: experiment.rawValue)
            default: PracticeLessonLab(lessonID: experiment.rawValue)
            }
        }.navigationTitle(experiment.title).navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("lessonLab_\(experiment.rawValue)")
    }
}

struct AdvancedLibraryView: View {
    var body: some View {
        BenchScreen {
            BenchHeader(eyebrow: "33 connected experiments", title: "Go deeper", subtitle: "From mathematical foundations to a tested sensor-and-actuator design.")
            ForEach(Curriculum.modules) { module in
                let experiments = module.lessons.compactMap { AdvancedLessonID(rawValue: $0.id) }
                if !experiments.isEmpty {
                    InstrumentPanel(title: module.title) {
                        ForEach(experiments) { experiment in
                            NavigationLink { AdvancedLessonLab(experiment: experiment) } label: {
                                HStack { Text(experiment.title).font(.subheadline); Spacer(); Image(systemName: "chevron.right") }
                                    .frame(minHeight: 44).foregroundStyle(BenchTheme.ink)
                            }.accessibilityIdentifier("advanced_\(experiment.rawValue)")
                        }
                    }
                }
            }
        }.navigationTitle("EE experiments").navigationBarTitleDisplayMode(.inline)
    }
}
