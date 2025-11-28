import mysql from "mysql2/promise";

export const db = mysql.createPool({
  host: "localhost",
  user: "root",
  password: "raihan123",
  database: "smart_train",
  connectionLimit: 10
});
