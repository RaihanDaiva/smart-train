import express from "express";
import cors from "cors";
import mysql from "mysql2/promise";
import mqttClient from "./mqtt.js";

const app = express();
app.use(cors());

// ==========================================
// Database Connection Pool
// ==========================================
export const db = mysql.createPool({
  host: "localhost",
  user: "root",
  password: "",
  database: "smart_train",
  waitForConnections: true,
  connectionLimit: 10,
});

// ==========================================
// TRAIN - Ambil data terakhir
// ==========================================
app.get("/train/latest", async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT * FROM train_speed ORDER BY id DESC LIMIT 1"
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: "No data found" });
    }
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

// ==========================================
// PALANG - Ambil data terakhir
// ==========================================
app.get("/palang", async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT * FROM palang ORDER BY id DESC LIMIT 1"
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: "No palang data found" });
    }
    // Kembalikan sebagai array agar kompatibel dengan Flutter
    res.json([rows[0]]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

app.post("/palang/update", express.json(), (req, res) => {
  const { status } = req.body;
  console.log(`Publishing palang status: ${status}`);
  mqttClient.publish("smartTrain/barrier", JSON.stringify({ status }));
  res.json({ success: true });
});

// ==========================================
// CAMERA - Ambil data terakhir
// ==========================================
app.get("/camera", async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT * FROM camera ORDER BY id DESC LIMIT 1"
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: "No camera data found" });
    }
    // Kembalikan sebagai array agar kompatibel dengan Flutter
    res.json([rows[0]]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

app.post("/camera/update", express.json(), (req, res) => {
  const { status } = req.body;
  console.log(`Publishing camera status: ${status}`);
  mqttClient.publish("smartTrain/camera", JSON.stringify({ status }));
  res.json({ success: true });
});

app.listen(4000, "0.0.0.0", () => {
  console.log("Server running at http://0.0.0.0:4000");
});

// ==========================================
// TRAIN - Ambil riwayat kecepatan (Filter Waktu)
// ==========================================
app.get("/train-speed/history", async (req, res) => {
  const { filter } = req.query;

  let condition = "";

  // Kita tambahkan "AND DATE(created_at) = CURDATE()" 
  // agar filter menit tidak mengambil data hari kemarin (misal saat jam 00:05)
  switch (filter) {
    case "1m":
      condition = "created_at >= NOW() - INTERVAL 1 MINUTE AND DATE(created_at) = CURDATE()";
      break;
    case "5m":
      condition = "created_at >= NOW() - INTERVAL 5 MINUTE AND DATE(created_at) = CURDATE()";
      break;
    case "10m":
      condition = "created_at >= NOW() - INTERVAL 10 MINUTE AND DATE(created_at) = CURDATE()";
      break;
    case "30m":
      condition = "created_at >= NOW() - INTERVAL 30 MINUTE AND DATE(created_at) = CURDATE()";
      break;
    default:
      // Default ke 5 menit hari ini
      condition = "created_at >= NOW() - INTERVAL 5 MINUTE AND DATE(created_at) = CURDATE()";
  }

  try {
    const [rows] = await db.query(`
      SELECT speed, created_at
      FROM train_speed
      WHERE ${condition}
      ORDER BY created_at ASC
    `);

    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "DB Error" });
  }
});

// ==========================================
// TRAIN - Ambil kecepatan realtime
// ==========================================
app.get("/train/realtime", async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT 
        segment,
        speed,
        DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') AS created_at
      FROM train_speed_realtime
      ORDER BY id DESC
      LIMIT 30
    `);

    res.json(rows.reverse()); // penting agar urutan waktu benar
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "DB Error" });
  }
});

// ==========================================
// AUTHENTICATION
// ==========================================
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";

const SECRET = "SUPER_SECRET_JWT_UBAH_INI";

// ---------------- REGISTER ----------------
app.post("/auth/register", express.json(), async (req, res) => {
  const { name, email, password } = req.body;

  try {
    // Cek email sudah ada?
    const [exists] = await db.query("SELECT * FROM users WHERE email = ?", [
      email,
    ]);

    if (exists.length > 0) {
      return res.status(400).json({ message: "Email already registered" });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Insert user ke database
    await db.query(
      "INSERT INTO users (name, email, password) VALUES (?, ?, ?)",
      [name, email, hashedPassword]
    );

    res.json({ message: "Register success" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Register failed" });
  }
});

// ---------------- LOGIN ----------------
app.post("/auth/login", express.json(), async (req, res) => {
  const { email, password } = req.body;

  try {
    const [users] = await db.query("SELECT * FROM users WHERE email = ?", [
      email,
    ]);

    if (users.length === 0) {
      return res.status(401).json({ message: "Email not found" });
    }

    const user = users[0];

    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      return res.status(401).json({ message: "Wrong password" });
    }

    // Generate JWT
    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name },
      SECRET,
      { expiresIn: "7d" }
    );

    res.json({
      accessToken: token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Login failed" });
  }
});

// ---------------- USER ----------------
app.get("/auth/user/:id", async (req, res) => {
  const [rows] = await db.query("SELECT * FROM users WHERE id = ? LIMIT 1", [
    req.params.id,
  ]);

  if (rows.length === 0)
    return res.status(404).json({ message: "User not found" });

  res.json(rows[0]);
});
