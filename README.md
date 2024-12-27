# htpdate

**htpdate** is a tool to synchronize system time from web servers, supporting Windows, Linux, BSD, and macOS. It provides time calibration with 0.5-second accuracy and can be used as a backup measure or in cases where NTP (Network Time Protocol) is not available.

## Features

- **High Accuracy**: Provides time calibration with 0.5-second accuracy.
- **Cross-Platform**: Supports Windows, Linux, BSD, and macOS.
- **Flexible**: Can be used as a backup measure or in environments where NTP is not available.
- **Easy to Use**: Simple command-line interface with various options for customization.

## Why htpdate?

- **Ubiquity of Web Servers**: Websites are everywhere, making them a more accessible source for time synchronization compared to NTP servers.
- **Backup Measure**: htpdate can serve as a backup when NTP is not available.
- **Versatility**: Useful in scenarios where devices cannot use NTP.

## Installation

### Prerequisites

- **gcc**: Ensure you have the GNU Compiler Collection (gcc) installed.
- **libcurl-dev**: Ensure you have the libcurl development package installed.

### Build

To build htpdate, use the following command:

```sh
gcc -o htpdate htpdate.c -lcurl
```

## Usage

```sh
htpdate [options...] URLs...
```

### Options

- `-c, --count`: The number of requests for each URL. Default: 4.
- `-C, --command`: Command to adjust system time, in [https://day.js.org/](https://day.js.org/) format.
  - Default (Linux/Mac): `'[date -s ]YYYY[-]MM[-]DDTHH[:]mm[:]ss[.]SSS'`
  - Default (Windows): `'[time ]HH[:]mm[:]ss[.]SS[ && date ]MM[-]DD[-]YY'`
- `-h, --help`: Display this help text. Default: false.
- `--http2`: Try to choose either HTTP/1.1 or HTTP/2 depending on the ALPN protocol. Default: false.
- `-i, --interval`: The minimum milliseconds between requests. Default: 500.
- `-k, --insecure`: Allow insecure server connections when using HTTPS. Default: false.
- `-m, --method`: HTTP method. Default: 'HEAD'.
- `-p, --protocol`: Use this protocol when no protocol is specified in the URL. Default: 'https'.
- `-r, --retry`: Number of retries. Default: 0.
- `-R, --redirect`: If redirect responses should be followed. Default: false.
- `-s, --set`: Adjust system time if necessary. Default: false.
- `-t, --threshold`: At least how many milliseconds are considered to adjust system time. Default: 1500.
- `-T, --timeout`: Total timeout value, milliseconds. Default: 6000.
- `-u, --user-agent`: Browser user agent name.
- `-V, --version`: Display the version of htpdate and exit. Default: false.
- `-v, --verbose`: Make the operation more talkative. Default: false.

## Time Synchronization Principle

According to the definition of RFC 7230/2822/2616, websites include a `Date` field in the response header, like this:

```
HTTP/2 200
Content-Type: text/html; charset=utf-8
Date: Wed, 03 Nov 2021 11:46:19 GMT
...
```

This `Date` field represents the moment the website processed the request, which is between the time we sent the request and the time we received the response. By assuming that the time to send the request and receive the response is equal, we can calculate the difference between local time and website time:

1. **Duration Calculation**:
   ```
   duration = received_at - sent_at
   ```

2. **Time Difference Calculation**:
   ```
   delta = server_time - received_at - duration / 2
   ```

3. **Precision Compensation**:
   Since the precision of the `Date` field can vary (e.g., `:23 GMT` could be `23.000` seconds or `23.999` seconds), we add a compensation of +0.5 seconds.

## Platform-Specific Handling

### Windows

On Windows, htpdate uses the `reg` command to query the short date format from the registry and constructs the appropriate date and time adjustment commands.

### Linux/MacOS

On Linux and macOS, htpdate uses the `date` command to adjust the system time.

## License

This project is licensed under the AGPL-3.0 License. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Acknowledgments

- Thanks to the original CoffeeScript version for the inspiration.
- Special thanks to the contributors and users of htpdate.

## Contact

For any questions or feedback, please open an issue on GitHub.

---

**htpdate** is a powerful tool for time synchronization, offering a reliable alternative to NTP. Try it out and ensure your system time is always accurate!
