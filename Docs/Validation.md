# Public validation guide

This guide separates published test definitions, historical reports and checks reproduced during the documentation repair on **2026-10-15 (UTC)**. The audited source baseline is [public snapshot `21bdf92107c59bb3cd1734a2dadcdc7ec0289f24`](https://github.com/utkarsh-n/CircuitToy/tree/21bdf92107c59bb3cd1734a2dadcdc7ec0289f24). The repair changes documentation only.

## Evidence status

| Claim or check | Accessible evidence | Status |
| --- | --- | --- |
| 54 lessons in 12 modules, with 33 advanced destinations | [CurriculumData.swift](../App/CurriculumData.swift), [LessonCatalog.swift](../App/LessonCatalog.swift), [CurriculumTests.swift](../Tests/AdvancedModelsTests/CurriculumTests.swift) | Counts reproduced by source inspection. Runtime routing and native rendering were not rerun. |
| 187 pure Swift tests, zero failures | The baseline README reports that outcome; [Package.swift](../Package.swift) and the test files below define the suite | **Historical outcome, not independently reproduced.** Source inventory confirms 187 declared test functions, not 187 passes. No corresponding public test log or result bundle is included. |
| Two nonlinear native workflows passed on iPhone 15 Pro Max | Historical README report; [BreadboardUITests.swift](../Tests/NativeLessonTests/BreadboardUITests.swift) contains the workflow definitions | **Historical outcome, not independently reproduced.** No public phone captures or device-run results accompany it. |
| Version 0.4.0 (5) installed and launched | Historical README report; [project.yml](../project.yml) declares the version/build | Version metadata is inspectable. Installation and launch were not reproduced; metadata does not prove delivery. |
| Published Markdown links resolve locally | Relative-link audit below, covering README, Docs, Design and PUBLICATION | Reproduced after the repair: no missing relative file targets. This does not validate external URLs or runtime behavior. |
| Model suite, native build and UI suite in this repair environment | Linux x86_64; `swift`, `xcodebuild` and `xcodegen` absent from PATH | **Not run.** No compiler, numerical-solver execution, simulator or physical-device pass is claimed. |

[PUBLICATION.md](../PUBLICATION.md) remains applicable: publication review does not certify that this snapshot builds or runs. Historical reports lack the original command output, exact toolchain versions and run identifiers needed for a fully reproducible run record. This guide supplies public experiments and commands for a new run; it does not reconstruct excluded diagnostics or media.

## Public test inventory

These are source counts at the audited baseline, obtained by counting `@Test func` declarations and XCTest `func test…` methods. They are not runner-discovered counts, assertion counts or results. Some functions iterate over many inputs.

| SwiftPM target | Declared tests | Public coverage |
| --- | ---: | --- |
| CircuitCoreTests | 90 | [Linear/DC and transient solver (18)](../Tests/CircuitCoreTests/CircuitSolverTests.swift), [logic (10)](../Tests/CircuitCoreTests/LogicTests.swift), [breadboard (23)](../Tests/CircuitCoreTests/BreadboardTests.swift), [nonlinear devices (20)](../Tests/CircuitCoreTests/NonlinearDeviceTests.swift), [nonlinear breadboard (19)](../Tests/CircuitCoreTests/NonlinearBreadboardTests.swift) |
| ScientificModelsTests | 12 | [Shockley, amplifier rails, sampling aliases, feedback, electrostatics, AM and AC power](../Tests/ScientificModelsTests/ScientificModelsTests.swift) |
| AdvancedModelsTests | 68 | [Foundations (24)](../Tests/AdvancedModelsTests/FoundationsModelsTests.swift), [systems (14)](../Tests/AdvancedModelsTests/SystemsModelsTests.swift), [engineering (22)](../Tests/AdvancedModelsTests/EngineeringModelsTests.swift), [practice (6)](../Tests/AdvancedModelsTests/PracticeModelsTests.swift), [curriculum (2)](../Tests/AdvancedModelsTests/CurriculumTests.swift) |
| BreadboardStoreTests | 17 | [Store edits, transient state and persistence (12)](../Tests/BreadboardStoreTests/BreadboardStoreTests.swift), [nonlinear store behavior (5)](../Tests/BreadboardStoreTests/NonlinearStoreTests.swift) |
| **SwiftPM total** | **187** | Model/store tests only |
| CircuitToyUITests (Xcode, separate) | 11 | [Lesson workflows (5)](../Tests/NativeLessonTests/NativeLessonTests.swift), [breadboard workflows (6)](../Tests/NativeLessonTests/BreadboardUITests.swift) |

## Environment and test commands

Run commands from the repository root. [Package.swift](../Package.swift) declares Swift tools version **6.0**, macOS **15+** and iOS **27.0**. The model package has no external package dependencies; it uses Foundation, Observation, XCTest and Swift Testing. A macOS 15+ host with a Swift 6 toolchain is the declared host setup for the complete SwiftPM suite. It needs neither XcodeGen, an iOS simulator nor device signing. Linux compatibility was not established by this audit.

```sh
git rev-parse HEAD
sw_vers
swift --version
swift test
```

The suite mixes XCTest and Swift Testing. Preserve both runner summaries and the exit status; a single runner's subtotal is not the full suite. Do not use `--skip-build` for a clean reproduction. The README's custom-cache command is an optional alternative for hosts with specific cache/sandbox constraints.

Targeted experiments below use the existing test names. They still build the package before filtering tests:

```sh
swift test --filter dividerObeysOhmKirchhoffAndPowerLaws
swift test --filter capacitorBackwardEulerMatchesDiscreteAnalyticSolution
swift test --filter capacitorTransientConvergesAsTimeStepShrinks
swift test --filter resistorDiodeLoadLineMatchesIndependentBisectionAndReversal
swift test --filter nonlinearDiodeCapacitorStepSatisfiesIndependentBackwardEulerEquation
swift test --filter nonlinearBreadboardFollowerRespectsOutputCurrentLimitUnderHeavyLoad
swift test --filter ScientificModelsTests
swift test --filter CurriculumTests
```

### Native build and UI tests

The app and UI tests require macOS with **Xcode 27**, the iOS **27 SDK**, a compatible installed iPhone simulator runtime, and **XcodeGen**, as declared by [project.yml](../project.yml) and the original README. Those tools were not available in the repair environment. A SwiftPM model pass does not compile the app's SwiftUI views. Physical-device use additionally requires your Apple signing team and a connected, unlocked compatible iPhone.

```sh
xcodebuild -version
xcodegen --version
xcrun simctl list devices available
xcodegen generate
xcodebuild -project CircuitToy.xcodeproj -scheme CircuitToy \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/CircuitToy-iOSBuild \
  CODE_SIGNING_ALLOWED=NO build
```

For UI tests, select a concrete iPhone simulator UDID from `simctl` output. A generic build destination cannot execute UI tests. Replace the example value before running; use a fresh result-bundle path on each run:

```sh
SIMULATOR_UDID='REPLACE_WITH_AVAILABLE_IPHONE_SIMULATOR_UDID'
xcodebuild -project CircuitToy.xcodeproj -scheme CircuitToy \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -derivedDataPath /private/tmp/CircuitToy-iOSBuild \
  -resultBundlePath /private/tmp/CircuitToy-UI-Results.xcresult \
  CODE_SIGNING_ALLOWED=NO test
```

The generated scheme includes `CircuitToyUITests`, not the four SwiftPM test targets. Run both commands for both layers of coverage. Review [the native lesson tests](../Tests/NativeLessonTests/NativeLessonTests.swift) for the 33 advanced destinations and [the breadboard UI tests](../Tests/NativeLessonTests/BreadboardUITests.swift) for editing, logic, transient and nonlinear workflows. Test definitions describe intended checks; they do not establish that the workflows passed on this snapshot.

## Reproducible model experiments

The values below are **analytical expectations or assertions in published tests**, not newly measured solver output. Execute the named tests above to compare CircuitToy against them. Quantities use SI units; `V(a) − V(b)` is branch voltage, current is positive `a → b`, and positive power is absorbed. For multi-terminal devices, currents are positive into each terminal and power is `Σ Vterminal Iterminal`.

### 1. DC divider: independent analytical and conservation checks

Source: [CircuitPresets.swift](../Sources/CircuitCore/CircuitPresets.swift), [CircuitSolver.swift](../Sources/CircuitCore/CircuitSolver.swift). Test: `dividerObeysOhmKirchhoffAndPowerLaws` in [CircuitSolverTests.swift](../Tests/CircuitCoreTests/CircuitSolverTests.swift).

The test calls `CircuitPresets.voltageDivider(supplyVolts: 9, topOhms: 1_000, bottomOhms: 2_000)`. Ground is node 0, supply is node 1, midpoint is node 2. From series resistance and KCL:

- `V2 = 9 × 2000 / (1000 + 2000) = 6 V`.
- Both resistor currents are `3 mA`; the supply branch current is `−3 mA` with its defined terminal orientation.
- R1 absorbs `9 mW`, R2 absorbs `18 mW`, and the supply delivers `27 mW`.

The test's value helper checks `|actual − expected| ≤ 1e−10 × max(1, |expected|)`. It also requires maximum KCL residual below `1e−12 A` and absolute power balance below `1e−12 W`. These are fixture-specific assertions, not a universal solver accuracy specification. The adjacent tests cover bridge symmetry, tiny conductance, reversed pins, floating nodes, and contradictory versus redundant sources.

### 2. RC transient: discrete identity and timestep convergence

Source: `TransientSimulator` in [CircuitSolver.swift](../Sources/CircuitCore/CircuitSolver.swift). Tests: `capacitorBackwardEulerMatchesDiscreteAnalyticSolution` and `capacitorTransientConvergesAsTimeStepShrinks` in [CircuitSolverTests.swift](../Tests/CircuitCoreTests/CircuitSolverTests.swift).

Use `Vs = 5 V`, `R = 1000 Ω`, `C = 0.001 F`, `Vc(0) = 0 V`; hence `τ = RC = 1 s`. Backward Euler gives:

```text
Vc[n] = 5 × (1 − (1 + h/τ)^(−n))
Vc_exact(t) = 5 × (1 − exp(−t/τ))
```

The discrete-identity test compares all 40 steps at `h = 0.05 s`, including KCL and power residuals. The convergence test compares 10 steps at `h = 0.1 s` with 100 steps at `h = 0.01 s`, both ending at `t = τ`. The exact reference is about `3.160602794 V`; the test requires the fine-step absolute error to be less than one eighth of the coarse error. Matching the discrete identity alone would not prove closeness to the continuous solution; this second check addresses timestep error.

Separate RL and passive LC tests check the inductor recurrence and non-increasing discrete LC energy. Backward Euler is first-order and dissipative; it does not exactly conserve an ideal LC oscillator's continuous energy. Initial conditions are explicit, and the Board has no solved probe sample at `t = 0` before stepping.

### 3. Nonlinear diode: independent load-line root and a transient step

Source: [NonlinearModels.swift](../Sources/CircuitCore/NonlinearModels.swift) and [CircuitSolver.swift](../Sources/CircuitCore/CircuitSolver.swift). Tests: `resistorDiodeLoadLineMatchesIndependentBisectionAndReversal` and `nonlinearDiodeCapacitorStepSatisfiesIndependentBackwardEulerEquation` in [NonlinearDeviceTests.swift](../Tests/CircuitCoreTests/NonlinearDeviceTests.swift).

The DC fixture is a 5 V source, 1 kΩ resistor and default silicon diode to ground, with `Is = 1e−12 A`, `n = 1`, `T = 300 K`, `Rs = 0`. Its reference solves:

```text
Vt = kT/q ≈ 0.025852 V
Is × expm1(Vd/Vt) = (5 − Vd)/1000
```

The test brackets `Vd` between 0 and 5 V and performs 100 bisections independently of the circuit solver. It compares both solved voltage and diode current against that root, rather than assuming a fixed 0.7 V drop. Its helper tolerance is `1e−9 × max(|expected|, 1e−12)`. Its conservation helper checks node KCL below `1e−9 A`, power balance below `1e−8 W`, and each device's terminal-current sum below `1e−12 A`.

The transient fixture has a diode and `1 µF` capacitor in parallel, initially at `0.2 V`, driven by a constant current source. Choose `h = 0.001 s` and compute the input current as `C(0.5 − 0.2)/h + Is × expm1(0.5/Vt)`. Then the independent backward-Euler equation predicts the first solved voltage as `0.5 V` and capacitor current as `0.0003 A`. The test checks both and rejects a zero timestep without advancing state. This checks a quasistatic junction coupled to stored capacitor energy; it does not model junction charge storage.

### 4. Powered op-amp: real load and supply-current accounting

Source: [OpAmpModel](../Sources/CircuitCore/NonlinearModels.swift), the follower preset in [Breadboard.swift](../Sources/CircuitCore/Breadboard.swift), and [NonlinearBreadboardTests.swift](../Tests/CircuitCoreTests/NonlinearBreadboardTests.swift).

`nonlinearBreadboardFollowerUsesFiveTerminalsAndSupplyInclusivePower` uses 0/5 V supply rails, a 2.5 V input and a 1 kΩ load. It expects output within `0.001 V` of the input, zero input currents, negative output-terminal current when delivering power, and positive current entering the positive supply terminal. All five terminals participate in power accounting.

`nonlinearBreadboardFollowerRespectsOutputCurrentLimitUnderHeavyLoad` changes the load to `10 Ω`. With the default `20 mA` output limit, it requires `0 < Vout ≤ 0.20001 V` and output-current magnitude at most `0.0200001 A`; a nominal 2.5 V reading under this load would fail. The breadboard helper checks KCL below `1e−8 A`, total power imbalance below `1e−7 W`, and terminal-current sums below `1e−8 A`. Other tests cover unpowered devices, input common-mode violations, output overdrive and persisted parameter profiles.

The guided ideal inverting-amplifier lesson in [ScientificModels.swift](../App/ScientificModels.swift) is a different model with hard rails. Its tests are not a substitute for checking the powered five-terminal breadboard device.

### 5. Scientific identities, advanced models and curriculum coverage

Run `swift test --filter ScientificModelsTests` to check, among other identities, signed aliases that preserve every original sample, inverse-square field versus inverse-distance potential, proportional-feedback time constants, and `S² = P² + Q²` with reactive-power sign. These use [ScientificModels.swift](../App/ScientificModels.swift); parameters and tolerances are visible in [the tests](../Tests/ScientificModelsTests/ScientificModelsTests.swift).

The [foundation](FoundationExperiments.md), [systems](SystemsExperiments.md), [engineering](EngineeringExperiments.md) and [practice](PracticeExperiments.md) specifications link assumptions to the advanced models. Their test files in the inventory add independent quadrature/derivatives, RLC damping regimes, Parseval's identity, Riccati/observer relations, exhaustive Hamming single-error correction, transformer/motor energy accounting, ADC bounds and thermal-capstone conservation. Passing these bounded fixtures would not establish arbitrary circuit correctness or physical calibration.

Run `swift test --filter CurriculumTests` for the declared 54 unique lessons and 33 advanced routes, nonempty teaching metadata and ordered prerequisites. It verifies metadata; the separate UI suite is needed to check native navigation and visible controls.

## Numerical specifications and limits

[CircuitSolver.swift](../Sources/CircuitCore/CircuitSolver.swift) uses modified nodal analysis with equilibrated complete-pivot Gaussian elimination. The nonlinear solve uses device derivatives, damped Newton steps and at most 200 iterations. Acceptance checks both scaled equation residuals and a small voltage correction; it does not declare convergence solely because junction leakage currents are small. Invalid, floating, singular, inconsistent, out-of-range and nonconvergent cases produce typed errors rather than fabricated readings. See [Circuit.swift](../Sources/CircuitCore/Circuit.swift) for error definitions and [Breadboard.md](Breadboard.md) for the complete electrical/interaction contract.

The model and test tolerances are distinct. Neither a tiny equation residual nor one passing fixture is a global error bound. Fixed-step backward Euler requires timestep refinement. Generic Shockley, Ebers–Moll and square-law devices omit breakdown, self-heating and charge-storage dynamics; the quasistatic op-amp omits bandwidth and slew. Logic states are ideal 0/1/X/Z, with no implicit analog thresholds or electrical fanout limits. These checks do not constitute manufacturer-part validation, a SPICE cross-simulator benchmark, hardware certification or assessed learner mastery.

## Documentation audit and replacements

The original README had ten distinct missing targets (one preview was linked twice). [Breadboard.md](Breadboard.md) also linked to the absent validation page. The repair uses public source/specifications as evidence, without presenting them as screenshots or retrieving excluded material.

| Missing README target at the baseline | Public replacement |
| --- | --- |
| `Docs/Validation.md` | This guide, with evidence status and runnable checks |
| `Design/breadboard-preview.jpg` | [Breadboard contract](Breadboard.md), [preset and connectivity source](../Sources/CircuitCore/Breadboard.swift) |
| `Design/bench-preview.jpg` | [Circuit presets](../Sources/CircuitCore/CircuitPresets.swift) and DC experiment above |
| `Design/learn-preview.jpg` | [Curriculum specification](Curriculum.md) and [routing tests](../Tests/AdvancedModelsTests/CurriculumTests.swift) |
| `Design/capstone-preview.jpg` | [Practice specification](PracticeExperiments.md) and [practice tests](../Tests/AdvancedModelsTests/PracticeModelsTests.swift) |
| `Design/adder-preview.jpg` | [Logic model and adder tests](../Tests/CircuitCoreTests/LogicTests.swift) |
| `Design/transient-preview.jpg` | RC experiment above and [solver tests](../Tests/CircuitCoreTests/CircuitSolverTests.swift) |
| `Design/ac-preview.jpg` | [RC/AC model contract](Curriculum.md) |
| `Design/nonlinear-led-current.png` | [Solved LED load-line checks](../Tests/CircuitCoreTests/NonlinearBreadboardTests.swift) |
| `Design/opamp-supply-current.png` | [Five-terminal op-amp and current-limit checks](../Tests/CircuitCoreTests/NonlinearBreadboardTests.swift) |

To reproduce the local file-target audit, use Python 3 from the repository root. This checks inline Markdown links/images in tracked Markdown files; it ignores external URLs and does not check anchors or prove buildability:

```sh
python3 - <<'PY'
from pathlib import Path
import re
import subprocess

files = subprocess.check_output(
    ["git", "ls-files", "--", "*.md"], text=True
).splitlines()
missing = []
checked = 0
for name in files:
    page = Path(name)
    for target in re.findall(r'!?\[[^\]]*\]\(([^\s)]+)\)', page.read_text()):
        if re.match(r'^[A-Za-z][\w+.-]*:', target) or target.startswith('#'):
            continue
        checked += 1
        if not (page.parent / target.split('#', 1)[0]).exists():
            missing.append(f"{page}: {target}")
print(f"Checked {checked} relative targets in {len(files)} Markdown files")
for entry in missing:
    print(entry)
raise SystemExit(bool(missing))
PY
```

## Recording a new public run

For a fresh result, record the commit SHA, date/time and timezone, host OS/architecture, complete Swift/Xcode/XcodeGen versions, exact commands, exit statuses, both SwiftPM runner summaries, and any failing/skipped cases. For UI runs add the simulator model/runtime and selected tests; for device delivery add the device/OS and install/launch observations separately. Publish only reviewed, sanitized evidence consistent with PUBLICATION.md. Keep this status table explicit about what was executed, what was inspected and what remains historical.
