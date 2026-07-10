import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/subscription_service.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/services/sync_service.dart';

class SubscriptionPaywallScreen extends ConsumerStatefulWidget {
  final VoidCallback? onDismiss;

  const SubscriptionPaywallScreen({super.key, this.onDismiss});

  @override
  ConsumerState<SubscriptionPaywallScreen> createState() => _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState extends ConsumerState<SubscriptionPaywallScreen> {
  bool _isLoading = false;
  ProductDetails? _subscriptionProduct;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    final isWindows = !kIsWeb && Platform.isWindows;
    if (isWindows) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final service = ref.read(subscriptionServiceProvider);
      final product = await service.getSubscriptionProduct();
      if (mounted) {
        setState(() {
          _subscriptionProduct = product;
          if (product == null) {
            _errorMessage = service.lastProductError ??
                'Premium subscription product not found. Please try again later.';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load product details: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _purchase() async {
    if (_subscriptionProduct == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ref.read(subscriptionServiceProvider).buySubscription(_subscriptionProduct!);
      if (!success && mounted) {
        setState(() {
          _errorMessage = 'Unable to launch checkout. Please check your App Store settings.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error starting purchase: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restore() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(subscriptionServiceProvider).restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase restoration request sent to App Store.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to restore: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $urlString: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);
    final isPremium = settings['is_premium'] == 'true';
    final primaryColor = Color(int.parse(settings['primary_color'] ?? '0xFF4CAF50'));
    final isWindows = !kIsWeb && Platform.isWindows;

    String storeName = 'App Store, Google Play, or Microsoft Store';
    String accountType = 'Apple ID, Google, or Microsoft account';
    if (!kIsWeb) {
      if (Platform.isIOS) {
        storeName = 'App Store';
        accountType = 'Apple ID account';
      } else if (Platform.isAndroid) {
        storeName = 'Google Play Store';
        accountType = 'Google Play account';
      } else if (Platform.isWindows) {
        storeName = 'Microsoft Store';
        accountType = 'Microsoft account';
      }
    }

    // Automatically navigate back if they successfully purchase premium
    if (isPremium && widget.onDismiss != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDismiss!();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Premium dark mode background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70, size: 28),
          onPressed: widget.onDismiss ?? () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header Brand Icon & Title
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.star, color: primaryColor, size: 60),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'FlockKeeper Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unlock the full power of your herd management',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Feature Listing
                    _buildFeatureRow(
                      Icons.settings_voice,
                      'Hands-Free Siri Voice Commands',
                      'Log kiddings, weights, and health entries in the field without touching your phone.',
                      primaryColor,
                    ),
                    _buildFeatureRow(
                      Icons.account_tree_outlined,
                      'Premium Pedigree & Ancestry Charts',
                      'Access beautiful lineage tree views to track sires, dams, and lines automatically.',
                      primaryColor,
                    ),
                    _buildFeatureRow(
                      Icons.sync,
                      'Unlimited Cloud Sync',
                      'Synchronize your ranch database seamlessly between all your iPad and iPhone devices.',
                      primaryColor,
                    ),
                    _buildFeatureRow(
                      Icons.picture_as_pdf,
                      'Registry Document Exports',
                      'Export pre-filled registration and transfer PDFs ready for submission.',
                      primaryColor,
                    ),
                    const SizedBox(height: 32),

                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Billing Panel (Fixed at Bottom)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isPremium) ...[
                    const Text(
                      '🌟 You are a Premium Member!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thank you for supporting FlockKeeper. All premium features are unlocked.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                  ] else if (_isLoading) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ] else if (isWindows) ...[
                    // Windows Info and Check Status
                    const Text(
                      'FlockKeeper Monthly Premium',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Monetization is processed via iOS (App Store) or Android (Google Play Store). Start your 30-Day Free Trial on your mobile device, then log in and sync on this Windows PC to unlock features instantly!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = '';
                        });
                        try {
                          final syncResult = await SyncService().syncNow();
                          if (syncResult == null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ranch synchronization complete! Premium settings applied.')),
                              );
                            }
                          } else {
                            if (mounted) {
                              setState(() {
                                _errorMessage = 'Sync failed: $syncResult';
                              });
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              _errorMessage = 'Sync Error: $e';
                            });
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        }
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sync),
                          SizedBox(width: 8),
                          Text(
                            'Check Premium Status (Sync Now)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    // Price tag & trial period
                    Text(
                      _subscriptionProduct != null
                          ? 'Start 30-Day Free Trial'
                          : 'FlockKeeper Monthly Premium',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subscriptionProduct != null
                          ? 'Then ${_subscriptionProduct!.price} per month. Cancel anytime.'
                          : '\$14.99/month. 30-Day Free Trial included.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _subscriptionProduct != null ? _purchase : _loadProduct,
                      child: Text(
                        _subscriptionProduct != null ? 'Start Free Trial' : 'Load Offers',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Restore Button
                  TextButton(
                    onPressed: _restore,
                    child: Text(
                      'Restore Purchases',
                      style: TextStyle(color: primaryColor, fontSize: 14),
                    ),
                  ),

                  const SizedBox(height: 12),
                  // App Store mandatory billing description disclosure
                  Text(
                    'Subscription Details: Payment will be charged to your $accountType at confirmation of purchase or at the end of your 30-day free trial. The subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period at \$14.99/mo. You can manage and cancel your subscriptions by going to your account settings on the $storeName after purchase.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Legal Links
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _openUrl('https://sites.google.com/clearcreekforge.com/clearcreekforge/privacy-policy'),
                        child: Text(
                          'Privacy Policy',
                          style: TextStyle(color: primaryColor, fontSize: 11, decoration: TextDecoration.underline),
                        ),
                      ),
                      const Text('  •  ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      GestureDetector(
                        onTap: () {
                          final eulaUrl = (!kIsWeb && Platform.isIOS)
                              ? 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'
                              : 'https://sites.google.com/clearcreekforge.com/clearcreekforge/terms';
                          _openUrl(eulaUrl);
                        },
                        child: Text(
                          'Terms of Use (EULA)',
                          style: TextStyle(color: primaryColor, fontSize: 11, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String description, Color tint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
