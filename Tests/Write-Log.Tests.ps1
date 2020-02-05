$path = (Split-Path -Parent $MyInvocation.MyCommand.Path).Replace("\Tests", "\WASP")
$Private = @(Get-ChildItem -Path $path\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in $Private) {
    . $import.fullname
}

Describe "Writing log to file and console" {

    Context "General log message tests" {
        Mock Write-Host { }
        Mock Write-EventLog { }
        Mock Add-Content { }

        It "logs no message if it is empty" {
            Write-Log "" 0
            Assert-MockCalled Add-Content -Exactly 0 -Scope It
            Assert-MockCalled Write-EventLog -Exactly 0 -Scope It
            Assert-MockCalled Write-Host -Exactly 0 -Scope It
        }
        It "logs message to debug as default" {
            Write-Log "This is nice" 0
            Assert-MockCalled Add-Content -Exactly 1 -Scope It
            Assert-MockCalled Write-EventLog -Exactly 0 -Scope It
            Assert-MockCalled Write-Host -Exactly 1 -Scope It
        }
        It "logs message to information when severity is 1 and writes in EventLog" {
            Write-Log "This is nice" 1
            Assert-MockCalled Add-Content -Exactly 1 -Scope It
            Assert-MockCalled Write-EventLog -Exactly 1 -Scope It
            Assert-MockCalled Write-Host -Exactly 1 -Scope It
        }
    }

    Context "Log messages to file" {
        Mock Write-Host { }
        Mock Write-EventLog { }

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

        It "creates log file if non exists" {
            Write-Log "This is nice" 1
            $log | Should -Exist
            $log | Should -FileContentMatch 'This is nice'
        }
        It "appends log to exisiting log file" {
            Write-Log "This is not nice" 1
            $log | Should -FileContentMatch 'This is not nice'
        }
    }
}