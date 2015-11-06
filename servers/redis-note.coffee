redis = require('../models/redis')()
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


  getNoteCount:(cb) ->
    Note.count (err, number) ->
      return cb(err) if err

      cb(null, number)


  cacheNoteCount:(number, cb) ->
    redis.set 'noteCount', number, (err, res) ->
      return cb(err) if err

      console.log "cache note count ok"
      cb()


  cachePageNote:(notes, cb) ->
    page = 1
    baseName = 'page:'
    while notes.length > 0
      pageName = baseName + page
      spliceArr = notes.splice(0, 10)
      spliceNote = []
      for i in spliceArr
        tmp =
          title:i.title
          tags:i.tags
          guid:i.guid
          created:getLocalTime(i.created / 1000)
          updated:getLocalTime(i.updated / 1000)

        spliceNote.push tmp

      spliceJson = JSON.stringify(spliceNote)
      redis.set pageName, spliceJson
      page = page +  1
      console.log page



    console.log "cache page ok"



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
    console.log notes.length
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

      # cache note
      A:(cb) ->
        _this.getNote cb
      B:['A', (cb, result) ->
        _this.cacheNote result.A, cb
      ]

      # cache tags
      C:(cb) ->
        _this.getTags cb
      D:['C', (cb, res) ->
          _this.cacheTags res.C, cb
      ]

      # cache recent note
      E:(cb) ->
        _this.getRecentNote cb
      F:['E', (cb, res) ->
        _this.cacheRecent res.E, cb
      ]

      # cache note count number
      G:(cb) ->
        _this.getNoteCount cb
      H:['G', (cb, res) ->
        _this.cacheNoteCount res.G, cb
      ]

      # cache page note
      J:['A', 'B', (cb, res) ->
        _this.cachePageNote res.A, cb
      ]



    ,(err) ->
        return console.log err if err

        console.log "cache ok"






module.exports = RedisNote




