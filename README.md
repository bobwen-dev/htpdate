# htpdate

A tool to synchronize system time from web servers, for linux, windows and macos. [Download](https://github.com/bobwen-dev/htpdate/releases)

`htpdate` provides time calibration with `0.5` second accuracy.

## But, why not use ntp?

- Websites are everywhere in the world, ntp servers are scarce that the access is centralized.
- `htpdate` can be used as a backup measure.
- There are always cases where the device cannot use ntp.

## Examples

Synchronize time from multiple URLs

```text
C:\> htpdate -s www.pool.ntp.org www.openssl.org nodejs.org
HEAD https://www.pool.ntp.org
    #1: +367325 ms
    #2: +366966 ms
    #3: +367462 ms
    #4: +366960 ms
HEAD https://www.openssl.org
    #1: +367258 ms
    #2: +366983 ms
    #3: +367487 ms
    #4: +366986 ms
HEAD https://nodejs.org
    #1: +367647 ms
    #2: +367278 ms
    #3: +367670 ms
    #4: +367516 ms
Median: 367301.5 ms
Adjust time...
>
$ time 13:22:42.28 && date 11-04-21
>
$ exit
Done
```

Note: Windows users need to be aware of the date format in their region. Default format(from [dayjs](https://day.js.org/docs/en/display/format)) is `MM-DD-YY`, users in non-U.S. regions may need to customize it with the `-C` parameter, eg:

`htpdate -s -C "[time ]HH:mm:ss.SS[ && date ]YY-MM-DD" github.com`.

Query from multiple URLs

```text
$ htpdate -c 5 -v www.pool.ntp.org www.openssl.org
HEAD https://www.pool.ntp.org
    #1:    -419 ms  DNS:   95 TCP:   27 TSL:   43 Send:    3 Recv:   38
    #2:    +403 ms  DNS:    0 TCP:    0 TSL:    0 Send:    1 Recv:   26
    #3:     -94 ms  DNS:    0 TCP:    0 TSL:    0 Send:    1 Recv:   24
    #4:    +372 ms  DNS:    0 TCP:    0 TSL:    0 Send:    1 Recv:   46
    #5:     -97 ms  DNS:    0 TCP:    0 TSL:    0 Send:    1 Recv:   24
HEAD https://www.openssl.org
    #1:    +251 ms  DNS:   38 TCP:   27 TSL:   67 Send:    1 Recv:   33
    #2:    -107 ms  DNS:    0 TCP:    0 TSL:    0 Send:    1 Recv:   28
    #3:    +396 ms  DNS:    0 TCP:    0 TSL:    0 Send:    1 Recv:   25
    #4:    -113 ms  DNS:    0 TCP:    0 TSL:    0 Send:    1 Recv:   30
    #5:    +385 ms  DNS:    0 TCP:    0 TSL:    0 Send:    0 Recv:   31
Median:    78.5 ms
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

 -C, --command          Command to adjust system time, in https://day.js.org/ format
                        Default(Linux/Mac): '[date -s ]YYYY[-]MM[-]DDTHH[:]mm[:]ss[.]SSS'
                        Default(Windows): '[time ]HH[:]mm[:]ss[.]SS[ && date ]MM[-]DD[-]YY'

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

According to the definition of [rfc7230](https://datatracker.ietf.org/doc/html/rfc7230)/[2822](https://datatracker.ietf.org/doc/html/rfc2822)/[2616](https://tools.ietf.org/html/rfc2616), website places a `Date` field in the response header, like this:

```text
HTTP/2 200
Content-Type: text/html; charset=utf-8
Date: Wed, 03 Nov 2021 11:46:19 GMT
...
```

This field `Date: Wed, 03 Nov 2021 11:46:19 GMT` is the moment the website was processing the request, which is between the time we sent the request and the time we received the response. Simply assuming that the period to send request and receive is equal, we can calculate that the difference between local time and website time:

```text
duration = received_at - sent_at
delta = server_time - received_at - duration / 2
```

There is one more thing: the precision of the field. Imagine we get a value end with `:23 GMT`, which could be `23.000` seconds, or `23.999` seconds. So we give `+0.5s` as a compensation.

## License

© 2021 Bob Wen

Licensed under the [GNU Affero General Public License v3.0](https://www.gnu.org/licenses/agpl-3.0.en.html) or later.
