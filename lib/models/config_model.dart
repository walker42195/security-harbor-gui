class ConfigModel {
  final int version;
  final int revision;
  final String updatedAt;
  final List<InterfaceModel> interfaces;
  final List<ZoneModel> zones;
  final List<ObjectModel> objects;
  final List<ServiceModel> services;
  final List<PolicyModel> policies;
  final SettingsModel settings;
  final WireGuardConfigModel? wireguard;
  final OpenVPNConfigModel? openvpn;
  final DNSConfigModel? dns;
  final NTPConfigModel? ntp;
  final SyslogConfigModel? syslog;
  final IDSConfigModel? ids;
  final List<SNIRouteModel> sniRoutes;
  final List<StaticRouteModel> staticRoutes;

  ConfigModel({
    required this.version,
    required this.revision,
    required this.updatedAt,
    required this.interfaces,
    required this.zones,
    required this.objects,
    required this.services,
    required this.policies,
    required this.settings,
    this.wireguard,
    this.openvpn,
    this.dns,
    this.ntp,
    this.syslog,
    this.ids,
    this.sniRoutes = const [],
    this.staticRoutes = const [],
  });

  factory ConfigModel.fromJson(Map<String, dynamic> json) {
    return ConfigModel(
      version: json['version'] ?? 1,
      revision: json['revision'] ?? 0,
      updatedAt: json['updated_at'] ?? '',
      interfaces: (json['interfaces'] as List? ?? []).map((e) => InterfaceModel.fromJson(e)).toList(),
      zones: (json['zones'] as List? ?? []).map((e) => ZoneModel.fromJson(e)).toList(),
      objects: (json['objects'] as List? ?? []).map((e) => ObjectModel.fromJson(e)).toList(),
      services: (json['services'] as List? ?? []).map((e) => ServiceModel.fromJson(e)).toList(),
      policies: (json['policies'] as List? ?? []).map((e) => PolicyModel.fromJson(e)).toList(),
      settings: SettingsModel.fromJson(json['settings'] ?? {}),
      wireguard: json['wireguard'] != null ? WireGuardConfigModel.fromJson(json['wireguard']) : null,
      openvpn: json['openvpn'] != null ? OpenVPNConfigModel.fromJson(json['openvpn']) : null,
      dns: json['dns'] != null ? DNSConfigModel.fromJson(json['dns']) : null,
      ntp: json['ntp'] != null ? NTPConfigModel.fromJson(json['ntp']) : null,
      syslog: json['syslog'] != null ? SyslogConfigModel.fromJson(json['syslog']) : null,
      ids: json['ids'] != null ? IDSConfigModel.fromJson(json['ids']) : null,
      sniRoutes: (json['sni_routes'] as List? ?? []).map((e) => SNIRouteModel.fromJson(e)).toList(),
      staticRoutes: (json['static_routes'] as List? ?? []).map((e) => StaticRouteModel.fromJson(e)).toList(),
    );
  }

  /// Returnerar en kopia med bara de angivna fälten utbytta.
  ///
  /// ALLA fält finns med här, inte bara de valfria undersektionerna. Skälet
  /// är en bugg som hittades vid kodgranskning 2026-08-20: skärmarna för
  /// policyer/objekt/gränssnitt byggde en helt ny ConfigModel för hand och
  /// räknade upp fält ett och ett — men ingen av dem skickade med `syslog`
  /// eller `ids` (de tillkom senare, i Fas 8/9, och call-sitesen
  /// uppdaterades aldrig). Eftersom GUI:t PUT:ar HELA konfigurationen vid
  /// varje ändring innebar det att så fort någon redigerade en enda
  /// brandväggsregel raderades IDS- och syslog-inställningarna tyst ur
  /// konfigurationen. Med copyWith måste ett nytt fält aktivt utelämnas
  /// för att försvinna, i stället för att glömmas bort som standard.
  ConfigModel copyWith({
    int? version,
    int? revision,
    String? updatedAt,
    List<InterfaceModel>? interfaces,
    List<ZoneModel>? zones,
    List<ObjectModel>? objects,
    List<ServiceModel>? services,
    List<PolicyModel>? policies,
    SettingsModel? settings,
    WireGuardConfigModel? wireguard,
    OpenVPNConfigModel? openvpn,
    DNSConfigModel? dns,
    NTPConfigModel? ntp,
    SyslogConfigModel? syslog,
    IDSConfigModel? ids,
    List<SNIRouteModel>? sniRoutes,
    List<StaticRouteModel>? staticRoutes,
  }) =>
      ConfigModel(
        version: version ?? this.version,
        revision: revision ?? this.revision,
        updatedAt: updatedAt ?? this.updatedAt,
        interfaces: interfaces ?? this.interfaces,
        zones: zones ?? this.zones,
        objects: objects ?? this.objects,
        services: services ?? this.services,
        policies: policies ?? this.policies,
        settings: settings ?? this.settings,
        wireguard: wireguard ?? this.wireguard,
        openvpn: openvpn ?? this.openvpn,
        dns: dns ?? this.dns,
        ntp: ntp ?? this.ntp,
        syslog: syslog ?? this.syslog,
        ids: ids ?? this.ids,
        sniRoutes: sniRoutes ?? this.sniRoutes,
        staticRoutes: staticRoutes ?? this.staticRoutes,
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'revision': revision,
        'updated_at': updatedAt,
        'interfaces': interfaces.map((e) => e.toJson()).toList(),
        'zones': zones.map((e) => e.toJson()).toList(),
        'objects': objects.map((e) => e.toJson()).toList(),
        'services': services.map((e) => e.toJson()).toList(),
        'policies': policies.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
        if (wireguard != null) 'wireguard': wireguard!.toJson(),
        if (openvpn != null) 'openvpn': openvpn!.toJson(),
        if (dns != null) 'dns': dns!.toJson(),
        if (ntp != null) 'ntp': ntp!.toJson(),
        if (syslog != null) 'syslog': syslog!.toJson(),
        if (ids != null) 'ids': ids!.toJson(),
        'sni_routes': sniRoutes.map((e) => e.toJson()).toList(),
        'static_routes': staticRoutes.map((e) => e.toJson()).toList(),
      };
}

/// Statisk IP-rutt (`ip route add <network> via <gateway>`) — se
/// pkg/config.StaticRoute i backend. Ett nät som inte nås via brandväggens
/// vanliga default-rutt utan kräver en specifik gateway, t.ex. ett internt
/// nät bakom en annan router på LAN-sidan.
class StaticRouteModel {
  final String id;
  final String name;
  final bool enabled;
  final String network; // CIDR, t.ex. "192.168.113.0/24"
  final String gateway; // t.ex. "10.0.0.1"
  final String interfaceDevice; // Valfritt, t.ex. "ens19" — tomt = låt kärnan välja
  final String description;

  StaticRouteModel({
    required this.id,
    this.name = '',
    this.enabled = true,
    required this.network,
    required this.gateway,
    this.interfaceDevice = '',
    this.description = '',
  });

  factory StaticRouteModel.fromJson(Map<String, dynamic> json) => StaticRouteModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        enabled: json['enabled'] ?? true,
        network: json['network'] ?? '',
        gateway: json['gateway'] ?? '',
        interfaceDevice: json['interface'] ?? '',
        description: json['description'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'network': network,
        'gateway': gateway,
        if (interfaceDevice.isNotEmpty) 'interface': interfaceDevice,
        'description': description,
      };

  StaticRouteModel copyWith({
    String? name,
    bool? enabled,
    String? network,
    String? gateway,
    String? interfaceDevice,
    String? description,
  }) =>
      StaticRouteModel(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        network: network ?? this.network,
        gateway: gateway ?? this.gateway,
        interfaceDevice: interfaceDevice ?? this.interfaceDevice,
        description: description ?? this.description,
      );
}

/// Namnbaserad routning (SNI passthrough via HAProxy) — se pkg/config SNIRoute
/// i backend. En rutt = en lyssnarport med flera värdnamn → olika interna
/// servrar. TLS termineras aldrig.
class SNIRouteModel {
  final String id;
  final String name;
  final bool enabled;
  final int listenPort;
  final String externalIp;
  final List<SNIBackendModel> backends;
  final SNIBackendModel? defaultBackend;

  SNIRouteModel({
    required this.id,
    this.name = '',
    this.enabled = true,
    this.listenPort = 443,
    this.externalIp = '',
    this.backends = const [],
    this.defaultBackend,
  });

  factory SNIRouteModel.fromJson(Map<String, dynamic> json) => SNIRouteModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        enabled: json['enabled'] ?? true,
        listenPort: json['listen_port'] ?? 443,
        externalIp: json['external_ip'] ?? '',
        backends: (json['backends'] as List? ?? []).map((e) => SNIBackendModel.fromJson(e)).toList(),
        defaultBackend: json['default_backend'] != null ? SNIBackendModel.fromJson(json['default_backend']) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'listen_port': listenPort,
        if (externalIp.isNotEmpty) 'external_ip': externalIp,
        'backends': backends.map((e) => e.toJson()).toList(),
        if (defaultBackend != null) 'default_backend': defaultBackend!.toJson(),
      };

  SNIRouteModel copyWith({
    String? name,
    bool? enabled,
    int? listenPort,
    String? externalIp,
    List<SNIBackendModel>? backends,
    SNIBackendModel? defaultBackend,
    bool clearDefault = false,
  }) =>
      SNIRouteModel(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        listenPort: listenPort ?? this.listenPort,
        externalIp: externalIp ?? this.externalIp,
        backends: backends ?? this.backends,
        defaultBackend: clearDefault ? null : (defaultBackend ?? this.defaultBackend),
      );
}

/// Ett vidarebefordringsmål i en SNI-rutt: antingen en intern server
/// (targetIp:targetPort) eller en lokal tjänst (localService, t.ex. "openvpn").
class SNIBackendModel {
  final List<String> hostnames;
  final String targetIp;
  final int targetPort;
  final String localService; // "" | "openvpn"

  SNIBackendModel({
    this.hostnames = const [],
    this.targetIp = '',
    this.targetPort = 0,
    this.localService = '',
  });

  bool get isLocalOpenVPN => localService == 'openvpn';

  factory SNIBackendModel.fromJson(Map<String, dynamic> json) => SNIBackendModel(
        hostnames: List<String>.from(json['hostnames'] ?? []),
        targetIp: json['target_ip'] ?? '',
        targetPort: json['target_port'] ?? 0,
        localService: json['local_service'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        if (hostnames.isNotEmpty) 'hostnames': hostnames,
        if (targetIp.isNotEmpty) 'target_ip': targetIp,
        if (targetPort != 0) 'target_port': targetPort,
        if (localService.isNotEmpty) 'local_service': localService,
      };
}

/// Centraliserad syslog-vidarebefordran (Fas 8) — se
/// pkg/adapter/syslog i backend.
class SyslogConfigModel {
  final bool enabled;
  final String host;
  final int port;
  final String protocol; // "udp" eller "tcp"

  SyslogConfigModel({
    required this.enabled,
    this.host = '',
    this.port = 514,
    this.protocol = 'udp',
  });

  factory SyslogConfigModel.fromJson(Map<String, dynamic> json) {
    return SyslogConfigModel(
      enabled: json['enabled'] ?? false,
      host: json['host'] ?? '',
      port: json['port'] ?? 514,
      protocol: json['protocol'] ?? 'udp',
    );
  }

  SyslogConfigModel copyWith({bool? enabled, String? host, int? port, String? protocol}) => SyslogConfigModel(
        enabled: enabled ?? this.enabled,
        host: host ?? this.host,
        port: port ?? this.port,
        protocol: protocol ?? this.protocol,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'host': host,
        'port': port,
        'protocol': protocol,
      };
}

/// Suricata IDS i passivt af-packet-läge (Fas 9) — se pkg/adapter/suricata
/// i backend. AutoBlock kräver att AutoBlockObjectID pekar på ett REDAN
/// EXISTERANDE objekt (skapas via Objekt-vyn) — ingen policy eller objekt
/// skapas automatiskt.
class IDSConfigModel {
  final bool enabled;
  final String interfaceDevice;
  final bool autoBlock;
  final String autoBlockObjectId;
  final int autoBlockSeverity;

  IDSConfigModel({
    required this.enabled,
    this.interfaceDevice = '',
    this.autoBlock = false,
    this.autoBlockObjectId = '',
    this.autoBlockSeverity = 2,
  });

  factory IDSConfigModel.fromJson(Map<String, dynamic> json) {
    return IDSConfigModel(
      enabled: json['enabled'] ?? false,
      interfaceDevice: json['interface'] ?? '',
      autoBlock: json['auto_block'] ?? false,
      autoBlockObjectId: json['auto_block_object_id'] ?? '',
      autoBlockSeverity: json['auto_block_severity'] ?? 2,
    );
  }

  IDSConfigModel copyWith({
    bool? enabled,
    String? interfaceDevice,
    bool? autoBlock,
    String? autoBlockObjectId,
    int? autoBlockSeverity,
  }) =>
      IDSConfigModel(
        enabled: enabled ?? this.enabled,
        interfaceDevice: interfaceDevice ?? this.interfaceDevice,
        autoBlock: autoBlock ?? this.autoBlock,
        autoBlockObjectId: autoBlockObjectId ?? this.autoBlockObjectId,
        autoBlockSeverity: autoBlockSeverity ?? this.autoBlockSeverity,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'interface': interfaceDevice,
        'auto_block': autoBlock,
        'auto_block_object_id': autoBlockObjectId,
        'auto_block_severity': autoBlockSeverity,
      };
}

/// Server-sidans OpenVPN-inställningar (Fas 4). CA-nyckeln och klienternas
/// privata nycklar lämnar aldrig agenten — bara caCertPem (publikt) och
/// klienternas publika certifikat/serienummer syns i GUI:t.
class OpenVPNConfigModel {
  final bool enabled;
  final int listenPort;
  final String protocol; // "udp" eller "tcp"
  final String address; // VPN-subnät, t.ex. "10.77.77.0/24"
  final String endpoint;
  final String caCertPem;
  final List<OpenVPNClientModel> clients;

  OpenVPNConfigModel({
    required this.enabled,
    required this.listenPort,
    required this.protocol,
    required this.address,
    required this.endpoint,
    this.caCertPem = '',
    required this.clients,
  });

  factory OpenVPNConfigModel.fromJson(Map<String, dynamic> json) {
    return OpenVPNConfigModel(
      enabled: json['enabled'] ?? false,
      listenPort: json['listen_port'] ?? 1194,
      protocol: json['protocol'] ?? 'udp',
      address: json['address'] ?? '',
      endpoint: json['endpoint'] ?? '',
      caCertPem: json['ca_cert_pem'] ?? '',
      clients: (json['clients'] as List? ?? []).map((e) => OpenVPNClientModel.fromJson(e)).toList(),
    );
  }

  OpenVPNConfigModel copyWith({
    bool? enabled,
    int? listenPort,
    String? protocol,
    String? address,
    String? endpoint,
    List<OpenVPNClientModel>? clients,
  }) =>
      OpenVPNConfigModel(
        enabled: enabled ?? this.enabled,
        listenPort: listenPort ?? this.listenPort,
        protocol: protocol ?? this.protocol,
        address: address ?? this.address,
        endpoint: endpoint ?? this.endpoint,
        caCertPem: caCertPem,
        clients: clients ?? this.clients,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'listen_port': listenPort,
        'protocol': protocol,
        'address': address,
        'endpoint': endpoint,
        'clients': clients.map((e) => e.toJson()).toList(),
      };
}

class OpenVPNClientModel {
  final String id;
  final String name;
  final bool enabled;
  final bool revoked;
  final String certSerial;
  final String certPem;
  final String issuedAt;

  OpenVPNClientModel({
    required this.id,
    required this.name,
    required this.enabled,
    this.revoked = false,
    this.certSerial = '',
    this.certPem = '',
    this.issuedAt = '',
  });

  factory OpenVPNClientModel.fromJson(Map<String, dynamic> json) {
    return OpenVPNClientModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      enabled: json['enabled'] ?? true,
      revoked: json['revoked'] ?? false,
      certSerial: json['cert_serial'] ?? '',
      certPem: json['cert_pem'] ?? '',
      issuedAt: json['issued_at'] ?? '',
    );
  }

  OpenVPNClientModel copyWith({bool? enabled, bool? revoked}) => OpenVPNClientModel(
        id: id,
        name: name,
        enabled: enabled ?? this.enabled,
        revoked: revoked ?? this.revoked,
        certSerial: certSerial,
        certPem: certPem,
        issuedAt: issuedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'revoked': revoked,
        'cert_serial': certSerial,
        'cert_pem': certPem,
        'issued_at': issuedAt,
      };
}

/// Server-sidans WireGuard-inställningar (wg0). Den privata serverns nyckel
/// lämnar aldrig agenten — endast `serverPublicKey` (fylld i av agenten,
/// aldrig skriven härifrån) och peer-listans publika nycklar syns i GUI:t.
class WireGuardConfigModel {
  final bool enabled;
  final int listenPort;
  final String address;
  final String endpoint;
  final String serverPublicKey;
  final List<WireGuardPeerModel> peers;

  WireGuardConfigModel({
    required this.enabled,
    required this.listenPort,
    required this.address,
    required this.endpoint,
    this.serverPublicKey = '',
    required this.peers,
  });

  factory WireGuardConfigModel.fromJson(Map<String, dynamic> json) {
    return WireGuardConfigModel(
      enabled: json['enabled'] ?? false,
      listenPort: json['listen_port'] ?? 51820,
      address: json['address'] ?? '',
      endpoint: json['endpoint'] ?? '',
      serverPublicKey: json['server_public_key'] ?? '',
      peers: (json['peers'] as List? ?? []).map((e) => WireGuardPeerModel.fromJson(e)).toList(),
    );
  }

  WireGuardConfigModel copyWith({
    bool? enabled,
    int? listenPort,
    String? address,
    String? endpoint,
    List<WireGuardPeerModel>? peers,
  }) =>
      WireGuardConfigModel(
        enabled: enabled ?? this.enabled,
        listenPort: listenPort ?? this.listenPort,
        address: address ?? this.address,
        endpoint: endpoint ?? this.endpoint,
        serverPublicKey: serverPublicKey,
        peers: peers ?? this.peers,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'listen_port': listenPort,
        'address': address,
        'endpoint': endpoint,
        'peers': peers.map((e) => e.toJson()).toList(),
      };
}

class WireGuardPeerModel {
  final String id;
  final String name;
  final String publicKey;
  final String allowedIps;
  final bool enabled;

  WireGuardPeerModel({
    required this.id,
    required this.name,
    required this.publicKey,
    required this.allowedIps,
    required this.enabled,
  });

  factory WireGuardPeerModel.fromJson(Map<String, dynamic> json) {
    return WireGuardPeerModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      publicKey: json['public_key'] ?? '',
      allowedIps: json['allowed_ips'] ?? '',
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'public_key': publicKey,
        'allowed_ips': allowedIps,
        'enabled': enabled,
      };
}

class InterfaceModel {
  final String id;
  final String name;
  final String device;
  final String parent;
  final int vlanId;
  final String zone;
  final bool enabled;
  final String addressType;
  final String ipv4;
  final String gateway;
  final List<String> dnsServers;
  final int mtu;
  /// Manuellt satt MAC-adress ("MAC-kloning"). Tomt = kortets brända adress
  /// används. Främst för WAN: en del ISP:er binder abonnemanget till MAC:en
  /// på den router som registrerades först.
  final String macAddress;
  final DHCPConfigModel? dhcp;

  InterfaceModel({
    required this.id,
    this.name = '',
    required this.device,
    this.parent = '',
    this.vlanId = 0,
    required this.zone,
    required this.enabled,
    required this.addressType,
    required this.ipv4,
    this.gateway = '',
    this.dnsServers = const [],
    this.mtu = 1500,
    this.macAddress = '',
    this.dhcp,
  });

  factory InterfaceModel.fromJson(Map<String, dynamic> json) {
    return InterfaceModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      device: json['device'] ?? '',
      parent: json['parent'] ?? '',
      vlanId: json['vlan_id'] ?? 0,
      zone: json['zone'] ?? 'LAN',
      enabled: json['enabled'] ?? true,
      addressType: json['address_type'] ?? 'static',
      ipv4: json['ipv4'] ?? '',
      gateway: json['gateway'] ?? '',
      dnsServers: List<String>.from(json['dns_servers'] ?? []),
      mtu: json['mtu'] ?? 1500,
      macAddress: json['mac_address'] ?? '',
      dhcp: json['dhcp'] != null ? DHCPConfigModel.fromJson(json['dhcp']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'device': device,
        'parent': parent,
        'vlan_id': vlanId,
        'zone': zone,
        'enabled': enabled,
        'address_type': addressType,
        'ipv4': ipv4,
        'gateway': gateway,
        'dns_servers': dnsServers,
        'mtu': mtu,
        'mac_address': macAddress,
        if (dhcp != null) 'dhcp': dhcp!.toJson(),
      };

  InterfaceModel copyWith({String? name, String? zone, String? macAddress, DHCPConfigModel? dhcp}) => InterfaceModel(
        id: id,
        name: name ?? this.name,
        device: device,
        parent: parent,
        vlanId: vlanId,
        zone: zone ?? this.zone,
        enabled: enabled,
        addressType: addressType,
        ipv4: ipv4,
        gateway: gateway,
        dnsServers: dnsServers,
        mtu: mtu,
        macAddress: macAddress ?? this.macAddress,
        dhcp: dhcp ?? this.dhcp,
      );
}

class DHCPConfigModel {
  final bool enabled;
  final String rangeStart;
  final String rangeEnd;
  final String gateway;
  final List<String> dnsServers;
  final int leaseTimeSec;
  final List<DHCPReservationModel> reservations;

  DHCPConfigModel({
    required this.enabled,
    required this.rangeStart,
    required this.rangeEnd,
    required this.gateway,
    required this.dnsServers,
    this.leaseTimeSec = 86400,
    required this.reservations,
  });

  factory DHCPConfigModel.fromJson(Map<String, dynamic> json) {
    return DHCPConfigModel(
      enabled: json['enabled'] ?? false,
      rangeStart: json['range_start'] ?? '',
      rangeEnd: json['range_end'] ?? '',
      gateway: json['gateway'] ?? '',
      dnsServers: List<String>.from(json['dns_servers'] ?? []),
      leaseTimeSec: json['lease_time_sec'] ?? 86400,
      reservations: (json['reservations'] as List? ?? []).map((e) => DHCPReservationModel.fromJson(e)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'range_start': rangeStart,
        'range_end': rangeEnd,
        'gateway': gateway,
        'dns_servers': dnsServers,
        'lease_time_sec': leaseTimeSec,
        'reservations': reservations.map((e) => e.toJson()).toList(),
      };
}

class DHCPReservationModel {
  final String hostname;
  final String mac;
  final String ip;

  DHCPReservationModel({required this.hostname, required this.mac, required this.ip});

  factory DHCPReservationModel.fromJson(Map<String, dynamic> json) {
    return DHCPReservationModel(
      hostname: json['hostname'] ?? '',
      mac: json['mac'] ?? '',
      ip: json['ip'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'hostname': hostname, 'mac': mac, 'ip': ip};
}

class ZoneModel {
  final String name;
  final String description;

  ZoneModel({required this.name, required this.description});

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    return ZoneModel(name: json['name'] ?? '', description: json['description'] ?? '');
  }

  Map<String, dynamic> toJson() => {'name': name, 'description': description};
}

class ObjectModel {
  final String id;
  final String name;
  final String type;
  final List<String> values;
  final String description;
  final ObjectSourceModel? source;

  ObjectModel({required this.id, required this.name, required this.type, required this.values, required this.description, this.source});

  factory ObjectModel.fromJson(Map<String, dynamic> json) {
    return ObjectModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'host',
      values: List<String>.from(json['values'] ?? []),
      description: json['description'] ?? '',
      source: json['source'] != null ? ObjectSourceModel.fromJson(json['source']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'values': values,
        'description': description,
        if (source != null) 'source': source!.toJson(),
      };
}

/// Beskriver en extern, automatiskt uppdaterad källa för ett iplist-/geoip-
/// objekts values (Fas 5 — Hot-listor & GeoIP). Agenten hämtar och skriver
/// om values med jämna mellanrum (pkg/threatfeed) — GUI:t visar bara status
/// och kan trigga en omedelbar uppdatering.
class ObjectSourceModel {
  final String kind; // "spamhaus_drop" | "spamhaus_edrop" | "tor_exit_nodes" | "custom_url" | "geoip_country"
  final String url;
  final String countryCode;
  final int refreshHours;
  final String lastUpdated;
  final String lastError;
  final int entryCount;

  ObjectSourceModel({
    required this.kind,
    this.url = '',
    this.countryCode = '',
    this.refreshHours = 24,
    this.lastUpdated = '',
    this.lastError = '',
    this.entryCount = 0,
  });

  factory ObjectSourceModel.fromJson(Map<String, dynamic> json) {
    return ObjectSourceModel(
      kind: json['kind'] ?? '',
      url: json['url'] ?? '',
      countryCode: json['country_code'] ?? '',
      refreshHours: json['refresh_hours'] ?? 24,
      lastUpdated: json['last_updated'] ?? '',
      lastError: json['last_error'] ?? '',
      entryCount: json['entry_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'url': url,
        'country_code': countryCode,
        'refresh_hours': refreshHours,
        // Status-fälten MÅSTE skickas tillbaka. Utelämnades tidigare, vilket
        // gjorde att varje gång GUI:t PUT:ade hela configen (t.ex. vid en
        // policy-ändring) nollställdes senast-uppdaterad/antal/fel som
        // agentens hot-lista-uppdaterare hade satt — objektet visade då
        // "Aldrig uppdaterad" trots att listan var hämtad (upptäckt
        // 2026-08-20). Backend behandlar dem numera som server-ägda och
        // återställer dem ändå, men att skicka dem korrekt är rätt.
        'last_updated': lastUpdated,
        'last_error': lastError,
        'entry_count': entryCount,
      };
}

class ServiceModel {
  final String id;
  final String name;
  final String protocol; // "tcp", "udp", "icmp", "any", eller "group" (Fas 7)
  final List<String> ports;
  final String description;
  final List<String> members; // Andra Service-ID:n, bara när protocol=="group"

  ServiceModel({required this.id, required this.name, required this.protocol, required this.ports, required this.description, this.members = const []});

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      protocol: json['protocol'] ?? 'tcp',
      ports: List<String>.from(json['ports'] ?? []),
      description: json['description'] ?? '',
      members: List<String>.from(json['members'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol,
        'ports': ports,
        'description': description,
        if (members.isNotEmpty) 'members': members,
      };
}

class PolicyModel {
  final String id;
  final String name;
  final bool enabled;
  final int priority;
  final String sourceZone;
  final String destZone;
  final String sourceObj;
  final String destObj;
  final String service;
  final String action;
  final NATConfigModel? nat;
  final bool logging;
  final String description;
  final bool local; // Gäller åtkomst till brandväggen själv (INPUT), t.ex. SSH
  final bool critical; // Kräver bekräftelse innan den inaktiveras/tas bort
  // protected är ett strängare skydd än critical: går INTE att inaktivera
  // eller ta bort ens med bekräftelse — GUI:t blockerar det helt (se
  // policies_screen.dart), och backend (validatePolicies vid Apply) stoppar
  // det ändå om GUI-spärren skulle kringgås. Används för Management
  // API-policyn ("sys-mgmt-api-lan") — se agentens config.MgmtAPIPolicyID.
  final bool protected;
  final PolicyScheduleModel? schedule; // Fas 7: tidsstyrd policy

  PolicyModel({
    required this.id,
    required this.name,
    required this.enabled,
    this.priority = 100,
    required this.sourceZone,
    required this.destZone,
    required this.sourceObj,
    required this.destObj,
    required this.service,
    required this.action,
    this.nat,
    this.logging = false,
    this.description = '',
    this.local = false,
    this.critical = false,
    this.protected = false,
    this.schedule,
  });

  factory PolicyModel.fromJson(Map<String, dynamic> json) {
    return PolicyModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      enabled: json['enabled'] ?? true,
      priority: json['priority'] ?? 100,
      sourceZone: json['source_zone'] ?? 'ANY',
      destZone: json['dest_zone'] ?? 'ANY',
      sourceObj: json['source_obj'] ?? 'ANY',
      destObj: json['dest_obj'] ?? 'ANY',
      service: json['service'] ?? 'ANY',
      action: json['action'] ?? 'accept',
      nat: json['nat'] != null ? NATConfigModel.fromJson(json['nat']) : null,
      logging: json['logging'] ?? false,
      description: json['description'] ?? '',
      local: json['local'] ?? false,
      critical: json['critical'] ?? false,
      protected: json['protected'] ?? false,
      schedule: json['schedule'] != null ? PolicyScheduleModel.fromJson(json['schedule']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'priority': priority,
        'source_zone': sourceZone,
        'dest_zone': destZone,
        'source_obj': sourceObj,
        'dest_obj': destObj,
        'service': service,
        'action': action,
        if (nat != null) 'nat': nat!.toJson(),
        'logging': logging,
        'description': description,
        'local': local,
        'critical': critical,
        'protected': protected,
        if (schedule != null) 'schedule': schedule!.toJson(),
      };

  PolicyModel copyWith({String? sourceZone, String? destZone}) => PolicyModel(
        id: id,
        name: name,
        enabled: enabled,
        priority: priority,
        sourceZone: sourceZone ?? this.sourceZone,
        destZone: destZone ?? this.destZone,
        sourceObj: sourceObj,
        destObj: destObj,
        service: service,
        action: action,
        nat: nat,
        logging: logging,
        description: description,
        local: local,
        critical: critical,
        protected: protected,
        schedule: schedule,
      );
}

/// Begränsar när en Policy är aktiv (Fas 7 — Schema/tidsbaserade regler).
/// Days är engelska veckodagsnamn ("Monday".."Sunday", nftables kräver
/// engelska), tom lista = alla dagar.
class PolicyScheduleModel {
  final bool enabled;
  final List<String> days;
  final String startTime; // "HH:MM"
  final String endTime; // "HH:MM"

  PolicyScheduleModel({required this.enabled, this.days = const [], this.startTime = '08:00', this.endTime = '17:00'});

  factory PolicyScheduleModel.fromJson(Map<String, dynamic> json) {
    return PolicyScheduleModel(
      enabled: json['enabled'] ?? false,
      days: List<String>.from(json['days'] ?? []),
      startTime: json['start_time'] ?? '08:00',
      endTime: json['end_time'] ?? '17:00',
    );
  }

  Map<String, dynamic> toJson() => {'enabled': enabled, 'days': days, 'start_time': startTime, 'end_time': endTime};
}

class NATConfigModel {
  final int externalPort;
  final String internalIp;
  final int internalPort;
  final String protocol;
  final String externalIp; // Fas 7: 1:1 NAT (dnat) eller SNAT-override (snat)

  NATConfigModel({required this.externalPort, required this.internalIp, required this.internalPort, required this.protocol, this.externalIp = ''});

  factory NATConfigModel.fromJson(Map<String, dynamic> json) {
    return NATConfigModel(
      externalPort: json['external_port'] ?? 0,
      internalIp: json['internal_ip'] ?? '',
      internalPort: json['internal_port'] ?? 0,
      protocol: json['protocol'] ?? 'tcp',
      externalIp: json['external_ip'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'external_port': externalPort,
        'internal_ip': internalIp,
        if (externalIp.isNotEmpty) 'external_ip': externalIp,
        'internal_port': internalPort,
        'protocol': protocol,
      };
}

/// Styr brandväggens lokala DNS-resolver (Fas 6). Domänblocklistans
/// innehåll lämnar aldrig agenten över API:t — bara källmetadata/status.
class DNSConfigModel {
  final bool enabled;
  final List<String> upstreamServers;
  final bool dotEnabled;
  final String dotHostname;
  // recursive: om sant slår servern själv mot rot-servrarna istället för
  // att vidarebefordra till upstreamServers (som då ignoreras).
  final bool recursive;
  final List<DNSBlocklistSourceModel> blocklists; // Flera kan vara aktiva samtidigt
  final List<String> customBlockedDomains;
  final List<String> customAllowedDomains;
  final List<DNSStaticRecordModel> staticRecords;
  final String localDomain;
  final bool dhcpHostnameRegistration;

  DNSConfigModel({
    required this.enabled,
    this.upstreamServers = const [],
    this.dotEnabled = false,
    this.dotHostname = '',
    this.recursive = false,
    this.blocklists = const [],
    this.customBlockedDomains = const [],
    this.customAllowedDomains = const [],
    this.staticRecords = const [],
    this.localDomain = '',
    this.dhcpHostnameRegistration = false,
  });

  factory DNSConfigModel.fromJson(Map<String, dynamic> json) {
    return DNSConfigModel(
      enabled: json['enabled'] ?? false,
      upstreamServers: List<String>.from(json['upstream_servers'] ?? []),
      dotEnabled: json['dot_enabled'] ?? false,
      dotHostname: json['dot_hostname'] ?? '',
      recursive: json['recursive'] ?? false,
      blocklists: (json['blocklists'] as List? ?? []).map((e) => DNSBlocklistSourceModel.fromJson(e)).toList(),
      customBlockedDomains: List<String>.from(json['custom_blocked_domains'] ?? []),
      customAllowedDomains: List<String>.from(json['custom_allowed_domains'] ?? []),
      staticRecords: (json['static_records'] as List? ?? []).map((e) => DNSStaticRecordModel.fromJson(e)).toList(),
      localDomain: json['local_domain'] ?? '',
      dhcpHostnameRegistration: json['dhcp_hostname_registration'] ?? false,
    );
  }

  DNSConfigModel copyWith({
    bool? enabled,
    List<String>? upstreamServers,
    bool? dotEnabled,
    String? dotHostname,
    bool? recursive,
    List<DNSBlocklistSourceModel>? blocklists,
    List<String>? customBlockedDomains,
    List<String>? customAllowedDomains,
    List<DNSStaticRecordModel>? staticRecords,
    String? localDomain,
    bool? dhcpHostnameRegistration,
  }) =>
      DNSConfigModel(
        enabled: enabled ?? this.enabled,
        upstreamServers: upstreamServers ?? this.upstreamServers,
        dotEnabled: dotEnabled ?? this.dotEnabled,
        dotHostname: dotHostname ?? this.dotHostname,
        recursive: recursive ?? this.recursive,
        blocklists: blocklists ?? this.blocklists,
        customBlockedDomains: customBlockedDomains ?? this.customBlockedDomains,
        customAllowedDomains: customAllowedDomains ?? this.customAllowedDomains,
        staticRecords: staticRecords ?? this.staticRecords,
        localDomain: localDomain ?? this.localDomain,
        dhcpHostnameRegistration: dhcpHostnameRegistration ?? this.dhcpHostnameRegistration,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'upstream_servers': upstreamServers,
        'dot_enabled': dotEnabled,
        'dot_hostname': dotHostname,
        'recursive': recursive,
        'blocklists': blocklists.map((e) => e.toJson()).toList(),
        'custom_blocked_domains': customBlockedDomains,
        'custom_allowed_domains': customAllowedDomains,
        'static_records': staticRecords.map((e) => e.toJson()).toList(),
        'local_domain': localDomain,
        'dhcp_hostname_registration': dhcpHostnameRegistration,
      };
}

/// EN manuellt inmatad A-post i den lokala DNS-zonen.
class DNSStaticRecordModel {
  final String hostname;
  final String ip;

  DNSStaticRecordModel({required this.hostname, required this.ip});

  factory DNSStaticRecordModel.fromJson(Map<String, dynamic> json) =>
      DNSStaticRecordModel(hostname: json['hostname'] ?? '', ip: json['ip'] ?? '');

  Map<String, dynamic> toJson() => {'hostname': hostname, 'ip': ip};
}

/// EN automatiskt uppdaterad domänblocklista (Fas 6). Flera kan vara
/// aktiverade samtidigt (t.ex. StevenBlack hosts + en egen URL parallellt).
class DNSBlocklistSourceModel {
  final String id;
  final String name;
  final bool enabled;
  final String kind; // "stevenblack_hosts" | "custom_domain_url"
  final String url;
  final int refreshHours;
  final String lastUpdated;
  final String lastError;
  final int entryCount;

  DNSBlocklistSourceModel({
    required this.id,
    required this.name,
    required this.enabled,
    this.kind = 'stevenblack_hosts',
    this.url = '',
    this.refreshHours = 24,
    this.lastUpdated = '',
    this.lastError = '',
    this.entryCount = 0,
  });

  factory DNSBlocklistSourceModel.fromJson(Map<String, dynamic> json) {
    return DNSBlocklistSourceModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      enabled: json['enabled'] ?? true,
      kind: json['kind'] ?? 'stevenblack_hosts',
      url: json['url'] ?? '',
      refreshHours: json['refresh_hours'] ?? 24,
      lastUpdated: json['last_updated'] ?? '',
      lastError: json['last_error'] ?? '',
      entryCount: json['entry_count'] ?? 0,
    );
  }

  DNSBlocklistSourceModel copyWith({bool? enabled}) => DNSBlocklistSourceModel(
        id: id,
        name: name,
        enabled: enabled ?? this.enabled,
        kind: kind,
        url: url,
        refreshHours: refreshHours,
        lastUpdated: lastUpdated,
        lastError: lastError,
        entryCount: entryCount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'kind': kind,
        'url': url,
        'refresh_hours': refreshHours,
      };
}

class SettingsModel {
  final String hostname;
  final int apiPort;
  // mode: "" eller "gateway" (router/appliance, standard) eller "host"
  // (enkelkorts-/värddator-läge, Fas 13). Se pkg/config/model.go.
  final String mode;
  // rollbackTimeoutSec och allowedManagementLan fanns i agentens
  // Settings-struct men SAKNADES här. Eftersom GUI:t läser hela configen och
  // skriver tillbaka den vid varje sparning innebar det att fälten TYST
  // nollställdes varje gång någon ändrade något i gränssnittet — för
  // allowed_management_lan (IP-begränsningen för management-API:t) är det en
  // säkerhetsregression, inte bara en förlorad inställning. Upptäckt vid
  // kodgranskning 2026-08-25.
  final int rollbackTimeoutSec;
  final List<String> allowedManagementLan;
  /// Serverns tidszon i IANA-format. Tomt = rör inte systemets nuvarande
  /// inställning. Måste ligga med här av samma skäl som fälten ovan: GUI:t
  /// skriver tillbaka HELA configen vid varje sparning, så ett fält som
  /// saknas i modellen nollställs tyst på servern.
  final String timezone;

  SettingsModel({
    required this.hostname,
    required this.apiPort,
    this.mode = '',
    this.rollbackTimeoutSec = 30,
    this.allowedManagementLan = const [],
    this.timezone = '',
  });

  bool get isHostMode => mode == 'host';

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      hostname: json['hostname'] ?? 'security-harbor',
      apiPort: json['api_port'] ?? 8443,
      mode: json['mode'] ?? '',
      rollbackTimeoutSec: json['rollback_timeout_sec'] ?? 30,
      allowedManagementLan: List<String>.from(json['allowed_management_lan'] ?? const []),
      timezone: json['timezone'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'hostname': hostname,
        'api_port': apiPort,
        'mode': mode,
        'rollback_timeout_sec': rollbackTimeoutSec,
        'allowed_management_lan': allowedManagementLan,
        'timezone': timezone,
      };

  SettingsModel copyWith({String? hostname, int? apiPort, String? mode, int? rollbackTimeoutSec, List<String>? allowedManagementLan, String? timezone}) =>
      SettingsModel(
        hostname: hostname ?? this.hostname,
        apiPort: apiPort ?? this.apiPort,
        mode: mode ?? this.mode,
        rollbackTimeoutSec: rollbackTimeoutSec ?? this.rollbackTimeoutSec,
        allowedManagementLan: allowedManagementLan ?? this.allowedManagementLan,
        timezone: timezone ?? this.timezone,
      );
}

/// En regel som agenten genererar själv och som inte finns som Policy.
/// Visas som en låst rad i Policies — allt som släpper in trafik ska gå att
/// se i gränssnittet.
/// Brandväggen som NTP-server för de interna näten.
class NTPConfigModel {
  final bool enabled;
  final bool serveWhenUnsynced;

  NTPConfigModel({this.enabled = false, this.serveWhenUnsynced = true});

  factory NTPConfigModel.fromJson(Map<String, dynamic> json) => NTPConfigModel(
        enabled: json['enabled'] ?? false,
        serveWhenUnsynced: json['serve_when_unsynced'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'serve_when_unsynced': serveWhenUnsynced,
      };

  NTPConfigModel copyWith({bool? enabled, bool? serveWhenUnsynced}) => NTPConfigModel(
        enabled: enabled ?? this.enabled,
        serveWhenUnsynced: serveWhenUnsynced ?? this.serveWhenUnsynced,
      );
}

class ImplicitRuleModel {
  final String name;
  final String chain;
  final String action;
  final String service;
  final String from;
  final String to;
  final bool logged;
  final String reason;

  ImplicitRuleModel({
    required this.name,
    required this.chain,
    required this.action,
    required this.service,
    required this.from,
    required this.to,
    required this.logged,
    required this.reason,
  });

  factory ImplicitRuleModel.fromJson(Map<String, dynamic> json) => ImplicitRuleModel(
        name: json['name'] ?? '',
        chain: json['chain'] ?? '',
        action: json['action'] ?? 'accept',
        service: json['service'] ?? 'ANY',
        from: json['from'] ?? '',
        to: json['to'] ?? 'SELF',
        logged: json['logged'] ?? false,
        reason: json['reason'] ?? '',
      );
}

class ConntrackModel {
  final String protocol;
  final String srcIp;
  final int srcPort;
  final String dstIp;
  final int dstPort;
  final String state;
  final String srcMac;
  // Endast ifyllt om målet är en direktansluten LAN-enhet (slås upp via
  // brandväggens ARP-tabell, precis som srcMac) — tomt för WAN-mål.
  final String dstMac;

  ConntrackModel({
    required this.protocol,
    required this.srcIp,
    required this.srcPort,
    required this.dstIp,
    required this.dstPort,
    required this.state,
    this.srcMac = '',
    this.dstMac = '',
  });

  factory ConntrackModel.fromJson(Map<String, dynamic> json) {
    return ConntrackModel(
      protocol: json['protocol'] ?? '',
      srcIp: json['src_ip'] ?? '',
      srcPort: json['src_port'] ?? 0,
      dstIp: json['dst_ip'] ?? '',
      dstPort: json['dst_port'] ?? 0,
      state: json['state'] ?? '',
      srcMac: json['src_mac'] ?? '',
      dstMac: json['dst_mac'] ?? '',
    );
  }
}

/// Representerar EN loggad paket-händelse (både tillåten OCH nekad, se
/// action) ur brandväggens kärnlogg (nftables "log"-regler, se
/// SH-ACCEPT-*/SH-DENY-*-prefixen i agenten). policyName är namnet på
/// den regel som fattade beslutet, uttaget ur själva log-prefixet.
class FirewallLogModel {
  final String timestamp;
  final String action; // "accept" eller "deny"
  final String chain; // "INPUT" eller "FWD"
  final String policyName;
  final String inIface;
  final String outIface;
  final String srcMac;
  final String dstMac;
  final String srcIp;
  final String dstIp;
  final String protocol;
  final int srcPort;
  final int dstPort;

  FirewallLogModel({
    required this.timestamp,
    this.action = 'deny',
    required this.chain,
    this.policyName = '',
    required this.inIface,
    required this.outIface,
    required this.srcMac,
    this.dstMac = '',
    required this.srcIp,
    required this.dstIp,
    required this.protocol,
    required this.srcPort,
    required this.dstPort,
  });

  factory FirewallLogModel.fromJson(Map<String, dynamic> json) {
    return FirewallLogModel(
      timestamp: json['timestamp'] ?? '',
      action: json['action'] ?? 'deny',
      chain: json['chain'] ?? '',
      policyName: json['policy_name'] ?? '',
      inIface: json['in_iface'] ?? '',
      outIface: json['out_iface'] ?? '',
      srcMac: json['src_mac'] ?? '',
      dstMac: json['dst_mac'] ?? '',
      srcIp: json['src_ip'] ?? '',
      dstIp: json['dst_ip'] ?? '',
      protocol: json['protocol'] ?? '',
      srcPort: json['src_port'] ?? 0,
      dstPort: json['dst_port'] ?? 0,
    );
  }
}

/// Ett larm från Suricata (Fas 9), utplockat ur eve.json. Se
/// pkg/config/model.go:SecurityEvent.
class SecurityEventModel {
  final String timestamp;
  final int severity; // 1 (högst) - 3 (lägst)
  final String signature;
  /// Suricatas signatur-ID. 0 om larmet saknar det (äldre agentversioner).
  /// Nyckeln som skickas till POST /api/v1/ids/rules för att tysta signaturen.
  final int sid;
  final String category;
  final String srcIp;
  final int srcPort;
  final String dstIp;
  final int dstPort;
  final String protocol;

  SecurityEventModel({
    required this.timestamp,
    required this.severity,
    required this.signature,
    this.sid = 0,
    this.category = '',
    required this.srcIp,
    this.srcPort = 0,
    required this.dstIp,
    this.dstPort = 0,
    this.protocol = '',
  });

  factory SecurityEventModel.fromJson(Map<String, dynamic> json) {
    return SecurityEventModel(
      timestamp: json['timestamp'] ?? '',
      severity: json['severity'] ?? 3,
      signature: json['signature'] ?? '',
      sid: json['sid'] ?? 0,
      category: json['category'] ?? '',
      srcIp: json['src_ip'] ?? '',
      srcPort: json['src_port'] ?? 0,
      dstIp: json['dst_ip'] ?? '',
      dstPort: json['dst_port'] ?? 0,
      protocol: json['protocol'] ?? '',
    );
  }
}

/// En punkt i en trafiktidsserie. Rx = nedladdat, Tx = uppladdat, alltid sett
/// ur ENHETENS perspektiv — inte brandväggens.
class TrafficPointModel {
  final int timestamp;
  final int rx;
  final int tx;

  TrafficPointModel({required this.timestamp, required this.rx, required this.tx});

  factory TrafficPointModel.fromJson(Map<String, dynamic> j) => TrafficPointModel(
        timestamp: j['t'] ?? 0,
        rx: j['rx'] ?? 0,
        tx: j['tx'] ?? 0,
      );
}

/// En enhet i dashboardens tabell.
class DeviceStatModel {
  final String ip;
  final String mac;
  final String hostname;
  final String vendor;
  final String interfaceName;
  final String zone;
  final bool online;

  /// MAC-adressens lokalt-administrerade bit är satt — nästan alltid en modern
  /// mobil eller laptop med integritetsskydd. En upplysning, inte ett påstående
  /// om anslutningstyp: brandväggen kan inte se skillnad på wifi och kabel.
  final bool randomizedMac;

  final int firstSeen;
  final int lastSeen;

  /// Ögonblicksbandbredd i byte per sekund.
  final int rxBps;
  final int txBps;

  /// Totalt under det valda fönstret.
  final int rxBytes;
  final int txBytes;

  final int blockedConnections;
  final int idsAlerts;
  final bool isNew;
  final List<TrafficPointModel> sparkline;

  DeviceStatModel({
    required this.ip,
    this.mac = '',
    this.hostname = '',
    this.vendor = '',
    this.interfaceName = '',
    this.zone = '',
    this.online = false,
    this.randomizedMac = false,
    this.firstSeen = 0,
    this.lastSeen = 0,
    this.rxBps = 0,
    this.txBps = 0,
    this.rxBytes = 0,
    this.txBytes = 0,
    this.blockedConnections = 0,
    this.idsAlerts = 0,
    this.isNew = false,
    this.sparkline = const [],
  });

  /// Namnet som visas: värdnamn om DHCP gav ett, annars tillverkare, annars IP.
  String get displayName {
    if (hostname.isNotEmpty) return hostname;
    if (vendor.isNotEmpty) return vendor;
    return ip;
  }

  factory DeviceStatModel.fromJson(Map<String, dynamic> j) => DeviceStatModel(
        ip: j['ip'] ?? '',
        mac: j['mac'] ?? '',
        hostname: j['hostname'] ?? '',
        vendor: j['vendor'] ?? '',
        interfaceName: j['interface'] ?? '',
        zone: j['zone'] ?? '',
        online: j['online'] ?? false,
        randomizedMac: j['randomized_mac'] ?? false,
        firstSeen: j['first_seen'] ?? 0,
        lastSeen: j['last_seen'] ?? 0,
        rxBps: j['rx_bps'] ?? 0,
        txBps: j['tx_bps'] ?? 0,
        rxBytes: j['rx_bytes'] ?? 0,
        txBytes: j['tx_bytes'] ?? 0,
        blockedConnections: j['blocked_connections'] ?? 0,
        idsAlerts: j['ids_alerts'] ?? 0,
        isNew: j['is_new'] ?? false,
        sparkline: ((j['sparkline'] ?? []) as List)
            .map((e) => TrafficPointModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Svaret från GET /api/v1/dashboard/devices.
class DashboardDataModel {
  final List<DeviceStatModel> devices;

  /// Summa per zon, så man ser vilket nätsegment som drar mest.
  final Map<String, TrafficPointModel> zones;

  final int totalRx;
  final int totalTx;
  final int totalRxBps;
  final int totalTxBps;
  final String resolution;
  final int sampledAt;

  DashboardDataModel({
    required this.devices,
    required this.zones,
    required this.totalRx,
    required this.totalTx,
    required this.totalRxBps,
    required this.totalTxBps,
    required this.resolution,
    required this.sampledAt,
  });

  factory DashboardDataModel.fromJson(Map<String, dynamic> j) {
    final zonesRaw = (j['zones'] ?? {}) as Map<String, dynamic>;
    final totals = (j['totals'] ?? {}) as Map<String, dynamic>;
    return DashboardDataModel(
      devices: ((j['devices'] ?? []) as List)
          .map((e) => DeviceStatModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      zones: zonesRaw.map((k, v) =>
          MapEntry(k, TrafficPointModel.fromJson(v as Map<String, dynamic>))),
      totalRx: totals['rx'] ?? 0,
      totalTx: totals['tx'] ?? 0,
      totalRxBps: j['total_rx_bps'] ?? 0,
      totalTxBps: j['total_tx_bps'] ?? 0,
      resolution: j['resolution'] ?? '5m',
      sampledAt: j['sampled_at'] ?? 0,
    );
  }
}

/// En Suricata-regelkategori, härledd ur regelns msg-prefix ("ET MALWARE",
/// "GPL ATTACK_RESPONSE", "SURICATA"). ET Open levereras som EN sammanslagen
/// regelfil, så det finns ingen filstruktur att gruppera på — prefixet är det
/// som faktiskt bär betydelse för en människa.
class IdsCategoryModel {
  final String name;

  /// Regler i kategorin totalt, oavsett status.
  final int total;

  /// Aktiva regler enligt regelfilen just nu. Avstängda regler tas inte bort
  /// av suricata-update utan kommenteras ut, så [enabled] kan vara mindre än
  /// [total] även för en kategori som inte är avstängd här — ET Open levererar
  /// en hel del regler avstängda från början.
  final int enabled;

  /// Speglar konfigurationen, INTE regelfilen. Efter en ändring tar det
  /// ~40–60 s innan suricata-update skrivit om filen, och vyn ska visa
  /// användarens val direkt.
  final bool disabled;

  IdsCategoryModel({
    required this.name,
    required this.total,
    required this.enabled,
    required this.disabled,
  });

  factory IdsCategoryModel.fromJson(Map<String, dynamic> json) => IdsCategoryModel(
        name: json['name'] ?? '',
        total: json['total'] ?? 0,
        enabled: json['enabled'] ?? 0,
        disabled: json['disabled'] ?? false,
      );
}

/// En enskild tystad signatur.
class IdsDisabledSignatureModel {
  final int sid;
  final String signature;
  final String disabledAt;

  IdsDisabledSignatureModel({
    required this.sid,
    this.signature = '',
    this.disabledAt = '',
  });

  factory IdsDisabledSignatureModel.fromJson(Map<String, dynamic> json) =>
      IdsDisabledSignatureModel(
        sid: json['sid'] ?? 0,
        signature: json['signature'] ?? '',
        disabledAt: json['disabled_at'] ?? '',
      );
}

/// Svaret från GET /api/v1/ids/rules.
class IdsRulesModel {
  final List<IdsCategoryModel> categories;
  final List<IdsDisabledSignatureModel> disabledSignatures;

  /// "activating"/"active" = regeluppdateringen pågår, "inactive" = klar,
  /// "failed" = misslyckades.
  final String updateStatus;

  IdsRulesModel({
    required this.categories,
    required this.disabledSignatures,
    required this.updateStatus,
  });

  bool get isUpdating => updateStatus == 'activating' || updateStatus == 'active';

  factory IdsRulesModel.fromJson(Map<String, dynamic> json) => IdsRulesModel(
        categories: ((json['categories'] ?? []) as List)
            .map((e) => IdsCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        disabledSignatures: ((json['disabled_signatures'] ?? []) as List)
            .map((e) => IdsDisabledSignatureModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        updateStatus: json['update_status'] ?? 'unknown',
      );
}

/// En aktiv DHCP-utlåning (Kea) berikad med gränssnitt/zon — se
/// /api/v1/dhcp/leases i backend (Engine.GetDHCPLeases). WAN utesluts där.
class DhcpLeaseModel {
  final String ip;
  final String mac;
  final String hostname;
  final int startTs; // när leasen gavs, unix-sekunder, 0 = okänt
  final int expireTs; // när leasen går ut, unix-sekunder, 0 = okänt
  final String interfaceDevice;
  final String zone;

  DhcpLeaseModel({
    required this.ip,
    required this.mac,
    required this.hostname,
    required this.startTs,
    required this.expireTs,
    required this.interfaceDevice,
    required this.zone,
  });

  factory DhcpLeaseModel.fromJson(Map<String, dynamic> json) => DhcpLeaseModel(
        ip: json['ip'] ?? '',
        mac: json['mac'] ?? '',
        hostname: json['hostname'] ?? '',
        startTs: json['start_ts'] ?? 0,
        expireTs: json['expire_ts'] ?? 0,
        interfaceDevice: json['interface'] ?? '',
        zone: json['zone'] ?? '',
      );
}

/// Status för EN systemd-tjänst agenten hanterar (se pkg/api/services.go).
/// Live status, inte en del av den deklarativa configen — hämtas separat
/// via ApiService.getServicesStatus().
class ServiceStatusModel {
  final String id;
  final String name;
  final String description;
  final String unit;
  final String active; // ActiveState: active, inactive, failed, activating, ...
  final String sub; // SubState: running, dead, exited, ...
  // configured = funktionen är påslagen i brandväggens konfiguration, till
  // skillnad från active som bara speglar systemd. rsyslog är systemets
  // ordinarie logghanterare och körs ALLTID — utan det här fältet såg
  // Tjänstepanelen ut att påstå att syslog-vidarebefordran var aktiv trots
  // att den var avstängd i inställningarna.
  final bool configured;

  ServiceStatusModel({
    required this.id,
    required this.name,
    required this.description,
    required this.unit,
    required this.active,
    required this.sub,
    this.configured = true,
  });

  factory ServiceStatusModel.fromJson(Map<String, dynamic> json) => ServiceStatusModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        unit: json['unit'] ?? '',
        active: json['active'] ?? 'unknown',
        configured: json['configured'] ?? true,
        sub: json['sub'] ?? 'unknown',
      );
}
