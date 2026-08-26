import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../widgets/dialog_helpers.dart';
import '../localization.dart';
import '../object_filter.dart';

class ObjectsScreen extends StatefulWidget {
  const ObjectsScreen({super.key});

  @override
  State<ObjectsScreen> createState() => _ObjectsScreenState();
}

class _ObjectsScreenState extends State<ObjectsScreen> {
  final TextEditingController _search = TextEditingController();
  /// null = alla kategorier.
  ObjectCategory? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  final Set<String> _refreshingIds = {};

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final cfg = provider.candidateConfig ?? provider.runningConfig;

    return Container(
      color: AppColors.bg,
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wrap i stället för Row+spaceBetween: tre knappar med rätt
            // långa etiketter fick tidigare aldrig plats bredvid varandra på
            // en telefonskärm - Row overflowade tyst (upptäckt 2026-08-24).
            // Wrap låter dem falla ner till en ny rad i stället.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category, color: Colors.cyanAccent, size: 22),
                    SizedBox(width: 10),
                    Text(tr('objects.objekt_grupper'), style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.dns, size: 14),
                  label: Text(tr('objects.skapa_objekt'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                  onPressed: () => _showAddObjectDialog(context, provider),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.workspaces_outline, size: 14),
                  label: Text(tr('objects.skapa_grupp'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                  onPressed: () => _showAddGroupDialog(context, provider),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.shield, size: 14),
                  label: Text(tr('objects.hot_lista_geoip'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                  onPressed: () => _showAddThreatFeedDialog(context, provider),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (cfg != null && cfg.objects.isNotEmpty) ...[
              _buildSearchAndFilter(cfg.objects),
              const SizedBox(height: 12),
            ],
            if (cfg != null && cfg.objects.isEmpty)
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text(tr('objects.inga_sparade_natverksobjekt_annu'), style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                ),
              )
            else if (cfg != null) ...[
              if (_visibleObjects(cfg.objects).isEmpty)
                Card(
                  color: AppColors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(tr('objects.inga_traffar'),
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _visibleObjects(cfg.objects).length,
                  itemBuilder: (context, idx) =>
                      _buildObjectCard(context, provider, _visibleObjects(cfg.objects)[idx]),
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<ObjectModel> _visibleObjects(List<ObjectModel> objects) =>
      filterAndSortObjects(objects, query: _search.text, category: _category);

  /// Sökfält plus kategoriknappar med antal.
  ///
  /// Räknarna beräknas på den SÖKFILTRERADE listan, inte på allt: siffran ska
  /// visa vad ett kategoribyte faktiskt skulle ge, inte hur många objekt som
  /// finns totalt.
  Widget _buildSearchAndFilter(List<ObjectModel> objects) {
    final matching = filterAndSortObjects(objects, query: _search.text);
    final counts = countByCategory(matching);

    Widget chip(ObjectCategory? cat, String label, IconData icon) {
      final selected = _category == cat;
      final count = cat == null ? matching.length : (counts[cat] ?? 0);
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ElevatedButton.icon(
          icon: Icon(icon, size: 14),
          label: Text('$label ($count)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: selected ? Colors.cyanAccent : AppColors.surface,
            foregroundColor: selected ? Colors.black : AppColors.textMuted,
            side: BorderSide(color: selected ? Colors.cyanAccent : AppColors.border),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onPressed: () => setState(() => _category = selected ? null : cat),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 12, color: Colors.white),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 16, color: AppColors.textMuted),
                prefixIconConstraints: const BoxConstraints(minWidth: 34),
                labelText: tr('objects.sok'),
                labelStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
                hintText: tr('objects.sok_hint'),
                hintStyle: TextStyle(fontSize: 11, color: AppColors.hint),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                border: const OutlineInputBorder(),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.clear, size: 15, color: AppColors.textMuted),
                        onPressed: () => setState(() => _search.clear()),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chip(null, tr('objects.kat_alla'), Icons.select_all),
                chip(ObjectCategory.group, tr('objects.kat_grupper'), Icons.workspaces_outline),
                chip(ObjectCategory.network, tr('objects.kat_nat'), Icons.lan_outlined),
                chip(ObjectCategory.host, tr('objects.kat_hostar'), Icons.dns_outlined),
                chip(ObjectCategory.geoip, tr('objects.kat_geoip'), Icons.public),
                chip(ObjectCategory.threatFeed, tr('objects.kat_hotlistor'), Icons.shield_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObjectCard(BuildContext context, ConfigProvider provider, ObjectModel obj) {
    final src = obj.source;
    final refreshing = _refreshingIds.contains(obj.id);

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(src != null ? Icons.shield : Icons.category, color: src != null ? Colors.tealAccent : Colors.cyanAccent),
              title: Text(obj.name, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: src != null
                  ? Row(
                      children: [
                        Text('Typ: ${obj.type.toUpperCase()}  |  ', style: const TextStyle(fontSize: 11)),
                        InkWell(
                          onTap: () => _showValuesDialog(context, obj),
                          child: Text(
                            '${obj.values.length} poster',
                            style: const TextStyle(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                          ),
                        ),
                        Text(trp('objects.automatisk_kalla', {'kind': _kindLabel(src.kind)}), style: const TextStyle(fontSize: 11)),
                      ],
                    )
                  : Text(
                      obj.type == 'group'
                          ? trp('objects.typ_grupp_medlemmar', {'members': _groupMemberNames(context, obj)})
                          : trp('objects.typ_varden', {'type': obj.type.toUpperCase(), 'values': obj.values.join(", ")}),
                      style: const TextStyle(fontSize: 11),
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (src != null)
                    refreshing
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent)),
                          )
                        : IconButton(
                            icon: const Icon(Icons.refresh, size: 18, color: Colors.tealAccent),
                            tooltip: tr('objects.uppdatera_nu'),
                            onPressed: () => _refreshSource(provider, obj),
                          ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.cyanAccent),
                    tooltip: tr('objects.redigera'),
                    onPressed: () => src != null
                        ? _showAddThreatFeedDialog(context, provider, existing: obj)
                        : obj.type == 'group'
                            ? _showAddGroupDialog(context, provider, existing: obj)
                            : _showAddObjectDialog(context, provider, existing: obj),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    tooltip: tr('objects.ta_bort'),
                    onPressed: () => _deleteObject(context, provider, obj),
                  ),
                ],
              ),
            ),
            if (src != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _statusChip(Icons.update, src.lastUpdated.isEmpty ? tr('objects.aldrig_uppdaterad') : trp('objects.uppdaterad_colon', {'time': _shortTime(src.lastUpdated)}), src.lastError.isNotEmpty ? Colors.amberAccent : AppColors.textMuted),
                    _statusChip(Icons.timer, trp('objects.var_x_timme', {'hours': '${src.refreshHours}'}), AppColors.textMuted),
                    if (src.lastError.isNotEmpty) _statusChip(Icons.error_outline, trp('objects.fel_colon', {'err': src.lastError}), Colors.redAccent),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showValuesDialog(BuildContext context, ObjectModel obj) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Container(
          width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 480.0),
          height: 560,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dialogTitleRow(context, '${obj.name} (${obj.values.length})', () => Navigator.pop(ctx)),
              const SizedBox(height: 10),
              Expanded(
                child: obj.values.isEmpty
                    ? Center(child: Text(tr('objects.inga_varden_hamtade_annu'), style: TextStyle(color: AppColors.textMuted, fontSize: 12)))
                    : Container(
                        decoration: BoxDecoration(color: AppColors.bg, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
                        child: ListView.builder(
                          itemCount: obj.values.length,
                          itemBuilder: (c, i) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            child: Text(obj.values[i], style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace')),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }

  String _shortTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'spamhaus_drop':
        return 'Spamhaus DROP';
      case 'spamhaus_edrop':
        return 'Spamhaus EDROP';
      case 'tor_exit_nodes':
        return tr('objects.tor_exit_noder');
      case 'custom_url':
        return tr('objects.anpassad_url');
      case 'geoip_country':
        return tr('objects.geoip_land');
      default:
        return kind;
    }
  }

  Future<void> _refreshSource(ConfigProvider provider, ObjectModel obj) async {
    setState(() => _refreshingIds.add(obj.id));
    final ok = await provider.api.refreshObjectSource(obj.id);
    await provider.fetchAll();
    if (mounted) {
      setState(() => _refreshingIds.remove(obj.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? trp('objects.updated', {'name': obj.name}) : trp('objects.update_failed', {'name': obj.name})),
          backgroundColor: ok ? Colors.teal : Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteObject(BuildContext context, ConfigProvider provider, ObjectModel obj) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr('objects.ta_bort_objekt'), style: TextStyle(color: AppColors.text, fontSize: 14)),
        content: Text(trp('objects.delete_confirm_body', {'name': obj.name}), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('objects.avbryt'), style: TextStyle(fontSize: 12))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('objects.ta_bort'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final cfg = provider.candidateConfig ?? provider.runningConfig;
    if (cfg == null) return;
    final updatedObjs = cfg.objects.where((o) => o.id != obj.id).toList();
    await provider.updateCandidate(cfg.copyWith(
      objects: updatedObjs,
    ));
  }

  void _showAddObjectDialog(BuildContext context, ConfigProvider provider, {ObjectModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? 'WEB-SERVERS');
    final valCtrl = TextEditingController(text: existing != null ? existing.values.join(', ') : '192.168.10.10, 192.168.10.11');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Container(
          width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 440.0),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dialogTitleRow(context, existing != null ? tr('objects.redigera_natverksobjekt') : tr('objects.skapa_nytt_natverksobjekt'), () => Navigator.pop(ctx)),
              const SizedBox(height: 12),

              dialogSection(title: tr('objects.section_objekt'), children: [
                dialogField(nameCtrl, tr('objects.objektnamn')),
                const SizedBox(height: 12),
                dialogField(valCtrl, tr('objects.ip_cidr'), hint: tr('objects.komma_separerade')),
              ]),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('objects.avbryt'), style: TextStyle(fontSize: 12))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    child: Text(tr('objects.spara'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
              final cfg = provider.candidateConfig ?? provider.runningConfig;
              if (cfg != null) {
                final savedValues =
                    valCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                final savedObj = ObjectModel(
                  id: existing?.id ?? 'obj_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text,
                  // Typen härleds ur värdena i stället för att alltid bli
                  // "host". Ett objekt med enbart CIDR ÄR ett nät, och ska
                  // kategoriseras som ett — grupper behåller sin typ.
                  type: existing?.type == 'group'
                      ? 'group'
                      : inferObjectType(savedValues, fallback: existing?.type ?? 'host'),
                  values: savedValues,
                  description: existing?.description ?? tr('objects.skapad_i_gui'),
                );
                final updatedObjs = existing != null
                    ? cfg.objects.map((o) => o.id == existing.id ? savedObj : o).toList()
                    : (List<ObjectModel>.from(cfg.objects)..add(savedObj));
                provider.updateCandidate(cfg.copyWith(
                  objects: updatedObjs,
                ));
              }
              Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Namnen på en grupps medlemsobjekt (obj.values = medlems-ID:n) för visning.
  String _groupMemberNames(BuildContext context, ObjectModel group) {
    final cfg = context.read<ConfigProvider>().candidateConfig ?? context.read<ConfigProvider>().runningConfig;
    if (cfg == null) return group.values.join(', ');
    final names = group.values.map((id) {
      final m = cfg.objects.where((o) => o.id == id);
      return m.isNotEmpty ? m.first.name : id;
    }).toList();
    return names.isEmpty ? '(inga)' : names.join(', ');
  }

  // En grupp är ett objekt av typ 'group' vars values är ANDRA objekts ID:n.
  // Backend (pkg/adapter/nftables/resolveObjectCIDRs) löser upp gruppen
  // rekursivt till alla medlemmars IP/CIDR, så en policy kan referera EN grupp
  // och matcha mot flera objekt samtidigt.
  void _showAddGroupDialog(BuildContext context, ConfigProvider provider, {ObjectModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? 'WEB-SERVERS-GRUPP');
    final selected = <String>{...(existing?.values ?? const <String>[])};

    final cfg = provider.candidateConfig ?? provider.runningConfig;
    // Valbara medlemmar: alla objekt utom gruppen själv (en grupp får inte
    // innehålla sig själv). Hot-listor/GeoIP (objekt med en källa, t.ex.
    // Spamhaus) fick tidigare INTE väljas här — en ren GUI-spärr utan
    // backend-grund, upptäckt 2026-08-24: resolveObjectCIDRs i
    // nftables-adaptern löser upp en grupps medlemmar rekursivt oavsett om
    // medlemmen har en Source eller inte, så en hot-lista fungerar precis
    // lika bra som ett manuellt objekt som gruppmedlem.
    final candidates = (cfg?.objects ?? const <ObjectModel>[])
        .where((o) => o.id != existing?.id)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 460.0),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dialogTitleRow(context, existing != null ? tr('objects.redigera_grupp') : tr('objects.skapa_ny_grupp'), () => Navigator.pop(ctx)),
                const SizedBox(height: 12),
                dialogSection(title: tr('objects.section_grupp'), children: [
                  dialogField(nameCtrl, tr('objects.gruppnamn')),
                ]),
                const SizedBox(height: 12),
                Text(tr('objects.medlemmar'), style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                if (candidates.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(tr('objects.skapa_forst_nagra_objekt_host_natverk'), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: candidates.map((o) {
                          final isGroup = o.type == 'group';
                          // En källbaserad hot-lista/GeoIP (t.ex. Spamhaus)
                          // kan ha tusentals poster — att skriva ut hela
                          // o.values-listan i subtitle:en (som för ett vanligt
                          // host/nätverk-objekt) hade gett en oläsbar rad.
                          // Visa antal poster i stället.
                          final subtitle = isGroup
                              ? trp('objects.grupp_colon', {'members': _groupMemberNames(context, o)})
                              : o.source != null
                                  ? '${o.type} (auto: ${o.source!.kind}) · ${o.source!.entryCount} poster'
                                  : '${o.type} · ${o.values.join(", ")}';
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: Colors.amberAccent,
                            checkColor: Colors.black,
                            value: selected.contains(o.id),
                            title: Text(o.name, style: TextStyle(color: AppColors.text, fontSize: 12)),
                            subtitle: Text(
                              subtitle,
                              style: TextStyle(color: AppColors.textFaint, fontSize: 10),
                            ),
                            onChanged: (v) => setDialogState(() {
                              if (v == true) {
                                selected.add(o.id);
                              } else {
                                selected.remove(o.id);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('objects.avbryt'), style: TextStyle(fontSize: 12))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                      onPressed: selected.isEmpty
                          ? null
                          : () {
                              final c = provider.candidateConfig ?? provider.runningConfig;
                              if (c != null) {
                                final savedObj = ObjectModel(
                                  id: existing?.id ?? 'obj_${DateTime.now().millisecondsSinceEpoch}',
                                  name: nameCtrl.text.trim().isEmpty ? tr('objects.ny_grupp') : nameCtrl.text.trim(),
                                  type: 'group',
                                  values: selected.toList(),
                                  description: existing?.description ?? tr('objects.grupp_skapad_i_gui'),
                                );
                                final updatedObjs = existing != null
                                    ? c.objects.map((o) => o.id == existing.id ? savedObj : o).toList()
                                    : (List<ObjectModel>.from(c.objects)..add(savedObj));
                                provider.updateCandidate(c.copyWith(objects: updatedObjs));
                              }
                              Navigator.pop(ctx);
                            },
                      child: Text(tr('objects.spara'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddThreatFeedDialog(BuildContext context, ConfigProvider provider, {ObjectModel? existing}) {
    final src = existing?.source;
    final nameCtrl = TextEditingController(text: existing?.name ?? 'Spamhaus DROP');
    final urlCtrl = TextEditingController(text: src?.url ?? '');
    final countryCtrl = TextEditingController(text: src != null && src.countryCode.isNotEmpty ? src.countryCode : 'RU');
    final refreshHoursCtrl = TextEditingController(text: (src?.refreshHours ?? 24).toString());
    String kind = src?.kind ?? 'spamhaus_drop';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 460.0),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dialogTitleRow(context, existing != null ? tr('objects.redigera_hotlista') : tr('objects.lagg_till_hotlista'), () => Navigator.pop(ctx)),
                const SizedBox(height: 12),
                dialogSection(title: tr('objects.section_kalla'), children: [
                  dialogField(nameCtrl, tr('objects.objektnamn')),
                  const SizedBox(height: 12),
                  Text(tr('objects.kalltyp'), style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: 'spamhaus_drop', child: Text(tr('objects.spamhaus_drop_kanda_spam_botnat_nat'))),
                      DropdownMenuItem(value: 'spamhaus_edrop', child: Text(tr('objects.spamhaus_edrop_utokad_drop'))),
                      DropdownMenuItem(value: 'tor_exit_nodes', child: Text(tr('objects.tor_exit_noder'))),
                      DropdownMenuItem(value: 'custom_url', child: Text(tr('objects.anpassad_url_en_cidr_ip_per'))),
                      DropdownMenuItem(value: 'geoip_country', child: Text(tr('objects.geoip_helt_land_landskod'))),
                    ],
                    onChanged: (v) => setDialogState(() => kind = v ?? kind),
                  ),
                  const SizedBox(height: 12),
                  if (kind == 'custom_url') dialogField(urlCtrl, 'URL', hint: 'https://exempel.se/blocklist.txt'),
                  if (kind == 'geoip_country') dialogField(countryCtrl, 'Landskod (ISO 3166-1 alpha-2)', hint: 't.ex. RU, CN, KP'),
                  if (kind == 'custom_url' || kind == 'geoip_country') const SizedBox(height: 12),
                  dialogField(refreshHoursCtrl, tr('objects.uppdateringsintervall_label'), hint: '24'),
                ]),
                const SizedBox(height: 6),
                Text(tr('objects.listan_hamtas_automatiskt_av_brandvaggen_enligt'),
                  style: TextStyle(color: Colors.amberAccent, fontSize: 10),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('objects.avbryt'), style: TextStyle(fontSize: 12))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                      child: Text(existing != null ? 'Spara & hämta nu' : 'Skapa & hämta nu', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final cfg = provider.candidateConfig ?? provider.runningConfig;
                        if (cfg == null) {
                          Navigator.pop(ctx);
                          return;
                        }
                        final objType = kind == 'geoip_country' ? 'geoip' : 'iplist';
                        // Behåller befintliga values vid redigering (uppdateras ändå
                        // vid nästa "Uppdatera nu"/periodisk hämtning) — nollställs
                        // bara om källtypen faktiskt bytts, eftersom gamla postar
                        // annars skulle vara missvisande för en helt annan källa.
                        final kindChanged = existing != null && existing.source?.kind != kind;
                        final savedObj = ObjectModel(
                          id: existing?.id ?? 'obj_${DateTime.now().millisecondsSinceEpoch}',
                          name: nameCtrl.text.trim().isEmpty ? _kindLabel(kind) : nameCtrl.text.trim(),
                          type: objType,
                          values: (existing == null || kindChanged) ? const [] : existing.values,
                          description: existing?.description ?? trp('objects.automatiskt_uppdaterad', {'kind': _kindLabel(kind)}),
                          source: ObjectSourceModel(
                            kind: kind,
                            url: urlCtrl.text.trim(),
                            countryCode: countryCtrl.text.trim(),
                            refreshHours: int.tryParse(refreshHoursCtrl.text.trim()) ?? 24,
                          ),
                        );
                        final updatedObjs = existing != null
                            ? cfg.objects.map((o) => o.id == existing.id ? savedObj : o).toList()
                            : (List<ObjectModel>.from(cfg.objects)..add(savedObj));
                        await provider.updateCandidate(cfg.copyWith(
                          objects: updatedObjs,
                        ));
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await provider.api.refreshObjectSource(savedObj.id);
                        await provider.fetchAll();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
