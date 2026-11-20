# Assignment 10: variant-call results dashboard

The app reads the existing Assignment 9 database. It does not run the variant
pipeline or modify the database. Run these commands on your laptop from the
repository root.

## Install and launch

```bash
python3 -m venv ~/.venvs/a10
source ~/.venvs/a10/bin/activate
pip install -r dashboard/requirements.txt
```

If `runs.db` does not already exist, build it once from your committed runs:

```bash
sqlite3 runs.db < db/schema.sql
python3 db/load.py runs.db db/variant-call-cohort.tsv \
    smoke-run-nf cluster-run-nf cluster-run-smk
```

Use a fresh database path if rebuilding; the schema creates new tables.
Then launch:

```bash
python3 dashboard/app.py runs.db
```

Open http://127.0.0.1:8050. Stop with Ctrl-C. For another port:

```bash
python3 dashboard/app.py runs.db 8051
```

Activate the venv again in each new terminal. The database path is required;
the optional port defaults to 8050. Database paths are relative to your current
terminal directory. The SQL file is located relative to `app.py`.

## Pages and interactions

- `/` executes `db/queries/q1.sql` and lists one link per run.
- `/results?run=<run_id>` shows only that run's samples and sites.
- `plot-filter` counts each exact FILTER string, including combined values.
- `plot-qual` plots every raw QUAL value in a histogram.
- `plot-type` counts multiallelic sites first (comma in ALT), then SNPs
  (one base each in REF and ALT), then indels.
- Click a FILTER or variant-type bar to replace the sites table with that
  category's sites. The latest click wins. **Show all sites** clears the selection.
- Tables support sorting, column filters and pagination. Pagination changes the
  visible page, not the underlying rows available to the acceptance tests.
- Phenotype labels are synthetic course metadata; absent metadata remains blank.

SQL uses parameters for run IDs and a separate read-only connection for each
query, so callbacks do not share SQLite connections across threads. Unknown
runs and routes show an explanatory page with a link back to the Runs page.

## Acceptance tests and submission

Keep the instructor's supplied tests in a separate folder, for example `~/a10`:

```bash
source ~/.venvs/a10/bin/activate
bash ~/a10/tests/run_acceptance.sh .
```

On a Mac whose `bash` is version 3.2, use `/opt/homebrew/bin/bash` instead.
The supplied tests passed all six checks (100/100) on 20 November 2026 using
five real runs from this repository. The report is in
`evidence/assignment10/acceptance.txt`. Tested versions: Python 3.12.14,
Dash 4.5.0, Dash AG Grid 35.3.0, Plotly 7.1.0, pandas 2.3.3, SQLite 3.53.1.

For submission, merge the dashboard branch into `main` and submit the repository
URL on Canvas. Do not commit `runs.db` or the virtual environment.
