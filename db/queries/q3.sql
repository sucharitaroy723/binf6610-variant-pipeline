SELECT r.run_id, COUNT(v.run_id) AS n_variants,
       COUNT(CASE WHEN v.filter = 'PASS' THEN 1 END) AS n_pass
FROM runs AS r
LEFT JOIN variants AS v USING (run_id)
GROUP BY r.run_id;
