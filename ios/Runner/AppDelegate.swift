import UIKit
import Flutter
import AVFoundation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, AVAudioPlayerDelegate {
  private var player: AVAudioPlayer?
  private var queue: [URL] = []

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    UNUserNotificationCenter.current().delegate = self

    // Works on templates where the registrar is available at launch.
    // For the implicit-engine template, call setupChannel from
    // didInitializeImplicitFlutterEngine instead (see notes).
    if let registrar = self.registrar(forPlugin: "AdhanNativeBridge") {
      setupChannel(messenger: registrar.messenger())
    } else {
      NSLog("[Adhan] registrar nil at launch - channel NOT registered yet")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private var channelReady = false

  func setupChannel(messenger: FlutterBinaryMessenger) {
    if channelReady { return }
    channelReady = true
    NSLog("[Adhan] channel registered")
    let channel = FlutterMethodChannel(name: "adhan/native", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      NSLog("[Adhan] call: \(call.method)")
      switch call.method {
      case "sync":
        self.sync(call.arguments as? [String: Any] ?? [:], result: result)
      case "playNow":
        let paths = UserDefaults.standard.stringArray(forKey: "adhan_paths") ?? []
        NSLog("[Adhan] playNow with \(paths.count) paths: \(paths)")
        self.play(paths: paths)
        result(nil)
      case "stop":
        self.stopPlayback()
        result(nil)
      case "openBatterySettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Scheduling

  private func sync(_ args: [String: Any], result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ["adhan_daily"])

    let enabled = args["enabled"] as? Bool ?? false
    let paths = args["paths"] as? [String] ?? []
    UserDefaults.standard.set(paths, forKey: "adhan_paths")

    guard enabled, !paths.isEmpty else { result(nil); return }

    let hour = args["hour"] as? Int ?? 0
    let minute = args["minute"] as? Int ?? 0
    let soundName = copyToSounds(path: paths[0])

    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      guard granted else { DispatchQueue.main.async { result(nil) }; return }

      let content = UNMutableNotificationContent()
      content.title = "Adhan"
      content.body = "It's time for prayer"
      content.sound = soundName.map { UNNotificationSound(named: UNNotificationSoundName($0)) } ?? .default
      content.interruptionLevel = .timeSensitive

      var comps = DateComponents()
      comps.hour = hour
      comps.minute = minute
      let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
      center.add(UNNotificationRequest(identifier: "adhan_daily", content: content, trigger: trigger))

      let next = Calendar.current.nextDate(after: Date(), matching: comps,
                                           matchingPolicy: .nextTime)
      DispatchQueue.main.async {
        result(next.map { Int($0.timeIntervalSince1970 * 1000) })
      }
    }
  }

  /// Notification sounds must live in Library/Sounds and be <= 30s.
  private func copyToSounds(path: String) -> String? {
    let src = URL(fileURLWithPath: path)
    guard let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
    else { return nil }
    let dir = lib.appendingPathComponent("Sounds", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let dst = dir.appendingPathComponent(src.lastPathComponent)
    try? FileManager.default.removeItem(at: dst)
    do { try FileManager.default.copyItem(at: src, to: dst) } catch { return nil }
    return src.lastPathComponent
  }

  // MARK: - Playback (works in background thanks to the "audio" background mode)

  private func play(paths: [String]) {
    queue = paths.map { URL(fileURLWithPath: $0) }
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      NSLog("[Adhan] audio session error: \(error)")
    }
    playNext()
  }

  private func playNext() {
    guard !queue.isEmpty else { NSLog("[Adhan] queue finished"); stopPlayback(); return }
    let url = queue.removeFirst()
    guard FileManager.default.fileExists(atPath: url.path) else {
      NSLog("[Adhan] FILE MISSING: \(url.path)")
      playNext(); return
    }
    do {
      player = try AVAudioPlayer(contentsOf: url)
      player?.delegate = self
      player?.volume = 1.0
      if player?.play() == true {
        NSLog("[Adhan] playing \(url.lastPathComponent)")
      } else {
        NSLog("[Adhan] play() returned false for \(url.lastPathComponent)")
        playNext()
      }
    } catch {
      NSLog("[Adhan] cannot open \(url.lastPathComponent): \(error)")
      playNext()
    }
  }

  private func stopPlayback() {
    queue.removeAll()
    player?.stop()
    player = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    playNext()
  }

  // If the app is open when the alarm fires, play the full playlist ourselves.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    play(paths: UserDefaults.standard.stringArray(forKey: "adhan_paths") ?? [])
    completionHandler([.banner])  // no .sound: our player handles it
  }

  // Tapping the notification (app was in background) starts the full playlist.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    play(paths: UserDefaults.standard.stringArray(forKey: "adhan_paths") ?? [])
    completionHandler()
  }
}