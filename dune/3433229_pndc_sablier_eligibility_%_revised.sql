-- Dataset is a query of Locked PNDC where:
-- Duration = 49 weeks
-- PNDC Locked older than 11 days ago (From 15th Feb 2024)
-- Addresses are used to query Sablier API for Eligibility
-- NOTE: This is a dataset and not regularly updated
-- Group Results
WITH eligible AS (
  SELECT
    date_locked,
    sablier_eligibility,
    COUNT(*) AS count
  FROM dune.andrewbx.dataset_sablierreport
  WHERE
    sablier_eligibility = 'Eligible'
  GROUP BY
    date_locked,
    sablier_eligibility
), not_eligible AS (
  SELECT
    date_locked,
    sablier_eligibility,
    COUNT(*) AS count
  FROM dune.andrewbx.dataset_sablierreport
  WHERE
    sablier_eligibility = 'Not Eligible'
  GROUP BY
    date_locked,
    sablier_eligibility
), eligibility AS (
  SELECT
    e.date_locked,
    e.sablier_eligibility,
    e.count,
    ne.sablier_eligibility AS ne_sablier_eligibility,
    ne.count AS ne_count
  FROM eligible AS e
  JOIN not_eligible AS ne
    ON ne.date_locked = e.date_locked
)
SELECT
  date_locked,
  count AS eligble,
  ne_count AS not_eligible
FROM eligibility
ORDER BY
  date_locked DESC
