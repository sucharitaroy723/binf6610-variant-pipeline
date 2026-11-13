PRAGMA foreign_keys = ON;

CREATE TABLE pipelines (
    pipeline_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    version TEXT NOT NULL,
    implementation TEXT NOT NULL,
    UNIQUE (name, version, implementation)
);

CREATE TABLE runs (
    run_id TEXT PRIMARY KEY NOT NULL,
    pipeline_id INTEGER NOT NULL REFERENCES pipelines (pipeline_id),
    started_at TEXT NOT NULL,
    finished_at TEXT NOT NULL,
    exit_status TEXT NOT NULL,
    platform TEXT NOT NULL,
    executor TEXT NOT NULL,
    samplesheet TEXT NOT NULL,
    reference TEXT NOT NULL,
    region TEXT NOT NULL,
    folder TEXT NOT NULL
);

CREATE TABLE samples (
    sample_id TEXT PRIMARY KEY NOT NULL,
    sex TEXT,
    population TEXT,
    family TEXT,
    father TEXT,
    mother TEXT,
    phenotype TEXT,
    is_synthetic_phenotype TEXT,
    run TEXT,
    read_length TEXT,
    bases_gb TEXT,
    study TEXT,
    native_layout TEXT,
    library_type TEXT
);

CREATE TABLE run_samples (
    run_id TEXT NOT NULL REFERENCES runs (run_id),
    sample_id TEXT NOT NULL REFERENCES samples (sample_id),
    condition TEXT NOT NULL,
    library_type TEXT NOT NULL,
    PRIMARY KEY (run_id, sample_id)
);

CREATE TABLE variants (
    run_id TEXT NOT NULL REFERENCES runs (run_id),
    chrom TEXT NOT NULL,
    pos INTEGER NOT NULL,
    ref TEXT NOT NULL,
    alt TEXT NOT NULL,
    qual REAL,
    filter TEXT NOT NULL
);

CREATE TABLE outputs (
    run_id TEXT NOT NULL REFERENCES runs (run_id),
    path TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    PRIMARY KEY (run_id, path)
);

CREATE INDEX run_samples_by_sample ON run_samples (sample_id);
CREATE INDEX variants_by_run ON variants (run_id);
