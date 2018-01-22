#!/usr/bin/env python
import os
import sys
import glob

def get_inv_file(filepath):
    list_of_files = glob.glob(filepath+'*')
    print list_of_files
    latest_file = max(list_of_files, key=os.path.getctime)
    return filepath+latest_file

class FilterModule(object):
    ''' A filter to fetch latest file '''
    def filters(self):
        return {
            'get_inv_file': get_inv_file
        }
