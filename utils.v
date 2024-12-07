module main

import db.sqlite

struct Metric {
	mean   i64
	stddev i64
}

struct Measurement {
mut:
	commit       string
	date         i64
	tested       i64
	csize        int
	vlines       Metric
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
		mean:   row['${name}_mean'].i64()
		stddev: row['${name}_stddev'].i64()
	}
}

fn metric_us(row map[string]string, name string) Metric {
	return Metric{
		mean:   row['${name}_mean'].i64() / 1_000
		stddev: row['${name}_stddev'].i64() / 1_000
	}
}

fn metric_ms(row map[string]string, name string) Metric {
	return Metric{
		mean:   row['${name}_mean'].i64() / 1_000_000
		stddev: row['${name}_stddev'].i64() / 1_000_000
	}
}

fn get_measurements(max_n int, kind string) []Measurement {
	mut res := []Measurement{}
	mut db := sqlite.connect('data.sqlite') or { panic(err) }
	rows := exec_map(mut db, 'SELECT
                                 `commit`, state, ${kind}, date, tested,
                                 csize_mean,
                                 vlines_mean, vlines_stddev,
                                 scan_mean, scan_stddev,
                                 parse_mean, parse_stddev,
                                 check_mean, check_stddev,
                                 cgen_mean, cgen_stddev,
                                 total_stages_mean, total_stages_stddev,
                                 total_mean, total_stddev
                              FROM commits
                              LEFT JOIN `measurements` ON commits.${kind} = measurements.id
                              WHERE commits.state = 1
                              ORDER BY date desc
                              LIMIT 0,${max_n}
                              ')
	for row in rows {
		mut m := Measurement{}
		m.commit = row['commit']
		m.date = row['date'].i64() * 1000 // ts in ms
		m.tested = row['tested'].i64() * 1000 // ts in ms
		m.csize = row['csize_mean'].int()
		m.vlines = metric(row, 'vlines')
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
