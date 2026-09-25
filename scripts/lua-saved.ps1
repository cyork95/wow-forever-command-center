if (-not ([System.Management.Automation.PSTypeName]'LuaSaved').Type) {
  Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

public class LuaSaved {
  string s;
  int i;

  public static Dictionary<string, object> Parse(string text) {
    var p = new LuaSaved();
    p.s = text;
    p.i = 0;
    var result = new Dictionary<string, object>();
    while (true) {
      p.Skip();
      if (p.i >= p.s.Length) break;
      string name = p.Ident();
      if (name.Length == 0) { p.i++; continue; }
      p.Skip();
      if (p.i < p.s.Length && p.s[p.i] == '=') {
        p.i++;
        result[name] = p.Value();
      }
    }
    return result;
  }

  void Skip() {
    while (i < s.Length) {
      char c = s[i];
      if (char.IsWhiteSpace(c) || c == ';') { i++; continue; }
      if (c == '-' && i + 1 < s.Length && s[i + 1] == '-') {
        if (i + 3 < s.Length && s[i + 2] == '[' && s[i + 3] == '[') {
          int end = s.IndexOf("]]", i + 4, StringComparison.Ordinal);
          i = end < 0 ? s.Length : end + 2;
        } else {
          while (i < s.Length && s[i] != '\n') i++;
        }
        continue;
      }
      break;
    }
  }

  string Ident() {
    int start = i;
    while (i < s.Length && (char.IsLetterOrDigit(s[i]) || s[i] == '_')) i++;
    return s.Substring(start, i - start);
  }

  object Value() {
    Skip();
    if (i >= s.Length) return null;
    char c = s[i];
    if (c == '{') return Table();
    if (c == '"' || c == '\'') return Str(c);
    if (c == '[' && i + 1 < s.Length && (s[i + 1] == '[' || s[i + 1] == '=')) return LongStr();
    if (c == '-' || c == '.' || char.IsDigit(c)) return Num();
    string word = Ident();
    if (word == "true") return true;
    if (word == "false") return false;
    if (word == "nil") return null;
    if (word == "math") { Ident(); i++; Ident(); return double.PositiveInfinity; }
    return word;
  }

  object Num() {
    int start = i;
    if (s[i] == '-') i++;
    if (i + 1 < s.Length && s[i] == '0' && (s[i + 1] == 'x' || s[i + 1] == 'X')) {
      i += 2;
      int hs = i;
      while (i < s.Length && Uri.IsHexDigit(s[i])) i++;
      long hex = Convert.ToInt64(s.Substring(hs, i - hs), 16);
      return s[start] == '-' ? -hex : hex;
    }
    while (i < s.Length && (char.IsDigit(s[i]) || s[i] == '.' || s[i] == 'e' || s[i] == 'E' ||
      ((s[i] == '-' || s[i] == '+') && (s[i - 1] == 'e' || s[i - 1] == 'E')))) i++;
    string text = s.Substring(start, i - start);
    long whole;
    if (long.TryParse(text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out whole)) return whole;
    double d;
    if (double.TryParse(text, NumberStyles.Float, CultureInfo.InvariantCulture, out d)) return d;
    return text;
  }

  string Str(char quote) {
    i++;
    var sb = new StringBuilder();
    while (i < s.Length && s[i] != quote) {
      char c = s[i++];
      if (c != '\\' || i >= s.Length) { sb.Append(c); continue; }
      char e = s[i++];
      switch (e) {
        case 'n': sb.Append('\n'); break;
        case 't': sb.Append('\t'); break;
        case 'r': sb.Append('\r'); break;
        case '\n': sb.Append('\n'); break;
        default:
          if (char.IsDigit(e)) {
            int n = e - '0';
            for (int k = 0; k < 2 && i < s.Length && char.IsDigit(s[i]); k++) n = n * 10 + (s[i++] - '0');
            sb.Append((char)n);
          } else sb.Append(e);
          break;
      }
    }
    i++;
    return sb.ToString();
  }

  string LongStr() {
    int start = i + 1;
    int level = 0;
    while (start < s.Length && s[start] == '=') { level++; start++; }
    start++;
    string close = "]" + new string('=', level) + "]";
    int end = s.IndexOf(close, start, StringComparison.Ordinal);
    if (end < 0) end = s.Length;
    i = Math.Min(s.Length, end + close.Length);
    return s.Substring(start, end - start);
  }

  object Table() {
    i++;
    var keys = new List<string>();
    var values = new List<object>();
    long next = 1;
    bool isList = true;
    while (true) {
      Skip();
      if (i >= s.Length) break;
      if (s[i] == '}') { i++; break; }
      if (s[i] == ',') { i++; continue; }
      string key = null;
      if (s[i] == '[' && !(i + 1 < s.Length && (s[i + 1] == '[' || s[i + 1] == '='))) {
        i++;
        object k = Value();
        Skip();
        if (i < s.Length && s[i] == ']') i++;
        Skip();
        if (i < s.Length && s[i] == '=') i++;
        key = Convert.ToString(k, CultureInfo.InvariantCulture);
        isList = false;
      } else if (char.IsLetter(s[i]) || s[i] == '_') {
        int save = i;
        string word = Ident();
        Skip();
        if (i < s.Length && s[i] == '=' && !(i + 1 < s.Length && s[i + 1] == '=')) {
          i++;
          key = word;
          isList = false;
        } else {
          i = save;
        }
      }
      object v = Value();
      if (key == null) key = (next++).ToString(CultureInfo.InvariantCulture);
      keys.Add(key);
      values.Add(v);
    }
    if (isList) return values;
    var dict = new Dictionary<string, object>();
    for (int n = 0; n < keys.Count; n++) dict[keys[n]] = values[n];
    return dict;
  }
}
'@
}

function Read-LuaSaved($path) {
  if (-not (Test-Path $path)) { return $null }
  $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  return [LuaSaved]::Parse($text)
}
