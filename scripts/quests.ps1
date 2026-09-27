# Read finished quests from Questie and the Forever quest catalog from QuestieDB.
# Questie stores completed quest ids in the account save. Names, levels, and zones
# live in QuestieDB_Forever.toc as base64 CBOR scalar rows (X-Quest-<id>-S).

. (Join-Path $PSScriptRoot "lua-saved.ps1")

if (-not ([System.Management.Automation.PSTypeName]'QuestieCbor').Type) {
  Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

public class QuestScalar {
  public int Id;
  public string Name;
  public bool HasLevel;
  public int Level;
  public bool HasZone;
  public int ZoneId;
}

public class QuestieCbor {
  byte[] b;
  int i;

  public static List<QuestScalar> ReadToc(string path) {
    var rows = new List<QuestScalar>();
    foreach (var line in File.ReadLines(path)) {
      if (line.Length < 16 || line[0] != '#') continue;
      int id = 0;
      int split = line.IndexOf("-S: ", StringComparison.Ordinal);
      if (split < 0) continue;
      const string prefix = "## X-Quest-";
      if (!line.StartsWith(prefix, StringComparison.Ordinal)) continue;
      string idText = line.Substring(prefix.Length, split - prefix.Length);
      if (!int.TryParse(idText, NumberStyles.None, CultureInfo.InvariantCulture, out id)) continue;
      string payload = line.Substring(split + 4).Trim();
      if (payload.Length == 0 || payload[0] == '~') continue;
      byte[] bytes;
      try { bytes = Convert.FromBase64String(payload); }
      catch (FormatException) { continue; }
      var parser = new QuestieCbor();
      parser.b = bytes;
      parser.i = 0;
      object value;
      try { value = parser.Read(); }
      catch (Exception) { continue; }
      var map = value as Dictionary<string, object>;
      if (map == null) continue;
      object nameObj;
      if (!map.TryGetValue("1", out nameObj)) continue;
      var name = nameObj as string;
      if (string.IsNullOrEmpty(name)) continue;
      var row = new QuestScalar();
      row.Id = id;
      row.Name = name;
      object levelObj;
      int level;
      if (map.TryGetValue("5", out levelObj) && TryInt(levelObj, out level)) {
        row.HasLevel = true;
        row.Level = level;
      }
      object zoneObj;
      int zone;
      if (map.TryGetValue("17", out zoneObj) && TryInt(zoneObj, out zone)) {
        row.HasZone = true;
        row.ZoneId = zone;
      }
      rows.Add(row);
    }
    rows.Sort(delegate(QuestScalar a, QuestScalar b) { return a.Id.CompareTo(b.Id); });
    return rows;
  }

  static bool TryInt(object value, out int number) {
    number = 0;
    if (value is int) { number = (int)value; return true; }
    if (value is long) {
      long wide = (long)value;
      if (wide < int.MinValue || wide > int.MaxValue) return false;
      number = (int)wide;
      return true;
    }
    return false;
  }

  object Read() {
    if (i >= b.Length) throw new InvalidDataException("truncated cbor");
    int ib = b[i++];
    int major = ib >> 5;
    int info = ib & 31;
    bool indef = info == 31;
    if (indef && (major == 0 || major == 1 || major == 6)) throw new InvalidDataException("bad indefinite");
    ulong len = indef ? 0 : Arg(info);
    switch (major) {
      case 0: return Fit(len);
      case 1: return FitSigned(-1L - (long)len);
      case 2: return TakeText(len, indef);
      case 3: return TakeText(len, indef);
      case 4: return TakeArray(len, indef);
      case 5: return TakeMap(len, indef);
      case 6: return Read();
      default: return TakeSimple(info);
    }
  }

  object Fit(ulong value) {
    if (value <= int.MaxValue) return (int)value;
    if (value <= long.MaxValue) return (long)value;
    return value.ToString(CultureInfo.InvariantCulture);
  }

  object FitSigned(long value) {
    if (value >= int.MinValue && value <= int.MaxValue) return (int)value;
    return value;
  }

  ulong Arg(int info) {
    if (info < 24) return (ulong)info;
    if (info == 24) return b[i++];
    if (info == 25) { uint n = (uint)(b[i] << 8 | b[i + 1]); i += 2; return n; }
    if (info == 26) {
      uint n = (uint)(b[i] << 24 | b[i + 1] << 16 | b[i + 2] << 8 | b[i + 3]);
      i += 4;
      return n;
    }
    if (info == 27) {
      ulong n = 0;
      for (int k = 0; k < 8; k++) n = (n << 8) | b[i++];
      return n;
    }
    throw new InvalidDataException("bad cbor length");
  }

  string TakeText(ulong len, bool indef) {
    if (!indef) {
      int n = (int)len;
      string text = Encoding.UTF8.GetString(b, i, n);
      i += n;
      return text;
    }
    var sb = new StringBuilder();
    while (i < b.Length && b[i] != 0xFF) sb.Append((string)Read());
    if (i < b.Length) i++;
    return sb.ToString();
  }

  List<object> TakeArray(ulong len, bool indef) {
    var list = new List<object>();
    if (!indef) {
      for (ulong n = 0; n < len; n++) list.Add(Read());
      return list;
    }
    while (i < b.Length && b[i] != 0xFF) list.Add(Read());
    if (i < b.Length) i++;
    return list;
  }

  Dictionary<string, object> TakeMap(ulong len, bool indef) {
    var map = new Dictionary<string, object>();
    if (!indef) {
      for (ulong n = 0; n < len; n++) {
        object key = Read();
        map[Convert.ToString(key, CultureInfo.InvariantCulture)] = Read();
      }
      return map;
    }
    while (i < b.Length && b[i] != 0xFF) {
      object key = Read();
      map[Convert.ToString(key, CultureInfo.InvariantCulture)] = Read();
    }
    if (i < b.Length) i++;
    return map;
  }

  object TakeSimple(int info) {
    if (info == 20) return false;
    if (info == 21) return true;
    return null;
  }
}
'@
}

function Format-EnumName($enum) {
  $small = @{ of = $true; the = $true; and = $true; in = $true; to = $true; a = $true }
  $parts = ([string]$enum).ToLowerInvariant() -split '_'
  $words = for ($n = 0; $n -lt $parts.Count; $n++) {
    $word = $parts[$n]
    if (-not $word) { continue }
    if ($n -gt 0 -and $small.ContainsKey($word)) { $word }
    else { $word.Substring(0, 1).ToUpperInvariant() + $word.Substring(1) }
  }
  return ($words -join ' ')
}

function Read-IdLabels($path, $negativeOnly) {
  $labels = @{}
  if (-not (Test-Path $path)) { return $labels }
  foreach ($line in [System.IO.File]::ReadLines($path)) {
    if ($line -notmatch '^\s*([A-Z][A-Z0-9_]+)\s*=\s*(-?\d+)') { continue }
    $id = [int]$Matches[2]
    if ($negativeOnly -and $id -ge 0) { continue }
    if ($labels.ContainsKey($id)) { continue }
    $labels[$id] = Format-EnumName $Matches[1]
  }
  return $labels
}

function Read-SubzoneNames($path, $labels) {
  if (-not (Test-Path $path)) { return }
  foreach ($line in [System.IO.File]::ReadLines($path)) {
    if ($line -notmatch '\[(-?\d+)\]\s*=\s*-?\d+\s*,\s*--\s*(.+)$') { continue }
    $id = [int]$Matches[1]
    if ($labels.ContainsKey($id)) { continue }
    $note = $Matches[2].Trim()
    $name = $note
    if ($note -match '^(.+?)\s*->') { $name = $Matches[1].Trim() }
    if ($name) { $labels[$id] = $name }
  }
}

function Read-ZoneLabels($addonsPath) {
  $root = Join-Path $addonsPath "QuestieDB\support\Forever\Zones"
  $labels = Read-IdLabels (Join-Path $root "zoneIds.lua") $false
  Read-SubzoneNames (Join-Path $root "subZoneToParentZone.lua") $labels
  $sorts = Read-IdLabels (Join-Path $addonsPath "Questie\Database\Constants.lua") $true
  foreach ($id in $sorts.Keys) {
    if (-not $labels.ContainsKey($id)) { $labels[$id] = $sorts[$id] }
  }
  return $labels
}

function Read-TocValue($path, $field) {
  if (-not (Test-Path $path)) { return $null }
  $pattern = '(?m)^##\s*' + [regex]::Escape($field) + ':\s*(.+)$'
  $text = [System.IO.File]::ReadAllText($path)
  if ($text -match $pattern) { return $Matches[1].Trim() }
  return $null
}

function Read-QuestCatalog($addonsPath) {
  $toc = Join-Path $addonsPath "QuestieDB\QuestieDB_Forever.toc"
  if (-not (Test-Path $toc)) { return $null }
  $labels = Read-ZoneLabels $addonsPath
  $rows = [QuestieCbor]::ReadToc($toc)
  $quests = foreach ($row in $rows) {
    $zone = "Other"
    $item = [ordered]@{ id = $row.Id; name = $row.Name }
    if ($row.HasLevel) { $item.level = $row.Level }
    if ($row.HasZone) {
      $item.zoneId = $row.ZoneId
      if ($labels.ContainsKey($row.ZoneId)) { $zone = $labels[$row.ZoneId] }
      elseif ($row.ZoneId -gt 0) { $zone = "Zone $($row.ZoneId)" }
    }
    $item.zone = $zone
    [pscustomobject]$item
  }
  $version = Read-TocValue (Join-Path $addonsPath "Questie\Questie_Vanilla.toc") "Version"
  [ordered]@{
    source = "Questie"
    version = $version
    dbVersion = Read-TocValue $toc "Version"
    quests = @($quests)
  }
}

function Add-ResolvedQuestNames($catalog, $repo) {
  if (-not $catalog) { return $catalog }
  $known = @{}
  foreach ($quest in @($catalog.quests)) { $known[[int]$quest.id] = $true }
  $extra = @()
  foreach ($root in @((Join-Path $repo "exports"), (Join-Path $repo "data\exports"))) {
    if (-not (Test-Path $root)) { continue }
    foreach ($file in @(Get-ChildItem -Path $root -Recurse -Filter "*.txt" -File -ErrorAction SilentlyContinue)) {
      $inSection = $false
      foreach ($line in [System.IO.File]::ReadLines($file.FullName)) {
        if ($line -eq "== Resolved Quests ==") { $inSection = $true; continue }
        if ($inSection -and $line.StartsWith("== ")) { $inSection = $false; continue }
        if (-not $inSection) { continue }
        if ($line -notmatch '^(.+) \(ID: (\d+)\)$') { continue }
        $id = [int]$Matches[2]
        if ($known.ContainsKey($id)) { continue }
        $known[$id] = $true
        $extra += [pscustomobject][ordered]@{ id = $id; name = $Matches[1].Trim(); zone = "Other" }
      }
    }
  }
  if ($extra.Count) {
    $catalog.quests = @(@($catalog.quests) + $extra | Sort-Object id)
    Write-Host "Named $($extra.Count) finished quests from CharacterExport that QuestieDB does not list."
  }
  return $catalog
}

function Get-QuestieName($key) {
  $text = ([string]$key).Trim()
  $parts = $text -split ' - ', 2
  return $parts[0].Trim()
}

function Test-FolderCharacter($folderName, $character) {
  $first = ($character.name -split ' ')[0]
  $compact = ($character.name -replace '\s+', '')
  $folderCompact = ([string]$folderName) -replace '-', ''
  return ($folderName -eq $first) -or ($folderName -like "$first-*") -or ($folderCompact -eq $compact)
}

function Get-QuestieFolders($wtfRoot) {
  $folders = @()
  $accountRoot = Join-Path $wtfRoot "Account"
  if (-not (Test-Path $accountRoot)) { return $folders }
  foreach ($file in (Get-ChildItem -Path $accountRoot -Recurse -Filter "Questie.lua" -ErrorAction SilentlyContinue)) {
    $saved = $file.Directory
    if ($saved.Name -ne "SavedVariables") { continue }
    $owner = $saved.Parent
    if ($owner.Parent.Name -eq "Account") { continue }
    $folders += [pscustomobject]@{ name = $owner.Name; at = $file.LastWriteTime }
  }
  return $folders
}

function Get-CompletedIds($complete) {
  $ids = @()
  if ($complete -isnot [System.Collections.IDictionary]) { return $ids }
  foreach ($key in $complete.Keys) {
    if ($complete[$key] -ne $true) { continue }
    $number = 0
    if ([int]::TryParse([string]$key, [ref]$number)) { $ids += $number }
  }
  return @($ids | Sort-Object)
}

function Get-QuestProgress($wtfRoot, $characters) {
  $characters = @($characters | ForEach-Object { $_ })
  $progress = @{}
  $accountRoot = Join-Path $wtfRoot "Account"
  if (-not (Test-Path $accountRoot)) { return $progress }
  $folders = @(Get-QuestieFolders $wtfRoot)
  $accountFiles = @(Get-ChildItem -Path $accountRoot -Recurse -Filter "Questie.lua" -ErrorAction SilentlyContinue | Where-Object {
    $_.Directory.Name -eq "SavedVariables" -and $_.Directory.Parent.Parent.Name -eq "Account"
  })

  foreach ($file in $accountFiles) {
    $parsed = Read-LuaSaved $file.FullName
    $chars = $null
    if ($parsed -is [System.Collections.IDictionary] -and $parsed.ContainsKey("QuestieConfig")) {
      $config = $parsed["QuestieConfig"]
      if ($config -is [System.Collections.IDictionary] -and $config.ContainsKey("char")) { $chars = $config["char"] }
    }
    if ($chars -isnot [System.Collections.IDictionary]) { continue }
    $when = $file.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss")

    foreach ($key in $chars.Keys) {
      $blob = $chars[$key]
      if ($blob -isnot [System.Collections.IDictionary]) { continue }
      $class = $null
      if ($blob.ContainsKey("townsfolkClass") -and $blob["townsfolkClass"]) {
        $class = ([string]$blob["townsfolkClass"]).ToUpperInvariant()
      }
      $name = Get-QuestieName $key
      $match = @()
      if ($name -and $name -ne "Unknown") {
        $match = @($characters | Where-Object {
          $first = ($_.name -split ' ')[0]
          ($name -ieq $_.name) -or ($name -ieq $first)
        })
        if ($class -and $match.Count -gt 1) {
          $byClass = @($match | Where-Object { ([string]$_.className).ToUpperInvariant() -eq $class })
          if ($byClass.Count) { $match = $byClass }
        }
      } elseif ($name -eq "Unknown") {
        $byClass = @($characters | Where-Object { $class -and ([string]$_.className).ToUpperInvariant() -eq $class })
        $folderIds = @{}
        foreach ($character in $characters) {
          $named = @($folders | Where-Object { Test-FolderCharacter $_.name $character })
          if ($named.Count) { $folderIds[$character.id] = $true }
        }
        $match = @($byClass | Where-Object { $folderIds.ContainsKey($_.id) })
      }

      if ($match.Count -ne 1) {
        $why = if ($name -eq "Unknown") { "without a character name" } else { "as '$key'" }
        Write-Host "Questie saved a character $why, and $($match.Count) roster characters fit. Skipped."
        continue
      }
      $character = $match[0]
      if ($progress.ContainsKey($character.id)) {
        Write-Host "Questie already matched $($character.name). Skipped a second save entry."
        continue
      }
      $ids = Get-CompletedIds $(if ($blob.ContainsKey("complete")) { $blob["complete"] } else { $null })
      $progress[$character.id] = [ordered]@{ completed = $ids; at = $when }
      Write-Host "Questie finished quests for $($character.name): $($ids.Count)"
    }
  }
  return $progress
}
