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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.category, color: Colors.cyanAccent, size: 22),
                    SizedBox(width: 10),
                    Text('Objekt & Grupper', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.dns, size: 14),
                      label: const Text('+ Skapa Objekt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                      onPressed: () => _showAddObjectDialog(context, provider),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.shield, size: 14),
                      label: const Text('+ Hot-lista / GeoIP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                      onPressed: () => _showAddThreatFeedDialog(context, provider),
                    ),
                  ],
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
              subtitle: Text(
                src != null
                    ? 'Typ: ${obj.type.toUpperCase()}  |  ${obj.values.length} poster (automatisk källa: ${_kindLabel(src.kind)})'
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
    await provider.updateCandidate(ConfigModel(
      version: cfg.version,
      revision: cfg.revision,
      updatedAt: cfg.updatedAt,
      interfaces: cfg.interfaces,
      zones: cfg.zones,
      objects: updatedObjs,
      services: cfg.services,
      policies: cfg.policies,
      settings: cfg.settings,
      wireguard: cfg.wireguard,
      openvpn: cfg.openvpn,
      dns: cfg.dns,
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
          width: 440,
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
                provider.updateCandidate(ConfigModel(
                  version: cfg.version,
                  revision: cfg.revision,
                  updatedAt: cfg.updatedAt,
                  interfaces: cfg.interfaces,
                  zones: cfg.zones,
                  objects: updatedObjs,
                  services: cfg.services,
                  policies: cfg.policies,
                  settings: cfg.settings,
                  wireguard: cfg.wireguard,
                  openvpn: cfg.openvpn,
                  dns: cfg.dns,
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
            width: 460,
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
                        await provider.updateCandidate(ConfigModel(
                          version: cfg.version,
                          revision: cfg.revision,
                          updatedAt: cfg.updatedAt,
                          interfaces: cfg.interfaces,
                          zones: cfg.zones,
                          objects: updatedObjs,
                          services: cfg.services,
                          policies: cfg.policies,
                          settings: cfg.settings,
                          wireguard: cfg.wireguard,
                          openvpn: cfg.openvpn,
                          dns: cfg.dns,
                        ));
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
