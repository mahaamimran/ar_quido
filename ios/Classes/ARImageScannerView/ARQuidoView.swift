import Foundation
import Flutter

class ARQuidoView: NSObject, FlutterPlatformView {
    private var viewController: ARQuidoViewController
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        // Initialize properties with default values
        var referenceImageNames = [String]()
        var referenceVideoNames = [String]()
        var showLogo = true // Default to true, adjust based on actual need

        // Extract parameters safely using guard and optional casting
        if let creationParams = args as? [String: Any] {
            referenceImageNames = creationParams["referenceImageNames"] as? [String] ?? []
            referenceVideoNames = creationParams["referenceVideoNames"] as? [String] ?? []
            showLogo = creationParams["showLogo"] as? Bool ?? true
        } else {
            fatalError("Could not extract parameters from creation params")
        }
        
        let channelName = "plugins.miquido.com/ar_quido"
        _ = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        viewController = ARQuidoViewController(referenceImageNames: referenceImageNames, referenceVideoNames: referenceVideoNames, showLogo: showLogo)
        super.init()
    }
    
    func view() -> UIView {
        return viewController.view
    }
}
