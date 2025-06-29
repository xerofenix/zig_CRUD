const std = @import("std");
const pg = @import("pg");
const zap = @import("zap");

pub fn db_connect(allocator: *std.mem.Allocator) !*pg.Pool {
    const pool = try pg.Pool.init(allocator.*, .{ .size = 5, .connect = .{
        .port = 5432,
        .host = "127.0.0.1",
    }, .auth = .{
        .username = "postgres",
        .database = "zap_crud",
        .password = "postgres",
        .timeout = 10_000,
    } });

    return pool; // Return the pointer to the allocated pool
}
