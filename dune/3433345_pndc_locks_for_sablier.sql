-- Slightly modified query to produce from @mogie_eth__x__magick_eth/all_locks
-- Locks at 49 weeks and older than 11 days from now (Used for the Feb 15th 2024 report)
-- Used for Sablier Eligibility report.
WITH
  locks AS (
    SELECT DISTINCT
      log.tx_hash,
      --   log.index,
      log.tx_from AS address,
      CONCAT(
        '<a href="https://debank.com/profile/',
        COALESCE(CAST(log.tx_from AS VARCHAR), ''),
        '" target="_blank">',
        COALESCE(
          NULLIF(ens.reverse_latest.name, ''),
          CAST(log.tx_from AS VARCHAR),
          ''
        ),
        '</a>'
      ) AS wallet,
      log.block_time,
      log.block_number,
      log.tx_index,
      log.contract_address,
      varbinary_to_int256 (BYTEARRAY_SUBSTRING (data, 1, 32)) / 1e18 AS locked,
      varbinary_to_int256 (BYTEARRAY_SUBSTRING (data, 33, 32)) AS starts_at,
      varbinary_to_int256 (BYTEARRAY_SUBSTRING (data, 66, 32)) AS locked_for_raw,
      varbinary_to_int256 (log.topic2) AS token_id
    FROM
      ethereum.logs log
      LEFT JOIN ens.reverse_latest ON ens.reverse_latest.address = log.tx_from
    WHERE
      log.block_number >= 18930110
      AND log.contract_address = 0xed96E69d54609D9f2cFf8AaCD66CCF83c8A1B470
      AND log.topic0 = 0x1b25091f383cba212d5e47f30dcc73a111f1304bf07e7f2c8503c7c311ddc6f0
  ),
  clean AS (
    SELECT
      *,
      case
        when locked_for_raw = 2 then 1
        when locked_for_raw = 8 then 9
        when locked_for_raw = 32 then 25
        when locked_for_raw = 64 then 36
        when locked_for_raw = 128 then 49
        when locked_for_raw = 4 then 4
        when locked_for_raw = 16 then 16
        else locked_for_raw
      end AS locked_for,
      case
        when locked_for_raw = 2 then 0.5
        when locked_for_raw = 8 then 4.5
        when locked_for_raw = 32 then 12.5
        when locked_for_raw = 64 then 18
        when locked_for_raw = 128 then 24.5
        when locked_for_raw = 4 then 2
        when locked_for_raw = 16 then 8
        else 0
      end AS streaming_yield_multiplier
    FROM
      locks
  )
SELECT
  *,
  DATE(block_time) AS block_date,
  starts_at - 2820 AS interval,
  case
    when starts_at = 2820 then 0
    else starts_at - 2821
  end AS interval2,
  starts_at + locked_for_raw AS ends_at,
  starts_at + locked_for_raw - 2820 AS ends_at_interval,
  starts_at + locked_for AS ends_at_ui,
  starts_at + locked_for - 2820 AS ends_at_interval_ui,
  date_add(
    'day',
    cast(locked_for * 7 AS bigint) + 7,
    block_time
  ) AS unlocked_at,
  date_trunc(
    'day',
    date_add(
      'day',
      cast(locked_for * 7 AS bigint) + 7,
      block_time
    )
  ) AS unlocked_at_day
FROM
  clean
WHERE
  block_time < now() - interval '11' day
  AND locked_for = 49
ORDER BY
  block_time
