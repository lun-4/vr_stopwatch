const sqlite = @import("sqlite");
const std = @import("std");

const logger = std.log.scoped(.main);

const Session = struct {
    timestamp_start: i64,
    timestamp_end: i64,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var alloc = gpa.allocator();

    const home_path = std.posix.getenv("HOME").?;
    const db_path = try std.fs.path.joinZ(alloc, &[_][]const u8{ home_path, "vr_stopwatch_state.db" });
    defer alloc.free(db_path);

    var db = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = db_path },
        .open_flags = .{
            .write = true,
            .create = true,
        },
        .threading_mode = .MultiThread,
    });
    defer db.deinit();

    const wal = try db.oneAlloc([]const u8, alloc,
        \\ PRAGMA journal_mode=WAL;
    , .{}, .{});
    defer alloc.free(wal.?);

    _ = try db.one(usize,
        \\ PRAGMA busy_timeout = 5000;
    , .{}, .{});

    try db.execMulti(
        \\ PRAGMA synchronous = NORMAL;
        \\ PRAGMA cache_size = 1000000000;
        \\ PRAGMA foreign_keys = true;
        \\ PRAGMA temp_store = memory;
        \\ CREATE TABLE IF NOT EXISTS current_session(
        \\   id int primary key,
        \\   timestamp_start int,
        \\   timestamp_end int
        \\ ) STRICT;
        // send current_session to sessions after 15 minutes between sessions
        \\ CREATE TABLE IF NOT EXISTS sessions(
        \\   timestamp_start int,
        \\   timestamp_end int
        \\ ) STRICT;
    , .{});

    const stdout = std.io.getStdOut();

    const now = std.time.timestamp();
    const maybe_current_session = try db.one(Session, "SELECT timestamp_start, timestamp_end FROM current_session", .{}, .{});

    var savepoint = try db.savepoint("updatesession");
    defer savepoint.rollback();

    if (maybe_current_session) |current_session| {
        const seconds_between_pings = now - current_session.timestamp_end;
        if (seconds_between_pings > 15 * 60) {
            // submit current session to sessions table, wipe current one
            try db.exec(
                "INSERT INTO sessions (timestamp_start, timestamp_end) VALUES (?, ?)",
                .{},
                .{ current_session.timestamp_start, current_session.timestamp_end },
            );
            try db.exec("DELETE FROM current_session", .{}, .{});
        }
    }
    const maybe_session_state = try db.one(struct {
        timestamp_start: i64,
        timestamp_end: i64,
    },
        \\ INSERT INTO current_session (id, timestamp_start, timestamp_end) VALUES (?, ?, ?)
        \\ ON CONFLICT (id) DO UPDATE SET timestamp_end = ?
        \\ RETURNING timestamp_start, timestamp_end
    , .{}, .{ 1, now, now, now });
    savepoint.commit();

    const session_state = maybe_session_state.?;
    const seconds_in_session = session_state.timestamp_end - session_state.timestamp_start;
    try formatSeconds(seconds_in_session, stdout.writer());
}

pub fn formatSeconds(seconds: i64, writer: anytype) !void {
    const hours = @divFloor(seconds, 3600);
    const minutes = @divFloor(@mod(seconds, 3600), 60);
    const secs = @mod(seconds, 60);

    if (hours > 0) {
        try writer.print("{d}h", .{hours});
    }

    if (hours > 0 or minutes > 0) {
        try writer.print("{d}m", .{minutes});
    }
    try writer.print("{d}s", .{secs});
}
