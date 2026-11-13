"""Load variant-calling run folders into the SQLite database."""

import argparse
from contextlib import closing
import csv
import json
import os
from pathlib import Path
import sqlite3


def tsv_rows(path):
    with path.open(encoding="utf-8", newline="") as handle:
        yield from csv.DictReader(
            (line for line in handle if not line.startswith("#")), delimiter="\t"
        )


def load_metadata(con, path):
    with con:
        con.executemany(
            """
            INSERT INTO samples (
                sample_id, sex, population, family, father, mother, phenotype,
                is_synthetic_phenotype, run, read_length, bases_gb, study,
                native_layout, library_type
            ) VALUES (
                :sample_id, :sex, :population, :family, :father, :mother, :phenotype,
                :is_synthetic_phenotype, :run, :read_length, :bases_gb, :study,
                :native_layout, :library_type
            ) ON CONFLICT (sample_id) DO UPDATE SET
                sex = excluded.sex, population = excluded.population,
                family = excluded.family, father = excluded.father,
                mother = excluded.mother, phenotype = excluded.phenotype,
                is_synthetic_phenotype = excluded.is_synthetic_phenotype,
                run = excluded.run, read_length = excluded.read_length,
                bases_gb = excluded.bases_gb, study = excluded.study,
                native_layout = excluded.native_layout, library_type = excluded.library_type
            """,
            tsv_rows(path),
        )


def load_run(con, folder):
    manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
    pipeline = manifest["pipeline"]
    run_id = pipeline["run_id"]

    with con:
        # Acquire the write lock before checking the ID so concurrent loads can skip it too.
        con.execute("BEGIN IMMEDIATE")
        if con.execute("SELECT 1 FROM runs WHERE run_id = ?", (run_id,)).fetchone():
            print(f"Skipped {folder} ({run_id} already loaded)")
            return

        pipeline_key = (pipeline["name"], pipeline["version"], pipeline["implementation"])
        con.execute(
            """
            INSERT INTO pipelines (name, version, implementation) VALUES (?, ?, ?)
            ON CONFLICT (name, version, implementation) DO NOTHING
            """,
            pipeline_key,
        )
        pipeline_id, = con.execute(
            """
            SELECT pipeline_id FROM pipelines
            WHERE name = ? AND version = ? AND implementation = ?
            """,
            pipeline_key,
        ).fetchone()

        platform = manifest["platform"]
        params = manifest["params"]
        con.execute(
            """
            INSERT INTO runs (
                run_id, pipeline_id, started_at, finished_at, exit_status,
                platform, executor, samplesheet, reference, region, folder
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                run_id, pipeline_id, pipeline["started_at"], pipeline["finished_at"],
                pipeline["exit_status"], platform["kind"], platform["executor"],
                params["samplesheet"], params["ref"], params["region"], os.path.abspath(folder),
            ),
        )

        # samples.tsv supplies the condition. Library type comes from the manifest.
        libraries = {sample["sample_id"]: sample["library_type"] for sample in manifest["samples"]}

        samples = list(tsv_rows(folder / "samples.tsv"))
        con.executemany(
            "INSERT INTO samples (sample_id) VALUES (?) ON CONFLICT (sample_id) DO NOTHING",
            ((sample["sample_id"],) for sample in samples),
        )
        con.executemany(
            """
            INSERT INTO run_samples (run_id, sample_id, condition, library_type)
            VALUES (?, ?, ?, ?)
            """,
            (
                (run_id, sample["sample_id"], sample["condition"], libraries[sample["sample_id"]])
                for sample in samples
            ),
        )
        if len(libraries) != len(manifest["samples"]):
            raise ValueError("duplicate sample ID in manifest.json")

        con.executemany(
            """
            INSERT INTO variants (run_id, chrom, pos, ref, alt, qual, filter)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                (
                    run_id, row["chrom"], int(row["pos"]), row["ref"], row["alt"],
                    None if row["qual"] in {"", "."} else float(row["qual"]), row["filter"],
                )
                for row in tsv_rows(folder / "variants.tsv")
            ),
        )
        con.executemany(
            "INSERT INTO outputs (run_id, path, sha256) VALUES (?, ?, ?)",
            (
                (run_id, item["path"], item["checksum"].split(":", 1)[1].lower())
                for item in manifest["outputs"]
            ),
        )
    print(f"Loaded {folder} ({run_id})")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("database", type=Path)
    parser.add_argument("metadata", type=Path)
    parser.add_argument("folders", type=Path, nargs="+")
    args = parser.parse_args()

    source = args.metadata
    try:
        database_uri = args.database.absolute().as_uri() + "?mode=rw"
        with closing(sqlite3.connect(database_uri, uri=True)) as con:
            con.execute("PRAGMA foreign_keys = ON")
            load_metadata(con, args.metadata)
            for folder in args.folders:
                source = folder
                load_run(con, folder)
    except (OSError, ValueError, KeyError, sqlite3.Error) as error:
        parser.exit(1, f"Load failed for {source}: {error}\n")


if __name__ == "__main__":
    main()
