# htpdate

A tool to synchronize system time from web servers, for linux, windows and macos. [Download](https://github.com/bobwen-dev/htpdate/releases)

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

```text
 -c, --count            The number of requests for each URL
                        Default: 4

 -C, --command          Command to adjust system time, in https://day.js.org/ UTC format
                        Default(Linux/Mac): '[date --utc -set=]YYYY-MM-DDTHH:mm:ss.SSS'
                        Default(Windows): '[wmic OS Set localdatetime=]YYYYMMDDmmss.SSS[000][+000]'

 -h, --help             This help text
                        Default: false

     --http2            Try to choose either HTTP/1.1 or HTTP/2 depending on the ALPN protocol
                        Default: false

 -i, --interval         The minimum milliseconds between requests
                        Default: 500

 -k, --insecure         Allow insecure server connections when using https
                        Default: false

 -m, --method           HTTP method
                        Default: 'HEAD'

 -p, --protocol         Use this protocol when no protocol is specified in the URL
                        Default: 'https'

 -r, --retry
                        Default: 0

 -R, --redirect         If redirect responses should be followed
                        Default: false

 -s, --set              Adjust system time if necessary
                        Default: false

 -t, --threshold        At least how many milliseconds are considered to adjust system time
                        Default: 1500

 -T, --timeout
                        Default: 6000

 -u, --user-agent
                        Type: string

 -V, --version          display the version of htpdate and exit
                        Default: false

 -v, --verbose          Make the operation more talkative
                        Default: false
```

## Install Precompiled package

Download the precompiled binary package from [Releases page](https://github.com/bobwen-dev/htpdate/releases), uncompress it, and run it independently as an executable.

## Compile

```bash
git clone https://github.com/bobwen-dev/htpdate
cd htpdate
npm install
npm run build
```

## The principle

Website returns the server's current date-time in each response's header, like this:

```
HTTP/2 200
Content-Type: text/html; charset=utf-8
Date: Wed, 03 Nov 2021 11:46:19 GMT
...
```

This `Date: Wed, 03 Nov 2021 11:46:19 GMT` is the moment the website was processing the request, which is in the middle of the time we sent the request and the time we received the response. Simply assuming that the period to send request and receive is equal, we can calculate that the difference between local time and website time:

```js
duration = received_at - sent_at
delta = server_time - received_at - duration / 2
```

There is one more error to consider. Imagine you get a Date value of `23` seconds, which could be `23.000` seconds, or `23.999` seconds. So we having to give 0.500s as compensation for the calculation.

## License

© 2021 Bob Wen

Licensed under the [GNU Affero General Public License v3.0](https://www.gnu.org/licenses/agpl-3.0.en.html) or later.
