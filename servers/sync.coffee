Evernote = require('evernote').Evernote;
async = require('async')
client = require('../servers/ervernote')
noteStore = client.getNoteStore('https://app.yinxiang.com/shard/s5/notestore')
Note = require('../models/note')
Tags = require('../models/tags')
SyncStatus = require('../models/sync_status')
uniq = require('uniq')

eqArr = require('./help').eqArr



Sync = () ->
  @guid = 'bd6d5877-9ff8-400d-9d83-f6c4baeb2406'
  @filterNote = new Evernote.NoteFilter()
  @filterNote.notebookGuid = @guid
  @countNoteNum = 0
  @serverTagNames = []
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

### 检查笔记状态，确定是否需要更新 ###
Sync::checkStatus = (cb) ->
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

### 更新同步状态 ###
Sync::updateStatus = (s, d, cb) ->
  d.currentTime = s.currentTime
  d.fullSyncBefore = s.fullSyncBefore
  d.updateCount = s.updateCount
  d.uploaded = s.uploaded
  d.save (err, row) ->
    return cb(err) if err
    cb(null, row)

### 获取数据库同步状态 ###
Sync::getDbStatus = (cb) ->
  SyncStatus.findOne (err, row) ->
    return cb(err) if err
    if not row
      newStatus = new SyncStatus()
      newStatus.save (sErr, newStatus) ->
        return cb(sErr) if sErr
        cb(null, newStatus)
    else
      cb(null, row)

### 得到笔记本笔记总数 ###
Sync::getNoteCount = (cb) ->
  self = @
  noteStore.findNoteCounts @filterNote, false, (err, info) ->
    if err
      cb(err)
    else
      self.countNoteNum =info.notebookCounts[self.guid]
      self.page = Math.ceil(self.countNoteNum / 50)
      console.log "countNoteNum ==>", self.countNoteNum
      console.log "page ==>", self.page
      cb()

### 同步笔记本笔记信息 ###
Sync::syncInfo = (offset, max, fun) ->
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
      self.upOrCrNote simpleArr, (err) ->
        return cb(err) if err
        cb()
    ]

  ,(autoErr) ->
      return fun(autoErr) if autoErr
      console.log "in here"
      fun()

### 创建或者更新笔记 ###
Sync::upOrCrNote = (simpleArr, cb) ->
  self = @
  async.eachSeries simpleArr, (item, callback) ->
    Note.findOne {'guid':item.guid}, (findErr, note) ->
      return callback(findErr) if findErr
      if not note
        self.createNote item, (cErr, newNote) ->
          return callback(cErr) if cErr
          console.log "create new note", newNote.title
          callback()
      else
        self.updateNote note, item, (uErr, upNote) ->
          return callback(uErr) if uErr
#          console.log "up note title ==>", upNote.title
          callback()

  ,(eachErr) ->
    return cb(eachErr) if eachErr
    cb()
### 更新笔记基本、内容、标签 ###
Sync::updateNote = (note, upInfo, cb) ->
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
  ,(autoErr, result) ->
      return cb(autoErr) if autoErr
      cb(null, result.updateNoteTagName)


### 更新笔记本基本信息 ###
Sync::updateNoteBase = (note, upInfo, cb) ->
  baseUp = ['title', 'created', 'updated', 'deleted', 'notebookGuid']
  upBase = false
  for i in baseUp
    if note[i] != upInfo[i]
      console.log "#{note[i]} != #{upInfo[i]}"
      note[i] = upInfo[i]
      upBase = true

  if Array.isArray(note['tagGuids']) is false or
        eqArr(note['tagGuids'], upInfo['tagGuids']) is false

      note['tagGuids'] = upInfo['tagGuids']
      upBase = true

  if upBase
    note.save (err, row) ->
      return cb(err) if err
      console.log "笔记 => #{note.title} 更改了基本信息"
      cb(null, row)
  else
    console.log "笔记 => #{note.title} 不需要更改基本信息"
    cb(null, note)

### 更新笔记本内容 ###
Sync::updateNoteContent = (note, cb) ->
  noteStore.getNoteContent note.guid, (err, content) ->
    return cb(err) if err
    if note.content != content
      note.content = content
      note.save (sErr, row) ->
        return cb(sErr) if sErr
        console.log "笔记 => #{row.title} 更新了笔记内容"
        cb(null, row)
    else
      console.log "笔记 => #{note.title} 内容不需要更新"
      cb(null, note)


### 更新笔记本标签名 ###
Sync::updateNoteTagName = (note, cb) ->
  self = @
  noteStore.getNoteTagNames note.guid, (err, tagArr) ->
    return cb(err) if err
    # 计算添加从服务器获取的笔记标签名
    for i in tagArr
      self.serverTagNames.push i

    if eqArr(note.tags, tagArr)
      console.log "笔记 => #{note.title} 不需要更新标签 "
      cb(null, note)
    else
      oldTagName = note.tags
      note.tags = tagArr
      note.save (sErr, row) ->
        return cb(sErr) if sErr
        console.log "笔记 => #{row.title} 标签由#{oldTagName}  变为 ==> #{row.tags}"
        cb(null, row)

### 创建笔记 ###
Sync::createNote = (simpleInfo, cb) ->
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
    console.log "创建了新笔记 => #{note.title}"
    self.getNoteContent note, (gErr, newNote) ->
      return cb(gErr) if gErr
      console.log "新笔记 #{newNote.title} 获取内容成功"
      cb(null, newNote)

### 获取笔记内容 ###
Sync::getNoteContent = (note, cb) ->
  noteStore.getNoteContent note.guid, (err, content) ->
    return cb(err) if err
    note.content = content

    note.save (sErr, newNote) ->
      return cb(sErr) if sErr
      cb(null, newNote)

### 更新笔记本标签 ###
Sync::updateNoteBookTags = (callback) ->
  self = @
  async.auto
    findDbTags:(cb) ->
      Tags.findOne (err, dTag) ->
        return cb(err) if err
        if not dTag
          newTags = new Tags()
          newTags.save (sErr, nTag) ->
            return cb(sErr) if sErr
            cb(null, nTag)
        else
          cb(null, dTag)

    compareTag:['findDbTags', (cb, result) ->
      dTag = result.findDbTags
      self.serverTagNames = uniq(self.serverTagNames)
      oldTags = uniq(dTag.tags)

      if eqArr(oldTags, self.serverTagNames) is false
        dTag.tags = self.serverTagNames
        dTag.save (err, uTag) ->
          return cb(err) if err
          console.log "笔记本标签#{oldTags} ==> #{uTag.tags}"
          cb()
      else
        console.log "笔记本标签不需要修改"
        cb()
    ]
  ,(autoErr) ->
      return callback(autoErr) if autoErr
      callback()







module.exports = Sync










