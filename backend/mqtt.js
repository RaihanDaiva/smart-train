// ==========================================
// Konfigurasi MQTT HiveMQ Cloud
// ==========================================
import mqtt from "mqtt";
import mysql from "mysql2/promise";

// MQTT Broker
const mqttServer =
  "mqtts://9e108cb03c734f0394b0f0b49508ec1e.s1.eu.hivemq.cloud:8883";
const mqttUser = "Device02";
const mqttPass = "Device02";

// Topic
const topicSpeed = "smartTrain/speedometer";
const topicPalang = "smartTrain/barrier";
const topicCamera = "smartTrain/camera";
const topicTelemetry = "smartTrain/telemetry_batch";

// ==========================================
// Koneksi MariaDB (Pool untuk async/await)
// ==========================================
const db = mysql.createPool({
  host: "localhost",
  user: "root",
  password: "",
  database: "smart_train",
  waitForConnections: true,
  connectionLimit: 10,
});

// ==========================================
// Realtime Dedup Cache
// ==========================================
const lastRealtimeCache = new Map();
// format:
// key   = segment
// value = { speed, timestamp }

// Test connection
(async () => {
  try {
    await db.query("SELECT 1");
    console.log("MariaDB Connected!");
  } catch (err) {
    console.error("DB Error:", err);
  }
})();

// ==========================================
// Queue System & Processing Flag
// ==========================================
let palangQueue = Promise.resolve();
let cameraQueue = Promise.resolve();

let isPalangProcessing = false;
let isCameraProcessing = false;

let lastPalangStatus = null;
let lastCameraStatus = null;


// ==========================================
// MQTT Connect
// ==========================================
const mqttClient = mqtt.connect(mqttServer, {
  username: mqttUser,
  password: mqttPass,
  reconnectPeriod: 5000,
});

mqttClient.on("connect", () => {
  console.log("Terhubung ke HiveMQ!");
  mqttClient.subscribe(
    [topicSpeed, topicPalang, topicCamera, topicTelemetry],
    (err) => {
      if (!err) {
        console.log("Subscribe:");
        console.log(" - " + topicSpeed);
        console.log(" - " + topicPalang);
        console.log(" - " + topicCamera);
        console.log(" - " + topicTelemetry);
      }
    }
  );
});

// ==========================================
//  MQTT Handler  ANTI DUPLICATE dengan QUEUE
// ==========================================
mqttClient.on("message", async (topic, message) => {
  try {
    const data = JSON.parse(message.toString());

    // ======================================================
    // KECEPATAN
    // ======================================================
    if (topic === topicSpeed) {
      const timestamp = new Date();

      // RATA-RATA > Key: kecepatan_r > SIMPAN KE DATABASE
      if (data.hasOwnProperty("kecepatan_r")) {
        console.log(`RATA-RATA diterima > ${data.kecepatan_r} km/jam`);
        console.log(`Waktu total: ${data.waktu_total || "N/A"} detik`);

        const sql = `
          INSERT INTO train_speed (speed, created_at)
          VALUES (?, ?)
        `;

        try {
          await db.query(sql, [data.kecepatan_r, timestamp]);
          console.log("RATA-RATA tersimpan ke DB!");
        } catch (err) {
          console.error("Error insert rata-rata:", err);
        }
      }
      // SEGMEN > Key: kecepatan_s > TIDAK DISIMPAN
      else if (data.hasOwnProperty("kecepatan_s")) {
        console.log(
          `Segmen ${data.id} > ${data.kecepatan_s} km/jam (Realtime UI only)`
        );
      }
      // Format tidak dikenal
      else {
        console.log("Data format tidak dikenal:", data);
      }

      return;
    }

    // ======================================================
    // KECEPATAN REALTIME (STRONG DEDUP - PER DETIK)
    // ======================================================
    if (topic === topicTelemetry) {
      let payload;
      try {
        payload = JSON.parse(message.toString());
      } catch {
        return;
      }

      if (!payload.speed || typeof payload.speed !== "object") return;

      // BUCKET PER DETIK
      const secondBucket = Math.floor(Date.now() / 1000);
      const createdAt = new Date(secondBucket * 1000);

      const inserts = [];

      for (const [segment, speedRaw] of Object.entries(payload.speed)) {
        const speed = Number(speedRaw);
        if (Number.isNaN(speed)) continue;

        const cacheKey = `${segment}_${secondBucket}`;

        // JIKA SUDAH ADA DI DETIK INI > SKIP
        if (lastRealtimeCache.has(cacheKey)) continue;

        lastRealtimeCache.set(cacheKey, true);

        inserts.push([segment, speed, createdAt]);
      }

      if (inserts.length === 0) return;

      try {
        await db.query(
          `
      INSERT INTO train_speed_realtime (segment, speed, created_at)
      VALUES ?
    `,
          [inserts]
        );

        console.log("Telemetry saved:", inserts.length);
      } catch (err) {
        console.error("Telemetry insert error:", err);
      }

      return;
    }

    // ======================================================
    // PALANG > INSERT DENGAN QUEUE SYSTEM
    // ======================================================
    if (topic === topicPalang) {
      const currentStatus = data.status;

      console.log(`PALANG request received: ${currentStatus}`);

      // Cek jika sedang processing
      if (isPalangProcessing) {
        console.log(`PALANG: Already processing, request IGNORED`);
        return;
      }

      // Add to queue - akan diproses satu per satu
      palangQueue = palangQueue.then(async () => {
        // Set processing flag
        isPalangProcessing = true;

        try {
          // Timestamp dibuat DI DALAM QUEUE
          const timestamp = new Date();

          // Delay kecil untuk pastikan tidak ada concurrent execution
          await new Promise((resolve) => setTimeout(resolve, 50));

          // Cek cache dulu (paling cepat)
          if (currentStatus === lastPalangStatus) {
            console.log(
              ` PALANG: Status sama dengan cache (${currentStatus}), SKIP`
            );
            return;
          }

          // Cek database dengan FOR UPDATE lock
          const connection = await db.getConnection();

          try {
            await connection.beginTransaction();

            const [lastRecord] = await connection.query(
              "SELECT status FROM palang ORDER BY id DESC LIMIT 1 FOR UPDATE"
            );

            // Cek apakah status berbeda dari database
            if (
              lastRecord.length > 0 &&
              lastRecord[0].status === currentStatus
            ) {
              console.log(
                `PALANG: Status sama dengan DB (${currentStatus}), SKIP`
              );
              await connection.commit();
              lastPalangStatus = currentStatus;
              return;
            }

            console.log(
              `PALANG: Insert status ${currentStatus} at ${timestamp.toISOString()}`
            );

            // Insert data baru
            await connection.query(
              "INSERT INTO palang (status, created_at, updated_at) VALUES (?, ?, ?)",
              [currentStatus, timestamp, timestamp]
            );

            await connection.commit();
            console.log("PALANG inserted successfully!");

            // Update cache setelah berhasil
            lastPalangStatus = currentStatus;
          } catch (err) {
            await connection.rollback();
            console.error("Error insert palang:", err);
          } finally {
            connection.release();
          }
        } catch (err) {
          console.error("PALANG queue error:", err);
        } finally {
          // Release processing flag setelah selesai
          isPalangProcessing = false;
        }
      });

      return;
    }

    // ======================================================
    // CAMERA > INSERT DENGAN QUEUE SYSTEM
    // ======================================================
    if (topic === topicCamera) {
      const currentStatus = data.status;

      console.log(`CAMERA request received: ${currentStatus}`);

      // Cek jika sedang processing
      if (isCameraProcessing) {
        console.log(`CAMERA: Already processing, request IGNORED`);
        return;
      }

      // Add to queue - akan diproses satu per satu
      cameraQueue = cameraQueue.then(async () => {
        // Set processing flag
        isCameraProcessing = true;

        try {
          // Timestamp dibuat DI DALAM QUEUE
          const timestamp = new Date();

          // Delay kecil untuk pastikan tidak ada concurrent execution
          await new Promise((resolve) => setTimeout(resolve, 50));

          // Cek cache dulu (paling cepat)
          if (currentStatus === lastCameraStatus) {
            console.log(
              `CAMERA: Status sama dengan cache (${currentStatus}), SKIP`
            );
            return;
          }

          // Cek database dengan FOR UPDATE lock
          const connection = await db.getConnection();

          try {
            await connection.beginTransaction();

            const [lastRecord] = await connection.query(
              "SELECT status FROM camera ORDER BY id DESC LIMIT 1 FOR UPDATE"
            );

            // Cek apakah status berbeda dari database
            if (
              lastRecord.length > 0 &&
              lastRecord[0].status === currentStatus
            ) {
              console.log(
                `CAMERA: Status sama dengan DB (${currentStatus}), SKIP`
              );
              await connection.commit();
              lastCameraStatus = currentStatus;
              return;
            }

            console.log(
              `CAMERA: Insert status ${currentStatus} at ${timestamp.toISOString()}`
            );

            // Insert data baru
            await connection.query(
              "INSERT INTO camera (status, created_at, updated_at) VALUES (?, ?, ?)",
              [currentStatus, timestamp, timestamp]
            );

            await connection.commit();
            console.log("CAMERA inserted successfully!");

            // Update cache setelah berhasil
            lastCameraStatus = currentStatus;
          } catch (err) {
            await connection.rollback();
            console.error("Error insert camera:", err);
          } finally {
            connection.release();
          }
        } catch (err) {
          console.error("CAMERA queue error:", err);
        } finally {
          // Release processing flag setelah selesai
          isCameraProcessing = false;
        }
      });

      return;
    }
  } catch (err) {
    console.error("Error parsing MQTT message:", err);
    console.error("Topic:", topic);
    console.error("Message:", message.toString());
  }
});

// ==========================================
// Error & Close Handlers
// ==========================================
mqttClient.on("error", (err) => {
  console.error("MQTT Error:", err);
});

mqttClient.on("close", () => {
  console.log("MQTT Connection closed");
});

export default mqttClient;
