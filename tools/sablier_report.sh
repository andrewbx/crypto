#!/bin/bash
# Using a pre-configured dune sql query to query sablier eligibility results

curl -skL "https://api.dune.com/api/v1/query/3433345/results?api_key=${API_KEY}" \
    > sablier.report.json

cat sablier.report.json \
    | jq -cr '.result | .rows[] | [.block_date,.token_id,.address,.locked_for,.locked]' \
    | sed 's/\[//g;s/\]//g;s/\"//g;s/,/ /g' \
    | while read -r a b c d e; \
        do \
            if [[ ($a = "") ]]; then \
                break; \
            else \
                echo -n "$a,$b,$c,$d,$e,"; \
                curl -s "https://v2-services.vercel.app/api/eligibility?cid=${CID}&address=$c" \
                | jq '.message // "Eligible"'; \
            fi \
            >> sablier.report.csv; \
        done

sed -i '' 's/\"The provided address is not eligible for this campaign\"/Not Eligible/g;s/"\Eligible\"/Eligible/g' \
    sablier.report.csv
