module main

struct Metric {
	min    i64
	max    i64
	mean   i64
	stddev i64
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
