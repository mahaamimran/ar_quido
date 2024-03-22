import UIKit
import ARKit
import SceneKit
import Flutter

protocol ImageRecognitionDelegate: AnyObject {
    func onRecognitionStarted()
    func onRecognitionPaused()
    func onRecognitionResumed()
    func onDetect(imageKey: String)
    func onDetectedImageTapped(imageKey: String)
}

class ARQuidoViewController: UIViewController {
    
    var sceneView: ARSCNView!
    
    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! +
                                    ".serialSceneKitQueue")
    
    var session: ARSession {
        return sceneView.session
    }
    
    private var wasCameraInitialized = false
    private var isResettingTracking = false
    private let referenceImageNames: Array<String>
    private let referenceVideoNames: Array<String>
    private let methodChannel: FlutterMethodChannel
    private var detectedImageNode: SCNNode?
    
    init(referenceImageNames: Array<String>, referenceVideoNames: Array<String>, methodChannel channel: FlutterMethodChannel) {
        self.referenceImageNames = referenceImageNames
        self.referenceVideoNames = referenceVideoNames
        self.methodChannel = channel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        methodChannel.setMethodCallHandler(nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        methodChannel.setMethodCallHandler(handleMethodCall(call:result:))
        sceneView = ARSCNView(frame: CGRect.zero)
        sceneView.delegate = self
        sceneView.session.delegate = self
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        view = sceneView
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        resetTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.pause()
        onRecognitionPaused()
    }
    
    @objc
    func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        let location = gestureRecognize.location(in: sceneView)
        let hitResults = sceneView.hitTest(location, options: [:])
        if hitResults.count > 0, let tappedImageName = hitResults[0].node.name {
            onDetectedImageTapped(imageKey: tappedImageName)
        }
        
    }
    
    // MARK: - Session management (Image detection setup)
    
    /// Prevents restarting the session while a restart is in progress.
    var isRestartAvailable = true
    
    func resetTracking() {
        if isResettingTracking {
            return
        }
        isResettingTracking = true
        DispatchQueue.global(qos: .userInteractive).async {
            _ = [ARReferenceImage]()
            for _ in self.referenceImageNames {
                var referenceImages = [ARReferenceImage]()
                for imagePath in self.referenceImageNames { // Assuming this now contains file paths
                    // Directly use the file path without looking it up from the bundle
                    guard let image = UIImage(contentsOfFile: imagePath) else {
                        print("Warning: UIImage could not be created for imagePath: \(imagePath)")
                        continue
                    }
                    guard let cgImage = image.cgImage else {
                        print("Warning: cgImage could not be obtained from UIImage")
                        continue
                    }
                    
                    let physicalSize: CGFloat = 0.5
                    let referenceImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: physicalSize)
                    referenceImage.name = URL(fileURLWithPath: imagePath).lastPathComponent
                    referenceImages.append(referenceImage)
                }
                let configuration = ARWorldTrackingConfiguration()
                configuration.detectionImages = Set(referenceImages)
                configuration.maximumNumberOfTrackedImages = 10
                self.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                if (!self.wasCameraInitialized) {
                    self.onRecognitionStarted()
                    self.wasCameraInitialized = true
                } else {
                    self.onRecognitionResumed()
                }
                self.isResettingTracking = false
            }
        }
    }
}

extension ARQuidoViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        
        // Fetch the video path for the detected image
         let videoPath = self.fetchVideoPath(forImageNamed: imageAnchor.referenceImage.name ?? "")
         // Use URL(fileURLWithPath:) for local file paths
         let videoURL = URL(fileURLWithPath: videoPath)

         // Create an AVPlayer with the video URL
         let player = AVPlayer(url: videoURL)
         let videoNode = SKVideoNode(avPlayer: player)
        
        // Create an SKScene to hold the SKVideoNode
        let videoScene = SKScene(size: CGSize(width: 720, height: 1280))
        videoScene.addChild(videoNode)
        
        // Position the video to play at the center of the scene
        videoNode.position = CGPoint(x: videoScene.size.width / 2, y: videoScene.size.height / 2)
        videoNode.size = videoScene.size
        videoNode.yScale = -1.0 // Invert video playback
        videoNode.play() // Start playing the video
        
        // Create an SCNPlane to serve as the video's display surface matching the image's dimensions
        let videoPlane = SCNPlane(width: imageAnchor.referenceImage.physicalSize.width, height: imageAnchor.referenceImage.physicalSize.height)
        videoPlane.firstMaterial?.diffuse.contents = videoScene // Use the SKScene as the diffuse content
        
        // Create an SCNNode for the video and add it to the detected node
        let videoPlaneNode = SCNNode(geometry: videoPlane)
        videoPlaneNode.eulerAngles.x = -.pi / 2 // Rotate to match image orientation
        node.addChildNode(videoPlaneNode)
    }
    
    func fetchVideoPath(forImageNamed imageName: String) -> String {
        // Implement fetching the video path based on the imageName
        // This is where you integrate with your Flutter code to get the appropriate video path
        // For this example, just return a placeholder string
       // return "https://file-examples.com/storage/fe7c2cbe4b65fa8179825d1/2017/04/file_example_MP4_480_1_5MG.mp4"
       print(referenceVideoNames[0])
        return referenceVideoNames[0];
    }
    

}

extension ARQuidoViewController: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        restartExperience()
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
    
    // MARK: - Error handling
    
    func displayErrorMessage(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.resetTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - Interface Actions
    
    func restartExperience() {
        guard isRestartAvailable else { return }
        isRestartAvailable = false
        resetTracking()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.isRestartAvailable = true
        }
    }
}

// MARK: PlatformView interface implementation

extension ARQuidoViewController {
    private func handleMethodCall(call: FlutterMethodCall, result: FlutterResult) {
        if call.method == "scanner#toggleFlashlight" {
            let arguments = call.arguments as? Dictionary<String, Any?>
            let shouldTurnOn = (arguments?["shouldTurnOn"] as? Bool) ?? false
            toggleFlashlight(shouldTurnOn)
            result(nil)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func toggleFlashlight(_ shouldTurnOn: Bool) {
        guard let camera = AVCaptureDevice.default(for: AVMediaType.video) else {
            return
        }
        if camera.hasTorch {
            do {
                try camera.lockForConfiguration()
                camera.torchMode = shouldTurnOn ? .on : .off
                camera.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
        } else {
            print("Torch is not available")
        }
    }
}

extension ARQuidoViewController: ImageRecognitionDelegate {
    func onRecognitionPaused() {
        DispatchQueue.main.async {
            self.methodChannel.invokeMethod("scanner#recognitionPaused", arguments: nil)
        }
    }
    
    func onRecognitionResumed() {
        DispatchQueue.main.async {
            self.methodChannel.invokeMethod("scanner#recognitionResumed", arguments: nil)
        }
    }
    
    func onRecognitionStarted() {
        DispatchQueue.main.async {
            self.methodChannel.invokeMethod("scanner#start", arguments: [String:Any]())
        }
    }
    
    func onDetect(imageKey: String) {
        DispatchQueue.main.async {
            self.methodChannel.invokeMethod("scanner#onImageDetected", arguments: ["imageName": imageKey])
        }
    }
    
    func onDetectedImageTapped(imageKey: String) {
        DispatchQueue.main.async {
            self.methodChannel.invokeMethod("scanner#onDetectedImageTapped", arguments: ["imageName": imageKey])
        }
    }
}
