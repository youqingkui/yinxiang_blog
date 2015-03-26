Evernote = require('evernote').Evernote;
async = require('async')
client = require('../servers/ervernote')
noteStore = client.getNoteStore('https://app.yinxiang.com/shard/s5/notestore')
Note = require('../models/note')
SyncStatus = require('../models/sync_status')
eqArr = require('./help').eqArr



SyncNewNote = () ->
  @guid = 'bd6d5877-9ff8-400d-9d83-f6c4baeb2406'
  @filterNote = new Evernote.NoteFilter()
  @filterNote.notebookGuid = @guid
  @countNoteNum = 0
  @needSync = false
  @serverSync = null

  # 设置查找返回的参数
  @reParams = new Evernote.NotesMetadataResultSpec()
  @reParams.includeTitle = true
  @reParams.includeCreated = true
  @reParams.includeUpdated = true
  @reParams.includeDeleted = true
  @reParams.includeTagGuids = true
  @reParams.includeNotebookGuid = true

  return


SyncNewNote::checkStatus = (cb) ->
  self = @
  async.auto
    getServerStatus:(callback) ->
      noteStore.getSyncState (err, info) ->
        return callback(err) if err
        callback(null, info)

    getDbStatusInfo:(callback) ->
      self.getDbStatus (err, row) ->
        return callback(err) if err
        callback(null, row)

    compareStatus:['getServerStatus', 'getDbStatusInfo', (callback, result) ->
      serverInfo = result.getServerStatus
      dbInfo = result.getDbStatusInfo
      console.log "serverInfo", serverInfo
      console.log "dbInfo", dbInfo

      if serverInfo.updateCount != dbInfo.updateCount
        self.updateStatus serverInfo, dbInfo, (err, row) ->
          return callback(err) if err
          self.needSync = true
          callback()
      else
        callback()
    ]

  ,(autoErr) ->
      return cb(autoErr) if autoErr
      cb()

SyncNewNote::updateStatus = (s, d, cb) ->
  d.currentTime = s.currentTime
  d.fullSyncBefore = s.fullSyncBefore
  d.updateCount = s.updateCount
  d.uploaded = s.uploaded
  d.save (err, row) ->
    return cb(err) if err
    cb(null, row)

SyncNewNote::getDbStatus = (cb) ->
  SyncStatus.findOne (err, row) ->
    return cb(err) if err
    if not row
      newStatus = new SyncStatus()
      newStatus.save (sErr, newStatus) ->
        return cb(sErr) if sErr
        cb(null, newStatus)
    else
      cb(null, row)


SyncNewNote::getNoteCount = (cb) ->
  self = @
  noteStore.findNoteCounts @filterNote, false, (err, info) ->
    if err
      cb(err)
    else
      self.countNoteNum =info.notebookCounts[self.guid]
      self.page = Math.ceil(self.countNoteNum / 50)
      console.log "......................."
      console.log info
      console.log "countNoteNum ==>", self.countNoteNum
      console.log "page ==>", self.page
      console.log "......................."
      cb()


SyncNewNote::syncInfo = (offset, max, fun) ->
  self = @
  async.auto
    getSimpleInfo:(cb) ->
      noteStore.findNotesMetadata self.filterNote, offset, max, self.reParams, (err, info) ->
        return cb(err) if err
        console.log "findNotesMetadata offset", offset
        console.log info
        cb(null, info.notes)

    checkNew:['getSimpleInfo', (cb, result) ->
      simpleArr = result.getSimpleInfo
      self.checkSimpleNote simpleArr, (err) ->
        return cb(err) if err
        cb()
    ]

  ,(autoErr) ->
      return fun(autoErr) if autoErr
      console.log "in here"
      fun()


SyncNewNote::checkSimpleNote = (simpleArr, cb) ->
  console.log "checkSimpleNote"
  self = @
  async.eachSeries simpleArr, (item, callback) ->
    Note.findOne {'guid':item.guid}, (findErr, note) ->
      return callback(findErr) if findErr
      if not note
        self.createNote item, (cErr, newNote) ->
          console.log "new note", newNote.title
          return callback(cErr) if cErr
          callback()
      else
        console.log "up note title ==>", note.title
        self.updateNote note, item, (uErr, upNote) ->

          return callback(uErr) if uErr
          callback()

  ,(eachErr) ->
    return cb(eachErr) if eachErr
    cb()

SyncNewNote::updateNote = (note, upInfo, cb) ->
  self = @
  async.auto
    updateNoteBase:(callback) ->
      self.updateNoteBase note, upInfo, (err, note1) ->
        return callback(err) if err
        callback(null, note1)

    updateNoteContent:['updateNoteBase', (callback, result) ->
      note = result.updateNoteBase
      self.updateNoteContent note, (err, note2) ->
        return callback(err) if err
        callback(null, note2)
    ]

    updateNoteTagName:['updateNoteContent', (callback, result) ->
      note = result.updateNoteContent
      self.updateNoteTagName note, (err, note3) ->
        return callback(err) if err
        callback(null, note3)
    ]
  ,(autoErr) ->
      return cb(autoErr) if autoErr
      cb()



SyncNewNote::updateNoteBase = (note, upInfo, cb) ->
  baseUp = ['title', 'created', 'updated', 'deleted', 'tagGuids', 'notebookGuid']
  upBase = false
  for i in baseUp
    if note[i] != upInfo[i]
      note[i] = upInfo[i]
      upBase = true

  if upBase
    note.save (err, row) ->
      return cb(err) if err
      cb(null, row)
  else
    cb(null, note)


SyncNewNote::updateNoteContent = (note, cb) ->

  noteStore.getNoteContent note.guid, (err, content) ->
    return cb(err) if err
    if note.content != content
      note.content = content
      note.save (sErr, row) ->
        return cb(sErr) if sErr
        cb(null, row)
    else
      cb(null, note)

SyncNewNote::updateNoteTagName = (note, cb) ->
  console.log "up note tag =========", note.title
#  console.log note
  noteStore.getNoteTagNames note.guid, (err, tagArr) ->
    console.log tagArr
    return cb(err) if err
    if eqArr(note.tags, tagArr)
      cb(null, note)
    else
      note.tags = tagArr
      note.save (sErr, row) ->
        return cb(sErr) if sErr
        cb(null, row)


SyncNewNote::createNote = (simpleInfo, cb) ->
  self = @
  newNote = new Note()
  newNote.title = simpleInfo.title
  newNote.guid = simpleInfo.guid
  newNote.created = simpleInfo.created
  newNote.updated = simpleInfo.updated
  newNote.deleted = simpleInfo.deleted
  newNote.tagGuids = simpleInfo.tagGuids
  newNote.notebookGuid = simpleInfo.notebookGuid
  newNote.save (sErr, note) ->
    return cb(sErr) if sErr
    self.getNoteContent note, (gErr, newNote) ->
      return cb(gErr) if gErr
      cb(null, newNote)


SyncNewNote::getNoteContent = (note, cb) ->
  noteStore.getNoteContent note.guid, (err, content) ->
    return cb(err) if err
    note.content = content

    note.save (sErr, newNote) ->
      return cb(sErr) if sErr
      cb(null, newNote)




module.exports = SyncNewNote










