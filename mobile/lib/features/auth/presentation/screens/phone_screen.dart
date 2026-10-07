import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../data/auth_gateway.dart';
import '../../domain/phone_number.dart';
import '../auth_status_provider.dart';
import '../widgets/auth_scaffold.dart';

/// Étape 1 : numéro de téléphone → envoi du code SMS.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = PhoneNumber.tryParse(_controller.text);
    if (phone == null) {
      setState(() => _error = 'Numéro invalide. Exemple : 77 123 45 67');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authStatusProvider.notifier).sendOtp(phone);
      if (mounted) context.push(Routes.otpCode, extra: phone);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Bienvenue',
      subtitle: 'Connectez-vous à votre caisse',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Numéro de téléphone', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d\s+]')),
                  LengthLimitingTextInputFormatter(17),
                ],
                style: const TextStyle(fontSize: 18, letterSpacing: 1),
                decoration: const InputDecoration(
                  // prefixIcon (et non prefixText) : visible même champ vide et non sélectionné.
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(left: 16, right: 8),
                    child: Text('🇸🇳 +221', style: TextStyle(fontSize: 18)),
                  ),
                  prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                  hintText: '77 000 00 00',
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Recevoir le code'),
              ),
              AuthError(_error),
              const SizedBox(height: 16),
              const Text(
                'Un code de vérification vous sera envoyé par SMS.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
