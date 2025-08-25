const std = @import("std");
/// This is a more resilient way to import ZON objects.
///
/// The main difference for my use case is for pointers.
/// This function will handle pointers as long as
/// they are not specified from the ZON object.
pub fn getZon(T: type, zon: anytype) T {
    if (T == @TypeOf(zon)) return zon;
    switch (@typeInfo(T)) {
        .@"struct" => |s| {
            var ret: T = undefined;
            inline for (s.fields) |f| {
                if (@hasField(@TypeOf(zon), f.name)) {
                    @field(ret, f.name) = getZon(f.type, @field(zon, f.name));
                } else {
                    @field(ret, f.name) = f.defaultValue() orelse @compileError("struct \"" ++ @typeName(T) ++ "\" has no default value for field \"" ++ f.name ++ "\" and zon import has no replacement");
                }
            }
            return ret;
        },
        .@"union" => {
            if (@typeInfo(@TypeOf(zon)) == .enum_literal) {
                return zon;
            }
            // unions have the same syntax as structs so we have to convert
            const field = @typeInfo(@TypeOf(zon)).@"struct".fields[0];
            return @unionInit(T, field.name, field.defaultValue().?);
        },
        .array => |a| {
            var ret: T = undefined;
            inline for (0..ret.len) |i| {
                ret[i] = getZon(a.child, zon[i]);
            }
            return ret;
        },
        else => return zon,
    }
}

const testing = std.testing;

test "nullable pointer" {
    const T = struct {
        a: ?*u8 = null,
    };
    try testing.expectEqualDeep(
        T{ .a = null },
        getZon(T, @import("empty.zon")),
    );
}

test "nullable" {
    const T = struct {
        a: ?*u8,
    };
    try testing.expectEqualDeep(
        T{ .a = null },
        getZon(T, @import("null.zon")),
    );
}

test "nested struct" {
    const T = struct {
        a: struct {
            b: u8 = 27,
            c: u8 = 7,
        } = .{},
        d: u8 = 97,
    };
    try testing.expectEqualDeep(T{
        .a = .{
            .b = 27,
            // this 42 comes from the zon
            .c = 42,
        },
        .d = 97,
    }, getZon(T, @import("nested.zon")));
}

test "enum" {
    const dir = enum { n, e, s, w };
    const T = struct {
        a: dir = .n,
        b: dir,
    };
    try testing.expectEqualDeep(
        T{ .a = .n, .b = .e },
        getZon(T, @import("enum.zon")),
    );
}

test "union" {
    const u = union(enum) { a: f32, b: u64 };
    const T = struct {
        a: u = u{ .a = 4.2 },
        b: u = u{ .a = 42.69 },
        c: u = u{ .b = 11111111 },
    };
    try testing.expectEqualDeep(
        T{
            .a = u{ .a = 4.2 },
            .b = u{ .b = 42 },
            .c = u{ .a = 11111111 },
        },
        getZon(T, @import("union.zon")),
    );
}

test "array" {
    const T2 = struct {
        c: u8 = 0,
        d: u32 = 7,
    };
    const T = struct { a: [5]u8 = [5]u8{ 0, 1, 2, 3, 4 }, b: [2]T2 = [2]T2{ .{}, .{} } };
    try testing.expectEqualDeep(
        T{
            .a = [5]u8{ 0, 0, 0, 0, 1 },
            .b = [2]T2{
                T2{ .c = 0, .d = 0 },
                T2{ .c = 0, .d = 7 },
            },
        },
        getZon(T, @import("array.zon")),
    );
}
