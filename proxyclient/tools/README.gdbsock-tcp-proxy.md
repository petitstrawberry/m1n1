Run on the host:

```bash
python proxyclient/tools/gdbsock_tcp_proxy.py --listen-host 0.0.0.0 --listen-port 12345
```

Then from the devcontainer/debugger, connect to:

```text
host.docker.internal:12345
```

For GDB:

```gdb
target remote host.docker.internal:12345
```
