import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/pin_rules.dart';

/// Saisie d'un PIN à 6 chiffres : points de progression + pavé numérique.
///
/// Grandes touches (usage en extérieur, une main). Appelle [onCompleted] au
/// 6ᵉ chiffre. Pour vider la saisie, reconstruire avec une nouvelle `key`.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onCompleted, this.enabled = true});

  final ValueChanged<String> onCompleted;
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';

  void _press(String digit) {
    if (!widget.enabled || _pin.length >= PinRules.length) return;
    HapticFeedback.lightImpact();
    setState(() => _pin += digit);
    if (_pin.length == PinRules.length) widget.onCompleted(_pin);
  }

  void _erase() {
    if (!widget.enabled || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '${_pin.length} chiffres saisis sur ${PinRules.length}',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < PinRules.length; i++)
                Container(
                  key: ValueKey('pin-dot-$i'),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? AppColors.primary : Colors.transparent,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          _row([for (final d in row) _DigitKey(d, onTap: () => _press(d))]),
        _row([
          const SizedBox(width: _DigitKey.size, height: _DigitKey.size),
          _DigitKey('0', onTap: () => _press('0')),
          SizedBox(
            width: _DigitKey.size,
            height: _DigitKey.size,
            child: IconButton(
              tooltip: 'Effacer',
              iconSize: 28,
              color: AppColors.textDark,
              onPressed: _erase,
              icon: const Icon(Icons.backspace_outlined),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> keys) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: keys,
        ),
      );
}

class _DigitKey extends StatelessWidget {
  const _DigitKey(this.digit, {required this.onTap});

  static const size = 72.0;
  final String digit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
