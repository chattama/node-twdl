EventEmitter = require('events').EventEmitter
fs      = require 'fs'
Path    = require 'path'
URL     = require 'url'
twit    = require 'twit'
wget    = require 'wgetjs'
mkdirp  = require 'mkdirp'

try
  nosql = require 'nosql'
catch
  nosql = null

try
  kue   = require 'kue'
catch
  kue   = null

config  = require './config.json'


token = config.token ? {}

s = config.stream ? {}
s.path = s.path ? 'user'
s.param = s.param ? {}


if process.argv.length < 3
  process.exit(1)

screen_name_list = process.argv[2..]

end_count = 0


dir = config.dest ? './download/'


# download job
download = (data)->
  opt = { url: data.url, dest: data.dest }
  console.log opt.url
  wget opt


db = null
if nosql
  db = nosql.load config.db ? './twdl'


if kue
  # kue.app.listen 3000

  jobs = kue.createQueue()
  jobs.promote 300000

  jobs.process 'twd-user-download', (job, done)->
    download job.data
    done()


# twitter stream
twitter = new twit token


ee = new EventEmitter


limit = (param)->

  twitter.get 'application/rate_limit_status', {}, (err, data, response)->

    if err
      ee.emit 'err', err

    l = data.resources.statuses['/statuses/user_timeline']

    if l.remaining == 0
      console.log l
      ee.emit 'wait_reset', l.reset, param
    else
      user_timeline param


user_timeline = (param)->

  twitter.get 'statuses/user_timeline', param, (err, tl, response)->

    if err
      ee.emit 'err', { screen_name: param.screen_name, error: err }

    tl = tl ? []

    if param.max_id
      tl.shift()

    max_id = null

    for tweet in tl

      # add queue
      for m in tweet.entities.media ? []

        url = name = m.media_url

        if url.match /pbs.twimg.com/
          url += ':large'
          name = Path.basename URL.parse(name).pathname

        if name and url
          data = { url: url, dest: Path.join(dir, param.screen_name, name) }
          if kue
            jobs.create('twd-user-download', data).save()
          else
            download data

      max_id = tweet.id_str

    if max_id
      ee.emit 'get', { screen_name: param.screen_name, count: 200, max_id: max_id }
    else
      ee.emit 'end'


ee.on 'get', (param)->
  limit param


ee.on 'wait_reset', (reset, param)->
  console.log 'waiting...'
  console.log reset, param


ee.on 'end', ()->
  end_count++
  if (screen_name_list.length-1) == end_count
    process.exit(0)


ee.on 'err', (err)->
  console.error err
  if (screen_name_list.length-1) == end_count
    process.exit(1)


for screen_name in screen_name_list
  diruser = Path.join(dir, screen_name)
  if not fs.existsSync(diruser)
    mkdirp.sync diruser
  ee.emit 'get', { screen_name: screen_name, count: 200 }

