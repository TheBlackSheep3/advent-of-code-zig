const std = @import("std");
const clap = @import("clap");

const USAGE_FMT =
    \\Usage: {s} [-i <FILE>] [-o <FILE>]
    \\
    \\Options:
    \\{s}
    \\
;

const PARAMETER_HELP =
    \\-h, --help           Display this help and exit.
    \\-i, --input <FILE>   Path to the file to read in.
    \\-o, --output <FILE>  Path to the file to write to.
    \\
;

const BUFFER_SIZE = 4096;

fn print_help(writer: *std.io.Writer) !void {
    const program_name = try get_program_name();
    const basename = std.fs.path.basename(program_name);
    try writer.print(USAGE_FMT, .{basename, PARAMETER_HELP});
    try writer.flush();
}

fn get_program_name() ![]const u8 {
    var argIter = std.process.args();
    if (argIter.next()) |name| {
        return name;
    } else {
        return error.UnknownProgramName;
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const heapCheck = gpa.deinit();
        if (std.heap.Check.leak == heapCheck) {
            std.debug.print("memory leak detected\n", .{});
        }
    }
    const allocator = gpa.allocator();

    // First we specify what parameters our program can take.
    // We can use `parseParamsComptime` to parse a string into an array of `Param(Help)`.
    const params = comptime clap.parseParamsComptime(PARAMETER_HELP);
    const parsers = comptime .{ .FILE = clap.parsers.string, };

    // buffer for writing output
    var write_buffer: [BUFFER_SIZE]u8 = undefined;

    // Initialize our diagnostics, which can be used for reporting useful errors.
    // This is optional. You can also pass `.{}` to `clap.parse` if you don't
    // care about the extra information `Diagnostic` provides.
    var res = clap.parse(clap.Help, &params, parsers, .{
        .allocator = allocator,
    }) catch |err| {
        var stderr_writer = std.fs.File.stderr().writer(&write_buffer);
        const stderr = &stderr_writer.interface;
        try print_help(stderr);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        var stdout_writer = std.fs.File.stdout().writer(&write_buffer);
        const stdout = &stdout_writer.interface;
        try print_help(stdout);
        return;
    }

    var read_buffer: [BUFFER_SIZE]u8 = undefined;
    var in: std.fs.File = undefined;
    if (res.args.input) |f| {
        in = try std.fs.cwd().openFile(f, .{});
    } else {
        in = std.fs.File.stdin();
    }
    defer in.close();
    var reader = in.reader(&read_buffer);

    var out: std.fs.File = undefined;
    if (res.args.output) |f| {
        out = try std.fs.cwd().createFile(f, .{});
    } else {
        out = std.fs.File.stdout();
    }
    defer out.close();
    var writer = out.writer(&write_buffer);

    const read_interface = &reader.interface;
    const write_interface = &writer.interface;
    defer write_interface.flush() catch |err| { std.debug.print("failed final flush: {}", .{err}); };
    var data = std.ArrayList(u8).empty;
    try read_interface.appendRemainingUnlimited(allocator, &data);
    defer data.deinit(allocator);
    try write_interface.print("sucessfully read {} bytes\n", .{data.items.len});
}
