import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../widgets/dialog_helpers.dart';
import '../localization.dart';

class PoliciesScreen extends StatefulWidget {
  const PoliciesScreen({super.key});

  @override
  State<PoliciesScreen> createState() => _PoliciesScreenState();
}

List<String> _policyColLabels() => [
  '#',
  tr('pol.col_action'),
  tr('pol.col_policy_name'),
  tr('pol.col_type_service'),
  tr('pol.col_from'),
  tr('pol.col_to'),
  tr('pol.col_port'),
  tr('pol.col_atgarder'),
];
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
              child: ColoredBox(color: (hovered || active) ? AppColors.accent : AppColors.textFaint),
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
              child: Text(_policyColLabels()[i], style: TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
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
      color: AppColors.bg,
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Verktygsfält (Toolbar) för Policy Hantering. Wrap i stället för
          // Row+Spacer: knapparna (särskilt "+ Port Forwarding (DNAT)")
          // overflowade tyst på en telefonskärm (upptäckt 2026-08-24) - Wrap
          // låter dem falla ner till en ny rad i stället.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surface,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.accent, size: 20),
                    SizedBox(width: 8),
                    Text(tr('pol.firewall_policies_rules'),
                      style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  icon: Icon(Icons.add, size: 16, color: AppColors.accent),
                  label: Text(tr('pol.ny_policy'), style: TextStyle(fontSize: 12, color: AppColors.text)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    side: BorderSide(color: AppColors.accent),
                  ),
                  onPressed: () => _showEditPolicyDialog(context, provider, cfg, null),
                ),
                // Port forwarding (DNAT) kräver NAT, som inte finns i
                // enkelkorts-/värddator-läge (Fas 13, se
                // pkg/adapter/nftables.RenderJSON) — döljs helt istället
                // för att erbjuda en åtgärd som ändå aldrig får effekt.
                if (!(cfg?.settings.isHostMode ?? false))
                  OutlinedButton.icon(
                    icon: Icon(Icons.input, size: 16, color: AppColors.info),
                    label: Text(tr('pol.port_forwarding_dnat'), style: TextStyle(fontSize: 12, color: AppColors.text)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      side: BorderSide(color: AppColors.info),
                    ),
                    onPressed: () => _showAddDNATDialog(context, provider),
                  ),
                IconButton(
                  icon: Icon(Icons.refresh, size: 18, color: AppColors.ok),
                  tooltip: tr('pol.uppdatera_traffraknare_hit_counters'),
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
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: (cfg == null || cfg.policies.isEmpty)
                  ? Center(
                      child: Text(tr('pol.inga_brandvaggsregler_definierade_default_deny_galler'),
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                                  color: AppColors.border,
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                  child: _buildPolicyHeaderRow(widths),
                                ),
                                Expanded(
                                  // Ordningen är betydelsebärande i en brandvägg —
                                  // första träff vinner — så raderna går att dra
                                  // med musen. De två låsta default-deny-raderna
                                  // ligger i footer i stället för i listan: de ska
                                  // alltid vara sist och får aldrig kunna dras.
                                  child: ReorderableListView.builder(
                                    buildDefaultDragHandles: false,
                                    itemCount: cfg.policies.length,
                                    onReorderItem: (oldIndex, newIndex) =>
                                        _reorderPolicy(provider, cfg, oldIndex, newIndex),
                                    footer: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildDefaultDenyRow(
                                          widths,
                                          name: tr('pol.deny_wan_name'),
                                          from: 'WAN',
                                          to: 'SELF / LAN',
                                          hitKey: null,
                                          tooltip: tr('pol.default_deny_wan_tooltip'),
                                        ),
                                        _buildDefaultDenyRow(
                                          widths,
                                          name: tr('pol.deny_all_name'),
                                          from: 'ANY',
                                          to: 'ANY',
                                          hitKey: 'DefaultDeny',
                                          tooltip: tr('pol.default_deny_all_tooltip'),
                                        ),
                                      ],
                                    ),
                                    itemBuilder: (context, idx) => KeyedSubtree(
                                      // Nyckeln måste följa POLICYN, inte positionen —
                                      // annars tappar Flutter kopplingen mellan rad och
                                      // innehåll så fort ordningen ändras.
                                      key: ValueKey(cfg.policies[idx].id),
                                      child: _buildPolicyDataRow(context, provider, cfg, idx, widths),
                                    ),
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
            ? tr('pol.allow_short')
            : isReject
                ? tr('pol.reject_short')
                : tr('pol.deny');
    final actionColor = isDNAT
        ? AppColors.info
        : isAllow
            ? AppColors.ok
            : isReject
                ? AppColors.caution
                : AppColors.danger;

    final cells = <Widget>[
      // Radnumret är också draghandtaget. Handtaget ligger HÄR och inte på
      // hela raden, eftersom raden innehåller knappar (upp/ner, redigera, ta
      // bort) vars klick annars hade tolkats som början på ett drag.
      ReorderableDragStartListener(
        index: idx,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Tooltip(
            message: tr('pol.dra_for_att_flytta'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.drag_indicator, size: 14, color: AppColors.textFaint),
                Text('${idx + 1}', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
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
            ? trp('pol.protected_policy_tooltip', {'name': pol.name, 'desc': pol.description})
            : trp('pol.hit_count', {'packets': '${_hitCountFor(pol.name).$1}', 'bytes': '${_hitCountFor(pol.name).$2}'}),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pol.protected) ...[
              Icon(Icons.lock, size: 11, color: AppColors.warn),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                pol.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: pol.enabled ? AppColors.text : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  decoration: pol.enabled ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
        ),
      ),
      Text(pol.service, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.accent, fontSize: 11)),
      _truncatedCell(_zoneOrObjLabel(cfg, pol.sourceZone, pol.sourceObj),
          object: _objectFor(cfg, pol.sourceObj)),
      _truncatedCell(isDNAT && pol.nat != null
          ? '${pol.nat!.internalIp}:${pol.nat!.internalPort}'
          // En local-regel gäller alltid brandväggen själv — visa SELF även
          // om destZone råkar innehålla ett gammalt (ignorerat) värde från
          // innan regeln gjordes till en local-regel.
          : (pol.local ? 'SELF' : _zoneOrObjLabel(cfg, pol.destZone, pol.destObj)),
          object: (isDNAT && pol.nat != null) || pol.local ? null : _objectFor(cfg, pol.destObj)),
      Text(isDNAT && pol.nat != null ? 'tcp:${pol.nat!.externalPort}' : _getPortForService(pol.service), overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.warn, fontSize: 11)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_upward, size: 13, color: AppColors.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: tr('pol.flytta_upp_hogre_prioritet'),
            onPressed: idx == 0 ? null : () => _movePolicy(provider, cfg, idx, idx - 1),
          ),
          IconButton(
            icon: Icon(Icons.arrow_downward, size: 13, color: AppColors.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: tr('pol.flytta_ner_lagre_prioritet'),
            onPressed: idx == cfg.policies.length - 1 ? null : () => _movePolicy(provider, cfg, idx, idx + 1),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.edit, size: 14, color: AppColors.accent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: tr('pol.redigera_policy_properties'),
            onPressed: () => _showEditPolicyDialog(context, provider, cfg, idx),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 14, color: pol.protected ? AppColors.textFaint : AppColors.danger),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: pol.protected ? tr('pol.skyddad_policy_kan_inte_tas_bort') : tr('pol.ta_bort_policy'),
            onPressed: pol.protected ? () => _showProtectedPolicyNotice(context, pol.name) : () => _deletePolicy(context, provider, cfg, idx),
          ),
          const SizedBox(width: 8),
          Switch(
            value: pol.enabled,
            activeThumbColor: AppColors.ok,
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
        color: isSelected ? Colors.cyan.withValues(alpha: 0.2) : (idx % 2 == 0 ? AppColors.surface : AppColors.bg),
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
    final denyColor = AppColors.danger;
    final nameTooltip = hitKey == null
        ? tr('pol.loggas_inte_tyst_drop')
        : trp('pol.hit_count', {'packets': '${_hitCountFor(hitKey).$1}', 'bytes': '${_hitCountFor(hitKey).$2}'});
    final cells = <Widget>[
      Icon(Icons.lock, size: 13, color: AppColors.textMuted),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 15, color: denyColor),
          SizedBox(width: 4),
          Flexible(
            child: Text(tr('pol.deny'), overflow: TextOverflow.ellipsis,
                style: TextStyle(color: denyColor, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      Tooltip(
        message: nameTooltip,
        child: Text(name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
      Text(tr('pol.any'), overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.accent, fontSize: 11)),
      _truncatedCell(from),
      _truncatedCell(to),
      Text(tr('pol.any_2'), overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.warn, fontSize: 11)),
      Tooltip(
        message: tooltip,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
            SizedBox(width: 6),
            Text(tr('pol.last'), style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    ];

    return Container(
      // Diskret avvikande bakgrund så det syns att raden inte är en vanlig,
      // redigerbar policy.
      color: AppColors.dangerSurface,
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
  Widget _truncatedCell(String text, {ObjectModel? object}) {
    final label = Text(
      text,
      style: TextStyle(
        color: object != null ? AppColors.accent : AppColors.textMuted,
        fontSize: 11,
        decoration: object != null ? TextDecoration.underline : null,
        decorationStyle: TextDecorationStyle.dotted,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
    final cell = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: label,
    );
    if (object == null) {
      return Tooltip(message: text, child: cell);
    }
    // Refererar cellen ett objekt går det att klicka på för att se vad det
    // faktiskt innehåller. En grupp visar bara sitt NAMN i policylistan, och
    // att behöva gå till Objekt-vyn och leta upp den för att svara på "vilka
    // adresser släpper den här regeln egentligen igenom?" var onödigt.
    return Tooltip(
      message: tr('pol.visa_objektinnehall'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _showObjectContents(object),
          child: cell,
        ),
      ),
    );
  }

  /// Objektet en From/To-cell refererar, om någon.
  ObjectModel? _objectFor(ConfigModel? cfg, String? objId) {
    if (cfg == null || objId == null || objId.isEmpty || objId.toUpperCase() == 'ANY') {
      return null;
    }
    for (final o in cfg.objects) {
      if (o.id == objId) return o;
    }
    return null;
  }

  /// Overlay som visar vad ett objekt innehåller. En grupp löses upp till sina
  /// medlemmar (vars values är ANDRA objekts ID:n), rekursivt, så man ser de
  /// faktiska adresserna och inte bara ännu ett gruppnamn.
  void _showObjectContents(ObjectModel object) {
    final cfg = Provider.of<ConfigProvider>(context, listen: false).candidateConfig ??
        Provider.of<ConfigProvider>(context, listen: false).runningConfig;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(object.type == 'group' ? Icons.folder_open : Icons.category,
                size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(object.name,
                  style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(object.type.toUpperCase(),
                  style: TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (object.description.isNotEmpty) ...[
                  Text(object.description,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                  const SizedBox(height: 12),
                ],
                ..._objectContentWidgets(cfg, object, 0, <String>{}),
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

  /// Bygger innehållsraderna. [seen] bryter cykler — en grupp som (direkt
  /// eller indirekt) innehåller sig själv skulle annars ge oändlig rekursion
  /// och hänga GUI:t.
  List<Widget> _objectContentWidgets(ConfigModel? cfg, ObjectModel object, int depth, Set<String> seen) {
    if (!seen.add(object.id) || depth > 5) {
      return [
        Padding(
          padding: EdgeInsets.only(left: depth * 14.0, bottom: 4),
          child: Text(tr('pol.cyklisk_grupp'),
              style: TextStyle(color: AppColors.caution, fontSize: 11)),
        ),
      ];
    }

    if (object.values.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.only(left: depth * 14.0, bottom: 4),
          child: Text(tr('pol.objekt_tomt'),
              style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (final value in object.values) {
      final member = object.type == 'group' ? _objectFor(cfg, value) : null;
      if (member != null) {
        widgets.add(Padding(
          padding: EdgeInsets.only(left: depth * 14.0, top: 6, bottom: 2),
          child: Row(
            children: [
              Icon(member.type == 'group' ? Icons.folder_open : Icons.subdirectory_arrow_right,
                  size: 13, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(member.name,
                  style: TextStyle(color: AppColors.accent, fontSize: 11.5, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text(member.type,
                  style: TextStyle(color: AppColors.textFaint, fontSize: 10)),
            ],
          ),
        ));
        widgets.addAll(_objectContentWidgets(cfg, member, depth + 1, seen));
        continue;
      }
      widgets.add(Padding(
        padding: EdgeInsets.only(left: depth * 14.0 + 19, bottom: 3),
        child: SelectableText(
          value,
          style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontFamily: 'monospace'),
        ),
      ));
    }
    return widgets;
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
    final labels = {
      'Monday': tr('pol.day_mon'), 'Tuesday': tr('pol.day_tue'), 'Wednesday': tr('pol.day_wed'), 'Thursday': tr('pol.day_thu'),
      'Friday': tr('pol.day_fri'), 'Saturday': tr('pol.day_sat'), 'Sunday': tr('pol.day_sun'),
    };
    return labels[enDay] ?? enDay;
  }

  Widget _dialogTimeField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          height: 34,
          child: TextField(
            controller: ctrl,
            style: TextStyle(fontSize: 12, color: AppColors.text),
            decoration: InputDecoration(isDense: true, hintText: tr('pol.hh_mm'), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
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
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warn, size: 20),
            SizedBox(width: 8),
            Text(tr('pol.ar_du_saker'), style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          trp('pol.critical_change_body', {'name': policyName, 'verb': actionVerb}),
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('pol.avbryt'), style: TextStyle(fontSize: 12))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('pol.ja_jag_ar_saker'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
  /// Drag-and-drop-flytt.
  ///
  /// onReorderItem (till skillnad från det deprecerade onReorder) levererar
  /// newIndex REDAN justerat för att raden plockats bort — ingen egen
  /// off-by-one-korrigering behövs. I ett regelverk där första träff vinner
  /// är ett steg fel en riktig ändring av beteendet, så det är värt att
  /// använda det callback som gör justeringen åt en.
  void _reorderPolicy(ConfigProvider provider, ConfigModel cfg, int oldIndex, int newIndex) {
    if (newIndex == oldIndex) return;
    _movePolicy(provider, cfg, oldIndex, newIndex);
    setState(() => _selectedRowIndex = newIndex);
  }

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
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.lock, color: AppColors.warn, size: 20),
            SizedBox(width: 8),
            Text(tr('pol.skyddad_policy'), style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          trp('pol.protected_notice_body', {'name': policyName}),
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: Text(tr('pol.ok'))),
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
      final confirmed = await _confirmCriticalChange(context, pol.name, tr('pol.verb_tar_bort'));
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
          backgroundColor: AppColors.surface,
          title: Text(tr('pol.ta_bort_regeln'), style: TextStyle(color: AppColors.text, fontSize: 14)),
          content: Text(
            trp('pol.delete_rule_body', {'name': pol.name}),
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(tr('pol.avbryt'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(dctx, true),
              child: Text(tr('pol.ta_bort')),
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
      final confirmed = await _confirmCriticalChange(context, cur.name, tr('pol.verb_inaktiverar'));
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

    final nameCtrl = TextEditingController(text: pol?.name ?? tr('pol.ny_brandvaggsregel'));
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
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 580.0),
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
                      isEditing ? tr('pol.edit_policy_properties') : tr('pol.add_policy_properties'),
                      style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Name & Enable Checkbox
                Row(
                  children: [
                    Text(tr('pol.name'), style: TextStyle(color: AppColors.text, fontSize: 12)),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: TextField(
                          controller: nameCtrl,
                          style: TextStyle(color: AppColors.text, fontSize: 12),
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
                          activeColor: AppColors.ok,
                          checkColor: Colors.black,
                          onChanged: (pol?.protected ?? false)
                              ? null
                              : (v) async {
                                  final newVal = v ?? false;
                                  if (pol != null && pol.critical && enabled && !newVal) {
                                    final confirmed = await _confirmCriticalChange(context, pol.name, tr('pol.verb_inaktiverar'));
                                    if (!confirmed) return;
                                  }
                                  setState(() => enabled = newVal);
                                },
                        ),
                        Text(tr('pol.enable'),
                          style: TextStyle(color: (pol?.protected ?? false) ? AppColors.textFaint : AppColors.text, fontSize: 12),
                        ),
                        if (pol?.protected ?? false) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: tr('pol.protected_policy_disable_tooltip'),
                            child: Icon(Icons.lock, size: 14, color: AppColors.warn),
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
                    _buildTabButton(tr('pol.tab_policy'), 0, selectedTab, (idx) => setState(() => selectedTab = idx)),
                    _buildTabButton(tr('pol.tab_properties'), 1, selectedTab, (idx) => setState(() => selectedTab = idx)),
                    _buildTabButton(tr('pol.tab_advanced'), 2, selectedTab, (idx) => setState(() => selectedTab = idx)),
                  ],
                ),
                Divider(color: AppColors.textFaint, height: 1),
                const SizedBox(height: 12),

                if (selectedTab == 0) ...[
                  // Action Selector
                  Row(
                    children: [
                      Text(trp('pol.connections_are', {'name': nameCtrl.text}), style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: action,
                        dropdownColor: AppColors.surface,
                        style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold),
                        items: [
                          DropdownMenuItem(value: 'accept', child: Text(tr('pol.allowed'), style: TextStyle(color: AppColors.ok))),
                          DropdownMenuItem(value: 'drop', child: Text(tr('pol.denied_drop'), style: TextStyle(color: AppColors.danger))),
                          // Reject fanns redan i backend-datamodellen men
                          // genererade tidigare ingen regel alls; sedan
                          // 2026-08-20 renderas den som ett riktigt
                          // nftables-reject (ICMP "admin-prohibited"), så
                          // den kan erbjudas här. Skillnad mot Drop:
                          // avsändaren får ett tydligt avslag direkt i
                          // stället för att vänta ut en timeout.
                          DropdownMenuItem(value: 'reject', child: Text(tr('pol.denied_reject'), style: TextStyle(color: AppColors.caution))),
                          DropdownMenuItem(value: 'dnat', child: Text(tr('pol.dnat_port_forward'), style: TextStyle(color: AppColors.info))),
                        ],
                        onChanged: (v) => setState(() => action = v ?? 'accept'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // From Box
                  _buildMemberBox(
                    context: context,
                    title: tr('pol.from_title'),
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
                          ? tr('pol.to_title_local')
                          : tr('pol.to_title'),
                      members: local ? [tr('pol.brandvaggen_sjalv')] : toMembers,
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
                          activeColor: AppColors.ok,
                          checkColor: Colors.black,
                          onChanged: (v) => setState(() => local = v ?? false),
                        ),
                        Expanded(
                          child: Text(
                            local
                                ? tr('pol.local_on_note')
                                : tr('pol.local_off_note'),
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (action == 'dnat') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(4)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('pol.port_forwarding_dnat_parametrar'), style: TextStyle(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: TextField(controller: extPortCtrl, style: TextStyle(fontSize: 11, color: AppColors.text), decoration: InputDecoration(labelText: tr('pol.wan_port'), isDense: true))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: intIpCtrl, style: TextStyle(fontSize: 11, color: AppColors.text), decoration: InputDecoration(labelText: tr('pol.intern_ip'), isDense: true))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: intPortCtrl, style: TextStyle(fontSize: 11, color: AppColors.text), decoration: InputDecoration(labelText: tr('pol.intern_port'), isDense: true))),
                              const SizedBox(width: 8),
                              Expanded(child: TextField(controller: protoCtrl, style: TextStyle(fontSize: 11, color: AppColors.text), decoration: InputDecoration(labelText: tr('pol.protokoll'), isDense: true))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else if (selectedTab == 1) ...[
                  Text(tr('pol.forinstalld_tjanst_protokoll'), style: TextStyle(color: AppColors.text, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedServicePreset,
                    dropdownColor: AppColors.surface,
                    style: TextStyle(color: AppColors.text, fontSize: 12),
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), border: OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: 'ANY', child: Text(tr('pol.any_alla_tjanster_portar'))),
                      DropdownMenuItem(value: 'HTTP', child: Text(tr('pol.http_tcp_80'))),
                      DropdownMenuItem(value: 'HTTPS', child: Text(tr('pol.https_tcp_443'))),
                      DropdownMenuItem(value: 'SSH', child: Text(tr('pol.ssh_tcp_22'))),
                      DropdownMenuItem(value: 'DNS', child: Text(tr('pol.dns_udp_53'))),
                      DropdownMenuItem(value: 'RDP', child: Text(tr('pol.rdp_tcp_3389'))),
                      DropdownMenuItem(value: 'ICMP', child: Text(tr('pol.icmp_ping'))),
                      DropdownMenuItem(value: 'CUSTOM', child: Text(tr('pol.anpassad_port_protokoll_skriv_sjalv_t'), style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold))),
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
                  Text(tr('pol.anpassat_portnummer_eller_protokoll_skriv_in'), style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 36,
                    child: TextField(
                      controller: customPortCtrl,
                      style: TextStyle(fontSize: 12, color: AppColors.text, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: tr('pol.t_ex_7201_eller_tcp_7201'),
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
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
                  Text(
                    tr('pol.custom_port_example'),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                ] else ...[
                  Text(tr('pol.schema_fas_7_tidsstyrd_regel'), style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Switch(
                        value: scheduleEnabled,
                        activeThumbColor: AppColors.ok,
                        onChanged: (v) => setState(() => scheduleEnabled = v),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        scheduleEnabled ? tr('pol.schedule_active_note') : tr('pol.schedule_always_active'),
                        style: TextStyle(color: scheduleEnabled ? AppColors.ok : AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                  if (scheduleEnabled) ...[
                    const SizedBox(height: 10),
                    Text(tr('pol.veckodagar'), style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final day in const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'])
                          FilterChip(
                            label: Text(_dayLabel(day), style: const TextStyle(fontSize: 11)),
                            selected: scheduleDays.contains(day),
                            selectedColor: AppColors.ok.withValues(alpha: 0.3),
                            checkmarkColor: AppColors.ok,
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
                        Expanded(child: _dialogTimeField(tr('pol.fran_hh_mm'), scheduleStartCtrl)),
                        const SizedBox(width: 10),
                        Expanded(child: _dialogTimeField(tr('pol.till_hh_mm'), scheduleEndCtrl)),
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
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBg, foregroundColor: AppColors.onAccentBg),
                      child: Text(tr('pol.ok'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                                    description: tr('pol.auto_created_desc'),
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
                            final side = srcMatchedObjs.length > 1 ? tr('pol.kalla_side') : tr('pol.mal_side');
                            final names = (srcMatchedObjs.length > 1 ? srcMatchedObjs : dstMatchedObjs).join(', ');
                            showDialog(
                              context: context,
                              builder: (dctx) => AlertDialog(
                                backgroundColor: AppColors.surface,
                                title: Text(tr('pol.flera_objekt_valda'), style: TextStyle(color: AppColors.text, fontSize: 14)),
                                content: Text(
                                  trp('pol.multi_object_body', {'side': side, 'names': names}),
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dctx), child: Text(tr('pol.ok_jag_fixar_det'))),
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
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.text),
                      child: Text(tr('pol.cancel'), style: TextStyle(fontSize: 12)),
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
          color: isSelected ? AppColors.border : Colors.transparent,
          border: Border(bottom: BorderSide(color: isSelected ? AppColors.accent : Colors.transparent, width: 2)),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? AppColors.accent : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
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
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: AppColors.border,
            width: double.infinity,
            child: Text(title, style: TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          Container(
            height: 70,
            padding: const EdgeInsets.all(6),
            color: AppColors.bg,
            child: members.isEmpty
                ? Text(tr('pol.inga_adresser_tillagda'), style: TextStyle(color: AppColors.textMuted, fontSize: 11))
                : ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (ctx, i) {
                      final item = members[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.computer, size: 14, color: AppColors.accent),
                            const SizedBox(width: 6),
                            Expanded(child: Text(item, style: TextStyle(color: AppColors.text, fontSize: 11))),
                            GestureDetector(
                              onTap: () => onRemove(item),
                              child: Icon(Icons.close, size: 14, color: AppColors.danger),
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
                  label: Text(tr('pol.add'), style: TextStyle(fontSize: 11)),
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
    final searchCtrl = TextEditingController();

    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final filtered = query.isEmpty ? available : available.where((item) => item.toLowerCase().contains(query)).toList();
          // Dialogen skalas mot skärmens storlek (i stället för en fast
          // bredd/höjd) så listan med tillgängliga objekt/nät/hostar visar
          // fler poster åt gången — tidigare syntes bara ~4-5 rader oavsett
          // fönsterstorlek.
          final screenSize = MediaQuery.of(context).size;
          return Dialog(
          backgroundColor: AppColors.surface,
          child: Container(
            width: (screenSize.width - 32).clamp(280.0, 560.0),
            height: (screenSize.height * 0.8).clamp(420.0, 700.0),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('pol.add_address_member'), style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(tr('pol.available_members'), style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 4),
                // Sökrutan filtrerar listan direkt vid varje knapptryck (redan
                // från första bokstaven) - inget Enter-tryck krävs.
                SizedBox(
                  height: 30,
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    style: TextStyle(fontSize: 11, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: tr('pol.sok'),
                      prefixIcon: Icon(Icons.search, size: 14, color: AppColors.textMuted),
                      prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      border: const OutlineInputBorder(),
                      suffixIcon: query.isEmpty ? null : IconButton(icon: Icon(Icons.clear, size: 14, color: AppColors.textMuted), onPressed: () => setState(() => searchCtrl.clear())),
                      suffixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), color: AppColors.bg),
                    child: filtered.isEmpty
                        ? Center(child: Text(tr('pol.inga_traffar'), style: TextStyle(color: AppColors.textMuted, fontSize: 11)))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (c, idx) {
                              final item = filtered[idx];
                              return ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                title: Text(item, style: TextStyle(color: AppColors.text, fontSize: 11)),
                                trailing: Icon(Icons.add, size: 14, color: AppColors.accent),
                                onTap: () {
                                  if (!selected.contains(item)) {
                                    setState(() => selected.add(item));
                                  }
                                },
                              );
                            },
                          ),
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
                          style: TextStyle(fontSize: 11, color: AppColors.text),
                          decoration: InputDecoration(
                            hintText: tr('pol.ange_egen_ip_eller_subnet_t'),
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
                      child: Text(tr('pol.add_other'), style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(tr('pol.selected_members_and_addresses'), style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 4),
                Container(
                  height: 90,
                  decoration: BoxDecoration(border: Border.all(color: AppColors.border), color: AppColors.bg),
                  child: ListView.builder(
                    itemCount: selected.length,
                    itemBuilder: (c, idx) {
                      final item = selected[idx];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(item, style: TextStyle(color: AppColors.accent, fontSize: 11)),
                        trailing: IconButton(
                          icon: Icon(Icons.remove_circle_outline, size: 14, color: AppColors.danger),
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
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBg, foregroundColor: AppColors.onAccentBg),
                      onPressed: () => Navigator.pop(ctx, selected),
                      child: Text(tr('pol.ok'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.text),
                      onPressed: () => Navigator.pop(ctx, null),
                      child: Text(tr('pol.cancel'), style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        },
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
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Container(
          width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 460.0),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dialogTitleRow(context, tr('pol.skapa_port_forwarding'), () => Navigator.pop(ctx)),
                const SizedBox(height: 12),

                dialogSection(title: tr('pol.section_regel'), children: [
                  dialogField(nameCtrl, tr('pol.regelnamn')),
                ]),
                const SizedBox(height: 12),

                dialogSection(title: tr('pol.section_extern'), children: [
                  dialogField(extPortCtrl, tr('pol.extern_port_wan'), hint: 't.ex. 443'),
                ]),
                const SizedBox(height: 12),

                dialogSection(title: tr('pol.section_intern'), children: [
                  dialogField(intIpCtrl, tr('pol.intern_mal_ip'), hint: 't.ex. 192.168.10.10'),
                  const SizedBox(height: 12),
                  dialogField(intPortCtrl, tr('pol.intern_malport'), hint: 't.ex. 443'),
                  const SizedBox(height: 12),
                  dialogField(protoCtrl, tr('pol.protokoll_tcp_udp')),
                ]),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('pol.avbryt'), style: TextStyle(fontSize: 12))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBg, foregroundColor: AppColors.onAccentBg),
                    child: Text(tr('pol.spara_dnat'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
