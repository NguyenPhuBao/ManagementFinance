import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Bắt buộc cho flutter_local_notifications trên iOS 10+.
    //
    // Không gán delegate thì thông báo nổ lúc app đang MỞ sẽ bị hệ thống nuốt
    // im lặng (không lỗi, không log), còn cú chạm vào thông báo lúc app đóng
    // không gọi được callback trong Dart. Trên máy thật lỗi này rất dễ chẩn
    // đoán nhầm thành "plugin hỏng".
    //
    // FlutterAppDelegate đã cài sẵn UNUserNotificationCenterDelegate, nên chỉ
    // cần trỏ delegate về self chứ không phải tự hiện thực.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
