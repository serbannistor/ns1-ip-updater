NS1 IP Updater
--------------

Simple bash script that updates a given [NS1](https://ns1.com/) type A DNS record with either the current public (WAN) IP address of the host it runs on or a manually given IP address.

It uses either Google or OpenDNS to resolve the host's public IP address using the Linux `dig` command ([Domain Information Groper](https://en.wikipedia.org/wiki/Dig_(command))).

## Prerequisites

* `bash`
* `dig`
* `curl`
* GNU `getopt` (GNU `getopt` is the default on Linux. MacOS and FreeBSD come with an amputated version of `getopt`, however the GNU version can still be installed and used)
* a NS1 account with:
  * a zone configured
  * a record with a type A response configured within that zone
  * an API key which has access to modify that zone

## Usage

### Command line

`ns1-ip-updater.sh [OPTION [OPTION [...]]]`
* `-c` or `--config=CONFIG_FILE` (mutually exclusive): Use a config file (see `config_sample`) instead of command line arguments. Command line parameters override the ones in the config file, if present (see below)
* `-a` or `--api-key=API_KEY` (overrides): NS1 API key to be used for authentication
* `-z` or `--zone=ZONE` (overrides): NS1 zone to be updated. Must be used together with the -r or --record and -t or --record-type parameters, otherwise the script halts
* `-r` or `--record=RECORD` (overrides): NS1 record to be updated. Must be used together with the -z or --zone and -t or --record-type parameters, otherwise the script halts
* `-t` or `--record-type=TYPE` (overrides): NS1 record type to be updated. Must be used together with the -z or --zone and -r or --record parameters, otherwise the script halts. Only record type A is supported currently.
* `-i` or `--ip=IP_ADDRESS` (optional): Do not attempt to determine the current WAN IP address, but use the one provided
* `-f` or `--force` (optional): Force updating the NS1 zone even if the current IP address seems to match the previously updated one (cached locally)
* `-l` or `--log-level=LEVEL` (optional): Log level to be used by the program. Can be either one of: 'debug', 'info', 'warn', 'error'. Default is 'error' (least verbose)
* `-h` or `--help` (optional): Display the usage and exits gracefully

### Configuration file

The script supports setting the parameters through a plain text configuration file. A sample containing the parameters supported can be found in `config_sample`.
* `NS1_ZONE`: Same as the `-z` or `--zone` option from command line
* `NS1_RECORD`: Same as the `-r` or `--record` option from command line
* `NS1_RECORD_TYPE`: Same as the `-t` or `--record-type` option from command line
* `NS1_API_KEY`: Same as the `-a` or `--api-key` option from command line
* `CURRENT_IP`: Same as the `-i` or `--ip` option from command line
* `FORCE`: Same as the `-f` or `--force` option from command line
* `LOG_LEVEL`: Same as the `-l` or `--log-level=LEVEL` option from command line

**WARNING:** All parameters set in the configuration file can be overridden through CLI. For example, if you set `CURRENT_IP` to be `127.0.0.1` in the configuration file and then you launch the script with `ns1-ip-updater.sh -c config -i 1.2.3.4` the value of the `CURRENT_IP` in the configuration file will be overridden by the one from command line, hence `1.2.3.4` will be finally used, and the script will no longer attempt to determine the real public IP address using either Google or OpenDNS.

### Examples of usage

* `ns1-ip-updater.sh -z example.com -r foo.bar.example.com -t A -a aBcDeFgHiJkLmNoPqR -l debug` will use the `aBcDeFgHiJkLmNoPqR` NS1 API key to update the `foo.bar.example.com` NS1 type A DNS record in the `example.com` zone and cause the script to verbose every operation
* `ns1-ip-updater.sh -c /path/to/config` will attempt to load the parameters from the file at `/path/to/config` and use those while keeping the others to their default values

## Additional information

* Before sending the update command to NS1, the script attempts to cache the IP address locally. It does this so that next time it runs, it first checks if a previous update has been made with the same IP address. As the script is intended to run regularly via a `crontab`, it should avoid sending unnecessary updates to NS1 if no changes occurred (public IP hasn't changed). In order to accomplish this task, it tries to save a file in the same folder as itself, called `.last_ip`. If the user running the script does not have write access to that path, local caching will be disabled, hence the script will send updates to NS1 each time it runs. Additionally, if the `-f` or `--force` parameter is used, the script ignores the local cache and sends the update to NS1 regardless what the previous IP was.
