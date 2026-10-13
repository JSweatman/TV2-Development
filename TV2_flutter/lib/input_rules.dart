class InputRules {
  static const allowed = '0123456789@/-#.*';
  static const symbols = '@/-#.';
  static const maxBaseLength = 15;

  static bool canAppend(String current, String next) {
    if (next.length != 1 || !allowed.contains(next)) return false;
    if (next == '*') {
      if (current.contains('*') || current.contains('.')) return false;
      // STAR is either the first character (Global Code) or follows a numeric
      // country context. It is not a base List Number character.
      return current.isEmpty || RegExp(r'^\d+$').hasMatch(current);
    }

    final body = current.contains('*')
        ? current.substring(current.indexOf('*') + 1)
        : current;
    final base = body.contains('.') ? body.substring(0, body.indexOf('.')) : body;
    final inTldx = body.contains('.');

    if (next == '.') {
      if (inTldx || base.isEmpty) return false;
      if (symbols.contains(current[current.length - 1])) return false;
      return true;
    }

    if (symbols.contains(next)) {
      if (body.isEmpty) return false;
      if (symbols.contains(current[current.length - 1])) return false;
    }

    if (!inTldx && next != '.' && base.length >= maxBaseLength) return false;
    return true;
  }
}
