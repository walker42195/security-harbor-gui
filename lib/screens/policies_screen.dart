import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';

class PoliciesScreen extends StatefulWidget {
  const PoliciesScreen({super.key});

  @override
  State<PoliciesScreen> createState() => _PoliciesScreenState();
}

const List<String> _policyColLabels = ['#', 'Action', 'Policy Name', 'Type / Service', 'From (Källa)', 'To (Mål)', 'Port', 'Åtgärder'];
const List<double> _policyDefaultColWidths = [28, 70, 160, 90, 150, 150, 70, 100];
const double _policyColMinWidth = 28;
const double _policyResizeHandleWidth = 8;

class _PoliciesScreenState extends State<PoliciesScreen> {
  int? _selectedRowIndex;
  final List<double> _colWidths = List<double>.from(_policyDefaultColWidths);
  final ScrollController _hScrollController = ScrollController();

  @override
  void dispose() {
    _hScrollController.dispose();
    super.dispose();
  }

  double get _totalTableWidth => _colWidths.fold(0.0, (sum, w) => sum + w) + _policyResizeHandleWidth * _colWidths.length;

  Widget _resizeHandle(int colIndex) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          setState(() {
            _colWidths[colIndex] = (_colWidths[colIndex] + details.delta.dx).clamp(_policyColMinWidth, 900.0);
          });
        },
        child: SizedBox(
          width: _policyResizeHandleWidth,
          child: const Center(child: VerticalDivider(color: Color(0xFF334155), thickness: 1, width: 1)),
        ),
      ),
    );
  }

  Widget _buildPolicyHeaderRow() {
    return Row(
      children: [
        for (int i = 0; i < _colWidths.length; i++) ...[
          SizedBox(
            width: _colWidths[i],
            child: Text(_policyColLabels[i], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ),
          _resizeHandle(i),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final cfg = provider.candidateConfig ?? provider.runningConfig;

    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Verktygsfält (Toolbar) för Policy Hantering
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Colors.cyanAccent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Firewall Policies & Rules',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16, color: Colors.cyanAccent),
                  label: const Text('Ny Policy', style: TextStyle(fontSize: 12, color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    side: const BorderSide(color: Colors.cyanAccent),
                  ),
                  onPressed: () => _showEditPolicyDialog(context, provider, cfg, null),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.input, size: 16, color: Colors.lightBlueAccent),
                  label: const Text('+ Port Forwarding (DNAT)', style: TextStyle(fontSize: 12, color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    side: const BorderSide(color: Colors.lightBlueAccent),
                  ),
                  onPressed: () => _showAddDNATDialog(context, provider),
                ),
              ],
            ),
          ),

          // Huvudtabell (WatchGuard-style Data Grid)
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border.all(color: const Color(0xFF334155)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: (cfg == null || cfg.policies.isEmpty)
                  ? const Center(
                      child: Text(
                        'Inga brandväggsregler definierade. Default Deny gäller mellan alla zoner.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _hScrollController,
                      child: SizedBox(
                        width: _totalTableWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              color: const Color(0xFF334155),
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              child: _buildPolicyHeaderRow(),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: cfg.policies.length,
                                itemBuilder: (context, idx) => _buildPolicyDataRow(context, provider, cfg, idx),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyDataRow(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx) {
    final pol = cfg.policies[idx];
    final isDNAT = pol.action == 'dnat';
    final isAllow = pol.action == 'accept';
    final isSelected = _selectedRowIndex == idx;

    final cells = <Widget>[
      Text('${idx + 1}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDNAT ? Icons.input : (isAllow ? Icons.check_circle : Icons.cancel),
            size: 15,
            color: isDNAT ? Colors.lightBlueAccent : (isAllow ? Colors.tealAccent : Colors.redAccent),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              isDNAT ? 'DNAT' : (isAllow ? 'Allow' : 'Deny'),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDNAT ? Colors.lightBlueAccent : (isAllow ? Colors.tealAccent : Colors.redAccent),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      Text(
        pol.name,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: pol.enabled ? Colors.white : Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          decoration: pol.enabled ? null : TextDecoration.lineThrough,
        ),
      ),
      Text(pol.service, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
      _truncatedCell(pol.sourceZone),
      _truncatedCell(isDNAT && pol.nat != null ? '${pol.nat!.internalIp}:${pol.nat!.internalPort}' : pol.destZone),
      Text(isDNAT && pol.nat != null ? 'tcp:${pol.nat!.externalPort}' : _getPortForService(pol.service), overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.amber, fontSize: 11)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 14, color: Colors.cyanAccent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Redigera Policy Properties',
            onPressed: () => _showEditPolicyDialog(context, provider, cfg, idx),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Ta bort Policy',
            onPressed: () => _deletePolicy(context, provider, cfg, idx),
          ),
          const SizedBox(width: 8),
          Switch(
            value: pol.enabled,
            activeThumbColor: Colors.tealAccent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (val) => _togglePolicy(context, provider, cfg, idx, val),
          ),
        ],
      ),
    ];

    return GestureDetector(
      onTap: () => setState(() => _selectedRowIndex = isSelected ? null : idx),
      child: Container(
        color: isSelected ? Colors.cyan.withValues(alpha: 0.2) : (idx % 2 == 0 ? const Color(0xFF1E293B) : const Color(0xFF0F172A)),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            for (int i = 0; i < _colWidths.length; i++) ...[
              SizedBox(width: _colWidths[i], child: cells[i]),
              const SizedBox(width: _policyResizeHandleWidth),
            ],
          ],
        ),
      ),
    );
  }

  // Begränsar From/To-cellens bredd oavsett innehåll — en policy vars
  // SourceZone/DestZone (eller, historiskt, ett buggigt sparat objektnamn
  // fullt av IP-adresser, se commit 2ed7c90) innehåller väldigt lång text
  // fick annars hela DataTable-raden att svälla ut så långt åt höger att
  // Åtgärder-kolumnen blev praktiskt taget onåbar utan att scrolla mycket
  // långt horisontellt. Hela texten syns fortfarande i en tooltip vid hover.
  Widget _truncatedCell(String text) {
    return Tooltip(
      message: text,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    );
  }

  String _getPortForService(String service) {
    final s = service.toUpperCase().trim();
    if (s == 'HTTP') return 'tcp:80';
    if (s == 'HTTPS') return 'tcp:443';
    if (s == 'SSH') return 'tcp:22';
    if (s == 'DNS') return 'udp:53';
    if (s == 'RDP') return 'tcp:3389';
    if (s == 'ICMP') return 'icmp';
    if (s == 'ANY') return 'any';
    if (!s.contains('tcp:') && !s.contains('udp:') && !s.contains('icmp')) {
      return 'tcp:$s';
    }
    return s;
  }

  // Visar en varningsdialog innan en kritisk policy (t.ex. SSH-åtkomst till
  // brandväggen) inaktiveras eller tas bort. Returnerar true om admin
  // uttryckligen bekräftar att de förstår konsekvensen.
  Future<bool> _confirmCriticalChange(BuildContext context, String policyName, String actionVerb) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text('Är du säker?', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '"$policyName" styr kritisk åtkomst till brandväggen själv. Om du $actionVerb den kan du bli utelåst från detta gränssnitt via nätverket.\n\n'
          'Se till att du har en annan väg in (t.ex. tangentbord och skärm, eller seriekonsol) innan du fortsätter.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ja, jag är säker', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deletePolicy(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx) async {
    final pol = cfg.policies[idx];
    if (pol.critical) {
      final confirmed = await _confirmCriticalChange(context, pol.name, 'tar bort');
      if (!confirmed) return;
    }
    final updatedPolicies = List<PolicyModel>.from(cfg.policies)..removeAt(idx);
    provider.updateCandidate(ConfigModel(
      version: cfg.version,
      revision: cfg.revision,
      updatedAt: cfg.updatedAt,
      interfaces: cfg.interfaces,
      zones: cfg.zones,
      objects: cfg.objects,
      services: cfg.services,
      policies: updatedPolicies,
      settings: cfg.settings,
      wireguard: cfg.wireguard,
      openvpn: cfg.openvpn,
    ));
  }

  Future<void> _togglePolicy(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx, bool enabled) async {
    final cur = cfg.policies[idx];
    if (cur.critical && !enabled) {
      final confirmed = await _confirmCriticalChange(context, cur.name, 'inaktiverar');
      if (!confirmed) return;
    }
    final updatedPolicies = List<PolicyModel>.from(cfg.policies);
    updatedPolicies[idx] = PolicyModel(
      id: cur.id,
      name: cur.name,
      enabled: enabled,
      priority: cur.priority,
      sourceZone: cur.sourceZone,
      destZone: cur.destZone,
      sourceObj: cur.sourceObj,
      destObj: cur.destObj,
      service: cur.service,
      action: cur.action,
      nat: cur.nat,
      logging: cur.logging,
      description: cur.description,
      local: cur.local,
      critical: cur.critical,
    );
    provider.updateCandidate(ConfigModel(
      version: cfg.version,
      revision: cfg.revision,
      updatedAt: cfg.updatedAt,
      interfaces: cfg.interfaces,
      zones: cfg.zones,
      objects: cfg.objects,
      services: cfg.services,
      policies: updatedPolicies,
      settings: cfg.settings,
      wireguard: cfg.wireguard,
      openvpn: cfg.openvpn,
    ));
  }

  void _showEditPolicyDialog(BuildContext context, ConfigProvider provider, ConfigModel? cfg, int? policyIndex) {
    final isEditing = policyIndex != null && cfg != null;
    final pol = isEditing ? cfg.policies[policyIndex] : null;

    final nameCtrl = TextEditingController(text: pol?.name ?? 'Ny Brandväggsregel');
    bool enabled = pol?.enabled ?? true;
    String action = pol?.action ?? 'accept';
    
    // Tjänst & Port
    final existingService = pol?.service ?? 'ANY';
    final isPreset = ['ANY', 'HTTP', 'HTTPS', 'SSH', 'DNS', 'RDP', 'ICMP'].contains(existingService);
    String selectedServicePreset = isPreset ? existingService : 'CUSTOM';
    final customPortCtrl = TextEditingController(text: isPreset ? '' : existingService);

    // Objektnamnet (om sourceObj/destObj är satt, t.ex. en hot-lista) tas med
    // i From/To-rutan tillsammans med ev. zoner, så att en befintlig
    // objekt-baserad policy visas och kan sparas om korrekt (se
    // resolveObjOrZones nedan vid Spara).
    String? objNameById(String? objId) {
      if (objId == null || objId == 'ANY' || cfg == null) return null;
      for (final o in cfg.objects) {
        if (o.id == objId) return o.name;
      }
      return null;
    }

    List<String> fromMembers = pol != null
        ? [
            ...pol.sourceZone.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
            if (objNameById(pol.sourceObj) != null) objNameById(pol.sourceObj)!,
          ]
        : ['LAN'];
    List<String> toMembers = pol != null
        ? [
            ...pol.destZone.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
            if (objNameById(pol.destObj) != null) objNameById(pol.destObj)!,
          ]
        : ['SERVERS'];

    // DNAT
    final extPortCtrl = TextEditingController(text: pol?.nat?.externalPort.toString() ?? '443');
    final intIpCtrl = TextEditingController(text: pol?.nat?.internalIp ?? '192.168.10.10');
    final intPortCtrl = TextEditingController(text: pol?.nat?.internalPort.toString() ?? '443');
    final protoCtrl = TextEditingController(text: pol?.nat?.protocol ?? 'tcp');

    int selectedTab = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: 580,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fönstertitel
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Policy Properties' : 'Add Policy Properties',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Name & Enable Checkbox
                Row(
                  children: [
                    const Text('Name: ', style: TextStyle(color: Colors.white, fontSize: 12)),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: TextField(
                          controller: nameCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: enabled,
                          activeColor: Colors.tealAccent,
                          checkColor: Colors.black,
                          onChanged: (v) async {
                            final newVal = v ?? false;
                            if (pol != null && pol.critical && enabled && !newVal) {
                              final confirmed = await _confirmCriticalChange(context, pol.name, 'inaktiverar');
                              if (!confirmed) return;
                            }
                            setState(() => enabled = newVal);
                          },
                        ),
                        const Text('Enable', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Flikar (Policy, Properties, Advanced)
                Row(
                  children: [
                    _buildTabButton('Policy', 0, selectedTab, (idx) => setState(() => selectedTab = idx)),
                    _buildTabButton('Properties / Portar', 1, selectedTab, (idx) => setState(() => selectedTab = idx)),
                    _buildTabButton('Advanced', 2, selectedTab, (idx) => setState(() => selectedTab = idx)),
                  ],
                ),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 12),

                if (selectedTab == 0) ...[
                  // Action Selector
                  Row(
                    children: [
                      Text('${nameCtrl.text} connections are... ', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: action,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(value: 'accept', child: Text('Allowed', style: TextStyle(color: Colors.tealAccent))),
                          DropdownMenuItem(value: 'drop', child: Text('Denied (Drop)', style: TextStyle(color: Colors.redAccent))),
                          DropdownMenuItem(value: 'dnat', child: Text('DNAT (Port Forward)', style: TextStyle(color: Colors.lightBlueAccent))),
                        ],
                        onChanged: (v) => setState(() => action = v ?? 'accept'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // From Box
                  _buildMemberBox(
                    context: context,
                    title: 'From (Källadresser / Zoner)',
                    members: fromMembers,
                    onAdd: () async {
                      final selected = await _showAddressPicker(context, cfg, fromMembers);
                      if (selected != null) {
                        setState(() => fromMembers = selected);
                      }
                    },
                    onRemove: (item) {
                      setState(() => fromMembers.remove(item));
                    },
                  ),
                  const SizedBox(height: 10),

                  // To Box
                  _buildMemberBox(
                    context: context,
                    title: 'To (Måladresser / Zoner)',
                    members: toMembers,
                    onAdd: () async {
                      final selected = await _showAddressPicker(context, cfg, toMembers);
                      if (selected != null) {
                        setState(() => toMembers = selected);
                      }
                    },
                    onRemove: (item) {
                      setState(() => toMembers.remove(item));
                    },
                  ),

                  if (action == 'dnat') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Port Forwarding (DNAT) Parametrar:', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: TextField(controller: extPortCtrl, style: const TextStyle(fontSize: 11, color: Colors.white), decoration: const InputDecoration(labelText: 'WAN Port', isDense: true))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: intIpCtrl, style: const TextStyle(fontSize: 11, color: Colors.white), decoration: const InputDecoration(labelText: 'Intern IP', isDense: true))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: intPortCtrl, style: const TextStyle(fontSize: 11, color: Colors.white), decoration: const InputDecoration(labelText: 'Intern Port', isDense: true))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: protoCtrl, style: const TextStyle(fontSize: 11, color: Colors.white), decoration: const InputDecoration(labelText: 'Protokoll', isDense: true))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else if (selectedTab == 1) ...[
                  const Text('Förinställd Tjänst / Protokoll:', style: TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedServicePreset,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'ANY', child: Text('ANY (Alla tjänster & portar)')),
                      DropdownMenuItem(value: 'HTTP', child: Text('HTTP (TCP 80)')),
                      DropdownMenuItem(value: 'HTTPS', child: Text('HTTPS (TCP 443)')),
                      DropdownMenuItem(value: 'SSH', child: Text('SSH (TCP 22)')),
                      DropdownMenuItem(value: 'DNS', child: Text('DNS (UDP 53)')),
                      DropdownMenuItem(value: 'RDP', child: Text('RDP (TCP 3389)')),
                      DropdownMenuItem(value: 'ICMP', child: Text('ICMP (Ping)')),
                      DropdownMenuItem(value: 'CUSTOM', child: Text('+ Anpassad Port / Protokoll (Skriv själv t.ex. 7201)', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          selectedServicePreset = v;
                          if (v != 'CUSTOM') {
                            customPortCtrl.clear();
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Anpassat Portnummer eller Protokoll (skriv in valfri port, t.ex. 7201):', style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 36,
                    child: TextField(
                      controller: customPortCtrl,
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: 't.ex. 7201 eller tcp:7201 eller udp:5000 eller 7000-8000',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        if (val.trim().isNotEmpty && selectedServicePreset != 'CUSTOM') {
                          setState(() => selectedServicePreset = 'CUSTOM');
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Exempel: skriv "7201" för TCP port 7201, "udp:5000" för UDP port 5000, eller "icmp" för Ping.',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ] else ...[
                  const Text('Avancerade brandväggsinställningar (Logging, TCP Sync timeout, PBR)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],

                const SizedBox(height: 16),
                // Knappladdning (OK / Cancel / Help)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                      child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        if (cfg != null) {
                          NATConfigModel? updatedNAT;
                          if (action == 'dnat') {
                            updatedNAT = NATConfigModel(
                              externalPort: int.tryParse(extPortCtrl.text) ?? 443,
                              internalIp: intIpCtrl.text,
                              internalPort: int.tryParse(intPortCtrl.text) ?? 443,
                              protocol: protoCtrl.text,
                            );
                          }

                          // Beräkna slutgiltig service
                          String finalService = 'ANY';
                          if (customPortCtrl.text.trim().isNotEmpty) {
                            finalService = customPortCtrl.text.trim();
                          } else if (selectedServicePreset != 'CUSTOM') {
                            finalService = selectedServicePreset;
                          }

                          // Ett valt medlemsnamn i From/To-rutan kan antingen vara en zon
                          // (LAN/WAN/SERVERS/...) eller ett Objekt (t.ex. en Spamhaus-hot-
                          // lista, Fas 5) — bara objekt matchas faktiskt av brandväggen
                          // (Policy.SourceObj/DestObj, se nftables-adapterns
                          // objectMatchExpr), så ett valt objekt måste hamna där, inte bara
                          // som text i SourceZone/DestZone. Backend-modellen har plats för
                          // EN källa/mål-objekt per policy — väljs fler än ett används det
                          // först valda och resten ignoreras.
                          String resolveObjOrZones(List<String> members, List<String> zonesOut) {
                            String objId = 'ANY';
                            for (final m in members) {
                              final match = cfg.objects.where((o) => o.name == m);
                              if (match.isNotEmpty) {
                                if (objId == 'ANY') objId = match.first.id;
                              } else {
                                zonesOut.add(m);
                              }
                            }
                            return objId;
                          }

                          final srcZones = <String>[];
                          final dstZones = <String>[];
                          final srcObjId = resolveObjOrZones(fromMembers, srcZones);
                          final dstObjId = resolveObjOrZones(toMembers, dstZones);

                          final updatedPolicies = List<PolicyModel>.from(cfg.policies);
                          final newPol = PolicyModel(
                            id: isEditing ? pol!.id : 'pol_${DateTime.now().millisecondsSinceEpoch}',
                            name: nameCtrl.text,
                            enabled: enabled,
                            priority: pol?.priority ?? (cfg.policies.length + 1),
                            sourceZone: srcZones.join(', '),
                            destZone: dstZones.join(', '),
                            sourceObj: srcObjId,
                            destObj: dstObjId,
                            service: finalService,
                            action: action,
                            nat: updatedNAT,
                            local: pol?.local ?? false,
                            critical: pol?.critical ?? false,
                          );

                          if (isEditing) {
                            updatedPolicies[policyIndex] = newPol;
                          } else {
                            updatedPolicies.add(newPol);
                          }

                          provider.updateCandidate(ConfigModel(
                            version: cfg.version,
                            revision: cfg.revision,
                            updatedAt: cfg.updatedAt,
                            interfaces: cfg.interfaces,
                            zones: cfg.zones,
                            objects: cfg.objects,
                            services: cfg.services,
                            policies: updatedPolicies,
                            settings: cfg.settings,
                            wireguard: cfg.wireguard,
                            openvpn: cfg.openvpn,
                          ));
                        }
                        Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                      onPressed: () => Navigator.pop(ctx),
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

  Widget _buildTabButton(String label, int index, int selectedTab, Function(int) onTap) {
    final isSelected = index == selectedTab;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF334155) : Colors.transparent,
          border: Border(bottom: BorderSide(color: isSelected ? Colors.cyanAccent : Colors.transparent, width: 2)),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.cyanAccent : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMemberBox({
    required BuildContext context,
    required String title,
    required List<String> members,
    required VoidCallback onAdd,
    required Function(String) onRemove,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: const Color(0xFF334155),
            width: double.infinity,
            child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          Container(
            height: 70,
            padding: const EdgeInsets.all(6),
            color: const Color(0xFF0F172A),
            child: members.isEmpty
                ? const Text('Inga adresser tillagda', style: TextStyle(color: Colors.grey, fontSize: 11))
                : ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (ctx, i) {
                      final item = members[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.computer, size: 14, color: Colors.cyanAccent),
                            const SizedBox(width: 6),
                            Expanded(child: Text(item, style: const TextStyle(color: Colors.white, fontSize: 11))),
                            GestureDetector(
                              onTap: () => onRemove(item),
                              child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 12),
                  label: const Text('Add...', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onAdd,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<List<String>?> _showAddressPicker(BuildContext context, ConfigModel? cfg, List<String> current) async {
    final List<String> available = [
      'ANY',
      'Any-External (WAN)',
      'Any-Trusted (LAN)',
      'SERVERS',
      'IOT',
      'GUEST',
      'VPN',
    ];

    if (cfg != null) {
      for (final z in cfg.zones) {
        if (!available.contains(z.name)) available.add(z.name);
      }
      for (final o in cfg.objects) {
        if (!available.contains(o.name)) available.add(o.name);
      }
    }

    final selected = List<String>.from(current);
    final customCtrl = TextEditingController();

    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Address / Member', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('Available Members:', style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 4),
                Container(
                  height: 110,
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF334155)), color: const Color(0xFF0F172A)),
                  child: ListView.builder(
                    itemCount: available.length,
                    itemBuilder: (c, idx) {
                      final item = available[idx];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(item, style: const TextStyle(color: Colors.white, fontSize: 11)),
                        trailing: const Icon(Icons.add, size: 14, color: Colors.cyanAccent),
                        onTap: () {
                          if (!selected.contains(item)) {
                            setState(() => selected.add(item));
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 30,
                        child: TextField(
                          controller: customCtrl,
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Ange egen IP eller subnet (t.ex. 10.13.13.14)',
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(50, 30)),
                      onPressed: () {
                        if (customCtrl.text.trim().isNotEmpty) {
                          setState(() {
                            selected.add(customCtrl.text.trim());
                            customCtrl.clear();
                          });
                        }
                      },
                      child: const Text('Add Other', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Selected Members and Addresses:', style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 4),
                Container(
                  height: 90,
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF334155)), color: const Color(0xFF0F172A)),
                  child: ListView.builder(
                    itemCount: selected.length,
                    itemBuilder: (c, idx) {
                      final item = selected[idx];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(item, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 14, color: Colors.redAccent),
                          onPressed: () => setState(() => selected.removeAt(idx)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                      onPressed: () => Navigator.pop(ctx, selected),
                      child: const Text('OK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, null),
                      child: const Text('Cancel', style: TextStyle(fontSize: 11)),
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

  void _showAddDNATDialog(BuildContext context, ConfigProvider provider) {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    final nameCtrl = TextEditingController(text: 'Web Server HTTPS Forward');
    final extPortCtrl = TextEditingController(text: '443');
    final intIpCtrl = TextEditingController(text: '192.168.10.10');
    final intPortCtrl = TextEditingController(text: '443');
    final protoCtrl = TextEditingController(text: 'tcp');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Skapa Port Forwarding (DNAT)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(controller: nameCtrl, style: const TextStyle(fontSize: 11, color: Colors.white), decoration: const InputDecoration(labelText: 'Regelnamn', isDense: true)),
              TextField(controller: extPortCtrl, style: const TextStyle(fontSize: 11, color: Colors.white), decoration: const InputDecoration(labelText: 'Extern Port på WAN (t.ex. 443)', isDense: true)),
              TextField(controller: intIpCtrl, style: const TextStyle(fontSize: 11, color: Colors.white), decoration: const InputDecoration(labelText: 'Intern Mål-IP (t.ex. 192.168.10.10)', isDense: true)),
              TextField(controller: intPortCtrl, style: const TextStyle(fontSize: 11, color: Colors.white), decoration: const InputDecoration(labelText: 'Intern Målport (t.ex. 443)', isDense: true)),
              TextField(controller: protoCtrl, style: const TextStyle(fontSize: 11, color: Colors.white), decoration: const InputDecoration(labelText: 'Protokoll (tcp/udp)', isDense: true)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                    child: const Text('Spara DNAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      if (cfg != null) {
                        final extP = int.tryParse(extPortCtrl.text) ?? 443;
                        final intP = int.tryParse(intPortCtrl.text) ?? 443;
                        final newPol = PolicyModel(
                          id: 'dnat_${DateTime.now().millisecondsSinceEpoch}',
                          name: nameCtrl.text,
                          enabled: true,
                          sourceZone: 'WAN',
                          destZone: 'LAN',
                          sourceObj: 'ANY',
                          destObj: 'ANY',
                          service: protoCtrl.text.toUpperCase(),
                          action: 'dnat',
                          nat: NATConfigModel(
                            externalPort: extP,
                            internalIp: intIpCtrl.text,
                            internalPort: intP,
                            protocol: protoCtrl.text,
                          ),
                        );
                        final updated = List<PolicyModel>.from(cfg.policies)..add(newPol);
                        provider.updateCandidate(ConfigModel(
                          version: cfg.version,
                          revision: cfg.revision,
                          updatedAt: cfg.updatedAt,
                          interfaces: cfg.interfaces,
                          zones: cfg.zones,
                          objects: cfg.objects,
                          services: cfg.services,
                          policies: updated,
                          settings: cfg.settings,
                          wireguard: cfg.wireguard,
                          openvpn: cfg.openvpn,
                        ));
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Cancel', style: TextStyle(fontSize: 11)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
