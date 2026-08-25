import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../localization.dart';

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

  // --- Statiska reservationer (bor i varje interfaces DHCP-scope) ---

  // Alla reservationer i configen tillsammans med vilket gränssnitt de hör till.
  List<({String device, DHCPReservationModel res})> _allReservations() {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    if (cfg == null) return [];
    final out = <({String device, DHCPReservationModel res})>[];
    for (final iface in cfg.interfaces) {
      final dhcp = iface.dhcp;
      if (dhcp == null) continue;
      for (final r in dhcp.reservations) {
        out.add((device: iface.device, res: r));
      }
    }
    return out;
  }

  bool _isReserved(String mac) {
    final m = mac.trim().toLowerCase();
    if (m.isEmpty) return false;
    return _allReservations().any((e) => e.res.mac.trim().toLowerCase() == m);
  }

  // Gränssnitt som har DHCP aktiverat (dit en reservation kan knytas).
  List<InterfaceModel> _dhcpInterfaces() {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    if (cfg == null) return [];
    return cfg.interfaces.where((i) => i.dhcp != null).toList();
  }

  // Skriver om reservationslistan för ETT gränssnitt och uppdaterar kandidaten.
  void _writeReservations(String device, List<DHCPReservationModel> reservations) {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    if (cfg == null) return;
    final updatedIfaces = cfg.interfaces.map((iface) {
      if (iface.device != device || iface.dhcp == null) return iface;
      final d = iface.dhcp!;
      final newDhcp = DHCPConfigModel(
        enabled: d.enabled,
        rangeStart: d.rangeStart,
        rangeEnd: d.rangeEnd,
        gateway: d.gateway,
        dnsServers: d.dnsServers,
        leaseTimeSec: d.leaseTimeSec,
        reservations: reservations,
      );
      return iface.copyWith(dhcp: newDhcp);
    }).toList();
    provider.updateCandidate(cfg.copyWith(interfaces: updatedIfaces));
  }

  void _deleteReservation(String device, DHCPReservationModel res) {
    final iface = _dhcpInterfaces().where((i) => i.device == device);
    if (iface.isEmpty) return;
    final remaining = iface.first.dhcp!.reservations
        .where((r) => !(r.mac == res.mac && r.ip == res.ip))
        .toList();
    _writeReservations(device, remaining);
    setState(() {});
  }

  void _showReservationDialog(BuildContext context, {String hostname = '', String mac = '', String ip = '', String device = ''}) {
    final hostCtrl = TextEditingController(text: hostname);
    final macCtrl = TextEditingController(text: mac);
    final ipCtrl = TextEditingController(text: ip);
    final ifaces = _dhcpInterfaces();
    if (ifaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('dhcp.inget_granssnitt_har_dhcp_aktiverat_aktivera')),
      ));
      return;
    }
    String selectedDevice = ifaces.any((i) => i.device == device) ? device : ifaces.first.device;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 420.0),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.push_pin, size: 18, color: Colors.amberAccent),
                    const SizedBox(width: 8),
                    Text(mac.isEmpty ? tr('dhcp.ny_dhcp_reservation') : tr('dhcp.reservera_ip_till_mac'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                _resField(hostCtrl, tr('dhcp.namn_hostnamn_label'), tr('dhcp.namn_hostnamn_hint')),
                const SizedBox(height: 10),
                _resField(macCtrl, tr('dhcp.mac_adress'), 'aa:bb:cc:dd:ee:ff'),
                const SizedBox(height: 10),
                _resField(ipCtrl, tr('dhcp.reserverad_ip_label'), tr('dhcp.reserverad_ip_hint')),
                const SizedBox(height: 10),
                Text(tr('dhcp.granssnitt_dhcp_scope'), style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF334155)), borderRadius: BorderRadius.circular(4)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedDevice,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      items: ifaces
                          .map((i) => DropdownMenuItem(value: i.device, child: Text('${i.device}${i.zone.isNotEmpty ? ' (${i.zone})' : ''}')))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedDevice = v ?? selectedDevice),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('dhcp.avbryt'), style: TextStyle(fontSize: 12))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                      child: Text(tr('dhcp.spara_reservation'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        final newMac = macCtrl.text.trim();
                        final newIp = ipCtrl.text.trim();
                        if (newMac.isEmpty || newIp.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(tr('dhcp.mac_och_ip_maste_anges'))));
                          return;
                        }
                        final ifaceMatch = _dhcpInterfaces().where((i) => i.device == selectedDevice);
                        final current = ifaceMatch.isNotEmpty ? List<DHCPReservationModel>.from(ifaceMatch.first.dhcp!.reservations) : <DHCPReservationModel>[];
                        // Ersätt ev. befintlig reservation för samma MAC.
                        current.removeWhere((r) => r.mac.trim().toLowerCase() == newMac.toLowerCase());
                        current.add(DHCPReservationModel(hostname: hostCtrl.text.trim(), mac: newMac, ip: newIp));
                        _writeReservations(selectedDevice, current);
                        Navigator.pop(ctx);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(tr('dhcp.reservation_tillagd_kom_ihag_att_applicera')),
                        ));
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

  Widget _resField(TextEditingController ctrl, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: TextField(
            controller: ctrl,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReservationsCard(BuildContext context) {
    final reservations = _allReservations();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.push_pin, size: 16, color: Colors.amberAccent),
                  const SizedBox(width: 8),
                  Text(tr('dhcp.statiska_reservationer'), style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('(${reservations.length})', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 14),
                label: Text(tr('dhcp.lagg_till_reservation'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                onPressed: () => _showReservationDialog(context),
              ),
            ],
          ),
          if (reservations.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(tr('dhcp.inga_reservationer_lagg_till_manuellt_eller'),
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reservations.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      border: Border.all(color: const Color(0xFF334155)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.res.hostname.isEmpty ? '(namnlös)' : e.res.hostname,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            Text('${e.res.ip}  ·  ${e.res.mac}  ·  ${e.device}',
                                style: const TextStyle(color: Colors.white54, fontSize: 10)),
                          ],
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _deleteReservation(e.device, e.res),
                          child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

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
                Text(tr('dhcp.dhcp_klienter'), style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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
            Text(tr('dhcp.enheter_som_fatt_en_adress_av'),
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 12),

            // Statiska reservationer (MAC -> IP)
            _buildReservationsCard(context),
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
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey),
                        labelText: tr('dhcp.sok_namn_ip_eller_mac'),
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
                            DropdownMenuItem(value: 'ALL', child: Text(tr('dhcp.granssnitt_alla'))),
                            ..._interfaces.map((i) => DropdownMenuItem(value: i, child: Text(trp('dhcp.granssnitt_colon', {'name': i})))),
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
                      label: Text(tr('dhcp.rensa'), style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                              DataColumn(label: Text(tr('dhcp.namn'), style: _hStyle), onSort: (i, _) => _onSort(0)),
                              DataColumn(label: Text(tr('dhcp.ip_adress'), style: _hStyle), onSort: (i, _) => _onSort(1)),
                              DataColumn(label: Text(tr('dhcp.mac_adress'), style: _hStyle), onSort: (i, _) => _onSort(2)),
                              DataColumn(label: Text(tr('dhcp.granssnitt'), style: _hStyle), onSort: (i, _) => _onSort(3)),
                              DataColumn(label: Text(tr('dhcp.zon'), style: _hStyle), onSort: (i, _) => _onSort(4)),
                              DataColumn(label: Text(tr('dhcp.fick_lease'), style: _hStyle), onSort: (i, _) => _onSort(5)),
                              DataColumn(label: Text(tr('dhcp.utgar'), style: _hStyle), onSort: (i, _) => _onSort(6)),
                              DataColumn(label: Text(tr('dhcp.reservera'), style: _hStyle)),
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
                                      DataCell(_isReserved(l.mac)
                                          ? const Tooltip(message: 'Redan reserverad', child: Icon(Icons.check_circle, size: 16, color: Colors.greenAccent))
                                          : IconButton(
                                              icon: const Icon(Icons.push_pin_outlined, size: 16, color: Colors.amberAccent),
                                              tooltip: tr('dhcp.reservera_denna_ip_till_mac_adressen'),
                                              onPressed: () => _showReservationDialog(context, hostname: l.hostname, mac: l.mac, ip: l.ip, device: l.interfaceDevice),
                                            )),
                                    ]))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                    if (_leases.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(tr('dhcp.inga_aktiva_dhcp_utlaningar_enheter_dyker'),
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      )
                    else if (visible.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(tr('dhcp.inga_klienter_matchar_filtret'), style: TextStyle(color: Colors.white38, fontSize: 12)),
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
