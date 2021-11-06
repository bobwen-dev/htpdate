util = require 'util'
{ spawn } = require 'child_process'
dayjs = require 'dayjs'
delay = require './delay'
dayjs.extend require './dayjs_format_ms'
platform = require('os').platform()


adjust_time = (delta) ->
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
    cmd = new_time.format adjust_time.command
  else
    adjust_time.command = adjust_time.command.replace /ss\.S+/, 'ss'
    new_time = dayjs().add(delta, 'ms')
    ms = new_time.get('millisecond')
    if ms > 0
      wait_time = 1000 - ms
      new_time = new_time.add(wait_time, 'ms')
      delay wait_time
    cmd = new_time.format adjust_time.command
  await input_line cmd
  await input_line 'exit'


COMMANDS = {
  # FIXME get the perfect win32 command with right format
  # yes I got it, weird but effective
  # reg query "HKEY_CURRENT_USER\Control Panel\International" /v sShortDate
  # various formats need to be recognized...
  #* @see # https://calendars.wikia.org/wiki/Date_format_by_country
  win32: '[time ]HH:mm:ss.SS[ && date ]MM-DD-YY'
  linux: '[date -s ]"YYYY-MM-DD HH:mm:ss"'
}
adjust_time.command = COMMANDS[platform] or COMMANDS.linux


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