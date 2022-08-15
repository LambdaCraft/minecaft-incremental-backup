#!/bin/bash

# Minecraft server automatic backup management script
# by Nicolas Chan & Lambdacraft
# MIT License
#
# For Minecraft servers running in a tmux.
# For most convenience, run automatically with cron.

# Default Configuration 
ENABLE_CHAT_MESSAGES=false # Tell players in Minecraft chat about backup status
PREFIX="Backup" # Shows in the chat message
DEBUG=false # Enable debug messages
SUPPRESS_WARNINGS=false # Suppress warnings
BK_KEEP_FULL="2"  # How many full+inc cycle to keep
# Following option takes an interval, which is a number followed by one of the characters s, m, h, D, W, M, or Y (indicating seconds, minutes, hours, days, weeks, months, or years respectively)
BK_FULL_FREQ="2W" # create a new full backup every...

# Required Configuration
SESSION_PANE_NAME="" # Name of the tmux session and pane your Minecraft server is running in, ex. minecraft.0
DATA_DIR="" # Fully qualified directory of data to backup, be careful not to put a trailing slash, ex: /root/tobackup and not /root/tobackup/
LOCAL_BACKUP_DIRECTORY="" # Directory to save backups in
REMOTE_BACKUP_DIRECTORY="" # URL to remote backup folder, ex: username@remote_host:destination_directory

# Advanced
PREFIX_CMD="nice -n18 ionice -c 3"

# Other Variables (do not modify)
DATE_FORMAT="%F_%H-%M-%S"
TIMESTAMP=$(date +$DATE_FORMAT)

while getopts 'a:cd:e:f:hi:l:m:o:p:qs:r:v' FLAG; do
  case $FLAG in
    c) ENABLE_CHAT_MESSAGES=true ;;
    # e) COMPRESSION_FILE_EXTENSION=".$OPTARG" ;;
    f) TIMESTAMP=$OPTARG ;;
    h) echo "Minecraft Backup"
       echo "-c    Enable chat messages"
       echo "-f    Output file name (default is the timestamp)"
       echo "-h    Shows this help text"
       echo "-i    Input directory (path to world folder)"
       echo "-o    Output directory"
       echo "-p    Prefix that shows in Minecraft chat (default: Backup)"
       echo "-q    Suppress warnings"
       echo "-r    Remote directory"
       echo "-s    Minecraft server tmux session name"
       echo "-v    Verbose mode"
       exit 0
       ;;
    i) DATA_DIR=$OPTARG ;;
    o) LOCAL_BACKUP_DIRECTORY=$OPTARG ;;
    p) PREFIX=$OPTARG ;;
    q) SUPPRESS_WARNINGS=true ;;
    r) REMOTE_BACKUP_DIRECTORY=$OPTARG ;;
    s) SESSION_PANE_NAME=$OPTARG ;;
    v) DEBUG=true ;;
  esac
done

log-fatal () {
  echo -e "\033[0;31mFATAL:\033[0m $*"
}
log-warning () {
  echo -e "\033[0;33mWARNING:\033[0m $*"
}

# Check for missing dependencies
FATAL=false
if ! hash rsync || ! hash duplicity || ! hash tmux; then
  log-fatal "Missing required dependency"
  FATAL=true
fi

# Check for missing encouraged arguments
if [[ $SESSION_PANE_NAME == "" ]]; then
  log-fatal "Minecraft tmux session name not specified (use -s)"
  FATAL=true
fi
# Check for required arguments

if [[ $DATA_DIR == "" ]]; then
  log-fatal "Server data directory not specified (use -i)"
  FATAL=true
fi

if [[ $LOCAL_BACKUP_DIRECTORY == "" ]]; then
  log-fatal "Local backup directory not specified (use -o)"
  FATAL=true
fi

if [[ $REMOTE_BACKUP_DIRECTORY == "" ]]; then
  log-fatal "Remote backup directory not specified (use -r)"
  FATAL=true
fi

if $FATAL; then
  exit 0
fi

# Minecraft server screen interface functions
message-players () {
  local MESSAGE=$1
  local HOVER_MESSAGE=$2
  message-players-color "$MESSAGE" "$HOVER_MESSAGE" "gray"
}
execute-command () {
  local COMMAND=$1
  if [[ $SESSION_PANE_NAME != "" ]]; then
    tmux send-keys -t $SESSION_PANE_NAME "$COMMAND" ENTER
  fi
}
message-players-error () {
  local MESSAGE=$1
  local HOVER_MESSAGE=$2
  message-players-color "$MESSAGE" "$HOVER_MESSAGE" "red"
}
message-players-success () {
  local MESSAGE=$1
  local HOVER_MESSAGE=$2
  message-players-color "$MESSAGE" "$HOVER_MESSAGE" "green"
}
message-players-color () {
  local MESSAGE=$1
  local HOVER_MESSAGE=$2
  local COLOR=$3
  if $DEBUG; then
    echo "$MESSAGE ($HOVER_MESSAGE)"
  fi
  if $ENABLE_CHAT_MESSAGES; then
    execute-command "tellraw @a [\"\",{\"text\":\"[$PREFIX] \",\"color\":\"gray\",\"italic\":true},{\"text\":\"$MESSAGE\",\"color\":\"$COLOR\",\"italic\":true,\"hoverEvent\":{\"action\":\"show_text\",\"value\":{\"text\":\"\",\"extra\":[{\"text\":\"$HOVER_MESSAGE\"}]}}}]"
  fi
}

# Warn players
message-players "Backup starting in 5 minutes"
sleep 4m

# Save the world
execute-command "save-all"
# wait for save to finish
sleep 1m

# Disable world autosaving
execute-command "save-off"

# Notify players of start
message-players "Starting backup..." "$ARCHIVE_FILE_NAME"

# Backup world
LOCAL_DUP_DIR="file://$LOCAL_BACKUP_DIRECTORY"
START_TIME=$(date +"%s")

${PREFIX_CMD} duplicity --no-encryption --allow-source-mismatch --full-if-older-than $BK_FULL_FREQ $DATA_DIR $LOCAL_DUP_DIR
${PREFIX_CMD} duplicity --allow-source-mismatch remove-all-but-n-full $BK_KEEP_FULL --force $LOCAL_DUP_DIR

if ! rsync -avh -e "ssh" "$LOCAL_BACKUP_DIRECTORY/" $REMOTE_BACKUP_DIRECTORY --delete ; then
  message-players-error "Failed to transfer backup to remote server"
fi

sync

END_TIME=$(date +"%s")

# Enable world autosaving
execute-command "save-on"

# Notify players of completion
TIME_DELTA=$((END_TIME - START_TIME))

message-players-success "Backup complete!" "$TIME_DELTA s"
