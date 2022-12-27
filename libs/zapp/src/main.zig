const std = @import("std");
const zecs = @import("zecs");
const ArrayList = std.ArrayListUnmanaged;
const HashMap = std.AutoHashMapUnmanaged;
const System = zecs.System;
const World = zecs.World;

pub const Plugin = *const fn (*App) anyerror!void;

const rl = @cImport({
    @cInclude("raylib.h");
});

pub const Stage = enum {
    startup,
    first,
    preUpdate,
    update,
    postUpdate,
    render,
    last,
};

pub const SystemGroup = struct {
    systems: ArrayList(System) = .{},

    pub fn addSystem(self: *SystemGroup, allocator: std.mem.Allocator, system: System) !void {
        try self.systems.append(allocator, system);
    }

    pub fn run(self: *SystemGroup, world: *World) !void {
        for (self.systems.items) |system| {
            try system(world);
        }
    }
};

pub const App = struct {
    world: World,
    plugins: ArrayList(Plugin) = .{},
    systems: HashMap(Stage, SystemGroup) = .{},

    pub fn init(allocator: std.mem.Allocator) !App {
        var app = App{
            .world = try World.init(allocator),
        };

        try app.systems.put(allocator, .startup, .{});
        try app.systems.put(allocator, .first, .{});
        try app.systems.put(allocator, .preUpdate, .{});
        try app.systems.put(allocator, .update, .{});
        try app.systems.put(allocator, .postUpdate, .{});
        try app.systems.put(allocator, .render, .{});
        try app.systems.put(allocator, .last, .{});

        return app;
    }

    pub fn deinit(self: *App) void {
        self.world.deinit();
        self.plugins.deinit(self.world.allocator);
        var it = self.systems.valueIterator();
        while (it.next()) |group| {
            group.systems.deinit(self.world.allocator);
        }
        self.systems.deinit(self.world.allocator);
    }

    pub fn addPlugin(self: *App, plugin: Plugin) *App {
        self.plugins.append(self.world.allocator, plugin) catch unreachable;
        return self;
    }

    pub fn addResource(self: *App, comptime T: type, resource: T) *App {
        self.world.addResource(T, resource);
        return self;
    }

    pub fn addSystem(self: *App, stage: Stage, system: System) *App {
        self.systems.getPtr(stage).?.addSystem(self.world.allocator, system) catch unreachable;
        return self;
    }

    pub fn run(self: *App) !void {
        rl.InitWindow(800, 600, "App");

        for (self.plugins.items) |plugin| {
            try plugin(self);
        }

        const startupSystems = self.systems.getPtr(.startup).?;

        const firstSystems = self.systems.getPtr(.first).?;
        const preUpdateSystems = self.systems.getPtr(.preUpdate).?;
        const updateSystems = self.systems.getPtr(.update).?;
        const postUpdateSystems = self.systems.getPtr(.postUpdate).?;
        const renderSystems = self.systems.getPtr(.render).?;
        const lastSystems = self.systems.getPtr(.last).?;

        try startupSystems.run(&self.world);

        while (!rl.WindowShouldClose()) {
            try firstSystems.run(&self.world);
            try preUpdateSystems.run(&self.world);
            try updateSystems.run(&self.world);
            try postUpdateSystems.run(&self.world);
            try renderSystems.run(&self.world);
            try lastSystems.run(&self.world);
        }

        rl.CloseWindow();
    }
};