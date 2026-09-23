/// Convertit un montant en dinars tunisiens (avec millimes) en toutes
/// lettres françaises, pour l'impression du champ "Montant en lettres"
/// des lettres de change (voir §1.14).
String amountToFrenchWords(double amount) {
  final dinars = amount.floor();
  final millimes = ((amount - dinars) * 1000).round();
  final dinarsWords = _intToWords(dinars);
  final buffer = StringBuffer();
  buffer.write(dinarsWords);
  buffer.write(dinars > 1 ? ' dinars' : ' dinar');
  if (millimes > 0) {
    buffer.write(' et ');
    buffer.write(_intToWords(millimes));
    buffer.write(millimes > 1 ? ' millimes' : ' millime');
  }
  final text = buffer.toString();
  return text[0].toUpperCase() + text.substring(1);
}

const _units = [
  '', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
  'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize', 'dix-sept', 'dix-huit', 'dix-neuf',
];
const _tens = ['', '', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante', 'soixante-dix', 'quatre-vingt', 'quatre-vingt-dix'];

String _intToWords(int n) {
  if (n == 0) return 'zéro';
  if (n < 0) return 'moins ${_intToWords(-n)}';
  if (n < 20) return _units[n];
  if (n < 100) {
    final t = n ~/ 10;
    final u = n % 10;
    if (t == 7 || t == 9) {
      final base = _tens[t - 1];
      return u == 0 ? '$base-dix' : '$base-${_units[10 + u]}';
    }
    if (u == 0) return _tens[t];
    if (u == 1 && t != 8) return '${_tens[t]} et un';
    return '${_tens[t]}-${_units[u]}';
  }
  if (n < 1000) {
    final h = n ~/ 100;
    final rest = n % 100;
    final prefix = h == 1 ? 'cent' : '${_units[h]} cent';
    if (rest == 0) return h > 1 ? '${prefix}s' : prefix;
    return '$prefix ${_intToWords(rest)}';
  }
  if (n < 1000000) {
    final th = n ~/ 1000;
    final rest = n % 1000;
    final prefix = th == 1 ? 'mille' : '${_intToWords(th)} mille';
    if (rest == 0) return prefix;
    return '$prefix ${_intToWords(rest)}';
  }
  final m = n ~/ 1000000;
  final rest = n % 1000000;
  final prefix = m == 1 ? 'un million' : '${_intToWords(m)} millions';
  if (rest == 0) return prefix;
  return '$prefix ${_intToWords(rest)}';
}
