const fs = require('fs');
const path = require('path');

const logDir = path.join(__dirname, '..', '..', 'logs');
const logFile = path.join(logDir, 'app.log');

if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir, { recursive: true });
}

function log(level, message) {
  const line = `[${new Date().toISOString()}] [${level}] ${message}\n`;
  fs.appendFile(logFile, line, () => {});
  if (level === 'ERROR') {
    console.error(line.trim());
  } else {
    console.log(line.trim());
  }
}

function readLastLines(maxLines = 200) {
  if (!fs.existsSync(logFile)) return [];
  const content = fs.readFileSync(logFile, 'utf-8');
  const lines = content.split('\n').filter(Boolean);
  return lines.slice(-maxLines);
}

module.exports = {
  info: (msg) => log('INFO', msg),
  error: (msg) => log('ERROR', msg),
  readLastLines
};
