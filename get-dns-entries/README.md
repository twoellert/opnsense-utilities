# Get DNS Entries from OPNsense API
Get DNS entries from the unbound service of the OPNsense API and generate a HTML page.

Usually you would call this script via a cronjob to keep updating the page. Then display the page in your wiki or other resources.

Access to the DNS entries is done via the OPNSense API and the API Key of a dedicated user on the OPNSense.

For API keys and OPNsense hostnames check the script:
```
# The API key and secret to use as set in OPNSense
API_KEY="YOUR_API_KEY"
API_SECRET="YOUR_API_SECRET"

# Hostname of the OPNSense firewall
OPNSENSE_HOST="your.opnsense.hostname"
```