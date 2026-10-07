import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_gateway.dart';
import '../../domain/phone_number.dart';
import '../auth_status_provider.dart';
import '../widgets/auth_scaffold.dart';

/// Étape 2 : code reçu par SMS. Validation automatique au 6ᵉ chiffre.
class OtpCodeScreen extends ConsumerStatefulWidget {
  const OtpCodeScreen({super.key, required this.phone});

  final PhoneNumber phone;

  @override
  ConsumerState<OtpCodeScreen> createState() => _OtpCodeScreenState();
}

class _OtpCodeScreenState extends ConsumerState<OtpCodeScreen> {
  static const resendDelay = 60;

  final _controller = TextEditingController();
  Timer? _timer;
  int _resendIn = resendDelay;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendIn = resendDelay);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_resendIn <= 1) t.cancel();
      setState(() => _resendIn--);
    });
  }

  Future<void> _verify() async {
    final code = _controller.text;
    if (code.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // En cas de succès, le routeur redirige vers la création du PIN.
      await ref.read(authStatusProvider.notifier).verifyOtp(widget.phone, code);
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
        _controller.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      await ref.read(authStatusProvider.notifier).sendOtp(widget.phone);
      _startResendTimer();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showLogo: false,
      leading: BackButton(onPressed: () => context.pop()),
      title: 'Code de vérification',
      subtitle: 'Saisissez le code à 6 chiffres envoyé au\n+221 ${widget.phone.display}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            enabled: !_busy,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
            onChanged: (value) {
              if (value.length == 6) _verify();
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _verify,
            child: _busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Valider'),
          ),
          AuthError(_error),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _resendIn > 0 || _busy ? null : _resend,
            child: Text(
              _resendIn > 0 ? 'Renvoyer le code dans $_resendIn s' : 'Renvoyer le code',
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => context.pop(),
            child: const Text('Modifier le numéro'),
          ),
        ],
      ),
    );
  }
}
