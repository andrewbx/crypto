-- Dataset is a query of Locked PNDC where:
-- Duration = 49 weeks
-- PNDC Locked older than 11 days ago (From 15th Feb 2024)
-- Addresses are used to query Sablier API for Eligibility
-- NOTE: This is a dataset and not regularly updated
-- Detailed Results
SELECT
  date_locked,
  token_id,
  CONCAT(
    '<a href="https://v2-services.vercel.app/api/eligibility?cid=QmVSddivy7x4CGnAX3UUr7UDu5RZzEf9zgnEzoS5zBjrRk&address=',
    COALESCE(CAST(wallet_address AS VARCHAR), ''),
    '" target="_blank">',
    COALESCE(CAST(wallet_address AS VARCHAR), ''),
    '</a>'
  ) AS wallet_sablier,
  --https://app.zerion.io/<wallet_address>/overview
  CONCAT(
    '<a href="https://app.zerion.io/',
    COALESCE(CAST(wallet_address AS VARCHAR), ''),
    '/overview" target="_blank">',
    COALESCE(CAST(wallet_address AS VARCHAR), ''),
    '</a>'
  ) AS wallet_zerion,
  weeks,
  amount_locked,
  sablier_eligibility
FROM
  dune.andrewbx.dataset_sablierreport
ORDER BY
  date_locked DESC,
  CAST(amount_locked AS REAL) DESC
