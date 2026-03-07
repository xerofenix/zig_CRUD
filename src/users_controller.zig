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
            if (user_id_from_path(path) == 0) {
                req.setStatus(.bad_request);
                try req.sendBody("Cannot parse the id from path | invalid user id");
            } else if (user_id_from_path(path) == null) {
                try self.get_users(req);
            } else if (user_id_from_path(path)) |_| {
                try self.get_user(req);
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

            // Attempt to parse the ID
            return std.fmt.parseUnsigned(usize, idstr, 10) catch |err| {
                std.debug.print("Error parsing/getting ID from path {}\n", .{err});
                return 0; // Return null in case of an error
            };
        }
        return null;
    }

    //function for getting all users
    pub fn get_users(self: *user_controller, req: zap.Request) !void {
        var result = try self.pool.query("SELECT id, name FROM users", .{});
        defer result.deinit();

        var users = std.ArrayList(User).empty;
        defer users.deinit(self.allocator);
        while (try result.next()) |row| {
            const id = row.get(i32, 0);
            const name = row.get([]u8, 1);
            try users.append(self.allocator, User{ .id = id, .name = name });
        }

        const user_slice = try users.toOwnedSlice(self.allocator);
        defer self.allocator.free(user_slice);

        const json_str = try std.json.Stringify.valueAlloc(self.allocator, user_slice, .{});
        defer self.allocator.free(json_str);
        try req.sendBody(json_str);
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
                if (result) |r| {
                    const user = User{
                        .id = r.get(i32, 0),
                        .name = r.get([]const u8, 1),
                    };

                    const json_str = try std.json.Stringify.valueAlloc(self.allocator, user, .{});
                    defer self.allocator.free(json_str);
                    try req.sendBody(json_str);
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
            if (try user_id_from_path(path)) |user_id| {
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
