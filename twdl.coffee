Path    = require 'path'
URL     = require 'url'
twit    = require 'twit'
wget    = require 'wgetjs'

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
  console.log data
  wget { url: data.url, dest: data.dest }


# using job queue if installed
if kue
  # kue.app.listen 3000

  jobs = kue.createQueue()
  jobs.promote 100

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
        jobs.create('download', data).save()
      else
        download data
