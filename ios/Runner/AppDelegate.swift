import Flutter
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var promotedPurchaseIntentTask: Task<Void, Never>?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didFinishLaunching = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    // A promoted in-app purchase can launch the app directly from its App Store
    // product page. StoreKit 2 delivers that request through PurchaseIntent.
    if #available(iOS 16.4, *) {
      observePromotedPurchaseIntents()
    }

    return didFinishLaunching
  }

  @available(iOS 16.4, *)
  private func observePromotedPurchaseIntents() {
    promotedPurchaseIntentTask?.cancel()
    promotedPurchaseIntentTask = Task {
      for await intent in PurchaseIntent.intents {
        guard !Task.isCancelled else { return }

        do {
          // The Flutter in_app_purchase transaction observer receives the
          // resulting transaction and applies the user's entitlement.
          _ = try await intent.product.purchase()
        } catch {
          NSLog("CruizX: unable to complete promoted purchase: %@", error.localizedDescription)
        }
      }
    }
  }

  deinit {
    promotedPurchaseIntentTask?.cancel()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CruizXMapKitView") {
      CruizXMapKitViewPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppleMapSearchPlugin") {
      AppleMapSearchPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CruizXCarPlayBridge") {
      CarPlayManager.shared.configureFlutterBridge(with: registrar.messenger())
    }
  }
}
