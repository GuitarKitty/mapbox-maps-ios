import UIKit

#if canImport(MapboxMapsFoundation)
import MapboxMapsFoundation
#endif

#if canImport(MapboxMapsStyle)
import MapboxMapsStyle
#endif

// MARK: - Snapshotter
public class Snapshotter {

    /// Internal `MapboxCoreMaps.MBXMapSnapshotter` object that takes care of
    /// rendering a snapshot.
    internal var mapSnapshotter: MapSnapshotter

    private let observer = DelegatingObserver()

    /// Map of event types to subscribed event handlers
    private var eventHandlers: [String: [(MapboxCoreMaps.Event) -> Void]] = [:]

    /// A `style` object that can be manipulated to set different styles for a snapshot
    public let style: Style

    /// Initialize a `Snapshotter` instance
    /// - Parameters:
    ///   - observer: Observer responsible for handling lifecycle events in a snapshot
    ///   - options: Options describing an intended snapshot
    public init(options: MapSnapshotOptions) {
        mapSnapshotter = MapSnapshotter(options: options)
        style = Style(with: mapSnapshotter)
        observer.delegate = self
        mapSnapshotter.subscribe(for: observer, events: [
            MapEvents.styleLoaded,
            MapEvents.styleImageMissing,
            MapEvents.mapLoadingError
        ])
    }

    /// Reacting to snapshot events.
    /// - Parameters:
    ///   - eventType: The event type to react to.
    ///   - handler: The block of code to execute when the event occurs.
    public func on(_ eventType: MapEvents.EventKind, handler: @escaping (MapboxCoreMaps.Event) -> Void) {
        var handlers: [(MapboxCoreMaps.Event) -> Void] = eventHandlers[eventType.rawValue] ?? []
        handlers.append(handler)
        eventHandlers[eventType.rawValue] = handlers
    }

    /// The size of the snapshot
    public var snapshotSize: CGSize {
        get {
            let mbxSize = mapSnapshotter.getSize()
            let size = CGSize(width: CGFloat(mbxSize.width),
                              height: CGFloat(mbxSize.height))
            return size
        } set(newSize) {
            let mbxSize = MapboxCoreMaps.Size(width: Float(newSize.width), height: Float(newSize.height))
            mapSnapshotter.setSizeFor(mbxSize)
        }
    }

    /// Camera configuration for the snapshot
    public var camera: CameraOptions {
        get {
            return mapSnapshotter.getCameraOptions(forPadding: nil)
        } set(newValue) {
            mapSnapshotter.setCameraFor(newValue)
        }
    }

    /// In the tile mode, the snapshotter fetches the still image of a single tile.
    public var tileMode: Bool {
        get {
            return mapSnapshotter.isInTileMode()
        } set(newValue) {
            mapSnapshotter.setTileModeForSet(newValue)
        }
    }

    /**
     Request a new snapshot. If there is a pending snapshot request, it is cancelled automatically.

     - Parameter overlayHandler: The optional block to call after the base map finishes drawing,
                                 but before the final snapshot has been drawn. This block provides a
                                `SnapshotOverlayHandler` type, which can be used with Core Graphics
                                 to draw custom content directly over the snapshot image.
     - Parameter completion: The block to call once the snapshot has been generated, providing a
                             `Result<UIImage, SnapshotError>` type.
     */
    public func start(overlayHandler: SnapshotOverlayHandler?,
                      completion: @escaping (Result<UIImage, SnapshotError>) -> Void) {

        mapSnapshotter.start { (expected) in
            guard let validExpected = expected else {
                completion(.failure(.unknown))
                return
            }

            if validExpected.isError() {
                completion(.failure(.snapshotFailed(reason: validExpected.error as? String)))
            }

            if validExpected.isValue(), let snapshot = validExpected.value as? MapSnapshot {
                let mbxImage = snapshot.image()
                let scale = UIScreen.main.scale

                if let uiImage = UIImage(mbxImage: mbxImage, scale: scale) {
                    let rect = CGRect(origin: .zero, size: uiImage.size)
                    let renderer = UIGraphicsImageRenderer(size: uiImage.size)
                    let compositeImage = renderer.image { rendererContext in

                        // First draw the snaphot image into the context
                        let context = rendererContext.cgContext

                        if let cgImage = uiImage.cgImage {
                            context.draw(cgImage, in: rect)
                        }

                        let pointForCoordinate = { (coordinate: CLLocationCoordinate2D) -> CGPoint in
                            let screenCoordinate = snapshot.screenCoordinate(for: coordinate)
                            return CGPoint(x: screenCoordinate.x, y: screenCoordinate.y)
                        }

                        let coordinateForPoint = { (point: CGPoint) -> CLLocationCoordinate2D in
                            // TODO: Fix circular dependency issues with MapboxMapsStyle/Foundation in order to use point.screenCoordinate extension
                            let screenCoordinate = ScreenCoordinate(x: Double(point.x), y: Double(point.y))
                            return snapshot.coordinate(for: screenCoordinate)
                        }

                        // Apply the overlay, if provided.
                        let overlay = SnapshotOverlay(context: context,
                                                      scale: scale,
                                                      pointForCoordinate: pointForCoordinate,
                                                      coordinateForPoint: coordinateForPoint)

                        if let overlayHandler = overlayHandler {
                            context.saveGState()
                            overlayHandler(overlay)
                            context.restoreGState()
                        }

                        // Composite the logo on the snapshot,
                        // only after everything else has been drawn.
                        let logoView = LogoView(logoSize: .regular)
                        let logoPadding = CGFloat(10.0)
                        let logoOrigin = CGPoint(x: logoPadding,
                                                 y: uiImage.size.height - logoView.frame.size.height - logoPadding)
                        context.translateBy(x: logoOrigin.x, y: logoOrigin.y)
                        logoView.layer.render(in: context)
                     }
                    completion(.success(compositeImage))
                } else {
                    completion(.failure(.snapshotFailed(reason: "Could not convert internal Image type to UIImage.")))
                }
            }

            if validExpected.isError(), let error = validExpected.error as? String {
                completion(.failure(.snapshotFailed(reason: error)))
            }

        }

    }

    /**
     Cancels the current snapshot operation.The callback passed to the start
     method is called with error parameter set.
     */
    public func cancel() {
        mapSnapshotter.cancel()
    }

    public enum SnapshotError: Error {
        case unknown

        /// Snapshot failed with error description
        case snapshotFailed(reason: String?)
    }

    internal func compositeLogo(for snapshotImage: UIImage) -> UIImage {
        let rect = CGRect(origin: .zero, size: snapshotImage.size)
        let logoView = LogoView(logoSize: .regular)

        let renderer = UIGraphicsImageRenderer(size: snapshotImage.size)

        let compositeImage = renderer.image { rendererContext in

            // First draw the snaphot
            let context = rendererContext.cgContext

            if let cgImage = snapshotImage.cgImage {
                context.draw(cgImage, in: rect)
            }

            // Padding between the edges of the logo and the snapshot
            let logoPadding = CGFloat(10.0)

            // Position the logo
            let logoOrigin = CGPoint(x: logoPadding,
                                     y: snapshotImage.size.height - logoView.frame.size.height - logoPadding)
            context.translateBy(x: logoOrigin.x, y: logoOrigin.y)

            // Composite the logo on the snapshot
            logoView.layer.render(in: context)
         }

        return compositeImage
    }
}

extension Snapshotter: DelegatingObserverDelegate {
    /// Notify correct handler
    internal func notify(for event: MapboxCoreMaps.Event) {
        let handlers = eventHandlers[event.type]
        handlers?.forEach { (handler) in
            handler(event)
        }
    }
}
