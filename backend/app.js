import express from "express";
import cors from "cors";
import mysql from "mysql2/promise";
import mqttClient from "./mqtt.js";

const app = express();
app.use(cors());

// ==========================================
// 🗄️ Database Connection Pool
// ==========================================
export const db = mysql.createPool({
  host: "localhost",
  user: "root",
  password: "raihan123",
  database: "smart_train",
  waitForConnections: true,
  connectionLimit: 10,
});

// ==========================================
// 🚆 TRAIN - Ambil data terakhir
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
// 🚧 PALANG - Ambil data terakhir
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
  console.log(`📤 Publishing palang status: ${status}`);
  mqttClient.publish("smarttrain/palang", JSON.stringify({ status }));
  res.json({ success: true });
});

// ==========================================
// 📸 CAMERA - Ambil data terakhir
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
  console.log(`📤 Publishing camera status: ${status}`);
  mqttClient.publish("smarttrain/camera", JSON.stringify({ status }));
  res.json({ success: true });
});

app.listen(4000, () => {
  console.log("🚀 Backend running on port 4000");
});