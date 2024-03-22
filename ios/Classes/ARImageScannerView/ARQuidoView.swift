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
        guard let creationParams = args as? [String: Any],
              let referenceImageNames = creationParams["referenceImageNames"] as? [String],
              let referenceVideoNames = creationParams["referenceVideoNames"] as? [String] else {
            fatalError("Could not extract reference names from creation params")
        }
        
        let channelName = "plugins.miquido.com/ar_quido"
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
        viewController = ARQuidoViewController(referenceImageNames: referenceImageNames, referenceVideoNames: referenceVideoNames, methodChannel: channel)
        super.init()
    }
    
    func view() -> UIView {
        return viewController.view
    }
}
