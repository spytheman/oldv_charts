## Run this with:
##    sqlite3 data.sqlite < q.sql |tail -n 30
## .. to measure the effect of having an index like the one from add_date_index.sql
.stats on

SELECT
commit_hash, state, v_hello_default_id, date, tested,
csize_mean, clines_mean,
vsize_mean, vlines_mean, vtypes_mean, vmodules_mean, vfiles_mean,
vlines_ps_min, vlines_ps_max, vlines_ps_mean, vlines_ps_stddev,
scan_min, scan_max, scan_mean, scan_stddev,
parse_min, parse_max, parse_mean, parse_stddev,
check_min, check_max, check_mean, check_stddev,
transform_min, transform_max, transform_mean, transform_stddev,
markused_min, markused_max, markused_mean, markused_stddev,
cgen_min, cgen_max, cgen_mean, cgen_stddev,
total_stages_min, total_stages_max, total_stages_mean, total_stages_stddev,
total_min, total_max, total_mean, total_stddev
FROM commits
LEFT JOIN `measurements` ON commits.v_hello_default_id = measurements.id
WHERE commits.state IN (1, 7) AND commits.v_hello_default_id IS NOT NULL AND commits.date > 1735656552
ORDER BY date desc
LIMIT 0,60000;
