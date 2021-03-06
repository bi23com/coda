#!/usr/bin/env python3

# In dune files, require preprocessing by ppx_coda, so that the version syntax linter is always run

import subprocess
import string
import sexpdata

dune_string = subprocess.check_output(['find','src','-name','dune'])

dune_paths_raw = dune_string.decode ('utf-8').split('\n')

# filter out dune paths where we don't require linting
def dune_paths_ok (dune) :
  path = dune.split ('/')
  path_prefix2 = path[1:2]
  path_prefix3 = path[1:3]
  return (not (path_prefix2 == ['_build'] or path_prefix2 == ['external'] or
               path_prefix3 == ['lib', 'snarky'] or path_prefix3 == ['lib', 'ppx_coda']))

dune_paths = list(filter(lambda s : len(s) > 0 and dune_paths_ok (s),dune_paths_raw))

library = sexpdata.loads ('library')
executable = sexpdata.loads ('executable')
preprocess = sexpdata.loads ('preprocess')
pps = sexpdata.loads ('pps')
no_preprocessing = sexpdata.loads ('no_preprocessing')

ppx_lint = sexpdata.loads ('ppx_coda')

exit_code = 0

def missing_ppx_error (dune,ppx) :
    print ("In dune file " + dune + ", the preprocessing clause is missing; there should be one containing " + (sexpdata.dumps (ppx)))
    global exit_code
    exit_code = 1

def no_ppx_error (dune,ppx) :
    print ("In dune file " + dune + ", the preprocessing clause indicates no preprocessing, but it should include " + (sexpdata.dumps (ppx)))
    global exit_code
    exit_code = 1

def get_ppx_ndx (dune,ppxs,ppx) :
    try :
      ppxs.index (ppx)
    except :
      print ("In dune file " + dune + ", the preprocessing clause does not contain " + (sexpdata.dumps (ppx)))
      global exit_code
      exit_code = 1

for dune in dune_paths :
  with open (dune) as fp :
        # wrap in parens to get list of top-level clauses
        sexps = sexpdata.loads ('(' + fp.read () + ')')
        for sexp in sexps :
            if isinstance (sexp,list) and len (sexp) > 0 and (sexpdata.car (sexp) == library or sexpdata.car (sexp) == executable) :
                clauses = sexpdata.cdr (sexp)
                found_preprocess = False
                for clause in clauses :
                  if sexpdata.car (clause) == preprocess :
                    found_preprocess = True
                    subclause = sexpdata.car (sexpdata.cdr (clause))
                    if subclause == no_preprocessing :
                      # error if no preprocessing explicitly
                      no_ppx_error (dune,ppx_lint)
                    elif sexpdata.car (subclause) == pps :
                      ppxs = sexpdata.cdr (subclause)
                      lint_ppx_ndx = get_ppx_ndx (dune,ppxs,ppx_lint)
                if found_preprocess == False :
                  # error if no preprocessing implicitly
                  missing_ppx_error (dune,ppx_lint)

exit (exit_code)
