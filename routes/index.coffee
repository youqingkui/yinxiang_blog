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
redis = require('../models/redis')()

Sync2 = require('../servers/sync2')
help = require('../servers/help')
getLocalTime = help.getLocalTime
getYear = help.getYear
toInt = help.toInt
isEmpty = help.isEmpty

### GET home page. ###
router.get '/', (req, res, next) ->
  page = toInt(req.query.page)
  page = 1 if page <= 0 or not page
  count = 0
  async.parallel
    getCount: (cb) ->
      redis.get 'noteCount', (err, number) ->
        return console.log err if err

        count = number
        cb()

    pageNote: (cb) ->
      redis.get 'page:' + page, (err, notes) ->
        return console.log err if err

        return next() if isEmpty notes

        notes = JSON.parse(notes)
        cb(null, notes)

    getRecentNote: (cb) ->
      redis.get 'recentNote', (err, notes) ->
        return console.loge err if err

        return next() if isEmpty notes
        notes = JSON.parse notes
        cb(null, notes)

    getTags: (cb) ->
      redis.hgetall 'tags', (err, tags) ->
        return console.log err if err

        return next() if isEmpty tags

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
      redis.hgetall noteGuid, (err, notes) ->
        return console.log err if err

        return next() if isEmpty notes

        notes.tags = notes.tags.split(',')
        cb(null, notes)

    recentNote: (cb) ->
      redis.get 'recentNote', (err, notes) ->
        return console.loge err if err

        notes = JSON.parse notes
        cb(null, notes)

    getTags: (cb) ->
      redis.hgetall 'tags', (err, tags) ->
        return console.log err if err

        tags.tags = tags.tags.split(',')
        cb(null, tags)


  , (autoErr, result) ->
    return console.log autoErr if autoErr
    return res.render 'note', {
      note: result.findNote,
      recentNote: result.recentNote
      tags: result.getTags.tags
      title: result.findNote.title
    }

### 查找对应标签笔记列表 ###
router.get '/tag/:tag/', (req, res, next) ->
  tag = req.params.tag.trim()
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

        return res.render 'archive', {
          archives: archive
          getLocalTime: getLocalTime
          title: "Archive List"

        }

    ]


router.get '/about', (req, res) ->
  return res.render 'about', {title: 'About'}


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


module.exports = router