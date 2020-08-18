const std = @import("std");

const envsrc = @import("environment.zig");

pub const TypeId = @TagType(Value);
pub const Value = union(enum) {
    const Self = @This();

    // non-allocating
    void: void,
    number: f64,
    object: envsrc.ObjectHandle,
    boolean: bool,

    // allocating
    string: String,
    array: Array,
    enumerator: Enumerator,

    pub fn initVoid() Self {
        return Self{ .void = {} };
    }

    pub fn initNumber(val: f64) Self {
        return Self{ .number = val };
    }

    pub fn initObject(id: envsrc.ObjectHandle) Self {
        return Self{ .object = id };
    }

    pub fn initBoolean(val: bool) Self {
        return Self{ .boolean = val };
    }

    /// Initializes a new value with string contents.
    pub fn initString(allocator: *std.mem.Allocator, text: []const u8) !Self {
        return Self{ .string = try String.init(allocator, text) };
    }

    /// Initializes a new string literal.
    pub fn initStringLiteral(comptime text: []const u8) Self {
        return Self{ .string = String.initLiteral(text) };
    }

    /// Creates a new value that takes ownership of the passed string.
    /// This string must not be deinited.
    pub fn fromString(str: String) Self {
        return Self{ .string = str };
    }

    /// Creates a new value that takes ownership of the passed array.
    /// This array must not be deinited.
    pub fn fromArray(array: Array) Self {
        return Self{ .array = array };
    }

    /// Creates a new value with an enumerator. The array will be cloned
    /// into the enumerator and will not be owned.
    pub fn initEnumerator(array: Array) !Self {
        return Self{ .enumerator = try Enumerator.init(array) };
    }

    /// Creates a new value that takes ownership of the passed enumerator.
    /// This enumerator must not be deinited.
    pub fn fromEnumerator(enumerator: Enumerator) Self {
        return Self{ .enumerator = enumerator };
    }

    /// Duplicate this value.
    pub fn clone(self: Self) !Self {
        return switch (self) {
            .string => |s| Self{ .string = try s.clone() },
            .array => |a| Self{ .array = try a.clone() },
            .enumerator => |e| Self{ .enumerator = try e.clone() },
            .void, .number, .object, .boolean => self,
        };
    }

    /// Exchanges two values
    pub fn exchangeWith(self: *Self, other: *Self) void {
        const temp = self.*;
        self.* = other.*;
        other.* = temp;
    }

    /// Replaces the current instance with another instance.
    /// This will move the memory from the other instance into the
    /// current one. Calling deinit() on `other` after this function
    /// is an error.
    pub fn replaceWith(self: *Self, other: Self) void {
        self.deinit();
        self.* = other;
    }

    /// Checks if two values are equal.
    pub fn eql(lhs: Self, rhs: Self) bool {
        const Tag = @TagType(Self);
        if (@as(Tag, lhs) != @as(Tag, rhs))
            return false;
        return switch (lhs) {
            .void => true,
            .number => |n| n == rhs.number,
            .object => |o| o == rhs.object,
            .boolean => |b| b == rhs.boolean,
            .string => |s| String.eql(s, rhs.string),
            .array => |a| Array.eql(a, rhs.array),
            .enumerator => |e| Enumerator.eql(e, rhs.enumerator),
        };
    }

    pub fn deinit(self: Self) void {
        switch (self) {
            .array => |a| a.deinit(),
            .string => |s| s.deinit(),
            .enumerator => |e| e.deinit(),
            else => {},
        }
    }

    const ConversionError = error{TypeMismatch};

    pub fn toNumber(self: Self) ConversionError!f64 {
        if (self != .number)
            return error.TypeMismatch;
        return self.number;
    }

    pub fn toBoolean(self: Self) ConversionError!bool {
        if (self != .boolean)
            return error.TypeMismatch;
        return self.boolean;
    }

    pub fn toVoid(self: Self) ConversionError!void {
        if (self != .void)
            return error.TypeMismatch;
    }

    pub fn toObject(self: Self) ConversionError!envsrc.ObjectHandle {
        if (self != .object)
            return error.TypeMismatch;
        return self.object;
    }

    pub fn toArray(self: Self) ConversionError!Array {
        if (self != .array)
            return error.TypeMismatch;
        return self.array;
    }

    /// Gets the contained array or fails.
    pub fn getArray(self: *Self) ConversionError!*Array {
        if (self.* != .array)
            return error.TypeMismatch;
        return &self.array;
    }

    /// Gets the contained string or fails.
    pub fn getString(self: *Self) ConversionError!*String {
        if (self.* != .string)
            return error.TypeMismatch;
        return &self.string;
    }

    /// Gets the contained enumerator or fails.
    pub fn getEnumerator(self: *Self) ConversionError!*Enumerator {
        if (self.* != .enumerator)
            return error.TypeMismatch;
        return &self.enumerator;
    }

    fn formatArray(a: Array, stream: anytype) !void {
        try stream.writeAll("[");
        for (a.contents) |item, i| {
            if (i > 0)
                try stream.writeAll(",");

            // Workaround until #???? is fixed:
            // Print only the type name of the array item.
            // const itemType = @as(TypeId, item);
            // try std.fmt.format(context, Errors, output, " {}", .{@tagName(itemType)});
            try stream.print(" {}", .{item});
        }
        try stream.writeAll(" ]");
    }

    /// Checks if two values are equal.
    pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, stream: anytype) !void {
        return switch (value) {
            .void => stream.writeAll("void"),
            .number => |n| stream.print("{d}", .{n}),
            .object => |o| stream.print("${d}", .{o}),
            .boolean => |b| if (b) stream.writeAll("true") else stream.writeAll("false"),
            .string => |s| stream.print("\"{}\"", .{s.contents}),
            .array => |a| formatArray(a, stream),
            .enumerator => |e| {
                try stream.print("enumerator({}/{})", .{ e.index, e.array.contents.len });
            },
        };
    }
};

test "Value.void" {
    var voidVal = Value{ .void = {} };
    defer voidVal.deinit();

    std.debug.assert(voidVal == .void);
}

test "Value.number" {
    var value = Value{ .number = 3.14 };
    defer value.deinit();
    std.debug.assert(value == .number);
    std.debug.assert(value.number == 3.14);
}

test "Value.boolean" {
    var value = Value{ .boolean = true };
    defer value.deinit();
    std.debug.assert(value == .boolean);
    std.debug.assert(value.boolean == true);
}

test "Value.object" {
    var value = Value{ .object = 2394 };
    defer value.deinit();
    std.debug.assert(value == .object);
    std.debug.assert(value.object == 2394);
}

test "Value.string (move)" {
    var value = Value.fromString(try String.init(std.testing.allocator, "Hello"));
    defer value.deinit();

    std.debug.assert(value == .string);
    std.debug.assert(std.mem.eql(u8, value.string.contents, "Hello"));
}

test "Value.string (init)" {
    var value = try Value.initString(std.testing.allocator, "Malloc'd");
    defer value.deinit();

    std.debug.assert(value == .string);
    std.debug.assert(std.mem.eql(u8, value.string.contents, "Malloc'd"));
}

test "Value.eql (void)" {
    var v1 = Value.initVoid();
    var v2 = Value.initVoid();

    std.debug.assert(v1.eql(v2));
}

test "Value.eql (boolean)" {
    var v1 = Value.initBoolean(true);
    var v2 = Value.initBoolean(true);
    var v3 = Value.initBoolean(false);

    std.debug.assert(v1.eql(v2));
    std.debug.assert(v2.eql(v1));
    std.debug.assert(v1.eql(v3) == false);
    std.debug.assert(v2.eql(v3) == false);
}

test "Value.eql (number)" {
    var v1 = Value.initNumber(1.3);
    var v2 = Value.initNumber(1.3);
    var v3 = Value.initNumber(2.3);

    std.debug.assert(v1.eql(v2));
    std.debug.assert(v2.eql(v1));
    std.debug.assert(v1.eql(v3) == false);
    std.debug.assert(v2.eql(v3) == false);
}

test "Value.eql (object)" {
    var v1 = Value.initObject(1);
    var v2 = Value.initObject(1);
    var v3 = Value.initObject(2);

    std.debug.assert(v1.eql(v2));
    std.debug.assert(v2.eql(v1));
    std.debug.assert(v1.eql(v3) == false);
    std.debug.assert(v2.eql(v3) == false);
}

test "Value.eql (string)" {
    var v1 = try Value.initString(std.testing.allocator, "a");
    defer v1.deinit();

    var v2 = try Value.initString(std.testing.allocator, "a");
    defer v2.deinit();

    var v3 = try Value.initString(std.testing.allocator, "b");
    defer v3.deinit();

    std.debug.assert(v1.eql(v2));
    std.debug.assert(v2.eql(v1));
    std.debug.assert(v1.eql(v3) == false);
    std.debug.assert(v2.eql(v3) == false);
}

/// Immutable string type.
/// Both
pub const String = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,
    contents: []const u8,

    /// Clones `text` with the given parameter and stores the
    /// duplicated value.
    pub fn init(allocator: *std.mem.Allocator, text: []const u8) !Self {
        return Self{
            .allocator = allocator,
            .contents = try std.mem.dupe(allocator, u8, text),
        };
    }

    /// Returns a string that will take ownership of the passed `text` and
    /// will free that with `allocator`.
    pub fn initFromOwned(allocator: *std.mem.Allocator, text: []const u8) Self {
        return Self{
            .allocator = allocator,
            .contents = text,
        };
    }

    /// Creates a string value that will not be freed as the passed `text`
    /// is located in static memory, not in the heap.
    pub fn initLiteral(comptime text: []const u8) Self {
        return initFromOwned(null_allocator, text);
    }

    pub fn clone(self: Self) error{OutOfMemory}!Self {
        return Self{
            .allocator = self.allocator,
            .contents = try std.mem.dupe(self.allocator, u8, self.contents),
        };
    }

    pub fn eql(lhs: Self, rhs: Self) bool {
        return std.mem.eql(u8, lhs.contents, rhs.contents);
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.contents);
    }
};

test "String" {
    var text = try String.init(std.testing.allocator, "Hello, World!");
    std.debug.assert(std.mem.eql(u8, text.contents, "Hello, World!"));

    var text2 = try text.clone();

    text.deinit();

    std.debug.assert(std.mem.eql(u8, text2.contents, "Hello, World!"));
    text2.deinit();
}

test "String.eql" {
    var str1 = try String.init(std.testing.allocator, "Hello, World!");
    defer str1.deinit();

    var str2 = try String.init(std.testing.allocator, "Hello, World!");
    defer str2.deinit();

    var str3 = try String.init(std.testing.allocator, "World, Hello!");
    defer str3.deinit();

    std.debug.assert(str1.eql(str2));
    std.debug.assert(str2.eql(str1));
    std.debug.assert(str1.eql(str3) == false);
    std.debug.assert(str2.eql(str3) == false);
}

pub const Array = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,
    contents: []Value,

    pub fn init(allocator: *std.mem.Allocator, size: usize) !Self {
        var arr = Self{
            .allocator = allocator,
            .contents = try allocator.alloc(Value, size),
        };
        for (arr.contents) |*item| {
            item.* = Value{ .void = {} };
        }
        return arr;
    }

    pub fn clone(self: Self) error{OutOfMemory}!Self {
        var arr = Self{
            .allocator = self.allocator,
            .contents = try self.allocator.alloc(Value, self.contents.len),
        };
        errdefer arr.allocator.free(arr.contents);

        var index: usize = 0;

        // Cleanup all successfully cloned items
        errdefer {
            var i: usize = 0;
            while (i < index) : (i += 1) {
                arr.contents[i].deinit();
            }
        }

        while (index < arr.contents.len) : (index += 1) {
            arr.contents[index] = try self.contents[index].clone();
        }
        return arr;
    }

    pub fn eql(lhs: Self, rhs: Self) bool {
        if (lhs.contents.len != rhs.contents.len)
            return false;
        for (lhs.contents) |v, i| {
            if (!Value.eql(v, rhs.contents[i]))
                return false;
        }
        return true;
    }

    pub fn deinit(self: Self) void {
        for (self.contents) |item| {
            item.deinit();
        }
        self.allocator.free(self.contents);
    }
};

test "Array" {
    var array = try Array.init(std.testing.allocator, 3);
    defer array.deinit();

    std.debug.assert(array.contents.len == 3);
    std.debug.assert(array.contents[0] == .void);
    std.debug.assert(array.contents[1] == .void);
    std.debug.assert(array.contents[2] == .void);

    array.contents[0].replaceWith(Value.initBoolean(true));
    array.contents[1].replaceWith(try Value.initString(std.testing.allocator, "Hello"));
    array.contents[2].replaceWith(Value.initNumber(45.0));

    std.debug.assert(array.contents[0] == .boolean);
    std.debug.assert(array.contents[1] == .string);
    std.debug.assert(array.contents[2] == .number);
}

test "Array.eql" {
    var array1 = try Array.init(std.testing.allocator, 2);
    defer array1.deinit();

    array1.contents[0] = Value.initBoolean(true);
    array1.contents[1] = Value.initNumber(42);

    var array2 = try Array.init(std.testing.allocator, 2);
    defer array2.deinit();

    array2.contents[0] = Value.initBoolean(true);
    array2.contents[1] = Value.initNumber(42);

    var array3 = try Array.init(std.testing.allocator, 2);
    defer array3.deinit();

    array3.contents[0] = Value.initBoolean(true);
    array3.contents[1] = Value.initNumber(43);

    var array4 = try Array.init(std.testing.allocator, 3);
    defer array4.deinit();

    std.debug.assert(array1.eql(array2));
    std.debug.assert(array2.eql(array1));

    std.debug.assert(array1.eql(array3) == false);
    std.debug.assert(array2.eql(array3) == false);

    std.debug.assert(array1.eql(array4) == false);
    std.debug.assert(array2.eql(array4) == false);
    std.debug.assert(array3.eql(array4) == false);
}

pub const Enumerator = struct {
    const Self = @This();

    array: Array,
    index: usize,

    /// Creates a new enumerator that will clone the contained value.
    pub fn init(array: Array) !Self {
        return Self{
            .array = try array.clone(),
            .index = 0,
        };
    }

    /// Creates a new enumerator that will own the passed value.
    pub fn initFromOwned(array: Array) Self {
        return Self{
            .array = array,
            .index = 0,
        };
    }

    /// Checks if the enumerator has a next item.
    pub fn hasNext(self: Self) bool {
        return self.index < self.array.contents.len;
    }

    /// Returns either a owned value or nothing.
    /// Will replace the returned value in the enumerator array with `void`.
    /// As the enumerator can only yield values from the array and does not "store"
    /// them for later use, this prevents unnecessary clones.
    pub fn next(self: *Self) ?Value {
        if (self.index >= self.array.contents.len)
            return null;
        var result = Value.initVoid();
        self.array.contents[self.index].exchangeWith(&result);
        self.index += 1;
        return result;
    }

    pub fn clone(self: Self) !Self {
        return Self{
            .array = try self.array.clone(),
            .index = self.index,
        };
    }

    // Enumerators are never equal to each other.
    pub fn eql(lhs: Self, rhs: Self) bool {
        return false;
    }

    pub fn deinit(self: Self) void {
        self.array.deinit();
    }
};

test "Enumerator" {
    var array = try Array.init(std.testing.allocator, 3);
    array.contents[0] = try Value.initString(std.testing.allocator, "a");
    array.contents[1] = try Value.initString(std.testing.allocator, "b");
    array.contents[2] = try Value.initString(std.testing.allocator, "c");

    var enumerator = Enumerator.initFromOwned(array);
    defer enumerator.deinit();

    std.debug.assert(enumerator.hasNext());

    var a = enumerator.next() orelse return error.NotEnoughItems;
    defer a.deinit();

    var b = enumerator.next() orelse return error.NotEnoughItems;
    defer b.deinit();

    var c = enumerator.next() orelse return error.NotEnoughItems;
    defer c.deinit();

    std.debug.assert(enumerator.next() == null);

    std.debug.assert(a == .string);
    std.debug.assert(b == .string);
    std.debug.assert(c == .string);

    std.debug.assert(std.mem.eql(u8, a.string.contents, "a"));
    std.debug.assert(std.mem.eql(u8, b.string.contents, "b"));
    std.debug.assert(std.mem.eql(u8, c.string.contents, "c"));
}

test "Enumerator.eql" {
    var array = try Array.init(std.testing.allocator, 0);
    defer array.deinit();

    var enumerator1 = try Enumerator.init(array);
    defer enumerator1.deinit();

    var enumerator2 = try Enumerator.init(array);
    defer enumerator2.deinit();

    std.debug.assert(enumerator1.eql(enumerator2) == false);
}