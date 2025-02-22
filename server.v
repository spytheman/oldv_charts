module main

import os
import net.http { Request, Response, Server }

const max_points = 60_000

const db_file = os.getenv_opt('FAST_DB') or { 'data.sqlite' }

struct ILink {
	cmd       string
	db_column string
}

const index_links = {
	'/v_hello.html':                ILink{'v examples/hello_world.v', 'v_hello_default_id'}
	'/v_hello_skip_unused.html':    ILink{'v -skip-unused examples/hello_world.v', 'v_hello_skip_unused_id'}
	'/v_hello_no_skip_unused.html': ILink{'v -no-skip-unused examples/hello_world.v', 'v_hello_no_skip_unused_id'}
	'/v_self.html':                 ILink{'v self', 'v_self_default_id'}
	'/v_self_skip_unused.html':     ILink{'v -skip-unused self', 'v_self_skip_unused_id'}
	'/v_self_no_skip_unused.html':  ILink{'v -no-skip-unused self', 'v_self_no_skip_unused_id'}
}

pub struct App {
	dynamic bool
mut:
	pages       map[string]string
	index_links map[string]ILink
}

fn get_stats(title string, kind string, ndays int) string {
	measurements := get_measurements(max_points, kind, ndays)
	res := $tmpl('templates/stats.html')
	return res
}

fn (app &App) get_index() string {
	title := 'All stats'
	links := app.index_links.clone()
	return $tmpl('templates/index.html')
}

fn (app &App) router(path string) ?string {
	println('rendering ${path}')
	match path {
		'/', '/index.html' {
			return app.get_index()
		}
		'/data.sqlite' {
			return os.read_file(db_file) or { return none }
		}
		'/favicon.ico' {
			return os.read_file('favicon.ico') or { return none }
		}
		else {
			if ilink := app.index_links[path] {
				ndays := path.all_before('.html').all_after_last('.').int()
				return get_stats(ilink.cmd, ilink.db_column, ndays)
			}
			return none
		}
	}
}

fn (mut app App) add_set(ndays int, keys []string) []string {
	mut pages := []string{}
	app.index_links['<h2>Last ${ndays} days:</h2>'] = ILink{}
	for k in keys {
		pk := k.replace('.html', '.${ndays}.html')
		pages << pk
		app.index_links[pk] = index_links[k]
	}
	return pages
}

fn (mut app App) build_index_links() []string {
	mut pages := []string{}
	keys := index_links.keys()
	pages << app.add_set(7, keys)
	pages << app.add_set(30, keys)
	pages << app.add_set(120, keys)
	pages << app.add_set(365, keys)
	app.index_links['<h2>No limit:</h2>'] = ILink{}
	pages << keys
	for k, v in index_links {
		app.index_links[k] = v
	}
	return pages
}

fn (mut app App) generate() ! {
	mut pages := ['/', '/index.html', '/data.sqlite', '/favicon.ico']
	pages << app.build_index_links()
	if app.dynamic {
		return
	}
	for url_prefix in pages {
		app.pages['output${url_prefix}'] = app.router(url_prefix) or {
			panic('failed to pre-render `${url_prefix}`, error: ${err}')
		}
	}
}

fn (mut app App) save() ! {
	os.mkdir('output/') or {}
	for k, v in app.pages {
		if k == 'output/' {
			continue
		}
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
