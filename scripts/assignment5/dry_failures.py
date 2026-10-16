#!/usr/bin/env python3
"""Cause failures 2 and 3 independently; always restore the original Snakefile."""
from pathlib import Path
import re
import subprocess
import sys
p = Path('Snakefile')
original = p.read_text()
evidence = Path('evidence/assignment5')
evidence.mkdir(parents=True, exist_ok=True)
cmd = ['snakemake', '--profile', 'profiles/laptop', '-n', *sys.argv[1:]]
variants = {
    'failure2-log-wildcard': original.replace('"logs/bwa_mem/{sample}.log"', '"logs/bwa_mem.log"'),
    'failure3-fastp-ambiguity': re.sub(r'    wildcard_constraints:\n        sample=one_of\((PAIRED|SINGLE)\),\n', '', original),
}
try:
    for name, broken in variants.items():
        if broken == original:
            raise RuntimeError('Could not apply deliberate change: ' + name)
        p.write_text(broken)
        run = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        content = '$ ' + ' '.join(cmd) + '\n' + run.stdout + '\nexit_status=' + str(run.returncode) + '\n'
        (evidence / (name + '.txt')).write_text(content)
        print(content)
finally:
    p.write_text(original)
