import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/montant_input.dart';
import '../../auth/presentation/auth_status_provider.dart';
import '../../auth/presentation/widgets/auth_scaffold.dart';
import '../../tresorerie/domain/compte.dart';
import '../data/onboarding_repository.dart';

enum _Etape { chargement, erreur, boutique, soldes }

/// Onboarding (A6, A7) : création de la boutique, puis soldes d'ouverture.
///
/// Reprend à la bonne étape si l'app a été fermée entre les deux.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const activites = ['Alimentation', 'Boutique de quartier', 'Restauration', 'Habillement', 'Quincaillerie'];

  _Etape _etape = _Etape.chargement;
  final _nom = TextEditingController();
  final _activite = TextEditingController();
  final _soldes = {for (final c in Compte.values) c: TextEditingController()};
  bool _busy = false;
  String? _error;

  OnboardingRepository get _repo => ref.read(onboardingRepositoryProvider);

  @override
  void initState() {
    super.initState();
    for (final controller in _soldes.values) {
      controller.addListener(() => setState(() {}));
    }
    _charger();
  }

  @override
  void dispose() {
    _nom.dispose();
    _activite.dispose();
    for (final controller in _soldes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _etape = _Etape.chargement;
      _error = null;
    });
    try {
      final profil = await _repo.monProfil();
      if (!mounted) return;
      if (profil.aUneBoutique && profil.ouvertureFaite) {
        await ref.read(authStatusProvider.notifier).markOnboarded();
        return;
      }
      setState(() => _etape = profil.aUneBoutique ? _Etape.soldes : _Etape.boutique);
    } catch (e) {
      if (mounted) {
        setState(() {
          _etape = _Etape.erreur;
          _error = ApiClient.messageFor(e);
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _creerBoutique() async {
    if (_nom.text.trim().isEmpty) {
      setState(() => _error = 'Indiquez le nom de votre boutique.');
      return;
    }
    await _run(() async {
      await _repo.creerBoutique(nom: _nom.text, activite: _activite.text);
      if (mounted) setState(() => _etape = _Etape.soldes);
    });
  }

  Future<void> _enregistrerSoldes({required bool ignorer}) async {
    final soldes = {
      for (final entry in _soldes.entries) entry.key: ignorer ? 0 : parseMontant(entry.value.text),
    };
    await _run(() async {
      await _repo.enregistrerSoldesOuverture(soldes);
      await ref.read(authStatusProvider.notifier).markOnboarded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_etape) {
      _Etape.chargement => const Scaffold(body: Center(child: CircularProgressIndicator())),
      _Etape.erreur => AuthScaffold(
          title: 'Connexion nécessaire',
          subtitle: 'La création de votre boutique se fait en ligne.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthError(_error),
              const SizedBox(height: 24),
              FilledButton(onPressed: _charger, child: const Text('Réessayer')),
            ],
          ),
        ),
      _Etape.boutique => _etapeBoutique(),
      _Etape.soldes => _etapeSoldes(),
    };
  }

  Widget _etapeBoutique() {
    return AuthScaffold(
      title: 'Votre boutique',
      subtitle: 'Étape 1 sur 2',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nom,
            enabled: !_busy,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nom de la boutique',
              hintText: 'Ex. Boutique Awa',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _activite,
            enabled: !_busy,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Activité (facultatif)', counterText: ''),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final activite in activites)
                ActionChip(
                  label: Text(activite),
                  onPressed: _busy ? null : () => setState(() => _activite.text = activite),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _creerBoutique,
            child: _busy ? const _Progress() : const Text('Continuer'),
          ),
          AuthError(_error),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => ref.read(authStatusProvider.notifier).signOut(),
            child: const Text('Changer de numéro'),
          ),
        ],
      ),
    );
  }

  Widget _etapeSoldes() {
    final total = _soldes.values.fold(0, (sum, c) => sum + parseMontant(c.text));
    return AuthScaffold(
      showLogo: false,
      title: "Combien avez-vous aujourd'hui ?",
      subtitle: "Étape 2 sur 2 — l'argent actuellement dans chaque compte. "
          'Vous pourrez le corriger plus tard.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final compte in Compte.values) ...[
            TextField(
              key: ValueKey('solde-${compte.api}'),
              controller: _soldes[compte],
              enabled: !_busy,
              keyboardType: TextInputType.number,
              // « Suivant » sur le clavier passe au compte suivant.
              textInputAction: compte == Compte.values.last ? TextInputAction.done : TextInputAction.next,
              inputFormatters: const [MontantInputFormatter()],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: compte.label,
                hintText: '0',
                suffixText: 'FCFA',
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Total : ${formatFcfa(total)}',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : () => _enregistrerSoldes(ignorer: false),
            child: _busy ? const _Progress() : const Text('Valider'),
          ),
          AuthError(_error),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => _enregistrerSoldes(ignorer: true),
            child: const Text('Ignorer (tout à 0)'),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      );
}
