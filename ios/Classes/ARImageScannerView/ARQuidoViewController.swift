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
    private let showLogo: Bool
    private var players = [String: AVPlayer]()
    private var videoNodes = [String: SKVideoNode]()
    private var observers = [NSObjectProtocol]()
    
    init(referenceImageNames: [String], referenceVideoNames: [String], showLogo: Bool) {
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
        
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right")?.withTintColor(.white, renderingMode: .alwaysOriginal), for: .normal)
        button.backgroundColor = .black
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 20),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            button.widthAnchor.constraint(equalTo: button.heightAnchor),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
        button.addTarget(self, action: #selector(buttonClicked), for: .touchUpInside)
    }

    @objc func buttonClicked() {
        print("Button clicked")
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
        for (index, imagePath) in referenceImageNames.enumerated() {
            guard let image = UIImage(contentsOfFile: imagePath),
                  let cgImage = image.cgImage else { continue }
            
            let referenceImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: 0.5)
            referenceImage.name = URL(fileURLWithPath: imagePath).lastPathComponent
            referenceImages.insert(referenceImage)
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionImages = referenceImages
        configuration.maximumNumberOfTrackedImages = 3
        DispatchQueue.main.async {
            self.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor,
              let imageName = imageAnchor.referenceImage.name,
              let videoPathIndex = referenceImageNames.firstIndex(where: { URL(fileURLWithPath: $0).lastPathComponent == imageName }),
              referenceVideoNames.indices.contains(videoPathIndex) else { return }

        let videoURL = URL(fileURLWithPath: referenceVideoNames[videoPathIndex])
        let player = AVPlayer(url: videoURL)
        let videoNode = SKVideoNode(avPlayer: player)
        let videoScene = SKScene(size: CGSize(width: imageAnchor.referenceImage.physicalSize.width * 1000, height: imageAnchor.referenceImage.physicalSize.height * 1000))
        videoScene.scaleMode = .resizeFill

        videoNode.position = CGPoint(x: videoScene.size.width / 2, y: videoScene.size.height / 2)
        videoNode.size = videoScene.size
        videoScene.addChild(videoNode)

        let asset = AVAsset(url: videoURL)
        let tracks = asset.tracks(withMediaType: .video)
        if let track = tracks.first {
            let t = track.preferredTransform
            let videoSize = track.naturalSize
            let videoAspectRatio = videoSize.width / videoSize.height
            let anchorAspectRatio = videoScene.size.width / videoScene.size.height
            
            DispatchQueue.main.async {
                // Size adjustment based on aspect ratio
                print("Video Aspect Ratio: \(videoAspectRatio), Anchor Aspect Ratio: \(anchorAspectRatio)")
                if videoAspectRatio > anchorAspectRatio {
                    videoNode.size.height = videoScene.size.height
                    videoNode.size.width = videoScene.size.height * videoAspectRatio
                    videoNode.xScale = -1  // Flipping horizontally if needed
                } else {
                    videoNode.size.width = videoScene.size.width
                    videoNode.size.height = videoScene.size.width / videoAspectRatio
                }
                print("Adjusted video size: width = \(videoNode.size.width), height = \(videoNode.size.height)")
                
                // Orientation and rotation adjustments based on transform matrix
                print("Transform matrix: a = \(t.a), b = \(t.b), c = \(t.c), d = \(t.d)")
                if t.a == 1.0 && t.b == 0.0 && t.c == 0.0 && t.d == 1.0 {
                    // Normal landscape orientation
                    // of image height is more than width
                    if imageAnchor.height > imageAnchor.width {
                        videoNode.zRotation = CGFloat.pi // changed
                        print("Rotated 90 degrees clockwise (portrait)") // correct
                    } else {
                        videoNode.zRotation = 0
                        print("Normal landscape orientation")
                    }
                   
                    print("Normal landscape orientation")
                } else if t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0 {
                    // Rotated 90 degrees clockwise (portrait)
                    videoNode.zRotation = -CGFloat.pi / 2
                    print("Rotated 90 degrees clockwise (portrait)") // correct
                } else if t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0 {
                    // Rotated 180 degrees
                    videoNode.zRotation = 0 // changed
                    print("Rotated 180 degrees")
                } else if t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0 {
                    // Rotated 90 degrees counterclockwise (portrait)
                    videoNode.zRotation = CGFloat.pi / 2
                    print("Rotated 90 degrees counterclockwise (portrait)")
                } else {
                    // Default case to handle unexpected orientations
                    videoNode.zRotation = 0
                    print("Default orientation applied")
                }
                
                // Debug final settings
                print("Final videoNode size: \(videoNode.size), zRotation: \(videoNode.zRotation)")
            }
        }


        let videoPlane = SCNPlane(width: imageAnchor.referenceImage.physicalSize.width, height: imageAnchor.referenceImage.physicalSize.height)
        videoPlane.firstMaterial?.diffuse.contents = videoScene
        let videoPlaneNode = SCNNode(geometry: videoPlane)
        videoPlaneNode.eulerAngles.x = -.pi / 2
        node.addChildNode(videoPlaneNode)

        player.play()
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        videoPlaneNode.opacity = 1.0
        SCNTransaction.commit()

        players[imageName] = player
        videoNodes[imageName] = videoNode
        let observer = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) {
            [weak self] _ in
            player.seek(to: CMTime.zero)
            player.play()
        }
        observers.append(observer)
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
