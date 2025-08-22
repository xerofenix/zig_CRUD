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
    ep: zap.Endpoint = undefined,

    pub fn init(allocator: std.mem.Allocator, pool: *pg.Pool) user_controller {
        return user_controller{
            .pool = pool,
            .allocator = allocator,
            .ep = zap.Endpoint.init(.{
                .path = "/users",
                .get = user_controller.dispatch,
                .post = user_controller.save_user,
                .delete = user_controller.delete_user,
            }),
        };
    }

    pub fn endpoint(self: *user_controller) *zap.Endpoint {
        return &self.ep;
    }

    pub fn dispatch(e: *zap.Endpoint, req: zap.Request) void {
        if (req.path) |path| {
            if (user_controller.user_id_from_path(path)) |_| {
                user_controller.get_user(e, req) catch req.setStatus(.internal_server_error);
            } else {
                user_controller.get_users(e, req) catch req.setStatus(.internal_server_error);
            }
        } else {
            req.setStatus(.not_found);
            req.sendBody("") catch return;
        }
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
    pub fn get_users(e: *zap.Endpoint, req: zap.Request) !void {
        const self: *user_controller = @fieldParentPtr("ep", e);

        if (req.path) |_| {
            var result = try self.pool.query("SELECT id, name FROM users", .{});
            defer result.deinit();

            var users = std.ArrayList(User).init(self.allocator);
            while (try result.next()) |row| {
                const id = row.get(i32, 0);
                const name = row.get([]u8, 1);
                try users.append(User{ .id = id, .name = name });
            }

            var string = std.ArrayList(u8).init(self.allocator);
            const user_slice = try users.toOwnedSlice();
            defer self.allocator.free(user_slice);

            try std.json.stringify(user_slice, .{}, string.writer());

            const s = try string.toOwnedSlice();
            defer self.allocator.free(s);

            req.sendBody(s) catch return;
        }
    }

    //function to add user to db
    pub fn save_user(e: *zap.Endpoint, req: zap.Request) void {
        const self: *user_controller = @fieldParentPtr("ep", e);

        if (req.body) |body| {
            const maybe_user: ?std.json.Parsed(new_user_req) = std.json.parseFromSlice(new_user_req, self.allocator, body, .{}) catch |err| {
                std.debug.print("error parsing json request: {any}\n", .{err});
                req.setStatus(.bad_request);
                req.sendBody("Error while parsing") catch {
                    std.debug.print("error while sending parsing error", .{});
                };
                return;
            };

            if (maybe_user) |user| {
                defer user.deinit();
                _ = self.pool.exec("INSERT INTO users (name) values ($1)", .{user.value.name}) catch {
                    req.setStatus(.internal_server_error);
                    req.sendBody("Error while saving") catch {
                        std.debug.print("error while sending error", .{});
                    };
                    return;
                };

                req.sendBody("User added successfully") catch {
                    std.debug.print("error while sending adding user msg", .{});
                };
            }
        }
    }

    //function for getting user based on id
    pub fn get_user(e: *zap.Endpoint, req: zap.Request) !void {
        const self: *user_controller = @fieldParentPtr("ep", e);

        if (req.path) |path| {
            if (user_controller.user_id_from_path(path)) |user_id| {
                const result = try self.pool.row("SELECT id,name FROM users WHERE id = $1", .{user_id});
                if (result) |r| {
                    const user = User{
                        .id = r.get(i32, 0),
                        .name = r.get([]const u8, 1),
                    };

                    var string = std.ArrayList(u8).init(self.allocator);
                    try std.json.stringify(user, .{}, string.writer());
                    const s = try string.toOwnedSlice();
                    defer self.allocator.free(s);
                    req.sendBody(s) catch return;
                } else {
                    req.setStatus(.not_found);
                    req.sendBody("User not found") catch
                        return;
                }
                return;
            }
            req.setStatus(.not_found);
        }
    }

    pub fn delete_user(e: *zap.Endpoint, req: zap.Request) void {
        const self: *user_controller = @fieldParentPtr("ep", e);

        if (req.path) |path| {
            if (user_controller.user_id_from_path(path)) |user_id| {
                _ = self.pool.exec("DELETE FROM users WHERE id = $1", .{user_id}) catch {
                    req.setStatus(.internal_server_error);
                    return;
                };
                req.setStatus(.ok);
            } else {
                req.setStatus(.not_found);
            }
        }
    }
};
