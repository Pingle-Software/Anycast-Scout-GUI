import Cocoa
import FlutterMacOS
import XCTest

class RunnerTests: XCTestCase {

  func testBundleIdentifierIsConfigured() {
    XCTAssertEqual(Bundle.main.bundleIdentifier, "com.pingle.anycastScoutGui.RunnerTests")
  }

}
