import Cocoa
import NIO
import GRPC

let points: [Int:CGPoint] = [
  6:  CGPoint(x: 0,    y: 0.22),
  1:  CGPoint(x: 0,    y: 0.78),
  5:  CGPoint(x: 0.08, y: 0),
  0:  CGPoint(x: 0.08, y: 0.5),
  2:  CGPoint(x: 0.08, y: 1),
  4:  CGPoint(x: 0.15, y: 0.22),
  3:  CGPoint(x: 0.15, y: 0.78),
  10: CGPoint(x: 0.85, y: 0.22),
  11: CGPoint(x: 0.85, y: 0.78),
  9:  CGPoint(x: 0.92, y: 0),
  7:  CGPoint(x: 0.92, y: 0.5),
  12: CGPoint(x: 0.92, y: 1),
  8:  CGPoint(x: 1,    y: 0.22),
  13: CGPoint(x: 1,    y: 0.78),
]

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  var group: MultiThreadedEventLoopGroup? = nil
  var connection: ClientConnection? = nil

  @IBOutlet weak var window: NSWindow!
  @IBOutlet weak var view: NSView!
  var lightViews: [LightView] = []

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Insert code here to initialize your application

    addLightViews()

    group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    connect(group: group!)
  }

  func addLightViews() {
    for (_, position) in points.sorted(by: { $0.key < $1.key }) {
      let origin = CGPoint(x: position.x * 400, y: position.y * 60)
      let lightView = LightView(frame: NSRect(x: origin.x, y: origin.y, width: 20, height: 20))
      lightView.layer?.cornerRadius = 10
      lightView.layer?.backgroundColor = .black
      view.addSubview(lightView)
      lightViews.append(lightView)
    }
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    try? group?.syncShutdownGracefully()
  }

  // MARK - RPC Client

  func connect(group: MultiThreadedEventLoopGroup) {
    let connection = ClientConnection.insecure(group: group)
      .connect(host: "localhost", port: 1427)
    self.connection = connection
    startStreaming()
  }

  func startStreaming() {
    guard let connection = connection else { return }

    let client = RPC_LightStateServiceClient(channel: connection)
    let req = RPC_LightStateStreamRequest()
    let options = CallOptions()
    let call = client.lightStateStream(req, callOptions: options) { (lightState) in
      DispatchQueue.main.async {
        self.updateLightState(lightState)
      }
    }
    call.status.whenComplete { (result) in
      print("done with rpc \(result)")
      DispatchQueue.main.async {
        // Restart stream on disconnect.
        self.startStreaming()
      }
    }
  }

  func updateLightState(_ lightState: RPC_LightState) {
    for (i, color) in lightState.lightColors.enumerated() {
      if i < lightViews.count {
        lightViews[i].layer?.backgroundColor = CGColor(red: CGFloat(color.red) / 255.0, green: CGFloat(color.green) / 255.0, blue: CGFloat(color.blue) / 255.0, alpha: 1)
        lightViews[i].setNeedsDisplay(lightViews[i].frame)
      }
    }
  }
}

class LightView: NSView {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.wantsLayer = true
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
