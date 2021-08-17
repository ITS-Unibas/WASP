BeforeAll {
    $path = Split-Path -Parent $PSCommandPath.Replace('.Tests.ps1', '.ps1').Replace('Tests', 'WASP\Private')
    $Private = @(Get-ChildItem -Path $path\*.ps1 -ErrorAction SilentlyContinue)
    foreach ($import in $Private) {
        . $import.fullname
    }

    Mock Write-Host { }
}

Describe "Writing log to file and console" {
    Context "General log message tests" {
        BeforeAll {
            Mock Out-File
        }
        It "logs no message if it is empty" {
            Write-Log "" 0
            Assert-MockCalled Out-File -Exactly 0 -Scope It
            Assert-MockCalled Write-Host -Exactly 0 -Scope It
        }
        It "logs message to debug as default" {
            Write-Log "This is nice" 0
            #Assert-MockCalled Out-File -Exactly 1 -Scope It
            #Assert-MockCalled Write-Host -Exactly 1 -Scope It
        }
        It "logs message to information when severity is 1 and writes in EventLog" {
            Write-Log "This is nice" 1
            Assert-MockCalled Out-File -Exactly 1 -Scope It
            Assert-MockCalled Write-Host -Exactly 1 -Scope It
        }
    }

    Context "Log messages to file" {
        BeforeAll {
            $test = '{
                "Application": {
                    "BaseDirectory": "TestDrive:\\"
                },
                "Logger": {
                    "EventLogName": "WASP",
                    "EventID": 9999,
                    "LogSubFilePath": "logs",
                    "LogFileNamePrefix": "choco_log",
                    "MaxLogFiles": 10,
                    "LogLevel": 0,
                    "LogToHost": true
                }
            }'

            Mock Read-ConfigFile { return ConvertFrom-Json $test }

            $log = "TestDrive:\logs\choco_log_$(Get-Date -Format yyyyMMdd).log"
        }
        It "creates log file if non exists" {
            Write-Log "This is nice" 1
            $log | Should -Exist
            $log | Should -FileContentMatch 'This is nice'
            Assert-MockCalled Write-Host -Exactly 1 -Scope It
        }
        It "appends log to exisiting log file" {
            Write-Log "This is not nice" 1
            $log | Should -Exist
            $log | Should -FileContentMatch 'This is nice'
            $log | Should -FileContentMatch 'This is not nice'
            Assert-MockCalled Write-Host -Exactly 1 -Scope It
        }
    }
}