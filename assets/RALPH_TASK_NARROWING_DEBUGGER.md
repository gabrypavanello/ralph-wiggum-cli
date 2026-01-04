---
task: Build "ts-narrow" - A TypeScript Type Narrowing Debugger
completion_criteria:
  - CLI parses TypeScript files
  - Tracks type of a variable through control flow
  - Explains narrowing at each step
  - Handles if/else, typeof, instanceof, truthiness
  - Outputs human-readable explanation
  - Works on real-world examples
max_iterations: 30
---

# Task: Build "ts-narrow" - TypeScript Type Narrowing Debugger

Build a CLI tool that explains how TypeScript narrows types through control flow. When developers ask "why is this type X here?", this tool shows them step-by-step.

## The Problem

TypeScript's type narrowing is powerful but opaque. When narrowing doesn't work as expected, developers have no way to understand why. Error messages like "Type 'string | null' is not assignable to type 'string'" don't explain what went wrong.

## The Solution

A CLI that traces a variable through code and explains each narrowing step:

```bash
$ ts-narrow analyze src/example.ts --variable user --line 15
```

Output:
```
Tracing `user` in src/example.ts

Line 3:  const user: User | null = getUser()
         → Type: User | null

Line 5:  if (user) {
         → Narrowed by: truthiness check
         → Type: User (inside if block)
         → Eliminated: null (falsy)

Line 8:  if (user.role === 'admin') {
         → Narrowed by: equality check on discriminant
         → Type: AdminUser (inside if block)

Line 15: user.permissions
         → Final type: AdminUser
         → Property 'permissions' exists ✓
```

## Technical Approach

Use the TypeScript Compiler API to:
1. Parse the source file into an AST
2. Create a type checker instance
3. Walk the AST tracking control flow
4. At each narrowing point, record what happened
5. Generate human-readable explanations

## Success Criteria

### Phase 1: Basic Parsing & Type Extraction
1. [ ] CLI accepts a TypeScript file path
2. [ ] Parses file using TypeScript Compiler API
3. [ ] Can find a variable declaration by name
4. [ ] Can get the type of a variable at declaration

### Phase 2: Control Flow Tracking
5. [ ] Tracks variable through if/else blocks
6. [ ] Identifies narrowing points (if conditions)
7. [ ] Records type before and after each narrowing
8. [ ] Handles nested if/else correctly

### Phase 3: Narrowing Detection
9. [ ] Detects truthiness narrowing (`if (x)`)
10. [ ] Detects typeof narrowing (`if (typeof x === 'string')`)
11. [ ] Detects instanceof narrowing (`if (x instanceof Error)`)
12. [ ] Detects equality narrowing (`if (x === null)`)
13. [ ] Detects discriminated union narrowing (`if (x.kind === 'a')`)

### Phase 4: Output & Explanation
14. [ ] Generates step-by-step trace output
15. [ ] Explains what caused each narrowing
16. [ ] Shows what types were eliminated
17. [ ] Highlights the final type at target line
18. [ ] Handles "type not narrowed" cases with explanation

### Phase 5: Edge Cases & Polish
19. [ ] Works with type aliases and interfaces
20. [ ] Handles function parameters
21. [ ] Works with optional chaining (`x?.foo`)
22. [ ] Provides helpful error for invalid inputs
23. [ ] Has --json output option for tooling

## Example Test Cases

### Test 1: Basic Truthiness
```typescript
// test/truthiness.ts
function example(x: string | null) {
  if (x) {
    console.log(x.toUpperCase()) // x is string here
  }
}
```

Expected output for `ts-narrow analyze test/truthiness.ts --variable x --line 4`:
```
Line 1: function example(x: string | null)
        → Type: string | null (parameter)

Line 2: if (x) {
        → Narrowed by: truthiness check
        → Type: string
        → Eliminated: null (falsy)

Line 3: x.toUpperCase()
        → Final type: string ✓
```

### Test 2: typeof Guard
```typescript
// test/typeof.ts
function process(value: string | number) {
  if (typeof value === 'string') {
    return value.toUpperCase()
  }
  return value.toFixed(2)
}
```

### Test 3: Discriminated Union
```typescript
// test/discriminated.ts
type Result = 
  | { ok: true; data: string }
  | { ok: false; error: Error }

function handle(result: Result) {
  if (result.ok) {
    console.log(result.data) // result is { ok: true; data: string }
  } else {
    console.log(result.error) // result is { ok: false; error: Error }
  }
}
```

### Test 4: No Narrowing (Negative Case)
```typescript
// test/no-narrow.ts
function broken(x: string | null) {
  const y = x // y is still string | null
  if (x) {
    console.log(y.toUpperCase()) // ERROR: y wasn't narrowed!
  }
}
```

Expected: Tool should explain that `y` was not narrowed because the check was on `x`, not `y`.

## File Structure

```
ts-narrow/
├── src/
│   ├── index.ts          # CLI entry point
│   ├── parser.ts         # TypeScript parsing utilities
│   ├── analyzer.ts       # Control flow analysis
│   ├── narrowing.ts      # Narrowing detection logic
│   ├── formatter.ts      # Output formatting
│   └── types.ts          # Internal type definitions
├── test/
│   ├── truthiness.ts
│   ├── typeof.ts
│   ├── discriminated.ts
│   └── no-narrow.ts
├── package.json
├── tsconfig.json
└── README.md
```

## Dependencies

- `typescript` (for Compiler API) - this is the ONLY external dependency
- Node.js built-ins only otherwise

## Constraints

- Must use TypeScript Compiler API (not regex/string parsing)
- No external dependencies except `typescript` itself
- Must handle real-world TypeScript (not toy examples only)
- Output must be human-readable, not just type dumps

---

## Ralph Instructions

1. Work through phases in order - don't skip ahead
2. Each criterion should have a working test before moving on
3. Commit after completing each criterion
4. If stuck on TypeScript Compiler API, read the docs at:
   https://github.com/microsoft/TypeScript/wiki/Using-the-Compiler-API
5. The `ts.TypeChecker` and `ts.Type` APIs are your friends
6. When ALL criteria are [x], say: `RALPH_COMPLETE: All criteria satisfied`
7. If stuck on same issue 3+ times, say: `RALPH_GUTTER: Need fresh context`
