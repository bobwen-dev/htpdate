path = require 'path'
util = require 'util'
minimist = require 'minimist'
minimist_opt = require 'minimist-options'
{ orderBy } = require 'natural-orderby'
info = require './package.json'
platform = require('os').platform()


DEFAULT_OPTIONS = {
  help: {
    describe: 'This help text'
    type: 'boolean'
    alias: 'h'
    default: false
  }
  version: {
    describe: "display the version of #{info.name} and exit"
    type: 'boolean'
    alias: 'v'
    default: false
  }
}


print_version = -> 
  console.log """
    #{info.name} #{info.version}, #{info.description}

    Copyright (C) 2021 Bob Wen. All rights reserved.

    License: AGPL-3.0

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
      License: #{lib_info.license}
      Homepage: #{lib_info.homepage.split('#')[0]}

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
    Usage: #{info.name} [options...] urls...
    
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
      Get time from multiple URLs
        #{info.name} www.pool.ntp.org www.openssl.org nodejs.org

      Change default protocol to 'http'
        #{info.name} --protocol http www.pool.ntp.org

      Mix http url and https url
        #{info.name} http://www.pool.ntp.org https://www.openssl.org

      Access through a http proxy
        #{if platform is 'win32' then 'set' else 'export'} http_proxy=http://127.0.0.1:8118
        #{info.name} www.pool.ntp.org
    """



module.exports = (opt, exam) ->
  cli_options = {
    DEFAULT_OPTIONS...
    opt...
  }
  argv = minimist process.argv.slice(2), minimist_opt cli_options
  if argv.version
    print_version()
    process.exit 0
  if argv.help or argv._.length is 0
    print_usage cli_options
    print_examples exam
    console.log()
    if argv.help
      process.exit 0
    console.error "\nError: Missing server url, at least one url should be specified"
    process.exit 0
  if argv.count < 1
    argv.count = 1
  argv
