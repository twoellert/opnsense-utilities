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

# URL to IEEE vendor list
IEEE_VENDOR_URL="http://standards-oui.ieee.org/oui.txt"
IEEE_VENDOR_FILE="./oui.txt"

# Allowed age of existing IEEE vendor list file in seconds (one week)
IEEE_MAX_AGE=604800

# Output HTML file
HTML_OUT="./leases.html"

# Only show IP addresses in this subnet
SHOW_SUBNET="10."

# Binaries
BIN_CURL="/usr/bin/curl"
BIN_JQ="/usr/bin/jq"
BIN_WGET="/usr/bin/wget"
BIN_DATE="/bin/date"
BIN_BC="/usr/bin/bc"

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
if ! command -v $BIN_BC &> /dev/null
then
        echo "[INFO] bc is not installed, aborting"
        exit 1
fi

# Check if we have access to the API
echo "[INFO] Checking API availability ..."
RESULT=$(${BIN_CURL} -I -s -k -u "${API_KEY}":"${API_SECRET}" https://${OPNSENSE_HOST}/api/dhcpleases/dhcpleases/leases | head -1)
if [[ $RESULT != *"200"* ]]; then
	echo "[ERROR] No access to API, result of the HTTP request is $RESULT"
	exit 1
fi

# Download the config
echo "[INFO] Querying DHCP leases from API ..."
LEASES=`${BIN_CURL} -s -k -u "${API_KEY}":"${API_SECRET}" https://${OPNSENSE_HOST}/api/dhcpleases/dhcpleases/leases`
RETCODE=$?
if [ $RETCODE -ne 0 ] ; then
	echo "[ERROR] Failed to get DHCP leases <returnCode=$RETCODE>"
	exit 1
fi

# Iterate all leases
AMOUNT_OF_LEASES=`grep -o 'mac-address' <<< "$LEASES" | wc -l`

echo "[INFO] Found number of existing leases <$AMOUNT_OF_LEASES>"

# Check age of IEEE vendor list file
UPDATE_IEEE_VENDORS=0

if [ ! -f $IEEE_VENDOR_FILE ] ; then
	# Does not exist, update it
	echo "[INFO] IEEE vendor file does not exist, updating <file=${IEEE_VENDOR_FILE}>"
	UPDATE_IEEE_VENDORS=1
else
	# It does exist check its age
	TIME_FILE=`${BIN_DATE} -r ${IEEE_VENDOR_FILE} +%s`
	TIME_CURRENT=`${BIN_DATE} +%s`
	TIME_DIFF=`echo "${TIME_CURRENT}-${TIME_FILE}" | $BIN_BC`
	echo "[INFO] Found existing IEEE vendor file <timeFile=$TIME_FILE><timeCurrent=$TIME_CURRENT><timeDiff=$TIME_DIFF><maxAge=$IEEE_MAX_AGE>"

	if [ $TIME_DIFF -gt $IEEE_MAX_AGE ] ; then
		echo "[INFO] IEEE vendor file too old, updating <diff=$TIME_DIFF>"
		UPDATE_IEEE_VENDORS=1
	else
		echo "[INFO] IEEE vendor file age is okay"
	fi
fi

if [ $UPDATE_IEEE_VENDORS -eq 1 ] ; then
	# Download the IEEE vendor list file
	echo "[INFO] Updating IEEE vendor list <url=${IEEE_VENDOR_URL}><file=${IEEE_VENDOR_FILE}>"

	# Remove the old file
	if [ ! -z $IEEE_VENDOR_FILE ] ; then
		`rm -f ${IEEE_VENDOR_FILE}`
	fi

	# Download the new file
	OUT=`${BIN_WGET} -q -O ${IEEE_VENDOR_FILE} ${IEEE_VENDOR_URL}`
	if [ $? -ne 0 ] ; then
		echo "[ERROR] Failure downloading the IEEE vendor list, aborting"
		exit 1
	fi
fi

echo "[INFO] Generating output HTML file <out=$HTML_OUT> ..."

# Generate header of output
DATE_CURRENT=`$BIN_DATE`
cat <<EOT > $HTML_OUT
<html>
    <head>
        <title>DHCP Leases</title>
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
	  table = document.getElementById("dhcp-leases-table");
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
        <table class="styled-table" id="dhcp-leases-table">
            <thead>
                <tr>
                    <th onclick="sortTable(0)">IP Address</th>
                    <th onclick="sortTable(1)">MAC Address</th>
                    <th onclick="sortTable(2)">Vendor</th>
                    <th onclick="sortTable(3)">Hostname</th>
                    <th onclick="sortTable(4)">Start Time</th>
                    <th onclick="sortTable(5)">End Time</th>
                </tr>
            </thead>
            <tbody>
EOT

LEASE_INDEX=0
while [ $LEASE_INDEX -lt $AMOUNT_OF_LEASES ]
do
	# Extract info from the json entry
	LEASE=`echo $LEASES | $BIN_JQ ".[$LEASE_INDEX]"`
	LEASE_IP=`echo $LEASE | $BIN_JQ ".address" | sed -e 's/^"//'  -e 's/"$//'`
	START_TIME=`echo $LEASE | $BIN_JQ ".starts" | sed -e 's/^"//'  -e 's/"$//'`
	END_TIME=`echo $LEASE | $BIN_JQ ".ends" | sed -e 's/^"//'  -e 's/"$//'`
	MAC_ADDRESS=`echo $LEASE | $BIN_JQ '.hardware."mac-address"' | sed -e 's/^"//'  -e 's/"$//'`
	CLIENT_HOSTNAME=`echo $LEASE | $BIN_JQ '."client-hostname"' | sed -e 's/^"//'  -e 's/"$//'`

	# Check if we should even show this IP
	if [[ "$LEASE_IP" != "${SHOW_SUBNET}"* ]] ; then
		echo "[INFO] Hide IP <$LEASE_IP><showSubnet=$SHOW_SUBNET> ..."
		let LEASE_INDEX=LEASE_INDEX+1
		continue;
	fi

	# Look up the vendor
	VENDOR_LOOKUP=`echo $MAC_ADDRESS | tr -d ':' | head -c 6`
	VENDOR=`grep -i "$VENDOR_LOOKUP" ./oui.txt | cut -d')' -f2 | tr -d '\t'`

	# Convert timestamps to something readable
	START_TIME_CONV=""
	END_TIME_CONV=""

	if [ "$START_TIME" != "null" ] ; then
		START_TIME_CONV=`$BIN_DATE -d @${START_TIME} +'%Y/%m/%d - %H:%M:%S'`
	fi
	if [ "$END_TIME" != "null" ] ; then
		END_TIME_CONV=`$BIN_DATE -d @${END_TIME} +'%Y/%m/%d - %H:%M:%S'`
	fi

	# Client Hostname might be null
	if [ "$CLIENT_HOSTNAME" = "null" ] ; then
		CLIENT_HOSTNAME=""
	fi

cat <<EOT >> $HTML_OUT
            <tr>
                <td>$LEASE_IP</td>
                <td>$MAC_ADDRESS</td>
                <td>$VENDOR</td>
                <td>$CLIENT_HOSTNAME</td>
                <td>$START_TIME_CONV</td>
                <td>$END_TIME_CONV</td>
            </tr>
EOT

	let LEASE_INDEX=LEASE_INDEX+1
done

# Generate footer of output
cat <<EOT >> $HTML_OUT
            </tbody>
        </table>
    </body>
</html>
EOT

exit 0
