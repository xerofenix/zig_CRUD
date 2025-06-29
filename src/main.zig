const std = @import("std");

const pg = @import("pg");
const zap = @import("zap");

// const db = @import("./db_config.zig");
const users_controller = @import("./users_controller.zig");

fn not_found(req: zap.Request) void {
    req.setStatusNumeric(200);
    req.sendBody("<html><body><h1>Hello from ZAP!!!</h1></body></html>") catch return;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    const allocator = gpa.allocator();

    var pool = try pg.Pool.init(allocator, .{ .size = 5, .connect = .{
        .port = 5432,
        .host = "127.0.0.1",
    }, .auth = .{
        .username = "postgres",
        .database = "zap_crud",
        .password = "postgres",
        .timeout = 10_000,
    } });

    // var pool = try db.db_connect();
    defer pool.deinit();

    _ = try pool.exec("CREATE TABLE IF NOT EXISTS users (id serial primary key, name text)", .{});

    var simple_router = zap.Router.init(allocator, .{
        .not_found = not_found,
    });
    defer simple_router.deinit();

    var user_controller = users_controller.user_controller.init(allocator, pool);

    var listener = zap.Endpoint.Listener.init(allocator, .{
        .port = 3000,
        .on_request = simple_router.on_request_handler(),
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
