import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';

/// En rad i den kombinerade anslutnings-/loggvyn. Slår ihop aktiva
/// (accepterade) anslutningar från conntrack med nekade paket från
/// brandväggens deny-logg till en gemensam, filtrerbar modell.
class _TrafficRow {
  final bool accepted;
  final String protocol;
  final String srcIp;
  final int srcPort;
  final String dstIp;
  final int dstPort;
  final String srcMac;
  final String dstMac;
  final String stateOrChain;
  final String timestamp;

  _TrafficRow({
    required this.accepted,
    required this.protocol,
    required this.srcIp,
    required this.srcPort,
    required this.dstIp,
    required this.dstPort,
    required this.srcMac,
    required this.dstMac,
    required this.stateOrChain,
    required this.timestamp,
  });

  factory _TrafficRow.fromConntrack(ConntrackModel m) => _TrafficRow(
        accepted: true,
        protocol: m.protocol,
        srcIp: m.srcIp,
        srcPort: m.srcPort,
        dstIp: m.dstIp,
        dstPort: m.dstPort,
        srcMac: m.srcMac,
        dstMac: m.dstMac,
        stateOrChain: m.state,
        timestamp: '',
      );

  factory _TrafficRow.fromFirewallLog(FirewallLogModel m) => _TrafficRow(
        accepted: false,
        protocol: m.protocol,
        srcIp: m.srcIp,
        srcPort: m.srcPort,
        dstIp: m.dstIp,
        dstPort: m.dstPort,
        srcMac: m.srcMac,
        dstMac: m.dstMac,
        stateOrChain: m.chain,
        timestamp: m.timestamp,
      );
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
const List<double> _defaultColWidths = [62, 130, 60, 200, 130, 200, 130, 90];
const List<String> _colLabels = ['Åtgärd', 'Tid', 'Protokoll', 'Källa', 'Källans MAC', 'Mål', 'Målets MAC', 'State/Kedja'];
const double _colMinWidth = 40;
const double _resizeHandleWidth = 14;

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  Timer? _pollTimer;
  List<ConntrackModel> _accepted = [];
  List<FirewallLogModel> _denied = [];
  bool _isLoading = false;
  int? _hoveredResizeHandle;
  int? _activeResizeIndex; // Se identisk kommentar i policies_screen.dart
  final List<double> _colWidths = List<double>.from(_defaultColWidths);
  final ScrollController _hScrollController = ScrollController();

  // Filter
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _macController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _directionFilter = 'ANY'; // ANY, FROM, TO
  String _actionFilter = 'ALL'; // ALL, ACCEPT, DENY
  // IPv4 aktivt som default — det är i praktiken all trafik i det här
  // nätet idag, så IPv6 (om något någonsin dyker upp) eller "Alla" får
  // väljas medvetet istället för att blanda in i vyn från start.
  String _ipVersionFilter = 'IPV4'; // ALL, IPV4, IPV6

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
    final accepted = await provider.api.getConntrack();
    final denied = await provider.api.getFirewallLog();
    if (!mounted) return;
    setState(() {
      _accepted = accepted;
      _denied = denied;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final objects = (provider.candidateConfig ?? provider.runningConfig)?.objects ?? [];

    List<_TrafficRow> rows = [
      ..._accepted.map(_TrafficRow.fromConntrack),
      ..._denied.map(_TrafficRow.fromFirewallLog),
    ];

    if (_actionFilter == 'ACCEPT') {
      rows = rows.where((r) => r.accepted).toList();
    } else if (_actionFilter == 'DENY') {
      rows = rows.where((r) => !r.accepted).toList();
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
        if (_directionFilter == 'FROM') return matchesSrc;
        if (_directionFilter == 'TO') return matchesDst;
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
        return srcName.contains(nameFilter) || dstName.contains(nameFilter);
      }).toList();
    }

    // Nyast/mest relevant överst: nekad trafik har tidsstämpel, sortera på den
    // fallande; accepterade anslutningar (utan tidsstämpel) hamnar sist.
    rows.sort((a, b) {
      if (a.timestamp.isEmpty && b.timestamp.isEmpty) return 0;
      if (a.timestamp.isEmpty) return 1;
      if (b.timestamp.isEmpty) return -1;
      return b.timestamp.compareTo(a.timestamp);
    });

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
            Expanded(child: _buildTable(rows, objects)),
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
          _buildFilterField('Namn (objekt)', _nameController, width: 160),
          _buildDropdown('Riktning', _directionFilter, const {
            'ANY': 'Från/Till',
            'FROM': 'Från (källa)',
            'TO': 'Till (mål)',
          }, (v) => setState(() => _directionFilter = v)),
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
              _directionFilter = 'ANY';
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

  Widget _buildDataRow(_TrafficRow r, List<ObjectModel> objects, List<double> widths) {
    final srcName = _resolveObjectName(objects, r.srcIp);
    final dstName = _resolveObjectName(objects, r.dstIp);
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
  Widget _buildTable(List<_TrafficRow> rows, List<ObjectModel> objects) {
    return Container(
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
                            itemBuilder: (context, i) => _buildDataRow(rows[i], objects, widths),
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
}

const _headerStyle = TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold);
const _cellStyle = TextStyle(color: Colors.white, fontSize: 11);
