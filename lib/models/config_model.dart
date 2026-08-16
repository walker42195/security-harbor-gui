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
    );
  }

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
      };
}

class InterfaceModel {
  final String id;
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
  final DHCPConfigModel? dhcp;

  InterfaceModel({
    required this.id,
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
    this.dhcp,
  });

  factory InterfaceModel.fromJson(Map<String, dynamic> json) {
    return InterfaceModel(
      id: json['id'] ?? '',
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
      dhcp: json['dhcp'] != null ? DHCPConfigModel.fromJson(json['dhcp']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
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
        if (dhcp != null) 'dhcp': dhcp!.toJson(),
      };
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

  ObjectModel({required this.id, required this.name, required this.type, required this.values, required this.description});

  factory ObjectModel.fromJson(Map<String, dynamic> json) {
    return ObjectModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'host',
      values: List<String>.from(json['values'] ?? []),
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type, 'values': values, 'description': description};
}

class ServiceModel {
  final String id;
  final String name;
  final String protocol;
  final List<String> ports;
  final String description;

  ServiceModel({required this.id, required this.name, required this.protocol, required this.ports, required this.description});

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      protocol: json['protocol'] ?? 'tcp',
      ports: List<String>.from(json['ports'] ?? []),
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'protocol': protocol, 'ports': ports, 'description': description};
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
      };
}

class NATConfigModel {
  final int externalPort;
  final String internalIp;
  final int internalPort;
  final String protocol;

  NATConfigModel({required this.externalPort, required this.internalIp, required this.internalPort, required this.protocol});

  factory NATConfigModel.fromJson(Map<String, dynamic> json) {
    return NATConfigModel(
      externalPort: json['external_port'] ?? 0,
      internalIp: json['internal_ip'] ?? '',
      internalPort: json['internal_port'] ?? 0,
      protocol: json['protocol'] ?? 'tcp',
    );
  }

  Map<String, dynamic> toJson() => {
        'external_port': externalPort,
        'internal_ip': internalIp,
        'internal_port': internalPort,
        'protocol': protocol,
      };
}

class SettingsModel {
  final String hostname;
  final int apiPort;

  SettingsModel({required this.hostname, required this.apiPort});

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      hostname: json['hostname'] ?? 'security-harbor',
      apiPort: json['api_port'] ?? 8443,
    );
  }

  Map<String, dynamic> toJson() => {'hostname': hostname, 'api_port': apiPort};
}

class ConntrackModel {
  final String protocol;
  final String srcIp;
  final int srcPort;
  final String dstIp;
  final int dstPort;
  final String state;

  ConntrackModel({
    required this.protocol,
    required this.srcIp,
    required this.srcPort,
    required this.dstIp,
    required this.dstPort,
    required this.state,
  });

  factory ConntrackModel.fromJson(Map<String, dynamic> json) {
    return ConntrackModel(
      protocol: json['protocol'] ?? '',
      srcIp: json['src_ip'] ?? '',
      srcPort: json['src_port'] ?? 0,
      dstIp: json['dst_ip'] ?? '',
      dstPort: json['dst_port'] ?? 0,
      state: json['state'] ?? '',
    );
  }
}
