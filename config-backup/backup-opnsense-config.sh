#!/bin/bash
# Downloader Script for OPNSense Config via API
# Create a user at OPNSense first which has access to the "Backup Config API"

# Get script directory
SCRIPTDIR=$(dirname $(readlink -f $0))

# The API key and secret to use as set in OPNSense
API_KEY="YOUR_API_KEY"
API_SECRET="YOUR_API_SECRET"

# Hostname of the OPNSense firewall
OPNSENSE_HOST="your.opnsense.hostname"

# Directory to put the config file into
BACKUP_DIR="${SCRIPTDIR}/../backup"

# Binaries
BIN_CURL="/usr/bin/curl"
BIN_GIT="/usr/bin/git"

# Settings if the backup dir is a git repository and we should commit and push the new file into it
GIT_ENABLED=1
GIT_PRIVATEKEY_FILE="${SCRIPTDIR}/ssh-git-opnsense.key"

# Get the current date for naming the config file
DATE=$(date +%Y%m%d%H%M%S)

# Check if we have access to the API
RESULT=$(${BIN_CURL} -I -s -k -u "${API_KEY}":"${API_SECRET}" https://${OPNSENSE_HOST}/api/backup/backup/download | head -1)
if [[ $RESULT != *"200"* ]]; then
	echo "[ERROR] No access to API, result of the HTTP request is $RESULT"
	exit 1
fi

# Generate the final filename
FILENAME="config-${OPNSENSE_HOST}-${DATE}.xml"

# Backup file retention, maximum amount of backup files which are kept in the repository
BACKUP_MAX_FILES=60

# Make sure ssh key file is not too open in terms of permissions
`chmod 600 $GIT_PRIVATEKEY_FILE`

# Download the config
echo "[INFO] Downloading opnsense configuration ..."
${BIN_CURL} -s -k -u "${API_KEY}":"${API_SECRET}" https://${OPNSENSE_HOST}/api/backup/backup/download > ${BACKUP_DIR}/${FILENAME}
RETCODE=$?
if [ $RETCODE -ne 0 ] ; then
	echo "[ERROR] Failed to download config <returnCode=$RETCODE>"
	exit 1
fi

# Push to git if enabled
if [ $GIT_ENABLED -eq 1 ] ; then
	
	# Update the local git repository to make sure we have no merge issues
	echo "[INFO] Updating local git repository ..."
	OUT=`cd ${BACKUP_DIR}; GIT_SSH_COMMAND="ssh -i $GIT_PRIVATEKEY_FILE" ${BIN_GIT} pull`
        if [ $? -ne 0 ] ; then
                echo "[ERROR] Failed to add new config file to git repository"
                exit 1
        fi

	# Add the new config file to the git
	echo "[INFO] Adding new config file to local git repository ..."
	OUT=`cd ${BACKUP_DIR}; ${BIN_GIT} add ${BACKUP_DIR}/${FILENAME}`
	if [ $? -ne 0 ] ; then
		echo "[ERROR] Failed to add new config file to git repository"
		exit 1
	fi

	# Commit the file locally
	echo "[INFO] Committing changes ..."
	OUT=`cd ${BACKUP_DIR}; ${BIN_GIT} commit -m "Auto backup at ${DATE}"`
	if [ $? -ne 0 ] ; then
                echo "[ERROR] Failed to commit new config file to git repository"
                exit 1
        fi

	# Push the file to the server
	echo "[INFO] Pushing changes ..."
	OUT=`cd ${BACKUP_DIR}; GIT_SSH_COMMAND="ssh -i $GIT_PRIVATEKEY_FILE" ${BIN_GIT} push`
	if [ $? -ne 0 ] ; then
                echo "[ERROR] Failed to push new config file to git repository"
                exit 1
        fi

	# Apply backup file retention
	echo "[INFO] Applying backup file retention <maxFiles=$BACKUP_MAX_FILES> ..."
	
	BACKUP_REMOVED=0
	BACKUP_COUNTER=0
	BACKUPS=($(ls $BACKUP_DIR | sort -rt '-' -k 3))
	for BACKUP in "${BACKUPS[@]}"
	do
	        BACKUP_COUNTER=$((BACKUP_COUNTER+1))
	        if [ $BACKUP_COUNTER -gt $BACKUP_MAX_FILES ] ; then
	                echo "[INFO] Cleaning up backup file <$BACKUP>"
	                `rm -f ${BACKUP_DIR}/${BACKUP}`
	        fi

		# Add removal of file to git
		OUT=`cd ${BACKUP_DIR}; ${BIN_GIT} add ${BACKUP_DIR}/${BACKUP}`
		if [ $? -ne 0 ] ; then
                	echo "[ERROR] Failed to add removed old config file to git repository"
        	        exit 1
	        fi

		BACKUP_REMOVED=1
	done

	if [ $BACKUP_REMOVED -eq 1 ] ; then
                # Comitting changes
                echo "[INFO] Committing cleanup ..."
                OUT=`cd ${BACKUP_DIR}; ${BIN_GIT} commit -m "Cleaning up old backups at ${DATE}"`
                if [ $? -ne 0 ] ; then
                        echo "[ERROR] Failed to commit removed old config file to git repository"
                        exit 1
                fi

                # Push the removals to the server
                echo "[INFO] Pushing cleanup ..."
                OUT=`cd ${BACKUP_DIR}; GIT_SSH_COMMAND="ssh -i $GIT_PRIVATEKEY_FILE" ${BIN_GIT} push`
                if [ $? -ne 0 ] ; then
                        echo "[ERROR] Failed to push removed old config file to git repository"
                        exit 1
                fi
	fi
fi

exit 0
