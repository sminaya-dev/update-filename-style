# update-filename-style

*Batch filename formatter for Windows — Title Case and snake_case with acronym awareness*

![PowerShell](https://img.shields.io/badge/PowerShell-Core-blue?logo=powershell) ![Pester](https://img.shields.io/badge/Tested%20with-Pester-darkgreen) ![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey?logo=windows)

---

## About

Inconsistent filenames are a common problem when accumulating documents, books, and assets over time. `Update-FileNameStyle.ps1` standardizes filenames across a folder in bulk — converting them to either human-readable Title Case or programmatic snake_case — while intelligently handling acronyms, minor words, and version numbers.

It supports both folder-based batch processing and pipeline input from `Get-ChildItem`, making it flexible enough for one-off fixes or integration into larger automation workflows.

---

## Features

- **Two formatting modes** — Title Case for readability (`Guide to TCP/IP.pdf`) or snake_case for programmatic access (`guide_to_tcp_ip.pdf`)
- **Acronym protection** — a built-in list prevents common terms like `TCP`, `SQL`, `API`, and `HTTP` from being incorrectly cased
- **Extensible acronym list** — pass custom acronyms at runtime via `-AddAcronyms` (e.g., `K8S`, `SRE`, `DevOps`)
- **Minor word awareness** — articles, conjunctions, and short prepositions (`a`, `the`, `of`, `to`, etc.) stay lowercase unless they're the first or last word
- **Version number preservation** — snake_case mode retains dots so `v1.2.5` stays intact rather than becoming `v1_2_5`
- **Pipeline support** — accepts input directly from `Get-ChildItem` for targeted, composable use
- **Transactional renaming** — uses a GUID-based temp name during the rename operation to avoid collisions on case-only changes
- **Automatic rollback** — if a rename fails midway, the script restores the original filename automatically
- **WhatIf support** — preview all changes before applying them with `-WhatIf`
- **Filtered processing** — scope runs by file extension (`-Extensions`) or exclude specific files (`-Exclude`)

---

## Usage

**Basic — rename all files in a folder to Title Case:**
```powershell
.\Update-FileNameStyle.ps1 -Path "C:\Books"
```

**Snake case — useful for scripting or programmatic access:**
```powershell
.\Update-FileNameStyle.ps1 -Path "C:\Books" -Case Snake
```

**Filter by extension — only process PDFs and EPUBs:**
```powershell
.\Update-FileNameStyle.ps1 -Path "C:\Books" -Extensions "pdf", "epub"
```

**Recurse into subfolders:**
```powershell
.\Update-FileNameStyle.ps1 -Path "C:\Books" -Recurse
```

**Add custom acronyms:**
```powershell
.\Update-FileNameStyle.ps1 -Path "C:\Docs" -AddAcronyms "K8S", "SRE"
```

**Pipeline — target specific files with Get-ChildItem:**
```powershell
Get-ChildItem "C:\Images" -Filter "*.png" | .\Update-FileNameStyle.ps1 -Case Snake
```

**Preview changes without renaming anything:**
```powershell
.\Update-FileNameStyle.ps1 -Path "C:\Books" -WhatIf
```

---

## Output

Each run returns a result object per file, displayed as a table:

```
Status   OriginalName                  NewName                       Details
------   ------------                  -------                       -------
Renamed  intro to sql.pdf              Intro to SQL.pdf
Renamed  my_cool_script.ps1            My Cool Script.ps1
Skipped  Already Correct.txt           Already Correct.txt
Error    locked_file.pdf               Locked File.pdf               Access denied [Rolled back]
```

---

## Technical Highlights

**Regex-based word matching**

Rather than splitting on spaces and rejoining, the script uses `[regex]::Matches()` with a word-boundary pattern (`\b(\w+)\b`) to locate words while preserving surrounding punctuation. Words are then replaced in reverse index order so that earlier positions in the string aren't shifted by changes made after them.

**Transactional rename with rollback**

Windows is case-insensitive for filenames, which means renaming `guide.pdf` to `Guide.pdf` in a single step is treated as a no-op. The script works around this by first renaming to a GUID-based temp name, then renaming to the final target. If the second step fails, a `catch` block detects whether the temp file still exists and renames it back to the original — leaving the filesystem in a clean state regardless of outcome.

**Extensible acronym dictionary**

The built-in `$KeepUppercase` list covers common tech terms and Roman numerals. At runtime, the `-AddAcronyms` parameter merges user-provided terms into the same list, so custom acronyms follow identical logic without any changes to the script itself.

---

## Testing

This project includes a [Pester](https://pester.dev/) test suite covering the core formatting logic and safety behaviors.

**Run the tests:**
```powershell
Invoke-Pester .\Update-FileNameStyle.Tests.ps1
```

**Test coverage:**
- Title Case — standard capitalization, minor word handling, acronym list, custom acronyms
- Snake Case — separator replacement, version number dot preservation
- Safety — skipping already-correct filenames

---

## License

[MIT](LICENSE)