module main

import math

fn ms(x i64) f64 {
	return f64(x) / 1_000_000.0
}

fn dates_to_error_bar(dates []i64) []i64 {
	mut head := dates.clone()
	mut tail := dates.clone()
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
