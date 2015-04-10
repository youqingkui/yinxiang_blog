#!/usr/bin/env python
#coding=utf-8

import sys
from evernote.api.client import EvernoteClient, NoteStore, UserStore
import os

dev_token = os.environ.get('DeveloperToken')
client = EvernoteClient(token=dev_token, sandbox=False)
client.service_host = 'app.yinxiang.com'
noteStore = client.get_note_store()

hash_bin = sys.argv[1].decode('hex')
note_guid = sys.argv[2]
data = noteStore.getResourceByHash(note_guid, hash_bin, True, False, False)
# file_path = './'  + sys.argv[1]
# f = open(file_path, "w")
# f.write(data.data.body)
# f.close()

print (data.data.body.encode('base64'))