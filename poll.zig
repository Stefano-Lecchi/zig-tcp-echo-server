const std = @import("std");
const posix = std.posix;
const net = std.net;
const linux = std.os.linux;

const MAX_CONNECTIONS = 5;

// SMARTER IMPLEMENTATION: MULTI-CLIENT WITH POLLING.

fn accept_new_client(
    //server: posix.socket_t
    server: *posix.pollfd
) posix.AcceptError!linux.pollfd {
    const conn = try posix.accept(server.fd, null, null, 0);
    server.*.revents = 0;

    return .{
        .fd = conn,
        .events = linux.POLL.IN,
        .revents = 0
    };
}

fn get_data_from_client(
    client: *posix.pollfd
) (posix.RecvFromError || posix.SendError)!void {
     var buf: [256]u8 = undefined;
     const msg_size = try posix.recv(client.*.fd, &buf, 0);
     std.debug.print(
         "received msg {s} with len {d} from client {d}\n",
         .{ buf[0..msg_size], msg_size, client.*.fd }
     );

     // client wants to disconnect
     if (msg_size == 0) {
        client.*.revents = linux.POLL.HUP;
     } else {
        _ = try posix.send(client.*.fd, buf[0..msg_size], posix.MSG.CONFIRM);
        client.*.revents = 0;
     }

     return;
}

pub fn main() !void {
    // generate server socket.
    const sock_fd = try posix.socket(posix.AF.INET, posix.SOCK.STREAM, 0);
    std.debug.print("opened socket fd: {d} \n", .{sock_fd});

    var sockaddr = try net.Address.parseIp4("0.0.0.0", 3000);
    try posix.bind(sock_fd, &sockaddr.any, sockaddr.getOsSockLen());
    try posix.listen(sock_fd, MAX_CONNECTIONS);

    // pollables connections (server + clients).
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    
    var pollables = std.ArrayList(posix.pollfd).init(gpa.allocator());
    defer pollables.deinit();

    try pollables.append(
        .{
            .fd = sock_fd,
            .events = linux.POLL.IN,
            .revents = 0 
        } 
    );
    defer {
        for (pollables.items) |pollable| {
            posix.close(pollable.fd);
        }
    }

    while (true) {
        std.debug.print("\n\n polling for connections \n", .{});

        // check for disconnected clients.
        for (pollables.items, 0..) |pollable, i| {
            if (pollable.revents == linux.POLL.HUP) {
                posix.close(pollable.fd);
                _ = pollables.orderedRemove(i);
                std.debug.print("client {d} disconnected \n", .{pollable.fd});
            }
        }

        const pollables_slice = pollables.items;
        std.debug.print("current connections {any}\n", .{pollables_slice});

        _ = try posix.poll(pollables_slice, -1);
        std.debug.print("polled: {any} \n", .{pollables_slice});

        for (pollables_slice, 0..) |pollable, i| {
            if (pollable.fd == sock_fd and pollable.revents == linux.POLL.IN) {
                // handle new connection.
                std.debug.print("handling new connection \n", .{});
                const new_conn = try accept_new_client(&pollables_slice[i]);
                try pollables.append(new_conn);
            } else if (pollable.revents == linux.POLL.IN) {
                // got data from a client
                std.debug.print("data from client {any} \n", .{pollable});
                try get_data_from_client(&pollables_slice[i]);
            } 
        }
    }
}
