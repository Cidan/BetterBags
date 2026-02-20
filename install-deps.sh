#!/bin/bash
set -e

checkout_svn() {
  local url=$1
  local dest=$2
  if [ -d "$dest" ]; then
    echo "Updating SVN repository at $dest"
    svn update "$dest"
  else
    echo "Checking out SVN repository to $dest"
    svn checkout "$url" "$dest"
  fi
}

clone_git() {
  local url=$1
  local dest=$2
  if [ -d "$dest" ]; then
    echo "Updating Git repository at $dest"
    git -C "$dest" pull
  else
    echo "Cloning Git repository to $dest"
    git clone "$url" "$dest"
  fi
}

checkout_svn https://repos.wowace.com/wow/libstub/tags/1.0 ./libs/LibStub
checkout_svn https://repos.wowace.com/wow/callbackhandler/trunk/CallbackHandler-1.0 ./libs/CallbackHandler-1.0
checkout_svn https://repos.wowace.com/wow/ace3/trunk/AceAddon-3.0 ./libs/AceAddon-3.0
checkout_svn https://repos.wowace.com/wow/ace3/trunk/AceConfig-3.0 ./libs/AceConfig-3.0
checkout_svn https://repos.wowace.com/wow/ace3/trunk/AceConsole-3.0 ./libs/AceConsole-3.0
checkout_svn https://repos.wowace.com/wow/ace3/trunk/AceDB-3.0 ./libs/AceDB-3.0
checkout_svn https://repos.wowace.com/wow/ace3/trunk/AceDBOptions-3.0 ./libs/AceDBOptions-3.0
checkout_svn https://repos.wowace.com/wow/ace3/trunk/AceEvent-3.0 ./libs/AceEvent-3.0
# checkout_svn https://repos.wowace.com/wow/ace3/trunk/AceGUI-3.0 ./libs/AceGUI-3.0
checkout_svn https://repos.wowace.com/wow/ace3/trunk/AceHook-3.0 ./libs/AceHook-3.0
clone_git https://github.com/tekkub/libdatabroker-1-1 ./libs/LibDataBroker-1.1
clone_git https://github.com/wagoio/WagoAnalyticsShim.git ./libs/WagoAnalytics
checkout_svn https://repos.wowace.com/wow/libsharedmedia-3-0/trunk/LibSharedMedia-3.0 ./libs/LibSharedMedia-3.0
# checkout_svn https://repos.wowace.com/wow/ace-gui-3-0-shared-media-widgets/trunk/AceGUI-3.0-SharedMediaWidgets ./libs/AceGUI-3.0-SharedMediaWidgets
checkout_svn https://repos.curseforge.com/wow/libwindow-1-1/trunk/LibWindow-1.1 ./libs/LibWindow-1.1
checkout_svn https://repos.wowace.com/wow/libuidropdownmenu/trunk/LibUIDropDownMenu ./libs/LibUIDropDownMenu

# Clone vscode-wow-api for WoW API annotations
if [ ! -d ".libraries/vscode-wow-api" ]; then
  git clone https://github.com/Ketho/vscode-wow-api .libraries/vscode-wow-api
  cd .libraries/vscode-wow-api
  rm -rf .git
  find . -mindepth 1 -maxdepth 1 ! -name 'Annotations' -exec rm -rf {} +
  cd ../..
fi

# Clone wow-ui-source for Blizzard UI source code
if [ ! -d ".libraries/wow-ui-source" ]; then
  git clone https://github.com/Gethe/wow-ui-source .libraries/wow-ui-source
  cd .libraries/wow-ui-source
  rm -rf .git
  find . -mindepth 1 -maxdepth 1 ! -name 'Interface' -exec rm -rf {} +
  cd ../..
fi
