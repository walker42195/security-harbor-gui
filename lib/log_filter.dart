/// Filteruttryck för trafikloggen — samma sätt att skriva som i Check Points
/// SmartConsole.
///
/// Loggvyn hade tidigare bara separata "innehåller"-fält (IP, MAC, namn) och
/// gick aldrig att skriva ett undantag i: vill man se allt UTOM DNS, eller
/// allt från ett nät utom en värd, fanns det ingen väg alls. Det här är den
/// vägen.
///
/// Exempel:
///
///     src:10.0.0.5                     trafik från en värd
///     src:10.9.9.0/24 and dst:8.8.8.8  nät → värd (CIDR stöds)
///     not port:53                      allt UTOM DNS
///     action:deny and not rule:DefaultDeny
///     (src:10.0.0.5 or src:10.0.0.6) and not dport:443
///     10.0.0.5                         fritext: matchar radens alla fält
///
/// Operatorerna är `and`, `or`, `not` (även `&&`, `||`, `!`, och `-` som
/// prefix). Utelämnad operator mellan två termer betyder `and`, precis som i
/// Check Point. Skiftläge spelar ingen roll, varken för operatorer,
/// fältnamn eller värden.
library;

/// Fälten ett filter kan fråga på. Nycklarna är de kanoniska namnen; kartan
/// [fieldAliases] mappar det användaren skriver till dem.
///
/// Värdet är en LISTA eftersom ett fält kan ha flera representationer som
/// alla ska kunna matchas — `src` matchar både IP-adressen och namnet på det
/// objekt adressen tillhör, så `src:Skrivare` fungerar lika bra som
/// `src:10.0.0.50`.
typedef LogRowFields = Map<String, List<String>>;

/// Fältnamn användaren kan skriva → kanoniskt namn. Både svenska och engelska
/// former finns med: GUI:t är tvåspråkigt, och ett filter man skrivit i det
/// ena språket ska inte sluta fungera för att man byter.
const Map<String, String> fieldAliases = {
  'src': 'src', 'source': 'src', 'from': 'src', 'källa': 'src', 'kalla': 'src',
  'dst': 'dst', 'dest': 'dst', 'destination': 'dst', 'to': 'dst', 'mål': 'dst', 'mal': 'dst',
  'ip': 'ip', 'host': 'ip', 'värd': 'ip', 'vard': 'ip',
  'sport': 'sport', 'srcport': 'sport',
  'dport': 'dport', 'dstport': 'dport',
  'port': 'port',
  'proto': 'proto', 'protocol': 'proto', 'protokoll': 'proto',
  'action': 'action', 'åtgärd': 'action', 'atgard': 'action',
  'rule': 'rule', 'policy': 'rule', 'regel': 'rule',
  'mac': 'mac',
  'srcmac': 'srcmac', 'dstmac': 'dstmac',
  'in': 'in', 'iif': 'in',
  'out': 'out', 'oif': 'out',
  'iface': 'iface', 'interface': 'iface', 'gränssnitt': 'iface', 'granssnitt': 'iface',
  'dir': 'dir', 'direction': 'dir', 'riktning': 'dir',
};

/// Fält som är sammansatta av flera andra — `port` träffar både käll- och
/// målport, `ip` både källa och mål. Det är den vanligaste frågan ("visa allt
/// som rör den här adressen"), och att behöva skriva `src:x or dst:x` varje
/// gång vore onödigt.
const Map<String, List<String>> _compositeFields = {
  'ip': ['src', 'dst'],
  'port': ['sport', 'dport'],
  'mac': ['srcmac', 'dstmac'],
  'iface': ['in', 'out'],
};

/// Ett tolkat filter. [matches] körs en gång per loggrad.
abstract class LogFilter {
  const LogFilter();

  bool matches(LogRowFields row);

  /// Tolkar ett uttryck. Kastar [LogFilterException] vid syntaxfel, så
  /// anroparen kan visa felet i stället för att tyst filtrera bort allt.
  ///
  /// Ett tomt uttryck ger [always], dvs. "visa allt" — inte "visa inget".
  static LogFilter parse(String input) {
    final tokens = _tokenize(input);
    if (tokens.isEmpty) return always;
    final parser = _Parser(tokens);
    final expr = parser.parseExpression();
    if (!parser.atEnd) {
      throw LogFilterException('Oväntat "${parser.peek().text}"');
    }
    return expr;
  }

  /// Matchar allt. Används för tomt uttryck.
  static const LogFilter always = _Always();
}

class LogFilterException implements Exception {
  final String message;
  const LogFilterException(this.message);
  @override
  String toString() => message;
}

class _Always extends LogFilter {
  const _Always();
  @override
  bool matches(LogRowFields row) => true;
}

class _Not extends LogFilter {
  final LogFilter inner;
  const _Not(this.inner);
  @override
  bool matches(LogRowFields row) => !inner.matches(row);
}

class _And extends LogFilter {
  final List<LogFilter> parts;
  const _And(this.parts);
  @override
  bool matches(LogRowFields row) => parts.every((p) => p.matches(row));
}

class _Or extends LogFilter {
  final List<LogFilter> parts;
  const _Or(this.parts);
  @override
  bool matches(LogRowFields row) => parts.any((p) => p.matches(row));
}

/// En enskild term: `fält:värde`, eller bara `värde` (fritext över alla fält).
class _Term extends LogFilter {
  final String? field; // null = fritext
  final String value;

  const _Term(this.field, this.value);

  @override
  bool matches(LogRowFields row) {
    if (field == null) {
      return row.values.any((values) => values.any((v) => _valueMatches(v, value)));
    }
    for (final name in _expand(field!)) {
      final values = row[name];
      if (values == null) continue;
      if (values.any((v) => _valueMatches(v, value))) return true;
    }
    return false;
  }

  static List<String> _expand(String field) => _compositeFields[field] ?? [field];
}

/// Jämför ett radvärde med ett filtervärde.
///
/// Tre nivåer, i tur och ordning:
///
///  1. CIDR (`10.9.9.0/24`) — matchar om radens IP ligger i nätet. Utan detta
///     vore ett brandväggsfilter halvt oanvändbart; man tänker i nät.
///  2. Exakt tal — portar. `port:80` ska INTE träffa 8080, vilket en ren
///     substrängsmatchning hade gjort.
///  3. Substräng, skiftlägesokänsligt — allt annat (namn, protokoll, MAC).
bool _valueMatches(String rowValue, String filterValue) {
  if (rowValue.isEmpty) return false;

  if (filterValue.contains('/')) {
    final inCidr = _ipInCidr(rowValue, filterValue);
    if (inCidr != null) return inCidr;
  }

  final asNumber = int.tryParse(filterValue);
  if (asNumber != null) {
    final rowNumber = int.tryParse(rowValue);
    if (rowNumber != null) return rowNumber == asNumber;
  }

  return rowValue.toLowerCase().contains(filterValue.toLowerCase());
}

/// Returnerar null om något av argumenten inte är en giltig IPv4/CIDR — då
/// faller anroparen tillbaka på vanlig textmatchning i stället för att tyst
/// svara "nej".
bool? _ipInCidr(String ip, String cidr) {
  final parts = cidr.split('/');
  if (parts.length != 2) return null;
  final base = _ipToInt(parts[0]);
  final target = _ipToInt(ip);
  final prefix = int.tryParse(parts[1]);
  if (base == null || target == null || prefix == null || prefix < 0 || prefix > 32) {
    return null;
  }
  if (prefix == 0) return true;
  final mask = (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
  return (base & mask) == (target & mask);
}

int? _ipToInt(String ip) {
  final octets = ip.split('.');
  if (octets.length != 4) return null;
  var result = 0;
  for (final o in octets) {
    final v = int.tryParse(o);
    if (v == null || v < 0 || v > 255) return null;
    result = (result << 8) | v;
  }
  return result;
}

// ---------------------------------------------------------------------------
// Tokenisering och parsning
// ---------------------------------------------------------------------------

enum _TokenType { word, and, or, not, lparen, rparen }

class _Token {
  final _TokenType type;
  final String text;
  /// True om ordet stod inom citattecken. Ett citerat ord är ALLTID ett värde,
  /// aldrig en operator — annars gick det inte att söka efter en regel som
  /// faktiskt heter "not" eller "and".
  final bool quoted;
  const _Token(this.type, this.text, {this.quoted = false});
}

List<_Token> _tokenize(String input) {
  final tokens = <_Token>[];
  var i = 0;

  while (i < input.length) {
    final c = input[i];

    if (c.trim().isEmpty) {
      i++;
      continue;
    }
    if (c == '(') {
      tokens.add(const _Token(_TokenType.lparen, '('));
      i++;
      continue;
    }
    if (c == ')') {
      tokens.add(const _Token(_TokenType.rparen, ')'));
      i++;
      continue;
    }
    if (c == '!') {
      tokens.add(const _Token(_TokenType.not, '!'));
      i++;
      continue;
    }
    // `-` är NOT bara som fristående prefix. Mitt i ett ord är det ett
    // vanligt tecken (MAC-adresser, regelnamn som "LAN-till-WAN").
    if (c == '-' && (tokens.isEmpty || _startsOperand(tokens.last)) && i + 1 < input.length && input[i + 1].trim().isNotEmpty) {
      tokens.add(const _Token(_TokenType.not, '-'));
      i++;
      continue;
    }
    if (input.startsWith('&&', i)) {
      tokens.add(const _Token(_TokenType.and, '&&'));
      i += 2;
      continue;
    }
    if (input.startsWith('||', i)) {
      tokens.add(const _Token(_TokenType.or, '||'));
      i += 2;
      continue;
    }

    final (text, quoted, next) = _readWord(input, i);
    i = next;
    if (text.isEmpty) continue;

    if (!quoted) {
      switch (text.toLowerCase()) {
        case 'and':
          tokens.add(_Token(_TokenType.and, text));
          continue;
        case 'or':
          tokens.add(_Token(_TokenType.or, text));
          continue;
        case 'not':
          tokens.add(_Token(_TokenType.not, text));
          continue;
      }
    }
    tokens.add(_Token(_TokenType.word, text, quoted: quoted));
  }
  return tokens;
}

/// True om nästa token skulle inleda en operand — dvs. om ett `-` här är ett
/// NOT-prefix och inte ett bindestreck i ett värde.
bool _startsOperand(_Token previous) {
  switch (previous.type) {
    case _TokenType.word:
    case _TokenType.rparen:
      return false;
    case _TokenType.and:
    case _TokenType.or:
    case _TokenType.not:
    case _TokenType.lparen:
      return true;
  }
}

/// Läser ett ord, som kan innehålla ett citerat värde efter kolon
/// (`rule:"LAN till WAN"`) eller vara citerat i sin helhet.
(String, bool, int) _readWord(String input, int start) {
  final buffer = StringBuffer();
  var i = start;
  var sawQuote = false;

  while (i < input.length) {
    final c = input[i];
    if (c == '"' || c == "'") {
      final quote = c;
      sawQuote = true;
      i++;
      while (i < input.length && input[i] != quote) {
        buffer.write(input[i]);
        i++;
      }
      if (i >= input.length) {
        throw LogFilterException('Citattecken saknar avslutning');
      }
      i++; // hoppa över det avslutande citattecknet
      continue;
    }
    if (c.trim().isEmpty || c == '(' || c == ')') break;
    if (input.startsWith('&&', i) || input.startsWith('||', i)) break;
    buffer.write(c);
    i++;
  }
  return (buffer.toString(), sawQuote, i);
}

class _Parser {
  final List<_Token> tokens;
  int pos = 0;
  _Parser(this.tokens);

  bool get atEnd => pos >= tokens.length;
  _Token peek() => tokens[pos];

  LogFilter parseExpression() => _parseOr();

  LogFilter _parseOr() {
    final parts = [_parseAnd()];
    while (!atEnd && peek().type == _TokenType.or) {
      pos++;
      parts.add(_parseAnd());
    }
    return parts.length == 1 ? parts.first : _Or(parts);
  }

  LogFilter _parseAnd() {
    final parts = [_parseUnary()];
    while (!atEnd) {
      if (peek().type == _TokenType.and) {
        pos++;
        parts.add(_parseUnary());
        continue;
      }
      // Underförstådd AND: två termer efter varandra utan operator, precis
      // som i Check Point.
      if (peek().type == _TokenType.word ||
          peek().type == _TokenType.not ||
          peek().type == _TokenType.lparen) {
        parts.add(_parseUnary());
        continue;
      }
      break;
    }
    return parts.length == 1 ? parts.first : _And(parts);
  }

  LogFilter _parseUnary() {
    if (atEnd) throw const LogFilterException('Uttrycket slutar oväntat');
    final token = peek();

    if (token.type == _TokenType.not) {
      pos++;
      return _Not(_parseUnary());
    }
    if (token.type == _TokenType.lparen) {
      pos++;
      final inner = parseExpression();
      if (atEnd || peek().type != _TokenType.rparen) {
        throw const LogFilterException('Parentes saknar avslutning');
      }
      pos++;
      return inner;
    }
    if (token.type != _TokenType.word) {
      throw LogFilterException('Oväntat "${token.text}"');
    }
    pos++;
    return _termFromWord(token);
  }

  LogFilter _termFromWord(_Token token) {
    // Ett helcitat ord är alltid fritext — annars gick "src:x" inte att söka
    // efter som bokstavlig text.
    if (!token.quoted || token.text.contains(':')) {
      final colon = token.text.indexOf(':');
      if (colon > 0) {
        final rawField = token.text.substring(0, colon).toLowerCase();
        final value = token.text.substring(colon + 1);
        final canonical = fieldAliases[rawField];
        if (canonical != null) {
          if (value.isEmpty) {
            throw LogFilterException('Fältet "$rawField" saknar värde');
          }
          return _Term(canonical, value);
        }
        // Okänt fältnamn: behandla hela strängen som fritext i stället för
        // att kasta. En IPv6-adress eller en tidsstämpel innehåller kolon och
        // ska gå att söka på rakt av.
      }
    }
    return _Term(null, token.text);
  }
}
