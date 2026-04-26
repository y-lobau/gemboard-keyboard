import XCTest
@testable import PlynMacCore

final class PlynMacHoldTriggerTests: XCTestCase {
  func testFnHoldStartsOnceAndStopsOnRelease() {
    var machine = PlynMacHoldTriggerStateMachine(trigger: .functionGlobe)

    XCTAssertEqual(machine.handle(.pressed(.functionGlobe)), .started)
    XCTAssertEqual(machine.handle(.pressed(.functionGlobe)), .unchanged)
    XCTAssertTrue(machine.isHeld)

    XCTAssertEqual(machine.handle(.released(.functionGlobe)), .stopped)
    XCTAssertFalse(machine.isHeld)
  }

  func testFallbackTriggerIgnoresFnEvents() {
    var machine = PlynMacHoldTriggerStateMachine(trigger: .controlOption)

    XCTAssertEqual(machine.handle(.pressed(.functionGlobe)), .unchanged)
    XCTAssertFalse(machine.isHeld)

    XCTAssertEqual(machine.handle(.pressed(.controlOption)), .started)
    XCTAssertEqual(machine.handle(.released(.functionGlobe)), .unchanged)
    XCTAssertEqual(machine.handle(.released(.controlOption)), .stopped)
  }
}
