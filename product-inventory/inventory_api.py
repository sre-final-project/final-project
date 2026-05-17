from flask import Flask, jsonify, request, Response
from flask_cors import CORS
import psycopg2
import os
import time
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST, CollectorRegistry, REGISTRY
from prometheus_client import start_http_server
import threading

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
DB_CONNECTIONS = Gauge(
    'db_connections_active',
    'Active database connections'
)

@app.before_request
def before_request():
    request._start_time = time.time()

@app.after_request
def after_request(response):
    latency = time.time() - request._start_time
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.path,
        status=response.status_code
    ).inc()
    REQUEST_LATENCY.labels(
        method=request.method,
        endpoint=request.path
    ).observe(latency)
    return response

# PostgreSQL connection
pg_host = os.environ['POSTGRES_HOST']
pg_port = os.environ['POSTGRES_PORT']
pg_database = os.environ['POSTGRES_DB']
pg_user = os.environ['POSTGRES_USER']
pg_password = os.environ['POSTGRES_PASSWORD']

max_retries = 5
retry_delay = 5

for retry in range(max_retries):
    try:
        conn = psycopg2.connect(
            host=pg_host, port=pg_port,
            database=pg_database, user=pg_user, password=pg_password
        )
        DB_CONNECTIONS.set(1)
        break
    except psycopg2.OperationalError as e:
        if retry < max_retries - 1:
            print(f"Connection attempt {retry + 1} failed. Retrying in {retry_delay}s...")
            time.sleep(retry_delay)
        else:
            print("Max retries reached.")
            raise e

with conn.cursor() as cur:
    cur.execute('''
        CREATE TABLE IF NOT EXISTS inventory (
            product_id INT PRIMARY KEY,
            quantity INT NOT NULL
        )
    ''')
    conn.commit()

def insert_initial_data():
    with conn.cursor() as cur:
        cur.execute('SELECT COUNT(*) FROM inventory')
        count = cur.fetchone()[0]
        if count == 0:
            initial_data = [(1,100),(2,50),(3,75),(4,120),(5,30),(6,60),(7,40),(8,90),(9,80),(10,70),(11,20),(12,55)]
            cur.executemany('INSERT INTO inventory (product_id, quantity) VALUES (%s, %s)', initial_data)
            conn.commit()
            print('Initial inventory data inserted')

insert_initial_data()

@app.route('/metrics')
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy', 'service': 'product-inventory'}), 200

@app.route('/api/inventory', methods=['GET'])
def get_inventory():
    with conn.cursor() as cur:
        cur.execute('SELECT * FROM inventory')
        rows = cur.fetchall()
        inventory = [{'id': row[0], 'quantity': row[1]} for row in rows]
        return jsonify(inventory)

@app.route('/api/inventory/<int:product_id>', methods=['GET'])
def get_product_inventory(product_id):
    with conn.cursor() as cur:
        cur.execute('SELECT * FROM inventory WHERE product_id = %s', (product_id,))
        row = cur.fetchone()
        if row:
            return jsonify({'id': row[0], 'quantity': row[1]})
        return jsonify({'error': 'Product not found'}), 404

@app.route('/api/order/<int:product_id>', methods=['POST'])
def order_product(product_id):
    with conn.cursor() as cur:
        cur.execute('SELECT * FROM inventory WHERE product_id = %s', (product_id,))
        row = cur.fetchone()
        if row:
            quantity = row[1]
            if quantity > 0:
                cur.execute('UPDATE inventory SET quantity = quantity - 1 WHERE product_id = %s', (product_id,))
                conn.commit()
                return jsonify({'id': product_id, 'quantity': quantity - 1})
            return jsonify({'error': 'Product is out of stock'}), 400
        return jsonify({'error': 'Product not found'}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3002)
