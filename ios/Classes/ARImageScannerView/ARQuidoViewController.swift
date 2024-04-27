import UIKit
import ARKit
import SceneKit
import SpriteKit
import AVFoundation

class ARQuidoViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    var sceneView: ARSCNView!
    private var session: ARSession { return sceneView.session }
    private let referenceImageNames: [String]
    private let referenceVideoNames: [String]
    private let showLogo: Bool // Now a single Boolean
    private var players = [String: AVPlayer]()
    private var videoNodes = [String: SKVideoNode]()
    private var observers = [NSObjectProtocol]()
    
    init(referenceImageNames: [String], referenceVideoNames: [String], showLogo: Bool) { // Bool, not [Bool]
        self.referenceImageNames = referenceImageNames
        self.referenceVideoNames = referenceVideoNames
        self.showLogo = showLogo
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
            
            print("Preparing image with path: \(imagePath)")
            if self.referenceVideoNames.indices.contains(index) {
                let videoPath = self.referenceVideoNames[index]
                print("Associated video path: \(videoPath)")
            }
            
            referenceImages.insert(referenceImage)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let configuration = ARWorldTrackingConfiguration()
            configuration.detectionImages = referenceImages
            configuration.maximumNumberOfTrackedImages = 3
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
        let asset = AVAsset(url: videoURL)
        let player = AVPlayer(url: videoURL)
        let videoNode = SKVideoNode(avPlayer: player)

        let physicalSize = imageAnchor.referenceImage.physicalSize
        let videoSceneSize = CGSize(width: physicalSize.width * 1000, height: physicalSize.height * 1000)
        let videoScene = SKScene(size: videoSceneSize)
        videoScene.scaleMode = .aspectFit

        videoNode.position = CGPoint(x: videoSceneSize.width / 2, y: videoSceneSize.height / 2)
        videoNode.scene?.scaleMode = .resizeFill
        videoNode.size = videoSceneSize
        videoScene.addChild(videoNode)
        var isVideoPortrait = false
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) {

            DispatchQueue.main.async {
                let tracks = asset.tracks(withMediaType: .video)
                if let videoTrack = tracks.first {
                    _ = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
                    isVideoPortrait = abs(videoTrack.preferredTransform.b) == 1.0

                    let rotationAngle: CGFloat = isVideoPortrait ? .pi / 2 : 0
                    videoNode.zRotation = rotationAngle
                }
            }
        }
        if self.showLogo {
            let watermarkImage = UIImage(named: "watermark")!
            let watermarkTexture = SKTexture(image: watermarkImage)
            let watermarkNode = SKSpriteNode(texture: watermarkTexture)
            watermarkNode.size = CGSize(width: 100, height: 50)
            watermarkNode.position = CGPoint(x: 70, y: 50)
            videoScene.addChild(watermarkNode)
        }
        let videoPlane = SCNPlane(width: CGFloat(imageAnchor.referenceImage.physicalSize.width), height: CGFloat(imageAnchor.referenceImage.physicalSize.height))
        videoPlane.firstMaterial?.diffuse.contents = videoScene
        let videoPlaneNode = SCNNode(geometry: videoPlane)
        videoPlaneNode.eulerAngles.x = -.pi / 2
        videoNode.xScale = -1.0 // Adjust if the video is upside down
        videoPlaneNode.eulerAngles.y = .pi
        videoPlaneNode.opacity = 0.0 // Set initial opacity to 0.0 to start with a transparent video
        node.addChildNode(videoPlaneNode)

        player.play()

        // Fade-in animation for the video
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5 // Adjust duration as needed
        videoPlaneNode.opacity = 1.0 // Increase opacity to fade in the video
        SCNTransaction.commit()

        self.players[imageName] = player
        self.videoNodes[imageName] = videoNode
        let observer = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            player.seek(to: CMTime.zero)
            player.play()
        }
        self.observers.append(observer)
    }

    
    deinit {
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
