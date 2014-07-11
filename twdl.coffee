Path    = require 'path'
URL     = require 'url'
twit    = require 'twit'
wget    = require 'wgetjs'

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

dir = config.dest ? './download/'


# download job
download = (data)->
  opt = { url: data.url, dest: data.dest }
  if db
    db.count (doc)->
      doc.url == opt.url
    , (count)->
      if count == 0
        console.log opt.url
        wget opt
        db.insert opt
        db.update()
  else
    wget opt


db = null
if nosql
  db = nosql.load config.db ? './twdl'


# using job queue if installed
if kue
  # kue.app.listen 3000

  jobs = kue.createQueue()
  jobs.promote 300000

  jobs.process 'download', (job, done)->
    download job.data
    done()


# twitter stream
twitter = new twit token

stream = twitter.stream s.path, s.param


stream.on 'tweet', (tweet)->

  for m in tweet.entities.media ? []
    url = name = m.media_url

    if url.match /pbs.twimg.com/
      url += ':large'
      name = Path.basename URL.parse(name).pathname

    if name and url
      data = { url: url, dest: Path.join(dir, name) }
      if kue
        #console.log 'job: ' + url
        jobs.create('download', data).save()
      else
        download data
