"""Builds one Luau file that runs the server services against a fake Roblox environment.
Usage: python3 tools/sim/build_sim.py out.luau && luau out.luau   (needs the Luau CLI from github.com/luau-lang/luau)"""
import os,sys
here=os.path.dirname(os.path.abspath(__file__))
root=os.path.join(here,'..','..','src')
mods={}
def add(path,key):
    mods[key]=open(path).read()
for d,tree in (('shared','Shared'),):
    for dp,_,fs in os.walk(f'{root}/{d}'):
        for f in fs:
            rel=os.path.relpath(os.path.join(dp,f),f'{root}/{d}')[:-5].replace('/','.')
            add(os.path.join(dp,f),f'Shared.{rel}')
for f in os.listdir(f'{root}/server/Services'):
    add(f'{root}/server/Services/{f}',f'Services.{f[:-5]}')
out=['local MODS = {}']
for k,v in mods.items():
    out.append(f'MODS["{k}"] = function(script)\n{v}\nend')
import sys
body=open(os.path.join(here,'harness.luau')).read()
open(sys.argv[1],'w').write('\n'.join(out)+'\n'+body)
