"""Send a Python file to the Blender MCP bridge (localhost:9876) and print the result.

Usage: python bl.py <script.py>
The script runs inside Blender; assign a dict to `result` to return data.
"""
import json
import socket
import sys

code = open(sys.argv[1], encoding="utf-8").read()
with socket.create_connection(("127.0.0.1", 9876), timeout=300) as s:
    s.sendall((json.dumps({"type": "execute", "code": code, "strict_json": False}) + "\0").encode("utf-8"))
    buf = b""
    while b"\0" not in buf:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf += chunk
print(json.dumps(json.loads(buf.split(b"\0")[0]), indent=2))
