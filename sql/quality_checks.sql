-- SQLite. Each row is an executable control; zero failures means PASS.
-- source_row_id is an ingestion position, not a borrower identifier.
WITH checks AS (
 SELECT 'source_row_count' AS control, ABS(COUNT(*)-1000) AS failures FROM loans
 UNION ALL
 SELECT 'source_id_uniqueness', COUNT(*)-COUNT(DISTINCT source_row_id) FROM loans
 UNION ALL
 SELECT 'missing_values', COUNT(*) FROM loans WHERE
   laufkont IS NULL OR laufzeit IS NULL OR moral IS NULL OR verw IS NULL OR hoehe IS NULL
   OR sparkont IS NULL OR beszeit IS NULL OR rate IS NULL OR famges IS NULL
   OR buerge IS NULL OR wohnzeit IS NULL OR verm IS NULL OR "alter" IS NULL
   OR weitkred IS NULL OR wohn IS NULL OR bishkred IS NULL OR beruf IS NULL
   OR pers IS NULL OR telef IS NULL OR gastarb IS NULL OR kredit IS NULL
 UNION ALL
 SELECT 'category_domains', COUNT(*) FROM loans WHERE
   laufkont NOT BETWEEN 1 AND 4 OR moral NOT BETWEEN 0 AND 4 OR verw NOT BETWEEN 0 AND 10
   OR sparkont NOT BETWEEN 1 AND 5 OR beszeit NOT BETWEEN 1 AND 5 OR rate NOT BETWEEN 1 AND 4
   OR famges NOT BETWEEN 1 AND 4 OR buerge NOT BETWEEN 1 AND 3 OR wohnzeit NOT BETWEEN 1 AND 4
   OR verm NOT BETWEEN 1 AND 4 OR weitkred NOT BETWEEN 1 AND 3 OR wohn NOT BETWEEN 1 AND 3
   OR bishkred NOT BETWEEN 1 AND 4 OR beruf NOT BETWEEN 1 AND 4 OR pers NOT IN (1,2)
   OR telef NOT IN (1,2) OR gastarb NOT IN (1,2) OR kredit NOT IN (0,1)
 UNION ALL
 SELECT 'positive_numeric_values', COUNT(*) FROM loans WHERE laufzeit<=0 OR hoehe<=0 OR "alter"<=0
 UNION ALL
 SELECT 'outcome_counts', ABS(SUM(kredit=0)-300)+ABS(SUM(kredit=1)-700) FROM loans
 UNION ALL
 SELECT 'split_id_uniqueness', COUNT(*)-COUNT(DISTINCT id) FROM splits
 UNION ALL
 SELECT 'split_membership', COUNT(*) FROM splits WHERE split IS NULL OR split NOT IN ('train','validation','test')
 UNION ALL
 SELECT 'source_without_split', COUNT(*) FROM loans l LEFT JOIN splits s ON l.source_row_id=s.id WHERE s.id IS NULL
 UNION ALL
 SELECT 'split_without_source', COUNT(*) FROM splits s LEFT JOIN loans l ON l.source_row_id=s.id WHERE l.source_row_id IS NULL
 UNION ALL
 SELECT 'split_counts', ABS(SUM(split='train')-600)+ABS(SUM(split='validation')-200)+ABS(SUM(split='test')-200) FROM splits
 UNION ALL
 SELECT 'split_outcome_balance', COUNT(*) FROM (
   SELECT s.split FROM splits s JOIN loans l ON s.id=l.source_row_id GROUP BY s.split
   HAVING SUM(l.kredit=0) <> CASE WHEN s.split='train' THEN 180 ELSE 60 END
       OR SUM(l.kredit=1) <> CASE WHEN s.split='train' THEN 420 ELSE 140 END
 )
)
SELECT control, failures, CASE WHEN failures=0 THEN 'PASS' ELSE 'FAIL' END AS status FROM checks;
