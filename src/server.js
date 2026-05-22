const express = require("express");
const fs = require("fs");
const path = require("path");
const app = express();
const port = process.env.PORT || 3000;

// Read the .build-env file stamped by the CI "Write build metadata" step into a
// plain object. Returns an empty object locally (file won't exist in dev).
// Keys are: APP_VERSION, APP_BRANCH, APP_BUILD, APP_DEPLOYED_AT, APP_COMMIT_SHA.
function readBuildEnv() {
  const envPath = path.join(__dirname, ".build-env");
  if (!fs.existsSync(envPath)) return {};
  const result = {};
  for (const line of fs.readFileSync(envPath, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    result[trimmed.slice(0, eq).trim()] = trimmed.slice(eq + 1).trim();
  }
  return result;
}

// Build-time values — stamped into .build-env by CI, read directly from the file.
// Runtime config (APP_ENV, PORT) comes from Azure App Settings / process.env.
const buildEnv = readBuildEnv();
const buildInfo = {
  version:     buildEnv.APP_VERSION     || "0.0.0-local",
  environment: process.env.APP_ENV      || "local",
  branch:      buildEnv.APP_BRANCH      || "unknown",
  buildNumber: buildEnv.APP_BUILD       || "local",
  deployedAt:  buildEnv.APP_DEPLOYED_AT || new Date().toISOString(),
  commitSha:   buildEnv.APP_COMMIT_SHA  || "unknown",
};

// Env → banner colour mapping (makes it obvious what you're looking at)
const envColours = {
  prod:           "#1a7f37",   // green
  "test-feature": "#b45309",   // amber
  test:           "#1d4ed8",   // blue
  staging:        "#7c3aed",   // purple
  local:          "#374151",   // grey
};

function bannerColour(env) {
  for (const [key, colour] of Object.entries(envColours)) {
    if (env.toLowerCase().includes(key)) return colour;
  }
  return "#374151";
}

app.get("/", (req, res) => {
  const colour = bannerColour(buildInfo.environment);
  res.setHeader("Content-Type", "text/html");
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>devloop · ${buildInfo.environment}</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: system-ui, sans-serif; background: #f9fafb; color: #111827; }

    .banner {
      background: ${colour};
      color: #fff;
      padding: 1.25rem 2rem;
      display: flex;
      align-items: center;
      gap: 1rem;
    }
    .banner h1 { font-size: 1.4rem; font-weight: 700; letter-spacing: -0.5px; }
    .banner .env-badge {
      background: rgba(255,255,255,0.2);
      border-radius: 999px;
      padding: 0.25rem 0.75rem;
      font-size: 0.8rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    .container { max-width: 680px; margin: 2.5rem auto; padding: 0 1.5rem; }

    .card {
      background: #fff;
      border: 1px solid #e5e7eb;
      border-radius: 10px;
      padding: 1.5rem 2rem;
      margin-bottom: 1.25rem;
    }
    .card h2 { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.08em; color: #6b7280; margin-bottom: 1rem; }

    table { width: 100%; border-collapse: collapse; }
    td { padding: 0.5rem 0; font-size: 0.9rem; vertical-align: top; }
    td:first-child { color: #6b7280; width: 40%; }
    td:last-child  { font-weight: 500; font-family: ui-monospace, monospace; font-size: 0.85rem; word-break: break-all; }

    .version-big {
      font-size: 2.5rem;
      font-weight: 800;
      color: ${colour};
      letter-spacing: -1px;
    }
    .version-sub { color: #6b7280; font-size: 0.85rem; margin-top: 0.25rem; }
  </style>
</head>
<body>
  <div class="banner">
    <h1>devloop demo</h1>
    <span class="env-badge">${buildInfo.environment}</span>
  </div>

  <div class="container">
    <div class="card">
      <div class="version-big">v${buildInfo.version}</div>
      <div class="version-sub">build #${buildInfo.buildNumber}</div>
    </div>

    <div class="card">
      <h2>Deployment details</h2>
      <table>
        <tr><td>Environment</td><td>${buildInfo.environment}</td></tr>
        <tr><td>Branch</td><td>${buildInfo.branch}</td></tr>
        <tr><td>Commit</td><td>${buildInfo.commitSha}</td></tr>
        <tr><td>Deployed at</td><td>${buildInfo.deployedAt}</td></tr>
        <tr><td>Build #</td><td>${buildInfo.buildNumber}</td></tr>
      </table>
    </div>
  </div>
</body>
</html>`);
});

// Health check endpoint (used by Azure and Octopus health checks)
app.get("/health", (req, res) => {
  res.json({ status: "ok", ...buildInfo });
});

app.listen(port, () => {
  console.log(`devloop-demo listening on port ${port} — env: ${buildInfo.environment}`);
});
