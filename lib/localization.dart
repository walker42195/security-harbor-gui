/// Eget, enkelt SV/EN-språksystem för GUI:t — INTE Flutters intl-baserade
/// l10n-maskineri (onödigt overhead för två statiska språkkartor som redan
/// finns som Dart-kod). `currentLanguage` sätts av [ConfigProvider] (som
/// äger den sparade preferensen, se `providers/config_provider.dart`) och
/// läses av `tr()` överallt i widget-trädet. Ett språkbyte triggar
/// `notifyListeners()` på `ConfigProvider`, som `MaterialApp.home` redan
/// lyssnar på via en rot-`Consumer` (se `main.dart`) — hela trädet ritas
/// alltså om automatiskt.
library;

enum AppLanguage { sv, en }

AppLanguage currentLanguage = AppLanguage.sv;

/// Slår upp `key` i den aktiva språkkartan. Saknas nyckeln (t.ex. ett
/// missat fall under migrering) returneras nyckeln själv rått, i stället
/// för att krascha — lätt att upptäcka i UI:t, aldrig ett stopp för
/// användaren.
String tr(String key) {
  final dict = _strings[currentLanguage] ?? _strings[AppLanguage.en]!;
  return dict[key] ?? _strings[AppLanguage.en]![key] ?? key;
}

/// Som [tr], men ersätter `{namn}`-platshållare i strängen med värden ur
/// `params`. Används för meddelanden som bär in ett dynamiskt värde (t.ex.
/// en URL eller ett antal) mitt i en annars översatt mening.
String trp(String key, Map<String, String> params) {
  var s = tr(key);
  params.forEach((k, v) {
    s = s.replaceAll('{$k}', v);
  });
  return s;
}

final Map<AppLanguage, Map<String, String>> _strings = {
  AppLanguage.sv: _sv,
  AppLanguage.en: _en,
};

// ---------------------------------------------------------------------
// Svenska
// ---------------------------------------------------------------------
const Map<String, String> _sv = {
  // --- ConfigProvider: status-/felmeddelanden ---
  'provider.status.connecting': 'Ansluter till brandvägg...',
  'provider.status.logged_in': 'Inloggad',
  'provider.error.login_failed': 'Inloggning misslyckades mot {url}',
  'provider.status.updating': 'Uppdaterar…',
  'provider.status.saving_candidate': 'Sparar ändringar i kandidatkonfiguration...',
  'provider.error.save_candidate_failed': 'Kunde inte spara ändring i kandidat',
  'provider.status.discarding': 'Återställer ändringar...',
  'provider.error.get_running_failed': 'Kunde inte hämta körande konfiguration',
  'provider.error.discard_failed': 'Kunde inte återställa ändringar',
  'provider.status.applying': 'Applicerar nftables-regler på brandväggsservern...',
  'provider.status.confirming': 'Bekräftar och committar konfiguration...',
  'provider.error.confirm_failed': 'Bekräftelse misslyckades',
  'provider.status.rolling_back': 'Återställer till senast kända säkra konfiguration...',

  // --- Login-skärmen ---
  'login.subtitle': 'Administrationsgränssnitt',
  'login.url_label': 'Brandväggens adress',
  'login.url_hint': 'https://192.168.1.1:8443',
  'login.username_label': 'Användarnamn',
  'login.password_label': 'Lösenord',
  'login.submit': 'Logga in',
  'login.language_label': 'Språk',

  // --- Huvudnavigation (main_screen.dart) ---
  'nav.dashboard': 'Dashboard',
  'nav.interfaces': 'Interfaces',
  'nav.routing': 'Routing',
  'nav.policies': 'Policies',
  'nav.objects': 'Objekt',
  'nav.sni': 'SNI',
  'nav.vpn': 'VPN',
  'nav.dns': 'DNS',
  'nav.dns_devices': 'DNS-enheter',
  'nav.dhcp': 'DHCP',
  'nav.logging': 'Loggning',
  'nav.ids': 'IDS',
  'nav.services': 'Tjänster',
  'nav.tools': 'Verktyg',
  'nav.settings': 'Settings',

  'main.title': 'SECURITY HARBOR',
  'main.menu_tooltip': 'Meny',
  'main.mode_host': 'LÄGE: VÄRDDATOR',
  'main.online': 'ONLINE',
  'main.online_with_url': 'ONLINE ({url})',
  'main.not_connected': 'EJ ANSLUTEN',
  'main.refresh_tooltip': 'Uppdatera allt (hämta om status och konfiguration)',
  'main.logout_tooltip': 'Logga ut',
  'main.service_alarm_one': 'Tjänsten "{name}" har fastnat i ett fel-läge (failed).',
  'main.service_alarm_many': '{count} tjänster har fastnat i ett fel-läge (failed): {names}.',
  'main.show_services': 'Visa Tjänster',
  'main.safe_apply_banner': 'ÄNDRINGAR APPLICERADE PÅ BRANDVÄGGEN (SAFE APPLY): Automatisk rollback sker om {seconds} sekunder om du inte bekräftar!',
  'main.confirm_commit': 'BEKRÄFTA (COMMIT)',
  'main.confirm_success': 'Konfiguration bekräftad och committad till running.json!',
  'main.confirm_failed': 'Misslyckades bekräfta',
  'main.rollback': 'RULLA TILLBAKA',
  'main.rollback_success': 'Konfigurationen återställd till senast säkra tillstånd.',
  'main.unapplied_banner': 'Du har obekräftade ändringar redo att testas på brandväggen.',
  'main.undo_changes': 'ÅNGRA ÄNDRINGAR',
  'main.undo_dialog_title': 'Ångra ändringar?',
  'main.undo_dialog_body': 'Alla ändringar du gjort sedan senaste applicering kastas bort och konfigurationen återställs till den som just nu kör på brandväggen. Detta går inte att ångra.',
  'main.cancel': 'Avbryt',
  'main.undo_confirm_button': 'Ångra ändringar',
  'main.undo_success': 'Ändringarna återställdes till körande konfiguration.',
  'main.undo_failed_fallback': 'Kunde inte återställa ändringarna.',
  'main.apply_safe': 'APPLICERA (SAFE APPLY)',
  'main.apply_success': 'Ändringar applicerade på brandväggen! Bekräfta (Commit) inom 30s för att behålla dem.',
  'main.apply_failed_fallback': 'Misslyckades applicera konfiguration på brandväggen',

  // --- Settings: språkkort ---
  'settings.language.title': 'Språk',
  'settings.language.body': 'Väljer språk för hela gränssnittet. Sparas på den här enheten/webbläsaren.',
  'settings.language.sv': 'Svenska',
  'settings.language.en': 'Engelska',

  // --- Settings: sidtitel + inloggningskort ---
  'settings.page_title': 'Systeminställningar & Management',
  'settings.login.title': 'Server-inloggning & Agent API',
  'settings.login.url_label': 'Brandväggens Agent URL (IP och Port)',
  'settings.login.username_label': 'Användarnamn',
  'settings.login.password_label': 'Lösenord',
  'settings.login.submit': 'Logga in på Brandväggen',
  'settings.login.snackbar_success': 'Inloggad som {user} på {url}!',
  'settings.login.snackbar_failed': 'Inloggning misslyckades på {url}',
  'settings.login.status_logged_in': 'Status: Inloggad (Token Aktiv)',
  'settings.login.status_logged_out': 'Status: Ej inloggad',
  'settings.rollback_timeout.title': 'Safe Apply Rollback Timeout (Sekunder)',
  'settings.rollback_timeout.body': 'Standard 30 sekunder innan automatisk återställning sker om bekräftelse (Commit) uteblir.',
  'settings.wan_lock.title': 'Hård WAN Management-spärr',
  'settings.wan_lock.body': 'AKTIV PÅ SYSTEMNIVÅ (Inkommande administration på WAN spärras alltid för säkerhet)',

  // --- services_screen.dart ---
  'services.avbryt': 'Avbryt',
  'services.starta_om': 'Starta om',
  'services.agenten_startar_om_logga_in_igen': 'Agenten startar om — logga in igen om en liten stund.',
  'services.tjanster': 'Tjänster',
  'services.kunde_inte_hamta_tjanststatus': 'Kunde inte hämta tjänststatus.',
  'services.uppdatera_status': 'Uppdatera status',
  'services.restart_confirm_title': 'Starta om {name}?',
  'services.restart_confirm_self': 'Det här är administrations-API:t/GUI:t själv. Din session kopplas ner under omstarten (tar normalt bara någon sekund) — logga in igen efteråt.',
  'services.restart_confirm_other': 'Tjänsten stängs ner och startas om. Om den är aktivt konfigurerad (t.ex. DHCP eller DNS på ett gränssnitt som används) kan klienter tappa anslutning en kort stund.',
  'services.status_note': 'Status uppdateras automatiskt var 15:e sekund. En tjänst som inte är konfigurerad (t.ex. OpenVPN avstängt) visas som "Inaktiv" — det är normalt, inte ett fel.',
  'services.status_active': 'Aktiv',
  'services.status_activating': 'Startar...',
  'services.status_reloading': 'Laddar om...',
  'services.status_failed': 'Misslyckad',
  'services.status_inactive': 'Inaktiv',
  'services.restarted': '{name} omstartad.',
  'services.restart_failed': 'Misslyckades: {err}',

  // --- dns_devices_screen.dart ---
  'dns_devices.dns_enheter': 'DNS-enheter',
  'dns_devices.uppdatera': 'Uppdatera',
  'dns_devices.lagg_till_post': 'Lägg till post',
  'dns_devices.inga_manuella_poster_tillagda_annu': 'Inga manuella poster tillagda ännu.',
  'dns_devices.automatisk_registrering_ar_avstangd_enheterna_nedan': 'Automatisk registrering är avstängd — enheterna nedan listas men slås inte upp i DNS förrän du slår på den ovan.',
  'dns_devices.inga_dhcp_enheter_med_vardnamn_hittades': 'Inga DHCP-enheter med värdnamn hittades.',
  'dns_devices.dns_namn': 'DNS-namn',
  'dns_devices.ip': 'IP',
  'dns_devices.granssnitt': 'Gränssnitt',
  'dns_devices.zon': 'Zon',
  'dns_devices.lagg_till_dns_post': 'Lägg till DNS-post',
  'dns_devices.avbryt': 'Avbryt',
  'dns_devices.lagg_till': 'Lägg till',
  'dns_devices.sok_namn_ip_mac': 'Sök namn / IP / MAC',
  'dns_devices.namn_label': 'Namn (exakt, valfri domän)',
  'dns_devices.namn_hint': 't.ex. server1.example.com eller server1',
  'dns_devices.ip_adress_label': 'IP-adress',

  // --- sni_routes_screen.dart ---
  'sni.intern_server': 'Intern server',
  'sni.lokal_openvpn': 'Lokal OpenVPN',
  'sni.namnbaserad_routning_sni': 'Namnbaserad routning (SNI)',
  'sni.ny_regel': '+ Ny regel',
  'sni.laddar': 'Laddar…',
  'sni.lagg_till_mal': 'Lägg till mål',
  'sni.trafik_utan_matchande_namn_t_ex': 'Trafik utan matchande namn (t.ex. OpenVPN, som inte skickar SNI) skickas hit.',
  'sni.avbryt': 'Avbryt',
  'sni.spara': 'Spara',
  'sni.obs_kraver_att_openvpn_ar_aktiverat': 'OBS: kräver att OpenVPN är aktiverat och kör i TCP-läge.',
  'sni.maltyp': 'Måltyp',
  'sni.redigera': 'Redigera',
  'sni.ta_bort': 'Ta bort',
  'sni.ta_bort_mal': 'Ta bort mål',
  'sni.intro_body': 'Tar emot TLS på en port och skickar vidare till olika interna servrar beroende på efterfrågat värdnamn (SNI). Ingen TLS-terminering — certifikaten stannar på servrarna. Suricata inspekterar handskakningen (SNI/JA3/cert).',
  'sni.ny_sni_regel': 'Ny SNI-regel',
  'sni.redigera_sni_regel': 'Redigera SNI-regel',
  'sni.section_regel': 'REGEL',
  'sni.namn': 'Namn',
  'sni.namn_hint': 't.ex. Interna webbservrar',
  'sni.lyssnarport': 'Lyssnarport',
  'sni.extern_ip_valfri': 'Extern IP (valfri)',
  'sni.bind_alla_om_tom': 'bind alla om tom',
  'sni.section_namn_till_server': 'NAMN → INTERN SERVER',
  'sni.section_fallback': 'FALLBACK (SISTA INSTANS)',
  'sni.intern_ip': 'Intern IP',
  'sni.port': 'Port',
  'sni.vardnamn_label': 'Värdnamn (komma-separerade, "*.x.se" stöds)',
  'sni.vardnamn_hint': 't.ex. px1.exempel.se, px2.exempel.se',

  // --- routes_screen.dart ---
  'routes.avbryt': 'Avbryt',
  'routes.ta_bort': 'Ta bort',
  'routes.lat_karnan_valja_rekommenderas': 'Låt kärnan välja (rekommenderas)',
  'routes.statiska_rutter_routing': 'Statiska Rutter (Routing)',
  'routes.ny_rutt': 'Ny rutt',
  'routes.inga_statiska_rutter_definierade': 'Inga statiska rutter definierade.',
  'routes.ta_bort_rutten': 'Ta bort rutten?',
  'routes.granssnitt_valfritt': 'Gränssnitt (valfritt)',
  'routes.aktiverad': 'Aktiverad',
  'routes.spara': 'Spara',
  'routes.redigera_rutt': 'Redigera rutt',
  'routes.ta_bort_rutt': 'Ta bort rutt',
  'routes.intro_body': 'En rutt gör bara nätet NÅBART. Trafik dit tillåts fortfarande bara om det finns en motsvarande Allow-policy under Policies — Default Deny gäller annars som vanligt.',
  'routes.delete_confirm_body': 'Vill du ta bort rutten "{name}"?\n\nÄndringen sparas i kandidaten men slår inte igenom på brandväggen förrän du trycker Applicera.',
  'routes.ny_statisk_rutt': 'Ny statisk rutt',
  'routes.namn_valfritt': 'Namn (valfritt)',
  'routes.namn_hint': 't.ex. Kontorsnät via router',
  'routes.nat_cidr': 'Nät (CIDR)',
  'routes.nat_hint': 't.ex. 192.168.113.0/24',
  'routes.gateway': 'Gateway',
  'routes.gateway_hint': 't.ex. 10.0.0.1',
  'routes.beskrivning_valfritt': 'Beskrivning (valfritt)',
  'routes.error_cidr': 'Nätet måste anges som CIDR, t.ex. 192.168.113.0/24',
  'routes.error_gateway': 'Gateway måste anges, t.ex. 10.0.0.1',
};

// ---------------------------------------------------------------------
// English
// ---------------------------------------------------------------------
const Map<String, String> _en = {
  // --- ConfigProvider status/error messages ---
  'provider.status.connecting': 'Connecting to firewall...',
  'provider.status.logged_in': 'Logged in',
  'provider.error.login_failed': 'Login failed against {url}',
  'provider.status.updating': 'Updating…',
  'provider.status.saving_candidate': 'Saving changes to candidate configuration...',
  'provider.error.save_candidate_failed': 'Could not save change to candidate',
  'provider.status.discarding': 'Reverting changes...',
  'provider.error.get_running_failed': 'Could not fetch running configuration',
  'provider.error.discard_failed': 'Could not revert changes',
  'provider.status.applying': 'Applying nftables rules on the firewall server...',
  'provider.status.confirming': 'Confirming and committing configuration...',
  'provider.error.confirm_failed': 'Confirmation failed',
  'provider.status.rolling_back': 'Restoring last known-safe configuration...',

  // --- Login screen ---
  'login.subtitle': 'Admin interface',
  'login.url_label': 'Firewall address',
  'login.url_hint': 'https://192.168.1.1:8443',
  'login.username_label': 'Username',
  'login.password_label': 'Password',
  'login.submit': 'Log in',
  'login.language_label': 'Language',

  // --- Main navigation (main_screen.dart) ---
  'nav.dashboard': 'Dashboard',
  'nav.interfaces': 'Interfaces',
  'nav.routing': 'Routing',
  'nav.policies': 'Policies',
  'nav.objects': 'Objects',
  'nav.sni': 'SNI',
  'nav.vpn': 'VPN',
  'nav.dns': 'DNS',
  'nav.dns_devices': 'DNS devices',
  'nav.dhcp': 'DHCP',
  'nav.logging': 'Logging',
  'nav.ids': 'IDS',
  'nav.services': 'Services',
  'nav.tools': 'Tools',
  'nav.settings': 'Settings',

  'main.title': 'SECURITY HARBOR',
  'main.menu_tooltip': 'Menu',
  'main.mode_host': 'MODE: HOST',
  'main.online': 'ONLINE',
  'main.online_with_url': 'ONLINE ({url})',
  'main.not_connected': 'NOT CONNECTED',
  'main.refresh_tooltip': 'Refresh everything (re-fetch status and configuration)',
  'main.logout_tooltip': 'Log out',
  'main.service_alarm_one': 'The service "{name}" is stuck in a failed state.',
  'main.service_alarm_many': '{count} services are stuck in a failed state: {names}.',
  'main.show_services': 'Show Services',
  'main.safe_apply_banner': 'CHANGES APPLIED TO THE FIREWALL (SAFE APPLY): automatic rollback in {seconds} seconds unless you confirm!',
  'main.confirm_commit': 'CONFIRM (COMMIT)',
  'main.confirm_success': 'Configuration confirmed and committed to running.json!',
  'main.confirm_failed': 'Confirmation failed',
  'main.rollback': 'ROLL BACK',
  'main.rollback_success': 'Configuration restored to the last safe state.',
  'main.unapplied_banner': 'You have unconfirmed changes ready to test on the firewall.',
  'main.undo_changes': 'UNDO CHANGES',
  'main.undo_dialog_title': 'Undo changes?',
  'main.undo_dialog_body': 'All changes you made since the last apply are discarded and the configuration is restored to what is currently running on the firewall. This cannot be undone.',
  'main.cancel': 'Cancel',
  'main.undo_confirm_button': 'Undo changes',
  'main.undo_success': 'The changes were reverted to the running configuration.',
  'main.undo_failed_fallback': 'Could not revert the changes.',
  'main.apply_safe': 'APPLY (SAFE APPLY)',
  'main.apply_success': 'Changes applied to the firewall! Confirm (Commit) within 30s to keep them.',
  'main.apply_failed_fallback': 'Failed to apply configuration to the firewall',

  // --- Settings: language card ---
  'settings.language.title': 'Language',
  'settings.language.body': 'Chooses the language for the whole interface. Saved on this device/browser.',
  'settings.language.sv': 'Swedish',
  'settings.language.en': 'English',

  // --- Settings: page title + login card ---
  'settings.page_title': 'System settings & management',
  'settings.login.title': 'Server login & agent API',
  'settings.login.url_label': "Firewall's agent URL (IP and port)",
  'settings.login.username_label': 'Username',
  'settings.login.password_label': 'Password',
  'settings.login.submit': 'Log in to the firewall',
  'settings.login.snackbar_success': 'Logged in as {user} at {url}!',
  'settings.login.snackbar_failed': 'Login failed at {url}',
  'settings.login.status_logged_in': 'Status: Logged in (token active)',
  'settings.login.status_logged_out': 'Status: Not logged in',
  'settings.rollback_timeout.title': 'Safe Apply rollback timeout (seconds)',
  'settings.rollback_timeout.body': 'Default 30 seconds before automatic rollback if confirmation (commit) is missed.',
  'settings.wan_lock.title': 'Hard WAN management lock',
  'settings.wan_lock.body': 'ACTIVE AT THE SYSTEM LEVEL (incoming administration on WAN is always blocked for security)',

  // --- services_screen.dart ---
  'services.avbryt': 'Cancel',
  'services.starta_om': 'Restart',
  'services.agenten_startar_om_logga_in_igen': 'The agent is restarting — log in again in a moment.',
  'services.tjanster': 'Services',
  'services.kunde_inte_hamta_tjanststatus': 'Could not fetch service status.',
  'services.uppdatera_status': 'Refresh status',
  'services.restart_confirm_title': 'Restart {name}?',
  'services.restart_confirm_self': "This is the admin API/GUI itself. Your session will be disconnected during the restart (usually just a second or so) — log in again afterwards.",
  'services.restart_confirm_other': 'The service will be shut down and restarted. If it is actively configured (e.g. DHCP or DNS on an interface in use), clients may briefly lose connectivity.',
  'services.status_note': 'Status updates automatically every 15 seconds. A service that isn\'t configured (e.g. OpenVPN disabled) shows as "Inactive" — that\'s normal, not an error.',
  'services.status_active': 'Active',
  'services.status_activating': 'Starting...',
  'services.status_reloading': 'Reloading...',
  'services.status_failed': 'Failed',
  'services.status_inactive': 'Inactive',
  'services.restarted': '{name} restarted.',
  'services.restart_failed': 'Failed: {err}',

  // --- dns_devices_screen.dart ---
  'dns_devices.dns_enheter': 'DNS devices',
  'dns_devices.uppdatera': 'Refresh',
  'dns_devices.lagg_till_post': 'Add record',
  'dns_devices.inga_manuella_poster_tillagda_annu': 'No manual records added yet.',
  'dns_devices.automatisk_registrering_ar_avstangd_enheterna_nedan': "Automatic registration is off — the devices below are listed but won't resolve in DNS until you turn it on above.",
  'dns_devices.inga_dhcp_enheter_med_vardnamn_hittades': 'No DHCP devices with a hostname were found.',
  'dns_devices.dns_namn': 'DNS name',
  'dns_devices.ip': 'IP',
  'dns_devices.granssnitt': 'Interface',
  'dns_devices.zon': 'Zone',
  'dns_devices.lagg_till_dns_post': 'Add DNS record',
  'dns_devices.avbryt': 'Cancel',
  'dns_devices.lagg_till': 'Add',
  'dns_devices.sok_namn_ip_mac': 'Search name / IP / MAC',
  'dns_devices.namn_label': 'Name (exact, domain optional)',
  'dns_devices.namn_hint': 'e.g. server1.example.com or server1',
  'dns_devices.ip_adress_label': 'IP address',

  // --- sni_routes_screen.dart ---
  'sni.intern_server': 'Internal server',
  'sni.lokal_openvpn': 'Local OpenVPN',
  'sni.namnbaserad_routning_sni': 'Name-based routing (SNI)',
  'sni.ny_regel': '+ New rule',
  'sni.laddar': 'Loading…',
  'sni.lagg_till_mal': 'Add target',
  'sni.trafik_utan_matchande_namn_t_ex': "Traffic without a matching name (e.g. OpenVPN, which doesn't send SNI) is sent here.",
  'sni.avbryt': 'Cancel',
  'sni.spara': 'Save',
  'sni.obs_kraver_att_openvpn_ar_aktiverat': 'NOTE: requires OpenVPN to be enabled and running in TCP mode.',
  'sni.maltyp': 'Target type',
  'sni.redigera': 'Edit',
  'sni.ta_bort': 'Delete',
  'sni.ta_bort_mal': 'Remove target',
  'sni.intro_body': "Accepts TLS on a port and forwards to different internal servers depending on the requested hostname (SNI). No TLS termination — the certificates stay on the servers. Suricata still inspects the handshake (SNI/JA3/cert).",
  'sni.ny_sni_regel': 'New SNI rule',
  'sni.redigera_sni_regel': 'Edit SNI rule',
  'sni.section_regel': 'RULE',
  'sni.namn': 'Name',
  'sni.namn_hint': 'e.g. Internal web servers',
  'sni.lyssnarport': 'Listen port',
  'sni.extern_ip_valfri': 'External IP (optional)',
  'sni.bind_alla_om_tom': 'bind all if empty',
  'sni.section_namn_till_server': 'NAME → INTERNAL SERVER',
  'sni.section_fallback': 'FALLBACK (LAST RESORT)',
  'sni.intern_ip': 'Internal IP',
  'sni.port': 'Port',
  'sni.vardnamn_label': 'Hostnames (comma-separated, "*.x.se" supported)',
  'sni.vardnamn_hint': 'e.g. px1.example.com, px2.example.com',

  // --- routes_screen.dart ---
  'routes.avbryt': 'Cancel',
  'routes.ta_bort': 'Delete',
  'routes.lat_karnan_valja_rekommenderas': 'Let the kernel choose (recommended)',
  'routes.statiska_rutter_routing': 'Static Routes (Routing)',
  'routes.ny_rutt': 'New route',
  'routes.inga_statiska_rutter_definierade': 'No static routes defined.',
  'routes.ta_bort_rutten': 'Delete the route?',
  'routes.granssnitt_valfritt': 'Interface (optional)',
  'routes.aktiverad': 'Enabled',
  'routes.spara': 'Save',
  'routes.redigera_rutt': 'Edit route',
  'routes.ta_bort_rutt': 'Delete route',
  'routes.intro_body': "A route only makes the network REACHABLE. Traffic to it is still only allowed if there's a matching Allow policy under Policies — Default Deny otherwise applies as usual.",
  'routes.delete_confirm_body': 'Delete the route "{name}"?\n\nThe change is saved to the candidate but won\'t take effect on the firewall until you press Apply.',
  'routes.ny_statisk_rutt': 'New static route',
  'routes.namn_valfritt': 'Name (optional)',
  'routes.namn_hint': 'e.g. Office network via router',
  'routes.nat_cidr': 'Network (CIDR)',
  'routes.nat_hint': 'e.g. 192.168.113.0/24',
  'routes.gateway': 'Gateway',
  'routes.gateway_hint': 'e.g. 10.0.0.1',
  'routes.beskrivning_valfritt': 'Description (optional)',
  'routes.error_cidr': 'The network must be given as CIDR, e.g. 192.168.113.0/24',
  'routes.error_gateway': 'A gateway is required, e.g. 10.0.0.1',
};
