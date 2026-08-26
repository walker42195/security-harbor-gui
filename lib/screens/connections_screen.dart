import 'dart:async';
import '../theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../localization.dart';
import '../log_filter.dart';
import '../log_filter_prefs.dart';
import '../time_format.dart';
import '../object_index.dart';

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

  /// Radens fält som filtermotorn (log_filter.dart) frågar mot.
  ///
  /// Käll- och målfälten innehåller BÅDE adressen och objektnamnet, så att
  /// `src:10.0.0.50` och `src:Skrivare` fungerar lika bra — man minns sällan
  /// IP-adresser, men objektet har man själv döpt.
  LogRowFields filterFields(String? srcName, String? dstName, String direction) => {
        'src': [srcIp, srcName ?? ''],
        'dst': [dstIp, dstName ?? ''],
        'sport': [srcPort > 0 ? '$srcPort' : ''],
        'dport': [dstPort > 0 ? '$dstPort' : ''],
        'proto': [protocol],
        'action': [accepted ? 'accept' : 'deny'],
        'rule': [policyName],
        'srcmac': [srcMac],
        'dstmac': [dstMac],
        'in': [inIface],
        'out': [outIface],
        'dir': [direction],
      };

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

  // Riktningen avgörs av VILKET KORT trafiken passerar, inte av vad den
  // interna zonen råkar heta.
  //
  // Villkoret krävde tidigare att källzonen hette exakt "LAN". En klient på
  // ett VLAN — vars zon heter t.ex. "VLAN 9" — klassades därför som
  // "Internt" trots att trafiken gick ut på WAN-kortet. I praktiken fick
  // bara 10.0.0.0/24 rätt riktning, och all VLAN-trafik mot internet såg ut
  // att stanna i huset (rapporterat 2026-08-26).
  if (inZone == 'WAN') return 'IN';
  if (outZone == 'WAN') return 'OUT';
  return 'INTERNAL';
}

/// Slår upp ett läsbart objektnamn för en IP-adress mot de Host/Network-objekt
/// som finns i den körande konfigurationen (samma objekt som används i
/// Policy-editorn). Enkel exakt-match för Host och CIDR-innehåll för Network.
/// Grov men tillräcklig avgörning av IP-version: en IPv6-adress innehåller
/// alltid ":", en IPv4-adress (eller en IPv4:port-sträng) aldrig.
bool _isIPv6(String ip) => ip.contains(':');

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

/// Kolumnordning delad mellan rubrikraden och varje datarad, så att
/// bredderna alltid är synkade. Källa/Mål var tidigare Expanded(flex: 3) men
/// måste vara fasta bredder för att kunna dras i storlek.
const List<double> _defaultColWidths = [62, 130, 90, 170, 60, 200, 130, 200, 130, 90];
List<String> _colLabels() => [
  tr('conn.col_atgard'),
  tr('conn.col_tid'),
  tr('conn.col_riktning'),
  tr('conn.col_regel'),
  tr('conn.col_protokoll'),
  tr('conn.col_kalla'),
  tr('conn.col_kallans_mac'),
  tr('conn.col_mal'),
  tr('conn.col_malets_mac'),
  tr('conn.col_state_kedja'),
];
const double _colMinWidth = 40;
const double _resizeHandleWidth = 14;

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  Timer? _pollTimer;
  List<FirewallLogModel> _entries = [];
  /// Hur långt bakåt loggen hämtas. Tidigare hämtades alltid de 500 senaste
  /// raderna, vilket med brandväggens loggvolym (~680 rader/minut) motsvarade
  /// omkring 45 sekunder — man kunde inte titta på något som hänt nyss.
  String _window = LogFilterPrefs.defaults.window;
  /// True när agenten klippte svaret vid sitt tak. Måste synas: annars tror
  /// man att det inte fanns mer trafik, i stället för att man bad om för
  /// mycket.
  bool _truncated = false;
  bool _isLoading = false;
  int? _hoveredResizeHandle;
  int? _activeResizeIndex; // Se identisk kommentar i policies_screen.dart
  final List<double> _colWidths = List<double>.from(_defaultColWidths);
  final ScrollController _hScrollController = ScrollController();

  // Filter
  /// Check Point-liknande filteruttryck. Subsumerar de enkla fälten nedan —
  /// de finns kvar eftersom de är snabbare för det allra vanligaste fallet —
  /// men är det enda sättet att skriva ett UNDANTAG ("visa allt utom ...").
  final TextEditingController _exprController = TextEditingController();
  /// Syntaxfel i uttrycket, visat under fältet. Vid fel filtreras INTE
  /// listan: att tyst dölja allt medan man skriver halva uttrycket vore
  /// obegripligt.
  String? _exprError;

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _macController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _directionFilterField = LogFilterPrefs.defaults.directionField; // ANY, FROM, TO — för IP-fältet ovan
  String _actionFilter = LogFilterPrefs.defaults.action; // ALL, ACCEPT, DENY
  // IPv4 aktivt som default — det är i praktiken all trafik i det här
  // nätet idag, så IPv6 (om något någonsin dyker upp) eller "Alla" får
  // väljas medvetet istället för att blanda in i vyn från start.
  String _ipVersionFilter = LogFilterPrefs.defaults.ipVersion; // ALL, IPV4, IPV6
  // Riktning relativt brandväggen (WAN/LAN-zonbaserad, se
  // _classifyDirection) — separat från _directionFilterField ovan, som
  // bara styr IP-fältets Från/Till-tolkning.
  String _trafficDirectionFilter = LogFilterPrefs.defaults.trafficDirection; // ALL, IN, OUT, INTERNAL

  // Paus fryser den automatiska uppdateringen så listan slutar rulla på
  // (manuell uppdatering via knappen fungerar ändå).
  bool _paused = false;
  // Dölj DefaultDeny: gömmer de generiska "logga och neka allt annat"-
  // raderna (SH-DENY-*-DefaultDeny) så bara träffar på namngivna regler syns.
  bool _hideDefaultDeny = false;

  @override
  void initState() {
    super.initState();
    // Filtren läses INNAN första hämtningen. Tidsfönstret styr vad som
    // hämtas, så en hämtning med standardvärdet först hade inneburit ett
    // bortkastat anrop — och en synlig blink där listan visar fel period.
    _restoreFilters().then((_) {
      if (!mounted) return;
      _poll();
      _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!_paused) _poll();
      });
    });
  }

  /// Återställer filtren från förra besöket.
  Future<void> _restoreFilters() async {
    final saved = await LogFilterPrefs.load();
    if (!mounted) return;
    setState(() {
      _exprController.text = saved.expression;
      _ipController.text = saved.ip;
      _macController.text = saved.mac;
      _nameController.text = saved.name;
      _directionFilterField = saved.directionField;
      _trafficDirectionFilter = saved.trafficDirection;
      _actionFilter = saved.action;
      _ipVersionFilter = saved.ipVersion;
      _window = saved.window;
      _hideDefaultDeny = saved.hideDefaultDeny;
    });
  }

  /// Kallas vid varje filterändring: uppdaterar vyn och sparar valen.
  ///
  /// Sparandet är avsiktligt inte fördröjt. Skrivningen är liten och sker på
  /// tangenttryck som ändå utlöser en omritning; en debounce hade bara
  /// riskerat att tappa de sista tecknen om man byter vy direkt efter att ha
  /// skrivit dem.
  void _onFilterChanged([VoidCallback? mutate]) {
    setState(() => mutate?.call());
    _currentFilters().save();
  }

  LogFilterPrefs _currentFilters() => LogFilterPrefs(
        expression: _exprController.text,
        ip: _ipController.text,
        mac: _macController.text,
        name: _nameController.text,
        directionField: _directionFilterField,
        trafficDirection: _trafficDirectionFilter,
        action: _actionFilter,
        ipVersion: _ipVersionFilter,
        window: _window,
        hideDefaultDeny: _hideDefaultDeny,
      );

  @override
  void dispose() {
    _pollTimer?.cancel();
    _exprController.dispose();
    _ipController.dispose();
    _macController.dispose();
    _nameController.dispose();
    _hScrollController.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    setState(() => _isLoading = true);
    final result = await provider.api.getFirewallLog(window: _window);
    if (!mounted) return;
    setState(() {
      _entries = result.entries;
      _truncated = result.truncated;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    final objects = cfg?.objects ?? [];
    final deviceZone = <String, String>{for (final iface in cfg?.interfaces ?? <InterfaceModel>[]) iface.device: iface.zone};
    // Byggs EN gång per omritning i stället för att sökas linjärt sex gånger
    // per rad. Se lib/object_index.dart för varför det spelar roll.
    final nameIndex = ObjectNameIndex.build(objects);

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
        final srcName = nameIndex.lookup(r.srcIp)?.toLowerCase() ?? '';
        final dstName = nameIndex.lookup(r.dstIp)?.toLowerCase() ?? '';
        final policyName = r.policyName.toLowerCase();
        return srcName.contains(nameFilter) || dstName.contains(nameFilter) || policyName.contains(nameFilter);
      }).toList();
    }

    if (_hideDefaultDeny) {
      rows = rows.where((r) => r.policyName != 'DefaultDeny').toList();
    }

    // Filteruttrycket sist: det är det mest uttrycksfulla filtret, och att
    // köra det på en redan bantad lista är billigare.
    final exprText = _exprController.text.trim();
    if (exprText.isNotEmpty) {
      try {
        final filter = LogFilter.parse(exprText);
        _exprError = null;
        rows = rows.where((r) {
          final direction = _classifyDirection(r, deviceZone);
          return filter.matches(r.filterFields(
            nameIndex.lookup(r.srcIp),
            nameIndex.lookup(r.dstIp),
            direction,
          ));
        }).toList();
      } on LogFilterException catch (e) {
        // Behåll listan ofiltrerad och visa felet — halvskrivna uttryck ska
        // inte se ut som "inga träffar".
        _exprError = e.message;
      }
    } else {
      _exprError = null;
    }

    rows.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Container(
      color: AppColors.bg,
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.list_alt, color: AppColors.accent, size: 22),
                    SizedBox(width: 10),
                    Text(tr('conn.anslutningar_loggning'),
                      style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    // Frågetecknet ligger i sidhuvudet och inte bara som en
                    // liten ikon inne i filterfältet: hjälpen behövs INNAN
                    // man vet att fältet finns, inte efter.
                    IconButton(
                      icon: Icon(Icons.help_outline, size: 17, color: AppColors.accent),
                      tooltip: tr('conn.filter_hjalp_titel'),
                      splashRadius: 16,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: _showFilterHelp,
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_isLoading && !_paused)
                      Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                      ),
                    Text(trp('conn.rader_count', {'n': '${rows.length}'}), style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(width: 10),
                    // Dölj/visa DefaultDeny-raderna.
                    TextButton.icon(
                      icon: Icon(_hideDefaultDeny ? Icons.visibility_off : Icons.visibility, size: 15, color: _hideDefaultDeny ? AppColors.caution : AppColors.textMuted),
                      label: Text(_hideDefaultDeny ? tr('conn.defaultdeny_dold') : tr('conn.dolj_defaultdeny'),
                          style: TextStyle(fontSize: 11, color: _hideDefaultDeny ? AppColors.caution : AppColors.textMuted)),
                      onPressed: () => _onFilterChanged(() => _hideDefaultDeny = !_hideDefaultDeny),
                    ),
                    const SizedBox(width: 4),
                    // Pausa/återuppta den automatiska uppdateringen.
                    TextButton.icon(
                      icon: Icon(_paused ? Icons.play_arrow : Icons.pause, size: 16, color: _paused ? AppColors.ok : AppColors.warn),
                      label: Text(_paused ? tr('conn.pausad') : tr('conn.pausa'),
                          style: TextStyle(fontSize: 11, color: _paused ? AppColors.ok : AppColors.warn)),
                      onPressed: () => setState(() => _paused = !_paused),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, size: 18, color: AppColors.accent),
                      tooltip: tr('conn.uppdatera_nu'),
                      onPressed: _poll,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildFilterBar(),
            if (_truncated) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.warn),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(trp('conn.klippt', {'max': '3000'}),
                        style: TextStyle(color: AppColors.warn, fontSize: 11)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Expanded(child: _buildTable(rows, nameIndex, deviceZone)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildExpressionField(),
          const SizedBox(height: 10),
          Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildFilterField(tr('conn.ip_adress'), _ipController, width: 160),
          _buildFilterField(tr('conn.mac_adress'), _macController, width: 160),
          Tooltip(
            message: tr('conn.namn_regel_tooltip'),
            child: _buildFilterField(tr('conn.namn_regel'), _nameController, width: 180),
          ),
          _buildDropdown(tr('conn.fran_till'), _directionFilterField, {
            'ANY': tr('conn.fran_till'),
            'FROM': tr('conn.fran_kalla'),
            'TO': tr('conn.till_mal'),
          }, (v) => _onFilterChanged(() => _directionFilterField = v)),
          _buildDropdown(tr('conn.riktning'), _trafficDirectionFilter, {
            'ALL': tr('conn.alla'),
            'IN': tr('conn.inkommande'),
            'OUT': tr('conn.utgaende'),
            'INTERNAL': tr('conn.internt_lokalt'),
          }, (v) => _onFilterChanged(() => _trafficDirectionFilter = v)),
          _buildDropdown(tr('conn.col_atgard'), _actionFilter, {
            'ALL': tr('conn.alla'),
            'ACCEPT': tr('conn.endast_accept'),
            'DENY': tr('conn.endast_deny'),
          }, (v) => _onFilterChanged(() => _actionFilter = v)),
          // Tidsfönstret hör till HÄMTNINGEN, inte till filtreringen — därför
          // laddas loggen om när det ändras, till skillnad från de andra
          // fälten som bara filtrerar det som redan hämtats.
          _buildDropdown(tr('conn.tidsfonster'), _window, {
            '5m': '5 min',
            '15m': '15 min',
            '1h': '1 timme',
            '6h': '6 timmar',
            '24h': '24 timmar',
            '7d': '7 dagar',
          }, (v) {
            _onFilterChanged(() => _window = v);
            _poll();
          }),
          _buildDropdown(tr('conn.ip_version'), _ipVersionFilter, {
            'ALL': tr('conn.alla'),
            'IPV4': tr('conn.endast_ipv4'),
            'IPV6': tr('conn.endast_ipv6'),
          }, (v) => _onFilterChanged(() => _ipVersionFilter = v)),
          TextButton.icon(
            icon: Icon(Icons.clear, size: 14, color: AppColors.textMuted),
            label: Text(tr('conn.rensa_filter'), style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            // Rensar även det SPARADE filtret: LogFilterPrefs.save() tar
            // bort posten när allt står på standard, så nästa besök börjar
            // rent i stället för att återuppliva det man just rensade bort.
            onPressed: () => _onFilterChanged(() {
              _exprController.clear();
              _exprError = null;
              _ipController.clear();
              _macController.clear();
              _nameController.clear();
              _directionFilterField = LogFilterPrefs.defaults.directionField;
              _trafficDirectionFilter = LogFilterPrefs.defaults.trafficDirection;
              _actionFilter = LogFilterPrefs.defaults.action;
              _ipVersionFilter = LogFilterPrefs.defaults.ipVersion;
            }),
          ),
        ],
          ),
        ],
      ),
    );
  }

  /// Filteruttrycket — det enda fältet som kan uttrycka ett UNDANTAG.
  /// Ligger överst och i full bredd eftersom uttryck snabbt blir långa.
  Widget _buildExpressionField() {
    final hasError = _exprError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: TextField(
            controller: _exprController,
            onChanged: (_) => _onFilterChanged(),
            style: TextStyle(fontSize: 12, color: AppColors.text, fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.filter_alt, size: 16, color: hasError ? AppColors.caution : AppColors.accent),
              prefixIconConstraints: const BoxConstraints(minWidth: 34),
              labelText: tr('conn.filter_uttryck'),
              labelStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
              hintText: tr('conn.filter_hint'),
              hintStyle: TextStyle(fontSize: 11, color: AppColors.hint, fontFamily: 'monospace'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: hasError ? AppColors.caution : AppColors.border),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_exprController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear, size: 15, color: AppColors.textMuted),
                      tooltip: tr('conn.rensa_filter'),
                      onPressed: () => _onFilterChanged(() {
                        _exprController.clear();
                        _exprError = null;
                      }),
                    ),
                  IconButton(
                    icon: Icon(Icons.help_outline, size: 15, color: AppColors.textMuted),
                    tooltip: tr('conn.filter_hjalp_titel'),
                    onPressed: _showFilterHelp,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(_exprError!, style: TextStyle(fontSize: 11, color: AppColors.caution)),
          ),
      ],
    );
  }

  /// Kort instruktion för filterfältet. Exemplen ligger i två kolumner —
  /// uttrycket och vad det betyder — eftersom det är så man lär sig syntaxen:
  /// genom att se ett riktigt uttryck bredvid sin egen fråga.
  void _showFilterHelp() {
    // Uttrycken kommer från filtermotorn (log_filter.dart) och testas där;
    // här paras de bara ihop med sin förklaring.
    const descriptionKeys = [
      'conn.filter_ex_1',
      'conn.filter_ex_2',
      'conn.filter_ex_3',
      'conn.filter_ex_4',
      'conn.filter_ex_5',
      'conn.filter_ex_6',
    ];
    final examples = [
      for (var i = 0; i < filterHelpExamples.length; i++)
        (filterHelpExamples[i], descriptionKeys[i]),
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.filter_alt, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tr('conn.filter_hjalp_titel'),
                  style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tr('conn.filter_hjalp_intro'),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 14),
                _helpHeading(tr('conn.filter_hjalp_exempel')),
                const SizedBox(height: 6),
                for (final (expr, descKey) in examples)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 280,
                          child: SelectableText(
                            expr,
                            style: TextStyle(
                                color: AppColors.accent, fontSize: 11.5, fontFamily: 'monospace'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(tr(descKey),
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                _helpHeading(tr('conn.filter_hjalp_operatorer')),
                const SizedBox(height: 4),
                Text(tr('conn.filter_hjalp_op_text'),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.5)),
                const SizedBox(height: 12),
                _helpHeading(tr('conn.filter_hjalp_falt')),
                const SizedBox(height: 4),
                Text(tr('conn.filter_hjalp_falt_text'),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.5)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.mouse, size: 15, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(tr('conn.filter_hjalp_tips'),
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  static Widget _helpHeading(String text) => Text(
        text.toUpperCase(),
        style: TextStyle(
            color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.6),
      );

  /// Lägger till en term i filteruttrycket. Termer AND:as ihop — det är vad
  /// man vill när man klickar sig fram till ett filter: varje klick smalnar
  /// av urvalet ytterligare.
  void _addFilterTerm(String term, {bool exclude = false}) {
    final addition = exclude ? 'not $term' : term;
    final current = _exprController.text.trim();
    _onFilterChanged(() {
      _exprController.text = current.isEmpty ? addition : '$current and $addition';
    });
  }

  /// Citerar ett värde som innehåller blanksteg, så att ett regelnamn som
  /// "LAN till WAN" blir EN term och inte tre.
  static String _quote(String value) =>
      value.contains(RegExp(r'\s')) ? '"$value"' : value;

  /// Högerklicksmeny för en cell — samma arbetssätt som i Check Points
  /// SmartConsole: man klickar sig fram till filtret i stället för att skriva
  /// det. Varje val AND:as in i uttrycksfältet.
  void _showCellMenu(BuildContext context, Offset globalPosition, List<_FilterTarget> targets) {
    if (targets.isEmpty) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      overlay.size.width - globalPosition.dx,
      overlay.size.height - globalPosition.dy,
    );

    final items = <PopupMenuEntry<VoidCallback>>[];
    for (var i = 0; i < targets.length; i++) {
      final t = targets[i];
      if (i > 0) items.add(const PopupMenuDivider(height: 6));
      items.add(PopupMenuItem<VoidCallback>(
        enabled: false,
        height: 26,
        child: Text(t.label, style: TextStyle(fontSize: 11, color: AppColors.accent)),
      ));
      for (final action in t.actions) {
        items.add(PopupMenuItem<VoidCallback>(
          height: 32,
          value: action.$2,
          child: Text(action.$1, style: TextStyle(fontSize: 12, color: AppColors.text)),
        ));
      }
    }

    showMenu<VoidCallback>(
      context: context,
      position: position,
      color: AppColors.surface,
      items: items,
    ).then((selected) => selected?.call());
  }

  /// Byggstenarna för en IP-cell. Käll- och målroll är separata val, precis
  /// som i Check Point: samma adress kan vara det ena i en rad och det andra
  /// i nästa.
  List<(String, VoidCallback)> _ipActions(String ip) => [
        (tr('conn.som_kalla'), () => _addFilterTerm('src:$ip')),
        (tr('conn.som_mal'), () => _addFilterTerm('dst:$ip')),
        (tr('conn.inkludera'), () => _addFilterTerm('ip:$ip')),
        (tr('conn.exkludera'), () => _addFilterTerm('ip:$ip', exclude: true)),
        (tr('conn.kopiera'), () => _copy(ip)),
      ];

  List<(String, VoidCallback)> _simpleActions(String field, String value) => [
        (tr('conn.inkludera'), () => _addFilterTerm('$field:${_quote(value)}')),
        (tr('conn.exkludera'), () => _addFilterTerm('$field:${_quote(value)}', exclude: true)),
        (tr('conn.kopiera'), () => _copy(value)),
      ];

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tr('conn.kopierat')}: $value'), duration: const Duration(seconds: 1)),
    );
  }

  /// Gör en cell högerklickbar. Vänsterklick lämnas orört — raderna är inte
  /// klickbara i övrigt, och att råka filtrera vid ett vanligt klick vore
  /// irriterande i en lista som uppdateras var fjärde sekund.
  Widget _filterable(Widget child, List<_FilterTarget> targets) {
    if (targets.isEmpty) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (d) => _showCellMenu(context, d.globalPosition, targets),
      // Långtryck ger samma meny på pekskärm (telefonappen har ingen
      // högerknapp).
      onLongPressStart: (d) => _showCellMenu(context, d.globalPosition, targets),
      child: child,
    );
  }

  Widget _buildFilterField(String label, TextEditingController controller, {required double width}) {
    return SizedBox(
      width: width,
      height: 34,
      child: TextField(
        controller: controller,
        onChanged: (_) => _onFilterChanged(),
        style: TextStyle(fontSize: 12, color: AppColors.text),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          labelStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButton<String>(
            value: value,
            dropdownColor: AppColors.surface,
            style: TextStyle(fontSize: 12, color: AppColors.text),
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
              child: ColoredBox(color: (hovered || active) ? AppColors.accent : AppColors.textFaint),
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
            SizedBox(width: widths[i], child: Text(_colLabels()[i], style: _headerStyle)),
            _resizeHandle(i),
          ],
        ],
      ),
    );
  }

  Widget _buildDataRow(_TrafficRow r, ObjectNameIndex nameIndex, Map<String, String> deviceZone, List<double> widths) {
    final srcName = nameIndex.lookup(r.srcIp);
    final dstName = nameIndex.lookup(r.dstIp);
    final direction = _classifyDirection(r, deviceZone);
    final action = r.accepted ? 'accept' : 'deny';
    final cells = <Widget>[
      _filterable(
        Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: (r.accepted ? AppColors.ok : AppColors.danger).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          r.accepted ? 'ACCEPT' : 'DENY',
          style: TextStyle(color: r.accepted ? AppColors.ok : AppColors.danger, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ),
        [_FilterTarget(action.toUpperCase(), _simpleActions('action', action))],
      ),
      Text(r.timestamp.isEmpty ? '—' : formatServerTime(r.timestamp), style: _cellStyle, overflow: TextOverflow.ellipsis),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            direction == 'IN' ? Icons.arrow_downward : (direction == 'OUT' ? Icons.arrow_upward : Icons.swap_horiz),
            size: 12,
            color: direction == 'IN' ? AppColors.warn : (direction == 'OUT' ? AppColors.accent : AppColors.textMuted),
          ),
          const SizedBox(width: 4),
          Text(
            direction == 'IN' ? tr('conn.inkommande_kort') : (direction == 'OUT' ? tr('conn.utgaende_kort') : tr('conn.internt_kort')),
            style: _cellStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      _filterable(
        Text(r.policyName.isEmpty ? '—' : r.policyName, style: _cellStyle, overflow: TextOverflow.ellipsis),
        r.policyName.isEmpty ? [] : [_FilterTarget(r.policyName, _simpleActions('rule', r.policyName))],
      ),
      _filterable(
        Text(r.protocol.toUpperCase(), style: _cellStyle, overflow: TextOverflow.ellipsis),
        r.protocol.isEmpty ? [] : [_FilterTarget(r.protocol.toUpperCase(), _simpleActions('proto', r.protocol))],
      ),
      _filterable(
        Text(
          '${r.srcIp}${r.srcPort > 0 ? ':${r.srcPort}' : ''}${srcName != null ? '\n$srcName' : ''}',
          style: _cellStyle,
          overflow: TextOverflow.ellipsis,
        ),
        [
          if (r.srcIp.isNotEmpty) _FilterTarget(r.srcIp, _ipActions(r.srcIp)),
          // Objektnamnet är ett eget filtermål: `src:Skrivare` är ofta det man
          // egentligen menar, och det överlever att enheten byter adress.
          if (srcName != null) _FilterTarget(srcName, _simpleActions('src', srcName)),
          if (r.srcPort > 0) _FilterTarget('port ${r.srcPort}', _simpleActions('port', '${r.srcPort}')),
        ],
      ),
      _filterable(
        Text(r.srcMac.isEmpty ? '—' : r.srcMac, style: _cellStyle, overflow: TextOverflow.ellipsis),
        r.srcMac.isEmpty ? [] : [_FilterTarget(r.srcMac, _simpleActions('mac', r.srcMac))],
      ),
      _filterable(
        Text(
          '${r.dstIp}${r.dstPort > 0 ? ':${r.dstPort}' : ''}${dstName != null ? '\n$dstName' : ''}',
          style: _cellStyle,
          overflow: TextOverflow.ellipsis,
        ),
        [
          if (r.dstIp.isNotEmpty) _FilterTarget(r.dstIp, _ipActions(r.dstIp)),
          if (dstName != null) _FilterTarget(dstName, _simpleActions('dst', dstName)),
          if (r.dstPort > 0) _FilterTarget('port ${r.dstPort}', _simpleActions('port', '${r.dstPort}')),
        ],
      ),
      _filterable(
        Text(r.dstMac.isEmpty ? '—' : r.dstMac, style: _cellStyle, overflow: TextOverflow.ellipsis),
        r.dstMac.isEmpty ? [] : [_FilterTarget(r.dstMac, _simpleActions('mac', r.dstMac))],
      ),
      Text(r.stateOrChain, style: _cellStyle, overflow: TextOverflow.ellipsis),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
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
  /// Se kommentaren i _buildTable: SelectionArea överallt UTOM på web.
  Widget _maybeSelectable(Widget child) => kIsWeb ? child : SelectionArea(child: child);

  Widget _buildTable(List<_TrafficRow> rows, ObjectNameIndex nameIndex, Map<String, String> deviceZone) {
    // SelectionArea runt raderna gör hela loggen musmarkerbar — man kan dra
    // över flera celler och kopiera med Ctrl+C. Cellerna förblir vanliga
    // Text-widgetar, så kolumnernas baseline är kvar (SelectableText per
    // cell reserverar extra utrymme för markör/handtag och gav ett synligt
    // ojämnt radläge).
    //
    // Bara utanför web: på CanvasKit-bygget renderade SelectionArea runt den
    // här anpassade tabellen en trasig ljusgrå ruta i stället för innehållet
    // — hela trafiken blev osynlig. Desktop- och Android-byggena har inte
    // det problemet, och det är där man faktiskt sitter och kopierar
    // IP-adresser ur loggen.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
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
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: _buildHeaderRow(widths),
                  ),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text(tr('conn.ingen_trafik_matchar_filtret'), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ),
                          )
                        : _maybeSelectable(
                            ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: rows.length,
                              itemBuilder: (context, i) => _buildDataRow(rows[i], nameIndex, deviceZone, widths),
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
}

TextStyle get _headerStyle => TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold);
TextStyle get _cellStyle => TextStyle(color: AppColors.text, fontSize: 11);

/// Ett filtrerbart värde i en cell, med de val högerklicksmenyn ska visa.
/// Rubriken är själva värdet, så man ser vad man håller på att filtrera på.
class _FilterTarget {
  final String label;
  final List<(String, VoidCallback)> actions;
  const _FilterTarget(this.label, this.actions);
}
