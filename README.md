# htpdate

A tool to synchronize system time from web servers, for linux, windows and macos. [Download](https://github.com/bobwen-dev/htpdate/releases)

## Examples

Synchronize time from multiple URLs

```bash
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
$ wmic os set localdatetime=20211103143426.513000+000
> Updating property(s) of '\\TESTDEVICE\ROOT\CIMV2:Win32_OperatingSystem=@'
$ exit
> Property(s) update successful.
>
>
Done
```

Query from multiple URLs

```bash
$ coffee index.coffee -c 5 -v www.pool.ntp.org www.openssl.org nodejs.org
> HEAD https://www.pool.ntp.org
>     #1:    +244 ms  DNS:    0 TCP:    0 TSL:   41 Send:    0 Recv:   76
>     #2:    +915 ms  DNS:    0 TCP:    0 TSL:    0 Send:    0 Recv:   77
>     #3:    +415 ms  DNS:    0 TCP:    0 TSL:    0 Send:    1 Recv:   75
>     #4:    +922 ms  DNS:    0 TCP:    0 TSL:    0 Send:    0 Recv:   62
>     #5:    +384 ms  DNS:    0 TCP:    0 TSL:    0 Send:    1 Recv:   75
> HEAD https://www.openssl.org
>     #1:    +608 ms  DNS:    0 TCP:    0 TSL:  124 Send:    0 Recv:   57
>     #2:    +381 ms  DNS:    0 TCP:    0 TSL:    0 Send:    1 Recv:   58
>     #3:    +864 ms  DNS:    0 TCP:    0 TSL:    0 Send:    0 Recv:   61
>     #4:    +345 ms  DNS:    0 TCP:    0 TSL:    0 Send:    0 Recv:   63
>     #5:    +844 ms  DNS:    0 TCP:    0 TSL:    0 Send:    0 Recv:   56
> HEAD https://nodejs.org
>     #1:    -135 ms  DNS:    0 TCP:    0 TSL: 1002 Send:    0 Recv:  202
>     #2:    +312 ms  DNS:    0 TCP:    0 TSL: 1116 Send:    0 Recv:  193
>     #3:    +563 ms  DNS:    0 TCP:    0 TSL: 2091 Send:    0 Recv:  193
>     #4:     -62 ms  DNS:    0 TCP:    0 TSL:  185 Send:    0 Recv:  189
>     #5:    +249 ms  DNS:    0 TCP:    0 TSL:  187 Send:    0 Recv:  189
> Median:     384 ms
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
                        Default(Linux/Mac): '[date --utc -s ]YYYY[-]MM[-]DDTHH[:]mm[:]ss[.]SSS'
                        Default(Windows): '[wmic os set localdatetime=]YYYYMMDDHHmmss[.]SSS[000][+000]'

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

Website returns a header `Date` in each response, like this:

```
HTTP/2 200
Content-Type: text/html; charset=utf-8
Date: Wed, 03 Nov 2021 11:46:19 GMT
...
```

This `Date: Wed, 03 Nov 2021 11:46:19 GMT` is the moment the website was processing the request, which is between the time we sent the request and the time we received the response. Simply assuming that the period to send request and receive is equal, we can calculate that the difference between local time and website time:

```js
duration = received_at - sent_at
delta = server_time - received_at - duration / 2
```

There is one more thing: the precision of `Date`. Imagine you get a Date end with `:23 GMT`, which could be `23.000` seconds, or `23.999` seconds. So we give `+0.5s` as a compensation.

## License

© 2021 Bob Wen

Licensed under the [GNU Affero General Public License v3.0](https://www.gnu.org/licenses/agpl-3.0.en.html) or later.
