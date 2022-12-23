

function Install-Adb() {

    $isThere = Test-Path "C:\Android\"
    if ($isThere -eq $false) {
        $saveAdb =  $($env:USERPROFILE + "\Downloads\adb.zip")
        Import-Module BitsTransfer
        Start-BitsTransfer -Source "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" -Destination $($env:USERPROFILE + "\Downloads\adb.zip")
        Expand-Archive -Path $saveAdb -DestinationPath "C:\Android\" -Verbose
    } else {
        Write-Host "ADB package loaded" -ForegroundColor Green
    }

}

if ($(Test-Path "C:\Android\") -eq $false) {
    Write-Host "Adb is not installed!`nPlease run 'Install-Adb' before use" -ForegroundColor Yellow
}

$executionPath = "C:\Android\platform-tools\adb.exe"

function Adb-Execute($parameter) {
    if ($parameter -eq $null) {
        Write-Host "No arguments provided!" -ForegroundColor Red
    } else {
        Write-Host "Command => " $parameter
        Invoke-Expression  $("$executionPath $parameter")
    }
}


function Adb-Get($parameter) {
    Write-Host "Running => " + $($executionPath + " $parameter")
    return Invoke-Expression $($executionPath + " $parameter")
}

function Adb-GetDevices() {
    $devices = @()
    $deviceArray = Invoke-Expression $($executionPath + " devices") | where { $_ -notlike "List of devices attached" } | Where-Object { $_ }
    foreach ($deviceEntry in $deviceArray) {
        if ($deviceEntry -match "^\S*") {
            $serial = $matches[0]
            $model = Adb-Get -parameter "-s $serial shell getprop ro.product.model"
            $deviceType = Adb-Get -parameter "-s $serial shell getprop ro.build.characteristics"
        
            $device = [PSCustomObject]@{
                Index = $deviceArray.IndexOf($deviceEntry)
                Serial = $serial
                Model = $model
                Type = $deviceType
            }

            $devices += $device
        }
    }
    return $devices
}

function Adb-Devices() {
    $result = Invoke-Expression $($executionPath + " devices")
    Write-Host $result
}


function Adb-Logcat {
    param
    (
      # variables define one or more parameters
      # this is a comma-separated list!
        $Device = $null,  # <-- don't forget the comma!
        $Package = $null
    )


    $devices = Adb-GetDevices
    if ([string]::IsNullOrWhiteSpace($Device) -and $devices.Count -gt 1) {
        [array]$callStack = $()
        Write-Host "Please input desired device(s) to run logcat on.`n`tSelect multiple by using comma (,)"
        $devices | ForEach {[PSCustomObject]$_} | Format-Table -AutoSize
        $selections = Read-Host "Devices" | % { $_.Split(",") }
        foreach ($selected in $selections) {
            try {
                $selectedDevice = $devices.Get($selected)
                $selectedSerial = $selectedDevice.Serial
                if ([string]::IsNullOrWhiteSpace($Package) -eq $false) {
                    $callStack += "Adb-Logcat -Package $Package -Device $selectedSerial"
                } else {
                    $callStack += "Adb-Logcat -Device $selectedSerial"
                }
            } catch {}
        }
        $joined = InternalSplitCommandsIntoPanes -commands $callStack
        Invoke-Expression $joined
    } elseif ([string]::IsNullOrWhiteSpace($Device)) {
        Write-Host "Connecting to logcat"
        Adb-Execute -parameter $(Internal-GetAdbLogcatParams -Package $Package)
    } else {
        Write-Host "Connecting to logcat" -ForegroundColor Yellow
        Adb-Execute -parameter "-s $Device $(Internal-GetAdbLogcatParams -Package $Package)"
    }

}

function Get-SelectedAdbDevices {
    $selectedSerials = @()
    $devices = Adb-GetDevices
    if ([string]::IsNullOrWhiteSpace($Device) -and $devices.Count -gt 1) {
        Write-Host "Please input desired device(s) to run wireless on.`n`tSelect multiple by using comma (,)"
        $devices | ForEach {[PSCustomObject]$_} | Format-Table -AutoSize
        $selections = Read-Host "Devices" | % { $_.Split(",") }

        foreach ($selected in $selections) {
            try {
                $selectedDevice = $devices.Get($selected)
                $selectedSerial = $selectedDevice.Serial
                $selectedSerials += $selectedSerial
            } catch {}
        }
    }
}





function Adb-StartWireless {
    $devices = Adb-GetDevices
    if ([string]::IsNullOrWhiteSpace($Device) -and $devices.Count -gt 1) {
        [array]$callStack = $()
        Write-Host "Please input desired device(s) to run wireless on.`n`tSelect multiple by using comma (,)"
        $devices | ForEach {[PSCustomObject]$_} | Format-Table -AutoSize
        $selections = Read-Host "Devices" | % { $_.Split(",") }
        foreach ($selected in $selections) {
            try {
                $selectedDevice = $devices.Get($selected)
                $selectedSerial = $selectedDevice.Serial
                $ip = Adb-Get -parameter $("-s $selectedSerial shell ip addr show wlan0 '|' grep -v 'inet6' '|' grep 'inet' '|' cut -d/ -f1 '|'  sed ''s/[^0-9.]*//g'' '|' xargs ")

                Adb-Execute -parameter $("-s $selectedSerial tcpip 5555")
                Adb-Execute -parameter $("connect " + $ip + ":5555")
            } catch {}
        }
    } elseif ([string]::IsNullOrWhiteSpace($Device)) {
        Write-Host "Obtaining IP"
        $ip = Adb-Get -parameter $("shell ip addr show wlan0 '|' grep -v 'inet6' '|' grep 'inet' '|' cut -d/ -f1 '|'  sed ''s/[^0-9.]*//g'' '|' xargs ")
        Write-Host "Enabling Wireless"
        Adb-Execute -parameter "tcpip 5555"
        Adb-Execute -parameter $("connect " + $ip + ":5555")
    } else {
        Write-Host "Obtaining IP"
        $ip = Adb-Get -parameter $("-s $Device shell ip addr show wlan0 '|' grep -v 'inet6' '|' grep 'inet' '|' cut -d/ -f1 '|'  sed ''s/[^0-9.]*//g'' '|' xargs ")
        Write-Host "Enabling Wireless"
        Adb-Execute -parameter "tcpip 5555"
        Adb-Execute -parameter $("connect " + $ip + ":5555")
    }
}






function Internal-GetAdbLogcatParams($Package) {
    $result = "logcat"
    #$result = "logcat AndroidRuntime:E *:S"
    if ([string]::IsNullOrWhiteSpace($Package) -eq $false) {
        $result = "logcat AndroidRuntime:E *:S $($Package):D $($Package):I $($Package):W $($Package):E"
    }
    Write-Host $result -ForegroundColor Magenta
    return $result
}

function Adb-LogcatOnDevice($device, $package) {
    if ([string]::IsNullOrWhiteSpace($device)) {
        return
    }
    $(Adb-Execute -parameter "-s $device logcat AndroidRuntime:E *:S $package:D $package:I $package:W $package:E")
}

function Adb-SetMode {
    param (
        [parameter(Mandatory=$true)]
        [ArgumentCompletions("light", "deep")]
        $Mode
    )
    if ($Mode -eq "light") {
        Adb-Execute -arg "shell dumpsys deviceidle step light"
    } elseif ($mode -eq "deep") {
        Adb-Execute -arg "shell dumpsys deviceidle step deep"
    } else {
        Write-Host "Correct Doze mode not supplied"
    }
}

function Adb-ClearDebugFlat() {
    
}


function InternalSplitCommandsIntoPanes($commands) {
    $expression = "wt"
    $pos = 0
    foreach ($command in $commands) {
        if ($pos -eq $commands.Count -1) {
            $expression += " split-pane powershell -noExit $command"
        } 
        elseif ($pos -eq 0)  {
            $expression += " powershell -noExit $command ``;"
        }
        else {
            $expression += " split-pane powershell -noExit $command ``;"
        }
        $pos += 1
    }

    return $expression
}

function Split() {
    # Erstatt Get-Process med string av kall
    wt powershell -noExit Get-Process `; split-pane powershell -noExit Get-Process `; split-pane powershell -noExit Get-Process
    
}

function Adb-ExecuteDebloat() {
    $packages = @(
        "com.facebook.appmanager",
        "com.facebook.katana",
        "com.facebook.services",
        "com.facebook.system"
    )
    foreach($package in $packages) {
        Invoke-Expression $($executionPath + " shell pm uninstall -k --user 0 " + $package)
    }
}

function global:color-logcat {
  Process {
    if ($_) {
      $color = "White"
      $fgcolor = "Black"

      if($_ -match [regex]"\s[V]\s") {
        $color = "Gray"
        #$fgcolor = "DarkBlue"
      }
      elseif($_ -match [regex]"\s[D]\s") {
        $color = "Green"
        #$fgcolor = "DarkBlue"
      }
      elseif($_ -match [regex]"\s[I]\s") {
        $color = "Cyan"
        #$fgcolor = "DarkBlue"
      }
      elseif($_ -match [regex]"\s[W]\s") {
        $color = "DarkYellow"
        #$fgcolor = "Blue"
      }
      elseif($_ -match [regex]"\s[E]\s") {
        $color = "Red"
        #$fgcolor = "Blue"
      }
      elseif($_ -match [regex]"\s[F]\s") {
        $color = "Magenta"
        #$fgcolor = "Blue"
      }  
      
        Write-host -foregroundcolor $color -backgroundcolor $fgcolor
    }
  }
}

Export-ModuleMember -Function Install-Adb
Export-ModuleMember -Function Adb-GetIP
Export-ModuleMember -Function Adb-Execute
Export-ModuleMember -Function Adb-Get
Export-ModuleMember -Function Adb-Devices
Export-ModuleMember -Function Adb-Logcat
Export-ModuleMember -Function Adb-StartWireless
