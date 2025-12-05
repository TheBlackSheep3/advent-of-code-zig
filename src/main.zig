const std = @import("std");
const clap = @import("clap");

const USAGE_FMT =
    \\Usage: {s} [-i <FILE>] [-o <FILE>]
    \\
    \\Options:
    \\{s}
    \\
;

const parameter_help =
    \\-h, --help           Display this help and exit.
    \\-i, --input <FILE>   Path to the file to read in.
    \\-o, --output <FILE>  Path to the file to write to.
    \\
;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // First we specify what parameters our program can take.
    // We can use `parseParamsComptime` to parse a string into an array of `Param(Help)`.
    const params = comptime clap.parseParamsComptime(parameter_help);

    const parsers = comptime .{
        .FILE = clap.parsers.string,
    };
    // Initialize our diagnostics, which can be used for reporting useful errors.
    // This is optional. You can also pass `.{}` to `clap.parse` if you don't
    // care about the extra information `Diagnostic` provides.
    var res = try clap.parse(clap.Help, &params, parsers, .{
        .allocator = arena.allocator(),
    });
    defer res.deinit();

    // buffer for writing output
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    if (res.args.help != 0)
    {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        defer _ = gpa.deinit();

        const argv = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, argv);
        try stdout.print(USAGE_FMT, .{std.fs.path.basename(argv[0]),parameter_help});
        try stdout.flush();
        return;
    }

    var read_buffer: [4096]u8 = undefined;
    var in: std.fs.File = undefined;
    if (res.args.input) |f| {
        in = try std.fs.cwd().openFile(f, .{});
    } else {
        in = std.fs.File.stdin();
    }
    defer in.close();
    var reader = in.reader(&read_buffer);

    var write_buffer: [4096]u8 = undefined;
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
    var line_no: usize = 0;
    while (try read_interface.takeDelimiter('\n')) |line| {
        line_no += 1;
        try write_interface.print("Read line: '{s}'\n", .{line});
    }
    try write_interface.print(
        \\============================
        \\= Read {d: >4} lines in total =
        \\============================
        \\
        , .{line_no});
}
