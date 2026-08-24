import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../widgets/dialog_helpers.dart';

class InterfacesScreen extends StatelessWidget {
  const InterfacesScreen({super.key});

  List<DropdownMenuItem<String>> _getZoneDropdownItems(ConfigModel? cfg) {
    // Byggs från configens FAKTISKA zoner (cfg.zones) — inte en hårdkodad
    // lista. Tidigare visades SERVERS/IOT/GUEST/VPN alltid, även efter att man
    // tagit bort dem via "Hantera zoner". Beskrivningen tas från zonen själv.
    final Map<String, String> itemsMap = {};

    if (cfg != null) {
      for (final z in cfg.zones) {
        final name = z.name.toUpperCase();
        final desc = z.description.trim();
        itemsMap[name] = desc.isNotEmpty ? '$name ($desc)' : name;
      }
      // Defensivt: en zon som ett gränssnitt redan använder men som (av någon
      // anledning) saknas i zonlistan ska ändå gå att välja/behålla.
      for (final i in cfg.interfaces) {
        if (i.zone.isNotEmpty) {
          itemsMap.putIfAbsent(i.zone.toUpperCase(), () => '${i.zone.toUpperCase()} (Aktiv zon)');
        }
      }
    }

    // Om inga zoner alls är definierade (t.ex. innan configen hämtats) — visa
    // åtminstone de två grundläggande så dropdownen aldrig är tom.
    if (itemsMap.isEmpty) {
      itemsMap['LAN'] = 'LAN (Internt nätverk)';
      itemsMap['WAN'] = 'WAN (Utsida / Internet)';
    }

    final list = itemsMap.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList();

    list.add(const DropdownMenuItem(
      value: 'CUSTOM',
      child: Text('+ Skapa ny / Anpassad zon...', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
    ));

    return list;
  }

  bool _zoneExistsInMenu(String zone, ConfigModel? cfg) {
    final z = zone.toUpperCase();
    if (cfg != null) {
      if (cfg.zones.any((x) => x.name.toUpperCase() == z)) return true;
      if (cfg.interfaces.any((i) => i.zone.toUpperCase() == z)) return true;
    }
    return false;
  }

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
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Wrap i stället för Row+spaceBetween: titeln + två knappar
            // overflowade tyst på en telefonskärm (upptäckt 2026-08-24).
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text(
                  'Nätverksgränssnitt & VLAN',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.category_outlined, size: 14),
                  label: const Text('Hantera zoner', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: cfg == null ? null : () => _showManageZonesDialog(context, provider, cfg),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.alt_route, size: 14),
                  label: const Text('+ Skapa VLAN', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _showAddVLANDialog(context, provider),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (cfg != null && cfg.interfaces.isEmpty)
              const Card(
                color: Color(0xFF1E293B),
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('Inga konfigurerade gränssnitt ännu.', style: TextStyle(color: Colors.grey, fontSize: 11))),
                ),
              )
            else if (cfg != null)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cfg.interfaces.length,
                itemBuilder: (context, idx) {
                  final iface = cfg.interfaces[idx];
                  final isVLAN = iface.vlanId > 0;
                  final isWAN = iface.zone == 'WAN';
                  final isStatic = iface.addressType == 'static';

                  return Card(
                    color: const Color(0xFF1E293B),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      dense: true,
                      leading: Icon(
                        isVLAN ? Icons.alt_route : Icons.router,
                        size: 18,
                        color: isWAN ? Colors.redAccent : Colors.tealAccent,
                      ),
                      title: Text(
                        '${iface.name.isNotEmpty ? iface.name : iface.device}${isVLAN ? " [VLAN ${iface.vlanId}]" : ""}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Kort: ${iface.device}  |  Zon: ${iface.zone}  |  Typ: ${isStatic ? "Statisk IP (${iface.ipv4})" : "DHCP-Klient${iface.ipv4.isNotEmpty ? " (${iface.ipv4})" : ""}"}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.cyanAccent, size: 16),
                            tooltip: 'Redigera gränssnitt',
                            onPressed: () => _showEditInterfaceDialog(context, provider, cfg, idx),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                            tooltip: 'Ta bort gränssnitt',
                            onPressed: () => _deleteInterface(context, provider, cfg, idx),
                          ),
                          Switch(
                            value: iface.enabled,
                            activeThumbColor: Colors.tealAccent,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) {
                              _toggleInterface(provider, cfg, idx, val);
                            },
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  Chip(
                                    label: Text('Adressering: ${isStatic ? "STATISK IP" : "DHCP-KLIENT"}', style: TextStyle(color: isStatic ? Colors.lightBlueAccent : Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                    backgroundColor: isStatic ? Colors.lightBlueAccent.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (iface.ipv4.isNotEmpty)
                                    Chip(
                                      label: Text('${isWAN ? "Extern IP" : "IP"}: ${_cidrAddress(iface.ipv4)}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (iface.ipv4.contains('/'))
                                    Chip(
                                      label: Text('Subnät: ${iface.ipv4} (${_cidrNetmask(iface.ipv4)})', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (iface.gateway.isNotEmpty)
                                    Chip(
                                      label: Text('Gateway: ${iface.gateway}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (iface.dnsServers.isNotEmpty)
                                    Chip(
                                      label: Text('DNS: ${iface.dnsServers.join(", ")}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                      backgroundColor: Colors.cyanAccent.withValues(alpha: 0.15),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (isWAN) ...[
                                Row(
                                  children: const [
                                    Icon(Icons.shield_outlined, color: Colors.amber, size: 16),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'WAN-gränssnitt: Kan köras som DHCP-klient eller Statisk IP med valfria DNS-servrar.',
                                        style: TextStyle(color: Colors.amber, fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      'DHCP Server: ${iface.dhcp != null && iface.dhcp!.enabled ? "AKTIV" : "AVSTÄNGD"}',
                                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    // Snabb av/på utan att behöva öppna
                                    // dialogen — den kunde tidigare bara
                                    // SÄTTA PÅ DHCP (dialogens Spara skrev
                                    // alltid enabled:true), det fanns ingen
                                    // väg alls att stänga av den igen
                                    // (upptäckt 2026-08-24, efterfrågad av
                                    // en administratör). Kräver att scopet
                                    // redan konfigurerats minst en gång
                                    // (iface.dhcp != null) — annars finns
                                    // inget IP-pool/gateway att slå på.
                                    if (iface.dhcp != null)
                                      Switch(
                                        value: iface.dhcp!.enabled,
                                        activeThumbColor: Colors.tealAccent,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (v) {
                                          final updatedDhcp = DHCPConfigModel(
                                            enabled: v,
                                            rangeStart: iface.dhcp!.rangeStart,
                                            rangeEnd: iface.dhcp!.rangeEnd,
                                            gateway: iface.dhcp!.gateway,
                                            dnsServers: iface.dhcp!.dnsServers,
                                            leaseTimeSec: iface.dhcp!.leaseTimeSec,
                                            reservations: iface.dhcp!.reservations,
                                          );
                                          final updated = List<InterfaceModel>.from(cfg.interfaces);
                                          updated[idx] = iface.copyWith(dhcp: updatedDhcp);
                                          provider.updateCandidate(cfg.copyWith(interfaces: updated));
                                        },
                                      ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.settings_ethernet, size: 14),
                                      label: const Text('Konfigurera DHCP Scope', style: TextStyle(fontSize: 10)),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                      onPressed: () => _showDHCPDialog(context, provider, cfg, idx),
                                    ),
                                  ],
                                ),
                                if (iface.dhcp != null && iface.dhcp!.enabled) ...[
                                  const SizedBox(height: 4),
                                  Text('IP Pool: ${iface.dhcp!.rangeStart} - ${iface.dhcp!.rangeEnd}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                  Text('Klient DNS: ${iface.dhcp!.dnsServers.join(", ")}  |  Gateway: ${iface.dhcp!.gateway}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            if (cfg != null) _buildDiscoveredSection(context, provider, cfg),
          ],
        ),
      ),
    );
  }

  // Visar fysiska nätverkskort som FINNS på systemet men ännu inte är
  // konfigurerade (t.ex. ett kort man precis satt i). De dyker upp
  // automatiskt men aktiveras INTE av sig själva — användaren måste själv
  // lägga till och aktivera dem.
  Widget _buildDiscoveredSection(BuildContext context, ConfigProvider provider, ConfigModel cfg) {
    return FutureBuilder<List<dynamic>>(
      future: provider.api.discoverInterfaces(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final configured = cfg.interfaces.map((i) => i.device).toSet();
        // Virtuella gränssnitt (VPN-tunnlar, docker, bryggor, veth m.m.) är
        // inte fysiska nätverkskort och ska inte erbjudas som sådana. wg0
        // (WireGuard) och tun0 (OpenVPN) skapas t.ex. av brandväggen själv.
        bool isVirtual(String n) => n.startsWith('wg') ||
            n.startsWith('tun') ||
            n.startsWith('tap') ||
            n.startsWith('docker') ||
            n.startsWith('veth') ||
            n.startsWith('br-') ||
            n.startsWith('virbr') ||
            n.startsWith('bond') ||
            n.startsWith('kube') ||
            n.startsWith('cni') ||
            n.startsWith('flannel') ||
            n == 'docker0';
        // Bara fysiska kort (inte loopback, inte VLAN, inte virtuella) som
        // inte redan är i konfigurationen.
        final newNics = snap.data!.where((d) {
          final name = (d['name'] ?? '').toString();
          final isLoop = d['is_loopback'] == true;
          final isVlan = d['is_vlan'] == true;
          return name.isNotEmpty && !isLoop && !isVlan && !isVirtual(name) && !configured.contains(name);
        }).toList();
        if (newNics.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              children: const [
                Icon(Icons.new_releases_outlined, size: 16, color: Colors.amberAccent),
                SizedBox(width: 6),
                Text('Nya nätverkskort (ej konfigurerade)',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Kort som hittats på systemet men ännu inte lagts till. De aktiveras inte automatiskt.',
                style: TextStyle(color: Colors.white54, fontSize: 10)),
            const SizedBox(height: 8),
            ...newNics.map((d) {
              final name = (d['name'] ?? '').toString();
              final mac = (d['mac'] ?? '').toString();
              final isUp = d['is_up'] == true;
              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: Colors.amberAccent.withValues(alpha: 0.35)),
                ),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.settings_ethernet, size: 18, color: Colors.amberAccent),
                  title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('MAC: ${mac.isEmpty ? "—" : mac}  |  Länk: ${isUp ? "uppe" : "nere"}  |  Ej konfigurerad',
                      style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Lägg till', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                    onPressed: () {
                      // Läggs till som INAKTIVERAT — användaren aktiverar och
                      // konfigurerar det själv efteråt.
                      final newIface = InterfaceModel(
                        id: 'if_${DateTime.now().millisecondsSinceEpoch}',
                        device: name,
                        zone: 'LAN',
                        enabled: false,
                        addressType: 'dhcp',
                        ipv4: '',
                      );
                      final updated = List<InterfaceModel>.from(cfg.interfaces)..add(newIface);
                      provider.updateCandidate(cfg.copyWith(interfaces: updated));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$name tillagt (inaktiverat) — öppna det för att aktivera och konfigurera.')),
                      );
                    },
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _showEditInterfaceDialog(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx) {
    final iface = cfg.interfaces[idx];
    final isVLAN = iface.vlanId > 0;
    String selectedType = iface.addressType;
    String selectedParent = iface.parent;
    // Fysiska kort (icke-VLAN) som en VLAN kan höra till.
    final physicalDevices = cfg.interfaces
        .where((i) => i.vlanId == 0 && i.device.isNotEmpty)
        .map((i) => i.device)
        .toSet()
        .toList()
      ..sort();
    if (selectedParent.isNotEmpty && !physicalDevices.contains(selectedParent)) {
      physicalDevices.add(selectedParent);
    }
    final nameCtrl = TextEditingController(text: iface.name);
    final ipCtrl = TextEditingController(text: iface.ipv4);
    final gwCtrl = TextEditingController(text: iface.gateway);
    final dnsCtrl = TextEditingController(text: iface.dnsServers.join(', '));
    
    String selectedZonePreset = iface.zone.isEmpty ? 'LAN' : iface.zone.toUpperCase();
    final customZoneCtrl = TextEditingController(text: _zoneExistsInMenu(selectedZonePreset, cfg) ? '' : iface.zone);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 480.0),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  dialogTitleRow(context, 'Redigera ${iface.name.isNotEmpty ? iface.name : iface.device}', () => Navigator.pop(ctx)),
                  const SizedBox(height: 12),

                  dialogSection(title: 'VISNINGSNAMN', children: [
                    dialogField(nameCtrl, 'Namn (valfritt)', hint: 't.ex. LAN Kontor, Servernät — kort: ${iface.device}'),
                  ]),
                  const SizedBox(height: 12),

                  if (isVLAN) ...[
                    dialogSection(title: 'FYSISKT KORT (VLAN ${iface.vlanId})', children: [
                      DropdownButtonFormField<String>(
                        initialValue: physicalDevices.contains(selectedParent) ? selectedParent : (physicalDevices.isNotEmpty ? physicalDevices.first : null),
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(
                          labelText: 'Föräldrakort',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                        items: physicalDevices.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedParent = val);
                        },
                      ),
                      const SizedBox(height: 6),
                      Text('Byter du kort flyttas VLAN ${iface.vlanId} till "$selectedParent.${iface.vlanId}" vid Applicera. Det gamla subinterfacet tas bort automatiskt.',
                          style: const TextStyle(color: Colors.amber, fontSize: 10)),
                    ]),
                    const SizedBox(height: 12),
                  ],

                  dialogSection(title: 'ADRESSERINGSTYP', children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'static', label: Text('Statisk IP', style: TextStyle(fontSize: 11)), icon: Icon(Icons.pin, size: 14)),
                        ButtonSegment(value: 'dhcp', label: Text('DHCP Klient', style: TextStyle(fontSize: 11)), icon: Icon(Icons.sync, size: 14)),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (val) => setState(() => selectedType = val.first),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  dialogSection(title: 'NÄTVERK', children: [
                    if (selectedType == 'static') ...[
                      dialogField(ipCtrl, 'IPv4 / CIDR', hint: 't.ex. 192.168.1.1/24'),
                      const SizedBox(height: 12),
                    ],
                    dialogField(gwCtrl, 'Default Gateway IP (Valfri)'),
                    const SizedBox(height: 12),
                    dialogField(dnsCtrl, 'DNS-servrar', hint: 't.ex. 1.1.1.1, 8.8.8.8'),
                  ]),
                  const SizedBox(height: 12),

                  dialogSection(title: 'ZON', children: [
                    DropdownButtonFormField<String>(
                      initialValue: _zoneExistsInMenu(selectedZonePreset, cfg) ? selectedZonePreset : 'CUSTOM',
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Tilldelad Zon',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      items: _getZoneDropdownItems(cfg),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedZonePreset = val);
                      },
                    ),
                    if (selectedZonePreset == 'CUSTOM') ...[
                      const SizedBox(height: 12),
                      dialogField(customZoneCtrl, 'Ange nytt Zon-namn', hint: 't.ex. DMZ, MANAGEMENT, CAMERAS'),
                    ],
                  ]),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        child: const Text('Spara Ändringar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                final dnsList = dnsCtrl.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                final finalZone = selectedZonePreset == 'CUSTOM'
                    ? customZoneCtrl.text.trim().toUpperCase()
                    : selectedZonePreset;

                final updatedZones = List<ZoneModel>.from(cfg.zones);
                if (finalZone.isNotEmpty && !updatedZones.any((z) => z.name.toUpperCase() == finalZone)) {
                  updatedZones.add(ZoneModel(
                    name: finalZone,
                    description: 'Egen skapad zon',
                  ));
                }

                final updated = List<InterfaceModel>.from(cfg.interfaces);
                // För en VLAN härleds device ur föräldrakort + VLAN-ID, så
                // att ett byte av föräldrakort verkligen slår igenom (t.ex.
                // ens19.9 → ens20.9). Fysiska kort behåller sitt device.
                final newDevice = isVLAN ? '$selectedParent.${iface.vlanId}' : iface.device;
                updated[idx] = InterfaceModel(
                  id: iface.id,
                  name: nameCtrl.text.trim(),
                  device: newDevice,
                  parent: isVLAN ? selectedParent : iface.parent,
                  vlanId: iface.vlanId,
                  zone: finalZone,
                  enabled: iface.enabled,
                  addressType: selectedType,
                  ipv4: selectedType == 'static' ? ipCtrl.text : '',
                  gateway: gwCtrl.text,
                  dnsServers: dnsList,
                  mtu: iface.mtu,
                  dhcp: iface.dhcp,
                );
                provider.updateCandidate(cfg.copyWith(
                  interfaces: updated,
                  zones: updatedZones,
                ));
                Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Tar bort ett gränssnitt HELT ur konfigurationen (till skillnad från
  // av/på-brytaren som bara inaktiverar det). Backend av-konfigurerar det
  // borttagna kortet vid apply: ett VLAN-subinterface rivs, ett fysiskt kort
  // får sin IP och ev. default-rutt bortflushad (se engine.applyInterfaces).
  // Zonen lämnas kvar — den städas separat via "Hantera zoner" om den blir
  // oanvänd. Ändringen sparas i candidate och slår igenom först när
  // användaren applicerar (Safe Apply).
  void _deleteInterface(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx) {
    final iface = cfg.interfaces[idx];
    final label = iface.name.isNotEmpty ? iface.name : iface.device;
    final isVLAN = iface.vlanId > 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Ta bort gränssnitt "$label"?', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          isVLAN
              ? 'VLAN-gränssnittet ${iface.device} tas bort ur konfigurationen och rivs från systemet vid nästa applicering. Enheter på det VLAN:et förlorar sin gateway.'
              : 'Gränssnittet ${iface.device} tas bort ur konfigurationen. Vid applicering flushas dess IP-adress och ev. default-rutt.\n\n'
                  'VARNING: Om detta är kortet du administrerar brandväggen genom (t.ex. LAN med management-IP) blir du UTELÅST via nätverket. Ta bort själva det virtuella kortet i hypervisorn separat om du vill städa helt.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Ta bort', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              final updatedIfaces = List<InterfaceModel>.from(cfg.interfaces)..removeAt(idx);
              provider.updateCandidate(cfg.copyWith(interfaces: updatedIfaces));
            },
          ),
        ],
      ),
    );
  }

  void _toggleInterface(ConfigProvider provider, ConfigModel cfg, int idx, bool enabled) {
    final updatedIfaces = List<InterfaceModel>.from(cfg.interfaces);
    final cur = updatedIfaces[idx];
    updatedIfaces[idx] = InterfaceModel(
      id: cur.id,
      name: cur.name,
      device: cur.device,
      parent: cur.parent,
      vlanId: cur.vlanId,
      zone: cur.zone,
      enabled: enabled,
      addressType: cur.addressType,
      ipv4: cur.ipv4,
      gateway: cur.gateway,
      dnsServers: cur.dnsServers,
      mtu: cur.mtu,
      dhcp: cur.dhcp,
    );
    provider.updateCandidate(cfg.copyWith(
      interfaces: updatedIfaces,
    ));
  }

  void _showAddVLANDialog(BuildContext context, ConfigProvider provider) {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    final parentCtrl = TextEditingController(text: 'ens19');
    final vlanIdCtrl = TextEditingController(text: '10');
    String selectedZonePreset = 'SERVERS';
    final customZoneCtrl = TextEditingController(text: '');
    final ipCtrl = TextEditingController(text: '192.168.10.1/24');
    final dnsCtrl = TextEditingController(text: '1.1.1.1, 8.8.8.8');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 480.0),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Skapa nytt Linux VLAN', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  dialogSection(title: 'GRUNDUPPGIFTER', children: [
                    dialogField(parentCtrl, 'Föräldra-interface (parent)'),
                    const SizedBox(height: 12),
                    dialogField(vlanIdCtrl, 'VLAN ID (1-4094)'),
                  ]),
                  const SizedBox(height: 12),

                  dialogSection(title: 'ZON', children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedZonePreset,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Tilldelad zon',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      items: _getZoneDropdownItems(cfg),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedZonePreset = val);
                      },
                    ),
                    if (selectedZonePreset == 'CUSTOM') ...[
                      const SizedBox(height: 12),
                      dialogField(customZoneCtrl, 'Ange nytt zon-namn', hint: 't.ex. DMZ, MANAGEMENT, CAMERAS'),
                    ],
                  ]),
                  const SizedBox(height: 12),

                  dialogSection(title: 'NÄTVERK', children: [
                    dialogField(ipCtrl, 'Statisk IPv4/CIDR', hint: 't.ex. 192.168.10.1/24'),
                    const SizedBox(height: 12),
                    dialogField(dnsCtrl, 'DNS-servrar', hint: 't.ex. 1.1.1.1, 8.8.8.8'),
                  ]),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        child: const Text('Skapa VLAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                if (cfg != null) {
                  final vlanId = int.tryParse(vlanIdCtrl.text) ?? 10;
                  final dev = '${parentCtrl.text}.$vlanId';
                  final dnsList = dnsCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  final finalZone = selectedZonePreset == 'CUSTOM'
                      ? customZoneCtrl.text.trim().toUpperCase()
                      : selectedZonePreset;

                  final updatedZones = List<ZoneModel>.from(cfg.zones);
                  if (finalZone.isNotEmpty && !updatedZones.any((z) => z.name.toUpperCase() == finalZone)) {
                    updatedZones.add(ZoneModel(
                      name: finalZone,
                      description: 'Egen skapad zon',
                    ));
                  }

                  final newIface = InterfaceModel(
                    id: 'vlan$vlanId',
                    device: dev,
                    parent: parentCtrl.text,
                    vlanId: vlanId,
                    zone: finalZone,
                    enabled: true,
                    addressType: 'static',
                    ipv4: ipCtrl.text,
                    dnsServers: dnsList,
                  );
                  final updated = List<InterfaceModel>.from(cfg.interfaces)..add(newIface);
                  provider.updateCandidate(cfg.copyWith(
                    interfaces: updated,
                    zones: updatedZones,
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
        ),
      ),
    );
  }

  void _showDHCPDialog(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx) {
    final iface = cfg.interfaces[idx];
    final dhcp = iface.dhcp;

    final startCtrl = TextEditingController(text: dhcp?.rangeStart ?? '192.168.10.100');
    final endCtrl = TextEditingController(text: dhcp?.rangeEnd ?? '192.168.10.200');
    final gwCtrl = TextEditingController(text: dhcp?.gateway ?? '192.168.10.1');
    final dnsCtrl = TextEditingController(text: dhcp != null && dhcp.dnsServers.isNotEmpty ? dhcp.dnsServers.join(', ') : '192.168.10.1, 1.1.1.1');

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('DHCP-inställningar för ${iface.id}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              dialogSection(title: 'IP-POOL', children: [
                dialogField(startCtrl, 'Start IP pool'),
                const SizedBox(height: 12),
                dialogField(endCtrl, 'Slut IP pool'),
              ]),
              const SizedBox(height: 12),

              dialogSection(title: 'NÄTVERK', children: [
                dialogField(gwCtrl, 'Standard gateway'),
                const SizedBox(height: 12),
                dialogField(dnsCtrl, 'DNS-servrar', hint: 'komma-separerade'),
              ]),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    child: const Text('Spara DHCP Scope', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
              final newDHCP = DHCPConfigModel(
                // Bevarar det befintliga på/av-läget (satt via
                // snabbknappen på gränssnittskortet) i stället för att
                // alltid tvinga på DHCP igen bara för att man öppnar
                // dialogen och sparar ett IP-pool-scope — annars hade
                // "Spara" av misstag återaktiverat en medvetet avstängd
                // DHCP-server. Standard true för ett HELT NYTT scope
                // (dhcp var null innan), precis som tidigare.
                enabled: dhcp?.enabled ?? true,
                rangeStart: startCtrl.text,
                rangeEnd: endCtrl.text,
                gateway: gwCtrl.text,
                dnsServers: dnsCtrl.text.split(',').map((e) => e.trim()).toList(),
                reservations: dhcp?.reservations ?? [],
              );
              final updated = List<InterfaceModel>.from(cfg.interfaces);
              updated[idx] = InterfaceModel(
                id: iface.id,
                name: iface.name,
                device: iface.device,
                parent: iface.parent,
                vlanId: iface.vlanId,
                zone: iface.zone,
                enabled: iface.enabled,
                addressType: iface.addressType,
                ipv4: iface.ipv4,
                gateway: iface.gateway,
                dnsServers: iface.dnsServers,
                mtu: iface.mtu,
                dhcp: newDHCP,
              );
              provider.updateCandidate(cfg.copyWith(
                interfaces: updated,
              ));
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

  // ---- Zon-hantering (döp om / ta bort) ----

  /// Alla zonnamn (versaler), unionen av cfg.zones och de zoner som
  /// gränssnitten faktiskt använder — sorterade.
  List<String> _allZoneNames(ConfigModel cfg) {
    final set = <String>{};
    for (final z in cfg.zones) {
      if (z.name.trim().isNotEmpty) set.add(z.name.trim().toUpperCase());
    }
    for (final i in cfg.interfaces) {
      if (i.zone.trim().isNotEmpty) set.add(i.zone.trim().toUpperCase());
    }
    final list = set.toList()..sort();
    return list;
  }

  int _zoneUsageCount(ConfigModel cfg, String zone) =>
      cfg.interfaces.where((i) => i.zone.toUpperCase() == zone.toUpperCase()).length;

  void _showManageZonesDialog(BuildContext context, ConfigProvider provider, ConfigModel cfg) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final current = provider.candidateConfig ?? provider.runningConfig ?? cfg;
          final zones = _allZoneNames(current);
          return Dialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            child: Container(
              width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 480.0),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  dialogTitleRow(context, 'Hantera zoner', () => Navigator.pop(ctx)),
                  const SizedBox(height: 8),
                  const Text(
                    'WAN kan inte döpas om eller tas bort — brandväggen använder namnet "WAN" internt för utsida, NAT och drop-regler.',
                    style: TextStyle(color: Colors.amber, fontSize: 10),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: SingleChildScrollView(
                      child: Column(
                        children: zones.map((zone) {
                          final usage = _zoneUsageCount(current, zone);
                          final isWAN = zone == 'WAN';
                          return Card(
                            color: const Color(0xFF0F172A),
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              title: Text(zone, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: Text('$usage gränssnitt använder zonen', style: const TextStyle(fontSize: 10)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, size: 16, color: isWAN ? Colors.grey : Colors.cyanAccent),
                                    tooltip: isWAN ? 'WAN kan inte döpas om' : 'Döp om zon',
                                    onPressed: isWAN ? null : () => _promptRenameZone(context, provider, zone, () => setState(() {})),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, size: 16, color: (isWAN || usage > 0) ? Colors.grey : Colors.redAccent),
                                    tooltip: isWAN
                                        ? 'WAN kan inte tas bort'
                                        : (usage > 0 ? 'Zonen används av $usage gränssnitt — flytta dem först' : 'Ta bort zon'),
                                    onPressed: (isWAN || usage > 0) ? null : () => _deleteZone(context, provider, zone, () => setState(() {})),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _promptRenameZone(BuildContext context, ConfigProvider provider, String oldZone, VoidCallback onDone) {
    final ctrl = TextEditingController(text: oldZone);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Döp om zon "$oldZone"', style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: dialogField(ctrl, 'Nytt zonnamn', hint: 't.ex. DMZ, KAMEROR'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
          ElevatedButton(
            child: const Text('Spara', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () {
              final newZone = ctrl.text.trim().toUpperCase();
              Navigator.pop(ctx);
              if (newZone.isEmpty || newZone == oldZone) return;
              if (newZone == 'WAN') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Namnet WAN är reserverat.')),
                );
                return;
              }
              _renameZone(provider, oldZone, newZone);
              onDone();
            },
          ),
        ],
      ),
    );
  }

  void _renameZone(ConfigProvider provider, String oldZone, String newZone) {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    if (cfg == null) return;
    final oldU = oldZone.toUpperCase();

    // Zoner
    final zones = cfg.zones.map((z) => z.name.toUpperCase() == oldU ? ZoneModel(name: newZone, description: z.description) : z).toList();
    // Se till att den nya zonen finns i listan (om gamla bara var en implicit interface-zon).
    if (!zones.any((z) => z.name.toUpperCase() == newZone)) {
      zones.add(ZoneModel(name: newZone, description: 'Egen zon'));
    }

    // Gränssnitt
    final ifaces = cfg.interfaces.map((i) => i.zone.toUpperCase() == oldU ? i.copyWith(zone: newZone) : i).toList();

    // Policyer: byt ut den kommaseparerade delen som matchar gamla zonen.
    final policies = cfg.policies.map((p) {
      final sz = _replaceZonePart(p.sourceZone, oldU, newZone);
      final dz = _replaceZonePart(p.destZone, oldU, newZone);
      if (sz == p.sourceZone && dz == p.destZone) return p;
      return p.copyWith(sourceZone: sz, destZone: dz);
    }).toList();

    provider.updateCandidate(cfg.copyWith(zones: zones, interfaces: ifaces, policies: policies));
  }

  /// Byter ut en enskild kommaseparerad zon-del (skiftlägesokänsligt) mot
  /// newZone, behåller övriga delar. Tomt/ANY lämnas orört.
  String _replaceZonePart(String spec, String oldU, String newZone) {
    if (spec.trim().isEmpty) return spec;
    final parts = spec.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    var changed = false;
    final out = parts.map((part) {
      if (part.toUpperCase() == oldU) {
        changed = true;
        return newZone;
      }
      return part;
    }).toList();
    return changed ? out.join(', ') : spec;
  }

  void _deleteZone(BuildContext context, ConfigProvider provider, String zone, VoidCallback onDone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Ta bort zon "$zone"?', style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: const Text(
          'Zonen tas bort ur listan och plockas ut ur alla regler som refererar den. Regler som då saknar käll-/målzon återgår till ANY.',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Ta bort', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              final cfg = provider.candidateConfig ?? provider.runningConfig;
              if (cfg == null) return;
              final zU = zone.toUpperCase();
              final zones = cfg.zones.where((z) => z.name.toUpperCase() != zU).toList();
              final policies = cfg.policies.map((p) {
                final sz = _removeZonePart(p.sourceZone, zU);
                final dz = _removeZonePart(p.destZone, zU);
                if (sz == p.sourceZone && dz == p.destZone) return p;
                return p.copyWith(sourceZone: sz, destZone: dz);
              }).toList();
              provider.updateCandidate(cfg.copyWith(zones: zones, policies: policies));
              onDone();
            },
          ),
        ],
      ),
    );
  }

  /// Tar bort en kommaseparerad zon-del; blir resultatet tomt återgår det
  /// till "ANY" (annars skulle en tom zonsträng tolkas som "matcha inget"
  /// och regeln tyst hoppas över i backend).
  String _removeZonePart(String spec, String zU) {
    if (spec.trim().isEmpty) return spec;
    final parts = spec.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final kept = parts.where((p) => p.toUpperCase() != zU).toList();
    if (kept.length == parts.length) return spec; // ingen ändring
    return kept.isEmpty ? 'ANY' : kept.join(', ');
  }

  /// Adressen ur ett "x.x.x.x/yy"-CIDR-uttryck, utan prefixlängden.
  String _cidrAddress(String cidr) => cidr.split('/').first;

  /// Nätmasken (t.ex. "255.255.255.0") som motsvarar CIDR-prefixlängden
  /// i ett "x.x.x.x/yy"-uttryck. Returnerar tom sträng om formatet inte
  /// kan tolkas.
  String _cidrNetmask(String cidr) {
    final parts = cidr.split('/');
    if (parts.length != 2) return '';
    final prefix = int.tryParse(parts[1]);
    if (prefix == null || prefix < 0 || prefix > 32) return '';
    final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    return [24, 16, 8, 0].map((shift) => (mask >> shift) & 0xFF).join('.');
  }
}
