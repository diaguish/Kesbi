import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/montant_input.dart';
import '../../auth/presentation/auth_status_provider.dart';
import '../data/transaction_store.dart';
import '../domain/compte.dart';
import '../domain/transaction.dart';
import 'transactions_controller.dart';

/// Textes propres à chaque type de saisie.
extension on TypeSaisie {
  String get titre => switch (this) {
        TypeSaisie.encaissement => 'Nouvel encaissement',
        TypeSaisie.depense => 'Nouvelle dépense',
      };
  String get nom => switch (this) {
        TypeSaisie.encaissement => "l'encaissement",
        TypeSaisie.depense => 'la dépense',
      };
  String get compteLabel => switch (this) {
        TypeSaisie.encaissement => 'Compte crédité',
        TypeSaisie.depense => 'Compte débité',
      };
  String get montantManquant => switch (this) {
        TypeSaisie.encaissement => 'Indiquez le montant encaissé.',
        TypeSaisie.depense => 'Indiquez le montant dépensé.',
      };
  String confirmation(int montant) => switch (this) {
        TypeSaisie.encaissement => 'Encaissement de ${formatFcfa(montant)} enregistré',
        TypeSaisie.depense => 'Dépense de ${formatFcfa(montant)} enregistrée',
      };
  Color get couleur => this == TypeSaisie.depense ? AppColors.outgoing : AppColors.incoming;
}

/// Saisie d'un encaissement (E1) ou d'une dépense (D1).
/// Enregistrée sur le téléphone, synchronisée ensuite (E3, D2).
class NouvelleOperationScreen extends ConsumerStatefulWidget {
  const NouvelleOperationScreen({super.key, required this.saisie});

  final TypeSaisie saisie;

  @override
  ConsumerState<NouvelleOperationScreen> createState() => _NouvelleOperationScreenState();
}

class _NouvelleOperationScreenState extends ConsumerState<NouvelleOperationScreen> {
  final _montant = TextEditingController();
  final _note = TextEditingController();
  Compte _compte = Compte.caisse;
  String? _categorie;
  DateTime? _date; // null = maintenant
  bool _busy = false;
  String? _error;

  TypeSaisie get _saisie => widget.saisie;

  @override
  void initState() {
    super.initState();
    // Saisies enchaînées : le message de l'opération précédente ne doit pas
    // masquer le bouton « Enregistrer ».
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  @override
  void dispose() {
    _montant.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final maintenant = ref.read(clockProvider)();
    final choisie = await showDatePicker(
      context: context,
      initialDate: heureDakar(_date ?? maintenant),
      firstDate: maintenant.subtract(const Duration(days: 365)),
      lastDate: maintenant,
      helpText: 'Date de ${_saisie.nom}',
    );
    if (choisie == null) return;
    setState(() {
      // Aujourd'hui → heure actuelle ; autre jour → midi (heure de Dakar = UTC).
      _date = memeJour(choisie, maintenant)
          ? null
          : DateTime.utc(choisie.year, choisie.month, choisie.day, 12);
    });
  }

  /// Une dépense qui rendrait le compte négatif est probablement une erreur
  /// (faute de frappe, recette oubliée) : on demande confirmation.
  Future<bool> _confirmerSoldeNegatif(int montant) async {
    if (_saisie != TypeSaisie.depense) return true;
    final solde = (await ref.read(transactionStoreProvider).soldes())[_compte] ?? 0;
    final apres = solde - montant;
    if (apres >= 0 || !mounted) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Solde ${_compte.label} insuffisant'),
        content: Text(
          'Le solde ${_compte.label} est de ${formatFcfa(solde)}. Après cette dépense, '
          'il serait de ${formatFcfa(apres)}.\n\nVérifiez le montant ou le compte. '
          "Si une recette n'a pas été saisie, vous pourrez l'ajouter ensuite.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Corriger')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer quand même')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _enregistrer() async {
    final montant = parseMontant(_montant.text);
    final erreur = switch ((montant, _categorie)) {
      (0, _) => _saisie.montantManquant,
      (_, null) => 'Choisissez une catégorie.',
      _ => null,
    };
    if (erreur != null) {
      setState(() => _error = erreur);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    if (!await _confirmerSoldeNegatif(montant)) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    await ref.read(transactionsControllerProvider.notifier).enregistrer(
          saisie: _saisie,
          montant: montant,
          compte: _compte,
          categorie: _categorie!,
          dateOperation: _date ?? ref.read(clockProvider)(),
          note: _note.text,
        );
    if (!mounted) return;
    (ScaffoldMessenger.of(context)..clearSnackBars()).showSnackBar(
      SnackBar(content: Text(_saisie.confirmation(montant))),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final date = _date ?? ref.read(clockProvider)();
    return Scaffold(
      appBar: AppBar(title: Text(_saisie.titre)),
      body: SafeArea(
        // Formulaire court : tout est construit d'emblée (pas de liste paresseuse).
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('montant'),
                controller: _montant,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: const [MontantInputFormatter()],
                // Le clavier masquerait « Enregistrer » : il se ferme dès qu'on
                // touche ailleurs (catégorie, compte…).
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: _saisie.couleur),
                decoration: const InputDecoration(hintText: '0', suffixText: 'FCFA'),
              ),
              const SizedBox(height: 24),
              const _Titre('Catégorie'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final categorie in _saisie.categories)
                    ChoiceChip(
                      label: Text(categorie),
                      selected: _categorie == categorie,
                      onSelected: _busy ? null : (_) => setState(() => _categorie = categorie),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _Titre(_saisie.compteLabel),
              SegmentedButton<Compte>(
                segments: [
                  for (final compte in Compte.values) ButtonSegment(value: compte, label: Text(compte.label)),
                ],
                selected: {_compte},
                showSelectedIcon: false,
                onSelectionChanged: _busy ? null : (s) => setState(() => _compte = s.single),
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(_date == null ? "Aujourd'hui" : formatDate(date)),
                subtitle: Text('Date de ${_saisie.nom}'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _busy ? null : _choisirDate,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                enabled: !_busy,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Note (facultatif)', counterText: ''),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _enregistrer,
                child: const Text('Enregistrer'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(texte, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}
