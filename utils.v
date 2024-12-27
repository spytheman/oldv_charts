module main

import math
import time
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
	vsize        int
	clines       int
	vlines       int
	vtypes       int
	vmodules     int
	vfiles       int
	vlines_ps    Metric
	scan         Metric
	parse        Metric
	check        Metric
	transform    Metric
	markused     Metric
	cgen         Metric
	total_stages Metric
	total        Metric
}

fn exec_map(mut db sqlite.DB, query string) []map[string]string {
	rows := db.exec(query) or { panic(err) }
	defer {
		unsafe { rows.free() }
	}
	mut res := []map[string]string{cap: rows.len}
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
	kmin := '${name}_min'
	kmax := '${name}_max'
	kmean := '${name}_mean'
	kstddev := '${name}_stddev'
	res := Metric{
		min:    row[kmin].i64()
		max:    row[kmax].i64()
		mean:   row[kmean].i64()
		stddev: row[kstddev].i64()
	}
	unsafe {
		kstddev.free()
		kmean.free()
		kmax.free()
		kmin.free()
	}
	return res
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

fn get_measurements(max_n int, kind string, ndays int) []Measurement {
	cutoff_ts := if ndays <= 0 { 0 } else { time.utc().add(-ndays * 24 * time.hour).unix() }
	mut res := []Measurement{}
	mut db := sqlite.connect(db_file) or { panic(err) }
	defer {
		db.close() or {}
	}
	rows := exec_map(mut db, 'SELECT
                                 commit_hash, state, ${kind}, date, tested,
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
                              LEFT JOIN `measurements` ON commits.${kind} = measurements.id
                              WHERE commits.state = 1 AND commits.${kind} IS NOT NULL AND commits.date > ${cutoff_ts}
                              ORDER BY date desc
                              LIMIT 0,${max_n}
                              ')
	for row in rows {
		mut m := Measurement{}
		m.commit = row['commit_hash']
		m.date = row['date'].i64() * 1000 // ts in ms
		m.tested = row['tested'].i64() * 1000 // ts in ms
		m.csize = row['csize_mean'].int()
		m.clines = row['clines_mean'].int()
		m.vsize = row['vsize_mean'].int()
		m.vlines = row['vlines_mean'].int()
		m.vlines_ps = metric(row, 'vlines_ps')
		m.vtypes = row['vtypes_mean'].int()
		m.vmodules = row['vmodules_mean'].int()
		m.vfiles = row['vfiles_mean'].int()
		m.scan = metric(row, 'scan')
		m.parse = metric(row, 'parse')
		m.check = metric(row, 'check')
		m.transform = metric(row, 'transform')
		m.markused = metric(row, 'markused')
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

fn misc_stddev2(s1 i64, s2 i64) i64 {
	// The equation below is totally made up, since we do not have the complete data,
	// but since total and total_stages seem to be very close, and proportional to each other,
	// their diff is ~10 smaller than each:
	// covariance_fudge_factor = 0.05
	// covariance := covariance_fudge_factor * f64(s1*s1 + s2*s2)
	return math.sqrti(s1 * s1 + s2 * s2) // + i64(2*covariance))
}
