import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pin_rules.dart';
import '../auth_status_provider.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/pin_pad.dart';

/// Étape 3 : création du PIN (saisie puis confirmation).
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String? _first;
  String? _error;
  bool _busy = false;
  int _attempt = 0;

  Future<void> _onCompleted(String pin) async {
    if (_first == null) {
      final weakness = PinRules.weaknessOf(pin);
      setState(() {
        _error = weakness;
        if (weakness == null) _first = pin;
        _attempt++;
      });
      return;
    }

    if (pin != _first) {
      setState(() {
        _error = 'Les deux codes ne correspondent pas. Recommencez.';
        _first = null;
        _attempt++;
      });
      return;
    }

    setState(() => _busy = true);
    // En cas de succès, le routeur quitte cet écran.
    await ref.read(authStatusProvider.notifier).createPin(pin);
  }

  @override
  Widget build(BuildContext context) {
    final confirming = _first != null;
    return AuthScaffold(
      showLogo: false,
      title: confirming ? 'Confirmez votre code PIN' : 'Créez votre code PIN',
      subtitle: confirming
          ? 'Saisissez le même code une seconde fois.'
          : 'Ce code à 6 chiffres ouvrira votre caisse chaque jour. '
              'Il reste sur ce téléphone.',
      child: Column(
        children: [
          PinPad(
            key: ValueKey('setup-$_attempt-$confirming'),
            enabled: !_busy,
            onCompleted: _onCompleted,
          ),
          AuthError(_error),
          if (_busy) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
