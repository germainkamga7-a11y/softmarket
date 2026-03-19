#!/usr/bin/env node
/**
 * Flutter MCP Server — CamerMarket project
 * Wraps Flutter CLI commands for use with Claude Code / AI agents.
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { execSync } from "child_process";
import { existsSync } from "fs";

const PROJECT_PATH =
  process.env.FLUTTER_PROJECT_PATH ||
  "C:\\Users\\germa\\Desktop\\projet\\softmarket";

const JAVA_HOME =
  process.env.JAVA_HOME ||
  "C:\\Program Files\\Android\\Android Studio\\jbr";

const BASE_ENV = {
  ...process.env,
  JAVA_HOME,
};

function runCmd(cmd, timeoutMs = 120000) {
  try {
    const output = execSync(cmd, {
      cwd: PROJECT_PATH,
      env: BASE_ENV,
      encoding: "utf8",
      timeout: timeoutMs,
      stdio: ["pipe", "pipe", "pipe"],
    });
    return { success: true, output: output || "Commande exécutée avec succès." };
  } catch (err) {
    const msg = [err.stdout, err.stderr, err.message]
      .filter(Boolean)
      .join("\n")
      .trim();
    return { success: false, output: msg || "Erreur inconnue." };
  }
}

function result(text, isError = false) {
  return { content: [{ type: "text", text }], isError };
}

// ─── Tool definitions ────────────────────────────────────────────────────────

const TOOLS = [
  {
    name: "flutter_analyze",
    description:
      "Lance flutter analyze sur le projet ou des fichiers spécifiques. " +
      "Retourne les erreurs et warnings Dart/Flutter.",
    inputSchema: {
      type: "object",
      properties: {
        files: {
          type: "array",
          items: { type: "string" },
          description:
            "Chemins de fichiers spécifiques à analyser (optionnel, défaut : lib/).",
        },
        fatal_infos: {
          type: "boolean",
          description: "Traiter les infos comme des erreurs fatales.",
        },
      },
    },
  },
  {
    name: "flutter_build",
    description:
      "Compile l'application Flutter pour une plateforme cible (web, apk, appbundle, windows).",
    inputSchema: {
      type: "object",
      required: ["target"],
      properties: {
        target: {
          type: "string",
          enum: ["web", "apk", "appbundle", "windows"],
          description: "Plateforme cible.",
        },
        release: {
          type: "boolean",
          description: "Mode release (défaut : true). false = debug.",
        },
        dart_defines_file: {
          type: "string",
          description:
            "Chemin vers un fichier dart-defines JSON (ex: dart-defines.json).",
        },
      },
    },
  },
  {
    name: "flutter_clean",
    description:
      "Supprime les artefacts de build Flutter (équivalent à flutter clean).",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "flutter_pub_get",
    description: "Lance flutter pub get pour récupérer/mettre à jour les dépendances.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "flutter_pub_outdated",
    description: "Affiche les packages Flutter qui ont des mises à jour disponibles.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "flutter_pub_upgrade",
    description:
      "Met à jour les dépendances Flutter dans les contraintes de version définies.",
    inputSchema: {
      type: "object",
      properties: {
        major_versions: {
          type: "boolean",
          description: "Inclure les mises à jour de version majeure.",
        },
      },
    },
  },
  {
    name: "flutter_test",
    description: "Lance les tests Flutter du projet.",
    inputSchema: {
      type: "object",
      properties: {
        path: {
          type: "string",
          description:
            "Fichier ou dossier de tests à lancer (défaut : test/).",
        },
        coverage: {
          type: "boolean",
          description: "Générer un rapport de couverture de code.",
        },
      },
    },
  },
  {
    name: "flutter_devices",
    description:
      "Liste les appareils/émulateurs disponibles pour lancer l'application Flutter.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "flutter_doctor",
    description:
      "Lance flutter doctor pour diagnostiquer l'environnement de développement.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "flutter_version",
    description: "Affiche la version de Flutter et Dart installée.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "flutter_gen_splash",
    description:
      "Régénère les écrans de démarrage (splash screens) via flutter_native_splash.",
    inputSchema: { type: "object", properties: {} },
  },
  {
    name: "flutter_gen_icons",
    description:
      "Régénère les icônes de l'application via flutter_launcher_icons.",
    inputSchema: { type: "object", properties: {} },
  },
];

// ─── Server setup ─────────────────────────────────────────────────────────────

const server = new Server(
  { name: "flutter-mcp", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args = {} } = request.params;

  switch (name) {
    // ── flutter analyze ───────────────────────────────────────────────────
    case "flutter_analyze": {
      const target =
        Array.isArray(args.files) && args.files.length > 0
          ? args.files.join(" ")
          : "lib/";
      const fatalFlag = args.fatal_infos ? " --fatal-infos" : "";
      const { success, output } = runCmd(
        `flutter analyze ${target}${fatalFlag}`
      );
      return result(output, !success);
    }

    // ── flutter build ─────────────────────────────────────────────────────
    case "flutter_build": {
      const modeFlag = args.release === false ? "--debug" : "--release";
      const target = args.target;
      let cmd = `flutter build ${target} ${modeFlag}`;
      if (target === "web") cmd += " --no-wasm-dry-run";
      if (args.dart_defines_file && existsSync(args.dart_defines_file)) {
        cmd += ` --dart-define-from-file=${args.dart_defines_file}`;
      } else if (
        existsSync(`${PROJECT_PATH}/dart-defines.json`)
      ) {
        cmd += " --dart-define-from-file=dart-defines.json";
      }
      const { success, output } = runCmd(cmd, 300000);
      return result(output, !success);
    }

    // ── flutter clean ─────────────────────────────────────────────────────
    case "flutter_clean": {
      const { success, output } = runCmd("flutter clean");
      return result(output, !success);
    }

    // ── flutter pub get ───────────────────────────────────────────────────
    case "flutter_pub_get": {
      const { success, output } = runCmd("flutter pub get");
      return result(output, !success);
    }

    // ── flutter pub outdated ──────────────────────────────────────────────
    case "flutter_pub_outdated": {
      const { success, output } = runCmd("flutter pub outdated");
      return result(output, !success);
    }

    // ── flutter pub upgrade ───────────────────────────────────────────────
    case "flutter_pub_upgrade": {
      const majorFlag = args.major_versions ? " --major-versions" : "";
      const { success, output } = runCmd(`flutter pub upgrade${majorFlag}`);
      return result(output, !success);
    }

    // ── flutter test ──────────────────────────────────────────────────────
    case "flutter_test": {
      const testPath = args.path || "test/";
      const covFlag = args.coverage ? " --coverage" : "";
      const { success, output } = runCmd(
        `flutter test ${testPath}${covFlag}`,
        180000
      );
      return result(output, !success);
    }

    // ── flutter devices ───────────────────────────────────────────────────
    case "flutter_devices": {
      const { success, output } = runCmd("flutter devices");
      return result(output, !success);
    }

    // ── flutter doctor ────────────────────────────────────────────────────
    case "flutter_doctor": {
      const { success, output } = runCmd("flutter doctor -v", 60000);
      return result(output, !success);
    }

    // ── flutter version ───────────────────────────────────────────────────
    case "flutter_version": {
      const { success, output } = runCmd("flutter --version");
      return result(output, !success);
    }

    // ── flutter gen splash ────────────────────────────────────────────────
    case "flutter_gen_splash": {
      const { success, output } = runCmd(
        "dart run flutter_native_splash:create"
      );
      return result(output, !success);
    }

    // ── flutter gen icons ─────────────────────────────────────────────────
    case "flutter_gen_icons": {
      const { success, output } = runCmd(
        "dart run flutter_launcher_icons"
      );
      return result(output, !success);
    }

    default:
      return result(`Outil inconnu : ${name}`, true);
  }
});

// ─── Start ───────────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
