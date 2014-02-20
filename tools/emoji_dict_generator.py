#!/usr/bin/env python

import os
import glob
import json

mapping = {}
rev_mapping = {}

for f in glob.glob('/Users/leo/humbug/static/third/gemoji/images/emoji/*.png'):
    if os.path.islink(f):
        name = os.path.basename(f).split('.')[0]
        target = os.readlink(f)
        codepoint = os.path.basename(target).split('.')[0]
        if '-' in codepoint:
            a, b = codepoint.split('-')
            uc = (r'\U' + a.zfill(8)) + (r'\U' + b.zfill(8))
        else:
            uc = r'\U' + codepoint.zfill(8)
        decoded = (uc).decode('unicode-escape')
        mapping[name] = decoded
        rev_mapping[decoded]=name

print json.dumps(mapping)
print json.dumps(rev_mapping)
