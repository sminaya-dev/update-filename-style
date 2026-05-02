# Update-FileNameStyle.Tests.ps1

# Ensure we are testing the file in the current directory
$ScriptPath = "$PSScriptRoot\Update-FileNameStyle.ps1"

Describe "Update-FileNameStyle" {
    
    # Pester creates a virtual "TestDrive:\" that is wiped clean after tests finish.
    # This prevents us from messing up real files on your hard drive.
    
    Context "Title Case Logic" {
        It "Should capitalize standard words" {
            # 1. Setup: Create a fake file
            New-Item -Path "TestDrive:\how computers work.txt" -ItemType File | Out-Null
            
            # 2. Act: Run your script
            & $ScriptPath -Path "TestDrive:\" -Case Title | Out-Null
            
            # 3. Assert: Check if the file was renamed
            $Result = Test-Path "TestDrive:\How Computers Work.txt"
            $Result | Should -Be $true
        }

        It "Should lowercase minor words (like 'to', 'the')" {
            New-Item -Path "TestDrive:\guide to the galaxy.txt" -ItemType File | Out-Null
            & $ScriptPath -Path "TestDrive:\" -Case Title | Out-Null
            
            # 'To' and 'The' should be lowercase
            (Test-Path "TestDrive:\Guide to the Galaxy.txt") | Should -Be $true
        }

        It "Should respect the Acronym list (SQL, TCP)" {
            New-Item -Path "TestDrive:\intro to sql.txt" -ItemType File | Out-Null
            & $ScriptPath -Path "TestDrive:\" -Case Title | Out-Null
            
            # 'SQL' should be uppercase
            (Test-Path "TestDrive:\Intro to SQL.txt") | Should -Be $true
        }

        It "Should accept custom acronyms via parameter" {
            New-Item -Path "TestDrive:\learning k8s.txt" -ItemType File | Out-Null
            
            # Pass 'K8S' as a custom acronym
            & $ScriptPath -Path "TestDrive:\" -Case Title -AddAcronyms "K8S" | Out-Null
            
            (Test-Path "TestDrive:\Learning K8S.txt") | Should -Be $true
        }
    }

    Context "Snake Case Logic" {
        It "Should convert spaces to underscores and lowercase everything" {
            New-Item -Path "TestDrive:\My Cool Script.ps1" -ItemType File | Out-Null
            & $ScriptPath -Path "TestDrive:\" -Case Snake | Out-Null
            
            (Test-Path "TestDrive:\my_cool_script.ps1") | Should -Be $true
        }

        It "Should Preserve dots for versions (The Fix)" {
            New-Item -Path "TestDrive:\Angular.js Guide v1.2.pdf" -ItemType File | Out-Null
            & $ScriptPath -Path "TestDrive:\" -Case Snake | Out-Null
            
            # It should NOT become angular_js_guide_v1_2.pdf
            (Test-Path "TestDrive:\angular.js_guide_v1.2.pdf") | Should -Be $true
        }
    }

    Context "Safety & Edge Cases" {
        It "Should skip files that are already correct" {
            New-Item -Path "TestDrive:\Already Correct.txt" -ItemType File | Out-Null
            
            # Capture the output object
            $Output = & $ScriptPath -Path "TestDrive:\" -Case Title
            
            # Status should be 'Skipped'
            $Output.Status | Should -Be "Skipped"
        }
    }
}