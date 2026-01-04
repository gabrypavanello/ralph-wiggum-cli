---
task: Build "throwlens" - TypeScript Error Provenance Analyzer
test_command: "npm test"
completion_criteria:
  - Core analysis layer working
  - Call graph construction
  - Throw path tracing
  - Confidence/soundness bands
  - Boundary detection
  - CLI adapter
  - All test assertions pass
max_iterations: 100
---

# Task: Build "throwlens" - TypeScript Error Provenance Analyzer

A static analyzer that answers the question every developer asks: **"What can this function throw, and where does it come from?"**

## The One-Line Success Criterion

For any function, throwlens must answer:
1. What can this throw?
2. Where is the nearest concrete throw site?
3. What's the minimal path that proves it?
4. Where would it be caught (if anywhere)?
5. Where does certainty degrade to unknown?

If you ship that, people at Cursor/Vercel will do the quiet "oh… damn" thing.

---

## Architecture (Do Not Deviate)

Split into 3 layers from day 1:

```
┌─────────────────────────────────────────────────────────────┐
│                        ADAPTERS                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │     CLI     │  │     LSP     │  │    JSON Export      │  │
│  │  (build)    │  │  (future)   │  │    (build)          │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                         ENGINE                               │
│  - Cache keyed by file hash + symbol ID                     │
│  - Supports analyzeChangedFiles([...])                      │
│  - Incremental-friendly                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                          CORE                                │
│  - Input: TS Program + Config                               │
│  - Output: ThrowGraph + FunctionSummaries + Paths           │
│  - PURE: No CLI, no VSCode, no side effects                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Core Data Types

### Confidence Bands (Soundness)

```typescript
type Confidence = "certain" | "likely" | "possible" | "unknown";

type ConfidenceReason =
  | "explicit-throw"      // throw new Error()
  | "await-reject"        // await might reject
  | "untyped-boundary"    // calls untyped/any function
  | "dynamic-call"        // fn(), obj[key]()
  | "external-module"     // node_modules call
  | "callback-inference"; // inferred from callback usage

interface ThrowInfo {
  type: string;                    // Error type name
  confidence: Confidence;
  reason: ConfidenceReason;
  location: SourceLocation;
}
```

### Throw Paths

```typescript
type PathKind = "witness" | "summary";
// witness = concrete throw site exists in analyzed code
// summary = inferred via unknown boundary (e.g., external call)

interface ThrowPath {
  kind: PathKind;
  errorType: string;
  frames: PathFrame[];
  caughtAt: SourceLocation | null;  // null = uncaught
}

interface PathFrame {
  function: string;
  location: SourceLocation;
  action: "calls" | "throws" | "awaits" | "catches" | "rethrows";
}
```

### Function Summary

```typescript
interface FunctionSummary {
  name: string;
  location: SourceLocation;
  throws: ThrowInfo[];
  paths: ThrowPath[];
  isBoundary: boolean;
  boundaryKind?: "export" | "handler" | "entrypoint";
}
```

---

## Boundary Detection

### Default Boundaries

1. **Exported functions**: `export function`, `export const fn =`
2. **Framework handlers** (detect by signature pattern):
   - Next.js: `export default function handler(req, res)`
   - Express: `(req, res, next) => ...`
3. **CLI entrypoints**: `bin` in package.json, `commander.action()`

### Configuration File (`throwlens.config.json`)

```json
{
  "boundaries": ["src/api/**", "src/pages/api/**"],
  "ignore": ["**/*.test.ts", "**/__mocks__/**"],
  "treatUnknownAs": "warning",
  "presets": ["nextjs"],
  "external": {
    "node_modules": "unknown",
    "allowlist": ["@vercel/postgres"]
  }
}
```

---

## Success Criteria

### Phase 1: Core Foundation (Pure Layer)
1. [ ] Parse TypeScript files using Compiler API
2. [ ] Find all `throw` statements with their error types
3. [ ] Build call graph for analyzed files
4. [ ] Create FunctionSummary for each function
5. [ ] Core is pure: no I/O, no CLI, just data in → data out

### Phase 2: Throw Path Tracing
6. [ ] Trace throws through call graph (single level)
7. [ ] Trace throws through multiple call levels (3+ deep)
8. [ ] Assign confidence levels based on ConfidenceReason
9. [ ] Distinguish witness vs summary paths
10. [ ] Handle direct throws: `throw new Error()`
11. [ ] Handle typed throws: `throw new CustomError()`

### Phase 3: Boundary & Catch Detection
12. [ ] Detect try/catch blocks
13. [ ] Track which throws are caught at which location
14. [ ] Detect re-throws: `catch (e) { throw e }`
15. [ ] Detect error wrapping: `catch (e) { throw new WrapperError(e) }`
16. [ ] Identify boundary functions (exports, handlers)
17. [ ] Report "uncaught at boundary" correctly

### Phase 4: Async Handling
18. [ ] Treat `await` as potential throw site
19. [ ] `await` inside try/catch catches rejections
20. [ ] Handle Promise.reject() as throw
21. [ ] Handle async function implicit rejection
22. [ ] Trace through async call chains

### Phase 5: Engine Layer (Incremental)
23. [ ] Cache analysis results by file hash
24. [ ] Support analyzeChangedFiles() for incremental updates
25. [ ] Symbol ID stability across minor edits

### Phase 6: CLI Adapter
26. [ ] `throwlens analyze <path>` - analyze files/directory
27. [ ] `throwlens analyze --function <name>` - analyze specific function
28. [ ] `--output json` - machine-readable output
29. [ ] `--output pretty` - human-readable terminal output
30. [ ] `--config <path>` - use config file
31. [ ] Exit code 1 if uncaught throws at boundaries, 0 otherwise

### Phase 7: Edge Cases & Polish
32. [ ] Conditional throws: `if (x) throw new Error()`
33. [ ] Throws in callbacks/closures
34. [ ] Generic error handling: `catch (e: unknown)`
35. [ ] External calls marked as "unknown" confidence
36. [ ] Helpful error messages for invalid inputs

---

## MANDATORY TEST CASES

### Test 1: Basic Throw Detection
```typescript
// test/fixtures/basic-throw.ts
export function willThrow(): never {
  throw new Error("always throws");
}
```

**Command:** `throwlens analyze test/fixtures/basic-throw.ts --output json`

**REQUIRED in output:**
- Function `willThrow` has throws array with length 1
- Throw type is "Error"
- Confidence is "certain"
- Reason is "explicit-throw"

---

### Test 2: Call Graph Tracing (2 levels)
```typescript
// test/fixtures/two-level.ts
function inner(): void {
  throw new ValidationError("invalid");
}

export function outer(): void {
  inner();
}
```

**Command:** `throwlens analyze test/fixtures/two-level.ts --function outer --output json`

**REQUIRED:**
- `outer` throws `ValidationError`
- Path has 2 frames: `outer` → `inner`
- Path kind is "witness"
- Confidence is "certain"

---

### Test 3: Call Graph Tracing (3+ levels)
```typescript
// test/fixtures/deep-call.ts
function level3(): void {
  throw new DeepError("deep");
}

function level2(): void {
  level3();
}

function level1(): void {
  level2();
}

export function entrypoint(): void {
  level1();
}
```

**Command:** `throwlens analyze test/fixtures/deep-call.ts --function entrypoint --output json`

**REQUIRED:**
- `entrypoint` throws `DeepError`
- Path has 4 frames: `entrypoint` → `level1` → `level2` → `level3`
- All frames present in correct order

---

### Test 4: Try/Catch Handling
```typescript
// test/fixtures/caught.ts
function mayThrow(): void {
  throw new Error("maybe");
}

export function catcher(): string {
  try {
    mayThrow();
    return "ok";
  } catch (e) {
    return "caught";
  }
}
```

**Command:** `throwlens analyze test/fixtures/caught.ts --function catcher --output json`

**REQUIRED:**
- `catcher` has throws array with length 0 (all caught)
- OR throws array shows `caughtAt` is not null

---

### Test 5: Re-throw Detection
```typescript
// test/fixtures/rethrow.ts
function inner(): void {
  throw new OriginalError("original");
}

export function rethrows(): void {
  try {
    inner();
  } catch (e) {
    throw e; // re-throw
  }
}
```

**Command:** `throwlens analyze test/fixtures/rethrow.ts --function rethrows --output json`

**REQUIRED:**
- `rethrows` throws `OriginalError`
- Path shows the re-throw

---

### Test 6: Error Wrapping
```typescript
// test/fixtures/wrap.ts
function inner(): void {
  throw new LowLevelError("low");
}

export function wraps(): void {
  try {
    inner();
  } catch (e) {
    throw new HighLevelError("wrapped", { cause: e });
  }
}
```

**Command:** `throwlens analyze test/fixtures/wrap.ts --function wraps --output json`

**REQUIRED:**
- `wraps` throws `HighLevelError` (the wrapper)
- `LowLevelError` is marked as handled/wrapped at catch site

---

### Test 7: Async/Await
```typescript
// test/fixtures/async.ts
async function fetchData(): Promise<string> {
  throw new NetworkError("failed");
}

export async function handler(): Promise<void> {
  const data = await fetchData();
  console.log(data);
}
```

**Command:** `throwlens analyze test/fixtures/async.ts --function handler --output json`

**REQUIRED:**
- `handler` throws `NetworkError`
- Path shows `await` as the propagation point

---

### Test 8: Async with Try/Catch
```typescript
// test/fixtures/async-caught.ts
async function fetchData(): Promise<string> {
  throw new NetworkError("failed");
}

export async function safeHandler(): Promise<string> {
  try {
    return await fetchData();
  } catch (e) {
    return "fallback";
  }
}
```

**Command:** `throwlens analyze test/fixtures/async-caught.ts --function safeHandler --output json`

**REQUIRED:**
- `safeHandler` has no uncaught throws
- `NetworkError` is caught

---

### Test 9: Unknown Boundary (External Call)
```typescript
// test/fixtures/external.ts
import { readFile } from "fs/promises";

export async function readConfig(): Promise<string> {
  return await readFile("config.json", "utf-8");
}
```

**Command:** `throwlens analyze test/fixtures/external.ts --function readConfig --output json`

**REQUIRED:**
- `readConfig` has throws with confidence "unknown" or "possible"
- Reason is "external-module"
- Path kind is "summary" (not witness)

---

### Test 10: Boundary Detection
```typescript
// test/fixtures/boundary.ts
function internal(): void {
  throw new Error("internal");
}

export function publicApi(): void {
  internal();
}

function alsoInternal(): void {
  internal();
}
```

**Command:** `throwlens analyze test/fixtures/boundary.ts --output json`

**REQUIRED:**
- `publicApi` is marked as boundary (isBoundary: true)
- `internal` and `alsoInternal` are NOT boundaries
- Report shows uncaught throw at `publicApi` boundary

---

## File Structure

```
throwlens/
├── src/
│   ├── core/
│   │   ├── index.ts           # Core exports
│   │   ├── types.ts           # All type definitions
│   │   ├── parser.ts          # TS parsing utilities
│   │   ├── call-graph.ts      # Call graph construction
│   │   ├── throw-finder.ts    # Find throw statements
│   │   ├── path-tracer.ts     # Trace throw paths
│   │   ├── catch-analyzer.ts  # Try/catch analysis
│   │   └── boundary.ts        # Boundary detection
│   ├── engine/
│   │   ├── index.ts           # Engine exports
│   │   ├── cache.ts           # File hash caching
│   │   └── incremental.ts     # Incremental analysis
│   ├── adapters/
│   │   ├── cli.ts             # CLI implementation
│   │   └── json.ts            # JSON output formatter
│   └── index.ts               # Main entry
├── test/
│   ├── fixtures/              # Test TypeScript files
│   │   ├── basic-throw.ts
│   │   ├── two-level.ts
│   │   ├── deep-call.ts
│   │   ├── caught.ts
│   │   ├── rethrow.ts
│   │   ├── wrap.ts
│   │   ├── async.ts
│   │   ├── async-caught.ts
│   │   ├── external.ts
│   │   └── boundary.ts
│   └── run-tests.js           # Test runner
├── package.json
├── tsconfig.json
└── README.md
```

## Dependencies

- `typescript` (Compiler API) - ONLY external dependency for core
- `commander` (CLI parsing) - for CLI adapter only
- Node.js built-ins

## Constraints

- **Core must be pure** - No I/O, no side effects, just analysis
- **Tests must assert on exact output** - Not "does it run"
- **Confidence must be explicit** - Never claim certainty you don't have
- **Paths must be traceable** - Every throw needs a path to its source
- **Task is NOT complete until `npm test` exits with code 0**

---

## Traps to Avoid

1. **Don't explode on node_modules** - Default: analyze only project files, treat external as "unknown"
2. **Don't over-claim** - If you can't prove it, mark confidence appropriately
3. **Don't ignore async** - `await` is a throw site, treat it as such
4. **Don't forget re-throws** - `catch (e) { throw e }` propagates the original error

---

## Ralph Instructions

1. Build Phase 1 first - get core working before CLI
2. **Run `npm test` after EVERY change**
3. Confidence bands are NOT optional - implement from the start
4. If tests fail, read the failure and fix
5. Commit after each phase
6. When ALL criteria are [x] AND `npm test` passes: `RALPH_COMPLETE`
7. If stuck on same issue 3+ times: `RALPH_GUTTER`
