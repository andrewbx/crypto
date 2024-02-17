-- Dataset is a query of Locked PNDC where:
-- Duration = 49 weeks
-- PNDC Locked older than 11 days ago (From 15th Feb 2024)
-- Addresses are used to query Sablier API for Eligibility
-- NOTE: This is a dataset and not regularly updated
-- Group Results
SELECT
  date_locked,
  sablier_eligibility,
  count(*) AS count
FROM
  dune.andrewbx.dataset_sablierreport
GROUP BY
  date_locked,
  sablier_eligibility
ORDER BY
  date_locked DESC
