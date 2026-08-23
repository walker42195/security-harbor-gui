// Web-varianten av update_service — desktop-självuppdatering är inte
// tillämplig i en webbläsare (webb-GUI:t uppdateras via agenten). Dessa
// no-ops finns bara så att `dart:io`-importen i update_service_io.dart aldrig
// kompileras in i en web-build.
import 'update_types.dart';

const bool desktopUpdateSupported = false;

Future<DesktopUpdate?> checkDesktopUpdate() async => null;

Future<String?> downloadDesktopUpdate(DesktopUpdate update) async =>
    'Desktop-uppdatering stöds inte i webbläsaren';

Future<String?> applyDesktopUpdate() async =>
    'Desktop-uppdatering stöds inte i webbläsaren';
