const std = @import("std");
const pg = @import("pg");
const zap = @import("zap");
const dotenv = @import("dotenv");

pub fn db_connect(allocator: std.mem.Allocator) !*pg.Pool {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator_local = gpa.allocator();
    // defer _ = gpa.deinit();

    // Load environment variables from .env file
    var env = try dotenv.init(allocator, ".env");
    defer env.deinit();

    const username = env.get("USERNAME") orelse "postgres";
    const password = env.get("PASSWORD") orelse "";
    const database = env.get("DATABASE") orelse "zap_crud";
    const host = env.get("HOST") orelse "localhost";
    const port = env.get("PORT") orelse "5432";
    const port_num = try std.fmt.parseInt(u16, port, 10);

    const pool = try pg.Pool.init(allocator, .{ .size = 5, .connect = .{
        .port = port_num,
        .host = host,
    }, .auth = .{
        .username = username,
        .database = database,
        .password = password,
        .timeout = 10_000,
    } });

    std.debug.print("Connected to database: {s} at {s}:{d}\n", .{ database, host, port_num });

    return pool; // Return the pointer to the allocated pool
}
