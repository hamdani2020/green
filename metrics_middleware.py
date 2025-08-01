import time
import psutil
import streamlit as st
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from threading import Thread
import http.server
import socketserver

# Prometheus metrics
REQUEST_COUNT = Counter('streamlit_requests_total', 'Total requests', ['method', 'endpoint'])
REQUEST_DURATION = Histogram('streamlit_request_duration_seconds', 'Request duration')
ACTIVE_USERS = Gauge('streamlit_active_users', 'Number of active users')
CPU_USAGE = Gauge('streamlit_cpu_usage_percent', 'CPU usage percentage')
MEMORY_USAGE = Gauge('streamlit_memory_usage_bytes', 'Memory usage in bytes')
YOLO_DETECTIONS = Counter('streamlit_yolo_detections_total', 'Total YOLO detections')
GEMINI_API_CALLS = Counter('streamlit_gemini_api_calls_total', 'Total Gemini API calls', ['status'])

class MetricsHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-Type', CONTENT_TYPE_LATEST)
            self.end_headers()
            self.wfile.write(generate_latest())
        else:
            self.send_response(404)
            self.end_headers()

def start_metrics_server(port=8502):
    """Start Prometheus metrics server"""
    handler = MetricsHandler
    with socketserver.TCPServer(("", port), handler) as httpd:
        httpd.serve_forever()

def update_system_metrics():
    """Update system metrics"""
    CPU_USAGE.set(psutil.cpu_percent())
    MEMORY_USAGE.set(psutil.virtual_memory().used)

def track_yolo_detection():
    """Track YOLO detection"""
    YOLO_DETECTIONS.inc()

def track_gemini_api_call(status='success'):
    """Track Gemini API call"""
    GEMINI_API_CALLS.labels(status=status).inc()

def track_request(endpoint='/', method='GET'):
    """Track request"""
    REQUEST_COUNT.labels(method=method, endpoint=endpoint).inc()

def track_active_users():
    """Track active users (simplified)"""
    if 'user_id' not in st.session_state:
        st.session_state.user_id = time.time()
        ACTIVE_USERS.inc()

# Start metrics server in background thread
def initialize_metrics():
    metrics_thread = Thread(target=start_metrics_server, daemon=True)
    metrics_thread.start()
    
    # Update system metrics periodically
    def update_metrics():
        while True:
            update_system_metrics()
            time.sleep(10)
    
    system_metrics_thread = Thread(target=update_metrics, daemon=True)
    system_metrics_thread.start()