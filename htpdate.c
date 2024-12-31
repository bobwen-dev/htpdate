#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <curl/curl.h>
#include <getopt.h>
#include <math.h>
#include <unistd.h>
#include <stdbool.h>
#include <ctype.h>
#include <stdarg.h>

#ifdef _WIN32
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <tchar.h>
#else
#include <sys/time.h>
#endif

#define HTPDATE_VERSION "1.0.4rc1"
#define DEFAULT_COUNT 5
#define DEFAULT_INTERVAL 500
#define DEFAULT_THRESHOLD 1500
#define DEFAULT_TIMEOUT 100000L
#define DEFAULT_TRANSFER_TIMEOUT 60000L
#define DEFAULT_DNS_TIMEOUT 30000L
#define DEFAULT_USER_AGENT "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36"
#define DEFAULT_METHOD "HEAD"
#define DEFAULT_HTTP_VERSION "auto"
#define DEFAULT_RETRY 0
#define DEFAULT_REDIRECT false
#define DEFAULT_INSECURE false
#define DEFAULT_ADJUST false
#define DEFAULT_VERBOSE false

typedef long long TIME_T;

struct ResponseData {
    char *date;
    TIME_T duration;
} data = {NULL, 0.0};

struct HeaderData {
    char *headers;
    size_t headers_len;
} header_data = {NULL, 0};

struct CmdOptions {
    int count;
    int interval;
    long timeout;
    long transfer_timeout;
    long dns_timeout;
    char *user_agent;
    char *method;
    int retry;
    bool insecure;
    bool help;
    bool version;
    bool adjust;
    int threshold;
} cmd_options = {
    .count = DEFAULT_COUNT,
    .interval = DEFAULT_INTERVAL,
    .timeout = DEFAULT_TIMEOUT,
    .transfer_timeout = DEFAULT_TRANSFER_TIMEOUT,
    .dns_timeout = DEFAULT_DNS_TIMEOUT,
    .user_agent = DEFAULT_USER_AGENT,
    .method = DEFAULT_METHOD,
    .retry = DEFAULT_RETRY,
    .insecure = DEFAULT_INSECURE,
    .help = false,
    .version = false,
    .adjust = DEFAULT_ADJUST,
    .threshold = DEFAULT_THRESHOLD
};

size_t HeaderCallback(void *ptr, size_t size, size_t nmemb, void *userdata);
size_t WriteCallback(void *ptr, size_t size, size_t nmemb, void *userdata);
TIME_T get_current_time();
char *strtolower(const char *str);
int parse_month(const char *month);
TIME_T parse_date(const char *date_str);
TIME_T parse_date_header(const char *headers, size_t headers_len, const char *url);
void print_formatted(const char *format, const char **args, size_t arg_count);
void print_help();
void parse_options(int argc, char *argv[]);
char *add_protocol_if_needed(const char *url);
TIME_T resolve_and_cache_dns(CURL *curl, const char *url);
void process_url(CURL *curl, const char *url, TIME_T *deltas, size_t *delta_count, int *max_width);
TIME_T calculate_median(TIME_T *deltas, size_t count);
int qsort_compare(const void *a, const void *b);

size_t HeaderCallback(void *ptr, size_t size, size_t nmemb, void *userdata) {
    size_t realsize = size * nmemb;
    struct HeaderData *header_data = (struct HeaderData *)userdata;
    char *new_headers = realloc(header_data->headers, header_data->headers_len + realsize + 1);
    if (new_headers) {
        header_data->headers = new_headers;
        memcpy(header_data->headers + header_data->headers_len, ptr, realsize);
        header_data->headers_len += realsize;
        header_data->headers[header_data->headers_len] = '\0';
    } else {
        fprintf(stderr, "Memory allocation failed in HeaderCallback\n");
    }
    return realsize;
}

size_t WriteCallback(void *ptr, size_t size, size_t nmemb, void *userdata) {
    // Do nothing, just to prevent curl from printing the response body
    return size * nmemb;
}

TIME_T get_current_time() {
#ifdef _WIN32
    FILETIME ft;
    ULARGE_INTEGER ul;
    GetSystemTimeAsFileTime(&ft);
    ul.LowPart = ft.dwLowDateTime;
    ul.HighPart = ft.dwHighDateTime;
    // FILETIME is in 100-nanosecond intervals since January 1, 1601 (UTC)
    // Convert to milliseconds since January 1, 1970 (UTC)
    return (ul.QuadPart / 10000LL - 11644473600000LL);
#else
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000 + tv.tv_usec / 1000;
#endif
}

char *strtolower(const char *str) {
    char *lower = malloc(strlen(str) + 1);
    if (lower) {
        for (size_t i = 0; str[i]; i++) {
            lower[i] = tolower(str[i]);
        }
        lower[strlen(str)] = '\0';
    }
    return lower;
}

int parse_month(const char *month) {
    static const char *months[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};
    for (int i = 0; i < 12; i++) {
        if (strcasecmp(month, months[i]) == 0) {
            return i;
        }
    }
    return -1;
}


TIME_T get_timezone_offset() {
    time_t now = time(NULL);
    struct tm *local_tm = localtime(&now);
    long timezone_offset = 0;

#ifdef _WIN32
    TIME_ZONE_INFORMATION tz_info;
    DWORD result = GetTimeZoneInformation(&tz_info);
    if (result == TIME_ZONE_ID_INVALID) {
        fprintf(stderr, "Failed to get timezone information\n");
        exit(EXIT_FAILURE);
    }
    timezone_offset = 0 - tz_info.Bias * 60 * 1000;
#else
    timezone_offset = local_tm->tm_gmtoff * 1000;
#endif
    return timezone_offset;
}

TIME_T parse_date(const char *date_str) {
    struct tm tm = {0};
    char day[4], month[4], year[5], time[9], zone[4];
    if ((sscanf(date_str, "%3s, %2d %3s %4s %2d:%2d:%2d %3s", day, &tm.tm_mday, month, year, &tm.tm_hour, &tm.tm_min, &tm.tm_sec, zone) == 8) ||
        (sscanf(date_str, "%3s, %2d-%3s-%4s %2d:%2d:%2d %3s", day, &tm.tm_mday, month, year, &tm.tm_hour, &tm.tm_min, &tm.tm_sec, zone) == 8)) {
        tm.tm_year = atoi(year) - 1900;
        tm.tm_mon = parse_month(month);
        if (tm.tm_mon != -1) {
            return mktime(&tm) * 1000 + get_timezone_offset() + 500;
        }
    } else {
        printf("sscanf failed: %s", date_str);
    }
    return 0;
}

TIME_T parse_date_header(const char *headers, size_t headers_len, const char *url) {
    char *lower_headers = strtolower(headers);
    const char *date_header = NULL;
    const char *last_date_header = NULL;
    char *temp_headers = lower_headers;

    while ((temp_headers = strstr(temp_headers, "date:"))) {
        last_date_header = temp_headers;
        temp_headers += 5; // Move past "Date:"
    }

    free(lower_headers);

    if (last_date_header) {
        size_t offset = last_date_header - lower_headers;
        last_date_header = headers + offset + 5; // Skip "Date:"
        while (*last_date_header == ' ') last_date_header++; // Skip spaces
        TIME_T server_timestamp = parse_date(last_date_header);
        if (server_timestamp < 1)
            fprintf(stderr, "Failed to parse Date header for URL %s - '%s'\n", url, last_date_header);
        return server_timestamp;
    }
    return 0.0;
}

void print_formatted(const char *format, const char **args, size_t arg_count) {
    char buffer[1024]; // Assume the formatted string will not exceed 1024 bytes
    size_t offset = 0;

    for (size_t i = 0; i < arg_count; i++) {
        const char *arg = args[i];
        while (*format) {
            if (*format == '%') {
                format++;
                if (*format == 'd') {
                    offset += sprintf(buffer + offset, "%d", (int)(intptr_t)arg);
                } else if (*format == 'l' && *(format + 1) == 'd') {
                    offset += sprintf(buffer + offset, "%ld", (long)(intptr_t)arg);
                    format++;
                } else if (*format == 's') {
                    offset += sprintf(buffer + offset, "%s", arg);
                }
                format++;
            } else {
                buffer[offset++] = *format++;
            }
        }
    }
    buffer[offset] = '\0';
    printf("%s", buffer);
}

void print_help() {
    struct HelpOption {
        const char *option;
        const char *description;
        const char **args; // Dynamic array to store arguments
        size_t arg_count;  // Number of arguments
    };

    struct HelpOption help_options[] = {
        {"-c, --count", "The number of requests for each URL (default: %d)", (const char *[]){(char*)(intptr_t)DEFAULT_COUNT, NULL}, 1},
        {"-i, --interval", "The minimum milliseconds between requests (default: %d)", (const char *[]){(char*)(intptr_t)DEFAULT_INTERVAL, NULL}, 1},
        {"-T, --timeout", "Total timeout value, milliseconds (default: %ld)", (const char *[]){(char*)(intptr_t)DEFAULT_TIMEOUT, NULL}, 1},
        {"-R, --transfer-timeout", "Transfer timeout value, milliseconds (default: %ld)", (const char *[]){(char*)(intptr_t)DEFAULT_TRANSFER_TIMEOUT, NULL}, 1},
        {"-D, --dns-timeout", "The timeout value of the domain name resolution, milliseconds (default: %ld)", (const char *[]){(char*)(intptr_t)DEFAULT_DNS_TIMEOUT, NULL}, 1},
        {"-u, --user-agent", "Browser user agent name (default: '%s')", (const char *[]){DEFAULT_USER_AGENT, NULL}, 1},
        {"-m, --method", "HTTP method (default: '%s')", (const char *[]){DEFAULT_METHOD, NULL}, 1},
        {"-r, --retry", "Number of retries (default: %d)", (const char *[]){(char*)(intptr_t)DEFAULT_RETRY, NULL}, 1},
        {"-k, --insecure", "Allow insecure server connections when using https or wss (default: %s)", (const char *[]){DEFAULT_INSECURE ? "true" : "false", NULL}, 1},
        {"-a, --adjust", "Adjust system time if necessary (default: %s)", (const char *[]){DEFAULT_ADJUST ? "true" : "false", NULL}, 1},
        {"-t, --threshold", "At least how many milliseconds are considered to adjust system time (default: %d)", (const char *[]){(char*)(intptr_t)DEFAULT_THRESHOLD, NULL}, 1},
        {"-h, --help", "Display this help text", (const char *[]){NULL}, 0},
        {"-V, --version", "Display the version of %s-%s and exit", (const char *[]){NULL}, 0}
    };

    printf("Usage: htpdate [options...] URLs...\n");
    printf("Options:\n");
    for (size_t i = 0; i < sizeof(help_options) / sizeof(help_options[0]); i++) {
        printf("  %s", help_options[i].option);
        print_formatted(help_options[i].description, help_options[i].args, help_options[i].arg_count);
        printf("\n");
    }
}

void parse_options(int argc, char *argv[]) {
    static struct option long_options[] = {
        {"count", required_argument, 0, 'c'},
        {"interval", required_argument, 0, 'i'},
        {"timeout", required_argument, 0, 'T'},
        {"transfer-timeout", required_argument, 0, 'R'},
        {"dns-timeout", required_argument, 0, 'D'},
        {"user-agent", required_argument, 0, 'u'},
        {"method", required_argument, 0, 'm'},
        {"retry", required_argument, 0, 'r'},
        {"insecure", no_argument, 0, 'k'},
        {"adjust", no_argument, 0, 'a'},
        {"threshold", required_argument, 0, 't'},
        {"help", no_argument, 0, 'h'},
        {"version", no_argument, 0, 'V'},
        {0, 0, 0, 0}
    };

    int option_index = 0;
    int c;
    while ((c = getopt_long(argc, argv, "c:i:T:R:D:u:m:r:kat:hV", long_options, &option_index)) != -1) {
        switch (c) {
            case 'c':
                cmd_options.count = atoi(optarg);
                break;
            case 'i':
                cmd_options.interval = atoi(optarg);
                break;
            case 'T':
                cmd_options.timeout = atol(optarg);
                break;
            case 'R':
                cmd_options.transfer_timeout = atol(optarg);
                break;
            case 'D':
                cmd_options.dns_timeout = atol(optarg);
                break;
            case 'u':
                cmd_options.user_agent = optarg;
                break;
            case 'm':
                cmd_options.method = optarg;
                break;
            case 'r':
                cmd_options.retry = atoi(optarg);
                break;
            case 'k':
                cmd_options.insecure = true;
                break;
            case 'a':
                cmd_options.adjust = true;
                break;
            case 't':
                cmd_options.threshold = atoi(optarg);
                break;
            case 'h':
                cmd_options.help = true;
                break;
            case 'V':
                cmd_options.version = true;
                break;
            default:
                fprintf(stderr, "Usage: htpdate [options...] URLs...\n");
                exit(EXIT_FAILURE);
        }
    }
}

// Helper function to add protocol prefix if needed
char *add_protocol_if_needed(const char *url) {
    const char *protocol_prefix = "https://";
    size_t protocol_prefix_len = strlen(protocol_prefix);

    // Check if the URL already contains a protocol prefix
    const char *colon_slash_slash = strstr(url, "://");
    if (colon_slash_slash) {
        // URL already contains a protocol prefix
        return strdup(url);
    } else {
        // URL does not have a protocol prefix, add https:// prefix
        char *new_url = malloc(protocol_prefix_len + strlen(url) + 1);
        if (new_url) {
            strcpy(new_url, protocol_prefix);
            strcat(new_url, url);
        }
        return new_url;
    }
}

// Function to perform DNS resolution and cache the result
TIME_T resolve_and_cache_dns(CURL *curl, const char *url) {
    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_CONNECT_ONLY, 1L);
    curl_easy_setopt(curl, CURLOPT_DNS_CACHE_TIMEOUT, cmd_options.dns_timeout / 1000);
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, (long)(cmd_options.insecure ? 0L : 1L));
    curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, (long)(cmd_options.insecure ? 0L : 2L));

    TIME_T start_time = get_current_time();
    CURLcode res = CURLE_OK;
    int retry_count = 0;

    while (retry_count <= cmd_options.retry && res != CURLE_OK) {
        res = curl_easy_perform(curl);
        if (res != CURLE_OK) {
            fprintf(stderr, "DNS resolution failed for URL %s: %s\n", url, curl_easy_strerror(res));
            retry_count++;
        }
    }

    TIME_T end_time = get_current_time();
    return end_time - start_time;
}

void process_url(CURL *curl, const char *url, TIME_T *deltas, size_t *delta_count, int *max_width) {
    struct {
        CURLoption option;
        const void *parameter;
    } curl_options[] = {
        {CURLOPT_CONNECT_ONLY, (const void *)(intptr_t)0L},
        {CURLOPT_USERAGENT, (const void *)cmd_options.user_agent},
        {CURLOPT_TIMEOUT_MS, (const void *)(intptr_t)cmd_options.timeout},
        {CURLOPT_CONNECTTIMEOUT_MS, (const void *)(intptr_t)cmd_options.transfer_timeout},
        {CURLOPT_DNS_CACHE_TIMEOUT, (const void *)(intptr_t)cmd_options.dns_timeout},
        {CURLOPT_SSL_VERIFYPEER, (const void *)(intptr_t)(cmd_options.insecure ? 0L : 1L)},
        {CURLOPT_SSL_VERIFYHOST, (const void *)(intptr_t)(cmd_options.insecure ? 0L : 2L)},
        {CURLOPT_FOLLOWLOCATION, (const void *)(intptr_t)(0L)},
        {CURLOPT_URL, url},
        {CURLOPT_CUSTOMREQUEST, cmd_options.method},
        {CURLOPT_HEADERFUNCTION, HeaderCallback},
        {CURLOPT_HEADERDATA, (const void *)&header_data},
        {CURLOPT_FAILONERROR, (const void *)0L},
        {CURLOPT_ERRORBUFFER, (const void *)0L},
        {CURLOPT_NOBODY, (const void *)1L},
        {CURLOPT_WRITEFUNCTION, WriteCallback},
        {CURLOPT_VERBOSE, (const void *)0L}, // Enable verbose mode for debugging
    };

    for (size_t i = 0; i < sizeof(curl_options) / sizeof(curl_options[0]); i++) {
        curl_easy_setopt(curl, curl_options[i].option, curl_options[i].parameter);
    }

    for (int i = 0; i < cmd_options.count; i++) {
        int retry_count = 0;
        bool success = false;
        printf("\n#%d\t", i + 1);

        while (retry_count <= cmd_options.retry && !success) {
            header_data.headers = NULL;
            header_data.headers_len = 0;
            TIME_T sent_at = get_current_time();
            CURLcode res = curl_easy_perform(curl);
            TIME_T received_at = get_current_time();
            TIME_T io_time = received_at - sent_at;

            if (res != CURLE_OK) {
                fprintf(stderr, "curl_easy_perform() failed for URL %s: %s\n", url, curl_easy_strerror(res));
            } else {
                TIME_T server_timestamp = parse_date_header(header_data.headers, header_data.headers_len, url);
                if (server_timestamp > 1) {
                    success = true;
                    TIME_T server_time = server_timestamp + io_time / 2.0;
                    TIME_T local_time = get_current_time();
                    TIME_T delta = server_time - local_time;
                    char delta_str[50];
                    sprintf(delta_str, "%s%lld ms", delta >= 0 ? "+" : "", delta);
                    *max_width = strlen(delta_str) > *max_width ? strlen(delta_str) : *max_width;
                    printf("%*s", *max_width, delta_str);
                    deltas[(*delta_count)++] = delta;
                    continue;
                } else {
                    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
                }
            }
            retry_count += 1;
        }

        if (header_data.headers) {
            free(header_data.headers);
            header_data.headers = NULL;
            header_data.headers_len = 0;
        }

        if (i < cmd_options.count - 1) {
            usleep(cmd_options.interval * 1000); // Sleep for the interval in milliseconds
        }
    }
    printf("\n");
}

// Function to calculate the median of an array of deltas
TIME_T calculate_median(TIME_T *deltas, size_t count) {
    if (count == 0) return 0.0;

    qsort(deltas, count, sizeof(TIME_T), qsort_compare);

    if (count % 2 == 0) {
        return (deltas[count / 2 - 1] + deltas[count / 2]) / 2;
    } else {
        return deltas[count / 2];
    }
}

// Comparison function for qsort
int qsort_compare(const void *a, const void *b) {
    TIME_T diff = (*(TIME_T *)a - *(TIME_T *)b);
    return (diff > 0.0) - (diff < 0.0);
}

void adjust_system_time(TIME_T delta) {
#ifdef _WIN32
    // Windows specific code
    char date_format[64];

    // Get the short date format from the registry
    FILE *fp = popen("reg query \"HKCU\\Control Panel\\International\" /v sShortDate", "r");
    if (fp) {
        while (fgets(date_format, sizeof(date_format), fp)) {
            if (strstr(date_format, "REG_SZ")) {
                break;
            }
        }
        pclose(fp);
    }

    // Extract the date format string
    char *format_start = strstr(date_format, "REG_SZ");
    if (format_start) {
        format_start += strlen("REG_SZ");
        while (*format_start == ' ') {
            format_start++;
        }
        char *format_end = strpbrk(format_start, "\r\n");
        if (format_end) {
            while (*format_end == ' ' && format_end > format_start) {
                format_end--;
            }
            *format_end = '\0';
        }
    }

    // Convert the date format to the desired format
    struct {
        const char *pattern;
        const char *format;
    } date_patterns[] = {
        {"yyyyy", "%Y-"},
        {"yyyy", "%Y-"},
        {"yy", "%Y-"},
        {"Y", "%Y-"},
        {"MM", "%m-"},
        {"M", "%m-"},
        {"mmm", "%m-"},
        {"mm", "%m-"},
        {"m", "%m-"},
        {"DD", "%d-"},
        {"D", "%d-"},
        {"ddd", "%d-"},
        {"dd", "%d-"},
        {"d", "%d-"},
    };

    char command_format[128] = "date ";
    char *p = format_start;
    while (*p) {
        for (size_t i = 0; i < sizeof(date_patterns) / sizeof(date_patterns[0]); i++) {
            size_t pattern_len = strlen(date_patterns[i].pattern);
            if (strncmp(p, date_patterns[i].pattern, pattern_len) == 0) {
                strcat(command_format, date_patterns[i].format);
                p += pattern_len - 1;
                break;
            }
        }
        p++;
    }

    // remove the trailing '-'
    if (command_format[strlen(command_format) - 1] == '-') {
        command_format[strlen(command_format) - 1] = '\0';
    }
    // add time command
    strcat(command_format, " && time %H:%M:%S");
#else
    char *command_format = "date -s '%Y-%m-%dT%H:%M:%S";
#endif

    // get target time
    time_t moment = time(NULL) + (time_t)(delta / 1000);
    int milliseconds = delta % 1000;
    char milliseconds_str[10];
    char adjust_cmd[128];

#ifdef _WIN32
    struct tm *tm_info = localtime(&moment);
    snprintf(milliseconds_str, sizeof(milliseconds_str), ".%02d", milliseconds / 10);
#else
    struct tm *tm_info = gmtime(&moment);
    snprintf(milliseconds_str, sizeof(milliseconds_str), ".%03d'", milliseconds);
#endif

    strftime(adjust_cmd, sizeof(adjust_cmd), command_format, tm_info);
    strcat(adjust_cmd, milliseconds_str);
    // printf("run %s\n", adjust_cmd);
    system(adjust_cmd);
}


int main(int argc, char *argv[]) {
    parse_options(argc, argv);

    if (cmd_options.help) {
        print_help();
        return 0;
    }

    if (cmd_options.version) {
        printf("htpdate version %s\n", HTPDATE_VERSION);
        return 0;
    }

    curl_global_init(CURL_GLOBAL_DEFAULT);
    CURL *curl = curl_easy_init();
    if (!curl) {
        fprintf(stderr, "curl init failed\n");
        return -1;
    }

    TIME_T *deltas = malloc(cmd_options.count * (argc - optind) * sizeof(TIME_T));
    if (!deltas) {
        fprintf(stderr, "Memory allocation failed for deltas\n");
        curl_easy_cleanup(curl);
        curl_global_cleanup();
        return -1;
    }

    size_t delta_count = 0;
    int max_width = 0;

    // Process each URL provided in the command line arguments
    for (int i = optind; i < argc; i++) {
        char *full_url = add_protocol_if_needed(argv[i]);
        if (!full_url) {
            fprintf(stderr, "Memory allocation failed for URL: %s\n", argv[i]);
            continue;
        }
        printf("%s %s", cmd_options.method, full_url);
        resolve_and_cache_dns(curl, full_url);
        process_url(curl, full_url, deltas, &delta_count, &max_width);
        free(full_url);
    }

    // Calculate and print the median delta
    if (delta_count > 0) {
        TIME_T median_delta = calculate_median(deltas, delta_count);
        char median_str[50];
        sprintf(median_str, "%s%lld ms", median_delta >= 0 ? "+" : "", median_delta);
        printf("median:\t%*s\n", max_width, median_str);
        if (cmd_options.adjust && abs(median_delta) >= cmd_options.threshold) {
            adjust_system_time(median_delta);
            printf("System time adjusted by %s ms\n", median_str);
        } else {
            printf("System time adjustment not necessary\n");
        }
    }

    free(deltas);
    curl_easy_cleanup(curl);
    curl_global_cleanup();
    return 0;
}
