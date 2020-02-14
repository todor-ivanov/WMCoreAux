#!/usr/bin/python

import json
from textwrap import TextWrapper
from pprint import pprint
from collections import OrderedDict


def twClosure(replace_whitespace=False,
              break_long_words=False,
              width=120,
              initial_indent=''):
    """
    Deals with indentation of dictionaries with very long key, value pairs.
    replace_whitespace: Replace each whitespace character with a single space.
    break_long_words: If True words longer than width will be broken.
    width: The maximum length of wrapped lines.
    initial_indent: String that will be prepended to the first line of the output

    Wraps all strings for both keys and values to 120 chars.
    Uses 4 spaces indentation for both keys and values.
    Nested dictionaries and lists go to next line.
    """
    twr = TextWrapper(replace_whitespace=replace_whitespace,
                      break_long_words=break_long_words,
                      width=width,
                      initial_indent=initial_indent)

    def twEnclosed(obj, ind='', reCall=False):
        """
        The inner function of the closure
        ind: Initial indentation for the single output string
        reCall: Flag to indicate a recursive call (should not be used outside)
        """
        output = ''
        if isinstance(obj, dict):
            obj = OrderedDict(sorted(obj.items(),
                                     key=lambda t: t[0],
                                     reverse=False))
            if reCall:
                output += '\n'
            ind += '    '
            for key, value in obj.iteritems():
                output += "%s%s: %s" % (ind,
                                        ''.join(twr.wrap(key)),
                                        twEnclosed(value, ind, reCall=True))
        elif isinstance(obj, list):
            if reCall:
                output += '\n'
            ind += '    '
            for value in obj:
                output += "%s%s" % (ind, twEnclosed(value, ind, reCall=True))
        else:
            output += "%s\n" % str(obj)# join(twr.wrap(str(obj)))
        return output
    return twEnclosed


def twPrint(obj):
    """
    A simple caller of twClosure (see docstring for twClosure)
    """
    twPrinter = twClosure()
    print(twPrinter(obj))


with open('couchdb.wf0.info.json', 'r') as file:
    wfInfo = json.load(file)

print("-----------------------------")
twPrint(wfInfo)
print("-----------------------------")

