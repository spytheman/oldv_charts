module main

import os
import net.http { Request, Response, Server }

const max_points = 20_000

const db_file = os.getenv_opt('FAST_DB') or { 'data.sqlite' }

fn get_stats(title string, kind string) string {
	measurements := get_measurements(max_points, kind)
	res := $tmpl('stats.html')
	return res
}

fn get_index() string {
	title := 'All stats'
	return $tmpl('index.html')
}

pub struct App {
	dynamic bool
mut:
	pages map[string]string
}

fn (app App) router(path string) ?string {
	println('rendering ${path}')
	match path {
		'/', '/index.html' {
			return get_index()
		}
		'/v_self.html' {
			return get_stats('v self', 'v_self_default_id')
		}
		'/v_hello.html' {
			return get_stats('v examples/hello_world.v', 'v_hello_default_id')
		}
		'/data.sqlite' {
			return os.read_file(db_file) or { return none }
		}
		'/favicon.ico' {
			return os.read_file('favicon.ico') or { return none }
		}
		else {
			return none
		}
	}
}

fn (mut app App) generate() ! {
	if app.dynamic {
		return
	}
	for prerender in ['/index.html', '/v_self.html', '/v_hello.html', '/data.sqlite', '/favicon.ico'] {
		app.pages['output${prerender}'] = app.router(prerender) or {
			panic('failed to pre-render: ${prerender}: ${err}')
		}
	}
}

fn (mut app App) save() ! {
	os.mkdir('output/') or {}
	for k, v in app.pages {
		os.write_file(k, v)!
	}
}

fn (mut app App) handle(req Request) Response {
	mut res := Response{
		header: http.new_header_from_map({
			.content_type: 'application/octet-stream'
		})
	}
	dump(req.url)
	if req.url.ends_with('.html') || req.url == '/' {
		res.header = http.new_header_from_map({
			.content_type: 'text/html'
		})
	}
	if req.url.ends_with('.ico') {
		res.header = http.new_header_from_map({
			.content_type: 'image/vnd.microsoft.icon'
		})
	}
	if app.dynamic {
		if content := app.router(req.url) {
			res.status_code = 200
			res.body = content
			return res
		}
	} else if content := app.pages['output${req.url}'] {
		res.status_code = 200
		res.body = content
		return res
	}
	res.status_code = 404
	res.body = 'Not found\n'
	return res
}

fn (mut app App) serve() ! {
	mut server := Server{
		handler: app
	}
	server.listen_and_serve()
}
