$webConfigFile = 'https://raw.githubusercontent.com/cloughney/installer/master/config.json'

function Get-Groups-From-Web {
    param ([string]$local:webConfigFile)

    $local:groups = @{}
    $local:webGroupConfig = (new-object net.webclient).downloadstring($webConfigFile) | convertfrom-json

    $webGroupConfig.groups | get-member -type noteproperty | % {
        $local:groupName = "$($_.Name)"
        $local:group = $webGroupConfig.groups."$($groupName)"

        $groups.Add($groupName, $group.apps)
    }

    $groups
}

function Get-Valid-Input {
    param ([string]$local:prompt, [string[]]$local:validOptions, [boolean]$local:displayOptions = $true)
    $local:answer = ''

     if ($displayOptions) {
        $prompt = "$($prompt) ("
        $validOptions | % {$local:index = 0} {
            $prompt = if ($index -eq 0) { "$($prompt)$($_)" } else { "$($prompt)/$($_)" }
            $index++
        }
        $prompt = "$($prompt))"
    }

    do {
        $answer = read-host -prompt $prompt
    } while (-not $validOptions.Contains($answer))

    $answer
}

function Get-Scoop-Path {
    $local:localPath = "$env:programdata.tolower()\scoop"
    $local:globalPath = "$env:USERPROFILE\scoop"
    $local:path = $null

    if ((Test-Path $localPath) -and (Get-Item $localPath) -is [System.IO.DirectoryInfo]) {
        $path = $localPath
    } elseif ((Test-Path $globalPath) -and (Get-Item $globalPath) -is [System.IO.DirectoryInfo]) {
        $path = $globalPath
    }

    if ($path -ne '') { "$($path)\shims\scoop" } else { $null }
}

function Install-Scoop {
    $local:scoop = get-scoop-path
    if ($scoop -eq $null) {
        write-host 'Installing scoop...'
        invoke-expression (new-object net.webclient).downloadstring('https://get.scoop.sh')
    } else {
        write-host "Existing installation of scoop found at $($scoop)"
    }

    $scoop
}

function List-Groups {
    param ([string[]]$local:groupNames)

    write-host ''
    write-host 'Available Groups:'
    write-host ''
    $groupNames | % { write-host "`t> $($_)" }
    write-host ''
}

function List-Apps {
    param ([string[]]$local:appNames)

    write-host ''
    $appNames | % { write-host "`t> $($_)" }
    write-host ''
}

function Select-Group {
    param ([Hashtable]$local:groups)

    $local:groupNames = $groups.GetEnumerator() | % { $_.Key }
    $local:selectedGroup = ''
    $local:listApps = $false
    $local:continueWithSelection = $true

    do {
        list-groups $groupNames
        $selectedGroup = get-valid-input 'Choose a group to install' $groupNames $false
        $continueWithSelection = $true

        if ((get-valid-input "List apps in group '$($selectedGroup)'?" $yn) -eq 'y') {
            list-apps $groups.Get_Item($selectedGroup)
            $continueWithSelection = ((get-valid-input 'Continue with this group?' $yn) -eq 'y')
        }
    } while (-not $continueWithSelection)

    $selectedGroup
}

function Install-Apps {
    param ([string]$local:scoop, [HashTable]$local:groups, [string]$local:groupName)

    $local:installAllApps = ((get-valid-input 'Install all apps in group?' $yn) -eq 'y')

    $groups.Get_Item($groupName).GetEnumerator() | % {
        if ($installAllApps -or ((get-valid-input "Install $($_)" $yn) -eq 'y')) {
            write-host "installing $($_)..."
            #& $scoop install $_
        }
    }

    write-host "Installation of group '$($groupName)' is complete."
    write-host ''
}

$yn = @('y', 'n')

clear

$groups = get-groups-from-web $webConfigFile
$scoop = install-scoop

do {
    $selectedGroup = select-group $groups
    install-apps $scoop $groups $selectedGroup
} while ((get-valid-input 'Install another group?' $yn) -eq 'y')
