express = require('express')
router = express.Router()

async = require('async')
uniq = require('uniq')
fs = require('fs')
crypto = require('crypto')
Evernote = require('evernote').Evernote;

client = require('../servers/ervernote')
noteStore = client.getNoteStore('https://app.yinxiang.com/shard/s5/notestore')
Note = require('../models/note')
Tags = require('../models/tags')
SyncStatus = require('../models/sync_status')
Redis = require('ioredis')
redis = new Redis()

Sync2 = require('../servers/sync2')
help = require('../servers/help')
getLocalTime = help.getLocalTime
getYear = help.getYear
toInt = help.toInt

### GET home page. ###
router.get '/', (req, res, next) ->
  page = toInt(req.query.page)
  page = 1 if page <= 0 or not page
  count = 0
  async.parallel
    getCount: (cb) ->
#      Note.count (err, number) ->
#        if err
#          return console.log err
#        count = Math.ceil number / 10
#        cb()
      redis.get 'noteCount', (err, number) ->
        return console.log err if err
        count = number
        cb()

    pageNote: (cb) ->
#      Note.find().sort('-created').skip(10 * (page - 1)).limit(10).exec (err, notes) ->
#        return console.log err if err
#        cb(null, notes)
      redis.get 'page:' + page, (err, notes) ->
        return console.log err if err
        notes = JSON.parse(notes)
        cb(null, notes)

    getRecentNote: (cb) ->
#      Note.find().sort('-created').limit(4).exec (err, notes) ->
#        if err
#          return console.log err
#
#        cb(null, notes)
      redis.get 'recentNote', (err, notes) ->
        return console.loge err if err

        notes = JSON.parse notes
        cb(null, notes)

    getTags: (cb) ->
#      Tags.findOne (err, tags) ->
#        return console.log err if err
#
#        cb(null, tags)
      redis.hgetall 'tags', (err, tags) ->
        return console.log err if err

        tags.tags = tags.tags.split(',')
        cb(null, tags)

  , (err, result) ->
    return console.log err if err
    return res.render 'index', {
      notes: result.pageNote
      currPage: page
      countPage: count
      recentNote: result.getRecentNote
      tags: result.getTags.tags
      title: "友情's 笔记"
    }


### 查找对应笔记 ###
router.get '/note/:noteGuid', (req, res, next) ->
  noteGuid = req.params.noteGuid
  async.parallel
    findNote: (cb) ->
      time1 = Date.now()
#      Note.findOne {guid: noteGuid}, (err, note) ->
#        if err
#          return console.log err
#
#        return next() if not note
#        time2 = Date.now()
#        console.log time2 - time1
#        cb(null, note)

      redis.hgetall noteGuid, (err, notes) ->
        return console.log err if err

        return next() if not notes

#        console.log notes

        notes.tags = notes.tags.split(',')
        time2 = Date.now()
        console.log time2 - time1
        cb(null, notes)

    recentNote: (cb) ->
#      Note.find().sort('-created').limit(4).exec (err, notes) ->
#        if err
#          return console.log err
#
#        cb(null, notes)

      redis.get 'recentNote', (err, notes) ->
        return console.loge err if err

        notes = JSON.parse notes
        cb(null, notes)

    getTags: (cb) ->
#      Tags.findOne (err, tags) ->
#        return console.log err if err
#        cb(null, tags)
      redis.hgetall 'tags', (err, tags) ->
        return console.log err if err

        tags.tags = tags.tags.split(',')
        cb(null, tags)


  , (autoErr, result) ->
    return console.log autoErr if autoErr
    return res.render 'note', {
      note: result.findNote,
#      getLocalTime: getLocalTime,
      recentNote: result.recentNote
      tags: result.getTags.tags
      title: result.findNote.title
    }

### 查找对应标签笔记列表 ###
router.get '/tag/:tag/', (req, res, next) ->
  tag = req.params.tag.trim()
#  query = "this.tags.indexOf('#{tag}') > -1"
  async.parallel
    findNotes: (cb) ->
      Note.find({tags:tag}, 'title': 1, 'guid': 1, 'tags': 1, 'updated': 1, 'created': 1)
      .sort('-created').exec (err, notes) ->
        return console.log err if err
        return next() if not notes.length
        cb(null, notes)


    getTags: (cb) ->
      Tags.findOne (err, tags) ->
        return console.log err if err
        console.log tags
        cb(null, tags)

  , (autoErr, result) ->
    return console.log autoErr if autoErr
    return res.render 'tags_note', {
      notes: result.findNotes
      tag: tag
      getLocalTime: getLocalTime
      tags: result.getTags.tags
      title: "Tags #{tag}"

    }

### 档案 ###
router.get '/archive', (req, res) ->
  async.auto
    getNotes: (cb) ->
      Note.find({}, 'guid': 1, 'created': 1, 'title': 1).sort('-created').exec (err, notes) ->
        return console.log err if err

        cb(null, notes)


    getYear: ['getNotes', (cb, result) ->
      notes = result.getNotes
      archive = {}
      async.eachSeries notes, (item, callback) ->
        year = getYear(item.created)
        if not archive[year]
          console.log "year ==>", year
          archive[year] = []
          archive[year].push item
        else
          archive[year].push item
        callback()

      , (eachErr) ->
        return console.log eachErr if eachErr
#        tmp = []
#        for i, v of archive
#          tmp1 = {}
#          tmp1[i] = v
#          tmp.push tmp1
#
##        console.log tmp.reverse()
#        console.log "archive", archive
        return res.render 'archive', {
          archives: archive
          getLocalTime: getLocalTime
          title: "Archive List"

        }

    ]


router.get '/about', (req, res) ->
  return res.render 'about', {title: 'About'}


#router.get '/sync', (req, res) ->
#  sync = new Sync()
#  async.series [
#      (cb) ->
#        sync.checkStatus (err) ->
#          return cb(err) if err
#          console.log("sync.needSync", sync.needSync)
#          if sync.needSync is false
#            return res.send "status not change don't need sync"
#          else
#            cb()
#      (cb) ->
#        sync.getNoteCount (err) ->
#          return cb(err) if err
#          cb()
#
#      (cb) ->
#        loopNum = [0...sync.page]
#        async.eachSeries loopNum, (item, callback) ->
#          sync.syncInfo item * 50, 50, (err) ->
#            return callback(err) if err
#            callback()
#
#        , (eachErr) ->
#          return cb(eachErr) if eachErr
#          cb()
#      (cb) ->
#        sync.updateNoteBookTags (err) ->
#          return cb(err) if err
#          cb()
#    ]
#  , (sErr) ->
#    return console.log sErr if sErr
#    res.send("sync new note ok")


router.get '/sync2', (req, res) ->
  sync = new Sync2()

  async.auto
    checkStatus: (cb) ->
      cb()
#      sync.compleSyncStatus (err, result) ->
#        if err
#          return console.log err
#
#        if result is true
#          cb()
#        else
#          return res.send "don't need update"

    syncInfo: ['checkStatus', (cb) ->
      sync.syncInfo (err) ->
        if err
          return console.log err

        return console.log "sync all do"
    ]


#router.get '/img', (req, res) ->
#
#  note = new Evernote.Note();
#  note.title = "Test note from EDAMTest.js"
#  image = fs.readFileSync(__dirname + '/01.png')
#  statInfo = fs.statSync(__dirname + '/01.png')
#  return console.log statInfo
#  hash = image.toString('base64')
#
#  data = new Evernote.Data()
#  data.size = image.length
#  data.bodyHash = hash
#  data.body = image
#
#  resource = new Evernote.Resource()
#  resource.mime = 'image/png'
#  resource.data = data
#
#  note.resources = [resource]
#  md5 = crypto.createHash('md5')
#  md5.update(image)
#  hashHex = md5.digest('hex')
#
#  note.content = '<?xml version="1.0" encoding="UTF-8"?>';
#  note.content += '<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">';
#  note.content += '<en-note>Here is the Evernote logo:<br/>';
#  note.content += '<en-media type="image/png" hash="' + hashHex + '"/>';
#  note.content += '</en-note>';
#
#  noteStore.createNote note, (err, info) ->
#    if err
#      return console.log err
#
#    console.log info
#
module.exports = router