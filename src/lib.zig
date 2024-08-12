const std = @import("std");

/// Represents a date and time with timezone offset
pub const DateTime = struct {
    /// Calendar year (e.g., 2023)
    year: u16,
    /// Month of the year (1-12)
    month: u8,
    /// Day of the month (1-31)
    day: u8,
    /// Hour of the day (0-23)
    hour: u8,
    /// Minute of the hour (0-59)
    minute: u8,
    /// Second of the minute (0-60, allowing for leap seconds)
    second: u8,
    /// Milliseconds (0-999)
    millisecond: u16,
    /// Timezone offset in minutes from UTC
    offset: i16,

    /// Parses a DateTime from a JSON string in RFC 3339 format
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!DateTime {
        _ = allocator;
        _ = options;

        const token = try source.next();
        if (token != .string) return error.UnexpectedToken;

        const datetime_str = token.string;
        if (datetime_str.len < 20) return error.InvalidCharacter;

        var result = DateTime{
            .year = 0,
            .month = 0,
            .day = 0,
            .hour = 0,
            .minute = 0,
            .second = 0,
            .millisecond = 0,
            .offset = 0,
        };

        // Parse date
        result.year = std.fmt.parseInt(u16, datetime_str[0..4], 10) catch return error.InvalidNumber;
        if (datetime_str[4] != '-') return error.InvalidCharacter;
        result.month = std.fmt.parseInt(u8, datetime_str[5..7], 10) catch return error.InvalidNumber;
        if (result.month < 1 or result.month > 12) return error.InvalidNumber;
        if (datetime_str[7] != '-') return error.InvalidCharacter;
        result.day = std.fmt.parseInt(u8, datetime_str[8..10], 10) catch return error.InvalidNumber;
        if (result.day < 1 or result.day > 31) return error.InvalidNumber;

        // Validate T separator
        if (datetime_str[10] != 'T' and datetime_str[10] != 't') return error.InvalidCharacter;

        // Parse time
        result.hour = std.fmt.parseInt(u8, datetime_str[11..13], 10) catch return error.InvalidNumber;
        if (result.hour > 23) return error.InvalidNumber;
        if (datetime_str[13] != ':') return error.InvalidCharacter;
        result.minute = std.fmt.parseInt(u8, datetime_str[14..16], 10) catch return error.InvalidNumber;
        if (result.minute > 59) return error.InvalidNumber;
        if (datetime_str[16] != ':') return error.InvalidCharacter;
        result.second = std.fmt.parseInt(u8, datetime_str[17..19], 10) catch return error.InvalidNumber;
        if (result.second > 60) return error.InvalidNumber; // 60 is allowed for leap seconds

        var index: usize = 19;

        // Parse optional fractional seconds
        if (index < datetime_str.len and datetime_str[index] == '.') {
            index += 1;
            const frac_start = index;
            while (index < datetime_str.len and std.ascii.isDigit(datetime_str[index])) : (index += 1) {}
            const frac_end = index;
            const frac_str = datetime_str[frac_start..frac_end];
            var frac: u16 = std.fmt.parseInt(u16, frac_str, 10) catch return error.InvalidNumber;
            // Adjust to milliseconds
            while (frac_str.len < 3) : (frac *= 10) {}
            while (frac_str.len > 3) : (frac /= 10) {}
            result.millisecond = frac;
        }

        // Parse timezone offset
        if (index >= datetime_str.len) return error.UnexpectedEndOfInput;
        switch (datetime_str[index]) {
            'Z', 'z' => {
                result.offset = 0;
                index += 1;
            },
            '+', '-' => {
                const sign: i16 = if (datetime_str[index] == '+') 1 else -1;
                index += 1;
                if (index + 5 > datetime_str.len) return error.UnexpectedEndOfInput;
                const offset_hour = std.fmt.parseInt(u8, datetime_str[index .. index + 2], 10) catch return error.InvalidNumber;
                index += 2;
                if (datetime_str[index] != ':') return error.InvalidCharacter;
                index += 1;
                const offset_minute = std.fmt.parseInt(u8, datetime_str[index .. index + 2], 10) catch return error.InvalidNumber;
                result.offset = sign * @as(i16, offset_hour) * 60 + sign * @as(i16, offset_minute);
                index += 2;
            },
            else => return error.InvalidCharacter,
        }

        if (index != datetime_str.len) return error.UnexpectedToken;

        return result;
    }

    fn getOffsetSign(offset: i16) u8 {
        return if (offset < 0) '-' else '+';
    }

    /// Serializes the DateTime to a JSON string in RFC 3339 format
    pub fn jsonStringify(self: DateTime, out: anytype) error{OutOfMemory}!void {
        var buf: [30]u8 = undefined; // Max length: YYYY-MM-DDTHH:mm:ss.sss+HH:mm
        var fbs = std.io.fixedBufferStream(&buf);
        var writer = fbs.writer();

        // Write the date and time components
        writer.print("{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}", .{
            self.year,        self.month,  self.day,
            self.hour,        self.minute, self.second,
            self.millisecond,
        }) catch unreachable;

        // Write the timezone offset
        if (self.offset == 0) {
            writer.writeAll("Z") catch unreachable;
        } else {
            const abs_offset = @abs(self.offset);
            const offset_hours = @divFloor(abs_offset, 60);
            const offset_minutes = @mod(abs_offset, 60);
            writer.print("{c}{d:0>2}:{d:0>2}", .{
                getOffsetSign(self.offset),
                offset_hours,
                offset_minutes,
            }) catch unreachable;
        }

        return out.write(fbs.getWritten());
    }

    /// Creates a DateTime from Unix timestamp in milliseconds
    /// Note: This function assumes UTC (offset 0)
    // largely constructed from https://www.aolium.com/karlseguin/cf03dee6-90e1-85ac-8442-cf9e6c11602a
    pub fn fromMillis(ms: i64) DateTime {
        const ts: u64 = @intCast(@divTrunc(ms, 1000));
        const SECONDS_PER_DAY = std.time.s_per_day;
        const DAYS_PER_YEAR = 365;
        const DAYS_IN_4YEARS = 1461;
        const DAYS_IN_100YEARS = 36524;
        const DAYS_IN_400YEARS = 146097;
        const DAYS_BEFORE_EPOCH = 719468;

        const seconds_since_midnight: u64 = @rem(ts, SECONDS_PER_DAY);
        var day_n: u64 = DAYS_BEFORE_EPOCH + ts / SECONDS_PER_DAY;
        var temp: u64 = 0;

        temp = 4 * (day_n + DAYS_IN_100YEARS + 1) / DAYS_IN_400YEARS - 1;
        var year: u16 = @intCast(100 * temp);
        day_n -= DAYS_IN_100YEARS * temp + temp / 4;

        temp = 4 * (day_n + DAYS_PER_YEAR + 1) / DAYS_IN_4YEARS - 1;
        year += @intCast(temp);
        day_n -= DAYS_PER_YEAR * temp + temp / 4;

        var month: u8 = @intCast((5 * day_n + 2) / 153);
        const day: u8 = @intCast(day_n - (@as(u64, @intCast(month)) * 153 + 2) / 5 + 1);

        month += 3;
        if (month > 12) {
            month -= 12;
            year += 1;
        }

        return DateTime{ .year = year, .month = month, .day = day, .hour = @intCast(seconds_since_midnight / 3600), .minute = @intCast(seconds_since_midnight % 3600 / 60), .second = @intCast(seconds_since_midnight % 60), .millisecond = @intCast(@rem(ms, 1000)), .offset = 0 };
    }

    /// Converts the DateTime to an RFC 3339 formatted string
    /// Returns an allocated string that must be freed by the caller
    pub fn toRfc3339(self: DateTime, allocator: std.mem.Allocator) ![]u8 {
        var buffer = try allocator.alloc(u8, 30); // Max length: YYYY-MM-DDTHH:mm:ss.sss+HH:mm
        errdefer allocator.free(buffer);

        var fbs = std.io.fixedBufferStream(buffer);
        var writer = fbs.writer();

        // Write the date and time components
        try writer.print("{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}", .{
            self.year,        self.month,  self.day,
            self.hour,        self.minute, self.second,
            self.millisecond,
        });

        // Write the timezone offset
        if (self.offset == 0) {
            _ = try writer.write("Z");
        } else {
            const abs_offset = @abs(self.offset);
            const offset_hours = @divFloor(abs_offset, 60);
            const offset_minutes = @mod(abs_offset, 60);
            try writer.print("{c}{d:0>2}:{d:0>2}", .{
                getOffsetSign(self.offset),
                offset_hours,
                offset_minutes,
            });
        }

        const out = try allocator.alloc(u8, fbs.pos);
        @memcpy(out, buffer[0..fbs.pos]);
        allocator.free(buffer);

        return out;
    }
};
