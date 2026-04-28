const express = require("express");
const cors = require("cors");
const path = require("path");

const authRoutes = require("./routes/auth");
const householdRoutes = require("./routes/households");
const profileRoutes = require("./routes/profiles");
const gmailRoutes = require("./routes/gmail");
const spotifyRoutes = require("./routes/spotify");
const mirrorsRoutes = require("./routes/mirrors");
const { getByMirrorId } = require("./controllers/profileController");

const app = express();

// app.use(cors()); // allow all origins in dev — lock this down before production
app.use(
  cors({
    origin: [
      "http://localhost:8080",
      "http://127.0.0.1:8080", // Flutter web
      "http://localhost:3001",
      "http://127.0.0.1:3001", // Mirror UI
    ],
  }),
);
app.use(express.json());

// Serve uploaded faces statically at http://127.0.0.1:3000/faces/filename.jpg
app.use("/faces", express.static(path.join(__dirname, "../data/faces")));

// Routes
app.use("/api/auth", authRoutes);
app.use("/api/households", householdRoutes);
app.use("/api/profiles", profileRoutes);
// Gmail OAuth callback — Google calls this directly, no JWT
app.use("/api/gmail", gmailRoutes);
// Spotify OAuth callback — Spotify calls this directly, no JWT
app.use("/api/spotify", spotifyRoutes);

// Public mirror endpoint — no auth, used by the mirror display (profile list)
app.get("/api/mirror/:mirrorId/profiles", getByMirrorId);

// Mirror routes — active user polling, Gmail status, Gmail messages
app.use("/api/mirrors", mirrorsRoutes);

// Health check — useful for the mirror to verify connectivity
app.get("/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// 404
app.use((req, res) => {
  res.status(404).json({ error: "Not found" });
});

// Central error handler — reads the .status property thrown by services
app.use((err, req, res, next) => {
  const status = err.status || 500;
  if (status === 500) console.error(err);
  res.status(status).json({ error: err.message || "Internal server error" });
});

module.exports = app;
