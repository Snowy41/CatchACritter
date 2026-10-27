"""One-shot localhost receiver: Studio POSTs {"relative/path.luau": "source", ...}; files are written
under the project root. Only accepts paths inside src/. Run: python tools/receive_sources.py"""
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"]))
        files = json.loads(body)
        written = []
        for rel, src in files.items():
            rel = rel.replace("\\", "/")
            if not rel.startswith("src/") or ".." in rel:
                continue
            path = os.path.join(ROOT, *rel.split("/"))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(src)
            written.append(rel)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(json.dumps(written).encode())

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", 8766), Handler).handle_request()  # serve exactly one request, then exit
