# Circuit Toy

Circuit Toy is a native SwiftUI playground for learning electrical engineering through circuits, live instruments, waveforms and logic boards. Its dark instrument bench uses bright wires and native Liquid Glass controls on **iPhone with iOS 27**. The logic bench extends Flips' binary place values into gates, arithmetic and memory.

Version **0.4.0 (build 5)** adds **nonlinear devices to the freeform breadboard sandbox** and retains **54 interactive lessons in 12 modules**. The 21 original lessons share ten benches; the additional lessons provide 33 destinations, including multiple subexperiments. Each lesson includes a model, controls, measurements, equations, prediction challenges and explicit assumptions. This degree-wide learning map does not claim accreditation, assessed mastery or equivalence to a physical laboratory.

## Explore

The **Board** tab opens a freeform 12-row breadboard. Place resistors, independent voltage/current sources, capacitors, inductors, diodes, LEDs, NPN/PNP and NMOS/PMOS transistors, and powered op-amps. Choose each pin's contact and connect jumpers. The internal A–E and F–J strips and four continuous rails determine the electrical nets. Mark a ground reference, probe a contact's voltage live, and select a component terminal for signed current, including transistor base/emitter and amplifier supply currents. Readings respond to the circuit you build and edit. Divider, RC, diode clipper, LED drive, transistor switches and op-amp follower examples are fully editable starting points; Empty starts a new board.

In the separate **Logic** mode, place input drivers and any of seven gates, wire them together, and probe **0/1/X/Z** signals live. Undriven nets read Z; opposing drivers resolve to X. Logical fanout is supported. Logic states use the same ideal gate models as the lessons; the board does not convert analog voltage into logic through unstated thresholds.

Analog analysis supports DC and fixed-step transient Run, Step and Reset. Reset loads explicit capacitor-voltage and inductor-current initial conditions; **t=0 has no solved measurement**, so probes remain unavailable until the first step. Editing parts, wiring, initial conditions or Δt resets the simulation. Undo restores a prior board edit, and Analog and Logic documents autosave separately on the device. Move or delete parts and jumpers through Edit or the parts list. The sandbox supports up to 32 components and 64 jumpers. See [the breadboard model and interaction contract](Docs/Breadboard.md) and [the editable preset definitions](Sources/CircuitCore/Breadboard.swift). Preview screenshots are not included in this public snapshot; [PUBLICATION.md](PUBLICATION.md) describes its exclusions.

The **Bench** tab opens a four-node DC editor. Load divider, series, parallel or bridge examples; add, edit and remove resistors or independent sources; change their terminals; probe node voltages; and inspect branch currents, KCL residuals and power balance. Edits support undo and persist locally. The editor supports up to 20 parts, with node 0 as ground.

The charge-and-energy panel connects a selected component's steady DC current and power to accumulated quantities over an adjustable **0.1–10 s** interval: `Q = IΔt` and `W = PΔt`. Charge follows the signed `a → b` current convention; positive energy is absorbed and negative energy is supplied. The foundations lesson on charge, current, voltage and energy links to this experiment.

The **Labs** tab opens the working introductory experiments:

| Destination | Available experiment |
|---|---|
| DC circuits | Grounded linear resistor networks, independent voltage/current sources, a node probe and signed charge/energy accounting |
| Logic boards | Seven four-state gates, truth tables, a four-bit ripple adder and an ideal positive-edge D flip-flop |
| Time & storage | RC charging/discharging, time scrubbing, analytical meters and a backward-Euler comparison |
| AC & impedance | RC low-pass amplitude, phase, cutoff frequency and sinusoidal input/output |
| Devices & amplifiers | Shockley diode I–V at 300 K and an ideal inverting amplifier with hard output rails |
| Signals & sampling | Harmonic synthesis, uniform samples and signed alias frequencies |
| Feedback | A first-order plant under proportional control and unity negative feedback |
| Fields & potential | Signed radial field and potential of one stationary point charge in vacuum |
| Modulation | Single-tone AM, adjustable modulation index and overmodulation |
| Power & phase | Sinusoidal single-phase real, reactive and apparent power; power factor and instantaneous power |

The **Labs** tab also opens **33 more experiments** covering calculus, matrices/phasors, ODEs, statistics, materials, RL/RLC, equivalent networks, BJTs/MOSFETs, analog small-signal design, convolution/DFTs/FIR, stability/PID/state estimation, Faraday/plane waves, transmission lines, BPSK/Hamming/queues, digital timing, transformers/motors, converters, CPU/ADC/interrupts, FSM verification, instrumentation, requirements, ethics and an integrated thermal capstone.

The **Learn** tab connects all 54 lessons to concepts, equations, prediction challenges and model limits. Every lesson opens a working experiment. Marking a lesson explored records practice, not assessed mastery. The module prerequisites suggest a sequence without preventing exploration.

## Model fidelity

Results follow the stated electrical model. Model assumptions and numerical approximations are part of each experiment.

- **CircuitCore:** modified nodal analysis enforces KCL, Ohm's law and ideal source constraints. Quantities use SI units. `V(a) − V(b)` defines voltage; positive current flows `a → b`; positive power is absorbed. DC capacitors are open and inductors are shorts. Board compiles contact connectivity into the same solver used by the lessons. Bench exposes four nodes and R/V/I parts; Board exposes freeform linear and nonlinear components. Its nonlinear solver enforces the compact device equations simultaneously with KCL, with terminal current and supply-power accounting.
- **Transient core:** fixed-step backward Euler solves R/L/C networks together with quasistatic nonlinear devices with explicit capacitor voltage and inductor current initial conditions. Board reuses this integrator directly. The guided RC bench uses exact exponential meters and compares a numerical trace at `Δt = τ/24`. Refining the timestep reduces approximation error; backward Euler can add artificial damping to oscillatory systems.
- **Logic:** 0, 1, X and Z are logical abstractions. Board calls the existing core gate evaluator and equal-strength driver resolver; gates in feedback cycles are conservatively X. The guided logic lesson separately includes ideal positive-edge D storage. Transistor voltages, electrical fanout limits, delays, setup/hold and analog metastability are outside these Boolean models.
- **Science labs:** closed-form models name their assumptions: unloaded RC filtering, fixed diode temperature, ideal amplifier feedback and rails, fixed harmonic phases, a noiseless uniform sampler, a first-order plant, vacuum point-charge electrostatics, ideal AM and prescribed sinusoidal voltage/current.

Floating, singular, contradictory and invalid circuit configurations produce typed errors. The solver does not add artificial ground conductance or substitute plausible readings. Nonlinear parts use Shockley junctions with series resistance, Ebers–Moll BJTs, long-channel square-law MOSFETs with source-tied body diodes, and a finite-gain, rail-aware, output-resistance/current-limited op-amp. The LED glow follows solved forward current. These generic compact models have explicit limits; semiconductor charge storage, breakdown, self-heating and amplifier bandwidth/slew are omitted. Model parameters are editable and persist with the board.

Board contacts and probes are ideal: there is no probe loading, contact resistance or parasitic wire model. Current is measured through a component branch; arbitrary ideal-jumper current is unavailable after its endpoints merge into a net. Analog and Logic remain separate analysis modes.

See [the curriculum and fidelity contract](Docs/Curriculum.md) and [the breadboard contract](Docs/Breadboard.md) for detailed coverage and references. The original README reported **187 pure Swift tests passing with zero failures**, two nonlinear native workflows passing on an iPhone 15 Pro Max, and installation/launch of **0.4.0 (5)**. Those are historical reports: the public snapshot contains test source, but no corresponding run logs, result bundles or phone captures. The documentation audit counted 187 declared SwiftPM tests; it did not execute them or verify the app's build, installation or launch. See [the public validation guide](Docs/Validation.md) for evidence status, environment requirements and reproducible experiments. Public source checks for [LED current and op-amp supply/current limits](Tests/CircuitCoreTests/NonlinearBreadboardTests.swift) replace the unavailable phone captures.

## Build and run

The native project declares **iOS 27** and Swift 6; use a macOS host with **Xcode 27**, its iOS 27 SDK and simulator runtime, and XcodeGen. These are the repository's declared requirements, not a newly verified build environment. The standalone model-test package declares Swift tools **6.0** and **macOS 15+** and does not require XcodeGen or an iOS simulator. See [validation and environment details](Docs/Validation.md#environment-and-test-commands). From this directory:

```sh
xcodegen generate
open CircuitToy.xcodeproj
```

Select the **CircuitToy** scheme, choose an iPhone simulator running iOS 27, and run. `project.yml` declares iOS 27, Swift 6 and device family `1` (iPhone only). The generated project contains the app and a `CircuitCore` framework. A physical-device run requires your development-team signing and a connected, unlocked iPhone.

For a simulator build from the terminal:

```sh
xcodebuild -project CircuitToy.xcodeproj -scheme CircuitToy \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/CircuitToy-iOSBuild \
  CODE_SIGNING_ALLOWED=NO build
```

On a supported macOS host, run the pure Swift model tests from the repository root:

```sh
swift --version
swift test
```

For a host that needs the original custom cache locations, the following alternative puts caches and build products in `/private/tmp`. Use `--disable-sandbox` only if needed for that host's nested-sandbox restrictions; it is not required by the scientific models and the calling environment's filesystem permissions still apply.

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/CircuitToyCoreBuild/ClangModuleCache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/CircuitToyCoreBuild/ModuleCache \
swift test --disable-sandbox \
  --scratch-path /private/tmp/CircuitToyCoreBuild \
  --cache-path /private/tmp/CircuitToySwiftCache \
  --config-path /private/tmp/CircuitToySwiftConfig \
  --security-path /private/tmp/CircuitToySwiftSecurity
```

[Package.swift](Package.swift) defines four model/store test targets covering `Sources/CircuitCore`, breadboard connectivity and analysis, the pure science/advanced models, and curriculum routing metadata. `swift test` does not run the separate native UI tests or build the SwiftUI app. The native UI test target includes workflows for all 33 additional lesson destinations, Learn navigation, capstone controls and breadboard placement, wiring, probes, edits, logic signals, transient stepping and persistence. Run those through the generated Xcode scheme using [the UI test command](Docs/Validation.md#native-build-and-ui-tests); a successful model run alone does not establish those workflows.

## Project layout

- `App/`: native app, bench/breadboard state, 43 lesson experiment destinations, 54-lesson curriculum and visual components.
- `Sources/CircuitCore/`: SI circuit models, DC/transient solver, breadboard netlist compiler, presets and digital logic.
- `Tests/`: conservation, analytical references, digital/coding properties, numerical convergence, curriculum and native UI checks.
- `Docs/`: [curriculum/model contract](Docs/Curriculum.md), experiment specifications and [public validation guide](Docs/Validation.md).
- `Design/`: [visual direction](Design/Direction.md) and [icon-generation source](Design/MakeIcon.swift). Simulator previews are not published. For public demonstrations, start with [reproducible circuit experiments](Docs/Validation.md#reproducible-model-experiments), [curriculum routing checks](Tests/AdvancedModelsTests/CurriculumTests.swift), [capstone specifications](Docs/PracticeExperiments.md), [logic tests](Tests/CircuitCoreTests/LogicTests.swift) and [RC/AC model specifications](Docs/Curriculum.md).


## Public snapshot

See [PUBLICATION.md](PUBLICATION.md) for publication exclusions and setup requirements.
