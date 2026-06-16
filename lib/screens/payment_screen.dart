import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

enum _Method { mobileMoney, card }

class PaymentScreen extends StatefulWidget {
  final String venueId;
  final String venueName;

  const PaymentScreen({
    super.key,
    required this.venueId,
    required this.venueName,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  List<PaymentPlan> _plans = [];
  String? _selectedPlanId;
  String? _currentTier;

  bool _loading = true;
  int _step = 0; // 0=plans, 1=method+phone, 2=processing, 3=success, 4=failure

  _Method _method = _Method.mobileMoney;
  final _phoneCtrl = TextEditingController();
  String? _reference;     // idempotency UUID – persisted in prefs to survive restarts
  String? _redirectUrl;
  String? _errorMsg;

  Timer? _pollTimer;
  int _pollCount = 0;
  static const int _maxPolls = 100; // 5 min at 3s intervals

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final plans = await ApiService().fetchPlans();
      final sub   = await ApiService().subscriptionStatus(widget.venueId);
      if (!mounted) return;
      setState(() {
        _plans       = plans.isEmpty ? PaymentPlan.defaults : plans;
        _currentTier = (sub['data'] as Map?)? ['tier'] as String?
                       ?? sub['tier'] as String?;
        _loading     = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _plans   = PaymentPlan.defaults;
        _loading = false;
      });
    }
  }

  Future<String> _getOrCreateReference() async {
    final prefs = await SharedPreferences.getInstance();
    final key   = 'pay_ref_${widget.venueId}_$_selectedPlanId';
    String? ref = prefs.getString(key);
    if (ref == null) {
      ref = const Uuid().v4();
      await prefs.setString(key, ref);
    }
    return ref;
  }

  Future<void> _clearReference() async {
    final prefs = await SharedPreferences.getInstance();
    final key   = 'pay_ref_${widget.venueId}_$_selectedPlanId';
    await prefs.remove(key);
  }

  Future<void> _proceed() async {
    if (_selectedPlanId == null) return;

    final plan = _plans.firstWhere((p) => p.id == _selectedPlanId);

    // Free plan — go straight to step 1 → confirm
    if (plan.priceUgx == 0) {
      await _initiatePayment(plan);
      return;
    }

    setState(() => _step = 1);
  }

  Future<void> _initiatePayment(PaymentPlan plan) async {
    if (!context.read<AuthProvider>().isAuthenticated) return;

    setState(() {
      _step     = 2;
      _errorMsg = null;
      _pollCount = 0;
    });

    try {
      _reference = await _getOrCreateReference();

      final result = await ApiService().initiatePayment(
        venueId:     widget.venueId,
        planId:      plan.id,
        method:      _method == _Method.card ? 'card' : 'mobile_money',
        reference:   _reference!,
        phoneNumber: _method == _Method.mobileMoney ? _phoneCtrl.text.trim() : null,
      );

      final status = result['status'] as String? ?? 'pending';

      if (status == 'completed') {
        await _clearReference();
        if (mounted) setState(() => _step = 3);
        return;
      }

      _redirectUrl = result['redirectUrl'] as String?;

      if (_method == _Method.card && _redirectUrl != null) {
          await launchUrl(
          Uri.parse(_redirectUrl!),
          mode: LaunchMode.externalApplication,
        );
        if (mounted) {
          setState(() {}); // stays on step 2 with a "Check Payment" button visible
        }
      }

      _startPolling();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _step     = 4;
          _errorMsg = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _step     = 4;
          _errorMsg = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_reference == null) return;
      _pollCount++;
      if (_pollCount > _maxPolls) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() {
            _step     = 4;
            _errorMsg = 'Payment is taking too long. If you completed the payment, check back later in your venue dashboard.';
          });
        }
        return;
      }
      try {
        final status = await ApiService().checkPaymentStatus(_reference!);
        if (!mounted) return;
        if (status == 'completed') {
          _pollTimer?.cancel();
          await _clearReference();
          setState(() => _step = 3);
        } else if (status == 'failed') {
          _pollTimer?.cancel();
          setState(() {
            _step     = 4;
            _errorMsg = 'Payment was declined or failed. Please try again.';
          });
        }
      } catch (_) {
        // ignore network blips during polling
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _step < 3
          ? AppBar(
              backgroundColor: AppTheme.surfaceColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppTheme.onSurfaceColor),
                onPressed: () {
                  if (_step == 1) {
                    setState(() => _step = 0);
                  } else if (_step == 0 || _step == 4) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              title: Text(
                _step == 0
                    ? 'Upgrade Plan'
                    : _step == 1
                        ? 'Payment Method'
                        : 'Processing…',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurfaceColor),
              ),
              centerTitle: true,
            )
          : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : switch (_step) {
              0 => _PlanStep(
                    plans: _plans,
                    selectedId: _selectedPlanId,
                    currentTier: _currentTier,
                    venueName: widget.venueName,
                    onSelect: (id) => setState(() => _selectedPlanId = id),
                    onProceed: _proceed,
                  ),
              1 => _MethodStep(
                    plan: _plans.firstWhere((p) => p.id == _selectedPlanId),
                    method: _method,
                    phoneCtrl: _phoneCtrl,
                    onMethodChange: (m) => setState(() => _method = m),
                    onPay: () => _initiatePayment(
                        _plans.firstWhere((p) => p.id == _selectedPlanId)),
                  ),
              2 => _ProcessingStep(
                    method: _method,
                    redirectUrl: _redirectUrl,
                    onCheckNow: _startPolling,
                    onOpenBrowser: _redirectUrl == null
                        ? null
                        : () => launchUrl(Uri.parse(_redirectUrl!),
                              mode: LaunchMode.externalApplication),
                  ),
              3 => _SuccessStep(
                    planName: _selectedPlanId != null
                        ? _plans
                            .firstWhere((p) => p.id == _selectedPlanId,
                                orElse: () => _plans.first)
                            .name
                        : 'Plan',
                    onDone: () => Navigator.of(context).pop(true),
                  ),
              4 => _FailureStep(
                    message: _errorMsg ?? 'Payment failed.',
                    onRetry: () {
                      _pollTimer?.cancel();
                      setState(() {
                        _step     = _method == _Method.card ? 0 : 1;
                        _errorMsg = null;
                      });
                    },
                    onCancel: () => Navigator.of(context).pop(false),
                  ),
              _ => const SizedBox.shrink(),
            },
    );
  }
}

class _PlanStep extends StatelessWidget {
  final List<PaymentPlan> plans;
  final String? selectedId;
  final String? currentTier;
  final String venueName;
  final ValueChanged<String> onSelect;
  final VoidCallback onProceed;

  const _PlanStep({
    required this.plans,
    required this.selectedId,
    required this.currentTier,
    required this.venueName,
    required this.onSelect,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _VenueHeader(name: venueName, tier: currentTier),
                const SizedBox(height: 24),
                const Text('Choose a plan',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurfaceColor)),
                const SizedBox(height: 14),
                ...plans.map((p) => _PlanCard(
                      plan: p,
                      selected: selectedId == p.id,
                      isCurrent: currentTier == p.tier,
                      onTap: () => onSelect(p.id),
                    )),
                const SizedBox(height: 12),
                const _SecurityNote(),
              ],
            ),
          ),
        ),
        _BottomBar(
          label: selectedId == null ? 'Select a plan' : 'Continue',
          enabled: selectedId != null,
          onTap: onProceed,
        ),
      ],
    );
  }
}

class _MethodStep extends StatelessWidget {
  final PaymentPlan plan;
  final _Method method;
  final TextEditingController phoneCtrl;
  final ValueChanged<_Method> onMethodChange;
  final VoidCallback onPay;

  const _MethodStep({
    required this.plan,
    required this.method,
    required this.phoneCtrl,
    required this.onMethodChange,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(plan.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppTheme.onSurfaceColor)),
                            Text('${plan.billingCycle} billing',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.mutedColor)),
                          ],
                        ),
                      ),
                      Text(
                        plan.priceUgx == 0
                            ? 'Free'
                            : 'UGX ${_fmt(plan.priceUgx)}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text('Payment Method',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurfaceColor)),
                const SizedBox(height: 12),

                _MethodTile(
                  icon: Icons.phone_android_rounded,
                  title: 'Mobile Money',
                  subtitle: 'MTN MoMo · Airtel Money',
                  selected: method == _Method.mobileMoney,
                  onTap: () => onMethodChange(_Method.mobileMoney),
                ),
                const SizedBox(height: 10),
                _MethodTile(
                  icon: Icons.credit_card_rounded,
                  title: 'Debit / Credit Card',
                  subtitle: 'Opens secure card gateway',
                  selected: method == _Method.card,
                  onTap: () => onMethodChange(_Method.card),
                ),

                if (method == _Method.mobileMoney) ...[
                  const SizedBox(height: 20),
                  const Text('Phone Number',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurfaceColor)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                        color: AppTheme.onSurfaceColor, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: '+256 7XX XXX XXX',
                      hintStyle: const TextStyle(color: AppTheme.mutedColor),
                      prefixIcon: const Icon(Icons.phone_rounded,
                          size: 20, color: AppTheme.mutedColor),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You will receive a USSD prompt to approve the payment.',
                    style: TextStyle(fontSize: 12, color: AppTheme.mutedColor),
                  ),
                ],

                if (method == _Method.card) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.accentColor.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.open_in_browser_rounded,
                            size: 18, color: AppTheme.accentColor),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You\'ll be taken to MarzPay\'s secure card gateway to complete payment, then returned here.',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.mutedColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        _BottomBar(
          label: method == _Method.card ? 'Pay with Card' : 'Pay with Mobile Money',
          enabled: true,
          onTap: onPay,
          icon: method == _Method.card
              ? Icons.credit_card_rounded
              : Icons.phone_android_rounded,
        ),
      ],
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _ProcessingStep extends StatelessWidget {
  final _Method method;
  final String? redirectUrl;
  final VoidCallback onCheckNow;
  final VoidCallback? onOpenBrowser;

  const _ProcessingStep({
    required this.method,
    required this.redirectUrl,
    required this.onCheckNow,
    required this.onOpenBrowser,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              method == _Method.mobileMoney
                  ? 'Waiting for approval…'
                  : 'Complete payment in browser',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurfaceColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              method == _Method.mobileMoney
                  ? 'Check your phone for a USSD prompt and approve the payment. This screen will update automatically.'
                  : 'After completing payment in your browser, tap "Check Payment" to confirm.',
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.mutedColor, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (method == _Method.card && onOpenBrowser != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenBrowser,
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('Open Payment Page'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (method == _Method.card) const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onCheckNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Check Payment',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessStep extends StatelessWidget {
  final String planName;
  final VoidCallback onDone;

  const _SuccessStep({required this.planName, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1A4A2E),
              ),
              child: const Icon(Icons.check_rounded,
                  size: 44, color: Color(0xFF68D391)),
            ),
            const SizedBox(height: 24),
            const Text('Payment Successful!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurfaceColor)),
            const SizedBox(height: 10),
            Text(
              'Your venue is now on the $planName plan. Enjoy your upgraded features!',
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.mutedColor, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back to Dashboard',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureStep extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _FailureStep({
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 44, color: Colors.redAccent),
            ),
            const SizedBox(height: 24),
            const Text('Payment Failed',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurfaceColor)),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.mutedColor, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Try Again',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.mutedColor,
                  side: const BorderSide(color: AppTheme.borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueHeader extends StatelessWidget {
  final String name;
  final String? tier;
  const _VenueHeader({required this.name, required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          const Text('🏟️', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(name,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
              textAlign: TextAlign.center),
          if (tier != null) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Current: ${tier!.toUpperCase()}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryColor.withValues(alpha: 0.15)
                    : AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 22,
                  color: selected
                      ? AppTheme.primaryColor
                      : AppTheme.mutedColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: selected
                              ? AppTheme.primaryColor
                              : AppTheme.onSurfaceColor)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.mutedColor)),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppTheme.primaryColor : AppTheme.mutedColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;

  const _BottomBar({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: enabled ? AppTheme.primaryColor : const Color(0xFF2a2a2a),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18,
                      color: enabled ? Colors.white : AppTheme.mutedColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: enabled ? Colors.white : AppTheme.mutedColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PaymentPlan plan;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPremium = plan.tier == 'premium';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? (isPremium
                  ? AppTheme.primaryColor
                  : AppTheme.accentColor.withValues(alpha: 0.25))
              : AppTheme.surfaceColor,
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.06),
            width: 1.5,
          ),
          boxShadow: selected
              ? AppTheme.glowShadow(
                  isPremium ? AppTheme.primaryColor : AppTheme.accentColor)
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(plan.name,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? Colors.white
                                  : AppTheme.onSurfaceColor)),
                      const SizedBox(width: 8),
                      if (isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('POPULAR',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                  letterSpacing: 0.5)),
                        ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            plan.priceUgx == 0
                                ? 'Free'
                                : 'UGX ${_fmt(plan.priceUgx)}',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: selected
                                    ? Colors.white
                                    : AppTheme.primaryColor),
                          ),
                          if (plan.priceUgx > 0)
                            Text('/month',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: selected
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : AppTheme.mutedColor)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...plan.features.take(4).map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 16,
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : AppTheme.accentColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(f,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: selected
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : AppTheme.onSurfaceColor
                                              .withValues(alpha: 0.7))),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            if (isCurrent)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.accentColor.withValues(alpha: 0.4)),
                  ),
                  child: const Text('Current',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentColor)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outlined,
            size: 13, color: AppTheme.mutedColor),
        const SizedBox(width: 6),
        Text(
          'Secured by MarzPay · Mobile Money & Card',
          style: TextStyle(
              fontSize: 11,
              color: AppTheme.onSurfaceColor.withValues(alpha: 0.4)),
        ),
      ],
    );
  }
}
