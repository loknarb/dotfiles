# Requires -RunAsAdministrator
# In case of error due to permissions do
# Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -y
# Windows Setup Script

# Error handling
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Status {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Set-CustomRegistryKeys {
    Write-Host "Applying custom registry modifications..."

    $registryChanges = @(
        # Snap-related settings
        @{
            Path = "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Name = "SnapFill"
            Type = "REG_DWORD"
            Value = "0"
        },
        @{
            Path = "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Name = "SnapAssist"
            Type = "REG_DWORD"
            Value = "0"
        },
        @{
            Path = "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Name = "JointResize"
            Type = "REG_DWORD"
            Value = "0"
        },
        # System policies and keyboard layout
        @{
            Path = "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\System"
            Name = "DisableLockWorkstation"
            Type = "REG_DWORD"
            Value = "1"
        },
        @{
            Path = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout"
            Name = "Scancode Map"
            Type = "REG_BINARY"
            Value = "0000000000000000030000001d005be05be01d0000000000"
        },
        @{
            Path = "HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Windows\Explorer"
            Name = "DisableNotificationCenter"
            Type = "REG_DWORD"
            Value = "1"
        }
    )

    foreach ($change in $registryChanges) {
        try {
            $registryPath = $change.Path -replace "^HKEY_LOCAL_MACHINE\\", "HKLM:\" -replace "^HKEY_CURRENT_USER\\", "HKCU:\"
            
            if ($change.Type -eq "REG_BINARY") {
                # Use reg.exe for binary values as they're easier to handle this way
                $result = reg add $change.Path /v $change.Name /t $change.Type /d $change.Value /f
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Successfully applied binary registry change: $($change.Path)\$($change.Name)" -ForegroundColor Green
                } else {
                    throw "reg.exe command failed with exit code $LASTEXITCODE"
                }
            } else {
                # Use PowerShell commands for non-binary values
                if (!(Test-Path "Registry::$($change.Path)")) {
                    New-Item -Path "Registry::$($change.Path)" -Force | Out-Null
                }
                Set-ItemProperty -Path "Registry::$($change.Path)" -Name $change.Name -Value $change.Value -Type DWord -Force
                Write-Host "Successfully applied registry change: $($change.Path)\$($change.Name)" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "Failed to apply registry change $($change.Path)\$($change.Name): $_"
        }
    }
}





function Install-WingetPackages {
    Write-Status "Installing Winget packages"
    # these can be installed with --scope machine
    $wingetPackages = @(
        'Microsoft.VCRedist.2015+.x64',
        '7zip.7zip',
        'SumatraPDF.SumatraPDF',
        'VideoLAN.VLC',
        'Mozilla.Firefox',
        'TheBrowserCompany.Arc',
        'AutoHotkey.AutoHotkey',
        'Bitwarden.Bitwarden',
        'Microsoft.VisualStudioCode',
        'Spotify.Spotify',
        'Anki.Anki',
        'DeepL.DeepL',
        'Microsoft.PowerToys',
        'Valve.Steam',
        'ShareX.ShareX',
        'Obsidian.Obsidian',
        'Flow-Launcher.Flow-Launcher',
        'JesseDuffield.lazygit',
        'gokcehan.lf',
        'calibre.calibre'
    )
    # these currently cannot be installed with --scope machine
    $wingetNoScopePackages = @(
        'Flow-Launcher.Flow-Launcher',
        'Discord.Discord'
    )

    foreach ($package in $wingetPackages) {
        try {
            Write-Host "Installing ${package}..."
            winget install --source winget --id $package --scope machine --silent --no-upgrade
        }
        catch {
            Write-Warning "Failed to install ${package}: $_"
        }
    }
    
    foreach ($noScopePackage in $wingetNoScopePackages) {
        try {
            Write-Host "Installing ${noScopePackage}..."
            winget install --source winget --id $noScopePackage --silent --no-upgrade
        }
        catch {
            Write-Warning "Failed to install ${noScopePackage}: $_"
        }
    }
}

function Install-NerdFont {
    param(
        [string]$FontName = 'CascadiaCode'
    )
    Write-Status "Installing $FontName Nerd Font"

    $tempPath = Join-Path $env:TEMP $FontName
    $zipPath = "$tempPath.zip"

    try {
        # Get latest version
        $nerdFontsUri = 'https://github.com/ryanoasis/nerd-fonts/releases'
        $webResponse = Invoke-WebRequest -Uri "$nerdFontsUri/latest" -MaximumRedirection 0 -ErrorAction SilentlyContinue
        $latestVersion = Split-Path -Path $webResponse.Headers.Location -Leaf

        # Download and extract
        $downloadUrl = "$nerdFontsUri/download/$latestVersion/$FontName.zip"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $tempPath -Force

        # Install fontjis
        $fonts = (New-Object -ComObject Shell.Application).Namespace(0x14)
        Get-ChildItem -Path $tempPath -Include '*.ttf', '*.otf' -Recurse | ForEach-Object {
            $fonts.CopyHere($_.FullName)
        }
    }
    catch {
        erite-Error "Failed to install font: $_"
    }
    finally {
        # Cleanup
        Remove-Item -Path $zipPath -ErrorAction SilentlyContinue
        Remove-Item -Path $tempPath -Recurse -ErrorAction SilentlyContinue
    }
}

function Remove-UnwantedApps {
    Write-Status "Removing unwanted Windows apps"
    # Remove some default apps I don't use
    @(
    'Microsoft.WindowsFeedbackHub',
    'Microsoft.GetHelp'
    'Microsoft.Getstarted',
    'Microsoft.MixedReality.Portal',
    'Microsoft.SkypeApp',
    'Microsoft.Microsoft3DViewer',
    'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.XboxApp'
  ) | Foreach-Object { Get-AppxPackage -Name $_ | Remove-AppxPackage }
}
function Remove-UnwantedWingetApps {
    Write-Status "Removing unwanted Windows apps"
    # Remove some default apps I don't use
    $wingetPackages = @(
        'Copilot',
        'Microsoft Bing',
        'News',
        'Windows Web Experience Pack', # stupid widget stuff
        'Xbox TCUI',
        'Xbox Game Bar Plugin',
        'Quick Assist',
        'Microsoft To Do',
        'Quick Assist',
        'Outlook for Windows'
        'Game Bar',
        'Xbox Identity Provider',
        'Phone Link', # remove this if you desperately want the compatability
        'Microsoft Family',
        'Game Speech Window',
        'Xbox'
    ) 
    foreach ($package in $wingetPackages) {
        try {
            Write-Host "Uninstalling ${package}..."
            winget uninstall -q $package
        }
        catch {
            Write-Warning "Failed to uninstall ${package}: $_"
        }
    }
}

function Install-AutoHotkeyScript {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GitRepoUrl,
        [string]$ScriptName = "script.ahk",
        [string]$BranchName = "main"
    )
    
    Write-Host "Setting up AutoHotkey script from $GitRepoUrl"
    
    # Define paths
    $startupFolder = [System.IO.Path]::Combine([Environment]::GetFolderPath("Startup"))
    $scriptsFolder = [System.IO.Path]::Combine($env:USERPROFILE, "dotfiles")
    
    try {
        # Create scripts directory if it doesn't exist
        if (!(Test-Path $scriptsFolder)) {
            New-Item -ItemType Directory -Path $scriptsFolder | Out-Null
        }
        
        # Clone or pull the repository
        Push-Location $scriptsFolder
        if (!(Test-Path ".git")) {
            Write-Host "Cloning repository..."
            git clone --branch $BranchName $GitRepoUrl .
        } else {
            Write-Host "Updating repository..."
            git pull origin $BranchName
        }
        Pop-Location
        
        # Create shortcut in startup folder
        $scriptPath = Join-Path $scriptsFolder $ScriptName
        $shortcutPath = Join-Path $startupFolder "$([System.IO.Path]::GetFileNameWithoutExtension($ScriptName)).lnk"
        
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)
        $Shortcut.TargetPath = $scriptPath
        $Shortcut.Save()
        
        Write-Host "Script installed successfully and will run at startup"
        
        # Start the script now
        if (Test-Path $scriptPath) {
            Start-Process $scriptPath
            Write-Host "Script started"
        }
    }
    catch {
        Write-Error "Failed to set up AutoHotkey script: $_"
    }
}

function Install-WSL {
    # wsl --manage <distro_name> --move <new_location>
    Write-Status "Setting up WSL2 with Ubuntu-24.04"

    try {
        # Check if WSL is already installed
        $wslCheck = wsl --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Installing WSL..."

	        wsl --update
            
            Write-Warning "WSL installation completed. A system restart may be required before proceeding with Ubuntu setup."
            return
        }
        wsl --install Ubuntu-24.04

        wsl --shutdown 
        # personalised to actually go to my biggest disk (maybe if you copied this dont do this..)
        $newLocation = 'D:\WSL\'
        wsl --manage Ubuntu-24.04 --move $newLocation

        # Set permissions on the new location this stops us from getting a Access is denied
        $acl = Get-Acl $newLocation
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.SetAccessRule($accessRule)
        Set-Acl $newLocation $acl

        # Setup Ubuntu environment
        Write-Host "Setting up Ubuntu environment..."
                wsl -d Ubuntu-24.04 -e bash -c "sudo useradd -m -s /bin/bash -G sudo --disabled-password seb"

                wsl -d Ubuntu-24.04 -e bash -c "git clone https://github.com/loknarb/dotfiles ~/dotfiles"

                
                

                wsl -d Ubuntu-24.04 -e bash -c "sudo apt install -y zsh"

                wsl -d Ubuntu-24.04 -e bash -c "sudo apt update && sudo apt install -y git curl && curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k"

                wsl -d Ubuntu-24.04 -e bash -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
                wsl -d Ubuntu-24.04 -e bash -c "git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
                # this is for the current ohmyzsh cloning I'll already have my profile 
                wsl -d Ubuntu-24.04 -e bash -c "rm ~/.zshrc"
                
                

                # symlink for batcat to bat
                wsl -d Ubuntu-24.04 -e bash -c "sudo apt install -y lf fzf ripgrep bat && mkdir -p ~/.local/bin && ln -s /usr/bin/batcat ~/.local/bin/bat"
                # install nvm or node in this linux
                wsl -d Ubuntu-24.04 -e bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"

                # symlinks  
                wsl -d Ubuntu-24.04 -e bash -c "ln -s ~/dotfiles/.gitconfig ~/.gitconfig && ln -s ~/dotfiles/.gitconfig-work ~/.gitconfig-work && ln -s ~/dotfiles/.gitconfig-personal ~/.gitconfig-personal && ln -s ~/dotfiles/.zshrc ~/.zshrc"


                wsl -d Ubuntu-24.04 -e bash -c "mkdir ~/work && mkdir ~/personal && code ~"


    }
    catch {
        Write-Error "WSL setup failed: $_"
    }
}

# Main execution
try {
    # Check for admin rights
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script requires administrator privileges. Please run as administrator."
    }

    #Set-CustomRegistryKeys
    #Install-WingetPackages
    #Install-NerdFont -FontName 'CascadiaCode'
    #Remove-UnwantedApps
    #Remove-UnwantedWingetApps
    Install-WSL

    #Install-AutoHotkeyScript -GitRepoUrl "https://github.com/loknarb/dotfiles" -ScriptName "coding_keybinds.ahk"

    Write-Status "Setup completed successfully!"
    Write-Warning "Some changes may require a system restart to take effect."
}
catch {
    Write-Error "Setup failed: $_"
    exit 1
}

