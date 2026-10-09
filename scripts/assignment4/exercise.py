#!/usr/bin/env python3
"""Apply one required laptop breakage and restore the exact original afterwards."""
import argparse
from pathlib import Path

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('action', choices=['queue', 'dollar', 'restore'])
args = parser.parse_args()
backup = root / '.a4-exercise-backup'

if args.action == 'restore':
    if not backup.exists():
        parser.error('no active exercise to restore')
    for saved in backup.rglob('*'):
        if saved.is_file():
            target = root / saved.relative_to(backup)
            target.write_bytes(saved.read_bytes())
            saved.unlink()
    for directory in sorted(backup.rglob('*'), key=lambda p: len(p.parts), reverse=True):
        if directory.is_dir():
            directory.rmdir()
    backup.rmdir()
    print('Restored the original pipeline files.')
else:
    if backup.exists():
        parser.error('restore the active exercise before applying another')
    if args.action == 'queue':
        relative = Path('main.nf')
        before = 'BWA_MEM(FASTP.out.reads, ref, ref_index)'
        after = 'BWA_MEM(FASTP.out.reads, channel.fromPath(params.ref), ref_index)'
    else:
        relative = Path('modules/bwa_mem.nf')
        before = r'n_records=\$(samtools view -c ${meta.id}.unsorted.bam)'
        after = r'n_records=$(samtools view -c ${meta.id}.unsorted.bam)'
    path = root / relative
    original = path.read_text()
    if original.count(before) != 1:
        parser.error(f'expected exactly one matching line in {relative}')
    saved = backup / relative
    saved.parent.mkdir(parents=True)
    saved.write_bytes(path.read_bytes())
    path.write_text(original.replace(before, after))
    print(f'Applied {args.action} exercise to {relative}.')
    print('After collecting the evidence: python3 scripts/assignment4/exercise.py restore')
