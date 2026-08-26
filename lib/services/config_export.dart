/// Spara en genererad klientkonfiguration till fil.
///
/// VPN-konfigurationer visades bara som text att markera och kopiera. En
/// OpenVPN-klient vill ha en riktig `.ovpn`-fil, och att klistra in text i en
/// editor och spara den med rätt filändelse är ett onödigt steg som dessutom
/// lätt går fel (radbrytningar, inline-certifikat).
///
/// Plattformarna sparar på olika sätt — webbläsaren laddar ner, desktop och
/// mobil skriver till disk — så implementationen väljs vid kompilering, samma
/// mönster som http_client_factory.
library;

export 'config_export_web.dart' if (dart.library.io) 'config_export_io.dart';
