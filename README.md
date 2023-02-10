# download-station.sh

## Description

This is a simple Bash shell script which can interface with a [Synology](https://www.synology.com/) download 
station via 
[API](https://global.download.synology.com/download/Document/Software/DeveloperGuide/Package/DownloadStation/All/enu/Synology_Download_Station_Web_API.pdf).

Working and tested on [DSM 7.1](https://www.synology.com/en-us/DSM71).

Can be used anywhere using a [tailscale](https://tailscale.com) mesh network (does not rely on QuickConnect).

## Use case

- Install script to the download station (not strictly necessary, could run locally or anywhere on tailscale mesh)
- Create a iOS shortcut which runs over SSH (add SSH key to [authorised keys](https://matsbauer.medium.com/how-to-run-ssh-terminal-commands-from-iphone-using-apple-shortcuts-ssh-29e868dccf22))
- Control downloads anywhere... add magnet link from share sheet...

## Installation

- [enable SSH access on download station](https://kb.synology.com/en-uk/DSM/help/DSM/AdminCenter/system_terminal?version=7)
- download files, unzip
- create a download-station.config file from the example provided
- copy them across (if there's no git installed)
```
$ scp -O download-station.sh user@synology.local:~
$ scp -O download-station.config user@synology.local:~
```
- ssh into the synology, make executable, and test:
```
$ chflags 755 download-station.sh	
$ ./download-station.sh list
```




