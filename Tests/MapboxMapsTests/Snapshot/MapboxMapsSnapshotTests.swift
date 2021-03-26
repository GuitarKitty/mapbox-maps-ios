import XCTest
import MapboxMaps
import MapboxCoreMaps
import Turf
import Foundation
import UIKit
#if canImport(MapboxMaps)
@testable import MapboxMaps
#else
@testable import MapboxMapsSnapshot
#endif
//swiftlint:disable explicit_top_level_acl explicit_acl
class MapboxMapsSnapshotTests: IntegrationTestCase {
   
    var geoJSONSource = GeoJSONSource()
    var snapshotView = UIImageView()
    var blankAttachment: XCTAttachment!
    var newAttachment: XCTAttachment!
    
    // Create snapshot options
    private func snapshotterOptions(size: CGSize) -> MapSnapshotOptions {
        let resourceOptions = ResourceOptions(accessToken: accessToken)
        let options = MapSnapshotOptions(size: size, resourceOptions: resourceOptions, pixelRatio: 4)
        return options
    }
    
    // Testing creating the snapshot
    func CapturingSnapshotterInSnapshotCompletion() {
        let timeout: TimeInterval = 10.0
        let expectation = self.expectation(description: "snapshot")
        let options = snapshotterOptions(size: CGSize(width: 300, height: 300))
        DispatchQueue.main.async {
            let snapshotter = Snapshotter(options: options)
            snapshotter.camera = CameraOptions(center: CLLocationCoordinate2D(latitude: 38.9180379, longitude: -77.0600235),zoom: 5)
            snapshotter.style.styleURL = StyleURL.light
            snapshotter.start(overlayHandler: nil) { (result) in
                dump(snapshotter)
                expectation.fulfill()
                XCTAssertNotNil(result)
            }
        }
        wait(for: [expectation], timeout: timeout)
    }
    
    // Testing snapshot overlay
    func testSnapshotOverlay() {
        
        let options = snapshotterOptions(size: CGSize(width: 300, height: 300))
        let snapshotter = Snapshotter(options: options)
        snapshotter.camera = CameraOptions(center: CLLocationCoordinate2D(latitude: 38.9180379, longitude: -77.0600235),zoom: 5)
        snapshotter.style.styleURL = StyleURL.light
        let expectation = self.expectation(description: "snapshot")
        expectation.expectedFulfillmentCount = 2
        snapshotter.start { (overlay) in
            guard let _ = overlay.context.makeImage() else {
                XCTFail()
                return
            }
            expectation.fulfill()
        } completion: { (result) in
            if case let .success(image) = result {
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("Snapshot Asset.png")
                print(url)
                do {
                    try image.pngData()?.write(to: url)
                } catch {
                    print(error)
                }
                
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)
    }
    
    func testSnapshotSizeAndScaleAccuracy() {
        let imageRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let options = snapshotterOptions(size: imageRect.size)
        let snapshotter = Snapshotter(options: options) //should have protocol for GLnative (may have been ticketed)
        snapshotter.camera = CameraOptions(center: CLLocationCoordinate2D(latitude: 38.9180379, longitude: -77.0600235),zoom: 5)
        snapshotter.style.styleURL = StyleURL.light
        let expectation = self.expectation(description: "snapshot accuracy")
        expectation.expectedFulfillmentCount = 2
        snapshotter.start { (overlay) in
            
            expectation.fulfill()
        } completion: { (result) in
            // size comparison for snapshotter
            XCTAssertEqual(snapshotter.snapshotSize, imageRect.size)
            
            //scale and size comparison for image
            switch result {
            case.success(let image) :
                XCTAssertEqual(image.scale, CGFloat(options.pixelRatio))
                XCTAssertEqual(image.size, imageRect.size)
            case.failure(_) :
                XCTFail()
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)
    }

    func testSnapshotLogoVisibility() {

        let imageRect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let options = snapshotterOptions(size: imageRect.size)
        let snapshotterNew = Snapshotter(options: options)
        snapshotterNew.camera = CameraOptions(center: CLLocationCoordinate2D(latitude: 38.9180379, longitude: -77.0600235),zoom: 5)
        snapshotterNew.style.styleURL = .light
        let expectation2 = self.expectation(description: "snapshot logo")
        snapshotterNew.start(overlayHandler: nil) { (result) in
            switch result {
            case.success(let image) :
                let newAttachment = XCTAttachment(image: image)
                newAttachment.lifetime = .keepAlways
                self.add(newAttachment)
                
                // Compare snapshot asset data vs snapshot image data
                let expectedImageData = try? Data(contentsOf: Bundle.mapboxMapsTests.url(forResource: "Snapshot Asset", withExtension: "png")!)
                
                XCTAssertEqual(expectedImageData, image.pngData())
                
            case.failure(_) :
                XCTFail()
            }
 
            expectation2.fulfill()
        }

        wait(for: [expectation2], timeout: 10)
    }
}
