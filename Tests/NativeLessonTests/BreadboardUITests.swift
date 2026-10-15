import XCTest

@MainActor final class BreadboardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBuildDividerFromEmptyBoardAndMeasureEditedCircuit() {
        let app = launchBoard()
        mode("Analog", in: app)
        example("empty", in: app)

        // Distinct holes in a row share a strip; components do not merge their pins.
        place("voltageSource", at: ["A1", "A2"], in: app)
        place("resistor", at: ["B1", "A3"], in: app)
        place("resistor", at: ["B3", "B2"], in: app)
        tap("groundTool", in: app); tap("hole_C2", in: app)
        tap("wireTool", in: app); tap("hole_D3", in: app); tap("hole_F3", in: app)
        tap("probeTool", in: app); tap("hole_G3", in: app)
        expectEngineering("probeVoltage", equals: 2.5, accuracy: 0.001, in: app)

        openEditor("R1", in: app); tap("probeBranchCurrent_R1", in: app)
        waitForEditorDismissal(in: app)
        expectEngineering("probeCurrent", equals: 0.0025, accuracy: 0.000001, in: app)

        openEditor("R1", in: app); tap("value_2000", in: app); tap("saveBoardComponent", in: app)
        waitForEditorDismissal(in: app)
        expectEngineering("probeVoltage", equals: 5.0 / 3.0, accuracy: 0.005, in: app)
        expectEngineering("probeCurrent", equals: 5.0 / 3000.0, accuracy: 0.000005, in: app)
        tap("undoBoardEdit", in: app)
        expectEngineering("probeVoltage", equals: 2.5, accuracy: 0.001, in: app)
        expectEngineering("probeCurrent", equals: 0.0025, accuracy: 0.000001, in: app)
    }

    func testEditorTypedValueMoveDeleteJumperAndUndo() {
        let app = launchBoard()
        mode("Analog", in: app)
        example("divider", in: app)
        tap("hole_D3", in: app)
        expectEngineering("probeVoltage", equals: 2.5, accuracy: 0.001, in: app)

        openEditor("R1", in: app)
        tap("probeBranchCurrent_R1", in: app)
        waitForEditorDismissal(in: app)
        expectEngineering("probeCurrent", equals: 0.0025, accuracy: 0.000001, in: app)

        openEditor("R1", in: app)
        replaceValue("boardComponentValue", with: "-1", in: app)
        tap("saveBoardComponent", in: app)
        XCTAssertTrue(app.staticTexts["boardComponentError"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["boardComponentValue"].exists)
        replaceValue("boardComponentValue", with: "2000", in: app)
        tap("saveBoardComponent", in: app)
        waitForEditorDismissal(in: app)
        expectEngineering("probeVoltage", equals: 5.0 / 3.0, accuracy: 0.005, in: app)
        expectEngineering("probeCurrent", equals: 5.0 / 3000.0, accuracy: 0.000005, in: app)
        tap("undoBoardEdit", in: app)
        expectEngineering("probeVoltage", equals: 2.5, accuracy: 0.001, in: app)

        // Move from Edit mode: the new pin taps must reach holes underneath part overlays.
        tap("editBoardTool", in: app)
        openEditor("R1", in: app)
        tap("moveBoardComponent", in: app)
        waitForEditorDismissal(in: app)
        tap("hole_D1", in: app); tap("hole_D3", in: app)
        XCTAssertTrue(app.buttons["part_R1"].label.contains("D1 → D3"))
        expectEngineering("probeVoltage", equals: 2.5, accuracy: 0.001, in: app)

        openEditor("R2", in: app)
        tap("deleteBoardComponent", in: app)
        waitForEditorDismissal(in: app)
        XCTAssertFalse(app.buttons["part_R2"].exists)
        expectEngineering("probeVoltage", equals: 5, accuracy: 0.001, in: app)
        tap("undoBoardEdit", in: app)
        XCTAssertTrue(app.buttons["part_R2"].exists)
        expectEngineering("probeVoltage", equals: 2.5, accuracy: 0.001, in: app)

        tap("jumper_W1", in: app); tap("deleteBoardWire", in: app)
        XCTAssertTrue(app.scrollViews["boardWireEditorForm"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["jumper_W1"].exists)
        expectEngineering("probeVoltage", equals: 5, accuracy: 0.001, in: app)
        tap("undoBoardEdit", in: app)
        XCTAssertTrue(app.buttons["jumper_W1"].exists)
        expectEngineering("probeVoltage", equals: 2.5, accuracy: 0.001, in: app)
    }

    func testANDSignalsUpdateAndOpposingDriversResolveUnknown() {
        let app = launchBoard()
        mode("Logic", in: app)
        example("and", in: app)
        tap("probeTool", in: app); tap("hole_G5", in: app)
        // The editable example starts with A=0 and B=1.
        expectValue("probeLogic", equals: "0", in: app)
        tap("toggle_A", in: app)
        expectValue("probeLogic", equals: "1", in: app)
        tap("toggle_B", in: app)
        expectValue("probeLogic", equals: "0", in: app)
        tap("toggle_A", in: app)
        expectValue("probeLogic", equals: "0", in: app)

        // A jumper really joins nets: opposing ideal input drivers must become X.
        tap("toggle_A", in: app)
        tap("wireTool", in: app); tap("hole_D1", in: app); tap("hole_D3", in: app)
        tap("probeTool", in: app); tap("hole_E1", in: app)
        expectValue("probeLogic", equals: "X", in: app)
        tap("undoBoardEdit", in: app)
        expectValue("probeLogic", equals: "1", in: app)
    }

    func testRCStepsResetsAndEditedDocumentSurvivesRelaunch() {
        let app = launchBoard()
        mode("Analog", in: app)
        example("rc", in: app)
        tap("transientAnalysis", in: app)
        tap("probeTool", in: app); tap("hole_C3", in: app)
        tap("resetBoardSimulation", in: app)
        XCTAssertTrue(element("boardAwaitingStep", in: app).waitForExistence(timeout: 5))
        expectValue("probeVoltage", equals: "—", in: app)
        tap("stepBoardSimulation", in: app)
        let first = engineeringValue("probeVoltage", in: app)
        // With R=1 kΩ, C=1 mF and h=1 ms, the first BE sample is 5h/(RC+h).
        XCTAssertEqual(first, 5 * 0.001 / 1.001, accuracy: 0.00001)
        tap("stepBoardSimulation", in: app)
        XCTAssertGreaterThan(engineeringValue("probeVoltage", in: app), first)
        let beforeReselectingStep = engineeringValue("probeVoltage", in: app)
        tap("boardTimeStep", in: app); tap("boardTimeStep_0.001", in: app)
        XCTAssertEqual(elapsedTime(in: app), 0.002, accuracy: 1e-10)
        XCTAssertEqual(engineeringValue("probeVoltage", in: app), beforeReselectingStep, accuracy: 1e-10)
        tap("runBoardSimulation", in: app)
        tap("runBoardSimulation", in: app)
        let pausedTime = elapsedTime(in: app)
        XCTAssertGreaterThan(pausedTime, 0.002)
        // A paused board must stay at the same sample while native UI queries complete.
        XCTAssertEqual(elapsedTime(in: app), pausedTime, accuracy: 1e-10)
        tap("resetBoardSimulation", in: app)
        XCTAssertTrue(element("boardAwaitingStep", in: app).waitForExistence(timeout: 5))
        expectValue("probeVoltage", equals: "—", in: app)

        openEditor("R1", in: app); tap("value_2000", in: app); tap("saveBoardComponent", in: app)
        waitForEditorDismissal(in: app)
        // Local autosave preserves the edited circuit, rather than reloading the example.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["addBoardComponent"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["part_C1"].exists)
        XCTAssertFalse(app.buttons["part_R2"].exists)
        openEditor("R1", in: app)
        let field = element("boardComponentValue", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        guard let text = field.value as? String, let resistance = Double(text) else {
            XCTFail("Missing saved resistance value: \(String(describing: field.value))")
            return
        }
        XCTAssertEqual(resistance, 2000, accuracy: 0.001)
        tap("probeBranchCurrent_R1", in: app)
        waitForEditorDismissal(in: app)
        tap("transientAnalysis", in: app)
        tap("hole_C3", in: app)
        expectValue("probeVoltage", equals: "—", in: app)
        tap("stepBoardSimulation", in: app)
        expectEngineering("probeVoltage", equals: 5 * 0.001 / 2.001, accuracy: 0.00001, in: app)
        expectEngineering("probeCurrent", equals: 5 / 2.001 / 1000, accuracy: 0.00001, in: app)
    }

    func testDiodeLEDModelEditsSignedProbesAndRelaunch() {
        let app = launchBoard()
        exampleDevice("Diode", in: app)
        tap("probeTool", in: app); tap("hole_D3", in: app)
        let diode = junctionReference(supply: 5, resistance: 1000, shunt: 10000,
                                      saturation: 1e-12, ideality: 1, seriesResistance: 0)
        expectEngineering("probeVoltage", equals: diode.voltage, accuracy: 0.002, in: app)
        openEditor("D1", in: app)
        replaceValue("deviceParameter_D1_idealityFactor", with: "0", in: app)
        tap("saveBoardComponent", in: app)
        XCTAssertTrue(app.staticTexts["boardComponentError"].waitForExistence(timeout: 5))
        dismissKeyboard(in: app)
        replaceValue("deviceParameter_D1_idealityFactor", with: "1", in: app)
        dismissKeyboard(in: app)
        tap("probeTerminalCurrent_D1_1", in: app)
        waitForEditorDismissal(in: app)
        expectEngineering("probeCurrent", equals: -diode.current, accuracy: 0.00002, in: app)

        exampleDevice("LED", in: app)
        let led = junctionReference(supply: 5, resistance: 330, shunt: 10000,
                                    saturation: 1e-20, ideality: 2, seriesResistance: 10)
        expectEngineering("probeVoltage", equals: led.voltage, accuracy: 0.005, in: app)
        openEditor("LED1", in: app)
        tap("probeBranchCurrent_LED1", in: app)
        waitForEditorDismissal(in: app)
        expectEngineering("probeCurrent", equals: led.current, accuracy: 0.00002, in: app)
        capture("LED current and breadboard", in: app)
        openEditor("LED1", in: app)
        replaceValue("deviceParameter_LED1_seriesResistance", with: "500", in: app)
        tap("saveBoardComponent", in: app)
        waitForEditorDismissal(in: app)
        let changed = junctionReference(supply: 5, resistance: 330, shunt: 10000,
                                        saturation: 1e-20, ideality: 2, seriesResistance: 500)
        expectEngineering("probeCurrent", equals: changed.current, accuracy: 0.00002, in: app)
        XCTAssertLessThan(engineeringValue("probeCurrent", in: app), led.current)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["part_LED1"].waitForExistence(timeout: 8))
        openEditor("LED1", in: app)
        tap("deviceParameter_LED1_seriesResistance", in: app)
        XCTAssertEqual(Double(app.textFields["deviceParameter_LED1_seriesResistance"].value as? String ?? ""), 500)
        dismissKeyboard(in: app)
        tap("probeBranchCurrent_LED1", in: app)
        waitForEditorDismissal(in: app)
        expectEngineering("probeCurrent", equals: changed.current, accuracy: 0.00002, in: app)
    }

    func testTransistorSwitchesPoweredOpAmpAndFivePinPlacement() {
        let app = launchBoard()
        exampleDevice("NPN", in: app)
        XCTAssertLessThan(engineeringValue("probeVoltage", in: app), 0.4)
        openEditor("Q1", in: app)
        tap("probeTerminalCurrent_Q1_2", in: app)
        waitForEditorDismissal(in: app)
        XCTAssertLessThan(engineeringValue("probeCurrent", in: app), -0.004)
        openEditor("V2", in: app)
        replaceValue("boardComponentValue", with: "0", in: app)
        tap("saveBoardComponent", in: app)
        waitForEditorDismissal(in: app)
        expectEngineering("probeVoltage", equals: 5, accuracy: 0.01, in: app)

        exampleDevice("MOSFET", in: app)
        XCTAssertLessThan(engineeringValue("probeVoltage", in: app), 0.2)
        openEditor("M1", in: app)
        tap("probeTerminalCurrent_M1_1", in: app)
        waitForEditorDismissal(in: app)
        expectEngineering("probeCurrent", equals: 0, accuracy: 1e-12, in: app)
        openEditor("V2", in: app)
        replaceValue("boardComponentValue", with: "0", in: app)
        tap("saveBoardComponent", in: app)
        waitForEditorDismissal(in: app)
        expectEngineering("probeVoltage", equals: 5, accuracy: 0.01, in: app)

        exampleDevice("OpAmp", in: app)
        expectEngineering("probeVoltage", equals: 2.5, accuracy: 0.005, in: app)
        openEditor("U1", in: app)
        tap("deviceParameter_U1_openLoopGain", in: app)
        XCTAssertEqual(Double(app.textFields["deviceParameter_U1_openLoopGain"].value as? String ?? ""), 100000)
        dismissKeyboard(in: app)
        tap("probeTerminalCurrent_U1_3", in: app)
        waitForEditorDismissal(in: app)
        expectEngineering("probeCurrent", equals: 0.0035, accuracy: 0.00002, in: app)
        capture("Powered op-amp follower", in: app)
        openEditor("R1", in: app)
        tap("value_100", in: app); tap("saveBoardComponent", in: app)
        waitForEditorDismissal(in: app)
        expectEngineering("probeVoltage", equals: 2, accuracy: 0.02, in: app)
        expectEngineering("probeCurrent", equals: 0.020, accuracy: 0.0002, in: app)
        openEditor("U1", in: app)
        tap("probeTerminalCurrent_U1_3", in: app)
        waitForEditorDismissal(in: app)
        expectEngineering("probeCurrent", equals: 0.021, accuracy: 0.0002, in: app)

        example("empty", in: app)
        place("opAmp", at: ["A1", "A3", "F3", "A5", "A7"], in: app)
        XCTAssertTrue(app.buttons["part_U1"].waitForExistence(timeout: 5))
        let part = app.buttons["part_U1"]
        XCTAssertTrue(part.label.contains("A1"))
        XCTAssertTrue(part.label.contains("A7"))
        openEditor("U1", in: app)
        tap("deviceParameter_U1_openLoopGain", in: app)
        XCTAssertEqual(Double(app.textFields["deviceParameter_U1_openLoopGain"].value as? String ?? ""), 100000)
        dismissKeyboard(in: app)
        tap("cancelBoardComponent", in: app)
        waitForEditorDismissal(in: app)
    }

    private func exampleDevice(_ suffix: String, in app: XCUIApplication) {
        tap("boardExamples", in: app)
        tap("example\(suffix)", in: app)
    }

    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Independent one-dimensional Shockley+series-resistance load-line reference.
    private func junctionReference(supply: Double, resistance: Double, shunt: Double,
                                   saturation: Double, ideality: Double,
                                   seriesResistance: Double) -> (voltage: Double, current: Double) {
        let thermalVoltage = 1.380649e-23 * 300 / 1.602176634e-19
        var low = 0.0, high = supply / resistance
        for _ in 0..<100 {
            let current = (low + high) / 2
            let voltage = ideality * thermalVoltage * log1p(current / saturation) + seriesResistance * current
            let loadLine = voltage + resistance * (current + voltage / shunt)
            if loadLine > supply { high = current } else { low = current }
        }
        let current = (low + high) / 2
        return (ideality * thermalVoltage * log1p(current / saturation) + seriesResistance * current, current)
    }

    private func launchBoard() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--breadboard", "--breadboard-test-suite", "CircuitToy.UITests.\(UUID().uuidString)"]
        app.launch()
        XCTAssertTrue(app.buttons["addBoardComponent"].waitForExistence(timeout: 8))
        return app
    }

    private func example(_ name: String, in app: XCUIApplication) {
        tap("boardExamples", in: app)
        tap("example_\(name)", in: app)
    }

    private func mode(_ name: String, in app: XCUIApplication) {
        let button = app.segmentedControls["boardMode"].buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    private func place(_ kind: String, at holes: [String], in app: XCUIApplication) {
        tap("addBoardComponent", in: app)
        tap("palette_\(kind)", in: app)
        for hole in holes { tap("hole_\(hole)", in: app) }
    }

    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        if ["boardComponentValue", "boardInitialState"].contains(id) || id.hasPrefix("deviceParameter_") {
            return app.textFields.matching(identifier: id).firstMatch
        }
        if id.hasPrefix("probe") && !id.hasPrefix("probeBranchCurrent_") && !id.hasPrefix("probeTerminalCurrent_") && id != "probeTool" ||
            ["boardAwaitingStep", "boardElapsedTime", "boardComponentError"].contains(id) {
            return app.staticTexts.matching(identifier: id).firstMatch
        }
        return app.buttons.matching(identifier: id).firstMatch
    }

    private func openEditor(_ part: String, in app: XCUIApplication) {
        tap("part_\(part)", in: app)
        XCTAssertTrue(app.buttons["saveBoardComponent"].waitForExistence(timeout: 5))
    }

    private func waitForEditorDismissal(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["saveBoardComponent"].waitForNonExistence(timeout: 5))
    }

    private func replaceValue(_ id: String, with text: String, in app: XCUIApplication) {
        dismissKeyboard(in: app)
        tap(id, in: app)
        let field = element(id, in: app)
        let count = (field.value as? String)?.count ?? 0
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count) + text)
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        if app.keyboards.firstMatch.exists, app.buttons["doneBoardKeyboard"].exists {
            app.buttons["doneBoardKeyboard"].tap()
        }
    }

    private func elapsedTime(in app: XCUIApplication) -> Double {
        guard let time = Double(value("boardElapsedTime", in: app)) else {
            XCTFail("Missing simulation time")
            return .nan
        }
        return time
    }

    private func tap(_ id: String, in app: XCUIApplication) {
        let target = element(id, in: app)
        _ = target.waitForExistence(timeout: 1)
        func ready() -> Bool {
            guard target.exists, target.isHittable else { return false }
            // AX can report a partly visible row beneath the pinned probe bar as hittable.
            // Scroll the entire interactive row into the usable viewport before tapping.
            if id.hasPrefix("part_") || id.hasPrefix("jumper_") || id.hasPrefix("selectTerminalCurrent_") {
                let frame = target.frame
                return frame.minY >= app.frame.minY + 80 && frame.maxY <= app.frame.maxY - 130
            }
            return true
        }
        let isHole = id.hasPrefix("hole_")
        if isHole && !ready() { revealBoard(target, in: app) }
        if !ready() {
            let modalIDs = ["boardEditorForm", "boardWireEditorForm", "boardPalette"]
            let candidates = modalIDs.flatMap { [app.scrollViews[$0], app.tables[$0], app.collectionViews[$0]] }
            let scroll = candidates.first { $0.exists } ?? app.scrollViews["sandboxScroll"]
            if scroll.exists {
                let topControls: Set<String> = ["boardExamples", "addBoardComponent", "probeTool", "wireTool",
                                                "groundTool", "editBoardTool", "undoBoardEdit"]
                let downFirst = isHole || topControls.contains(id)
                for attempt in 0..<12 {
                    if ready() { break }
                    var upwards = attempt < 6 ? !downFirst : downFirst
                    if target.exists {
                        let frame = target.frame
                        let visible = scroll.frame.intersection(app.frame)
                        let top = max(visible.minY, app.frame.minY + 80)
                        let bottom = min(visible.maxY, app.frame.maxY - 130)
                        if frame.minY < top { upwards = false }
                        else if frame.maxY > bottom { upwards = true }
                    }
                    dragOuter(scroll, upwards: upwards, in: app)
                }
            }
        }
        if isHole && !ready() { revealBoard(target, in: app) }
        XCTAssertTrue(target.waitForExistence(timeout: 5), "Missing \(id)")
        XCTAssertTrue(target.isHittable, "Cannot reach \(id)")
        target.tap()
    }

    private func dragOuter(_ scroll: XCUIElement, upwards: Bool, in app: XCUIApplication) {
        let visible = scroll.frame.intersection(app.frame)
        let isModal = scroll.identifier != "sandboxScroll"
        if !isModal {
            // Keep the gesture above the persistent probe bar and home indicator.
            let low = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.8))
            let high = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.25))
            (upwards ? low : high).press(forDuration: 0.05, thenDragTo: upwards ? high : low,
                                       withVelocity: .slow, thenHoldForDuration: 0.3)
            return
        }
        let keyboardTop = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : visible.maxY
        let bottom = min(visible.maxY, keyboardTop, app.frame.maxY - 100) - 24
        let top = max(app.frame.minY + 200, visible.minY + min(120, max(30, (bottom - visible.minY) * 0.2)))
        // Use the Form's visible center, keeping gestures inside its content above the keyboard.
        // The main scroll uses its padded edge, outside the independently pannable board.
        let x = visible.midX
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let low = origin.withOffset(CGVector(dx: x - app.frame.minX, dy: bottom - app.frame.minY))
        let high = origin.withOffset(CGVector(dx: x - app.frame.minX, dy: top - app.frame.minY))
        (upwards ? low : high).press(forDuration: 0.05, thenDragTo: upwards ? high : low,
                                   withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    private func revealBoard(_ target: XCUIElement, in app: XCUIApplication) {
        let board = app.scrollViews["breadboardSurface"]
        guard board.exists && board.isHittable else { return }
        let usable = CGRect(x: app.frame.minX, y: app.frame.minY + 80,
                            width: app.frame.width, height: app.frame.height - 210)
        for _ in 0..<4 {
            guard target.exists else { break }
            let visible = board.frame.intersection(usable)
            guard !visible.isNull else { break }
            if target.frame.minY < visible.minY { board.swipeDown() }
            else if target.frame.maxY > visible.maxY { board.swipeUp() }
            else { break }
        }
        for _ in 0..<2 {
            if target.exists && target.isHittable { break }
            board.swipeLeft()
        }
        for _ in 0..<4 {
            if target.exists && target.isHittable { break }
            board.swipeRight()
        }
    }

    private func value(_ id: String, in app: XCUIApplication) -> String {
        let meter = element(id, in: app)
        XCTAssertTrue(meter.waitForExistence(timeout: 5), "Missing live probe \(id)")
        return meter.value as? String ?? meter.label
    }

    private func expectValue(_ id: String, equals expected: String, in app: XCUIApplication) {
        let target = element(id, in: app)
        let predicate = NSPredicate(format: "value == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
                       "\(id) read \(value(id, in: app)); expected \(expected)")
    }

    private func engineeringValue(_ id: String, in app: XCUIApplication) -> Double {
        let raw = value(id, in: app)
        let fields = raw.split(separator: " ")
        guard let number = fields.first.flatMap({ Double($0) }), let unit = fields.last else {
            XCTFail("Non-numeric probe result: \(raw)")
            return .nan
        }
        let factors: [Character: Double] = ["G": 1e9, "M": 1e6, "k": 1e3, "m": 1e-3, "µ": 1e-6, "n": 1e-9, "p": 1e-12]
        let scale = unit.count > 1 ? factors[unit.first!] ?? 1 : 1
        return number * scale
    }

    private func expectEngineering(_ id: String, equals expected: Double, accuracy: Double,
                                   in app: XCUIApplication) {
        XCTAssertEqual(engineeringValue(id, in: app), expected, accuracy: accuracy,
                       "Unexpected live reading from \(id)")
    }
}
