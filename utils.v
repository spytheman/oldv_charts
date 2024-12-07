module main

import os
import db.sqlite

struct Metric {
	min    i64
	max    i64
	mean   i64
	stddev i64
}

struct Measurement {
mut:
	commit       string
	date         i64
	tested       i64
	csize        int
	clines       int
	vsize        int
	vlines       int
	vlines_ps    Metric
	vtypes       int
	vmodules     int
	vfiles       int
	scan         Metric
	parse        Metric
	check        Metric
	cgen         Metric
	total_stages Metric
	total        Metric
}

fn exec_map(mut db sqlite.DB, query string) []map[string]string {
	rows := db.exec(query) or { panic(err) }
	mut res := []map[string]string{}
	columns := query.all_after('SELECT')
		.all_before('FROM')
		.split(',').map(it.replace('`', ' ')
		.trim_space())
	for row in rows {
		mut m := map[string]string{}
		for ci, cname in columns {
			m[cname] = row.vals[ci]
		}
		res << m
	}
	return res
}

fn metric(row map[string]string, name string) Metric {
	return Metric{
		min:    row['${name}_min'].i64()
		max:    row['${name}_max'].i64()
		mean:   row['${name}_mean'].i64()
		stddev: row['${name}_stddev'].i64()
	}
}

fn metric_us(row map[string]string, name string) Metric {
	return Metric{
		min:    row['${name}_min'].i64() / 1_000
		max:    row['${name}_max'].i64() / 1_000
		mean:   row['${name}_mean'].i64() / 1_000
		stddev: row['${name}_stddev'].i64() / 1_000
	}
}

fn metric_ms(row map[string]string, name string) Metric {
	return Metric{
		min:    row['${name}_min'].i64() / 1_000_000
		max:    row['${name}_max'].i64() / 1_000_000
		mean:   row['${name}_mean'].i64() / 1_000_000
		stddev: row['${name}_stddev'].i64() / 1_000_000
	}
}

fn get_measurements(max_n int, kind string) []Measurement {
	mut res := []Measurement{}
	mut db := sqlite.connect(os.getenv_opt('FAST_DB') or { 'data.sqlite' }) or { panic(err) }
	rows := exec_map(mut db, 'SELECT
                                 commit_hash, state, ${kind}, date, tested,
                                 csize_mean, clines_mean,
                                 vsize_mean, vlines_mean, vtypes_mean, vmodules_mean, vfiles_mean,
                                 vlines_ps_min, vlines_ps_max, vlines_ps_mean, vlines_ps_stddev,
                                 scan_min, scan_max, scan_mean, scan_stddev,
                                 parse_min, parse_max, parse_mean, parse_stddev,
                                 check_min, check_max, check_mean, check_stddev,
                                 cgen_min, cgen_max, cgen_mean, cgen_stddev,
                                 total_stages_min, total_stages_max, total_stages_mean, total_stages_stddev,
                                 total_min, total_max, total_mean, total_stddev
                              FROM commits
                              LEFT JOIN `measurements` ON commits.${kind} = measurements.id
                              WHERE commits.state = 1 AND commits.v_self_skip_unused_id IS NOT NULL AND commits.date > 1704063600
                              ORDER BY date desc
                              LIMIT 0,${max_n}
                              ')
	for row in rows {
		mut m := Measurement{}
		m.commit = row['commit_hash']
		m.date = row['date'].i64() * 1000 // ts in ms
		m.tested = row['tested'].i64() * 1000 // ts in ms
		m.csize = row['csize_mean'].int()
		m.clines = row['csize_mean'].int()
		m.vsize = row['vsize_mean'].int()
		m.vlines = row['vlines_mean'].int()
		m.vlines_ps = metric(row, 'vlines_ps')
		m.vtypes = row['vtypes_mean'].int()
		m.vmodules = row['vmodules_mean'].int()
		m.vfiles = row['vfiles_mean'].int()
		m.scan = metric(row, 'scan')
		m.parse = metric(row, 'parse')
		m.check = metric(row, 'check')
		m.cgen = metric(row, 'cgen')
		m.total_stages = metric(row, 'total_stages')
		m.total = metric(row, 'total')
		res << m
	}
	return res
}

fn ms(x i64) f64 {
	return f64(x) / 1_000_000.0
}

fn dates_to_error_bar(dates []i64) []i64 {
	mut head := dates.clone()
	mut tail := dates.clone()
	head << tail.reverse()
	return head
}

fn metrics_stddev_to_error_bar(metrics []Metric) []i64 {
	mut head := []i64{}
	mut tail := []i64{}

	for m in metrics {
		mean := m.mean
		head << mean + m.stddev
		tail << mean - m.stddev
	}

	head << tail.reverse()
	return head
}
