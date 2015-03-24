express = require('express')
router = express.Router()

async = require('async')
Evernote = require('evernote').Evernote;
client = require('../servers/ervernote')
noteStore = client.getNoteStore()
Note = require('../models/note')


### GET home page. ###

router.get '/', (req, res, next) ->
  Note.find (err, notes) ->
    if err
      return console.log err

    return res.render 'index', {notes:notes}



router.get '/notebooks', (req, res) ->
  noteStore.listNotebooks (err, list) ->
    if err
      return console.log err
    console.log list
    return res.render 'notebook', {
      notebooks: list
    }


router.get '/listnote', (req, res) ->
  filterNote = new Evernote.NoteFilter()
  guid = '2e5dc578-8a1d-4303-8be7-5711ea6fa301'
  filterNote.notebookGuid = guid
  noteStore.findNotes filterNote, 0, 10, (err, notes) ->
    if err
      console.log "here"
      return console.log err
    console.log notes
    return res.render 'notes', {
      notes:notes
    }

router.get '/note/:noteGuid', (req, res) ->
  noteGuid = req.params.noteGuid
  Note.findOne {guid:noteGuid}, (err, note) ->
    if err
      return console.log err
    if note
      console.log note
      return res.render 'note', {note:note}





router.get '/test', (req, res) ->
  filterNote = new Evernote.NoteFilter()
  guid = '2e5dc578-8a1d-4303-8be7-5711ea6fa301'
  filterNote.notebookGuid = guid

  noteStore.findNotes filterNote, 0, 100, (err, notes) ->
    if err
      return console.log err

    async.each notes.notes, (item, callback) ->
      newNote = new Note()
      newNote.guid = item.guid
      newNote.title = item.title
      newNote.content =  item.content
      newNote.created = item.created
      newNote.updated = item.updated
      newNote.deleted = item.deleted
      newNote.tagGuids = item.tagGuids
      newNote.notebookGuid = item.notebookGuid
      newNote.findSameGuid (err, note) ->
        if err
          return console.log err

        newNote.save (err, noteInfo) ->
          if err
            return console.log err

          console.log noteInfo














    return res.send("ok")


router.get '/test_note', (req, res) ->
  async.auto
    getDbNote:(cb) ->
      Note.find (err, notes) ->
        if err
          return console.log err

        cb(null, notes)

    getNoteInfo:['getDbNote', (cb, result) ->
      notes = result.getDbNote
      async.eachSeries notes, (item, callback) ->
        noteStore.getNote item.guid, true, false,false,false, (err, noteInfo) ->
          if err
            return console.log err

          item.content = noteInfo.content
          item.save (err, note) ->
            if err
              return console.log err

            console.log note
            callback()
    ]



router.get '/test_db', (req, res) ->
  newNote = new Note()
  newNote.guid = '123456333'
#  newNote.save (err, res) ->
#    if err
#      return console.log err
#
#    console.log res
  newNote.findSameGuid (err, note) ->
    if err
      return console.log err

    console.log note






module.exports = router