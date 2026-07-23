import Flutter
import StoreKit

@available(iOS 15.0, *)
private enum StoreKitSubscriptionError: Error {
  case productNotFound
  case unverified
}

@available(iOS 15.0, *)
private func verified<T>(_ result: VerificationResult<T>) throws -> T {
  switch result {
  case .verified(let value):
    return value
  case .unverified:
    throw StoreKitSubscriptionError.unverified
  }
}

final class StoreKitSubscriptionPlugin: NSObject, FlutterPlugin {
  private static let productIds = [
    "god_morning_monthly",
    "god_morning_annual",
  ]

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "god_morning/storekit",
      binaryMessenger: registrar.messenger()
    )
    let instance = StoreKitSubscriptionPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      if #available(iOS 15.0, *) {
        result(true)
      } else {
        result(false)
      }

    case "products":
      guard #available(iOS 15.0, *) else {
        result([])
        return
      }
      Task {
        do {
          let products = try await Self.loadProducts()
          let payload = products.map(Self.productPayload)
          await MainActor.run { result(payload) }
        } catch {
          await MainActor.run {
            result(FlutterError(
              code: "products_failed",
              message: error.localizedDescription,
              details: nil
            ))
          }
        }
      }

    case "purchase":
      guard #available(iOS 15.0, *) else {
        result(["status": "unavailable"])
        return
      }
      guard let args = call.arguments as? [String: Any],
            let productId = args["productId"] as? String else {
        result(FlutterError(code: "bad_args", message: "productId required", details: nil))
        return
      }
      Task {
        do {
          let status = try await Self.purchase(productId: productId)
          await MainActor.run { result(["status": status]) }
        } catch {
          await MainActor.run {
            result(FlutterError(
              code: "purchase_failed",
              message: error.localizedDescription,
              details: nil
            ))
          }
        }
      }

    case "restore":
      guard #available(iOS 15.0, *) else {
        result(false)
        return
      }
      Task {
        do {
          try await AppStore.sync()
          let active = await Self.hasActiveSubscription()
          await MainActor.run { result(active) }
        } catch {
          await MainActor.run {
            result(FlutterError(
              code: "restore_failed",
              message: error.localizedDescription,
              details: nil
            ))
          }
        }
      }

    case "hasActiveSubscription":
      guard #available(iOS 15.0, *) else {
        result(false)
        return
      }
      Task {
        let active = await Self.hasActiveSubscription()
        await MainActor.run { result(active) }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 15.0, *)
  private static func loadProducts() async throws -> [Product] {
    let products = try await Product.products(for: productIds)
    return products.sorted { lhs, rhs in
      if lhs.id == "god_morning_annual" { return true }
      if rhs.id == "god_morning_annual" { return false }
      return lhs.displayPrice < rhs.displayPrice
    }
  }

  @available(iOS 15.0, *)
  private static func productPayload(_ product: Product) -> [String: Any] {
    [
      "id": product.id,
      "displayName": product.displayName,
      "description": product.description,
      "displayPrice": product.displayPrice,
    ]
  }

  @available(iOS 15.0, *)
  private static func purchase(productId: String) async throws -> String {
    let products = try await loadProducts()
    guard let product = products.first(where: { $0.id == productId }) else {
      throw StoreKitSubscriptionError.productNotFound
    }

    let result = try await product.purchase()
    switch result {
    case .success(let verification):
      let transaction = try verified(verification)
      await transaction.finish()
      return "success"
    case .userCancelled:
      return "cancelled"
    case .pending:
      return "pending"
    @unknown default:
      return "unknown"
    }
  }

  @available(iOS 15.0, *)
  private static func hasActiveSubscription() async -> Bool {
    for await entitlement in Transaction.currentEntitlements {
      guard let transaction = try? verified(entitlement),
            productIds.contains(transaction.productID),
            transaction.revocationDate == nil else {
        continue
      }

      if let expirationDate = transaction.expirationDate {
        if expirationDate > Date() { return true }
      } else {
        return true
      }
    }
    return false
  }
}
