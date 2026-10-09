#!/usr/bin/env python3
"""Interrupt a real Docker smoke run at the first BWA submission and save its evidence."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--smoke', type=Path, default=Path.home() / 'Desktop' / 'smoke')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    smoke = args.smoke.expanduser().resolve()
    for name in ('samplesheet.csv', 'smoke.fa', 'smoke.dict'):
        if not (smoke / name).is_file():
            parser.error(f'missing smoke input: {smoke / name}')
    evidence = root / 'evidence' / 'assignment4'
    evidence.mkdir(parents=True, exist_ok=True)
    stamp = str(time.time_ns())
    log_path = evidence / 'interrupted.log'
    snapshot = evidence / 'interrupted.nextflow.log'
    receipt = evidence / 'interruption.json'
    # Keep the earlier completed attempts rather than replacing their logs.
    for path in (log_path, snapshot, receipt):
        if path.exists():
            path.rename(path.with_name(f'{path.stem}.before-auto-{stamp}{path.suffix}'))
    command = [
        'nextflow', 'run', 'main.nf', '-profile', 'docker', '-ansi-log', 'false',
        '--samplesheet', str(smoke / 'samplesheet.csv'),
        '--ref', str(smoke / 'smoke.fa'), '--region', 'smoke_1mb',
        '--outdir', 'results-interrupt-auto',
    ]
    started = time.time()
    interrupted = False
    run_name = None
    with log_path.open('w') as log:
        process = subprocess.Popen(
            command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, bufsize=1, start_new_session=True,
        )
        for line in process.stdout:
            print(line, end='', flush=True)
            log.write(line)
            log.flush()
            match = re.search(r'Launching .* \[([^]]+)\]', line)
            if match:
                run_name = match.group(1)
            if not interrupted and 'Submitted process > BWA_MEM' in line:
                try:
                    os.killpg(process.pid, signal.SIGINT)
                    interrupted = True
                    message = '[helper] Sent SIGINT (the Control+C signal) at the first BWA task.\n'
                    print(message, end='', flush=True)
                    log.write(message)
                    log.flush()
                except ProcessLookupError:
                    pass
        status = process.wait()
    nextflow_log = root / '.nextflow.log'
    if nextflow_log.exists() and nextflow_log.stat().st_mtime >= started:
        shutil.copyfile(nextflow_log, snapshot)
    receipt.write_text(json.dumps({
        'command': command, 'run_name': run_name,
        'interrupted': interrupted, 'signal': 'SIGINT' if interrupted else None,
        'trigger': 'first Submitted process > BWA_MEM line',
        'process_return_code': status,
        'shell_exit_status': 128 - status if status < 0 else status,
    }, indent=2) + '\n')
    print(f'Interruption triggered: {interrupted}; Nextflow return code: {status}', flush=True)
    print(f'Evidence saved in {evidence}', flush=True)
    if not interrupted or status == 0:
        raise SystemExit('The interruption exercise did not complete as intended; inspect the log.')
    print('Next: resume this run with the same arguments and -resume.', flush=True)


if __name__ == '__main__':
    main()
