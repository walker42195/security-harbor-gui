import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../widgets/dialog_helpers.dart';

class ObjectsScreen extends StatefulWidget {
  const ObjectsScreen({super.key});

  @override
  State<ObjectsScreen> createState() => _ObjectsScreenState();
}

class _ObjectsScreenState extends State<ObjectsScreen> {
  final Set<String> _refreshingIds = {};

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final cfg = provider.candidateConfig ?? provider.runningConfig;

    return Container(
      color: const Color(0xFF0F172A),
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
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category, color: Colors.cyanAccent, size: 22),
                    SizedBox(width: 10),
                    Text('Objekt & Grupper', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.dns, size: 14),
                  label: const Text('+ Skapa Objekt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                  onPressed: () => _showAddObjectDialog(context, provider),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.workspaces_outline, size: 14),
                  label: const Text('+ Skapa Grupp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                  onPressed: () => _showAddGroupDialog(context, provider),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.shield, size: 14),
                  label: const Text('+ Hot-lista / GeoIP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                  onPressed: () => _showAddThreatFeedDialog(context, provider),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (cfg != null && cfg.objects.isEmpty)
              const Card(
                color: Color(0xFF1E293B),
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text('Inga sparade nätverksobjekt ännu.', style: TextStyle(color: Colors.grey, fontSize: 12))),
                ),
              )
            else if (cfg != null)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cfg.objects.length,
                itemBuilder: (context, idx) => _buildObjectCard(context, provider, cfg.objects[idx]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildObjectCard(BuildContext context, ConfigProvider provider, ObjectModel obj) {
    final src = obj.source;
    final refreshing = _refreshingIds.contains(obj.id);

    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(src != null ? Icons.shield : Icons.category, color: src != null ? Colors.tealAccent : Colors.cyanAccent),
              title: Text(obj.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
                        Text('  (automatisk källa: ${_kindLabel(src.kind)})', style: const TextStyle(fontSize: 11)),
                      ],
                    )
                  : Text(
                      obj.type == 'group'
                          ? 'Typ: GRUPP  |  Medlemmar: ${_groupMemberNames(context, obj)}'
                          : 'Typ: ${obj.type.toUpperCase()}  |  Värden: ${obj.values.join(", ")}',
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
                            tooltip: 'Uppdatera nu',
                            onPressed: () => _refreshSource(provider, obj),
                          ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.cyanAccent),
                    tooltip: 'Redigera',
                    onPressed: () => src != null
                        ? _showAddThreatFeedDialog(context, provider, existing: obj)
                        : obj.type == 'group'
                            ? _showAddGroupDialog(context, provider, existing: obj)
                            : _showAddObjectDialog(context, provider, existing: obj),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    tooltip: 'Ta bort',
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
                    _statusChip(Icons.update, src.lastUpdated.isEmpty ? 'Aldrig uppdaterad' : 'Uppdaterad: ${_shortTime(src.lastUpdated)}', src.lastError.isNotEmpty ? Colors.amberAccent : Colors.grey),
                    _statusChip(Icons.timer, 'Var ${src.refreshHours}:e timme', Colors.grey),
                    if (src.lastError.isNotEmpty) _statusChip(Icons.error_outline, 'Fel: ${src.lastError}', Colors.redAccent),
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
        backgroundColor: const Color(0xFF1E293B),
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
                    ? const Center(child: Text('Inga värden hämtade ännu.', style: TextStyle(color: Colors.grey, fontSize: 12)))
                    : Container(
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), border: Border.all(color: const Color(0xFF334155)), borderRadius: BorderRadius.circular(4)),
                        child: ListView.builder(
                          itemCount: obj.values.length,
                          itemBuilder: (c, i) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            child: Text(obj.values[i], style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
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
        return 'Tor-exit-noder';
      case 'custom_url':
        return 'Anpassad URL';
      case 'geoip_country':
        return 'GeoIP-land';
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
          content: Text(ok ? '"${obj.name}" uppdaterad' : 'Misslyckades uppdatera "${obj.name}" — se felmeddelande på objektet'),
          backgroundColor: ok ? Colors.teal : Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteObject(BuildContext context, ConfigProvider provider, ObjectModel obj) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Ta bort objekt?', style: TextStyle(color: Colors.white, fontSize: 14)),
        content: Text('Är du säker på att du vill ta bort "${obj.name}"? Policies som refererar till det slutar fungera som avsett.', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ta bort', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Container(
          width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 440.0),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dialogTitleRow(context, existing != null ? 'Redigera Nätverksobjekt' : 'Skapa nytt Nätverksobjekt', () => Navigator.pop(ctx)),
              const SizedBox(height: 12),

              dialogSection(title: 'OBJEKT', children: [
                dialogField(nameCtrl, 'Objektnamn'),
                const SizedBox(height: 12),
                dialogField(valCtrl, 'IP / CIDR', hint: 'komma-separerade'),
              ]),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    child: const Text('Spara', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
              final cfg = provider.candidateConfig ?? provider.runningConfig;
              if (cfg != null) {
                final savedObj = ObjectModel(
                  id: existing?.id ?? 'obj_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text,
                  type: existing?.type ?? 'host',
                  values: valCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  description: existing?.description ?? 'Skapad i GUI',
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
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 460.0),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dialogTitleRow(context, existing != null ? 'Redigera Grupp' : 'Skapa ny Grupp', () => Navigator.pop(ctx)),
                const SizedBox(height: 12),
                dialogSection(title: 'GRUPP', children: [
                  dialogField(nameCtrl, 'Gruppnamn'),
                ]),
                const SizedBox(height: 12),
                const Text('MEDLEMMAR', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                if (candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Skapa först några objekt (host/nätverk) att gruppera.', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
                              ? 'grupp: ${_groupMemberNames(context, o)}'
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
                            title: Text(o.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            subtitle: Text(
                              subtitle,
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
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
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
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
                                  name: nameCtrl.text.trim().isEmpty ? 'Ny grupp' : nameCtrl.text.trim(),
                                  type: 'group',
                                  values: selected.toList(),
                                  description: existing?.description ?? 'Grupp skapad i GUI',
                                );
                                final updatedObjs = existing != null
                                    ? c.objects.map((o) => o.id == existing.id ? savedObj : o).toList()
                                    : (List<ObjectModel>.from(c.objects)..add(savedObj));
                                provider.updateCandidate(c.copyWith(objects: updatedObjs));
                              }
                              Navigator.pop(ctx);
                            },
                      child: const Text('Spara', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 460.0),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dialogTitleRow(context, existing != null ? 'Redigera Hot-lista / GeoIP-objekt' : 'Lägg till Hot-lista / GeoIP-objekt', () => Navigator.pop(ctx)),
                const SizedBox(height: 12),
                dialogSection(title: 'KÄLLA', children: [
                  dialogField(nameCtrl, 'Objektnamn'),
                  const SizedBox(height: 12),
                  const Text('Källtyp', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'spamhaus_drop', child: Text('Spamhaus DROP (kända spam/botnät-nät)')),
                      DropdownMenuItem(value: 'spamhaus_edrop', child: Text('Spamhaus EDROP (utökad DROP)')),
                      DropdownMenuItem(value: 'tor_exit_nodes', child: Text('Tor-exit-noder')),
                      DropdownMenuItem(value: 'custom_url', child: Text('Anpassad URL (en CIDR/IP per rad)')),
                      DropdownMenuItem(value: 'geoip_country', child: Text('GeoIP — helt land (landskod)')),
                    ],
                    onChanged: (v) => setDialogState(() => kind = v ?? kind),
                  ),
                  const SizedBox(height: 12),
                  if (kind == 'custom_url') dialogField(urlCtrl, 'URL', hint: 'https://exempel.se/blocklist.txt'),
                  if (kind == 'geoip_country') dialogField(countryCtrl, 'Landskod (ISO 3166-1 alpha-2)', hint: 't.ex. RU, CN, KP'),
                  if (kind == 'custom_url' || kind == 'geoip_country') const SizedBox(height: 12),
                  dialogField(refreshHoursCtrl, 'Uppdateringsintervall (timmar)', hint: '24'),
                ]),
                const SizedBox(height: 6),
                const Text(
                  'Listan hämtas automatiskt av brandväggen enligt intervallet ovan. Innehållet syns här efter första hämtningen (kan ta en liten stund).',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 10),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
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
                          description: existing?.description ?? 'Automatiskt uppdaterad (${_kindLabel(kind)})',
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
