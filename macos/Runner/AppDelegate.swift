import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var activeSecurityScopedURLs: [String: URL] = [:]

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "arcane_forge/workspace_access",
        binaryMessenger: controller.engine.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handleWorkspaceAccess(call: call, result: result)
      }
    }
    super.applicationDidFinishLaunching(notification)
  }

  private func handleWorkspaceAccess(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "createBookmark":
      guard let path = args["path"] as? String, !path.isEmpty else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing path.", details: nil))
        return
      }
      createBookmark(forPath: path, result: result)
    case "resolveBookmark":
      guard let bookmark = args["bookmark"] as? String, !bookmark.isEmpty else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing bookmark.", details: nil))
        return
      }
      resolveBookmark(bookmark, result: result)
    case "stopBookmark":
      guard let bookmark = args["bookmark"] as? String, !bookmark.isEmpty else {
        result(nil)
        return
      }
      stopBookmark(bookmark)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func createBookmark(forPath path: String, result: @escaping FlutterResult) {
    let url = URL(fileURLWithPath: path)
    do {
      let bookmarkData = try url.bookmarkData(
        options: [.withSecurityScope],
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      result(bookmarkData.base64EncodedString())
    } catch {
      result(
        FlutterError(
          code: "BOOKMARK_CREATE_FAILED",
          message: "Unable to create security-scoped bookmark.",
          details: error.localizedDescription
        )
      )
    }
  }

  private func resolveBookmark(_ bookmark: String, result: @escaping FlutterResult) {
    if let existingURL = activeSecurityScopedURLs[bookmark] {
      result(existingURL.path)
      return
    }

    guard let bookmarkData = Data(base64Encoded: bookmark) else {
      result(
        FlutterError(
          code: "BOOKMARK_INVALID",
          message: "Bookmark is not valid base64.",
          details: nil
        )
      )
      return
    }

    var isStale = false
    do {
      let url = try URL(
        resolvingBookmarkData: bookmarkData,
        options: [.withSecurityScope],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )

      let accessGranted = url.startAccessingSecurityScopedResource()
      if !accessGranted {
        result(
          FlutterError(
            code: "BOOKMARK_ACCESS_DENIED",
            message: "Unable to access security-scoped bookmark.",
            details: nil
          )
        )
        return
      }

      activeSecurityScopedURLs[bookmark] = url
      result(url.path)
    } catch {
      result(
        FlutterError(
          code: "BOOKMARK_RESOLVE_FAILED",
          message: "Unable to resolve security-scoped bookmark.",
          details: error.localizedDescription
        )
      )
    }
  }

  private func stopBookmark(_ bookmark: String) {
    guard let url = activeSecurityScopedURLs.removeValue(forKey: bookmark) else {
      return
    }
    url.stopAccessingSecurityScopedResource()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
