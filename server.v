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
mut:
	pages map[string]string
}

fn (mut app App) generate() ! {
	app.pages = {
		'output/index.html':   get_index()
		'output/v_self.html':  get_stats('v self', 'v_self_default_id')
		'output/v_hello.html': get_stats('v examples/hello_world.v', 'v_hello_default_id')
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
	if content := app.pages['output${req.url}'] {
		res.status_code = 200
		res.body = content
	} else {
		res.status_code = 404
		res.body = 'Not found\n'
	}
	return res
}

fn main() {
	mut app := App{}
	app.generate()!
	app.save()!
	mut server := Server{
		handler: app
	}
	server.listen_and_serve()
}
