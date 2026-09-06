#!/usr/bin/env node
/**
 * Unity CLI bridge for safe-opencode (Docker) -> Windows host.
 *
 * Listens on localhost only. The opencode container calls POST /run with a
 * JSON payload {args:[...], cwd?, timeoutMs?}; this script executes the Unity
 * CLI installed on the host and returns stdout/stderr/exit code as JSON.
 *
 * Zero dependencies. Requires Node.js >= 18: winget install OpenJS.NodeJS.LTS
 *
 * Usage:
 *   node unity-bridge.mjs [options]
 *
 * Options:
 *   --port <n>        Port to listen on            (default 7777, env UNITY_BRIDGE_PORT)
 *   --command <cmd>   Unity CLI executable         (default "unity", env UNITY_CLI_COMMAND)
 *   --token <t>       Require this auth token      (env UNITY_BRIDGE_TOKEN)
 *   --no-token        Disable token auth
 *   --allow-cmds <l>  Comma list of allowed first args, e.g. "build,test" (env UNITY_ALLOWED_CMDS)
 *   --path-map <m>    Container->host path pairs "cpath=hpath;cpath2=hpath2" (env UNITY_PATH_MAP)
 *
 * A generated token is stored in ~/.unity-bridge/token when none is supplied.
 *
 * Runtime API:
 *   GET  /health          status probe
 *   POST /run             execute the Unity CLI
 *   POST /set-path-map    update path mappings at runtime, body {"path":"c=h;c2=h2"}
 */

import http from "node:http";
import { spawn } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";

const DEFAULT_PORT = 7777;
const MAX_OUTPUT = 10 * 1024 * 1024;
const KILL_GRACE_MS = 5000;

function parseArgs(argv) {
  const out = {
    port: Number(process.env.UNITY_BRIDGE_PORT || DEFAULT_PORT),
    command: process.env.UNITY_CLI_COMMAND || "unity",
    token: process.env.UNITY_BRIDGE_TOKEN || "",
    noToken: false,
    allowCmds: process.env.UNITY_ALLOWED_CMDS || "",
    pathMap: process.env.UNITY_PATH_MAP || "",
    help: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--port") out.port = Number(argv[++i]);
    else if (a === "--command") out.command = argv[++i];
    else if (a === "--token") out.token = argv[++i];
    else if (a === "--no-token") out.noToken = true;
    else if (a === "--allow-cmds") out.allowCmds = argv[++i];
    else if (a === "--path-map") out.pathMap = argv[++i];
    else if (a === "--help" || a === "-h") out.help = true;
    else throw new Error(`Unknown option: ${a}`);
  }
  return out;
}

function parsePathMap(s) {
  // "/workspace=C:/src/game;/other=D:/other project"
  return s
    .split(";")
    .map((p) => p.trim())
    .filter(Boolean)
    .map((pair) => {
      const idx = pair.indexOf("=");
      if (idx <= 0) throw new Error(`Invalid PATH_MAP pair: ${pair}`);
      return { from: pair.slice(0, idx).replace(/\/+$/, ""), to: pair.slice(idx + 1).trim() };
    });
}

function mapPath(p, mappings) {
  for (const m of mappings) {
    if (p === m.from || p.startsWith(m.from + "/")) {
      const rest = p.slice(m.from.length);
      const joined = rest ? m.to.replace(/[\\/]+$/, "") + rest.replace(/\//g, "\\") : m.to;
      return joined;
    }
  }
  return p;
}

function resolveTokenFile() {
  return path.join(os.homedir(), ".unity-bridge", "token");
}

function savedPathMapFile() {
  return path.join(os.homedir(), ".unity-bridge", "path-map");
}

function loadSavedPathMap() {
  try {
    return fs.readFileSync(savedPathMapFile(), "utf8").trim();
  } catch {
    return "";
  }
}

function savePathMap(mapStr) {
  try {
    fs.mkdirSync(path.dirname(savedPathMapFile()), { recursive: true });
    fs.writeFileSync(savedPathMapFile(), mapStr + "\n");
  } catch {}
}

function ensureToken(opts) {
  if (opts.noToken) {
    console.warn("[bridge] WARNING: token auth disabled (--no-token)");
    return "";
  }
  if (opts.token) return opts.token;
  const file = resolveTokenFile();
  try {
    const existing = fs.readFileSync(file, "utf8").trim();
    if (existing) {
      opts.token = existing;
      console.log(`[bridge] Using existing token from ${file}`);
      return existing;
    }
  } catch {}
  opts.token = crypto.randomBytes(24).toString("hex");
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, opts.token + "\n", { mode: 0o600 });
  console.log(`[bridge] Generated new token at ${file}`);
  return opts.token;
}

function send(res, status, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(body),
    Connection: "close",
  });
  res.end(body);
}

function truncate(buf, label) {
  if (buf.length <= MAX_OUTPUT) return buf.toString("utf8");
  const half = Math.floor(MAX_OUTPUT / 2);
  return (
    buf.subarray(0, half).toString("utf8") +
    `\n[...${label} truncated (${buf.length - MAX_OUTPUT} bytes dropped)...]\n` +
    buf.subarray(buf.length - half).toString("utf8")
  );
}

function runUnity(payload, opts) {
  return new Promise((resolve) => {
    const started = Date.now();
      let child;
      let killed = false;
      let killTimer = null;

      const killTree = (signal) => {
        if (!child || child.exitCode !== null || child.signalCode !== null) return;
        try {
          // Negative pid targets the whole process group (POSIX); Windows kills just the child
          if (process.platform === "win32") child.kill(signal);
          else {
            if (child.pid && signal === "SIGTERM") process.kill(-child.pid, signal);
            else child.kill(signal);
          }
        } catch {}
      };

    const run = () => {
      const stdout = [];
      const stderr = [];
      let outLen = 0;
      let errLen = 0;

      child = spawn(opts.command, payload.args, {
        cwd: payload.cwd,
        shell: false,
        windowsHide: true,
        detached: process.platform !== "win32",
        stdio: ["ignore", "pipe", "pipe"],
      });

      const finish = (code, signal) => {
        if (killTimer) clearTimeout(killTimer);
        resolve({
          ok: code === 0,
          code: typeof code === "number" ? code : null,
          signal: signal || null,
          timedOut: killed,
          durationMs: Date.now() - started,
          stdout: truncate(Buffer.concat(stdout), "stdout"),
          stderr: truncate(Buffer.concat(stderr), "stderr"),
        });
      };

      let killTimer = null;

      child.stdout.on("data", (d) => {
        if (outLen < MAX_OUTPUT * 2) {
          stdout.push(d);
          outLen += d.length;
        }
      });
      child.stderr.on("data", (d) => {
        if (errLen < MAX_OUTPUT * 2) {
          stderr.push(d);
          errLen += d.length;
        }
      });
      child.on("error", (err) => {
        if (killTimer) clearTimeout(killTimer);
        resolve({
          ok: false,
          code: null,
          signal: null,
          timedOut: false,
          durationMs: Date.now() - started,
          stdout: "",
          stderr: `Failed to start '${opts.command}': ${err.message}\nSet UNITY_CLI_COMMAND or pass --command to the correct Unity CLI path.`,
        });
      });
      child.on("close", finish);

      if (payload.timeoutMs > 0) {
        killTimer = setTimeout(() => {
          killed = true;
          killTree("SIGTERM");
          setTimeout(() => killTree("SIGKILL"), KILL_GRACE_MS);
        }, payload.timeoutMs);
      }
    };

    // Empty string cwd -> run in the bridge's own working directory
    if (payload.cwd === "") payload.cwd = undefined;
    const requestedCwd = payload.cwd || opts.fallbackCwd || undefined;

    if (requestedCwd !== undefined) {
      try {
        fs.accessSync(requestedCwd, fs.constants.R_OK);
      } catch {
        return resolve({
          ok: false,
          code: null,
          signal: null,
          timedOut: false,
          durationMs: Date.now() - started,
          stdout: "",
          stderr:
            `Directory not found on host: ${requestedCwd}\n` +
            `Map container paths with --path-map "/workspace=C:\\path\\to\\project".`,
        });
      }
      payload.cwd = requestedCwd;
    }
    run();
  });
}

function main() {
  let opts;
  try {
    opts = parseArgs(process.argv.slice(2));
  } catch (e) {
    console.error(e.message);
    process.exit(2);
  }
  if (opts.help) {
    console.log(__filename.replace(/^.*[\\/]/, "") + " --port <n> --command <cmd> --token <t> --no-token --allow-cmds <list> --path-map <map>");
    process.exit(0);
  }

  ensureToken(opts);
  // Precedence: CLI flag > last runtime map > env
  opts.pathMap = opts.pathMap || loadSavedPathMap() || process.env.UNITY_PATH_MAP || "";
  opts.pathMappings = parsePathMap(opts.pathMap || "");
  // Per-session overrides (from safe-code) live in memory only; sessions
  // re-push at every launch and stale entries die with the bridge process.
  opts.sessionMaps = {};
  const allowedCmds =
    opts.allowCmds
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);

  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, "http://localhost");

    if (req.method === "GET" && url.pathname === "/health") {
      return send(res, 200, { status: "ok", command: opts.command, pid: process.pid });
    }

    if (req.method !== "POST" || !["/run", "/set-path-map"].includes(url.pathname)) {
      return send(res, 404, { error: "Not found" });
    }

    if (!opts.noToken) {
      const given = req.headers["x-unity-token"] || "";
      const valid =
        given.length === opts.token.length &&
        crypto.timingSafeEqual(Buffer.from(given), Buffer.from(opts.token));
      if (!valid) {
        console.log(`[bridge] 401 rejected request`);
        return send(res, 401, { error: "Invalid or missing x-unity-token header" });
      }
    }

    if (url.pathname === "/set-path-map") {
      let mapBody = "";
      req.on("data", (chunk) => {
        mapBody += chunk;
        if (mapBody.length > 64 * 1024) req.destroy();
      });
      req.on("end", () => {
        let body;
        try {
          body = JSON.parse(mapBody || "{}");
        } catch {
          return send(res, 400, { error: "Invalid JSON" });
        }
        const raw = typeof body.path === "string" ? body.path : null;
        const session = typeof body.session === "string" ? body.session : "";
        if (raw === null) {
          return send(res, 400, { error: 'Expected body {"path":"c=h;c2=h2","session":"s123456"}' });
        }
        if (session && !/^[A-Za-z0-9_-]{1,64}$/.test(session)) {
          return send(res, 400, { error: "Invalid session id" });
        }
        try {
          if (session) {
            opts.sessionMaps[session] = parsePathMap(raw);
          } else {
            opts.pathMappings = parsePathMap(raw);
            opts.pathMap = raw;
            savePathMap(raw);
          }
          console.log(`[bridge] path map set${session ? ` (session ${session})` : ""}: ${raw}`);
          return send(res, 200, { ok: true, pathMap: raw, session: session || undefined });
        } catch (e) {
          return send(res, 400, { error: e.message });
        }
      });
      return;
    }

    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 1024 * 1024) req.destroy();
    });
    req.on("end", async () => {
      let payload;
      try {
        payload = JSON.parse(body || "{}");
      } catch {
        return send(res, 400, { error: "Invalid JSON" });
      }

      const rawArgs = Array.isArray(payload.args) ? payload.args : [];
      const cwdRaw = typeof payload.cwd === "string" ? payload.cwd : "";
      const session =
        typeof payload.session === "string" && /^[A-Za-z0-9_-]{1,64}$/.test(payload.session)
          ? payload.session
          : "";
      const mappings = (session && opts.sessionMaps[session]) || opts.pathMappings;

      if (allowedCmds.length > 0 && rawArgs.length > 0 && !allowedCmds.includes(rawArgs[0])) {
        console.log(`[bridge] 403 denied command: ${rawArgs[0]}`);
        return send(res, 403, { error: `Command '${rawArgs[0]}' not allowed (UNITY_ALLOWED_CMDS)` });
      }

      const payloadMapped = {
        args: rawArgs.map((a) => String(a)),
        cwd: mapPath(cwdRaw, mappings),
        timeoutMs: Number.isFinite(payload.timeoutMs) ? Math.min(Math.max(payload.timeoutMs, 1000), 24 * 60 * 60 * 1000) : 30 * 60 * 1000,
      };

      console.log(
        `[bridge] run${session ? ` [${session}]` : ""}: ${(payloadMapped.args.join(" ") || "").slice(0, 200)}${payloadMapped.cwd ? ` (cwd=${payloadMapped.cwd})` : ""}`
      );
      const result = await runUnity(payloadMapped, opts);
      console.log(`[bridge] done: code=${result.code ?? result.signal} in ${(result.durationMs / 1000).toFixed(1)}s`);
      send(res, 200, result);
    });
  });

  server.listen(opts.port, "127.0.0.1", () => {
    console.log(`[bridge] Unity CLI bridge listening on http://127.0.0.1:${opts.port}`);
    console.log(`[bridge] Command: ${opts.command}`);
    if (opts.pathMappings.length) console.log(`[bridge] Path map: ${opts.pathMap}`);
    if (allowedCmds.length) console.log(`[bridge] Allowed commands: ${allowedCmds.join(", ")}`);
    console.log(`[bridge] Token: ${opts.noToken ? "DISABLED" : "(stored in ~/.unity-bridge/token)"}`);
  });
}

main();
