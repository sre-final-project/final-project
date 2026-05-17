const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const { MongoClient } = require('mongodb');
const fs = require('fs');
const client = require('prom-client');

const app = express();
app.use(bodyParser.json());
app.use(cors());

// Prometheus metrics
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register],
});

// Middleware to track metrics
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.path, status_code: res.statusCode });
    httpRequestTotal.inc({ method: req.method, route: req.path, status_code: res.statusCode });
  });
  next();
});

// Environment variables
const mongoUrl = `mongodb://${process.env.MONGODB_HOST}:${process.env.MONGODB_PORT}`;
const dbName = process.env.MONGODB_DATABASE;

// Load products data from JSON file
const productsData = JSON.parse(fs.readFileSync('products.json'));

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Health endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', service: 'product-catalog', timestamp: new Date() });
});

// Connect to MongoDB
MongoClient.connect(mongoUrl, { useUnifiedTopology: true }, async (err, mongoClient) => {
  if (err) {
    console.error('Error connecting to MongoDB:', err);
    process.exit(1);
  }
  console.log('Connected to MongoDB');
  const db = mongoClient.db(dbName);

  const count = await db.collection('products').countDocuments();
  if (count === 0) {
    await db.collection('products').insertMany(productsData);
    console.log('Inserted initial products data');
  }

  app.get('/api/products', async (req, res) => {
    try {
      const products = await db.collection('products').find().toArray();
      res.json(products);
    } catch (err) {
      console.error('Error retrieving products:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  app.get('/api/products/:id', async (req, res) => {
    try {
      const productId = parseInt(req.params.id);
      const product = await db.collection('products').findOne({ id: productId });
      if (product) {
        res.json(product);
      } else {
        res.status(404).json({ error: 'Product not found' });
      }
    } catch (err) {
      console.error('Error retrieving product:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  const port = process.env.PORT || 3001;
  app.listen(port, () => {
    console.log(`Product Catalog microservice is running on port ${port}`);
  });
});
