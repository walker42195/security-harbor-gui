// Desktop-appens självuppdatering. Väljer implementation vid kompilering:
// den riktiga `dart:io`-varianten på desktop, en no-op-stub i en web-build
// (webb-GUI:t uppdateras i stället via agenten, se Settings-kortet). Samma
// mönster som tls_trust.dart.
export 'update_service_stub.dart' if (dart.library.io) 'update_service_io.dart';
