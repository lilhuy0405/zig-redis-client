const std = @import("std");
const net = std.net;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;

pub const RedisError = error{
    ConnectionFailed,
    InvalidResponse,
    CommandFailed,
    PoolExhausted,
};

const Connection = struct {
    stream: net.Stream,
    db: i32,
    in_use: bool,

    pub fn init(stream: net.Stream) Connection {
        return .{
            .stream = stream,
            .db = 0,
            .in_use = false,
        };
    }

    pub fn deinit(self: *Connection) void {
        self.stream.close();
    }
};

const Command = struct {
    command: []const u8,
    callback: *const fn ([]const u8) anyerror!void,
};

pub const RedisClient = struct {
    allocator: Allocator,
    pool: ArrayList(Connection),
    command_queue: ArrayList(Command),
    host: []const u8,
    port: u16,
    current_db: i32,

    pub fn init(allocator: Allocator, host: []const u8, port: u16, pool_size: usize) !*RedisClient {
        var client = try allocator.create(RedisClient);
        client.* = .{
            .allocator = allocator,
            .pool = ArrayList(Connection).init(allocator),
            .command_queue = ArrayList(Command).init(allocator),
            .host = try allocator.dupe(u8, host),
            .port = port,
            .current_db = 0,
        };

        // Initialize connection pool
        var i: usize = 0;
        while (i < pool_size) : (i += 1) {
            const stream = try net.tcpConnectToHost(allocator, host, port);
            try client.pool.append(Connection.init(stream));
        }

        return client;
    }

    pub fn deinit(self: *RedisClient) void {
        for (self.pool.items) |*conn| {
            conn.deinit();
        }
        self.pool.deinit();
        self.command_queue.deinit();
        self.allocator.free(self.host);
        self.allocator.destroy(self);
    }

    fn getConnection(self: *RedisClient) !*Connection {
        for (self.pool.items) |*conn| {
            if (!conn.in_use) {
                conn.in_use = true;
                return conn;
            }
        }
        return RedisError.PoolExhausted;
    }

    fn releaseConnection(self: *RedisClient, conn: *Connection) void {
        _ = self; // Explicitly ignore self
        conn.in_use = false;
    }

    fn sendCommand(conn: *Connection, command: []const u8) !void {
        _ = try conn.stream.write(command);
    }

    fn readResponse(conn: *Connection, allocator: Allocator) ![]const u8 {
        var buffer = try allocator.alloc(u8, 1024);
        defer allocator.free(buffer);

        const bytes_read = try conn.stream.read(buffer);
        if (bytes_read == 0) return RedisError.InvalidResponse;

        // Simple response parsing - in real implementation you'd want more robust RESP protocol parsing
        if (buffer[0] == '-') return RedisError.CommandFailed;

        const response = try allocator.dupe(u8, buffer[1 .. bytes_read - 2]); // Remove RESP formatting
        return response;
    }

    pub fn setDb(self: *RedisClient, db: i32) !void {
        if (db == self.current_db) return;

        const cmd = try std.fmt.allocPrint(self.allocator, "SELECT {d}\r\n", .{db});
        defer self.allocator.free(cmd);

        const conn = try self.getConnection();
        defer self.releaseConnection(conn);

        try sendCommand(conn, cmd);
        const response = try readResponse(conn, self.allocator);
        defer self.allocator.free(response);

        if (std.mem.eql(u8, response, "OK")) {
            self.current_db = db;
        } else {
            return RedisError.CommandFailed;
        }
    }

    pub fn get(self: *RedisClient, key: []const u8, callback: *const fn ([]const u8) anyerror!void) !void {
        const cmd = try std.fmt.allocPrint(self.allocator, "GET {s}\r\n", .{key});
        try self.command_queue.append(.{ .command = cmd, .callback = callback });
        try self.processQueue();
    }

    pub fn set(self: *RedisClient, key: []const u8, value: []const u8, callback: *const fn ([]const u8) anyerror!void) !void {
        const cmd = try std.fmt.allocPrint(self.allocator, "SET {s} {s}\r\n", .{ key, value });
        try self.command_queue.append(.{ .command = cmd, .callback = callback });
        try self.processQueue();
    }

    pub fn incr(self: *RedisClient, key: []const u8, callback: *const fn ([]const u8) anyerror!void) !void {
        const cmd = try std.fmt.allocPrint(self.allocator, "INCR {s}\r\n", .{key});
        try self.command_queue.append(.{ .command = cmd, .callback = callback });
        try self.processQueue();
    }

    fn processQueue(self: *RedisClient) !void {
        if (self.command_queue.items.len == 0) return;

        const conn = try self.getConnection();
        defer self.releaseConnection(conn);

        // Send all commands in queue
        for (self.command_queue.items) |cmd| {
            try sendCommand(conn, cmd.command);
        }

        // Read all responses and trigger callbacks
        for (self.command_queue.items) |cmd| {
            const response = try readResponse(conn, self.allocator);
            defer self.allocator.free(response);
            try cmd.callback(response);
            self.allocator.free(cmd.command);
        }

        self.command_queue.clearRetainingCapacity();
    }
};

