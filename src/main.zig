const std = @import("std");

const pg = @import("pg");
const zap = @import("zap");

const db = @import("./db_config.zig");
const users_controller = @import("./users_controller.zig");

fn not_found(req: zap.Request) anyerror!void {
    req.setStatusNumeric(400);
    req.sendBody("<html><body><h1>Hello from ZAP!!!</h1><div><h2>Error 404 Not found</h2></div></body></html>") catch return;
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    const allocator = arena.allocator();
    const io = init.io;
    var pool = try db.db_connect(io, allocator);
    defer pool.deinit();

    _ = try pool.exec("CREATE TABLE IF NOT EXISTS users (id serial primary key, name text)", .{});

    // Modern Zap: Router initialization options changed
    var simple_router = zap.Router.init(allocator, .{
        .not_found = not_found,
    });

    var user_controller = users_controller.user_controller.init(allocator, pool);

    var listener = zap.Endpoint.Listener.init(allocator, .{
        .port = 3000,
        .on_request = simple_router.on_request_handler(),
        .public_folder = "public",
        .log = true,
    });
    defer listener.deinit();

    try listener.register(user_controller.endpoint());

    try listener.listen();
    std.debug.print("Listening on http://127.0.0.1:3000\n", .{});

    zap.start(.{
        .threads = 1,
        .workers = 1,
    });
}
