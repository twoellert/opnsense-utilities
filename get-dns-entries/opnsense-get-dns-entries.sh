#!/bin/bash
# Get DHCP leases information from OPNSense via API
# Create a user at OPNSense first which has access to the "GUI All pages" type

# Get script directory
SCRIPTDIR=$(dirname $(readlink -f $0))

# The API key and secret to use as set in OPNSense
API_KEY="YOUR_API_KEY"
API_SECRET="YOUR_API_SECRET"

# Hostname of the OPNSense firewall
OPNSENSE_HOST="your.opnsense.hostname"

# Directory to put the config file into
BACKUP_DIR="${SCRIPTDIR}/.."

# Output HTML file
HTML_OUT="./dns-entries.html"

# Binaries
BIN_CURL="/usr/bin/curl"
BIN_JQ="/usr/bin/jq"
BIN_WGET="/usr/bin/wget"
BIN_DATE="/bin/date"

# Check binary requirements
if ! command -v $BIN_CURL &> /dev/null
then
	echo "[INFO] curl is not installed, aborting"
	exit 1
fi
if ! command -v $BIN_JQ &> /dev/null
then
        echo "[INFO] jq is not installed, aborting"
        exit 1
fi
if ! command -v $BIN_WGET &> /dev/null
then
        echo "[INFO] wget is not installed, aborting"
        exit 1
fi
if ! command -v $BIN_DATE &> /dev/null
then
        echo "[INFO] date is not installed, aborting"
        exit 1
fi

# Check if we have access to the API
echo "[INFO] Checking API availability ..."
RESULT=$(${BIN_CURL} -I -s -k -u "${API_KEY}":"${API_SECRET}" https://${OPNSENSE_HOST}/api/unbound/diagnostics/listlocaldata | head -1)
if [[ $RESULT != *"200"* ]]; then
	echo "[ERROR] No access to API, result of the HTTP request is $RESULT"
	exit 1
fi

# Download the config
echo "[INFO] Querying DNS leases from API ..."
ENTRIES=`${BIN_CURL} -s -k -u "${API_KEY}":"${API_SECRET}" https://${OPNSENSE_HOST}/api/unbound/diagnostics/listlocaldata`
RETCODE=$?
if [ $RETCODE -ne 0 ] ; then
	echo "[ERROR] Failed to get DHCP leases <returnCode=$RETCODE>"
	exit 1
fi

# Iterate all entries
AMOUNT_OF_ENTRIES=`grep -o 'name' <<< "$ENTRIES" | wc -l`

echo "[INFO] Found number of existing entries <$AMOUNT_OF_ENTRIES>"

echo "[INFO] Generating output HTML file <out=$HTML_OUT> ..."

# Generate header of output
DATE_CURRENT=`$BIN_DATE`
cat <<EOT > $HTML_OUT
<html>
    <head>
        <title>DNS Entries</title>
        <style>
		body {
  		    font-family: Arial, Helvetica, sans-serif
		}
                .styled-table thead tr {
                    background-color: #1976D2;
                    color: #ffffff;
                    text-align: left;
                }
                .styled-table thead th {
                    padding-top: 12px;
                    padding-bottom: 12px;
                    padding-left: 10px;
                }
                .styled-table tbody tr {
                    border-bottom: 1px solid #dddddd;
                }
                .styled-table tbody td {
                    padding-left: 10px;
                    padding-right: 10px;
                    padding-top: 5px;
                    padding-bottom: 5px;
                }
                .styled-table tbody tr:nth-of-type(even) {
                    background-color: #f3f3f3;
                }

                .styled-table tbody tr:hover {
                    background-color: #ddd;
                }

                .styled-table tbody tr:last-of-type {
                    border-bottom: 2px solid #1976D2;
                }

                .styled-table {
                    border-collapse: collapse;
                    margin: 25px 0;
                    font-size: 0.9em;
                    font-family: sans-serif;
                    min-width: 400px;
                }
        </style>
    </head>
    <script>
	function sortTable(n) {
	  var table, rows, switching, i, x, y, shouldSwitch, dir, switchcount = 0;
	  table = document.getElementById("dns-entries-table");
	  switching = true;
	  // Set the sorting direction to ascending:
	  dir = "asc";
	  /* Make a loop that will continue until
	  no switching has been done: */
	  while (switching) {
	    // Start by saying: no switching is done:
	    switching = false;
	    rows = table.rows;
	    /* Loop through all table rows (except the
	    first, which contains table headers): */
	    for (i = 1; i < (rows.length - 1); i++) {
	      // Start by saying there should be no switching:
	      shouldSwitch = false;
	      /* Get the two elements you want to compare,
	      one from current row and one from the next: */
	      x = rows[i].getElementsByTagName("TD")[n];
	      y = rows[i + 1].getElementsByTagName("TD")[n];
	      /* Check if the two rows should switch place,
	      based on the direction, asc or desc: */
	      if (dir == "asc") {
	        if (x.innerHTML.toLowerCase() > y.innerHTML.toLowerCase()) {
	          // If so, mark as a switch and break the loop:
	          shouldSwitch = true;
	          break;
	        }
	      } else if (dir == "desc") {
	        if (x.innerHTML.toLowerCase() < y.innerHTML.toLowerCase()) {
	          // If so, mark as a switch and break the loop:
	          shouldSwitch = true;
	          break;
	        }
	      }
	    }
	    if (shouldSwitch) {
	      /* If a switch has been marked, make the switch
	      and mark that a switch has been done: */
	      rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
	      switching = true;
	      // Each time a switch is done, increase this count by 1:
	      switchcount ++;
	    } else {
	      /* If no switching has been done AND the direction is "asc",
	      set the direction to "desc" and run the while loop again. */
	      if (switchcount == 0 && dir == "asc") {
	        dir = "desc";
	        switching = true;
	      }
	    }
	  }
	}
    </script>
    <body onload="sortTable(0)">
        <p>Generated at ${DATE_CURRENT}</p>
        <table class="styled-table" id="dns-entries-table">
            <thead>
                <tr>
                    <th onclick="sortTable(0)">Name</th>
                    <th onclick="sortTable(1)">IP Address</th>
                </tr>
            </thead>
            <tbody>
EOT

ENTRY_INDEX=0
while [ $ENTRY_INDEX -lt $AMOUNT_OF_ENTRIES ]
do
	# Extract info from the json entry
	ENTRY=`echo $ENTRIES | $BIN_JQ ".data[$ENTRY_INDEX]"`
	ENTRY_IP=`echo $ENTRY | $BIN_JQ ".value" | sed -e 's/^"//'  -e 's/"$//'`
	ENTRY_NAME=`echo $ENTRY | $BIN_JQ ".name" | sed -e 's/^"//'  -e 's/"$//'`

	# Ignore entries with "in-addr.arpa" in their name
	if [[ "$ENTRY_NAME" = *"in-addr.arpa"* ]] ; then
		let ENTRY_INDEX=ENTRY_INDEX+1
		continue;
	fi
	
	# Ignore entries with "localhost" in IP or name
	if [[ "$ENTRY_IP" = *"localhost"* ]] ; then
                let ENTRY_INDEX=ENTRY_INDEX+1
                continue;
        fi

	# Ignore entries with "ip6.arpa" in name
        if [[ "$ENTRY_NAME" = *"ip6.arpa"* ]] ; then
                let ENTRY_INDEX=ENTRY_INDEX+1
                continue;
        fi

	# Ignore any IPs not starting with "10." or "192."
	if [[ "$ENTRY_IP" != "10."* ]] ; then
		if [[ "$ENTRY_IP" != "192."* ]] ; then
			let ENTRY_INDEX=ENTRY_INDEX+1
			continue;
		fi
	fi

	# Ignore any names which are just "opnsense."
	if [[ "$ENTRY_NAME" = "opnsense." ]] ; then
                let ENTRY_INDEX=ENTRY_INDEX+1
		continue;
	fi

	# Remove the dot from the end of the name
	ENTRY_NAME=${ENTRY_NAME::-1}

cat <<EOT >> $HTML_OUT
            <tr>
                <td>$ENTRY_NAME</td>
                <td>$ENTRY_IP</td>
            </tr>
EOT

	let ENTRY_INDEX=ENTRY_INDEX+1
done

# Generate footer of output
cat <<EOT >> $HTML_OUT
            </tbody>
        </table>
    </body>
</html>
EOT

exit 0
