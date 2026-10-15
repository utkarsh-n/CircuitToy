# Circuit Toy: curriculum and fidelity contract

Circuit Toy contains **54 interactive lessons across 12 modules**. All 33 formerly planned lessons now have distinct working experiments; 21 existing lessons connect to the ten original benches. The app therefore exposes 43 experiment destinations, with several lessons and subexperiments sharing a destination.

A working lesson contains a concept, equation, supported interaction, prediction challenge and explicit model boundary. The model follows real governing equations under those assumptions. This map spans the subject areas of an EE curriculum; it does not claim the depth of every university elective, an accredited degree, assessed mastery or physical laboratory equivalence.

## Coverage

| Stage | Module | Interactive lessons | Available work |
|---|---|---:|---|
| 1 | The language of electricity | 6 | DC charge/energy; calculus; two-node linear algebra and phasors; first-order ODE methods; probability/measurement statistics; conductivity, heat, mechanical work and photons |
| 1 | Circuits from conservation | 5 | Ohm, series/parallel, Kirchhoff conservation and loaded dividers through an editable MNA bench |
| 1 | From bits to logic boards | 5 | Gates, complete truth tables, ripple addition, clocked register/counter/FSM, synchronous timing and transport-delay hazards |
| 2 | Energy gives circuits a memory | 5 | RC charge/release and AC low-pass; RL storage; RLC resonance/damping; Thevenin load power and RC transform/pole |
| 2 | Matter becomes electronics | 5 | Shockley diode, reciprocal Ebers–Moll BJT, long-channel MOSFET regions, rail-limited ideal op amp and nonlinear/small-signal common-emitter stage |
| 2 | Signals carry structure | 5 | Harmonics, sampling/aliasing, discrete convolution, windowed DFT and an editable FIR filter |
| 3 | Feedback shapes behavior | 4 | Proportional feedback; second-order pole stability; sampled PID, saturation/antiwindup; LQR and a state observer |
| 3 | Circuits live inside fields | 4 | Point-charge field/potential; Faraday induction/vacuum plane wave; lossless transmission-line reflections |
| 3 | Put information on a wave | 4 | AM; coherent BPSK with Gaussian decision noise; Shannon capacity/Hamming correction; finite FIFO packet-link events |
| 3 | Energy at useful scale | 4 | AC real/reactive/apparent power and power factor; transformer/DC motor; CCM buck and three-phase wye loads |
| 3 | Logic becomes a computer | 3 | Stepped teaching CPU with registers/ALU/memory; ADC and interrupt deadlines; FSM safety verification and CMOS dynamic power |
| 4 | Think and work like an engineer | 4 | Probe loading/bandwidth; requirement/tolerance tradeoffs; engineering decision cases; integrated sensor-to-heater capstone with exported evidence |
| | **Total** | **54** | **54 available; zero planned placeholders** |

## Model details and references

The exact supported controls, numerical methods, boundaries and primary sources for the new experiments are documented in:

- [Foundation experiments](FoundationExperiments.md): eleven mathematics, material, circuit and device lessons.
- [Systems experiments](SystemsExperiments.md): eleven signal, control, field and communication lessons.
- [Engineering experiments](EngineeringExperiments.md): seven digital, computing, machine and power lessons.
- [Practice experiments](PracticeExperiments.md): four measurement/design/professional/capstone lessons.

The ten original benches remain:

| Bench | Model |
|---|---|
| DC | Modified nodal analysis of grounded R/V/I networks, SI units, signed branch current/power, KCL and power residuals. Editor: four nodes, up to 20 parts. Invalid, floating and inconsistent systems are reported. |
| Logic | Four-state 0/1/X/Z gates, complete binary truth tables, a four-bit ripple adder and ideal rising-edge storage. |
| RC | Exact charging/discharging meters; fixed-step backward-Euler comparison with an explicit timestep-error disclosure. |
| AC | Ideal unloaded first-order RC transfer function in sinusoidal steady state. |
| Devices | Shockley junction at 300 K; ideal inverting op amp with explicit hard rail limits. |
| Signals | Fixed-phase first/second/third harmonics, uniform sampling and signed aliases that preserve samples. |
| Feedback | First-order plant under proportional unity negative feedback. |
| Fields | One stationary ideal point charge in vacuum, with signed radial E and potential relative to infinity. |
| Modulation | Single-tone full-carrier AM including overmodulation. |
| Power | Prescribed sinusoidal single-phase RMS voltage/current with phase difference and instantaneous power. |

CircuitCore additionally supports general ideal linear RLC backward-Euler stepping with explicit initial conditions. The guided UI chooses bounded examples; the core is not represented as a general nonlinear SPICE or full-wave electromagnetic simulator.

## Fidelity rules

1. Every control changes the declared model, and readouts retain units and sign conventions.
2. Traces compared quantitatively share axes. Discrete samples connected by lines do not assert analog reconstruction. Clipping a trace to a labeled display range does not change the mathematical result.
3. Invalid configurations produce a diagnostic. An approximation outside its assumptions is labeled or withheld: a DCM candidate is not presented as a valid CCM solution; an over-stall motor result is not presented as a forward motoring operating point.
4. Exact equations, finite-step integration, seeded random realizations and theoretical probabilities are distinguished. A sample BER is not the exact channel error probability; a component bound is not a confidence interval.
5. Verification uses independent analytical identities, conservation, exhaustive finite logic/coding cases, convergence and recorded native interactions. A build, simulation acceptance result or explored lesson does not prove real-device physics or learner mastery.
6. Professional-practice cases use qualitative consequences and written reasoning. Ethics and design responsibility are not assigned a fabricated numerical score.

## Learning path and Flips bridge

Begin with charge, current, energy and units. Explore conservation in circuits and bits in logic. Add stored energy, devices and signals; then study control, fields, communication, power and computing. Finish by comparing design requirements with recorded evidence in the capstone. Prerequisites suggest an order without blocking exploration.

Flips' place values become gates, carry chains, registers and processor state. The logical bit retains its mathematical meaning while the timing lesson explains constraints a physical implementation must satisfy. The ideal digital simulation does not invent analog transistor voltages or exact metastability behavior.

## Degree source context

EE programs share foundations and differ in required electives and laboratory depth. The source map uses:

- [ABET Engineering Criteria, 2026–2027](https://www.abet.org/accreditation/accreditation-criteria/criteria-for-accrediting-engineering-programs-2026-2027/).
- [Illinois Electrical Engineering BS](https://catalog.illinois.edu/undergraduate/engineering/electrical-engineering-bs/).
- [MIT Electrical Engineering with Computing](https://catalog.mit.edu/degree-charts/electrical-engineering-computing-course-6-5/).
- [MIT EECS specialization tracks](https://catalog.mit.edu/degree-charts/electrical-engineering-computer-science-tracks/).

The outlines are original synthesized teaching content. Per-experiment source links support the implemented equations and assumptions; no university's complete course material is reproduced.
