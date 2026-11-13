SELECT r.run_id, r.folder || '/cohort.filtered.vcf.gz' AS file, o.sha256
FROM runs AS r
LEFT JOIN outputs AS o
    ON r.run_id = o.run_id AND o.path = 'cohort.filtered.vcf.gz';
