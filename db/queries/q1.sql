SELECT r.run_id, p.implementation, r.platform,
       COUNT(s.sample_id) AS n_samples,
       ROUND((julianday(r.finished_at) - julianday(r.started_at)) * 1440, 1) AS minutes
FROM runs AS r
JOIN pipelines AS p USING (pipeline_id)
LEFT JOIN run_samples AS s USING (run_id)
GROUP BY r.run_id
ORDER BY julianday(r.started_at), r.folder;
