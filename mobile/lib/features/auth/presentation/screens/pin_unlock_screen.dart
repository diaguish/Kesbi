import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/pin_repository.dart';
import '../auth_status_provider.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/pin_pad.dart';

/// Déverrouillage quotidien par PIN (fonctionne hors ligne).
class PinUnlockScreen extends ConsumerStatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  ConsumerState<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends ConsumerState<PinUnlockScreen> {
  String? _error;
  bool _busy = false;
  int _attempt = 0;

  Future<void> _onCompleted(String pin) async {
    setState(() => _busy = true);
    final result = await ref.read(authStatusProvider.notifier).unlock(pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _attempt++;
      _error = switch (result) {
        PinRejected(:final remainingAttempts) => remainingAttempts == 1
            ? 'Code incorrect. Dernier essai avant de devoir recevoir un SMS.'
            : 'Code incorrect. Il reste $remainingAttempts essais.',
        _ => null,
      };
    });
  }

  Future<void> _forgotPin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Code PIN oublié ?'),
        content: const Text(
          'Vous allez recevoir un nouveau code par SMS pour vous reconnecter, '
          'puis créer un nouveau code PIN. Vos données ne sont pas perdues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await ref.read(authStatusProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Entrez votre code PIN',
      child: Column(
        children: [
          PinPad(key: ValueKey('unlock-$_attempt'), enabled: !_busy, onCompleted: _onCompleted),
          AuthError(_error),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _busy ? null : _forgotPin,
            child: const Text('Code PIN oublié ?'),
          ),
        ],
      ),
    );
  }
}
