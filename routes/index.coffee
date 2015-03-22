express = require('express')
router = express.Router()

asycn = require('async')
Evernote = require('evernote').Evernote;
client = require('../servers/ervernote')
noteStore = client.getNoteStore()


### GET home page. ###

router.get '/', (req, res, next) ->
  res.render 'index', title: 'Express'
  return

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
  noteStore.getNote noteGuid, true, false,false,false, (err, note) ->
    if err
      return console.log err

    console.log note

    return res.render 'note', {
      content:note.content
    }




module.exports = router