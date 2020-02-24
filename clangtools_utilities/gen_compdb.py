# Ryunosuke O'Neil, 2019
# roneil@fnal.gov
# ryunosuke.oneil@postgrad.manchester.ac.uk

# create a compile_commands.json from scons.
# run with Offline as cwd and with mu2e set up correctly.

import os, json

def main():
    GCC_PATH = os.environ['COMPILER_PATH']
    print ('Getting all compile commands..')
    os.system('scons --no-cache --dry-run > .temp_compile_cmds')

    cwd = os.getcwd()

    compile_cmds = []
    with open('.temp_compile_cmds', 'r') as f:
        for line in f.readlines():
            line = line.replace('\n','')
            if line.startswith('scons: '): continue
            if not line.startswith('g++'): continue
            filename = line.split(' ')[-1]

            if not line.endswith('.cc'): continue
            compile_cmds.append({"directory": cwd,
                "command": '%s' % (line),
                "file": filename})

    with open('compile_commands.json', 'w') as f:
        f.write(json.dumps(compile_cmds))



if __name__ == "__main__":
    main()
