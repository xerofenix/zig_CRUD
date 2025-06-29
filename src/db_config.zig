const std = @import("std");

const pg = @import("pg");
const zap = @import("zap");

pub fn db_connect() !*pg.Pool {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};

    const allocator = gpa.allocator();
    const pool = try pg.Pool.init(allocator, .{ .size = 5, .connect = .{
        .port = 5432,
        .host = "127.0.0.1",
    }, .auth = .{
        .username = "postgres",
        .database = "zap_crud",
        .password = "postgres",
        .timeout = 10_000,
    } });
    // defer pool.deinit();

    return pool;
}
