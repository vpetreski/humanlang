import * as fs from "fs";
import * as path from "path";
import { execSync } from "child_process";

const scriptDir = __dirname === "." ? process.cwd() : __dirname;
const testsFile = path.resolve(scriptDir, "..", "tests.yaml");
const yaml = fs.readFileSync(testsFile, "utf-8");

interface TestCase {
  name: string;
  program: string;
  output: string;
}

function parseTests(yamlContent: string): TestCase[] {
  const tests: TestCase[] = [];
  const lines = yamlContent.split("\n");
  let i = 0;

  function readBlock(): string {
    let block = "";
    while (i < lines.length) {
      const bl = lines[i];
      if (/^\s{6}/.test(bl)) {
        block += bl.substring(6) + "\n";
        i++;
      } else if (bl.trim() === "") {
        // Empty line: include it if there are more indented lines after
        // (part of the YAML block scalar content)
        let j = i + 1;
        let hasMore = false;
        while (j < lines.length) {
          if (/^\s{6}/.test(lines[j])) { hasMore = true; break; }
          if (lines[j].trim() === "") { j++; continue; }
          break;
        }
        if (hasMore) {
          block += "\n";
          i++;
        } else {
          break;
        }
      } else {
        break;
      }
    }
    return block;
  }

  while (i < lines.length) {
    const line = lines[i];
    const nameMatch = line.match(/^\s*-\s*name:\s*"(.*)"/);
    if (nameMatch) {
      const test: TestCase = { name: nameMatch[1], program: "", output: "" };
      i++;

      while (i < lines.length) {
        const l = lines[i];
        if (/^\s*-\s*name:/.test(l)) break;
        if (l.trim() === "" || l.trim().startsWith("#")) {
          i++;
          continue;
        }

        if (/^\s*program:\s*\|\s*$/.test(l)) {
          i++;
          test.program = readBlock();
          continue;
        }

        if (/^\s*output:\s*\|\s*$/.test(l)) {
          i++;
          test.output = readBlock();
          continue;
        }

        i++;
      }

      tests.push(test);
      continue;
    }
    i++;
  }

  return tests;
}

const tests = parseTests(yaml);
let passed = 0;
let failed = 0;
const failures: string[] = [];

for (const test of tests) {
  const tmpFile = `/tmp/hl_test_${Date.now()}_${Math.random().toString(36).slice(2)}.hl`;
  fs.writeFileSync(tmpFile, test.program);

  let actual = "";
  try {
    actual = execSync(`npx tsx humanlang.ts "${tmpFile}"`, {
      cwd: scriptDir,
      encoding: "utf-8",
      timeout: 10000,
      stdio: ["pipe", "pipe", "pipe"],
    });
  } catch (e: any) {
    actual = e.stdout || "";
  }

  fs.unlinkSync(tmpFile);

  // Strip trailing whitespace/newlines for comparison (matches other implementations)
  const expected = test.output.replace(/\s+$/, "");
  const actualTrimmed = actual.replace(/\s+$/, "");
  if (actualTrimmed === expected) {
    console.log(`  PASS: ${test.name}`);
    passed++;
  } else {
    console.log(`  FAIL: ${test.name}`);
    failed++;
    const expRepr = JSON.stringify(expected).slice(0, 120);
    const actRepr = JSON.stringify(actualTrimmed).slice(0, 120);
    failures.push(`--- FAIL: ${test.name} ---\n  Expected: ${expRepr}\n  Actual:   ${actRepr}`);
  }
}

console.log("");
console.log("==============================");
console.log(`Results: ${passed} passed, ${failed} failed (out of ${tests.length} tests)`);
console.log("==============================");

if (failures.length > 0) {
  console.log("");
  console.log("Failed tests:");
  for (const f of failures) {
    console.log(f);
  }
  console.log("");
  process.exit(1);
}
