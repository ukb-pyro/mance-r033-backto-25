from flask import Flask, send_from_directory
import sys
import os

# Get port from environment variable or command line or use default
PORT = int(os.getenv('PORT', sys.argv[1] if len(sys.argv) > 1 else 5001))
app = Flask(__name__, static_folder='.')

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

@app.route('/<path:path>')
def static_proxy(path):
    # Security check to prevent directory traversal
    if '..' in path or path.startswith('/'):
        return "Access denied", 403
    return send_from_directory('.', path)

if __name__ == '__main__':
    print(f"🚀 Starting Flask server on port {PORT}")
    app.run(debug=True, port=PORT, host='0.0.0.0')
