import XCTest
import Vision

final class TV2SafariTests: XCTestCase {
    func testHostedLookup() throws {
        continueAfterFailure = false
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.activate()
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 20))
        print("TV2_STAGE: attached_to_mobile_safari")
        func button(_ label: String) -> XCUIElement {
            safari.webViews.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        }
        func capture(_ name: String, _ element: XCUIElement) throws {
            let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tv2-evidence")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try element.screenshot().pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
        }
        // Only pre-lookup screenshots: never capture a full resolved contact page.
        try capture("01-safari-launch", safari)
        // The parent visually verified the Safari tip in artifact 15014991701:
        // 750x1334 screenshot, close x at (675,826). Never apply to other sizes.
        func words() throws -> [VNRecognizedTextObservation] {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            let image = XCUIScreen.main.screenshot().image.cgImage!
            try VNImageRequestHandler(cgImage: image).perform([request])
            return request.results ?? []
        }
        func text(_ observations: [VNRecognizedTextObservation]) -> String {
            observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
        }
        func tipPresent(_ value: String) -> Bool {
            value.contains("View Bookmarks") && value.contains("Open Tabs")
        }
        let before = try words()
        if tipPresent(text(before)) {
            let frame = safari.frame
            let close = safari.buttons.matching(NSPredicate(format: "label ==[c] 'Close' OR label ==[c] 'Dismiss'")).allElementsBoundByIndex.first {
                $0.isHittable && $0.frame.midX > frame.width * 0.8 &&
                $0.frame.midY > frame.height * 0.55 && $0.frame.midY < frame.height * 0.7
            }
            if let close = close {
                close.tap()
                print("TV2_STAGE: safari_tip_dismissal_native_close_query")
            } else {
                let image = XCUIScreen.main.screenshot().image
                guard image.size.width * image.scale == 750 && image.size.height * image.scale == 1334 else {
                    XCTFail("Safari tip exists but screenshot geometry differs from reviewed reference")
                    return
                }
                safari.coordinate(withNormalizedOffset: CGVector(dx: 675.0/750.0, dy: 826.0/1334.0)).tap()
                print("TV2_STAGE: safari_tip_dismissal_reviewed_close_coordinate_750x1334")
            }
            // Independent visual postcondition, no blind second dismissal attempt.
            let gone = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard let observed = try? words() else { return false }
                return !tipPresent(text(observed))
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed)
            try capture("02-safari-tip-dismissed", safari)
        } else {
            print("TV2_STAGE: safari_tip_not_visually_detected")
        }
        let plus = button("+1 Shared calling-code namespace")
        if plus.waitForExistence(timeout: 15) && plus.isHittable {
            plus.tap()
            print("TV2_STAGE: plus_one_native_web_query")
        } else {
            // Visual fallback only for the uniquely recognized row in the country sheet.
            // OCR uses the current screenshot, not guessed Flutter coordinates.
            let current = try words()
            let value = text(current)
            let rows = current.filter { $0.topCandidates(1).first?.string == "Shared calling-code namespace" }
            guard value.contains("Select Country"), value.contains("+1"), rows.count == 1 else {
                try capture("02-country-unavailable", safari)
                print("TV2_STAGE: country_control_unavailable; retry_country=\(button("Retry Country").exists)")
                XCTFail("Neither exposed +1 semantics nor uniquely recognized visible country row")
                return
            }
            let box = rows[0].boundingBox
            XCTAssertTrue(box.midY > 0.1 && box.midY < 0.8)
            try capture("02-country-row-before-visual-tap", safari)
            safari.coordinate(withNormalizedOffset: CGVector(dx: box.midX, dy: 1-box.midY)).tap()
            print("TV2_STAGE: plus_one_current_screenshot_ocr_row_tap; web_button_not_exposed")
        }
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let observed = try? words() else { return false }
            let value = text(observed)
            return value.contains("ENTER LIST NUMBER") && value.contains("+1") && !value.contains("Select Country")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 10), .completed)
        print("TV2_STAGE: visible_plus_one_activated_independent_visual_postcondition")
        try capture("03-country-selected", safari)
        guard button("5").waitForExistence(timeout: 10) else {
            print("TV2_STAGE: selected_namespace_but_keypad_web_button_semantics_unavailable")
            XCTFail("Country selected; keypad accessibility query unavailable. No blind keypad taps.")
            return
        }
        for digit in ["5", "2", "9"] {
            let key = button(digit)
            XCTAssertTrue(key.isHittable, "Key must be visibly hittable")
            key.tap()
        }
        let enter = button("ENTER")
        XCTAssertTrue(enter.waitForExistence(timeout: 30))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: enter)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
        if !enter.isHittable { safari.webViews.firstMatch.swipeUp() }
        XCTAssertTrue(enter.isHittable)
        enter.tap()
        let jaz = safari.webViews.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Jaz")).firstMatch
        XCTAssertTrue(jaz.waitForExistence(timeout: 30), "Jaz must be visible after app ENTER")
        XCTAssertTrue(jaz.isHittable)
        try capture("04-jaz-label-only", jaz)
        print("TV2_STAGE: app_enter_then_visible_jaz; no_contact_actions")
    }
}
