import UIKit
import Flutter
import FirebaseCore   // ✅ import Firebase

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()   // ✅ initialize Firebase
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
