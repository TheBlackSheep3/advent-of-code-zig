//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub fn get_zero_position_count(input: []const u8) !i32 {
    var zero_count: i32        = 0;
    var current_position: i32  = 50;
    var start_index: usize     = 0;
    var line_number: usize     = 1;
    while (std.mem.indexOfScalarPos(u8, input, start_index, '\n')) |end_index| {
        const len: usize = end_index - start_index;
        const line: []const u8 = input[start_index..end_index];
        const line_result: ?i32 = process_line(line) catch |err| {
            std.debug.print("failed to parse line: '{s}' (line: {})\n", .{line, line_number});
            return err;
        };
        if (line_result) |turn| {
            current_position += turn;
            current_position = mod(current_position, 100);
            if (0 == current_position) {
                zero_count += 1;
            }
        } else {
            break;
        }
        start_index += (len + 1); // skip over the new line
        line_number += 1;
    }
    return zero_count;
}

fn mod(numerator: i32, denominator: i32) i32 {
    var res: i32 = @rem(numerator, denominator);
    if (0 > res) {
        res += denominator;
    }
    return res;
}

fn check_get_zero_position_count(expected: i32, input: []const u8) !void {
    const result: i32 = try get_zero_position_count(input);
    std.testing.expect(result == expected) catch |err| {
        std.debug.print("expected: {}, actual: {}\n", .{expected, result});
        return err;
    };
}

test "modulo" {
    try std.testing.expect(mod(-2, 7) == 5);
    try std.testing.expect(mod(-7, 3) == 2);
    try std.testing.expect(mod(20, 3) == 2);
    try std.testing.expect(mod(15, 5) == 0);
}

test "empty string" {
    const result = try get_zero_position_count("");
    try std.testing.expect(result == 0);
}

test "sample input" {
    const sample =
        \\L68
        \\L30
        \\R48
        \\L5
        \\R60
        \\L55
        \\L1
        \\L99
        \\R14
        \\L82
        \\
    ;
    // try check_get_zero_position_count(0, sample[0..4]);  // including L68
    // try check_get_zero_position_count(0, sample[0..8]);  // including L30
    // try check_get_zero_position_count(1, sample[0..12]); // including R48
    // try check_get_zero_position_count(1, sample[0..15]); // including L5
    // try check_get_zero_position_count(1, sample[0..19]); // including R60
    // try check_get_zero_position_count(2, sample[0..23]); // including L55
    // try check_get_zero_position_count(2, sample[0..26]); // including L1
    // try check_get_zero_position_count(3, sample[0..30]); // including L99
    // try check_get_zero_position_count(3, sample[0..34]); // including R14
    try check_get_zero_position_count(3, sample);
}

fn process_line(line: []const u8) !?i32 {
    // assumes no new lines in the string
    if (line.len == 0) {
        return null;
    } else if (line.len == 1) {
        return error.InvalidLine;
    } else {
        var sign: i32 = undefined;
        if (line[0] == 'L') {
            sign = -1;
        } else if (line[0] == 'R') {
            sign = 1;
        } else {
            return error.InvalidLine;
        }
        const value: i32 = std.fmt.parseInt(i32, line[1..], 10) catch {
            return error.InvalidLine;
        };
        if (0 > value) {
            return error.InvalidLine;
        }
        return sign * value;
    }
}

fn check_process_line(expected: ?i32, input: []const u8) !void {
    const result: ?i32 = try process_line(input);
    std.testing.expect(result == expected) catch |err| {
        std.debug.print("expected: {?}, actual: {?}\n", .{expected, result});
        return err;
    };
}

test "empty line" {
    try check_process_line(null, "");
}

test "ill-formed line" {
    try std.testing.expectError(error.InvalidLine, process_line("1"));
    try std.testing.expectError(error.InvalidLine, process_line("foo"));
    try std.testing.expectError(error.InvalidLine, process_line("\n\n"));
    try std.testing.expectError(error.InvalidLine, process_line(".|:"));
    try std.testing.expectError(error.InvalidLine, process_line("R-5"));
    try std.testing.expectError(error.InvalidLine, process_line("L-10"));
}

test "correct line" {
    try check_process_line(3, "R3");
    try check_process_line(32, "R32");
    try check_process_line(-32, "L32");
    try check_process_line(100, "R100");
    try check_process_line(-9082, "L9082");
}
