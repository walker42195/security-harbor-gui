import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';

/// DHCP-klienter (Fas 6) — visar alla enheter som fått en adress via
/// brandväggens DHCP-server, för alla gränssnitt UTOM WAN (ingen DHCP körs
/// där). Data kommer från /api/v1/dhcp/leases (Kea-utlåningar berikade med
/// gränssnitt/zon). Listan går att söka (namn/IP/MAC), filtrera på
/// gränssnitt och sortera på valfri kolumn.
class DhcpScreen extends StatefulWidget {
  const DhcpScreen({super.key});

  @override
  State<DhcpScreen> createState() => _DhcpScreenState();
}

class _DhcpScreenState extends State<DhcpScreen> {
  List<DhcpLeaseModel> _leases = [];
  bool _loading = false;
  Timer? _pollTimer;

  final _search = TextEditingController();
  String _ifaceFilter = 'ALL';

  int _sortCol = 0; // 0=namn,1=ip,2=mac,3=iface,4=zon,5=utgår
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    if (!provider.isAuthenticated) return;
    setState(() => _loading = true);
    final leases = await provider.api.getDhcpLeases();
    if (!mounted) return;
    setState(() {
      _leases = leases;
      _loading = false;
    });
  }

  List<String> get _interfaces {
    final set = <String>{for (final l in _leases) if (l.interfaceDevice.isNotEmpty) l.interfaceDevice};
    final list = set.toList()..sort();
    return list;
  }

  List<DhcpLeaseModel> get _visible {
    final q = _search.text.trim().toLowerCase();
    var rows = _leases.where((l) {
      if (_ifaceFilter != 'ALL' && l.interfaceDevice != _ifaceFilter) return false;
      if (q.isEmpty) return true;
      return l.hostname.toLowerCase().contains(q) ||
          l.ip.toLowerCase().contains(q) ||
          l.mac.toLowerCase().contains(q);
    }).toList();

    int cmp(DhcpLeaseModel a, DhcpLeaseModel b) {
      int c;
      switch (_sortCol) {
        case 1:
          c = _ipKey(a.ip).compareTo(_ipKey(b.ip));
          break;
        case 2:
          c = a.mac.toLowerCase().compareTo(b.mac.toLowerCase());
          break;
        case 3:
          c = a.interfaceDevice.toLowerCase().compareTo(b.interfaceDevice.toLowerCase());
          break;
        case 4:
          c = a.zone.toLowerCase().compareTo(b.zone.toLowerCase());
          break;
        case 5:
          c = a.startTs.compareTo(b.startTs);
          break;
        case 6:
          c = a.expireTs.compareTo(b.expireTs);
          break;
        default:
          c = a.hostname.toLowerCase().compareTo(b.hostname.toLowerCase());
      }
      return _sortAsc ? c : -c;
    }

    rows.sort(cmp);
    return rows;
  }

  // Sorterar IPv4 numeriskt (så .2 kommer före .10) istället för som text.
  int _ipKey(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return 0;
    var key = 0;
    for (final p in parts) {
      key = key * 256 + (int.tryParse(p) ?? 0);
    }
    return key;
  }

  String _expiry(int ts) {
    if (ts <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000).toLocal();
    final now = DateTime.now();
    final diff = dt.difference(now);
    final when = '${dt.year}-${_pad2(dt.month)}-${_pad2(dt.day)} ${_pad2(dt.hour)}:${_pad2(dt.minute)}';
    if (diff.isNegative) return '$when (utgången)';
    if (diff.inHours >= 1) return '$when (om ${diff.inHours}h)';
    return '$when (om ${diff.inMinutes}m)';
  }

  String _pad2(int n) => n.toString().padLeft(2, '0');

  // Absolut tidpunkt utan relativt tillägg — används för "Fick lease".
  String _fmtTime(int ts) {
    if (ts <= 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000).toLocal();
    return '${dt.year}-${_pad2(dt.month)}-${_pad2(dt.day)} ${_pad2(dt.hour)}:${_pad2(dt.minute)}';
  }

  void _onSort(int col) => setState(() {
        if (_sortCol == col) {
          _sortAsc = !_sortAsc;
        } else {
          _sortCol = col;
          _sortAsc = true;
        }
      });

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices_other, color: Colors.cyanAccent, size: 22),
                const SizedBox(width: 10),
                const Text('DHCP-klienter', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: _loading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                      : const Icon(Icons.refresh, size: 18, color: Colors.cyanAccent),
                  onPressed: _loading ? null : _poll,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Enheter som fått en adress av brandväggens DHCP-server (alla gränssnitt utom WAN).',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 12),

            // Filterrad
            Container(
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
                  SizedBox(
                    width: 280,
                    height: 34,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey),
                        labelText: 'Sök namn, IP eller MAC',
                        labelStyle: TextStyle(fontSize: 11, color: Colors.grey),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFF334155)), borderRadius: BorderRadius.circular(4)),
                        child: DropdownButton<String>(
                          value: _ifaceFilter,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          items: [
                            const DropdownMenuItem(value: 'ALL', child: Text('Gränssnitt: Alla')),
                            ..._interfaces.map((i) => DropdownMenuItem(value: i, child: Text('Gränssnitt: $i'))),
                          ],
                          onChanged: (v) => setState(() => _ifaceFilter = v ?? 'ALL'),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    _search.text.trim().isNotEmpty || _ifaceFilter != 'ALL'
                        ? '${visible.length} av ${_leases.length} klienter'
                        : '${_leases.length} klienter',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  if (_search.text.trim().isNotEmpty || _ifaceFilter != 'ALL')
                    TextButton.icon(
                      icon: const Icon(Icons.clear, size: 14, color: Colors.grey),
                      label: const Text('Rensa', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      onPressed: () => setState(() {
                        _search.clear();
                        _ifaceFilter = 'ALL';
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  border: Border.all(color: const Color(0xFF334155)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tabellhuvudet visas ALLTID (även utan klienter), så
                    // kolumnerna syns direkt — bara rad-innehållet är tomt.
                    Flexible(
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            sortColumnIndex: _sortCol,
                            sortAscending: _sortAsc,
                            headingRowHeight: 36,
                            dataRowMinHeight: 32,
                            dataRowMaxHeight: 32,
                            columns: [
                              DataColumn(label: const Text('Namn', style: _hStyle), onSort: (i, _) => _onSort(0)),
                              DataColumn(label: const Text('IP-adress', style: _hStyle), onSort: (i, _) => _onSort(1)),
                              DataColumn(label: const Text('MAC-adress', style: _hStyle), onSort: (i, _) => _onSort(2)),
                              DataColumn(label: const Text('Gränssnitt', style: _hStyle), onSort: (i, _) => _onSort(3)),
                              DataColumn(label: const Text('Zon', style: _hStyle), onSort: (i, _) => _onSort(4)),
                              DataColumn(label: const Text('Fick lease', style: _hStyle), onSort: (i, _) => _onSort(5)),
                              DataColumn(label: const Text('Utgår', style: _hStyle), onSort: (i, _) => _onSort(6)),
                            ],
                            rows: visible
                                .map((l) => DataRow(cells: [
                                      DataCell(Text(l.hostname.isEmpty ? '(okänt)' : l.hostname,
                                          style: TextStyle(color: l.hostname.isEmpty ? Colors.white38 : Colors.white, fontSize: 11))),
                                      DataCell(SelectableText(l.ip, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11))),
                                      DataCell(SelectableText(l.mac, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                                      DataCell(Text(l.interfaceDevice, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                                      DataCell(Text(l.zone, style: const TextStyle(color: Colors.amberAccent, fontSize: 11))),
                                      DataCell(Text(_fmtTime(l.startTs), style: const TextStyle(color: Colors.white54, fontSize: 11))),
                                      DataCell(Text(_expiry(l.expireTs), style: const TextStyle(color: Colors.white54, fontSize: 11))),
                                    ]))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                    if (_leases.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Inga aktiva DHCP-utlåningar. Enheter dyker upp här när de fått en adress av DHCP-servern.',
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      )
                    else if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Inga klienter matchar filtret.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _hStyle = TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold);
