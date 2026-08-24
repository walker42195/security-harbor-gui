import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../widgets/dialog_helpers.dart';

class PoliciesScreen extends StatefulWidget {
  const PoliciesScreen({super.key});

  @override
  State<PoliciesScreen> createState() => _PoliciesScreenState();
}

const List<String> _policyColLabels = ['#', 'Action', 'Policy Name', 'Type / Service', 'From (Källa)', 'To (Mål)', 'Port', 'Åtgärder'];
const List<double> _policyDefaultColWidths = [28, 70, 160, 90, 150, 150, 70, 160];
const double _policyColMinWidth = 28;
const double _policyResizeHandleWidth = 14;

class _PoliciesScreenState extends State<PoliciesScreen> {
  int? _selectedRowIndex;
  int? _hoveredResizeHandle;
  // Sätts under en aktiv resize-dragning (mellan onPointerDown och
  // onPointerUp/Cancel på handtaget). Medan den är satt görs den omgivande
  // horisontella SingleChildScrollView icke-scrollbar (NeverScrollable-
  // ScrollPhysics) — detta är ett strukturellt sätt att garantera att
  // scrollvyn INTE kan konkurrera om pekar-events under dragningen, istället
  // för att lita på att Listener/gesture-routing prioriterar rätt widget
  // (vilket visade sig opålitligt i praktiken trots att det borde fungera
  // enligt Flutters dokumenterade beteende).
  int? _activeResizeIndex;
  final List<double> _colWidths = List<double>.from(_policyDefaultColWidths);
  final ScrollController _hScrollController = ScrollController();
  Map<String, Map<String, int>> _hitCounts = {};

  @override
  void initState() {
    super.initState();
    _loadHitCounts();
  }

  @override
  void dispose() {
    _hScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHitCounts() async {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    final counts = await provider.api.getHitCounts();
    if (mounted) setState(() => _hitCounts = counts);
  }

  double get _totalTableWidth => _colWidths.fold(0.0, (sum, w) => sum + w) + _policyResizeHandleWidth * _colWidths.length;

  // Låter tabellen fylla hela GUI-bredden istället för att lämna dött
  // utrymme (eller kräva onödig horisontell scroll) när fönstret är
  // bredare än kolumnernas naturliga summa — sista kolumnen ("Åtgärder")
  // absorberar det extra utrymmet. Manuell breddjustering (dragbara
  // handtag) fungerar precis som förut; det här påverkar bara HUR breda
  // kolumnerna visas när det finns oanvänt utrymme kvar.
  List<double> _effectiveColWidths(double availableWidth) {
    if (_totalTableWidth >= availableWidth) return _colWidths;
    final widths = List<double>.from(_colWidths);
    final othersTotal = widths.sublist(0, widths.length - 1).fold(0.0, (sum, w) => sum + w);
    final handlesTotal = _policyResizeHandleWidth * widths.length;
    final remaining = availableWidth - othersTotal - handlesTotal;
    if (remaining > widths.last) {
      widths[widths.length - 1] = remaining;
    }
    return widths;
  }

  // Rå pekar-events (Listener) istället för GestureDetector.
  // onHorizontalDragUpdate — se identisk kommentar/fix i
  // connections_screen.dart: handtaget sitter inuti en horisontellt
  // scrollande SingleChildScrollView, och två konkurrerande
  // HorizontalDragGestureRecognizers gav opålitlig resize eftersom
  // scrollvyn ofta vann gesture-arenan.
  // OBS: den här widgeten MÅSTE sitta innanför en IntrinsicHeight-anfader
  // (se _buildPolicyHeaderRow) — annars ger den omgivande Row:en en olöst
  // ("loose", 0..oändligt) höjd-constraint i sidled, och den synliga
  // skiljelinjen (som saknar egen `height`/child) kollapsar tyst till 0
  // pixlars höjd. Det gjorde linjen både osynlig OCH i praktiken
  // odragbar (träffytan var 0px hög) — roten till att breddjustering
  // upplevdes helt trasig trots att pekar-hanteringen i sig var korrekt.
  Widget _resizeHandle(int colIndex) {
    final hovered = _hoveredResizeHandle == colIndex;
    final active = _activeResizeIndex == colIndex;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hoveredResizeHandle = colIndex),
      onExit: (_) => setState(() => _hoveredResizeHandle = null),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => setState(() => _activeResizeIndex = colIndex),
        onPointerMove: (event) {
          if (_activeResizeIndex != colIndex) return;
          setState(() {
            _colWidths[colIndex] = (_colWidths[colIndex] + event.delta.dx).clamp(_policyColMinWidth, 900.0);
          });
        },
        onPointerUp: (_) => setState(() => _activeResizeIndex = null),
        onPointerCancel: (_) => setState(() => _activeResizeIndex = null),
        child: SizedBox(
          width: _policyResizeHandleWidth,
          height: double.infinity,
          child: Center(
            child: SizedBox(
              width: (hovered || active) ? 3 : 2,
              height: double.infinity,
              child: ColoredBox(color: (hovered || active) ? Colors.cyanAccent : Colors.white38),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPolicyHeaderRow(List<double> widths) {
    return IntrinsicHeight(
      child: Row(
        children: [
          for (int i = 0; i < widths.length; i++) ...[
            SizedBox(
              width: widths[i],
              child: Text(_policyColLabels[i], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ),
            _resizeHandle(i),
          ],
        ],
      ),
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
                // Port forwarding (DNAT) kräver NAT, som inte finns i
                // enkelkorts-/värddator-läge (Fas 13, se
                // pkg/adapter/nftables.RenderJSON) — döljs helt istället
                // för att erbjuda en åtgärd som ändå aldrig får effekt.
                if (!(cfg?.settings.isHostMode ?? false)) ...[
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
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.tealAccent),
                  tooltip: 'Uppdatera träffräknare (Hit Counters)',
                  onPressed: _loadHitCounts,
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final widths = _effectiveColWidths(constraints.maxWidth);
                        final tableWidth = widths.fold(0.0, (sum, w) => sum + w) + _policyResizeHandleWidth * widths.length;
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _hScrollController,
                          physics: _activeResizeIndex != null ? const NeverScrollableScrollPhysics() : null,
                          child: SizedBox(
                            width: tableWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  color: const Color(0xFF334155),
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                  child: _buildPolicyHeaderRow(widths),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    // +2 för de inbyggda, låsta default-deny-raderna
                                    // som alltid ligger sist (se _buildDefaultDenyRow):
                                    // först WAN→brandvägg/LAN (inkommande från internet),
                                    // sedan all övrig trafik mellan zoner (t.ex. LAN→WAN).
                                    itemCount: cfg.policies.length + 2,
                                    itemBuilder: (context, idx) {
                                      if (idx == cfg.policies.length) {
                                        return _buildDefaultDenyRow(
                                          widths,
                                          name: 'Neka all inkommande från internet (standard)',
                                          from: 'WAN',
                                          to: 'SELF / LAN',
                                          hitKey: null,
                                          tooltip: 'Inbyggd standardregel – kan inte flyttas, ändras eller tas bort.\n'
                                              'Släpper tyst all oombedd inkommande trafik från internet (WAN) mot brandväggen och interna nät. '
                                              'Svar på anslutningar som startats inifrån släpps ändå igenom (established/related). '
                                              'Loggas inte, för att internetbrus/portscan inte ska fylla loggen.',
                                        );
                                      }
                                      if (idx == cfg.policies.length + 1) {
                                        return _buildDefaultDenyRow(
                                          widths,
                                          name: 'Neka all övrig trafik (standard)',
                                          from: 'ANY',
                                          to: 'ANY',
                                          hitKey: 'DefaultDeny',
                                          tooltip: 'Inbyggd standardregel – kan inte flyttas, ändras eller tas bort.\n'
                                              'Allt som ingen Allow-policy ovanför släppt igenom nekas här (t.ex. LAN→WAN, trafik mellan zoner).',
                                        );
                                      }
                                      return _buildPolicyDataRow(context, provider, cfg, idx, widths);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyDataRow(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx, List<double> widths) {
    final pol = cfg.policies[idx];
    final isDNAT = pol.action == 'dnat';
    final isAllow = pol.action == 'accept';
    final isReject = pol.action == 'reject';
    final isSelected = _selectedRowIndex == idx;

    // Reject visas som en egen etikett/färg i stället för att buntas ihop
    // med Drop - skillnaden (avsändaren får ett avslag i stället för
    // tystnad) är precis den administratören valde mellan.
    final actionLabel = isDNAT
        ? 'DNAT'
        : isAllow
            ? 'Allow'
            : isReject
                ? 'Reject'
                : 'Deny';
    final actionColor = isDNAT
        ? Colors.lightBlueAccent
        : isAllow
            ? Colors.tealAccent
            : isReject
                ? Colors.orangeAccent
                : Colors.redAccent;

    final cells = <Widget>[
      Text('${idx + 1}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDNAT ? Icons.input : (isAllow ? Icons.check_circle : Icons.cancel),
            size: 15,
            color: actionColor,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              actionLabel,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: actionColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      Tooltip(
        message: pol.protected
            ? '${pol.name}\n\nSkyddad policy — kan inte inaktiveras eller tas bort. ${pol.description}'
            : 'Träffar: ${_hitCountFor(pol.name).$1} paket, ${_hitCountFor(pol.name).$2} bytes',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pol.protected) ...[
              const Icon(Icons.lock, size: 11, color: Colors.amber),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                pol.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: pol.enabled ? Colors.white : Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  decoration: pol.enabled ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
        ),
      ),
      Text(pol.service, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
      _truncatedCell(_zoneOrObjLabel(cfg, pol.sourceZone, pol.sourceObj)),
      _truncatedCell(isDNAT && pol.nat != null
          ? '${pol.nat!.internalIp}:${pol.nat!.internalPort}'
          // En local-regel gäller alltid brandväggen själv — visa SELF även
          // om destZone råkar innehålla ett gammalt (ignorerat) värde från
          // innan regeln gjordes till en local-regel.
          : (pol.local ? 'SELF' : _zoneOrObjLabel(cfg, pol.destZone, pol.destObj))),
      Text(isDNAT && pol.nat != null ? 'tcp:${pol.nat!.externalPort}' : _getPortForService(pol.service), overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.amber, fontSize: 11)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 13, color: Colors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Flytta upp (högre prioritet)',
            onPressed: idx == 0 ? null : () => _movePolicy(provider, cfg, idx, idx - 1),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 13, color: Colors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Flytta ner (lägre prioritet)',
            onPressed: idx == cfg.policies.length - 1 ? null : () => _movePolicy(provider, cfg, idx, idx + 1),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit, size: 14, color: Colors.cyanAccent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Redigera Policy Properties',
            onPressed: () => _showEditPolicyDialog(context, provider, cfg, idx),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 14, color: pol.protected ? Colors.white24 : Colors.redAccent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: pol.protected ? 'Skyddad policy — kan inte tas bort' : 'Ta bort Policy',
            onPressed: pol.protected ? () => _showProtectedPolicyNotice(context, pol.name) : () => _deletePolicy(context, provider, cfg, idx),
          ),
          const SizedBox(width: 8),
          Switch(
            value: pol.enabled,
            activeThumbColor: Colors.tealAccent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: pol.protected && pol.enabled
                ? null
                : (val) => _togglePolicy(context, provider, cfg, idx, val),
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
            for (int i = 0; i < widths.length; i++) ...[
              SizedBox(width: widths[i], child: cells[i]),
              const SizedBox(width: _policyResizeHandleWidth),
            ],
          ],
        ),
      ),
    );
  }

  // Inbyggd, icke-redigerbar default-deny-rad som alltid renderas SIST i
  // listan. Motsvarar nftables implicita slutregler (policy drop): forward-
  // kedjans "SH-DENY-FWD-DefaultDeny" och INPUT-kedjans hårda WAN-drop. All
  // trafik som ingen ovanstående Allow-policy släppt igenom nekas här. Raderna
  // lagras INTE i konfigurationen (ingen PolicyModel), utan är syntetiska så
  // att administratören kan SE att brandväggen är "default deny" utan att kunna
  // flytta, redigera, inaktivera eller ta bort själva slutreglerna.
  //
  // hitKey: nftables-nyckeln för träffräknare (t.ex. "DefaultDeny"); null när
  // regeln inte loggas (den hårda WAN-dropen är tyst med flit, se
  // pkg/adapter/nftables Input 3) och därför saknar räknare.
  Widget _buildDefaultDenyRow(
    List<double> widths, {
    required String name,
    required String from,
    required String to,
    required String? hitKey,
    required String tooltip,
  }) {
    const denyColor = Colors.redAccent;
    final nameTooltip = hitKey == null
        ? 'Loggas inte (tyst drop)'
        : 'Träffar: ${_hitCountFor(hitKey).$1} paket, ${_hitCountFor(hitKey).$2} bytes';
    final cells = <Widget>[
      const Icon(Icons.lock, size: 13, color: Colors.grey),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.block, size: 15, color: denyColor),
          SizedBox(width: 4),
          Flexible(
            child: Text('Deny', overflow: TextOverflow.ellipsis,
                style: TextStyle(color: denyColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      Tooltip(
        message: nameTooltip,
        child: Text(name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
      const Text('ANY', overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
      _truncatedCell(from),
      _truncatedCell(to),
      const Text('any', overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.amber, fontSize: 11)),
      Tooltip(
        message: tooltip,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 14, color: Colors.grey),
            SizedBox(width: 6),
            Text('Låst', style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    ];

    return Container(
      // Diskret avvikande bakgrund så det syns att raden inte är en vanlig,
      // redigerbar policy.
      color: const Color(0xFF2A1518),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          for (int i = 0; i < widths.length; i++) ...[
            SizedBox(width: widths[i], child: cells[i]),
            const SizedBox(width: _policyResizeHandleWidth),
          ],
        ],
      ),
    );
  }

  // Bygger den text som visas i From/To-kolumnen. En policy anger sin källa/
  // mål som EN zon (t.ex. "LAN"), ETT objekt (t.ex. en host "192.0.2.10" eller
  // en hot-lista), eller båda — översikten visade tidigare bara zonen, så en
  // rent objektbaserad regel (sourceZone tom) fick en TOM cell fast regeln har
  // en källa. Kombinerar därför zon(er) och objektnamn, med "ANY" som fallback.
  String _zoneOrObjLabel(ConfigModel? cfg, String zone, String? objId) {
    final parts = <String>[
      ...zone.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty && e.toUpperCase() != 'ANY'),
    ];
    if (objId != null && objId.isNotEmpty && objId.toUpperCase() != 'ANY' && cfg != null) {
      for (final o in cfg.objects) {
        if (o.id == objId) {
          parts.add(o.name.isNotEmpty ? o.name : objId);
          break;
        }
      }
    }
    return parts.isEmpty ? 'ANY' : parts.join(', ');
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

  // Slår upp Hit Counter-data (Fas 7) för en policy. Nyckeln i
  // API-svaret är den exakta nftables-regelkommentaren, som skiljer sig
  // mellan FORWARD-policies ("Namn (Tjänst)") och lokala INPUT-policies
  // ("Namn on LAN <iface>") — summerar därför alla nycklar som börjar med
  // policyns namn istället för att återskapa exakt kommentarformat här.
  (int, int) _hitCountFor(String policyName) {
    int packets = 0, bytes = 0;
    for (final entry in _hitCounts.entries) {
      if (entry.key == policyName || entry.key.startsWith('$policyName (') || entry.key.startsWith('$policyName on LAN')) {
        packets += entry.value['packets'] ?? 0;
        bytes += entry.value['bytes'] ?? 0;
      }
    }
    return (packets, bytes);
  }

  String _dayLabel(String enDay) {
    const labels = {
      'Monday': 'Mån', 'Tuesday': 'Tis', 'Wednesday': 'Ons', 'Thursday': 'Tors',
      'Friday': 'Fre', 'Saturday': 'Lör', 'Sunday': 'Sön',
    };
    return labels[enDay] ?? enDay;
  }

  Widget _dialogTimeField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          height: 34,
          child: TextField(
            controller: ctrl,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: const InputDecoration(isDense: true, hintText: 'HH:MM', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
          ),
        ),
      ],
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

  // Byter plats på två policies i listan (Fas 7 — regelordning styr
  // faktisk matchningsordning i nftables-adaptern, som itererar
  // cfg.Policies i array-ordning — Policy.priority-fältet i sig läses
  // INTE av adaptern, så en flytt måste byta plats i listan, inte bara
  // ändra ett nummer).
  void _movePolicy(ConfigProvider provider, ConfigModel cfg, int fromIdx, int toIdx) {
    final updatedPolicies = List<PolicyModel>.from(cfg.policies);
    final moved = updatedPolicies.removeAt(fromIdx);
    updatedPolicies.insert(toIdx, moved);
    provider.updateCandidate(cfg.copyWith(
      policies: updatedPolicies,
    ));
  }

  // Visas när admin försöker inaktivera/ta bort en Protected policy (t.ex.
  // Management API-åtkomsten) via en väg som redan är avstängd i GUI:t
  // (disabled knapp/switch) men som ändå kan nås, t.ex. via delete-ikonens
  // onPressed. Backend blockerar detta ändå vid Apply (validatePolicies),
  // men GUI:t ska förklara VARFÖR direkt i stället för att bara ignorera
  // klicket.
  Future<void> _showProtectedPolicyNotice(BuildContext context, String policyName) {
    return showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: const [
            Icon(Icons.lock, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text('Skyddad policy', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '"$policyName" kan inte inaktiveras eller tas bort. Det är den enda vägen in i GUI:t, '
          'utan en text-baserad reservväg som SSH — att stänga av den skulle riskera att låsa ute '
          'administratören helt.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _deletePolicy(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx) async {
    final pol = cfg.policies[idx];
    if (pol.protected) {
      await _showProtectedPolicyNotice(context, pol.name);
      return;
    }
    if (pol.critical) {
      // Kritiska regler har sin egen, strängare bekräftelse (utelåsnings-
      // varning) — den räcker, ingen extra dialog ovanpå.
      final confirmed = await _confirmCriticalChange(context, pol.name, 'tar bort');
      if (!confirmed) return;
    } else {
      // Bekräfta ALLA borttagningar, inte bara kritiska — en råkad delete
      // ska inte tyst ta bort en regel (den syns annars inte förrän man
      // upptäcker att den är borta, och efter ett Bekräfta går den inte att
      // rulla tillbaka). "Ångra ändringar"-knappen räddar den som ännu inte
      // applicerat, men bättre att fråga direkt.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Ta bort regeln?', style: TextStyle(color: Colors.white, fontSize: 14)),
          content: Text(
            'Vill du ta bort regeln "${pol.name}"?\n\n'
            'Ändringen sparas i kandidaten men slår inte igenom på brandväggen '
            'förrän du trycker Applicera. Innan dess kan du ångra med '
            '"Ångra ändringar".',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Avbryt')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Ta bort'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    final updatedPolicies = List<PolicyModel>.from(cfg.policies)..removeAt(idx);
    provider.updateCandidate(cfg.copyWith(
      policies: updatedPolicies,
    ));
  }

  Future<void> _togglePolicy(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx, bool enabled) async {
    final cur = cfg.policies[idx];
    if (cur.protected && !enabled) {
      await _showProtectedPolicyNotice(context, cur.name);
      return;
    }
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
      protected: cur.protected,
      schedule: cur.schedule,
    );
    provider.updateCandidate(cfg.copyWith(
      policies: updatedPolicies,
    ));
  }

  void _showEditPolicyDialog(BuildContext context, ConfigProvider provider, ConfigModel? cfg, int? policyIndex) {
    final isEditing = policyIndex != null && cfg != null;
    final pol = isEditing ? cfg.policies[policyIndex] : null;

    final nameCtrl = TextEditingController(text: pol?.name ?? 'Ny Brandväggsregel');
    bool enabled = pol?.enabled ?? true;
    String action = pol?.action ?? 'accept';

    // Schema (Fas 7 — tidsstyrda regler)
    bool scheduleEnabled = pol?.schedule?.enabled ?? false;
    Set<String> scheduleDays = Set<String>.from(pol?.schedule?.days ?? const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']);
    final scheduleStartCtrl = TextEditingController(text: pol?.schedule?.startTime ?? '08:00');
    final scheduleEndCtrl = TextEditingController(text: pol?.schedule?.endTime ?? '17:00');

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
        // "ANY" som default (alltid giltigt) i stället för en zon som kan ha
        // tagits bort via "Hantera zoner".
        : ['ANY'];

    // DNAT
    final extPortCtrl = TextEditingController(text: pol?.nat?.externalPort.toString() ?? '443');
    final intIpCtrl = TextEditingController(text: pol?.nat?.internalIp ?? '192.168.10.10');
    final intPortCtrl = TextEditingController(text: pol?.nat?.internalPort.toString() ?? '443');
    final protoCtrl = TextEditingController(text: pol?.nat?.protocol ?? 'tcp');

    // local = regeln gäller trafik TILL brandväggen själv (INPUT-kedjan),
    // t.ex. ping eller SSH mot brandväggen — inte trafik som ska
    // vidarebefordras genom den (FORWARD). En vanlig "från LAN till Any"-
    // regel är en forward-regel och matchar därför ALDRIG paket riktade
    // till brandväggens egen IP; för det krävs en local-regel.
    bool local = pol?.local ?? false;

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
                          onChanged: (pol?.protected ?? false)
                              ? null
                              : (v) async {
                                  final newVal = v ?? false;
                                  if (pol != null && pol.critical && enabled && !newVal) {
                                    final confirmed = await _confirmCriticalChange(context, pol.name, 'inaktiverar');
                                    if (!confirmed) return;
                                  }
                                  setState(() => enabled = newVal);
                                },
                        ),
                        Text(
                          'Enable',
                          style: TextStyle(color: (pol?.protected ?? false) ? Colors.white38 : Colors.white, fontSize: 12),
                        ),
                        if (pol?.protected ?? false) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: 'Skyddad policy — kan inte inaktiveras, det är den enda vägen in i GUI:t.',
                            child: Icon(Icons.lock, size: 14, color: Colors.amber),
                          ),
                        ],
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
                          // Reject fanns redan i backend-datamodellen men
                          // genererade tidigare ingen regel alls; sedan
                          // 2026-08-20 renderas den som ett riktigt
                          // nftables-reject (ICMP "admin-prohibited"), så
                          // den kan erbjudas här. Skillnad mot Drop:
                          // avsändaren får ett tydligt avslag direkt i
                          // stället för att vänta ut en timeout.
                          DropdownMenuItem(value: 'reject', child: Text('Denied (Reject)', style: TextStyle(color: Colors.orangeAccent))),
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

                  // To Box — nedtonad och märkt när regeln gäller
                  // brandväggen själv, eftersom "To" då inte används.
                  Opacity(
                    opacity: local ? 0.4 : 1.0,
                    child: _buildMemberBox(
                      context: context,
                      title: local
                          ? 'To (används INTE — regeln gäller brandväggen själv)'
                          : 'To (Måladresser / Zoner)',
                      members: local ? ['Brandväggen själv'] : toMembers,
                      onAdd: local
                          ? () {}
                          : () async {
                              final selected = await _showAddressPicker(context, cfg, toMembers);
                              if (selected != null) {
                                setState(() => toMembers = selected);
                              }
                            },
                      onRemove: local ? (_) {} : (item) => setState(() => toMembers.remove(item)),
                    ),
                  ),

                  // Local-regel: trafik TILL brandväggen själv.
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => setState(() => local = !local),
                    child: Row(
                      children: [
                        Checkbox(
                          value: local,
                          activeColor: Colors.tealAccent,
                          checkColor: Colors.black,
                          onChanged: (v) => setState(() => local = v ?? false),
                        ),
                        Expanded(
                          child: Text(
                            local
                                ? 'PÅ: regeln gäller trafik TILL brandväggen själv — att nå brandväggens '
                                    'egen IP, t.ex. pinga eller SSH:a TILL brandväggen. "To"-fältet ovan '
                                    'används inte. (Detta styr INTE trafik ut genom brandväggen.)'
                                : 'AV: regeln gäller trafik GENOM brandväggen, från "From" till "To" — '
                                    't.ex. att en LAN-enhet pingar ut mot internet. (Detta styr INTE om man '
                                    'kan pinga brandväggen själv — bocka i rutan för det.)',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
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
                  const Text('Schema (Fas 7 — tidsstyrd regel)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Switch(
                        value: scheduleEnabled,
                        activeThumbColor: Colors.tealAccent,
                        onChanged: (v) => setState(() => scheduleEnabled = v),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        scheduleEnabled ? 'Aktiv bara under angivna dagar/tider' : 'Alltid aktiv (inget schema)',
                        style: TextStyle(color: scheduleEnabled ? Colors.tealAccent : Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                  if (scheduleEnabled) ...[
                    const SizedBox(height: 10),
                    const Text('Veckodagar', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final day in const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'])
                          FilterChip(
                            label: Text(_dayLabel(day), style: const TextStyle(fontSize: 11)),
                            selected: scheduleDays.contains(day),
                            selectedColor: Colors.tealAccent.withValues(alpha: 0.3),
                            checkmarkColor: Colors.tealAccent,
                            onSelected: (sel) => setState(() {
                              if (sel) {
                                scheduleDays.add(day);
                              } else {
                                scheduleDays.remove(day);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _dialogTimeField('Från (HH:MM)', scheduleStartCtrl)),
                        const SizedBox(width: 10),
                        Expanded(child: _dialogTimeField('Till (HH:MM)', scheduleEndCtrl)),
                      ],
                    ),
                  ],
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

                          // Ett valt medlemsnamn i From/To-rutan kan vara en zon
                          // (LAN/WAN/SERVERS/...), ett befintligt Objekt (t.ex. en
                          // Spamhaus-hotlista, Fas 5), eller en egen inskriven IP/subnet
                          // (pickerns "Add Other"-fält) — bara objekt matchas faktiskt av
                          // brandväggen (Policy.SourceObj/DestObj, se nftables-adapterns
                          // objectMatchExpr). Egen IP-text matchade tidigare INGET av
                          // dessa — den hamnade i SourceZone/DestZone som inert text (post
                          // zon-fixen 2026-08-19: gav då bara ett valideringsfel om "zonen
                          // matchar inget gränssnitt", utan att någonsin faktiskt
                          // begränsa trafiken). Skapar nu istället automatiskt ett riktigt
                          // Host/Network-objekt av texten, så fältet gör vad namnet lovar.
                          final knownZoneNames = <String>{
                            'ANY',
                            'Any-External (WAN)',
                            'Any-Trusted (LAN)',
                            ...cfg.zones.map((z) => z.name),
                          };
                          final ipLikePattern = RegExp(r'^[0-9a-fA-F.:]+(/\d{1,3})?$');
                          final newObjects = <ObjectModel>[];

                          String resolveObjOrZones(List<String> members, List<String> zonesOut, List<String> matchedNamesOut) {
                            String objId = 'ANY';
                            for (final m in members) {
                              final match = cfg.objects.where((o) => o.name == m);
                              if (knownZoneNames.contains(m)) {
                                zonesOut.add(m);
                              } else if (match.isNotEmpty) {
                                matchedNamesOut.add(m);
                                if (objId == 'ANY') objId = match.first.id;
                              } else if (ipLikePattern.hasMatch(m)) {
                                // Återanvänd ett tidigare auto-skapat objekt med samma
                                // värde istället för att skapa dubbletter varje gång
                                // policyn sparas om.
                                final existing = [...cfg.objects, ...newObjects]
                                    .where((o) => o.values.length == 1 && o.values.first == m);
                                final ObjectModel obj;
                                if (existing.isNotEmpty) {
                                  obj = existing.first;
                                } else {
                                  obj = ObjectModel(
                                    id: 'obj_auto_${DateTime.now().microsecondsSinceEpoch}_${newObjects.length}',
                                    name: m,
                                    type: m.contains('/') ? 'network' : 'host',
                                    values: [m],
                                    description: 'Automatiskt skapad från policy-editorns "Ange egen IP"-fält',
                                  );
                                  newObjects.add(obj);
                                }
                                matchedNamesOut.add(m);
                                if (objId == 'ANY') objId = obj.id;
                              } else {
                                // Okänd text som varken är en känd zon, ett objekt eller
                                // ser ut som en IP/subnet - troligen en felstavad zon.
                                // Behåll i zonesOut så zon-valideringen ger ett tydligt
                                // fel istället för att tyst ignoreras.
                                zonesOut.add(m);
                              }
                            }
                            return objId;
                          }

                          final srcZones = <String>[];
                          final dstZones = <String>[];
                          final srcMatchedObjs = <String>[];
                          final dstMatchedObjs = <String>[];
                          final srcObjId = resolveObjOrZones(fromMembers, srcZones, srcMatchedObjs);
                          // För en local-regel (trafik TILL brandväggen själv) är
                          // målet alltid brandväggen — backend läser inte To för
                          // local-regler. Spara "SELF" som destZone (samma som den
                          // fördefinierade SSH-regeln) i stället för det ignorerade
                          // To-fältets innehåll, så listvyn visar SELF korrekt.
                          final String dstObjId;
                          if (local) {
                            dstZones.add('SELF');
                            dstObjId = 'ANY';
                          } else {
                            dstObjId = resolveObjOrZones(toMembers, dstZones, dstMatchedObjs);
                          }

                          if (srcMatchedObjs.length > 1 || dstMatchedObjs.length > 1) {
                            final side = srcMatchedObjs.length > 1 ? 'Källa' : 'Mål';
                            final names = (srcMatchedObjs.length > 1 ? srcMatchedObjs : dstMatchedObjs).join(', ');
                            showDialog(
                              context: context,
                              builder: (dctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E293B),
                                title: const Text('Flera objekt valda', style: TextStyle(color: Colors.white, fontSize: 14)),
                                content: Text(
                                  'Du har valt $side objekt: $names.\n\n'
                                  'En regel kan bara referera ETT objekt direkt.\n\n'
                                  'Skapa istället en Grupp under Objekt-vyn som innehåller $names, '
                                  'och välj den gruppen här - brandväggen matchar mot alla objekt i '
                                  'gruppen samtidigt.',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('OK, jag fixar det')),
                                ],
                              ),
                            );
                            return;
                          }

                          final updatedPolicies = List<PolicyModel>.from(cfg.policies);
                          final newPol = PolicyModel(
                            id: isEditing ? pol!.id : 'pol_${DateTime.now().millisecondsSinceEpoch}',
                            name: nameCtrl.text,
                            // En Protected policy sparas alltid som enabled=true, oavsett
                            // vad "enabled" råkar innehålla — checkboxen ovan är redan
                            // disabled för den, men detta är ett andra skyddslager mot att
                            // ett dolt/oåtkomligt state ändå slinker med (backend
                            // blockerar det ändå vid Apply, se validatePolicies).
                            enabled: (pol?.protected ?? false) ? true : enabled,
                            priority: pol?.priority ?? (cfg.policies.length + 1),
                            sourceZone: srcZones.join(', '),
                            destZone: dstZones.join(', '),
                            sourceObj: srcObjId,
                            destObj: dstObjId,
                            service: finalService,
                            action: action,
                            nat: updatedNAT,
                            local: local,
                            critical: pol?.critical ?? false,
                            protected: pol?.protected ?? false,
                            schedule: scheduleEnabled
                                ? PolicyScheduleModel(
                                    enabled: true,
                                    days: scheduleDays.toList(),
                                    startTime: scheduleStartCtrl.text.trim(),
                                    endTime: scheduleEndCtrl.text.trim(),
                                  )
                                : null,
                          );

                          if (isEditing) {
                            updatedPolicies[policyIndex] = newPol;
                          } else {
                            updatedPolicies.add(newPol);
                          }

                          provider.updateCandidate(cfg.copyWith(
                            objects: [...cfg.objects, ...newObjects],
                            policies: updatedPolicies,
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
    // De tre snabbvalen (ANY + de syntetiska WAN/LAN-valen) hålls kvar
    // överst eftersom de är de vanligaste valen. Resten — zoner och objekt —
    // sorteras i bokstavsordning (skiftlägesokänsligt) så listan blir
    // lätt att skanna, i stället för den tidigare oordnade blandningen.
    final pinned = ['ANY', 'Any-External (WAN)', 'Any-Trusted (LAN)'];
    // Byggs från configens FAKTISKA zoner + objekt — inte en hårdkodad
    // zon-lista (som visade SERVERS/IOT/GUEST/VPN även efter att de tagits bort
    // via "Hantera zoner").
    final rest = <String>{};
    if (cfg != null) {
      for (final z in cfg.zones) {
        rest.add(z.name);
      }
      for (final o in cfg.objects) {
        rest.add(o.name);
      }
    }
    rest.removeAll(pinned);
    final sortedRest = rest.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final List<String> available = [...pinned, ...sortedRest];

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dialogTitleRow(context, 'Skapa Port Forwarding (DNAT)', () => Navigator.pop(ctx)),
                const SizedBox(height: 12),

                dialogSection(title: 'REGEL', children: [
                  dialogField(nameCtrl, 'Regelnamn'),
                ]),
                const SizedBox(height: 12),

                dialogSection(title: 'EXTERN (WAN)', children: [
                  dialogField(extPortCtrl, 'Extern port på WAN', hint: 't.ex. 443'),
                ]),
                const SizedBox(height: 12),

                dialogSection(title: 'INTERN (LAN)', children: [
                  dialogField(intIpCtrl, 'Intern mål-IP', hint: 't.ex. 192.168.10.10'),
                  const SizedBox(height: 12),
                  dialogField(intPortCtrl, 'Intern målport', hint: 't.ex. 443'),
                  const SizedBox(height: 12),
                  dialogField(protoCtrl, 'Protokoll (tcp/udp)'),
                ]),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                    child: const Text('Spara DNAT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                        provider.updateCandidate(cfg.copyWith(
                          policies: updated,
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
    );
  }
}
