util = require 'util'
{ spawn, execSync } = require 'child_process'
dayjs = require 'dayjs'
delay = require './delay'
dayjs.extend require './dayjs_format_ms'
platform = require('os').platform()


adjust_time = (delta, adjust_command) ->
  console.log 'Adjust time...'
  shell = spawn spawn_args...
  shell.stderr.on 'data', (data) -> console.error "> " + "#{data}".trim()
  shell.stdout.on 'data', (data) -> console.debug "> " + "#{data}".trim()
  shell.on 'close', (code) ->
    shell.stdin.end()
    console.log 'Done'
    process.exit 0
  wait_data = util.promisify (cb) ->
    shell.stdout.once 'data', (chunk) ->
      setTimeout ->
        cb null, chunk
      , 1
  input_line = util.promisify (cmd, cb) ->
    console.debug "$ #{cmd}"
    shell.stdin.write "#{cmd}\n", (p...) ->
      await wait_data() if platform in ['win32']
      cb p...
  if platform in ['win32']
    await wait_data()
    new_time = dayjs().add(delta, 'ms')
    cmd = new_time.format adjust_command
  else
    adjust_command = adjust_command.replace /ss\.S+/, 'ss'
    new_time = dayjs().add(delta, 'ms')
    ms = new_time.get('millisecond')
    if ms > 0
      wait_time = 1000 - ms
      new_time = new_time.add(wait_time, 'ms')
      delay wait_time
    cmd = new_time.format adjust_command
  await input_line cmd
  await input_line 'exit'


# win32: get local date format by command:
# reg query "HKCU\Control Panel\International" /v sShortDate
#* @see # https://calendars.wikia.org/wiki/Date_format_by_country
if platform isnt 'win32'
  adjust_time.COMMAND = '[date -s ]"YYYY-MM-DD HH:mm:ss"'
else
  date_format = 'MM-DD-YY'
  try
    date_format_raw = ('' + execSync(
      'reg query "HKCU\\Control Panel\\International" /v sShortDate'
    )).trim().split(/[\n\r]+/).pop()?.trim().split(/\s+/).pop()
  catch err
    null
  if date_format_raw and date_format_raw isnt ''
    date_format = date_format_raw.
      replace(/[^YMDymd]+/g, '-').
      replace(/y+/gi, 'YY').
      replace(/m+/gi, 'MM').
      replace(/d+/gi, 'DD')
  adjust_time.COMMAND = '[time ]HH:mm:ss.SS[ && date ]' + date_format


SHELL_ARGS = {
  win32: [
    'cmd'
    ['/q', '/k', 'prompt $H && chcp 65001 > nul']
    {
      windowsHide: true
    }
  ]
  linux: [
    'sh'
  ]
}
spawn_args = SHELL_ARGS[platform] or SHELL_ARGS.linux
if not /UTF\-8/i.test (process.env.LANGUAGE or '')
  process.env.LANGUAGE = 'C.UTF-8'


module.exports = adjust_time