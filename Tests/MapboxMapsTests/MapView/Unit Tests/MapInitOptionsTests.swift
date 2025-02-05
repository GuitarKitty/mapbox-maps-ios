import XCTest
@testable import MapboxMaps

class MapInitOptionsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        CredentialsManager.default.accessToken = ""
    }

    override func tearDown() {
        super.tearDown()
        CredentialsManager.default.accessToken = ""
    }

    func testDefaultMapInitOptionsAreOverridden() {
        var updatedMapInitOptions = MapInitOptions()
        XCTAssertNotEqual(updatedMapInitOptions.resourceOptions.accessToken, "pk.aaaaaa")

        CredentialsManager.default.accessToken = "pk.aaaaaa"

        updatedMapInitOptions = MapInitOptions()
        XCTAssertEqual(updatedMapInitOptions.resourceOptions.accessToken, "pk.aaaaaa")

        // Check default MapOptions. This is to ensure that that MapOption's default
        // `init` is not being called.
        XCTAssert(updatedMapInitOptions.mapOptions.constrainMode != .none)
    }

    func testEquality() {
        let a = MapInitOptions()
        let b = MapInitOptions()
        XCTAssertEqual(a, b)

        let options = ResourceOptions(accessToken: "1234")
        let c = MapInitOptions(resourceOptions: options,
                               mapOptions: MapOptions(constrainMode: .heightOnly))
        XCTAssertNotEqual(a, c)
    }

    func testHashable() {
        var set = Set<MapInitOptions>()

        let a = MapInitOptions()
        set.insert(a)

        let b = MapInitOptions()
        set.insert(b)

        XCTAssert(set.count == 1)
    }
}
