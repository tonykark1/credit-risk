-- Sample composition only: these proportions are not population default rates.
SELECT s.split, COUNT(*) AS records,
       SUM(1-l.kredit) AS bad_credits,
       ROUND(AVG(1.0-l.kredit),4) AS bad_credit_share,
       ROUND(AVG(l.laufzeit),2) AS mean_duration_months
FROM loans l JOIN splits s ON l.source_row_id=s.id
GROUP BY s.split ORDER BY s.split;
