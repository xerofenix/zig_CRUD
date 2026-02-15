const std = @import("std");

const pg = @import("pg");
const zap = @import("zap");

const User = struct {
    id: i32,
    name: []const u8,
};

const new_user_req = struct {
    name: []const u8,
};

pub const user_controller = struct {
    pool: *pg.Pool,
    allocator: std.mem.Allocator,
    path: []const u8,
    error_strategy: zap.Endpoint.ErrorStrategy = .log_to_response,

    pub fn init(allocator: std.mem.Allocator, pool: *pg.Pool) user_controller {
        return user_controller{
            .pool = pool,
            .allocator = allocator,
            .path = "/users",
        };
    }

    pub fn endpoint(self: *user_controller) *user_controller {
        return self;
    }

    pub fn get(self: *user_controller, req: zap.Request) !void {
        if (req.path) |path| {
            if (user_id_from_path(path)) |_| {
                try self.get_user(req);
            } else {
                try self.get_users(req);
            }
        } else {
            req.setStatus(.not_found);
            try req.sendBody("");
        }
    }

    pub fn post(self: *user_controller, req: zap.Request) !void {
        try self.save_user(req);
    }

    pub fn delete(self: *user_controller, req: zap.Request) !void {
        try self.delete_user(req);
    }

    //function for getting id from path
    fn user_id_from_path(path: []const u8) ?usize {
        if (path.len >= "/users".len + 2) {
            if (path["/users".len] != '/') {
                return null;
            }
            var idstr = path["/users".len + 1 ..];

            while (idstr.len > 0 and idstr[idstr.len - 1] == '/') {
                idstr = idstr[0 .. idstr.len - 1];
            }
            if (idstr.len == 0) return null;
            return std.fmt.parseUnsigned(usize, idstr, 10) catch null;
        }
        return null;
    }

    //function for getting all users
    pub fn get_users(self: *user_controller, req: zap.Request) !void {
        var result = try self.pool.query("SELECT id, name FROM users", .{});
        defer result.deinit();

        var users = std.ArrayList(User).init(self.allocator);
        defer users.deinit();
        while (try result.next()) |row| {
            const id = row.get(i32, 0);
            const name = row.get([]u8, 1);
            try users.append(User{ .id = id, .name = name });
        }

        var string = std.ArrayList(u8).init(self.allocator);
        defer string.deinit();
        const user_slice = try users.toOwnedSlice();
        defer self.allocator.free(user_slice);

        try std.json.stringify(user_slice, .{}, string.writer());

        try req.sendBody(string.items);
    }

    //function to add user to db
    pub fn save_user(self: *user_controller, req: zap.Request) !void {
        if (req.body) |body| {
            const maybe_user = std.json.parseFromSlice(new_user_req, self.allocator, body, .{}) catch |err| {
                std.debug.print("error parsing json request: {any}\n", .{err});
                req.setStatus(.bad_request);
                try req.sendBody("Error while parsing");
                return;
            };
            defer maybe_user.deinit();

            _ = self.pool.exec("INSERT INTO users (name) values ($1)", .{maybe_user.value.name}) catch {
                req.setStatus(.internal_server_error);
                try req.sendBody("Error while saving");
                return;
            };

            try req.sendBody("User added successfully");
        }
    }

    //function for getting user based on id
    pub fn get_user(self: *user_controller, req: zap.Request) !void {
        if (req.path) |path| {
            if (user_id_from_path(path)) |user_id| {
                const result = try self.pool.row("SELECT id,name FROM users WHERE id = $1", .{user_id});
                if ( result) |r| {
                    const user = User{
                        .id = r.get(i32, 0),
                        .name = r.get([]const u8, 1),
                    };

                    var string = std.ArrayList(u8).init(self.allocator);
                    defer string.deinit();
                    try std.json.stringify(user, .{}, string.writer());
                    try req.sendBody(string.items);
                } else {
                    req.setStatus(.not_found);
                    try req.sendBody("User not found");
                }
                return;
            }
            req.setStatus(.not_found);
        }
    }

    //function for deleting user
    pub fn delete_user(self: *user_controller, req: zap.Request) !void {
        if (req.path) |path| {
            if (user_id_from_path(path)) |user_id| {
                _ = self.pool.exec("DELETE FROM users WHERE id = $1", .{user_id}) catch {
                    req.setStatus(.internal_server_error);
                    return;
                };
                req.setStatus(.ok);
                try req.sendBody("");
            } else {
                req.setStatus(.not_found);
            }
        }
    }

    //function for updating user
    pub fn update_user(self: *user_controller, req: zap.Request) !void {
        if (req.path) |path| {
            if (user_id_from_path(path)) |user_id| {
                const result = try self.pool.row("SELECT id,name FROM users WHERE id = $1", .{user_id});
                if (try result) |r| {
                     // Update logic here
                     _ = r;
                } else {
                    req.setStatus(.not_found);
                    try req.sendBody("User not found");
                }
            }
        }
    }
};
