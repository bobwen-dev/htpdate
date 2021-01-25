# htpdate

A tool to synchronize system time with web servers.

## Examples

Get time from multiple URLs

```bash
htpdate www.pool.ntp.org www.openssl.org nodejs.org
```

Change default protocol to 'http'

```bash
htpdate --protocol http www.pool.ntp.org
```

Mix http url and https url

```bash
htpdate http://www.pool.ntp.org https://www.openssl.org
```

Access through a http proxy

```bash
export http_proxy=http://127.0.0.1:8118
htpdate www.pool.ntp.org
```


## Usage
`htpdate [options...] urls...`

### Options
```
 -c, --count            The number of requests for each url
                        Default: 4

 -C, --command          Command to adjust system time, in https://day.js.org/ display format
                        Default: '[time ]HH:mm:ss.SS[ && date ]YYYY-MM-DD'

 -h, --help             This help text
                        Default: false

 -i, --interval         The minimum milliseconds between requests
                        Default: 500

 -m, --method           HTTP method
                        Default: 'HEAD'

 -p, --protocol         Use this protocol when no protocol is specified in the url
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

## Install

### Precompiled package
Download the precompiled binary package from [Releases page](https://github.com/bobwen-dev/htpdate/releases), uncompress it, and run it independently as an executable

### Install by npm

```bash
npm i -g https://github.com/bobwen-dev/htpdate
```
