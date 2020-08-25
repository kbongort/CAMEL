//
//  AppDelegate.swift
//  LazyViewer
//
//  Created by Kenneth Bongort on 8/23/20.
//  Copyright © 2020 Kenneth Bongort. All rights reserved.
//

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
  var client: ClientConnection? = nil

  @IBOutlet weak var window: NSWindow!
  @IBOutlet weak var view: NSView!

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Insert code here to initialize your application

    let lightViews = addLightViews()

    group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    let channel = ClientConnection.insecure(group: group!)
      .connect(host: "localhost", port: 1427)
    let client = RPC_LightStateServiceClient(channel: channel)

    let req = RPC_LightStateStreamRequest()

    var options = CallOptions()
//    options.timeLimit = .timeout(.seconds(2))
    let call = client.lightStateStream(req, callOptions: options) { (lightState) in
      print("Receieved lightState: \(lightState)")
      DispatchQueue.main.async {

        for (i, color) in lightState.lightColors.enumerated() {
          if i < lightViews.count {
            lightViews[i].layer?.backgroundColor = CGColor(red: CGFloat(color.red) / 255.0, green: CGFloat(color.green) / 255.0, blue: CGFloat(color.blue) / 255.0, alpha: 1)
            lightViews[i].setNeedsDisplay(lightViews[i].frame)
          }
        }
      }
    }
    call.status.whenComplete { (result) in
      print("done with rpc \(result)")
    }

    DispatchQueue.global().async {
      print("Waiting for status")
      _ = try? call.status.wait()
      print("done")
    }
  }

  func addLightViews() -> [LightView] {
    var lightViews: [LightView] = []
    for (_, position) in points.sorted(by: { $0.key < $1.key }) {
      let origin = CGPoint(x: position.x * 400, y: position.y * 60)
      let lightView = LightView(frame: NSRect(x: origin.x, y: origin.y, width: 20, height: 20))
      lightView.layer?.cornerRadius = 10
      lightView.layer?.backgroundColor = .black
      view.addSubview(lightView)
      lightViews.append(lightView)
    }
    return lightViews
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    try? group?.syncShutdownGracefully()
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
