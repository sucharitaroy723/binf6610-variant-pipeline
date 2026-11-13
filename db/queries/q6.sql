SELECT rs.run_id, s.sex, COUNT(*) AS n_samples
FROM run_samples AS rs
JOIN samples AS s USING (sample_id)
GROUP BY rs.run_id, s.sex;
