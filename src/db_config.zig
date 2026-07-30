const std = @import("std");
const pg = @import("pg");
const zap = @import("zap");
const envo = @import("envo");

pub fn db_connect(io: std.Io, allocator: std.mem.Allocator) !*pg.Pool {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator_local = gpa.allocator();
    // defer _ = gpa.deinit();
    // Load the .env file contents:
    const env_contents = try envo.loadFile(io, allocator, "./.env");

    const env_data = try envo.parse(allocator, .RECURSIVE_DESCENT, env_contents); // Call .allocator()

    const username = env_data.get("USERNAME") orelse "";
    const password = env_data.get("PASSWORD") orelse "";
    const database = env_data.get("DATABASE") orelse "zap_crud";
    const host = env_data.get("HOST") orelse "";
    const port = env_data.get("PORT") orelse "5432";
    const port_num = try std.fmt.parseInt(u16, port, 10);

    const pool = try pg.Pool.init(io,allocator, .{ .size = 5, .connect = .{
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
