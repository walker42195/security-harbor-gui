import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../theme.dart';

/// Regelurval för Suricata: stäng av hela kategorier eller slå på tystade
/// signaturer igen.
///
/// Kategorierna härleds ur regelfilens msg-prefix ("ET MALWARE", "SURICATA"),
/// eftersom ET Open levereras som en enda sammanslagen fil utan filstruktur
/// att gruppera på.
class IdsRulesScreen extends StatefulWidget {
  const IdsRulesScreen({super.key});

  @override
  State<IdsRulesScreen> createState() => _IdsRulesScreenState();
}

class _IdsRulesScreenState extends State<IdsRulesScreen> {
  IdsRulesModel? _rules;
  bool _loading = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<ConfigProvider>().api;
    final r = await api.getIdsRules();
    if (!mounted) return;
    setState(() {
      _rules = r;
      _loading = false;
    });
    // Medan suricata-update kör (~40–60 s) ändras antalen i regelfilen, så
    // poll:a tills den är klar och sluta sedan — ingen bakgrundstrafik i onödan.
    _poll?.cancel();
    if (r != null && r.isUpdating) {
      _poll = Timer(const Duration(seconds: 5), _load);
    }
  }

  Future<void> _send(Map<String, dynamic> delta) async {
    final api = context.read<ConfigProvider>().api;
    final err = await api.postIdsRuleChange(delta);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err == null
          ? tr('idsrules.andring_sparad')
          : '${tr('idsrules.kunde_inte_spara')}: $err'),
    ));
    if (err == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConfigProvider>();
    final rules = _rules;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rule, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(tr('idsrules.titel'),
                  style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (rules != null && rules.isUpdating) ...[
                SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                const SizedBox(width: 8),
                Text(tr('idsrules.uppdatering_pagar'),
                    style: TextStyle(color: AppColors.accent, fontSize: 11)),
              ],
              IconButton(
                icon: Icon(Icons.refresh, color: AppColors.textMuted, size: 18),
                onPressed: _load,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(tr('idsrules.beskrivning'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4)),
          const SizedBox(height: 16),
          _buildSilenced(rules, provider.isAdmin),
          const SizedBox(height: 16),
          _buildCategories(rules, provider.isAdmin),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _buildSilenced(IdsRulesModel? rules, bool isAdmin) {
    final sigs = rules?.disabledSignatures ?? const <IdsDisabledSignatureModel>[];
    return _card(
      title: '${tr('idsrules.tystade_signaturer')} (${sigs.length})',
      child: sigs.isEmpty
          ? Text(tr('idsrules.inga_tystade'),
              style: TextStyle(color: AppColors.textFaint, fontSize: 12))
          : Column(
              children: sigs
                  .map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text('${s.sid}',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ),
                            Expanded(
                              child: Text(s.signature.isEmpty ? '—' : s.signature,
                                  style: TextStyle(color: AppColors.text, fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (isAdmin)
                              TextButton(
                                onPressed: () => _send({'unsilence_sid': s.sid}),
                                child: Text(tr('idsrules.slå_pa_igen'),
                                    style: TextStyle(color: AppColors.accent, fontSize: 11)),
                              ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildCategories(IdsRulesModel? rules, bool isAdmin) {
    final cats = rules?.categories ?? const <IdsCategoryModel>[];
    return _card(
      title: '${tr('idsrules.kategorier')} (${cats.length})',
      child: cats.isEmpty
          ? Text(tr('idsrules.inga_kategorier'),
              style: TextStyle(color: AppColors.textFaint, fontSize: 12))
          : Column(
              children: cats
                  .map((c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(c.name,
                                  style: TextStyle(
                                      color: c.disabled ? AppColors.textFaint : AppColors.text,
                                      fontSize: 12)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${c.enabled} ${tr('idsrules.aktiva')} / ${c.total} ${tr('idsrules.regler')}',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ),
                            Switch(
                              value: !c.disabled,
                              onChanged: isAdmin
                                  ? (v) => _send(v
                                      ? {'enable_category': c.name}
                                      : {'disable_category': c.name})
                                  : null,
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}
