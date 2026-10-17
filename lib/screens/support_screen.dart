import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import '../theme/arcade_config.dart';

/// Tip-jar support screen. Everything in the game is unlocked;
/// these are purely optional tips with fun per-game labels.
class SupportScreen extends StatefulWidget {
  final ArcadeConfig config;
  const SupportScreen({super.key, required this.config});
  @override State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String? _thanks;

  Future<void> _tip(String productId, String label) async {
    // No store on web — tips are mobile-only.
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tips are available in the mobile app!')));
      }
      return;
    }
    final available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store not available right now — try again later!')));
      }
      return;
    }
    final resp = await InAppPurchase.instance.queryProductDetails({productId});
    if (resp.productDetails.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tip jar is being set up — coming soon!')));
      }
      return;
    }
    final param = PurchaseParam(productDetails: resp.productDetails.first);
    await InAppPurchase.instance.buyConsumable(purchaseParam: param);
    if (mounted) setState(() => _thanks = 'Thanks for the $label! 💛');
  }

  @override Widget build(BuildContext context) {
    final c = widget.config;
    return Scaffold(
      backgroundColor: c.darkColor,
      appBar: AppBar(title: const Text('Support'), backgroundColor: c.primaryColor, foregroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Center(child: Text(c.playerEmoji, style: const TextStyle(fontSize: 64))),
        const SizedBox(height: 8),
        const Center(child: Text('💛 100% FREE, FOREVER',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        const Center(child: Text(
          'Every theme, shape and feature is already unlocked.\nTips are purely optional — they just make our day!',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white70))),
        const SizedBox(height: 20),
        if (_thanks != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12)),
            child: Text(_thanks!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          ),
        _tipBtn(c.tip1Label, c.tip1Id, Colors.amber.shade700),
        const SizedBox(height: 10),
        _tipBtn(c.tip2Label, c.tip2Id, Colors.white24),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.share),
          label: const Text('Share this game'),
          onPressed: () => Share.share('Check out ${c.displayName}! ${c.tagline}'),
        ),
        TextButton(
          onPressed: () {
              if (kIsWeb) return; // no store listing on web
              InAppReview.instance.openStoreListing();
            },
          child: const Text('Rate us ⭐', style: TextStyle(color: Colors.white70)),
        ),
        const SizedBox(height: 12),
        const Center(child: Text('Credits: WAJIHA', style: TextStyle(color: Colors.white38, fontSize: 12))),
      ]),
    );
  }

  Widget _tipBtn(String label, String productId, Color bg) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: bg, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      onPressed: () => _tip(productId, label),
      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ),
  );
}
