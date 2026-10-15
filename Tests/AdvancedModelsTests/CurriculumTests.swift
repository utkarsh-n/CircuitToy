import XCTest
@testable import CircuitCurriculum

final class CurriculumTests: XCTestCase {
    func testEveryLessonHasAnExperimentAndNoPlaceholderText() {
        let lessons = Curriculum.modules.flatMap(\.lessons)
        XCTAssertEqual(lessons.count, 54)
        XCTAssertEqual(Set(lessons.map(\.id)).count, 54)
        XCTAssertEqual(lessons.filter(\.isImplemented).count, 54)
        XCTAssertEqual(AdvancedLessonID.allCases.count, 33)
        for lesson in lessons {
            XCTAssertTrue(lesson.isImplemented, lesson.id)
            XCTAssertTrue(lesson.destination != nil || lesson.advancedExperiment != nil, lesson.id)
            for text in [lesson.title, lesson.concept, lesson.equation, lesson.experiment, lesson.challenge, lesson.modelLimit] {
                XCTAssertFalse(text.isEmpty, lesson.id)
                XCTAssertFalse(text.lowercased().contains("planned"), "Placeholder in \(lesson.id): \(text)")
            }
        }
    }
    func testAdvancedRoutesAndAcyclicPrerequisites() {
        let routes = AdvancedLessonID.allCases
        XCTAssertEqual(routes.filter { $0.family == "foundations" }.count, 11)
        XCTAssertEqual(routes.filter { $0.family == "systems" }.count, 11)
        XCTAssertEqual(routes.filter { $0.family == "engineering" }.count, 7)
        XCTAssertEqual(routes.filter { $0.family == "practice" }.count, 4)
        var visited = Set<String>()
        for module in Curriculum.modules {
            for prerequisite in module.prerequisites { XCTAssertTrue(visited.contains(prerequisite), "\(module.id) prerequisite \(prerequisite) must precede it") }
            visited.insert(module.id)
        }
        for route in routes {
            XCTAssertNotEqual(route.title, route.rawValue)
            XCTAssertEqual(Curriculum.modules.flatMap(\.lessons).filter { $0.advancedExperiment == route }.count, 1)
        }
    }
}
