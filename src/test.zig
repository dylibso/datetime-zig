const std = @import("std");
const DateTime = @import("lib.zig").DateTime;

const SAMPLE_MS = 1723428925483;

const UpdatedAtName = struct {
    updatedAt: DateTime,
    name: []const u8,
};
const GoLikeInput = "{\"updatedAt\": \"2009-11-10T23:00:00Z\", \"name\": \"Steve\"}";
const GoLikeExpected = UpdatedAtName{
    .updatedAt = DateTime{
        .year = 2009,
        .month = 11,
        .day = 10,
        .hour = 23,
        .minute = 0,
        .second = 0,
        .millisecond = 0,
        .offset = 0,
    },
    .name = "Steve",
};

test "can use Zig std timestamp millis" {
    const ts = std.time.milliTimestamp();
    const d = DateTime.fromMillis(ts);

    try std.testing.expectEqual(@rem(ts, 1000), d.millisecond);
}

test "datetime equality against known input" {
    const dt = DateTime.fromMillis(SAMPLE_MS);
    const actual = try dt.toRfc3339(std.testing.allocator);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings("2024-08-12T02:15:25.483Z", actual);
}

test "serializes to JSON in new struct" {
    const WithTime = struct {
        name: []const u8,
        value: f64,
        date: DateTime,
    };

    const wt = WithTime{
        .name = "Steve",
        .value = std.math.pi,
        .date = DateTime.fromMillis(SAMPLE_MS),
    };

    const actual = try std.json.stringifyAlloc(std.testing.allocator, wt, .{});
    defer std.testing.allocator.free(actual);
    const expected = "{\"name\":\"Steve\",\"value\":3.141592653589793e0,\"date\":\"2024-08-12T02:15:25.483Z\"}";
    try std.testing.expectEqualStrings(expected, actual);
}

test "deserializes from JSON into DateTime" {
    const actual = try std.json.parseFromSlice(UpdatedAtName, std.testing.allocator, GoLikeInput, .{ .allocate = .alloc_always });
    defer actual.deinit();

    try std.testing.expectEqual(GoLikeExpected.updatedAt, actual.value.updatedAt);
}

test "preserve roundtrip JSON conversion" {
    const from_json = try std.json.parseFromSlice(UpdatedAtName, std.testing.allocator, GoLikeInput, .{ .allocate = .alloc_always });
    defer from_json.deinit();
    const from = from_json.value;

    const to = try std.json.stringifyAlloc(std.testing.allocator, from, .{});
    defer std.testing.allocator.free(to);

    const from_converted = try std.json.parseFromSlice(UpdatedAtName, std.testing.allocator, to, .{ .allocate = .alloc_always });
    defer from_converted.deinit();

    const expected = GoLikeExpected.updatedAt;
    const actual = from_converted.value.updatedAt;

    try std.testing.expectEqual(expected.year, actual.year);
    try std.testing.expectEqual(expected.month, actual.month);
    try std.testing.expectEqual(expected.day, actual.day);
    try std.testing.expectEqual(expected.hour, actual.hour);
    try std.testing.expectEqual(expected.minute, actual.minute);
    try std.testing.expectEqual(expected.second, actual.second);
    try std.testing.expectEqual(expected.millisecond, actual.millisecond);
    try std.testing.expectEqual(expected.offset, actual.offset);
}
