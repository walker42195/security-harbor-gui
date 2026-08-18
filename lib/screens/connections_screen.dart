import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';

/// En rad i loggvyn — läst direkt ur brandväggens kärnlogg (både
/// tillåten OCH nekad trafik loggas numera med ett policynamns-bärande
/// prefix, se pkg/adapter/nftables SH-ACCEPT-*/SH-DENY-*). Ersätter den
/// tidigare uppdelningen mellan "aktiva conntrack-anslutningar" (som
/// aldrig kunde visa VILKEN regel som tillät något) och en separat
/// deny-logg — nu är allt EN källa, med regelnamn på båda sidor.
class _TrafficRow {
  final bool accepted;
  final String policyName;
  final String protocol;
  final String srcIp;
  final int srcPort;
  final String dstIp;
  final int dstPort;
  final String srcMac;
  final String dstMac;
  final String stateOrChain;
  final String timestamp;
  final String inIface;
  final String outIface;

  _TrafficRow({
    required this.accepted,
    required this.policyName,
    required this.protocol,
    required this.srcIp,
    required this.srcPort,
    required this.dstIp,
    required this.dstPort,
    required this.srcMac,
    required this.dstMac,
    required this.stateOrChain,
    required this.timestamp,
    required this.inIface,
    required this.outIface,
  });

  factory _TrafficRow.fromFirewallLog(FirewallLogModel m) => _TrafficRow(
        accepted: m.action == 'accept',
        policyName: m.policyName,
        protocol: m.protocol,
        srcIp: m.srcIp,
        srcPort: m.srcPort,
        dstIp: m.dstIp,
        dstPort: m.dstPort,
        srcMac: m.srcMac,
        dstMac: m.dstMac,
        stateOrChain: m.chain,
        timestamp: m.timestamp,
        inIface: m.inIface,
        outIface: m.outIface,
      );
}

/// Riktning relativt brandväggen, avgjord via vilken zon (WAN/LAN) käll-
/// respektive mål-gränssnittet tillhör — inte bara vilken IP:et pratar
/// med, eftersom en och samma IP kan nås via olika gränssnitt. "IN" är
/// trafik som kommer in via ett WAN-gränssnitt (mot brandväggen själv
/// ELLER vidarebefordrad till en LAN-enhet, t.ex. port forwarding),
/// "OUT" är LAN mot WAN, resten (LAN mot LAN, eller lokal åtkomst mot
/// brandväggen själv) är "INTERNAL".
String _classifyDirection(_TrafficRow r, Map<String, String> deviceZone) {
  final inZone = (deviceZone[r.inIface] ?? '').toUpperCase();
  final outZone = (deviceZone[r.outIface] ?? '').toUpperCase();
  if (inZone == 'WAN') return 'IN';
  if (inZone == 'LAN' && outZone == 'WAN') return 'OUT';
  return 'INTERNAL';
}

/// Slår upp ett läsbart objektnamn för en IP-adress mot de Host/Network-objekt
/// som finns i den körande konfigurationen (samma objekt som används i
/// Policy-editorn). Enkel exakt-match för Host och CIDR-innehåll för Network.
/// Grov men tillräcklig avgörning av IP-version: en IPv6-adress innehåller
/// alltid ":", en IPv4-adress (eller en IPv4:port-sträng) aldrig.
bool _isIPv6(String ip) => ip.contains(':');

String? _resolveObjectName(List<ObjectModel> objects, String ip) {
  if (ip.isEmpty) return null;
  for (final obj in objects) {
    for (final value in obj.values) {
      if (value == ip) return obj.name;
      if (value.contains('/') && _ipInCidr(ip, value)) return obj.name;
    }
  }
  return null;
}

bool _ipInCidr(String ip, String cidr) {
  try {
    final parts = cidr.split('/');
    if (parts.length != 2) return false;
    final base = _ipToInt(parts[0]);
    final prefix = int.parse(parts[1]);
    final target = _ipToInt(ip);
    if (base == null || target == null || prefix < 0 || prefix > 32) return false;
    if (prefix == 0) return true;
    final mask = 0xFFFFFFFF << (32 - prefix);
    return (base & mask) == (target & mask);
  } catch (_) {
    return false;
  }
}

int? _ipToInt(String ip) {
  final octets = ip.split('.');
  if (octets.length != 4) return null;
  int result = 0;
  for (final o in octets) {
    final v = int.tryParse(o);
    if (v == null || v < 0 || v > 255) return null;
    result = (result << 8) | v;
  }
  return result;
}

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

/// Kolumnordning delad mellan rubrikraden och varje datarad, så att
/// bredderna alltid är synkade. Källa/Mål var tidigare Expanded(flex: 3) men
/// måste vara fasta bredder för att kunna dras i storlek.
const List<double> _defaultColWidths = [62, 130, 90, 170, 60, 200, 130, 200, 130, 90];
const List<String> _colLabels = ['Åtgärd', 'Tid', 'Riktning', 'Regel', 'Protokoll', 'Källa', 'Källans MAC', 'Mål', 'Målets MAC', 'State/Kedja'];
const double _colMinWidth = 40;
const double _resizeHandleWidth = 14;

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  Timer? _pollTimer;
  List<FirewallLogModel> _entries = [];
  bool _isLoading = false;
  int? _hoveredResizeHandle;
  int? _activeResizeIndex; // Se identisk kommentar i policies_screen.dart
  final List<double> _colWidths = List<double>.from(_defaultColWidths);
  final ScrollController _hScrollController = ScrollController();

  // Filter
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _macController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _directionFilterField = 'ANY'; // ANY, FROM, TO — för IP-fältet ovan
  String _actionFilter = 'ALL'; // ALL, ACCEPT, DENY
  // IPv4 aktivt som default — det är i praktiken all trafik i det här
  // nätet idag, så IPv6 (om något någonsin dyker upp) eller "Alla" får
  // väljas medvetet istället för att blanda in i vyn från start.
  String _ipVersionFilter = 'IPV4'; // ALL, IPV4, IPV6
  // Riktning relativt brandväggen (WAN/LAN-zonbaserad, se
  // _classifyDirection) — separat från _directionFilterField ovan, som
  // bara styr IP-fältets Från/Till-tolkning.
  String _trafficDirectionFilter = 'ALL'; // ALL, IN, OUT, INTERNAL

  @override
  void initState() {
    super.initState();
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ipController.dispose();
    _macController.dispose();
    _nameController.dispose();
    _hScrollController.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    setState(() => _isLoading = true);
    final entries = await provider.api.getFirewallLog();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    final objects = cfg?.objects ?? [];
    final deviceZone = <String, String>{for (final iface in cfg?.interfaces ?? <InterfaceModel>[]) iface.device: iface.zone};

    List<_TrafficRow> rows = _entries.map(_TrafficRow.fromFirewallLog).toList();

    if (_actionFilter == 'ACCEPT') {
      rows = rows.where((r) => r.accepted).toList();
    } else if (_actionFilter == 'DENY') {
      rows = rows.where((r) => !r.accepted).toList();
    }

    if (_trafficDirectionFilter != 'ALL') {
      rows = rows.where((r) => _classifyDirection(r, deviceZone) == _trafficDirectionFilter).toList();
    }

    if (_ipVersionFilter != 'ALL') {
      final wantIPv6 = _ipVersionFilter == 'IPV6';
      rows = rows.where((r) => _isIPv6(r.srcIp.isNotEmpty ? r.srcIp : r.dstIp) == wantIPv6).toList();
    }

    final ipFilter = _ipController.text.trim();
    if (ipFilter.isNotEmpty) {
      rows = rows.where((r) {
        final matchesSrc = r.srcIp.contains(ipFilter);
        final matchesDst = r.dstIp.contains(ipFilter);
        if (_directionFilterField == 'FROM') return matchesSrc;
        if (_directionFilterField == 'TO') return matchesDst;
        return matchesSrc || matchesDst;
      }).toList();
    }

    final macFilter = _macController.text.trim().toLowerCase();
    if (macFilter.isNotEmpty) {
      rows = rows.where((r) => r.srcMac.toLowerCase().contains(macFilter)).toList();
    }

    final nameFilter = _nameController.text.trim().toLowerCase();
    if (nameFilter.isNotEmpty) {
      rows = rows.where((r) {
        final srcName = _resolveObjectName(objects, r.srcIp)?.toLowerCase() ?? '';
        final dstName = _resolveObjectName(objects, r.dstIp)?.toLowerCase() ?? '';
        final policyName = r.policyName.toLowerCase();
        return srcName.contains(nameFilter) || dstName.contains(nameFilter) || policyName.contains(nameFilter);
      }).toList();
    }

    rows.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.list_alt, color: Colors.cyanAccent, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Anslutningar & Loggning',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent)),
                      ),
                    Text('${rows.length} rader', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18, color: Colors.cyanAccent),
                      tooltip: 'Uppdatera nu',
                      onPressed: _poll,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildFilterBar(),
            const SizedBox(height: 10),
            Expanded(child: _buildTable(rows, objects, deviceZone)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildFilterField('IP-adress', _ipController, width: 160),
          _buildFilterField('MAC-adress', _macController, width: 160),
          Tooltip(
            message: 'Söker på namnet på ett sparat Objekt (Host/Network) vars IP matchar källan eller målet,\n'
                'OCH på namnet på den brandväggsregel som tillät/nekade trafiken.',
            child: _buildFilterField('Namn / Regel', _nameController, width: 180),
          ),
          _buildDropdown('Från/Till', _directionFilterField, const {
            'ANY': 'Från/Till',
            'FROM': 'Från (källa)',
            'TO': 'Till (mål)',
          }, (v) => setState(() => _directionFilterField = v)),
          _buildDropdown('Riktning', _trafficDirectionFilter, const {
            'ALL': 'Alla',
            'IN': 'Inkommande (från WAN)',
            'OUT': 'Utgående (till WAN)',
            'INTERNAL': 'Internt/Lokalt',
          }, (v) => setState(() => _trafficDirectionFilter = v)),
          _buildDropdown('Åtgärd', _actionFilter, const {
            'ALL': 'Alla',
            'ACCEPT': 'Endast Accept',
            'DENY': 'Endast Deny',
          }, (v) => setState(() => _actionFilter = v)),
          _buildDropdown('IP-version', _ipVersionFilter, const {
            'ALL': 'Alla',
            'IPV4': 'Endast IPv4',
            'IPV6': 'Endast IPv6',
          }, (v) => setState(() => _ipVersionFilter = v)),
          TextButton.icon(
            icon: const Icon(Icons.clear, size: 14, color: Colors.grey),
            label: const Text('Rensa filter', style: TextStyle(fontSize: 11, color: Colors.grey)),
            onPressed: () => setState(() {
              _ipController.clear();
              _macController.clear();
              _nameController.clear();
              _directionFilterField = 'ANY';
              _trafficDirectionFilter = 'ALL';
              _actionFilter = 'ALL';
              _ipVersionFilter = 'IPV4';
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterField(String label, TextEditingController controller, {required double width}) {
    return SizedBox(
      width: width,
      height: 34,
      child: TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 12, color: Colors.white),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11, color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, Map<String, String> options, ValueChanged<String> onChanged) {
    return SizedBox(
      height: 34,
      child: DropdownButtonHideUnderline(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF334155)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButton<String>(
            value: value,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(fontSize: 12, color: Colors.white),
            items: options.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text('$label: ${e.value}')))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }

  double get _totalTableWidth => _colWidths.fold(0.0, (sum, w) => sum + w) + _resizeHandleWidth * _colWidths.length;

  // Se identisk kommentar/motivering i policies_screen.dart —
  // _effectiveColWidths: fyller ut sista kolumnen med oanvänt utrymme när
  // fönstret är bredare än tabellens naturliga bredd, istället för att
  // lämna dött utrymme eller tvinga fram onödig horisontell scroll.
  List<double> _effectiveColWidths(double availableWidth) {
    if (_totalTableWidth >= availableWidth) return _colWidths;
    final widths = List<double>.from(_colWidths);
    final othersTotal = widths.sublist(0, widths.length - 1).fold(0.0, (sum, w) => sum + w);
    final handlesTotal = _resizeHandleWidth * widths.length;
    final remaining = availableWidth - othersTotal - handlesTotal;
    if (remaining > widths.last) {
      widths[widths.length - 1] = remaining;
    }
    return widths;
  }

  // Använder rå pekar-events (Listener) istället för en
  // HorizontalDragGestureRecognizer (GestureDetector.onHorizontalDragUpdate):
  // handtaget sitter inuti en horisontellt scrollande SingleChildScrollView,
  // och två HorizontalDragGestureRecognizers (handtaget + scrollvyns egen)
  // som tävlar om samma drag i gesture-arenan gav opålitligt/obefintligt
  // resize — scrollvyn vann ofta arenan istället för det lilla handtaget.
  // Listener kringgår hela gesture-arena-mekanismen genom att läsa
  // pekarrörelser direkt.
  // OBS: måste sitta innanför en IntrinsicHeight-anfader (se _buildHeaderRow)
  // — se identisk kommentar/motivering i policies_screen.dart. Utan den
  // kollapsar den synliga skiljelinjen (ingen egen `height`/child) tyst
  // till 0 pixlars höjd i Row:ens olösta höjd-constraint, vilket gjorde
  // den både osynlig och i praktiken odragbar (0px hög träffyta).
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
            _colWidths[colIndex] = (_colWidths[colIndex] + event.delta.dx).clamp(_colMinWidth, 800.0);
          });
        },
        onPointerUp: (_) => setState(() => _activeResizeIndex = null),
        onPointerCancel: (_) => setState(() => _activeResizeIndex = null),
        child: SizedBox(
          width: _resizeHandleWidth,
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

  Widget _buildHeaderRow(List<double> widths) {
    return IntrinsicHeight(
      child: Row(
        children: [
          for (int i = 0; i < widths.length; i++) ...[
            SizedBox(width: widths[i], child: Text(_colLabels[i], style: _headerStyle)),
            _resizeHandle(i),
          ],
        ],
      ),
    );
  }

  Widget _buildDataRow(_TrafficRow r, List<ObjectModel> objects, Map<String, String> deviceZone, List<double> widths) {
    final srcName = _resolveObjectName(objects, r.srcIp);
    final dstName = _resolveObjectName(objects, r.dstIp);
    final direction = _classifyDirection(r, deviceZone);
    final cells = <Widget>[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: (r.accepted ? Colors.tealAccent : Colors.redAccent).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          r.accepted ? 'ACCEPT' : 'DENY',
          style: TextStyle(color: r.accepted ? Colors.tealAccent : Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ),
      Text(r.timestamp.isEmpty ? '—' : r.timestamp, style: _cellStyle, overflow: TextOverflow.ellipsis),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            direction == 'IN' ? Icons.arrow_downward : (direction == 'OUT' ? Icons.arrow_upward : Icons.swap_horiz),
            size: 12,
            color: direction == 'IN' ? Colors.amber : (direction == 'OUT' ? Colors.cyanAccent : Colors.grey),
          ),
          const SizedBox(width: 4),
          Text(
            direction == 'IN' ? 'Inkommande' : (direction == 'OUT' ? 'Utgående' : 'Internt'),
            style: _cellStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      Text(r.policyName.isEmpty ? '—' : r.policyName, style: _cellStyle, overflow: TextOverflow.ellipsis),
      Text(r.protocol.toUpperCase(), style: _cellStyle, overflow: TextOverflow.ellipsis),
      Text(
        '${r.srcIp}${r.srcPort > 0 ? ':${r.srcPort}' : ''}${srcName != null ? '\n$srcName' : ''}',
        style: _cellStyle,
        overflow: TextOverflow.ellipsis,
      ),
      Text(r.srcMac.isEmpty ? '—' : r.srcMac, style: _cellStyle, overflow: TextOverflow.ellipsis),
      Text(
        '${r.dstIp}${r.dstPort > 0 ? ':${r.dstPort}' : ''}${dstName != null ? '\n$dstName' : ''}',
        style: _cellStyle,
        overflow: TextOverflow.ellipsis,
      ),
      Text(r.dstMac.isEmpty ? '—' : r.dstMac, style: _cellStyle, overflow: TextOverflow.ellipsis),
      Text(r.stateOrChain, style: _cellStyle, overflow: TextOverflow.ellipsis),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: const Color(0xFF334155).withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          for (int i = 0; i < widths.length; i++) ...[
            SizedBox(width: widths[i], child: cells[i]),
            SizedBox(width: _resizeHandleWidth),
          ],
        ],
      ),
    );
  }

  // Header och rader delar EN horisontell SingleChildScrollView (inte två
  // separata med samma ScrollController — att dela en controller mellan två
  // Scrollables synkar INTE automatiskt deras offset, bara att de kan
  // koexistera). Rubrikraden ligger utanför den vertikala ListView men
  // innanför samma horisontella scroll-region, så den förblir vertikalt
  // fast ("sticky") medan raderna scrollar, men rör sig i sidled i takt med
  // dem eftersom det är exakt samma scroll-offset.
  // SelectionArea (istället för SelectableText per cell) gör hela tabellen
  // musmarkerbar med vanliga Text-widgetar — SelectableText har inte exakt
  // samma layoutmått som Text (extra utrymme reserverat för markörer/
  // handtag), vilket gav ett synligt ojämnt baseline mellan kolumnerna
  // trots att varje cell för sig var korrekt centrerad. Med SelectionArea
  // slipper vi det problemet helt eftersom cellerna är rena Text-widgetar
  // igen, och man kan dessutom markera text över FLERA celler i ett drag.
  Widget _buildTable(List<_TrafficRow> rows, List<ObjectModel> objects, Map<String, String> deviceZone) {
    return SelectionArea(
      child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final widths = _effectiveColWidths(constraints.maxWidth);
          final tableWidth = widths.fold(0.0, (sum, w) => sum + w) + _resizeHandleWidth * widths.length;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _hScrollController,
            physics: _activeResizeIndex != null ? const NeverScrollableScrollPhysics() : null,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFF334155))),
                    ),
                    child: _buildHeaderRow(widths),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text('Ingen trafik matchar filtret.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: rows.length,
                            itemBuilder: (context, i) => _buildDataRow(rows[i], objects, deviceZone, widths),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}

const _headerStyle = TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold);
const _cellStyle = TextStyle(color: Colors.white, fontSize: 11);
