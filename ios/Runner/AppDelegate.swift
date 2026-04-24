import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var logBridge: Any?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    #if DEBUG
    if let controller = window?.rootViewController as? FlutterViewController {
      logBridge = LogBridge(messenger: controller.binaryMessenger)
    }
    #endif

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}