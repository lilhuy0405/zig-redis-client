const std = @import("std");
const RedisClient = @import("redis-client.zig").RedisClient;

// Example callback functions
fn printResponse(response: []const u8) !void {
    std.debug.print("Response: {s}\n", .{response});
}

const BenchmarkContext = struct {
    completed: usize = 0,
    start_time: i128 = 0,
    end_time: i128 = 0,
};

fn countCallback(response: []const u8) !void {
    _ = response; // Ignore the response in benchmark
}

pub fn main() !void {
    // Initialize
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create Redis client with a pool of 5 connections
    var client = try RedisClient.init(allocator, "localhost", 6379, 5);
    defer client.deinit();

    // Select database
    try client.setDb(1);

    // First set a key for testing
    try client.set("test_key", "test_value", countCallback);

    // Benchmark configuration
    const num_operations = 1_000_000;
    std.debug.print("\nStarting benchmark with {d} GET operations...\n", .{num_operations});

    // Start timing
    const start = std.time.nanoTimestamp();

    // Send GET commands
    var i: usize = 0;
    while (i < num_operations) : (i += 1) {
        try client.get("test_key", countCallback);
    }

    // Wait for a moment to ensure all operations complete
    std.time.sleep(100 * std.time.ns_per_ms);

    // End timing
    const end = std.time.nanoTimestamp();
    const duration_ns = end - start;
    const duration_s = @as(f64, @floatFromInt(duration_ns)) / @as(f64, @floatFromInt(std.time.ns_per_s));
    const ops_per_second = @as(f64, @floatFromInt(num_operations)) / duration_s;

    // Print results
    std.debug.print("\nBenchmark Results:\n", .{});
    std.debug.print("Total operations: {d}\n", .{num_operations});
    std.debug.print("Total time: {d:.2} seconds\n", .{duration_s});
    std.debug.print("Operations per second: {d:.2} ops/sec\n", .{ops_per_second});
    std.debug.print("Average latency: {d:.2} ms\n", .{(duration_s * 1000) / @as(f64, @floatFromInt(num_operations))});
}