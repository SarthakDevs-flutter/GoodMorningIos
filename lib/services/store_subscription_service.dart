import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class StoreSubscriptionProduct {
  const StoreSubscriptionProduct({
    required this.id,
    required this.displayName,
    required this.description,
    required this.displayPrice,
  });

  final String id;
  final String displayName;
  final String description;
  final String displayPrice;

  bool get isAnnual => id == StoreSubscriptionService.annualProductId;
  bool get isMonthly => id == StoreSubscriptionService.monthlyProductId;

  static StoreSubscriptionProduct? fromMap(Object? raw) {
    if (raw is! Map) return null;
    return StoreSubscriptionProduct(
      id: raw['id']?.toString() ?? '',
      displayName: raw['displayName']?.toString() ?? '',
      description: raw['description']?.toString() ?? '',
      displayPrice: raw['displayPrice']?.toString() ?? '',
    );
  }
}

enum StorePurchaseStatus {
  success,
  pending,
  cancelled,
  unavailable,
  failed,
  unknown,
}

class StoreSubscriptionService {
  StoreSubscriptionService._();

  static const monthlyProductId = 'god_morning_monthly';
  static const annualProductId = 'god_morning_annual';
  static const _productIds = <String>{monthlyProductId, annualProductId};

  static const _channel = MethodChannel('god_morning/storekit');
  static final InAppPurchase _googlePlayBilling = InAppPurchase.instance;

  static bool get _ios =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> isAvailable() async {
    if (_android) {
      try {
        return _googlePlayBilling.isAvailable();
      } catch (error) {
        debugPrint('Google Play Billing isAvailable failed: $error');
        return false;
      }
    }

    if (!_ios) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException catch (error) {
      debugPrint('StoreKit isAvailable failed: $error');
      return false;
    }
  }

  static Future<List<StoreSubscriptionProduct>> products() async {
    if (_android) return _googlePlayProducts();
    if (!await isAvailable()) return const [];
    try {
      final raw = await _channel.invokeMethod<Object?>('products');
      if (raw is! List) return const [];
      final products = raw
          .map(StoreSubscriptionProduct.fromMap)
          .whereType<StoreSubscriptionProduct>()
          .where((product) => product.id.isNotEmpty)
          .toList();
      products.sort((a, b) {
        if (a.isAnnual) return -1;
        if (b.isAnnual) return 1;
        return a.id.compareTo(b.id);
      });
      return products;
    } on PlatformException catch (error) {
      debugPrint('StoreKit products failed: $error');
      return const [];
    }
  }

  static Future<StorePurchaseStatus> purchase(String productId) async {
    if (_android) return _purchaseGooglePlay(productId);
    if (!await isAvailable()) return StorePurchaseStatus.unavailable;
    try {
      final raw = await _channel.invokeMethod<Object?>('purchase', {
        'productId': productId,
      });
      final status = raw is Map ? raw['status']?.toString() : raw?.toString();
      return switch (status) {
        'success' => StorePurchaseStatus.success,
        'pending' => StorePurchaseStatus.pending,
        'cancelled' => StorePurchaseStatus.cancelled,
        'unavailable' => StorePurchaseStatus.unavailable,
        'unknown' => StorePurchaseStatus.unknown,
        _ => StorePurchaseStatus.failed,
      };
    } on PlatformException catch (error) {
      debugPrint('StoreKit purchase failed: $error');
      return StorePurchaseStatus.failed;
    }
  }

  static Future<bool> restore() async {
    if (_android) return _restoreGooglePlay();
    if (!await isAvailable()) return false;
    try {
      return await _channel.invokeMethod<bool>('restore') ?? false;
    } on PlatformException catch (error) {
      debugPrint('StoreKit restore failed: $error');
      return false;
    }
  }

  static Future<bool> hasActiveSubscription() async {
    if (_android) return _restoreGooglePlay();
    if (!await isAvailable()) return false;
    try {
      return await _channel.invokeMethod<bool>('hasActiveSubscription') ??
          false;
    } on PlatformException catch (error) {
      debugPrint('StoreKit hasActiveSubscription failed: $error');
      return false;
    }
  }

  static Future<List<StoreSubscriptionProduct>> _googlePlayProducts() async {
    if (!await isAvailable()) return const [];
    try {
      final response = await _googlePlayBilling.queryProductDetails(
        _productIds,
      );
      if (response.error != null) {
        debugPrint('Google Play products failed: ${response.error}');
      }
      final products = response.productDetails
          .map(
            (product) => StoreSubscriptionProduct(
              id: product.id,
              displayName: product.title,
              description: product.description,
              displayPrice: product.price,
            ),
          )
          .toList();
      products.sort((a, b) {
        if (a.isAnnual) return -1;
        if (b.isAnnual) return 1;
        return a.id.compareTo(b.id);
      });
      return products;
    } catch (error) {
      debugPrint('Google Play products failed: $error');
      return const [];
    }
  }

  static Future<StorePurchaseStatus> _purchaseGooglePlay(
    String productId,
  ) async {
    if (!await isAvailable()) return StorePurchaseStatus.unavailable;
    try {
      final response = await _googlePlayBilling.queryProductDetails({
        productId,
      });
      if (response.error != null) {
        debugPrint('Google Play product lookup failed: ${response.error}');
        return StorePurchaseStatus.failed;
      }
      ProductDetails? product;
      for (final details in response.productDetails) {
        if (details.id == productId) {
          product = details;
          break;
        }
      }
      if (product == null) return StorePurchaseStatus.unavailable;

      final completer = Completer<StorePurchaseStatus>();
      late final StreamSubscription<List<PurchaseDetails>> subscription;

      Future<void> finish(StorePurchaseStatus status) async {
        if (!completer.isCompleted) completer.complete(status);
        await subscription.cancel();
      }

      subscription = _googlePlayBilling.purchaseStream.listen(
        (purchases) {
          for (final purchase in purchases) {
            if (purchase.productID != productId) continue;
            unawaited(_completeIfNeeded(purchase));
            unawaited(finish(_purchaseStatus(purchase)));
            break;
          }
        },
        onError: (Object error) {
          debugPrint('Google Play purchase stream failed: $error');
          unawaited(finish(StorePurchaseStatus.failed));
        },
      );

      final launched = await _googlePlayBilling.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!launched) await finish(StorePurchaseStatus.failed);

      return completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          unawaited(subscription.cancel());
          return StorePurchaseStatus.unknown;
        },
      );
    } catch (error) {
      debugPrint('Google Play purchase failed: $error');
      return StorePurchaseStatus.failed;
    }
  }

  static Future<bool> _restoreGooglePlay() async {
    if (!await isAvailable()) return false;
    try {
      final completer = Completer<bool>();
      late final StreamSubscription<List<PurchaseDetails>> subscription;

      Future<void> finish(bool restored) async {
        if (!completer.isCompleted) completer.complete(restored);
        await subscription.cancel();
      }

      subscription = _googlePlayBilling.purchaseStream.listen(
        (purchases) {
          for (final purchase in purchases) {
            if (!_productIds.contains(purchase.productID)) continue;
            if (purchase.status == PurchaseStatus.purchased ||
                purchase.status == PurchaseStatus.restored) {
              unawaited(_completeIfNeeded(purchase));
              unawaited(finish(true));
              return;
            }
          }
        },
        onError: (Object error) {
          debugPrint('Google Play restore stream failed: $error');
          unawaited(finish(false));
        },
      );

      await _googlePlayBilling.restorePurchases();
      return completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          unawaited(subscription.cancel());
          return false;
        },
      );
    } catch (error) {
      debugPrint('Google Play restore failed: $error');
      return false;
    }
  }

  static StorePurchaseStatus _purchaseStatus(PurchaseDetails purchase) {
    return switch (purchase.status) {
      PurchaseStatus.pending => StorePurchaseStatus.pending,
      PurchaseStatus.purchased => StorePurchaseStatus.success,
      PurchaseStatus.restored => StorePurchaseStatus.success,
      PurchaseStatus.canceled => StorePurchaseStatus.cancelled,
      PurchaseStatus.error => StorePurchaseStatus.failed,
    };
  }

  static Future<void> _completeIfNeeded(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    if (purchase.status != PurchaseStatus.purchased &&
        purchase.status != PurchaseStatus.restored) {
      return;
    }
    try {
      await _googlePlayBilling.completePurchase(purchase);
    } catch (error) {
      debugPrint('Google Play completePurchase failed: $error');
    }
  }
}
