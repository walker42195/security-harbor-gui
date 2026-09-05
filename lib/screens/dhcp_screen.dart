import 'dart:async';
import '../theme.dart';
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
  /// Vilken lista som visas. Reservationer och utlåningar är två olika saker
  /// — det man konfigurerar respektive det som faktiskt delats ut — och att
  /// visa båda samtidigt gjorde sidan rörig.
  _DhcpView _view = _DhcpView.leases;
  bool _loading = false;
  Timer? _pollTimer;

  final _search = TextEditingController();
  String _ifaceFilter = 'ALL';

  int _sortCol = 0; // 0=namn,1=ip,2=mac,3=iface,4=zon,5=fick lease,6=utgår
  bool _sortAsc = true;
  // Reservationerna har EGEN sorteringsstate: kolumnerna är inte desamma som
  // utlåningarnas (ingen zon, inga tider), så ett delat kolumnindex hade
  // betytt olika saker i de två vyerna.
  int _resSortCol = 1; // 0=namn,1=ip,2=mac,3=gränssnitt,4=status
  bool _resSortAsc = true;

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

  Future<void> _confirmDeleteLease(DhcpLeaseModel l) async {
    final name = l.hostname.isEmpty ? l.ip : '${l.hostname} (${l.ip})';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ta bort DHCP-lease?'),
        content: Text('Frigör leasen för $name?\n\nAdressen går tillbaka till poolen. '
            'Enheten kan begära en ny lease direkt — sätt en reservation om du vill '
            'att den aldrig ska få adressen igen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Avbryt')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Ta bort', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    final err = await provider.api.deleteDhcpLease(l.ip);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err == null ? 'Lease ${l.ip} borttagen' : 'Kunde inte ta bort: $err'),
      backgroundColor: err == null ? AppColors.ok : AppColors.danger,
    ));
    await _poll();
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

  void _onResSort(int col) => setState(() {
        if (_resSortCol == col) {
          _resSortAsc = !_resSortAsc;
        } else {
          _resSortCol = col;
          _resSortAsc = true;
        }
      });

  /// Har reservationen en aktiv utlåning? Delas mellan statuskolumnen och
  /// sorteringen på den, så de inte kan komma isär.
  bool _reservationHasLease(DHCPReservationModel res) => _leases.any(
      (l) => l.mac.trim().toLowerCase() == res.mac.trim().toLowerCase());

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

  /// [original] anges när en BEFINTLIG reservation redigeras. Utan den kan
  /// man bara ändra fält som inte är en del av identiteten: byter man MAC
  /// eller flyttar reservationen till ett annat gränssnitt skulle den gamla
  /// annars ligga kvar som en dubblett.
  void _showReservationDialog(BuildContext context,
      {String hostname = '',
      String mac = '',
      String ip = '',
      String device = '',
      ({String device, DHCPReservationModel res})? original}) {
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
          backgroundColor: AppColors.surface,
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
                    Icon(Icons.push_pin, size: 18, color: AppColors.warn),
                    const SizedBox(width: 8),
                    Text(mac.isEmpty ? tr('dhcp.ny_dhcp_reservation') : tr('dhcp.reservera_ip_till_mac'),
                        style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(icon: Icon(Icons.close, size: 18, color: AppColors.textMuted), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                _resField(hostCtrl, tr('dhcp.namn_hostnamn_label'), tr('dhcp.namn_hostnamn_hint')),
                const SizedBox(height: 10),
                _resField(macCtrl, tr('dhcp.mac_adress'), 'aa:bb:cc:dd:ee:ff'),
                const SizedBox(height: 10),
                _resField(ipCtrl, tr('dhcp.reserverad_ip_label'), tr('dhcp.reserverad_ip_hint')),
                const SizedBox(height: 10),
                Text(tr('dhcp.granssnitt_dhcp_scope'), style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedDevice,
                      dropdownColor: AppColors.surface,
                      style: TextStyle(fontSize: 12, color: AppColors.text),
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
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.warnBg, foregroundColor: AppColors.onWarnBg),
                      child: Text(tr('dhcp.spara_reservation'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        final newMac = macCtrl.text.trim();
                        final newIp = ipCtrl.text.trim();
                        if (newMac.isEmpty || newIp.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(tr('dhcp.mac_och_ip_maste_anges'))));
                          return;
                        }
                        // Redigering som byter gränssnitt: ta bort posten på
                        // det gamla kortet först, annars blir den kvar där.
                        if (original != null && original.device != selectedDevice) {
                          _deleteReservation(original.device, original.res);
                        } else if (original != null) {
                          final remaining = _dhcpInterfaces()
                              .where((i) => i.device == original.device)
                              .expand((i) => i.dhcp!.reservations)
                              .where((r) => r.mac.trim().toLowerCase() != original.res.mac.trim().toLowerCase())
                              .toList();
                          _writeReservations(original.device, remaining);
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
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: TextField(
            controller: ctrl,
            style: TextStyle(fontSize: 12, color: AppColors.text),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  /// Reservationerna som en kolumnlista, i samma form som utlåningarna.
  /// Låg tidigare som en Wrap av "chips" där varje post klämde in namn, IP,
  /// MAC och gränssnitt på två rader — omöjligt att jämföra poster med
  /// varandra, vilket är hela poängen med en lista.
  Widget _buildReservationsTable(BuildContext context) {
    final reservations = _visibleReservations;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  sortColumnIndex: _resSortCol,
                  sortAscending: _resSortAsc,
                  headingRowHeight: 36,
                  dataRowMinHeight: 32,
                  dataRowMaxHeight: 32,
                  columns: [
                    DataColumn(label: Text(tr('dhcp.namn'), style: _hStyle), onSort: (i, _) => _onResSort(0)),
                    DataColumn(label: Text(tr('dhcp.ip_adress'), style: _hStyle), onSort: (i, _) => _onResSort(1)),
                    DataColumn(label: Text(tr('dhcp.mac_adress'), style: _hStyle), onSort: (i, _) => _onResSort(2)),
                    DataColumn(label: Text(tr('dhcp.granssnitt'), style: _hStyle), onSort: (i, _) => _onResSort(3)),
                    DataColumn(label: Text(tr('dhcp.status'), style: _hStyle), onSort: (i, _) => _onResSort(4)),
                    DataColumn(label: Text(tr('dhcp.atgarder'), style: _hStyle)),
                  ],
                  rows: reservations.map((e) {
                    // Har enheten en aktiv utlåning syns det direkt — en
                    // reservation som ingen klient hämtat är oftast ett
                    // tecken på fel MAC.
                    final active = _reservationHasLease(e.res);
                    return DataRow(cells: [
                      DataCell(Text(
                        e.res.hostname.isEmpty ? tr('dhcp.namnlos') : e.res.hostname,
                        style: TextStyle(
                            color: e.res.hostname.isEmpty ? AppColors.textFaint : AppColors.text,
                            fontSize: 11),
                      )),
                      DataCell(SelectableText(e.res.ip,
                          style: TextStyle(color: AppColors.accent, fontSize: 11))),
                      DataCell(SelectableText(e.res.mac,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                      DataCell(Text(e.device,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                      DataCell(active
                          ? Tooltip(
                              message: tr('dhcp.aktiv_lease_finns'),
                              child: Icon(Icons.check_circle, size: 15, color: AppColors.ok))
                          : Tooltip(
                              message: tr('dhcp.ingen_aktiv_lease'),
                              child: Icon(Icons.remove_circle_outline, size: 15, color: AppColors.textFaint))),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, size: 15, color: AppColors.accent),
                            tooltip: tr('dhcp.redigera'),
                            onPressed: () => _showReservationDialog(
                              context,
                              hostname: e.res.hostname,
                              mac: e.res.mac,
                              ip: e.res.ip,
                              device: e.device,
                              original: e,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 15, color: AppColors.danger),
                            tooltip: tr('dhcp.ta_bort'),
                            onPressed: () => _deleteReservation(e.device, e.res),
                          ),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
          if (_allReservations().isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(tr('dhcp.inga_reservationer_lagg_till_manuellt_eller'),
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            )
          else if (reservations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(tr('dhcp.inga_reservationer_matchar_filtret'),
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  /// Reservationer efter sökfiltret — samma sökfält som utlåningarna använder,
  /// så man inte behöver lära sig två filter.
  List<({String device, DHCPReservationModel res})> get _visibleReservations {
    final q = _search.text.trim().toLowerCase();
    final rows = _allReservations()
        .where((e) =>
            q.isEmpty ||
            e.res.hostname.toLowerCase().contains(q) ||
            e.res.ip.toLowerCase().contains(q) ||
            e.res.mac.toLowerCase().contains(q) ||
            e.device.toLowerCase().contains(q))
        .toList();
    return sortReservations(rows, _resSortCol, _resSortAsc, _reservationHasLease);
  }

  /// Växling mellan utlåningar och reservationer.
  Widget _buildViewToggle(BuildContext context) {
    Widget button(_DhcpView view, IconData icon, String label, int count) {
      final selected = _view == view;
      return ElevatedButton.icon(
        icon: Icon(icon, size: 15),
        label: Text('$label ($count)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? AppColors.accent : AppColors.surface,
          foregroundColor: selected ? Colors.black : AppColors.textMuted,
          side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
          elevation: 0,
        ),
        onPressed: selected ? null : () => setState(() => _view = view),
      );
    }

    return Row(
      children: [
        button(_DhcpView.leases, Icons.dns_outlined, tr('dhcp.leasade_adresser'), _leases.length),
        const SizedBox(width: 8),
        button(_DhcpView.reservations, Icons.push_pin, tr('dhcp.statiska_reservationer'), _allReservations().length),
        const Spacer(),
        if (_view == _DhcpView.reservations)
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 14),
            label: Text(tr('dhcp.lagg_till_reservation'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warnBg, foregroundColor: AppColors.onWarnBg),
            onPressed: () => _showReservationDialog(context),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Container(
      color: AppColors.bg,
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices_other, color: AppColors.accent, size: 22),
                const SizedBox(width: 10),
                Text(tr('dhcp.dhcp_klienter'), style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: _loading
                      ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                      : Icon(Icons.refresh, size: 18, color: AppColors.accent),
                  onPressed: _loading ? null : _poll,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(tr('dhcp.enheter_som_fatt_en_adress_av'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),

            // Utlåningar eller reservationer — en i taget.
            _buildViewToggle(context),
            const SizedBox(height: 12),

            // Filterrad
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
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
                      style: TextStyle(fontSize: 12, color: AppColors.text),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 16, color: AppColors.textMuted),
                        labelText: tr('dhcp.sok_namn_ip_eller_mac'),
                        labelStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
                        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
                        child: DropdownButton<String>(
                          value: _ifaceFilter,
                          dropdownColor: AppColors.surface,
                          style: TextStyle(fontSize: 12, color: AppColors.text),
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
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  if (_search.text.trim().isNotEmpty || _ifaceFilter != 'ALL')
                    TextButton.icon(
                      icon: Icon(Icons.clear, size: 14, color: AppColors.textMuted),
                      label: Text(tr('dhcp.rensa'), style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      onPressed: () => setState(() {
                        _search.clear();
                        _ifaceFilter = 'ALL';
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_view == _DhcpView.reservations)
              Expanded(child: _buildReservationsTable(context))
            else
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
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
                              DataColumn(label: Text('Ta bort', style: _hStyle)),
                            ],
                            rows: visible
                                .map((l) => DataRow(cells: [
                                      DataCell(Text(l.hostname.isEmpty ? '(okänt)' : l.hostname,
                                          style: TextStyle(color: l.hostname.isEmpty ? AppColors.textFaint : AppColors.text, fontSize: 11))),
                                      DataCell(SelectableText(l.ip, style: TextStyle(color: AppColors.accent, fontSize: 11))),
                                      DataCell(SelectableText(l.mac, style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                      DataCell(Text(l.interfaceDevice, style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                      DataCell(Text(l.zone, style: TextStyle(color: AppColors.warn, fontSize: 11))),
                                      DataCell(Text(_fmtTime(l.startTs), style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                      DataCell(Text(_expiry(l.expireTs), style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                      DataCell(_isReserved(l.mac)
                                          ? Tooltip(message: 'Redan reserverad', child: Icon(Icons.check_circle, size: 16, color: AppColors.ok))
                                          : IconButton(
                                              icon: Icon(Icons.push_pin_outlined, size: 16, color: AppColors.warn),
                                              tooltip: tr('dhcp.reservera_denna_ip_till_mac_adressen'),
                                              onPressed: () => _showReservationDialog(context, hostname: l.hostname, mac: l.mac, ip: l.ip, device: l.interfaceDevice),
                                            )),
                                      DataCell(IconButton(
                                        icon: Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                                        tooltip: 'Frigör (ta bort) denna lease',
                                        onPressed: () => _confirmDeleteLease(l),
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
                            style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                      )
                    else if (visible.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(tr('dhcp.inga_klienter_matchar_filtret'), style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
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

TextStyle get _hStyle => TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold);

/// Vilken av DHCP-sidans två listor som visas.
enum _DhcpView { leases, reservations }

/// Sorterar reservationslistan. Toppnivåfunktion, inte en metod, så att
/// ordningen går att testa utan att bygga upp en hel skärm.
///
/// [hasLease] skickas in i stället för att slås upp här: samma predikat
/// används av statuskolumnen, och de två får inte kunna komma isär.
List<({String device, DHCPReservationModel res})> sortReservations(
  List<({String device, DHCPReservationModel res})> rows,
  int col,
  bool ascending,
  bool Function(DHCPReservationModel) hasLease,
) {
  int cmp(({String device, DHCPReservationModel res}) a,
      ({String device, DHCPReservationModel res}) b) {
    int c;
    switch (col) {
      case 1:
        // Numeriskt, så .2 hamnar före .10 — en ren textjämförelse hade gett
        // .10 före .2, vilket är oläsbart i en adresslista.
        c = ipSortKey(a.res.ip).compareTo(ipSortKey(b.res.ip));
        break;
      case 2:
        c = a.res.mac.toLowerCase().compareTo(b.res.mac.toLowerCase());
        break;
      case 3:
        c = a.device.toLowerCase().compareTo(b.device.toLowerCase());
        break;
      case 4:
        // Utan aktiv utlåning först vid stigande sortering: det är de raderna
        // som behöver uppmärksamhet (oftast en felskriven MAC).
        c = (hasLease(a.res) ? 1 : 0).compareTo(hasLease(b.res) ? 1 : 0);
        break;
      default:
        c = a.res.hostname.toLowerCase().compareTo(b.res.hostname.toLowerCase());
    }
    // Lika värden faller tillbaka på IP, så ordningen inte hoppar runt mellan
    // omritningar när flera rader delar sorteringsnyckel.
    if (c == 0) c = ipSortKey(a.res.ip).compareTo(ipSortKey(b.res.ip));
    return ascending ? c : -c;
  }

  final sorted = List<({String device, DHCPReservationModel res})>.from(rows);
  sorted.sort(cmp);
  return sorted;
}

/// Sorteringsnyckel för en IPv4-adress. 0 för allt som inte är giltig IPv4,
/// så sorteringen inte kraschar på en tom eller felskriven adress.
int ipSortKey(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return 0;
  var key = 0;
  for (final p in parts) {
    final v = int.tryParse(p);
    if (v == null || v < 0 || v > 255) return 0;
    key = (key << 8) | v;
  }
  return key;
}
