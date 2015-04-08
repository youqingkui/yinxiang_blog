Evernote = require('evernote').Evernote;
async = require('async')
client = require('../servers/ervernote')
noteStore = client.getNoteStore('https://app.yinxiang.com/shard/s5/notestore')
Note = require('../models/note')
Tags = require('../models/tags')
SyncStatus = require('../models/sync_status')
uniq = require('uniq')
cheerio = require('cheerio')
eqArr = require('./help').eqArr


class sync
  constructor: () ->
    # 设置查找过滤的笔记本
    @guid = 'bd6d5877-9ff8-400d-9d83-f6c4baeb2406'
    @filterNote = new Evernote.NoteFilter()
    @filterNote.notebookGuid = @guid

    # 设置查找返回的参数
    @reParams = new Evernote.NotesMetadataResultSpec()
    @reParams.includeTitle = true
    @reParams.includeCreated = true
    @reParams.includeUpdated = true
    @reParams.includeDeleted = true
    @reParams.includeTagGuids = true
    @reParams.includeNotebookGuid = true

  getPageCount: (cb) ->
    self = @
    noteStore.findNoteCounts @filterNote, false, (err, Info) ->
      return cb(err) if err

      countNoteNum = info.notebookCounts[self.guid]
      page = Math.ceil(countNoteNum / 50)
      cb(null, page)

  syncInfo: (offset, max, cb) ->
    self = @

    async.auto
      getNote:(callback) ->
        noteStore.findNotesMetadata self.filterNote, offset, max,
                                          self.reParams, (err, info) ->

          return cb(err) if err
          callback(null, info)


      upNote:(callback, result) ->
        noteArr = result.getNote



  upNoteInfo: (item, cb) ->
    self = @
    async.auto
      findNote:(callback) ->
        Note.findOne guid:item.guid, (err, note) ->
          return callback(err) if err

          cb(null, note)

      composeUp:(callback, result) ->
        note = result.findNote
        if not note
          cggc = async.compose(
            self.changeImgHtml,self.getTagName,
                  self.getContent,self.createNote)
          cggc note




  createNote: (noteInfo, cb) ->
    newNote = new Note()
    newNote.guid = noteInfo.guid
    newNote.title = noteInfo.title
    newNote.content = noteInfo.content
    newNote.created = noteInfo.created
    newNote.updated = noteInfo.updated
    newNote.tagGuids = noteInfo.tagGuids
    newNote.notebookGuid = noteInfo.notebookGuid

    cb(null, newNote)


  getContent: (note, cb) ->
    noteStore.getNoteContent note.guid, (err, content) ->
      return cb(err) if err

      note.content = content if note.content != content
      cb(null, note)


  getTagName: (note, cb) ->
    noteStore.getNoteTagNames note.guid, (err, tagsName) ->
      return cb(err) if err

      note.tags = tagsName if not eqArr note.tags, tagsName
      cb(null, note)


  upbaseInfo: (note, upInfo, cb) ->
    for v, k of upInfo
      note[k] = v

    cb(null, note)

  changeImgHtml:(note, cb) ->
    $ = cheerio.load(note.content)
    all_media = $('en-media')
    async.eachSeries all_media, (item, callback) ->
      return console.log err if err

      newTag = $("<img src=/images/#{item.attribs.hash + MIME_TO_EXTESION_MAPPING[item.attribs.type]}>")
      $(item).replaceWith(newTag)
      callback()

    ,(eachErr) ->
      return cb(eachErr) if eachErr

      note.htmlContent = $.html()
      cb(null, note)



















class CreateNote
  constructor: (@noteInfo) ->

  save: (cb) ->
    newNote = new Note()
    newNote.guid = @noteInfo.guid
    newNote.title = @noteInfo.title
    newNote.content = @noteInfo.content
    newNote.created = @noteInfo.created
    newNote.updated = @noteInfo.updated
    newNote.tagGuids = @noteInfo.tagGuids
    newNote.notebookGuid = @noteInfo.notebookGuid
    newNote.save (err, row) ->
      return cb(err) if err
      cb(null, row)


class GetContent
  constructor: (@noteInfo) ->
    super

  get: (cb) ->





