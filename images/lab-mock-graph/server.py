#!/usr/bin/env python3
"""A minimal mock of Microsoft Graph for the loadsmith `sharepoint` connector.

Serves only the routes the connector calls, backed by the canonical dataset
(baked in at /data/events.csv):

  POST .../oauth2/v2.0/token         → a fake bearer token
  GET  .../drives/{id}/root:...:/content → the CSV verbatim (file mode)
  GET  .../sites/{id}/lists              → empty (connector falls back to id)
  GET  .../lists/{id}/items              → list page 1 (+ @odata.nextLink)
  GET  /graphmock/page2                  → list page 2 (no nextLink)

The List fixture is the first rows of the same CSV, split across two pages so
the connector's pagination is exercised. Empty CSV fields become JSON null,
mirroring the canonical "empty string means NULL" convention.
"""
import csv
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CSV_PATH = "/data/events.csv"
PORT = 8080
LIST_PAGE_SIZE = 50
LIST_TOTAL = 100  # → two pages of 50; lab cases assert 100 list rows


def _load_list_items():
    items = []
    with open(CSV_PATH, newline="") as f:
        reader = csv.DictReader(f)
        for i, row in enumerate(reader):
            if i >= LIST_TOTAL:
                break
            fields = {k: (None if v == "" else v) for k, v in row.items()}
            items.append({"fields": fields})
    return items


ITEMS = _load_list_items()


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _json(self, code, obj):
        self._send(code, json.dumps(obj).encode(), "application/json")

    def do_POST(self):  # noqa: N802 (http.server API)
        path = self.path.split("?", 1)[0]
        length = int(self.headers.get("Content-Length", 0) or 0)
        if length:
            self.rfile.read(length)
        if path.endswith("/oauth2/v2.0/token"):
            return self._json(200, {"access_token": "mock-token", "expires_in": 3600})
        self._json(404, {"error": "not found", "path": path})

    def do_GET(self):  # noqa: N802 (http.server API)
        path = self.path.split("?", 1)[0]
        host = self.headers.get("Host", "graph:%d" % PORT)
        if path.endswith("/content"):
            with open(CSV_PATH, "rb") as f:
                return self._send(200, f.read(), "text/csv")
        if path == "/graphmock/page2":
            return self._json(200, {"value": ITEMS[LIST_PAGE_SIZE:LIST_TOTAL]})
        if path.endswith("/items"):
            return self._json(
                200,
                {
                    "value": ITEMS[:LIST_PAGE_SIZE],
                    "@odata.nextLink": "http://%s/graphmock/page2" % host,
                },
            )
        if path.endswith("/lists"):
            # No display-name match → connector treats the configured value as an id.
            return self._json(200, {"value": []})
        self._json(404, {"error": "not found", "path": path})

    def log_message(self, *args):  # silence per-request logging
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
