#!/usr/bin/env python3
# SPDX-License-Identifier: MIT

import argparse
import selectors
import socket
import sys
from contextlib import closing


def forward_bidirectional(client: socket.socket, upstream: socket.socket) -> None:
    sel = selectors.DefaultSelector()
    sel.register(client, selectors.EVENT_READ, upstream)
    sel.register(upstream, selectors.EVENT_READ, client)

    try:
        while True:
            for key, _ in sel.select():
                src = key.fileobj
                dst = key.data
                try:
                    data = src.recv(65536)
                except ConnectionResetError:
                    return

                if not data:
                    return

                view = memoryview(data)
                while view:
                    sent = dst.send(view)
                    view = view[sent:]
    finally:
        sel.close()


def handle_client(client: socket.socket, unix_socket_path: str) -> None:
    with closing(client):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as upstream:
            upstream.connect(unix_socket_path)
            forward_bidirectional(client, upstream)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Expose an m1n1 gdb unix socket over TCP for devcontainer use."
    )
    parser.add_argument(
        "--unix-socket",
        default="/tmp/.m1n1-unix",
        help="Path to the host-side m1n1 gdb unix socket (default: %(default)s)",
    )
    parser.add_argument(
        "--listen-host",
        default="127.0.0.1",
        help="TCP listen host (default: %(default)s)",
    )
    parser.add_argument(
        "--listen-port",
        type=int,
        default=12345,
        help="TCP listen port (default: %(default)s)",
    )

    args = parser.parse_args()

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((args.listen_host, args.listen_port))
        server.listen(1)

        print(
            f"Listening on tcp://{args.listen_host}:{args.listen_port} -> {args.unix_socket}",
            flush=True,
        )

        while True:
            client, addr = server.accept()
            host, port = addr
            print(f"Accepted {host}:{port}", flush=True)
            try:
                handle_client(client, args.unix_socket)
            except KeyboardInterrupt:
                raise
            except Exception as exc:
                print(f"Connection error: {exc}", file=sys.stderr, flush=True)
            finally:
                print(f"Closed {host}:{port}", flush=True)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("Stopping proxy", flush=True)
        raise SystemExit(0)
