import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(name: "com.soundconnect/push", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { call, result in
          if call.method == "installationId" || call.method == "nextMutation" {
            do {
              let support = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true)
              var identity = support.appendingPathComponent("soundconnect-push-installation")
              let data = try? Data(contentsOf: identity)
              let stored = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
              var id = (stored?["installationId"] as? String).flatMap(UUID.init(uuidString:))
              var revision = (stored?["clientRevision"] as? NSNumber)?.int64Value ?? -1
              if id == nil || revision < 0 || revision >= 9007199254740991 {
                id = UUID()
                revision = 0
              }
              if call.method == "nextMutation" { revision += 1 }
              let record: [String: Any] = ["installationId": id!.uuidString, "clientRevision": revision]
              try JSONSerialization.data(withJSONObject: record).write(to: identity, options: .atomic)
              var values = URLResourceValues()
              values.isExcludedFromBackup = true
              try identity.setResourceValues(values)
              if call.method == "installationId" {
                result(id!.uuidString)
              } else {
                result(record)
              }
            } catch { result(FlutterError(code: "installation_storage",
              message: "Installation identity unavailable.", details: nil)) }
          } else if call.method == "clearDelivered" {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            result(nil)
          } else { result(FlutterMethodNotImplemented) }
        }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
