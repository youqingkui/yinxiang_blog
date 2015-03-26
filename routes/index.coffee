express = require('express')
router = express.Router()

async = require('async')
uniq = require('uniq')

Evernote = require('evernote').Evernote;
client = require('../servers/ervernote')
noteStore = client.getNoteStore('https://app.yinxiang.com/shard/s5/notestore')
Note = require('../models/note')
Tags = require('../models/tags')
SyncStatus = require('../models/sync_status')

SyncNewNote = require('../servers/sync_simple')
help = require('../servers/help')
getLocalTime = help.getLocalTime
getYear = help.getYear
toInt = help.toInt


### GET home page. ###

router.get '/', (req, res, next) ->
  page = toInt(req.param('page'))
  page = 1 if page <= 0 or not page
  count = 0
  async.auto
    getCount:(cb) ->
      Note.count (err, number) ->
        if err
          return console.log err
        console.log "count note ==>", number
        count = Math.ceil number / 10
        console.log "1"
        cb()

    pageNote:(cb) ->
      Note.find().sort('-created').skip(10 * (page - 1)).limit(10).exec (err, notes) ->
        return console.log err if err
        console.log "2"
        cb(null, notes)

    getRecentNote:(cb) ->
      Note.find().sort('-created').limit(4).exec (err, notes) ->
        if err
          return console.log err

        cb(null, notes)

    getTags:(cb) ->
      Tags.findOne (err, tags) ->
        return console.log err if err

        cb(null, tags)

  ,(err, result) ->
    return console.log err if err
    console.log result.getTags
    return res.render 'index', {
      notes:result.pageNote
      currPage:page
      countPage:count
      getLocalTime:getLocalTime
      recentNote:result.getRecentNote
      tags:result.getTags.tags
    }


router.get '/page/:page', (req, res) ->
  page = toInt(req.params.page)
  page = 1 if page <= 0
  count = 0
  async.auto
    getCount:(cb) ->
      Note.count (err, number) ->
        if err
          return console.log err
        console.log "count note ==>", number
        count = Math.ceil number / 10
        console.log "1"
        cb()

    pageNote:(cb) ->
      Note.find().sort('-created').skip(10 * (page - 1)).limit(10).exec (err, notes) ->
        return console.log err if err
        console.log "2"
        cb(null, notes)

  ,(err, result) ->
      return console.log err if err
      console.log getLocalTime(123333)
      return res.render 'index', {
        notes:result.pageNote
        currPage:page
        countPage:count
        getLocalTime:getLocalTime
      }


router.get '/note/:noteGuid', (req, res) ->
  noteGuid = req.params.noteGuid
  async.auto
    findNote:(cb) ->
      Note.findOne {guid:noteGuid}, (err, note) ->
        if err
          return console.log err

        next() if not note
        cb(null, note)

    recentNote:(cb) ->
      Note.find().sort('-created').limit(4).exec (err, notes) ->
        if err
          return console.log err

        cb(null, notes)

    getTags:(cb) ->
      Tags.findOne (err, tags) ->
        return console.log err if err
        cb(null, tags)


  ,(autoErr, result) ->
      return console.log autoErr if autoErr
      console.log result.getTags
      return res.render 'note', {
        note:result.findNote,
        getLocalTime:getLocalTime,
        recentNote:result.recentNote
        tags:result.getTags.tags
      }


router.get '/tag/:tag/', (req, res, next) ->
  tag = req.params.tag.trim()
  query = "this.tags.indexOf('#{tag}') > -1"
  async.auto
    findNotes:(cb) ->
      Note.find({},'title':1, 'guid':1, 'tags':1, 'updated':1, 'created':1)
      .where({$where:query}).sort('-created').exec (err, notes) ->
        return console.log err if err
        return next() if not notes.length
        cb(null, notes)


    getTags:(cb) ->
      Tags.findOne (err, tags) ->
        return console.log err if err
        cb(null, tags)

    ,(autoErr, result) ->
      return console.log autoErr if autoErr
      return res.render 'tags_note', {
        notes:result.findNotes
        tag:tag
        getLocalTime:getLocalTime
        tags:result.getTags.tags

      }


router.get '/archive', (req, res) ->
  async.auto
    getNotes:(cb) ->
      Note.find({}, 'guid':1, 'created':1, 'title':1).sort('-created').exec (err, notes) ->
        return console.log err if err
        cb(null, notes)


    getYear:['getNotes', (cb, result) ->
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

      ,(eachErr) ->
        return console.log eachErr if eachErr
        console.log archive
        return res.render 'archive', {'archive':archive, getLocalTime:getLocalTime}

    ]


router.get '/get_note_tag', (req, res) ->
  async.auto
    getNote:(cb) ->
      Note.find (err, notes) ->
        return console.log err if err

        cb(null, notes)

    getTagName:['getNote', (cb, result) ->
      notes = result.getNote
      async.eachSeries notes, (item, callback) ->
        noteStore.getNoteTagNames item.guid, (err, tags) ->
          return console.log err if err
          item.tags = tags
          item.save (err, note) ->
            return console.log err if err
            console.log "#{note.title} tag ==> #{tags}"
            callback()

      ,(eachErr) ->
        return console.log eachErr if eachErr
        res.send("get tag ok")
    ]


router.get '/create_tags', (req, res) ->
  Note.find({}, 'tags':1).exec (err, notes) ->
    return console.log err if err
    tags = []
    for note in notes
      for t in note.tags
        tags.push t

    tags = uniq(tags)
    Tags.findOne (err, info) ->
      return console.log err if err

      if not info
        newTag = new Tags()
        newTag.tags = tags
        newTag.save (err, row) ->
          return console.log err if err
          console.log "ok save tages", row
          return res.send("create_tags ok")

      else
        console.log "tag has"
        return res.send("tags already exits")


router.get '/new_note', (req, res) ->
  sync = new SyncNewNote()
  async.series [
#      (cb) ->
#        sync.checkStatus (err) ->
#          return cb(err) if err
#          console.log("sync.needSync", sync.needSync)
#          if sync.needSync is false
#            return res.send "status not change don't need sync"
#          else
#            cb()
      (cb) ->
        sync.getNoteCount (err) ->
          return cb(err) if err
          cb()

      (cb) ->
        loopNum = [0...sync.page]
        async.eachSeries loopNum, (item, callback) ->
          sync.syncInfo item * 50, 50, (err) ->
            return callback(err) if err
            callback()

        ,(eachErr) ->
          return cb(eachErr) if eachErr
          cb()
    ]
  ,(sErr) ->
    console.log "here"
    return console.log sErr if sErr
    res.send("sync new note ok")



#router.get '/notebooks', (req, res) ->
#  noteStore.listNotebooks (err, list) ->
#    if err
#      return console.log err
#    console.log list
#    return res.render 'notebook', {
#      notebooks: list
#    }
#
#router.get '/listnote', (req, res) ->
#  filterNote = new Evernote.NoteFilter()
#  guid = '2e5dc578-8a1d-4303-8be7-5711ea6fa301'
#  filterNote.notebookGuid = guid
#  noteStore.findNotes filterNote, 0, 10, (err, notes) ->
#    if err
#      console.log "here"
#      return console.log err
#    console.log notes
#    return res.render 'notes', {
#      notes:notes
#    }
#
#
#
#router.get '/test', (req, res) ->
#  filterNote = new Evernote.NoteFilter()
#  guid = 'bd6d5877-9ff8-400d-9d83-f6c4baeb2406'
#  filterNote.notebookGuid = guid
#
#  noteStore.findNotes filterNote, 0, 50, (err, notes) ->
#    if err
#      return console.log err
#    async.each notes.notes, (item, callback) ->
#      newNote = new Note()
#      newNote.guid = item.guid
#      newNote.title = item.title
#      newNote.content =  item.content
#      newNote.created = item.created
#      newNote.updated = item.updated
#      newNote.deleted = item.deleted
#      newNote.tagGuids = item.tagGuids
#      newNote.notebookGuid = item.notebookGuid
#      newNote.findSameGuid (err, note) ->
#        if err
#          return console.log err
#
#        if not note
#          newNote.save (err, noteInfo) ->
#            if err
#              return console.log err
#
#            callback()
#
#        else
#          console.log "已经存在:", note.guid
#          callback()
#
#    ,(eachErr) ->
#      if eachErr
#        return console.log err
#      return res.send "ok"
#      return res.redirect('/test_note')
#
#
#router.get '/test_note', (req, res) ->
#  async.auto
#    getDbNote:(cb) ->
#      Note.find (err, notes) ->
#        if err
#          return console.log err
#
#        cb(null, notes)
#
#    getNoteInfo:['getDbNote', (cb, result) ->
#      notes = result.getDbNote
#      async.eachSeries notes, (item, callback) ->
#        noteStore.getNote item.guid,true,false,false,false, (err, noteInfo) ->
#          if err
#            return console.log err
#
#          item.content = noteInfo.content
#          item.save (err, note) ->
#            if err
#              return console.log err
#
#            callback()
#
#      ,(eachErr) ->
#        if eachErr
#          console.log err if eachErr
#
#        return res.send "ok"
#    ]



#router.get '/test_db', (req, res) ->
#  newNote = new Note()
#  newNote.guid = '123456333'
##  newNote.save (err, res) ->
##    if err
##      return console.log err
##
##    console.log res
#  newNote.findSameGuid (err, note) ->
#    if err
#      return console.log err
#
#    console.log note
#
#
#router.get '/test_tag', (req, res) ->
#  guid = 'e57abb2a-3997-47f1-b9fe-ac94740130ce'
#  noteStore.getNoteTagNames guid, (err, tag) ->
#    if err
#      return console.log err
#
#    console.log tag
#
#  noteStore.listTagsByNotebook 'bd6d5877-9ff8-400d-9d83-f6c4baeb2406', (err, tags) ->
#    return console.log err if err
#    console.log tags
















#router.get '/sync', (req, res) ->
#  # 设置查找的笔记本
#  guid = 'bd6d5877-9ff8-400d-9d83-f6c4baeb2406'
#  filterNote = new Evernote.NoteFilter()
#  filterNote.notebookGuid = guid
#
#  # 设置查找返回的参数
#  reParams = new Evernote.NotesMetadataResultSpec()
#  reParams.includeTitle = true
#  reParams.includeCreated = true
#  reParams.includeUpdated = true
#  reParams.includeDeleted = true
#  reParams.includeTagGuids = true
#  reParams.includeNotebookGuid = true
#  reParams.includeTagGuids = true
#
#  noteStore.findNoteCounts filterNote, false, (err, info) ->
#    return console.log err if err
#    console.log info

#  noteStore.getNoteContent '178c3462-46a2-4b04-bc80-3c8aaf0ab60b', (err, info) ->
#    return console.log err if err
#    console.log info
#  noteStore.getNotebook guid, (err, info) ->
#    return console.log err if err
#    console.log info

#  noteStore.findNotesMetadata filterNote, 0, 100, reParams, (err, info) ->
#    return console.log err if err
#    console.log info.notes.length


#router.get '/sync_status', (req, res, next) ->
##  guid = 'bd6d5877-9ff8-400d-9d83-f6c4baeb2406'
##  filterNote = new Evernote.NoteFilter()
##  reParams = new Evernote.NotesMetadataResultSpec()
##  reParams.includeTitle = true
##  filterNote.notebookGuid = guid
#
#  async.auto
#    getDbSyncStatus:(cb) ->
#      SyncStatus.findOne (err, row) ->
#        return console.log err if err
#        cb(null, row)
#
#    getSyncStatus:(cb) ->
#      noteStore.getSyncState (err, info) ->
#        return console.log err if err
#        console.log info
#        console.log getLocalTime(info.currentTime / 1000)
#        console.log getLocalTime(info.fullSyncBefore / 1000)
#        cb(null, info)
#
#    createSyncStatus:['getDbSyncStatus', (cb, result) ->
#      row = result.getDbSyncStatus
#      if not row
#        newSatus = new SyncStatus()
#        newSatus.syncStatus = 0
#        newSatus.save (err, info) ->
#          return console.log err if err
#          cb(null, info)
#      else
#        cb(null, row)
#
#    ]
#
#    checkStatus:['createSyncStatus', 'getSyncStatus', (cb, result) ->
#      dbInfo = result.createSyncStatus
#      serverInfo = result.getSyncStatus
#      if dbInfo.syncStatus != serverInfo.updateCount
#        dbInfo.syncStatus = serverInfo.updateCount
#        dbInfo.save (err, row) ->
#          return console.log err if err
#          return res.redirect('/sync')
#
#      else
#        return res.send "no need syncs"
#    ]

router.get '/status', (req, res) ->
  noteStore.getSyncState (err, info) ->
    return console.log err if err
    console.log info


module.exports = router