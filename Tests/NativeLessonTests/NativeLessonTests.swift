import XCTest

@MainActor final class NativeLessonTests: XCTestCase {
    private let lessons = ["calculus", "linear-algebra", "differential-equations", "probability", "matter", "sequential", "digital-timing", "inductors", "resonance", "network-analysis", "bjt", "mosfet", "analog-design", "systems", "transforms", "dsp", "stability", "pid", "state-space", "maxwell", "rf", "digital-comms", "information", "networks", "machines", "converters", "architecture", "embedded", "hardware-design", "instrumentation", "design", "ethics", "capstone"]

    override func setUpWithError() throws { continueAfterFailure = false }

    func testAdvancedExperiments01Through11() {
        verifyExperiments(Array(lessons.prefix(11)))
    }

    func testAdvancedExperiments12Through22() {
        verifyExperiments(Array(lessons.dropFirst(11).prefix(11)))
    }

    func testAdvancedExperiments23Through33() {
        verifyExperiments(Array(lessons.dropFirst(22)))
    }

    private func verifyExperiments(_ lessonIDs: [String]) {
        let app = XCUIApplication()
        for lesson in lessonIDs {
            app.launchArguments = ["--lesson", lesson]
            app.launch()
            let experiment = app.descendants(matching: .any).matching(identifier: "lessonLab_\(lesson)").firstMatch
            XCTAssertTrue(experiment.waitForExistence(timeout: 8), "Missing native experiment \(lesson)")
            XCTAssertFalse(app.staticTexts["Experiment unavailable"].exists, lesson)
            XCTAssertGreaterThan(app.buttons.count + app.sliders.count + app.switches.count, 0, "No controls in \(lesson)")
            app.terminate()
        }
    }

    func testCapstoneChecksAndParameterChanges() {
        let app = XCUIApplication(); app.launchArguments = ["--lesson", "capstone"]; app.launch()
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 8))
        let button = app.buttons["Increase Supply voltage"]
        for _ in 0..<6 where !button.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(button.isHittable); button.tap()
        let check = app.buttons["runCapstoneChecks"]
        for _ in 0..<12 where !check.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(check.isHittable); check.tap()
        XCTAssertTrue(app.descendants(matching: .any)["capstoneResults"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Simulation meets these conditions"].exists)
    }

    func testAllLessonsAvailableThroughLearnMap() {
        let app = XCUIApplication(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.tabBars.buttons["Learn"].waitForExistence(timeout: 8)); app.tabBars.buttons["Learn"].tap()
        XCTAssertTrue(app.staticTexts["All 54 lessons include an interactive experiment. Exploring a lesson records practice, not assessed mastery."].waitForExistence(timeout: 5))
        app.buttons["module_foundations"].tap()
        let calculus = app.staticTexts["Calculus: accumulation & change"]
        for _ in 0..<4 where !calculus.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(calculus.isHittable); calculus.tap()
        let open = app.buttons["openLessonLab"]
        for _ in 0..<6 where !open.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(open.isHittable); open.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "lessonLab_calculus").firstMatch.waitForExistence(timeout: 5))
    }
}
