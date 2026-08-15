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
      revision: json['revision'] ?? 1,
      updatedAt: json['updated_at'] ?? '',
      interfaces: (json['interfaces'] as List? ?? [])
          .map((i) => InterfaceModel.fromJson(i))
          .toList(),
      zones: (json['zones'] as List? ?? [])
          .map((z) => ZoneModel.fromJson(z))
          .toList(),
      objects: (json['objects'] as List? ?? [])
          .map((o) => ObjectModel.fromJson(o))
          .toList(),
      services: (json['services'] as List? ?? [])
          .map((s) => ServiceModel.fromJson(s))
          .toList(),
      policies: (json['policies'] as List? ?? [])
          .map((p) => PolicyModel.fromJson(p))
          .toList(),
      settings: SettingsModel.fromJson(json['settings'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'revision': revision,
        'updated_at': updatedAt,
        'interfaces': interfaces.map((i) => i.toJson()).toList(),
        'zones': zones.map((z) => z.toJson()).toList(),
        'objects': objects.map((o) => o.toJson()).toList(),
        'services': services.map((s) => s.toJson()).toList(),
        'policies': policies.map((p) => p.toJson()).toList(),
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
  final int mtu;

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
    this.mtu = 1500,
  });

  factory InterfaceModel.fromJson(Map<String, dynamic> json) => InterfaceModel(
        id: json['id'] ?? '',
        device: json['device'] ?? '',
        parent: json['parent'] ?? '',
        vlanId: json['vlan_id'] ?? 0,
        zone: json['zone'] ?? 'LAN',
        enabled: json['enabled'] ?? true,
        addressType: json['address_type'] ?? 'static',
        ipv4: json['ipv4'] ?? '',
        gateway: json['gateway'] ?? '',
        mtu: json['mtu'] ?? 1500,
      );

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
        'mtu': mtu,
      };
}

class ZoneModel {
  final String name;
  final String description;

  ZoneModel({required this.name, required this.description});

  factory ZoneModel.fromJson(Map<String, dynamic> json) => ZoneModel(
        name: json['name'] ?? '',
        description: json['description'] ?? '',
      );

  Map<String, dynamic> toJson() => {'name': name, 'description': description};
}

class ObjectModel {
  final String id;
  final String name;
  final String type;
  final List<String> values;
  final String description;

  ObjectModel({
    required this.id,
    required this.name,
    required this.type,
    required this.values,
    required this.description,
  });

  factory ObjectModel.fromJson(Map<String, dynamic> json) => ObjectModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        type: json['type'] ?? 'host',
        values: List<String>.from(json['values'] ?? []),
        description: json['description'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'values': values,
        'description': description,
      };
}

class ServiceModel {
  final String id;
  final String name;
  final String protocol;
  final List<String> ports;
  final String description;

  ServiceModel({
    required this.id,
    required this.name,
    required this.protocol,
    required this.ports,
    required this.description,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) => ServiceModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        protocol: json['protocol'] ?? 'tcp',
        ports: List<String>.from(json['ports'] ?? []),
        description: json['description'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol,
        'ports': ports,
        'description': description,
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
  final bool logging;
  final String description;

  PolicyModel({
    required this.id,
    required this.name,
    required this.enabled,
    required this.priority,
    required this.sourceZone,
    required this.destZone,
    required this.sourceObj,
    required this.destObj,
    required this.service,
    required this.action,
    required this.logging,
    required this.description,
  });

  factory PolicyModel.fromJson(Map<String, dynamic> json) => PolicyModel(
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
        logging: json['logging'] ?? true,
        description: json['description'] ?? '',
      );

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
        'logging': logging,
        'description': description,
      };
}

class SettingsModel {
  final String hostName;
  final int apiPort;
  final int rollbackTimeoutSec;

  SettingsModel({
    required this.hostName,
    required this.apiPort,
    required this.rollbackTimeoutSec,
  });

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
        hostName: json['hostname'] ?? 'security-harbor',
        apiPort: json['api_port'] ?? 8443,
        rollbackTimeoutSec: json['rollback_timeout_sec'] ?? 30,
      );

  Map<String, dynamic> toJson() => {
        'hostname': hostName,
        'api_port': apiPort,
        'rollback_timeout_sec': rollbackTimeoutSec,
      };
}
