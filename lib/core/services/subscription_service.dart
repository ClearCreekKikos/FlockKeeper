import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../shared/providers/providers.dart';

class SubscriptionService {
  final Ref _ref;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  static const String subscriptionId = 'com.clearcreekforge.flockkeeper.monthly';

  /// Holds the last error from product loading so the UI can display it.
  String? lastProductError;

  SubscriptionService(this._ref);

  void initialize() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        _handlePurchaseUpdates(purchaseDetailsList);
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (Object error) {
        debugPrint('⚠️ In-App Purchase Stream Error: $error');
      },
    );
  }

  void dispose() {
    _subscription?.cancel();
  }

  Future<ProductDetails?> getSubscriptionProduct() async {
    lastProductError = null;

    final bool available = await _iap.isAvailable();
    if (!available) {
      lastProductError = 'The App Store is not available. Please check your network connection and App Store settings.';
      debugPrint('⚠️ App Store is not available');
      return null;
    }

    final ProductDetailsResponse response = await _iap.queryProductDetails({subscriptionId});

    if (response.error != null) {
      lastProductError = 'App Store error: ${response.error!.message} (code: ${response.error!.code})';
      debugPrint('⚠️ App Store query error: ${response.error!.message}');
      return null;
    }

    if (response.notFoundIDs.isNotEmpty) {
      lastProductError = 'Subscription product "$subscriptionId" was not found in the App Store. '
          'This may be a configuration issue. Please contact support.';
      debugPrint('⚠️ Product not found in App Store: ${response.notFoundIDs}');
    }

    if (response.productDetails.isNotEmpty) {
      lastProductError = null; // Clear any not-found warning since we got a result
      return response.productDetails.first;
    }

    // If we reach here, no products were returned and no error was set
    lastProductError ??= 'No subscription products are currently available. Please try again later.';
    return null;
  }

  Future<bool> buySubscription(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    try {
      // In-App purchases are auto-renewable subscriptions (non-consumable)
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('⚠️ Error launching App Store checkout: $e');
      return false;
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('⚠️ Error restoring purchases: $e');
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Transaction is being processed by Apple
        debugPrint('ℹ️ Purchase is pending...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('⚠️ Purchase Error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          debugPrint('✅ Purchase status: ${purchaseDetails.status} for product ${purchaseDetails.productID}');
          
          if (purchaseDetails.productID == subscriptionId) {
            debugPrint('✅ Valid subscription verified! Marking as premium.');
            await _ref.read(settingsStateProvider.notifier).updateSetting('is_premium', 'true');
          } else {
            debugPrint('ℹ️ Unrelated product ID purchased: ${purchaseDetails.productID}. Ignoring.');
          }
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
          debugPrint('ℹ️ Completed purchase transaction.');
        }
      }
    }
  }
}

// Global Provider for the Subscription Service
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final service = SubscriptionService(ref);
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});
