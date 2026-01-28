module main

import time
import db.sqlite

struct Measurement {
mut:
	commit       string
	title        string
	date         i64
	tested       i64
	csize        int
	vsize        int
	clines       int
	vlines       int
	vtypes       int
	vmodules     int
	vfiles       int
	tl_stmts     int
	tl_nvlib     int
	tl_main      int
	vlines_ps    Metric
	scan         Metric
	parse        Metric
	check        Metric
	comptime     Metric
	transform    Metric
	markused     Metric
	cgen         Metric
	total_stages Metric
	total        Metric
}

fn get_measurements(max_n int, kind string, ndays int) []Measurement {
	cutoff_ts := if ndays <= 0 { 0 } else { time.utc().add(-ndays * 24 * time.hour).unix() }
	mut res := []Measurement{}
	mut db := sqlite.connect(db_file) or { panic(err) }
	defer {
		db.close() or {}
	}
	rows := exec_map(mut db, 'SELECT
                                 commit_hash, commit_title, state, ${kind}, date, tested,
                                 csize_mean, clines_mean,
                                 vsize_mean, vlines_mean, vtypes_mean, vmodules_mean, vfiles_mean,
                                 tl_stmts_mean, non_vlib_tl_stmts_mean, main_tl_stmts_mean, 
                                 vlines_ps_min, vlines_ps_max, vlines_ps_mean, vlines_ps_stddev,
                                 scan_min, scan_max, scan_mean, scan_stddev,
                                 parse_min, parse_max, parse_mean, parse_stddev,
                                 check_min, check_max, check_mean, check_stddev,
                                 comptime_min, comptime_max, comptime_mean, comptime_stddev,
                                 transform_min, transform_max, transform_mean, transform_stddev,
                                 markused_min, markused_max, markused_mean, markused_stddev,
                                 cgen_min, cgen_max, cgen_mean, cgen_stddev,
                                 total_stages_min, total_stages_max, total_stages_mean, total_stages_stddev,
                                 total_min, total_max, total_mean, total_stddev
                              FROM commits
                              LEFT JOIN `measurements` ON commits.${kind} = measurements.id
                              WHERE commits.state IN (1, 7) AND commits.${kind} IS NOT NULL AND commits.date > ${cutoff_ts}
                              ORDER BY date desc
                              LIMIT 0,${max_n}
                              ')
	for row in rows {
		commit := row['commit_hash']
		mut m := Measurement{}
		m.title = clean_title(row['commit_title'])
		m.commit = '<a href="https://github.com/vlang/v/commit/${commit}">${commit}<br>${m.title}</a>'
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
		m.tl_stmts = row['tl_stmts_mean'].int()
		m.tl_nvlib = row['non_vlib_tl_stmts_mean'].int()
		m.tl_main = row['main_tl_stmts_mean'].int()
		m.scan = metric(row, 'scan')
		m.parse = metric(row, 'parse')
		m.check = metric(row, 'check')
		m.comptime = metric(row, 'comptime')
		m.transform = metric(row, 'transform')
		m.markused = metric(row, 'markused')
		m.cgen = metric(row, 'cgen')
		m.total_stages = metric(row, 'total_stages')
		m.total = metric(row, 'total')
		res << m
	}
	return res
}

fn clean_title(s string) string {
	res := s.clone()
	for i := 0; i < s.len; i++ {
		c := s[i]
		if (c >= `A` && c <= `Z`) || (c >= `a` && c <= `z`) || (c >= `0` && c <= `9`)
			|| c in [` `, `_`, `=`, `-`, `+`, `*`, `/`, `:`, `,`, `.`, `{`, `}`, `[`, `]`, `(`, `)`, `\``] {
			continue
		}
		unsafe {
			res.str[i] = ` `
		}
	}
	return res
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
