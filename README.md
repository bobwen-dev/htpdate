# htpdate

A tool to synchronize system time from web servers.

## Examples

Synchronize time from multiple URLs

```bash
htpdate -s www.pool.ntp.org www.openssl.org nodejs.org
```

Query time from multiple URLs

```bash
htpdate www.pool.ntp.org www.openssl.org nodejs.org
```

Change default protocol to 'http'

```bash
htpdate -s -p http www.pool.ntp.org
```

Mix http and https URLs

```bash
htpdate -s http://www.pool.ntp.org https://www.openssl.org
```

Access through a http proxy

```bash
export http_proxy=http://127.0.0.1:8118
htpdate -s www.pool.ntp.org
```


## Usage

`htpdate [options...] URLs...`

### Options

```
 -c, --count            The number of requests for each URL
                        Default: 4

 -C, --command          Command to adjust system time, in https://day.js.org/ display format
                        Default(Linux/Mac): '[date -s ]YYYY-MM-DDTHH:mm:ss.SSSZ'
                        Default(Windows): '[time ]HH:mm:ss.SS[ && date ]YYYY-MM-DD'

 -h, --help             This help text
                        Default: false

 -i, --interval         The minimum milliseconds between requests
                        Default: 500

 -m, --method           HTTP method
                        Default: 'HEAD'

 -p, --protocol         Use this protocol when no protocol is specified in the URL
                        Default: 'https'

 -r, --redirect         If redirect responses should be followed
                        Default: false

 -s, --set              Adjust system time if necessary
                        Default: false

 -t, --threshold        At least how many milliseconds are considered to adjust system time
                        Default: 1500

 -T, --timeout
                        Default: 6000

 -u, --user-agent
                        Default: 'htpdate/1.0.0'

 -v, --version          display the version of htpdate and exit
                        Default: false
```

## Install Precompiled package

Download the precompiled binary package from [Releases page](https://github.com/bobwen-dev/htpdate/releases), uncompress it, and run it independently as an executable

## Compile from source code

```bash
git clone https://github.com/bobwen-dev/htpdate
cd htpdate
npm install
npm run build
```
