# OPNsense Config Backups
Can be run via a cronjob to automatically backup your whole opnsense config in a file and push it to a git repository of yours.

For API keys and OPNsense hostnames check the script:
```
# The API key and secret to use as set in OPNSense
API_KEY="YOUR_API_KEY"
API_SECRET="YOUR_API_SECRET"

# Hostname of the OPNSense firewall
OPNSENSE_HOST="your.opnsense.hostname"
```

It is accessing the OPNSense via an API key. Access to the git repository - in order to store the downloaded config - is done via a private SSH key of a user which has access to your repository.
If you want to enable that and info related to your git key check the script here:
```
# Settings if the backup dir is a git repository and we should commit and push the new file into it
GIT_ENABLED=1
GIT_PRIVATEKEY_FILE="${SCRIPTDIR}/ssh-git-opnsense.key"
```

The script is configured to only keep a certain amount of backups of the past config:
```
# Backup file retention, maximum amount of backup files which are kept in the repository
BACKUP_MAX_FILES=60
```
