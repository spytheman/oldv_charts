module main

import os
import net.http { Request, Response, Server }

const max_points = 20_000

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
	println('rendering $path')
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
		else {
			return none
		}
	}
}

fn (mut app App) generate() ! {
	for prerender in ['/index.html', '/v_self.html', '/v_hello.html'] {
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

fn (app App) handle(req Request) Response {
	mut res := Response{
		header: http.new_header_from_map({
			.content_type: 'text/html'
		})
	}
	dump(req.url)
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

fn main() {
	is_dynamic := arguments().contains('-dynamic')
	mut app := App{dynamic: is_dynamic}
	app.generate()!
	app.save()!
	mut server := Server{
		handler: app
	}
	server.listen_and_serve()
}
