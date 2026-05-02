<#
.SYNOPSIS
    Renames files to Title Case or Snake Case. Supports Pipeline input and Undo-safety.

.DESCRIPTION
    Standardizes filenames across a folder or pipeline input using one of two formatting styles:
    - Title Case: Converts "my_cool_book.pdf" -> "My Cool Book.pdf", with minor word and acronym awareness
    - Snake Case: Converts "My Cool Book.pdf" -> "my_cool_book.pdf", preserving version number dots

    Renames are transactional — a GUID-based temp name is used during the operation to avoid
    case-collision issues on Windows, and automatic rollback is performed if a rename fails midway.

    NOTE: Supports both folder-based batch processing and pipeline input from Get-ChildItem.
    
.PARAMETER Path
    The file or folder to process. Accepts pipeline input.

.PARAMETER Case
    'Title' (Human readable, spaces) or 'Snake' (Programmatic, underscores).

.PARAMETER AddAcronyms
    Additional words to force uppercase (e.g., "K8S", "SRE"). Merged with the built-in acronym list at runtime.

.EXAMPLE
    Get-ChildItem *.pdf | .\Update-FileNameStyle.ps1 -Case Snake
    Pipes all PDFs into the script to be snake_cased.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias("FullName")] # Allows piping from Get-ChildItem seamlessly
    [string[]]$Path = ".",

    [Parameter()]
    [switch]$Recurse,

    [Parameter()]
    [string[]]$Extensions,

    [Parameter()]
    [ValidateSet("Title", "Snake")]
    [string]$Case = "Title",

    [Parameter()]
    [string[]]$Exclude = @(),

    [Parameter()]
    [string[]]$AddAcronyms = @()
)

begin {
    # --- CONFIGURATION (Runs once at startup) ---
    $MinorWords = @(
        "a", "an", "the", "and", "but", "or", "nor", "for", "yet", "so",
        "at", "by", "for", "in", "of", "on", "to", "up", "with", "as", 
        "is", "via", "vs", "v", "from", "into"
    )

    $KeepUppercase = @(
        "TCP", "UDP", "SQL", "API", "CPU", "RAM", "IP", "SSH", "HTTP", "HTTPS", 
        "AWS", "GCP", "AZURE", "GIT", "PDF", "PNG", "JPG",
        "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"
    ) + $AddAcronyms
}

process {
    # --- PROCESSING (Runs for every item passed via Pipeline or Parameter) ---
    foreach ($ItemPath in $Path) {
        
        # 1. Resolve the path (handling relative paths vs absolute paths)
        if (Test-Path $ItemPath -PathType Container) {
            # If input is a Folder, get the files inside
            $FilesToProcess = Get-ChildItem -Path $ItemPath -File -Recurse:$Recurse -Exclude $Exclude | 
            Where-Object { if ($Extensions) { $Extensions -contains $_.Extension.TrimStart('.') } else { $true } }
        }
        else {
            # If input is a File (via pipeline), process just that file
            $FilesToProcess = Get-Item -Path $ItemPath -Exclude $Exclude |
            Where-Object { if ($Extensions) { $Extensions -contains $_.Extension.TrimStart('.') } else { $true } }
        }

        foreach ($File in $FilesToProcess) {
            $OldBaseName = $File.BaseName
            $NewBaseName = ""

            if ($Case -eq "Snake") {
                # Snake: Replace separators with underscore, remove weird chars, lowercase
                $NewBaseName = ($OldBaseName -replace '[^a-zA-Z0-9\.]+', '_').Trim('_').ToLower()
            }
            else {
                # Title: First, replace underscores/dots/hyphens with spaces for readability
                # This ensures "my_file" becomes "My File"
                $CleanName = $OldBaseName -replace '[-_\.]', ' ' -replace '\s+', ' '
                
                $WordsFound = [regex]::Matches($CleanName, '\b(\w+)\b')
                $NewBaseName = $CleanName

                for ($i = $WordsFound.Count - 1; $i -ge 0; $i--) {
                    $Match = $WordsFound[$i]
                    $Word = $Match.Value
                    $ProcessedWord = ""

                    if ($KeepUppercase -contains $Word.ToUpper()) {
                        $ProcessedWord = $Word.ToUpper()
                    }
                    elseif ($i -eq 0 -or $i -eq ($WordsFound.Count - 1) -or ($MinorWords -notcontains $Word.ToLower())) {
                        $ProcessedWord = (Get-Culture).TextInfo.ToTitleCase($Word.ToLower())
                    }
                    else {
                        $ProcessedWord = $Word.ToLower()
                    }

                    $NewBaseName = $NewBaseName.Remove($Match.Index, $Match.Length).Insert($Match.Index, $ProcessedWord)
                }
            }

            $NewFileName = "$NewBaseName$($File.Extension)"
            $Action = "Skipped"
            $ErrorMsg = $null

            if ($NewFileName -cne $File.Name) {
                $TempName = "$($File.BaseName)_$([Guid]::NewGuid())" + $File.Extension
                $TempPath = Join-Path -Path $File.DirectoryName -ChildPath $TempName
                
                try {
                    Rename-Item -Path $File.FullName -NewName $TempName -ErrorAction Stop
                    Rename-Item -Path $TempPath -NewName $NewFileName -ErrorAction Stop
                    $Action = "Renamed"
                }
                catch {
                    $ErrorMsg = $_.Exception.Message
                    if (Test-Path $TempPath) {
                        Rename-Item -Path $TempPath -NewName $File.Name -ErrorAction SilentlyContinue
                        $ErrorMsg += " [Rolled back]"
                    }
                    $Action = "Error"
                }
            }

            [PSCustomObject]@{
                Status       = $Action
                OriginalName = $File.Name
                NewName      = $NewFileName
                Details      = $ErrorMsg
            }
        }
    }
}