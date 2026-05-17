from flask import Flask, jsonify, request, Response
from flask_cors import CORS
from pymongo import MongoClient
from datetime import datetime
import os
import time
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)
CORS(app)

# Prometheus metrics
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)
REQUEST_LATENCY = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency',
    ['method', 'endpoint']
)

@app.before_request
def before_request():
    request._start_time = time.time()

@app.after_request
def after_request(response):
    latency = time.time() - request._start_time
    REQUEST_COUNT.labels(method=request.method, endpoint=request.path, status=response.status_code).inc()
    REQUEST_LATENCY.labels(method=request.method, endpoint=request.path).observe(latency)
    return response

# MongoDB
mongo_host = os.environ['MONGODB_HOST']
mongo_port = int(os.environ['MONGODB_PORT'])
mongo_database = os.environ['MONGODB_DATABASE']

mongo_client = MongoClient(mongo_host, mongo_port)
db = mongo_client[mongo_database]
contact_messages = db['contact_messages']

@app.route('/metrics')
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'contact-support-team'}), 200

@app.route('/api/contact-message', methods=['GET'])
def get_contact_message():
    return jsonify({'message': "We're here to help! If you have any questions, concerns, or feedback, please don't hesitate to reach out."})

@app.route('/api/contact-submit', methods=['POST'])
def submit_contact_form():
    post_data = request.get_json()
    contact_messages.insert_one({
        'name': post_data.get('name'),
        'email': post_data.get('email'),
        'message': post_data.get('message'),
        'timestamp': datetime.now()
    })
    return jsonify({'status': 'success', 'message': 'Your message has been successfully submitted.'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000)
