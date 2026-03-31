const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const householdRoutes = require('./routes/households');
const profileRoutes = require('./routes/profiles');
const gmailRoutes = require('./routes/gmail');

const app = express();

app.use(cors()); // allow all origins in dev — lock this down before production
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/households', householdRoutes);
app.use('/api/profiles', profileRoutes);
// Gmail OAuth callback — Google calls this directly, no JWT
app.use('/api/gmail', gmailRoutes);

// Health check — useful for the mirror to verify connectivity
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// 404
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Central error handler — reads the .status property thrown by services
app.use((err, req, res, next) => {
  const status = err.status || 500;
  if (status === 500) console.error(err);
  res.status(status).json({ error: err.message || 'Internal server error' });
});

module.exports = app;
