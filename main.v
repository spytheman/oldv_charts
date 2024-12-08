module main

fn main() {
	is_dynamic := arguments().contains('-dynamic')
	mut app := App{
		dynamic: is_dynamic
	}
	app.generate()!
	app.save()!
	app.serve()!
}
