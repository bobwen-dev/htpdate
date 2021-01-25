module.exports = (o, c, d) ->
  proto = c.prototype
  old_format = proto.format
  proto.format = (fmt_str = 'YYYY-MM-DDTHH:mm:ssZ') ->
    locale = @$locale()
    utils = @$utils()
    r = fmt_str.replace /\[([^\]]+)]|SSS|S{2,2}|S/g, (word) =>
      switch word
        when 'S'
          "#{@$ms}"
        when 'SS'
          ms = Math.round(@$ms / 10)
          "#{ms}".padStart(2, '0')
        else
          word
    old_format.bind(this) r
