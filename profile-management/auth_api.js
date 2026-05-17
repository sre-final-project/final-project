const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const mysql = require('mysql2/promise');
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

app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.path, status_code: res.statusCode });
    httpRequestTotal.inc({ method: req.method, route: req.path, status_code: res.statusCode });
  });
  next();
});

const secretKey = 'secret-key';
let connection;

const dbConfig = {
  host: process.env.MYSQL_HOST,
  port: process.env.MYSQL_PORT,
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD,
  database: process.env.MYSQL_DATABASE,
};

async function connectToMySQL() {
  const maxRetries = 5;
  const retryDelay = 5000;
  for (let i = 0; i < maxRetries; i++) {
    try {
      connection = await mysql.createConnection(dbConfig);
      console.log('Connected to MySQL');
      await createUsersTable();
      break;
    } catch (error) {
      console.error(`Error connecting to MySQL (attempt ${i + 1}):`, error);
      if (i === maxRetries - 1) { console.error('Max retries reached. Exiting...'); process.exit(1); }
      await new Promise(resolve => setTimeout(resolve, retryDelay));
    }
  }
}

async function createUsersTable() {
  try {
    await connection.execute(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        firstName VARCHAR(255) NOT NULL,
        lastName VARCHAR(255) NOT NULL,
        address VARCHAR(255) NOT NULL,
        postalCode VARCHAR(10) NOT NULL,
        email VARCHAR(255) NOT NULL UNIQUE,
        password VARCHAR(255) NOT NULL
      )
    `);
    console.log('Users table created');
  } catch (error) {
    console.error('Error creating users table:', error);
    process.exit(1);
  }
}

connectToMySQL();

const authenticateToken = (req, res, next) => {
  const token = req.headers.authorization;
  if (!token) return res.status(401).json({ error: 'No token provided' });
  jwt.verify(token, secretKey, (err, decoded) => {
    if (err) return res.status(401).json({ error: 'Invalid token' });
    req.userId = decoded.userId;
    next();
  });
};

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', service: 'profile-management', timestamp: new Date() });
});

app.post('/api/signup', async (req, res) => {
  const { firstName, lastName, address, postalCode, email, password } = req.body;
  try {
    const [rows] = await connection.execute('SELECT * FROM users WHERE email = ?', [email]);
    if (rows.length > 0) return res.status(409).json({ error: 'Email already exists' });
    await connection.execute(
      'INSERT INTO users (firstName, lastName, address, postalCode, email, password) VALUES (?, ?, ?, ?, ?, ?)',
      [firstName, lastName, address, postalCode, email, password]
    );
    res.status(201).json({ message: 'User registered successfully' });
  } catch (error) {
    console.error('Error signing up:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/signin', async (req, res) => {
  const { email, password } = req.body;
  try {
    const [rows] = await connection.execute('SELECT * FROM users WHERE email = ?', [email]);
    const user = rows[0];
    if (!user || user.password !== password) return res.status(401).json({ error: 'Invalid credentials' });
    const token = jwt.sign({ userId: user.id }, secretKey);
    res.json({ message: 'Login successful', token, user });
  } catch (error) {
    console.error('Error signing in:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/signout', authenticateToken, (req, res) => {
  res.json({ message: 'Logout successful' });
});

app.get('/api/protected', authenticateToken, async (req, res) => {
  try {
    const [rows] = await connection.execute('SELECT * FROM users WHERE id = ?', [req.userId]);
    res.json({ message: 'Protected route accessed successfully', user: rows[0] });
  } catch (error) {
    console.error('Error accessing protected route:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.put('/api/update', authenticateToken, async (req, res) => {
  const { firstName, lastName, address, postalCode } = req.body;
  try {
    const [rows] = await connection.execute('SELECT * FROM users WHERE id = ?', [req.userId]);
    const user = rows[0];
    if (!user) return res.status(404).json({ error: 'User not found' });
    await connection.execute(
      'UPDATE users SET firstName = ?, lastName = ?, address = ?, postalCode = ? WHERE id = ?',
      [firstName || user.firstName, lastName || user.lastName, address || user.address, postalCode || user.postalCode, req.userId]
    );
    const [updatedRows] = await connection.execute('SELECT * FROM users WHERE id = ?', [req.userId]);
    res.json({ message: 'User updated successfully', user: updatedRows[0] });
  } catch (error) {
    console.error('Error updating user:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const port = 3003;
app.listen(port, () => { console.log(`Authentication API is running on port ${port}`); });
