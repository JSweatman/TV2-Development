import XCTest

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
        let plus = button("+1 Shared calling-code namespace")
        guard plus.waitForExistence(timeout: 75) && plus.isHittable else {
            try capture("02-country-unavailable", safari)
            print("TV2_STAGE: country_control_unavailable; retry_country=\(button("Retry Country").exists)")
            XCTFail("No visible hittable +1 control; network or accessibility not established")
            return
        }
        plus.tap()
        XCTAssertTrue(button("5").waitForExistence(timeout: 10))
        print("TV2_STAGE: visible_plus_one_activated")
        try capture("03-country-selected", safari)
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
