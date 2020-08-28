import Cocoa
import NIO
import GRPC

let points: [Int:CGPoint] = [
  6:  CGPoint(x: 0,    y: 0.22),
  1:  CGPoint(x: 0,    y: 0.78),
  5:  CGPoint(x: 0.07, y: 0),
  0:  CGPoint(x: 0.07, y: 0.5),
  2:  CGPoint(x: 0.07, y: 1),
  4:  CGPoint(x: 0.14, y: 0.22),
  3:  CGPoint(x: 0.14, y: 0.78),
  10: CGPoint(x: 0.86, y: 0.22),
  11: CGPoint(x: 0.86, y: 0.78),
  9:  CGPoint(x: 0.93, y: 0),
  7:  CGPoint(x: 0.93, y: 0.5),
  12: CGPoint(x: 0.93, y: 1),
  8:  CGPoint(x: 1,    y: 0.22),
  13: CGPoint(x: 1,    y: 0.78),
]

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  var group: MultiThreadedEventLoopGroup? = nil
  var connection: ClientConnection? = nil

  @IBOutlet weak var window: NSWindow!
  @IBOutlet weak var view: NSView!
  var monitorView: MonitorView?

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Insert code here to initialize your application
    monitorView = MonitorView(frame: view.frame)
    view.addSubview(monitorView!)
    monitorView!.autoresizingMask = [.width, .height]

    group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    connect(group: group!)
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    try? group?.syncShutdownGracefully()
  }

  // MARK - RPC Client

  func connect(group: MultiThreadedEventLoopGroup) {
    let connection = ClientConnection.insecure(group: group)
      .withConnectionBackoff(fixed: .seconds(2))
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
        self.monitorView?.updateLightState(lightState)
      }
    }
    call.status.whenComplete { (result) in
      print("done with rpc \(result)")
      DispatchQueue.main.async {
        // Restart stream on disconnect.
        if let group = self.group {
          self.connect(group: group)
        }
      }
    }
  }
}

class LayerBackedView: NSView {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.wantsLayer = true
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class MonitorView: LayerBackedView {

  var lightContainer = LayerBackedView()
  var lightViews: [NSView] = []

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    self.wantsLayer = true
    self.layer?.backgroundColor = .black
    setUp()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func setUp() {
    lightContainer.frame = CGRect(origin: .zero, size: .init(width: 420, height: 80))
    lightContainer.autoresizingMask = [.maxXMargin, .maxYMargin, .minXMargin, .minYMargin]
    lightContainer.translatesAutoresizingMaskIntoConstraints = true
    addSubview(lightContainer)

    // Create & add views for each light.
    for (_, position) in points.sorted(by: { $0.key < $1.key }) {
      let origin = CGPoint(x: position.x * (lightContainer.frame.width - 20), y: position.y * (lightContainer.frame.height - 20))
      let lightView = LayerBackedView(frame: NSRect(x: origin.x, y: origin.y, width: 20, height: 20))
      lightView.layer?.cornerRadius = 10
      lightView.layer?.backgroundColor = .black
      lightViews.append(lightView)
      lightContainer.addSubview(lightView)
    }

    // Have to dispatch async to get layout to happen.
    DispatchQueue.main.async {
      self.layout()
    }
  }

  override func layout() {
    super.layout()
    lightContainer.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    lightContainer.layer?.position = CGPoint(x: frame.midX, y: frame.midY)
  }

  func updateLightState(_ lightState: RPC_LightState) {
    for (i, color) in lightState.lightColors.enumerated() {
      if i < lightViews.count {
        lightViews[i].layer?.backgroundColor = CGColor(red: CGFloat(color.red) / 255.0,
                                                       green: CGFloat(color.green) / 255.0,
                                                       blue: CGFloat(color.blue) / 255.0,
                                                       alpha: 1)
        lightViews[i].setNeedsDisplay(lightViews[i].frame)
      }
    }
  }
}
