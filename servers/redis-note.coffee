redis = require('../models/redis')
Note = require('../models/note')
Tags = require('../models/tags')
async = require('async')
help = require('../servers/help')
getLocalTime = help.getLocalTime



class RedisNote
  constructor:() ->


  getNote:(cb) ->
    Note.find().sort('-created').exec (err, notes) ->
      return cb(err) if err

      cb(null, notes)


  getTags:(cb) ->
    Tags.findOne (err, tags) ->
      return cb(err) if err

      cb(null, tags)


  getRecentNote:(cb) ->
    Note.find().sort('-created').limit(4).exec (err, notes) ->
      return cb(err) if err

      cb(null, notes)


  cacheRecent:(notes, cb) ->
    recentNote = []
    async.each notes, (item, callback) ->
      noteJson = {}
      noteJson.title = item.title
      noteJson.guid = item.guid
      recentNote.push noteJson
      callback()

    ,() ->
      jsonStr = JSON.stringify recentNote
      redis.set 'recentNote', jsonStr, (err, res) ->
        return cb (err) if err

        console.log "cache recent note ok"
        cb()



  cacheTags:(tags, cb) ->
    redis.hmset 'tags', {tags:tags.tags}, (err, res) ->
      return cb(err) if err

      console.log "cache tags ok"
      cb()

  cacheNote:(notes, cb) ->
    async.eachSeries notes, (item, callback) ->
      note =
        title:item.title
        htmlContent:item.htmlContent
        created:getLocalTime(item.created / 1000)
        updated:getLocalTime(item.updated / 1000)
        tags:item.tags
        guid:item.guid
      redis.hmset item.guid, note, (err, res) ->
        return callback(err) if err

        callback()

    ,(err) ->
      return cb(err) if err

      console.log "cacheNote ok"
      cb()


  cacheRedis:() ->
    _this = @
    async.auto
      A:(cb) ->
        _this.getNote cb
      B:['A', (cb, result) ->
        _this.cacheNote result.A, cb
      ]

      C:(cb) ->
        _this.getTags cb
      D:['C', (cb, res) ->
          _this.cacheTags res.C, cb
      ]

      E:(cb) ->
        _this.getRecentNote cb
      F:['E', (cb, res) ->
        _this.cacheRecent res.E, cb
      ]


    ,(err) ->
        return console.log err if err

        console.log "cache ok"








rn = new RedisNote()
rn.cacheRedis()






