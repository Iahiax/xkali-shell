// ============================================================
// Placeholder Node.js bot
// Replace this file with your real bot code.
// The reviver will start it automatically if package.json exists.
// ============================================================

console.log("[node-bot] started at", new Date().toISOString());

// Keep the process alive
setInterval(() => {
  console.log("[node-bot] heartbeat", new Date().toISOString());
}, 60_000);

// Example: graceful shutdown
process.on("SIGINT", () => {
  console.log("[node-bot] shutting down");
  process.exit(0);
});
