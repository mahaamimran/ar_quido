import UIKit
import ARKit
import SceneKit

class ARQuidoViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    var sceneView: ARSCNView!
    private var session: ARSession { return sceneView.session }
    private let referenceImageNames: [String]
    private let referenceVideoNames: [String]
    private var players = [String: AVPlayer]()
    private var videoNodes = [String: SKVideoNode]()
    private var observers = [NSObjectProtocol]()

    init(referenceImageNames: [String], referenceVideoNames: [String]) {
        self.referenceImageNames = referenceImageNames
        self.referenceVideoNames = referenceVideoNames
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sceneView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        resetTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.pause()
    }
    
    func resetTracking() {
        var referenceImages = Set<ARReferenceImage>()
        for (index, imagePath) in self.referenceImageNames.enumerated() {
            guard let image = UIImage(contentsOfFile: imagePath),
                  let cgImage = image.cgImage else {
                print("Warning: Could not create UIImage or cgImage for imagePath: \(imagePath)")
                continue
            }

            let physicalSize: CGFloat = 0.5 // Adjust based on your actual image size in meters
            let referenceImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: physicalSize)
            referenceImage.name = URL(fileURLWithPath: imagePath).lastPathComponent

            // Print the full image path
            print("Preparing image with path: \(imagePath)")

            // If your videos are directly associated with images by index
            if self.referenceVideoNames.indices.contains(index) {
                let videoPath = self.referenceVideoNames[index]
                // Print the current video path
                print("Associated video path: \(videoPath)")
            }

            referenceImages.insert(referenceImage)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let configuration = ARWorldTrackingConfiguration()
            configuration.detectionImages = referenceImages
            configuration.maximumNumberOfTrackedImages = 5 // Adjust based on your requirements
            self.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor,
              let imageName = imageAnchor.referenceImage.name,
              let videoPathIndex = self.referenceImageNames.firstIndex(where: { URL(fileURLWithPath: $0).lastPathComponent == imageName }),
              self.referenceVideoNames.indices.contains(videoPathIndex) else { return }
        
        let videoPath = self.referenceVideoNames[videoPathIndex]
        let videoURL = URL(fileURLWithPath: videoPath)
        let player = AVPlayer(url: videoURL)
        let videoNode = SKVideoNode(avPlayer: player)

        player.play()
        let videoScene = SKScene(size: CGSize(width: 720, height: 1280))
        videoNode.position = CGPoint(x: videoScene.size.width / 2, y: videoScene.size.height / 2)
        videoNode.yScale = -1.0 // Invert video playback
        videoScene.addChild(videoNode)

        let videoPlane = SCNPlane(width: imageAnchor.referenceImage.physicalSize.width, height: imageAnchor.referenceImage.physicalSize.height)
        videoPlane.firstMaterial?.diffuse.contents = videoScene
        let videoPlaneNode = SCNNode(geometry: videoPlane)
        videoPlaneNode.eulerAngles.x = -.pi / 2
        node.addChildNode(videoPlaneNode)

        // Keep references for cleanup
        players[imageName] = player
        videoNodes[imageName] = videoNode
        let observer = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            player.seek(to: CMTime.zero)
            player.play()
        }
        observers.append(observer)
    }
    
    deinit {
        // Cleanup
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        for player in players.values {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        videoNodes.forEach { $1.removeFromParent() }
    }
}
