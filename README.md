# Minecraft Backup
Differential backup script for Linux servers running a Minecraft server in tmux using duplicity

### Disclaimer
Backups are essential to the integrity of your Minecraft world. You should automate regular backups and **check that your backups work**. While this script has been used in production for several years, it is up to you to make sure that your backups work and that you have a reliable backup policy. 

Please refer to the LICENSE (MIT License) for the full legal disclaimer.

## Features
- Create backups of your world folder
- Configurable number of full backups to keep
- Able to print backup status and info to the Minecraft chat

## Requirements
- Linux computer (tested on CentOS)
- tmux (running your Minecraft server)
- rsync (remote backup sync)
- duplictiy (differential backup binary)
- Minecraft server (tested with Vanilla 1.14.4)

## Installation
1. Download the script: `$ wget https://raw.githubusercontent.com/nicolaschan/minecraft-backup/master/backup.sh`
2. Mark as executable: `$ chmod +x backup.sh`
3. Use the command line options or configure default values at the top of `backup.sh`:

Command line options:
```text
-c    Enable chat messages
-f    Output file name (default is the timestamp)
-h    Shows this help text
-i    Input directory (path to world folder)
-o    Output directory
-p    Prefix that shows in Minecraft chat (default: Backup)
-q    Suppress warnings
-s    Minecraft server tmux session name
-v    Verbose mode
```

Example usage of command line options:
```bash
./backup.sh -c -i /home/server/minecraft-server/world -o /mnt/external-storage/minecraft-backups -r username@remote_host:destination_directory -s minecraft
```
This will use show chat messages (`-c`) in the screen called "minecraft" and save a backup of `/home/server/minecraft-server/world` into `/mnt/external-storage/minecraft-backups` and rsync it into `username@remote_host:destination_directory`.

By default it will do a full backup if the last full backup is older than 2 weeks, and keep 2 full backup cycles.

4. Create a cron job to automatically backup:
    - Edit the crontab: `$ crontab -e`
    - Example for hourly backups: `00 * * * * /path/to/backup.sh`
  
## Retrieving Backups
Follow duplicity docs to learn how to restore your server

## Help
- Make sure cron has permissions for all the files involved and access to the Minecraft server's GNU Screen
- Do not put trailing `/` in the `SERVER_DIRECTORY` or `BACKUP_DIRECTORY`
