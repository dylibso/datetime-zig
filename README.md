# datetime-zig

This library provides a `DateTime` struct and associated functions for parsing
and serialization of RFC 3339 formatted date-time strings, conversion from Unix
timestamps, and more.

It aims to provide JSON serialization for a `datetime` string as specified in
OpenAPI. It is not very general-purpose, and simply implements enough to handle
the supported schema in Dylibso's [XTP](https://getxtp.com) product.

## Features

- RFC 3339 compliant date-time representation
- JSON parsing and serialization
- Conversion from Unix timestamp (milliseconds)
- Timezone offset support
- RFC 3339 string formatting

## Installation

```
zig fetch --save https://github.com/dylibso/datetime-zig/archive/refs/tags/v0.0.1.tar.gz
```

## Usage

Here's a simple example demonstrating how to use the `datetime` library:

```zig
const std = @import("std");
const DateTime = @import("datetime").DateTime;

pub fn main() !void {
    // Create a DateTime instance
    const dt = DateTime.fromMillis(std.time.milliTimestamp());

    // Directly convert to an RFC 3339 DateTime string
    const s = try dt.toRfc3339(std.heap.wasm_allocator);
    defer std.heap.wasm_allocator.free(s);
    // "2024-08-12T02:15:25.483Z"

    // Working with JSON
    // `DateTime` or any struct that contains a `DateTime` can be parsed from a JSON string, and stringified to JSON. Just use std.json.parseFromSlice, std.json.stringifyAlloc etc...
}
```

## API Reference

### `DateTime` Struct

- **`year`**: `u16`: Calendar year
- **`month`**:`u8`: Month of the year (1-12)
- **`day`**:`u8`: Day of the month (1-31)
- **`hour`**:`u8`: Hour of the day (0-23)
- **`minute`**:`u8`: Minute of the hour (0-59)
- **`second`**:`u8`: Second of the minute (0-60, allowing for leap seconds)
- **`millisecond`**:`u16`: Milliseconds (0-999)
- **`offset`**:`i16`: Timezone offset in minutes from UTC

### Functions

- `fromMillis(ms: u64) DateTime` Creates a DateTime from Unix timestamp in
  milliseconds (UTC).

- `toRfc3339(self: DateTime, allocator: std.mem.Allocator) ![]u8` Converts the
  DateTime to an RFC 3339 formatted string. Returns an allocated string that
  must be freed by the caller.

#### Mostly for Zig internally (JSON handling)

- `jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !DateTime`
  Parses a DateTime from a JSON string in RFC 3339 format.

- `jsonStringify(self: DateTime, out: anytype) !void` Serializes the DateTime to
  a JSON string in RFC 3339 format.

## License

[BSD-3-Clause](./LICENSE)

## Contributing

We welcome contributions, but you may want to open an issue first as this is
intentionally limited in scope to support our use cases. We'd be happy to
broaden the scope, but need to ensure compatibility and the commitment to
supporting new code and features.
