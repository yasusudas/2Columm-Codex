#!/usr/bin/env node
"use strict";
var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  // If the importer is in node compatibility mode or this is not an ESM
  // file that has been converted to a CommonJS file using a Babel-
  // compatible transform (i.e. "__esModule" has not been set), then set
  // "default" to the CommonJS "module.exports" for node compatibility.
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
  mod
));

// server/src/providers/hook/claude/hooks/claude-hook.ts
var fs = __toESM(require("fs"));
var http = __toESM(require("http"));
var os = __toESM(require("os"));
var path = __toESM(require("path"));

// core/src/constants.ts
var HOOK_API_PREFIX = "/api/hooks";
var SERVER_JSON_DIR = ".pixel-agents-for-codex";
var SERVER_JSON_NAME = "server.json";

// server/src/providers/hook/claude/hooks/claude-hook.ts
var SERVER_JSON = path.join(os.homedir(), SERVER_JSON_DIR, SERVER_JSON_NAME);
async function main() {
  let input = "";
  for await (const chunk of process.stdin) input += chunk;
  let data;
  try {
    data = JSON.parse(input);
  } catch {
    process.exit(0);
  }
  let server;
  try {
    server = JSON.parse(fs.readFileSync(SERVER_JSON, "utf-8"));
  } catch {
    process.exit(0);
  }
  const body = JSON.stringify(data);
  return new Promise((resolve) => {
    const req = http.request(
      {
        hostname: "127.0.0.1",
        port: server.port,
        path: `${HOOK_API_PREFIX}/claude`,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(body),
          Authorization: `Bearer ${server.token}`
        },
        timeout: 2e3
      },
      () => resolve()
    );
    req.on("error", () => resolve());
    req.on("timeout", () => {
      req.destroy();
      resolve();
    });
    req.end(body);
  });
}
main().catch(() => {
}).finally(() => process.exit(0));
