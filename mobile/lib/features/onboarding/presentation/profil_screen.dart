import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/domain/phone_number.dart';
import '../../auth/presentation/auth_status_provider.dart';
import '../data/onboarding_repository.dart';

/// Profil : informations du compte, déconnexion, suppression de compte (A8).
class ProfilScreen extends ConsumerStatefulWidget {
  const ProfilScreen({super.key});

  @override
  ConsumerState<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends ConsumerState<ProfilScreen> {
  late Future<MonProfil> _profil = ref
      .read(onboardingRepositoryProvider)
      .monProfil();

  Future<void> _seDeconnecter() async {
    final ok = await _confirmer(
      titre: 'Se déconnecter ?',
      message: 'Pour revenir, vous recevrez un code par SMS. Vos données sont conservées.',
      action: 'Se déconnecter',
    );
    if (ok) await ref.read(authStatusProvider.notifier).signOut();
  }

  Future<void> _supprimerCompte() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ConfirmationSuppression(),
    );
    if (!(ok ?? false) || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(onboardingRepositoryProvider).supprimerCompte();
      await ref.read(authStatusProvider.notifier).accountDeleted();
      (messenger..clearSnackBars()).showSnackBar(
        const SnackBar(content: Text('Votre compte a été supprimé.')),
      );
    } catch (e) {
      (messenger..clearSnackBars()).showSnackBar(
        SnackBar(content: Text(ApiClient.messageFor(e))),
      );
    }
  }

  Future<bool> _confirmer({
    required String titre,
    required String message,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder(
            future: _profil,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    title: Text(ApiClient.messageFor(snapshot.error!)),
                    trailing: IconButton(
                      tooltip: 'Réessayer',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => setState(
                        () => _profil = ref
                            .read(onboardingRepositoryProvider)
                            .monProfil(),
                      ),
                    ),
                  ),
                );
              }
              final profil = snapshot.data;
              final phone = profil == null
                  ? null
                  : PhoneNumber.tryParse(profil.phone);
              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text(profil?.boutiqueNom ?? '…'),
                      subtitle: const Text('Boutique'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: Text(
                        phone == null
                            ? (profil?.phone ?? '…')
                            : '+221 ${phone.display}',
                      ),
                      subtitle: const Text('Numéro de téléphone'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Se déconnecter'),
                  onTap: _seDeconnecter,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Supprimer mon compte',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Efface définitivement votre boutique et vos données',
                  ),
                  onTap: _supprimerCompte,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmation forte : il faut taper SUPPRIMER (action irréversible).
class _ConfirmationSuppression extends StatefulWidget {
  const _ConfirmationSuppression();

  @override
  State<_ConfirmationSuppression> createState() =>
      _ConfirmationSuppressionState();
}

class _ConfirmationSuppressionState extends State<_ConfirmationSuppression> {
  static const motCle = 'SUPPRIMER';
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirme = _controller.text.trim().toUpperCase() == motCle;
    return AlertDialog(
      title: const Text('Supprimer votre compte ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Votre boutique, vos encaissements, dépenses et créances seront effacés '
            'définitivement. Cette action est irréversible.',
          ),
          const SizedBox(height: 16),
          const Text('Pour confirmer, tapez $motCle :'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
          ),
          onPressed: confirme ? () => Navigator.pop(context, true) : null,
          child: const Text('Supprimer'),
        ),
      ],
    );
  }
}
