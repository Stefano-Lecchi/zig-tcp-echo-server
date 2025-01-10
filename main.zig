const std = @import("std");
const posix = std.posix;
const net = std.net;

// FIRST IMPLEMENTATION: SINGLE CLIENT NO POLL.

pub fn main() !void {
    // generate server socket.
    const sock_fd = try posix.socket(posix.AF.INET, posix.SOCK.STREAM, 0);
    defer posix.close(sock_fd);
    std.debug.print("opened socket fd: {d} \n", .{sock_fd});

    const sockaddr = try net.Address.parseIp4("0.0.0.0", 3000);
    try posix.bind(sock_fd, &sockaddr.any, sockaddr.getOsSockLen());
    try posix.listen(sock_fd, 5);

    // handle client connection.
    const conn = try posix.accept(sock_fd, undefined, undefined, 0);
    defer posix.close(conn);
 
    while (true) {
        var buf: [256]u8 = undefined;
        const msg_size = try posix.recv(conn, &buf, 0);
        std.debug.print(
            "received msg {s} with len {d}\n",
            .{ buf[0..msg_size], msg_size }
        );

        if (msg_size == 0) {
            std.debug.print("client {d} disconnected", .{conn});
            break;
        }

        _ = try posix.send(conn, buf[0..msg_size], posix.MSG.CONFIRM);
    }
}
