path = require 'path'
util = require 'util'
minimist = require 'minimist'
minimist_opt = require 'minimist-options'
{ orderBy } = require 'natural-orderby'
info = require './package.json'
adjust_time = require './adjust_time'
platform = require('os').platform()


CLI_OPTIONS = {
  threshold: {
    alias: 't'
    describe: 'At least how many milliseconds are considered to adjust system time'
    default: 1500
    type: 'number'
  }
  set: {
    describe: 'Adjust system time if necessary'
    alias: 's'
    default: false
    type: 'boolean'
  }
  protocol: {
    describe: 'Use this protocol when no protocol is specified in the URL'
    alias: 'p'
    default: 'https'
    type: 'string'
  }
  method: {
    describe: 'HTTP method'
    alias: 'm'
    default: 'HEAD'
    type: 'string'
  }
  http2: {
    describe: 'Try to choose either HTTP/1.1 or HTTP/2 depending on the ALPN protocol'
    default: false
    type: 'boolean'
  }
  count: {
    describe: 'The number of requests for each URL'
    alias: 'c'
    default: 4
    type: 'number'
  }
  retry: {
    alias: 'r'
    default: 0
    type: 'number'
  }
  redirect: {
    describe: 'If redirect responses should be followed'
    alias: 'R'
    default: false
    type: 'boolean'
  }
  timeout: {
    alias: 'T'
    default: 10000
    type: 'number'
  }
  insecure: {
    describe: 'Allow insecure server connections when using https'
    alias: 'k'
    default: false
    type: 'boolean'
  }
  command: {
    describe: 'Command to adjust system time, in https://day.js.org/ UTC format'
    alias: 'C'
    default: adjust_time.COMMAND
    type: 'string'
  }
  interval: {
    describe: 'The minimum milliseconds between requests'
    alias: 'i'
    default: 500
    type: 'number'
  }
  'user-agent': {
    alias: 'u'
    type: 'string'
  }
  verbose: {
    describe: 'Make the operation more talkative'
    alias: 'v'
    default: false
    type: 'boolean'
  }
  help: {
    describe: 'This help text'
    type: 'boolean'
    alias: 'h'
    default: false
  }
  version: {
    describe: "display the version of #{info.name} and exit"
    type: 'boolean'
    alias: 'V'
    default: false
  }
}


print_version = -> 
  console.log """
    #{info.name} #{info.version}, #{info.description}

    License: AGPL-3.0
    Copyright (C) 2021 Bob Wen. All rights reserved.
    Homepage: #{info.homepage}

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as 
    published by the Free Software Foundation; either version 3 of the 
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful, 
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
    Affero General Public License for more details.


    Libraries:

    """
  for lib_name, version of info.dependencies
    lib_info = require "./node_modules/#{lib_name}/package.json"
    console.log """
      #{lib_info.name} #{lib_info.version}
      License: #{lib_info.license or ''}
      Homepage: #{lib_info.homepage?.split('#')[0] or ''}

      """



print_usage = (options) ->
  items = []
  for k, v of options
    items.push {
      key: k
      v...
    }
  items = orderBy items, (v) -> v.alias ? v.key
  console.log """
    #{info.name} #{info.version}, #{info.description}
    Usage: #{info.name} [options...] URLs...
    
    Options
    """
  for o in items
    if o.alias?
      line = " -#{o.alias}, --#{o.key}".padEnd 24
    else
      line = "     --#{o.key}".padEnd 24
    line += "#{o.describe or ''}\n"
    if o.default?
      line += "".padStart(24) + "Default: #{util.inspect o.default}"
    else if o.type?
      line += "".padStart(24) + "Type: #{o.type}"
    console.log line + '\n'


print_examples = (exam = []) ->
  console.log """
    Examples
      Synchronize time from multiple URLs
        #{info.name} -s www.pool.ntp.org www.openssl.org nodejs.org

      Query time from multiple URLs
        #{info.name} www.pool.ntp.org www.openssl.org nodejs.org

      Change default protocol to 'http'
        #{info.name} -s -p http www.pool.ntp.org

      Mix http and https URLs
        #{info.name} -s http://www.pool.ntp.org https://www.openssl.org

      Access through a http proxy
        #{if platform is 'win32' then 'set' else 'export'} http_proxy=http://127.0.0.1:8118
        #{info.name} -s www.pool.ntp.org
    """



module.exports = (exam) -> 
  argv = minimist process.argv.slice(2), minimist_opt CLI_OPTIONS
  if argv.version
    print_version()
    process.exit 0
  if argv.help or argv._.length is 0
    print_usage CLI_OPTIONS
    print_examples exam
    console.log()
    if not argv.help
      console.error "\nError: Missing server URL, at least one URL should be specified"
    return process.exit 0
  if argv.count < 1
    argv.count = 1
  if argv.retry < 0
    argv.retry = 0
  argv['user-agent'] = argv['user-agent'].trim() if argv['user-agent']
  argv['user-agent'] = undefined if argv['user-agent'] == ''
  argv
