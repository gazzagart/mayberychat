#!/bin/bash
# Serve the web build with proper COOP/COEP headers for WASM support

cd "$(dirname "$0")"

# Build if not already built
if [ ! -d "build/web" ]; then
    echo "Building web app first..."
    flutter build web
fi

echo "Starting web server with COOP/COEP headers on http://localhost:8080"
echo "Access your app at: http://localhost:8080"
echo ""

# Use Python's http.server with custom headers
python3 - <<'EOF'
from http.server import HTTPServer, SimpleHTTPRequestHandler
import os

class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        # Add COOP and COEP headers for SharedArrayBuffer support
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        # Add CORS headers for local development
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

os.chdir('build/web')
httpd = HTTPServer(('0.0.0.0', 8080), CORSRequestHandler)
print("Server running on http://localhost:8080")
httpd.serve_forever()
EOF
