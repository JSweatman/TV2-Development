import XCTest
import Vision

final class TV2SafariTests: XCTestCase {
    func testSyntheticLookup() throws {
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
        let allowAddressFallback = false // set true by harness only after simctl timeout
        let health = safari.webViews.staticTexts["TV2 LOOPBACK HEALTH B42077A"]
        if !health.waitForExistence(timeout: 15) {
            guard allowAddressFallback else {
                try capture("00-health-unavailable-no-fallback", safari)
                XCTFail("Health marker absent after simctl returned; bounded stop")
                return
            }
            print("TV2_STAGE: health_missing_attempt_single_native_address_fallback")
            let address = safari.textFields.matching(NSPredicate(format: "label CONTAINS[c] 'address' OR label CONTAINS[c] 'Search'")).firstMatch
            guard address.exists && address.isHittable else {
                try capture("00-health-address-unavailable", safari)
                XCTFail("No visible native Safari address field; stop before app")
                return
            }
            address.tap()
            guard safari.keyboards.firstMatch.waitForExistence(timeout: 5) else { XCTFail("Address tap did not expose keyboard"); return }
            address.typeText("http://127.0.0.1:8765/health\n")
            guard health.waitForExistence(timeout: 20) else {
                try capture("00-health-unavailable", safari)
                XCTFail("Loopback health marker absent after one native address attempt")
                return
            }
        }
        XCTAssertTrue(health.isHittable)
        try capture("00-health-visible", safari)
        print("TV2_STAGE: distinct_loopback_health_visible")
        let link = safari.webViews.links["Open synthetic TV2"]
        XCTAssertTrue(link.isHittable)
        link.tap()
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
        // Local Flutter engine source names this opt-in; XCUI exposure in the
        // hosted Safari build is still a hypothesis, not an observed diagnosis.
        // Never use DOM injection or guessed coordinates for this control.
        let accessibility = safari.webViews.buttons.matching(
            NSPredicate(format: "label == %@", "Enable accessibility"))
        let optInCount = accessibility.count
        let optInHittable = optInCount == 1 && accessibility.firstMatch.isHittable
        print("TV2_STAGE: accessibility_opt_in_query; count=\(optInCount); hittable=\(optInHittable)")
        if optInHittable {
            accessibility.firstMatch.tap()
            print("TV2_STAGE: accessibility_opt_in_exact_unique_hittable_control_tapped; effect_unverified")
        } else {
            print("TV2_HYPOTHESIS: flutter_accessibility_opt_in_not_actionable; not_evidence_of_failure_cause")
        }
        let plus = button("+1 Shared calling-code namespace")
        let plusExists = plus.waitForExistence(timeout: 15)
        let plusHittable = plusExists && plus.isHittable
        print("TV2_STAGE: plus_one_after_tip_check; exists=\(plusExists)")
        print("TV2_STAGE: plus_one_after_tip_check; hittable=\(plusHittable)")
        if plusExists && plusHittable {
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
            print("TV2_STAGE: plus_one_current_screenshot_ocr_row_tap; native_query_not_actionable")
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
        let jaz = safari.webViews.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Sample Cedar Workshop")).firstMatch
        // Case-sensitive, web-content-only Back excludes Safari chrome Back
        // and the uppercase keypad BACK. A preview-only Jaz is not a listing.
        let listingBack = button("Back")
        let resolvedListing = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            return jaz.exists && jaz.isHittable && listingBack.exists &&
                listingBack.isHittable && !button("ENTER").exists
        }, object: nil)
        guard XCTWaiter.wait(for: [resolvedListing], timeout: 30) == .completed else {
            print("TV2_STAGE: resolved_listing_not_verified; listing_back_exists=\(listingBack.exists); keypad_enter_exists=\(button("ENTER").exists)")
            XCTFail("Require Jaz AND listing-only Back AND absent keypad ENTER; preview name alone cannot pass")
            return
        }
        try capture("04-synthetic-listing", safari)
        print("TV2_STAGE: resolved_listing_verified; jaz_visible; listing_back_hittable; keypad_enter_absent; no_contact_actions")
        listingBack.tap()
        let returnedKeypad = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let returnedEnter = button("ENTER")
            return returnedEnter.exists && !button("Back").exists
        }, object: nil)
        guard XCTWaiter.wait(for: [returnedKeypad], timeout: 10) == .completed else {
            XCTFail("Listing Back must return to keypad ENTER")
            return
        }
        try capture("05-back-to-keypad", safari)
        print("TV2_STAGE: listing_back_returned_to_keypad_enter")
    }
}
