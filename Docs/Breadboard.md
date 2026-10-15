# Freeform breadboard sandbox

The Breadboard workspace turns an editable physical connection layout into pure circuit and Boolean models. Its readings come from the resulting netlist. Divider, RC, diode clipper, LED drive, NPN and MOSFET switches, powered op-amp feedback, and AND examples are editable starting points; placing components and wires does not select a prerecorded outcome.

## Building and measuring

Choose Analog or Logic, add a component, then tap its required pin locations in order. Wires join two holes. On this 12-row board, A–E in each row form one connected strip and F–J form another. The center channel separates E from F. Each of L+, L−, R+ and R− is one continuous vertical rail; the four rails remain separate until wired together. This virtual board has unsplit rails. Real breadboards can have split rails, so their printed markings and measured continuity matter.

Selecting a connection highlights its entire net. Ground supplies an analog voltage reference. L−1 is explicitly marked as ground in a new document; choosing another hole moves that reference. A source's negative terminal does not silently establish ground. The workspace supports up to 32 components and 64 jumpers.

The voltage probe measures the selected hole relative to the chosen ground. Current is positive **into the selected terminal**. For a two-terminal element, the first terminal's reading is the familiar a → b branch current and the second terminal has the opposite sign. Transistors expose C/B/E or D/G/S readings; op-amps expose both inputs, output and both power terminals. Ideal-wire current is unavailable: after ideal connected wires and strips are collapsed into one node, an arbitrary internal wire current need not be uniquely determined. The voltage probe is ideal and does not load the circuit. Measurement-loading effects remain available in the Instrumentation lesson.

Component values and pin locations can be edited. Undo restores the prior document. Analog and Logic documents are autosaved separately on the device so a circuit can be revisited. Undo history is held during the app session. Relaunch opens the saved Analog document in DC analysis. Changing circuit topology, analog values, the initial conditions or the time step resets transient state; a changed board is a new initial-value problem rather than a continuation with silently reassigned capacitor charge or inductor flux.

## Analog model

The supported components are positive resistances, capacitances and inductances, independent constant voltage and current sources, diodes, LEDs, NPN/PNP BJTs, NMOS/PMOS transistors, and five-terminal op-amps. The sandbox calls `CircuitSolver.solveDC` and `TransientSimulator` from `CircuitCore`; it does not introduce a second calculator for these elements.

| Quantity or analysis | Governing relation and convention |
| --- | --- |
| Branch voltage | `v = V(a) − V(b)` |
| Resistor | `i = v/R`; positive current is a → b |
| Voltage source | `V(a) − V(b) = Vs`; its current is solved from the connected circuit |
| Current source | `i = Is` from a → b |
| DC capacitor | Open circuit, `i = 0` |
| DC inductor | Zero voltage with its branch current solved |
| Capacitor transient | Backward Euler: `i[n+1] = C(v[n+1] − v[n])/h` |
| Inductor transient | Backward Euler: `v[n+1] = L(i[n+1] − i[n])/h` |
| Two-terminal power | `p = vi`; positive means absorbed, negative means supplied |

The grounded modified nodal equations enforce Kirchhoff's current law and each constitutive relation at the same time. Unused empty strips are not invented circuit nodes. An active node without a voltage reference, contradictory ideal sources, redundant ideal constraints, incompatible reactive initial conditions, invalid values and numerical-range failures produce an explicit unavailable result. The solver does not fabricate a ground path or substitute plausible readings for a failed solve.

Transient stepping starts from the entered capacitor voltages and inductor currents. Reset loads those initial values and clears readings; it shows “Step or Run” until a complete circuit sample has been solved. The first solved sample is at one positive time step. Run advances simulated time using the chosen fixed step; it does not imply real-time hardware execution. Backward Euler is a first-order numerical approximation with finite-step error and numerical damping. Reduce the step and compare convergence, especially for fast or lightly damped circuits. Constant independent sources remain constant during a run. Selecting the existing time step or saving an unchanged component preserves the current sample and playback state; an actual change resets the initial-value problem. Rejected document edits do not replace the valid circuit or its saved board.

Breadboard contact resistance, wire inductance, stray capacitance, component ratings, breakdown, self-heating, manufacturing tolerance and measurement noise are not added by the visual board. A real assembly can differ when these effects matter.

## Nonlinear devices

All terminals participate in the same simultaneous nodal solve as the R/L/C network. The solver reports each terminal current and computes device power as `Σ Vterminal × Iterminal`, including the op-amp supplies. A transistor's collector/drain current is not substituted for its base/gate or emitter/source current. A powered amplifier draws its load current from the wired supplies.

| Part and placement order | Model |
| --- | --- |
| Diode / LED: A, K | Shockley junction with series resistance: `I = Is(expm1(Vj/(nVt)))`, `VA − VK = Vj + I Rs`, `Vt = kT/q` |
| NPN / PNP: C, B, E | Reciprocal Ebers–Moll transport, including both forward- and reverse-biased junctions and finite forward/reverse current gain |
| NMOS / PMOS: D, G, S | Long-channel square-law cutoff, triode and saturation regions, channel-length modulation, reverse channel operation and a source-tied body diode; ideal insulated gate |
| Op-amp: +In, −In, Out, V+, V− | Generic finite open-loop gain, explicit supply rails, rail headroom, finite output resistance, bidirectional output current limit and quiescent supply current |

The device editor exposes the model parameters in their stated units. Junction temperature changes `Vt`; the entered saturation current is the value at that temperature, with no separate material-dependent `Is(T)` law. The diode and LED use continuous exponential I–V curves, rather than a fixed forward-voltage switch. The red LED profile has a different saturation current and ideality factor. Its glow is a display-only mapping of solved positive anode current; it is not calibrated light output or a thermal/rating simulation.

BJT saturation follows the two junction equations, including base current. The model omits Early effect, high-injection gain reduction, series resistance and stored charge. The enhancement-mode MOSFET bodies are internally tied to the labeled source, with no fourth body contact. The model omits body-effect threshold shift, subthreshold conduction, short-channel behavior and gate/junction capacitances. These are generic teaching profiles, not fitted manufacturer part numbers.

The op-amp must be powered through V+ and V−. It uses a rail-centered finite-gain command with bounded voltage swing, output resistance and a hard current limit. Its ideal inputs draw zero current and have a supported common-mode range within the wired rails. Invalid supplies, inputs outside the rails, or an externally forced output outside the rails produce a diagnostic. Protection-diode and back-power behavior are outside this model. The model is quasistatic: it has no offset, bias current, frequency-dependent gain, slew rate or transistor-level internal dynamics. External capacitors and inductors still evolve through the shared transient solver.

Nonlinear DC and each transient step solve the device equations together with KCL. Failure to converge produces an unavailable result instead of a fabricated reading. Backward Euler's finite-step error applies to energy-storage elements; omitted semiconductor charge storage does not appear automatically in transient mode.

## Logic model

The Logic workspace uses `LogicLevel.resolve` and `LogicGate.evaluate` from `CircuitCore`. Nets carry four states: **0**, **1**, **X** for unknown or conflicting drivers, and **Z** for an undriven/high-impedance net. A Z gate input is treated as unknown. A controlling input can still determine a gate's output, such as `0 AND X = 0` and `1 OR X = 1`.

Equal-strength drivers of the same known value agree; conflicting active values resolve to X. Gates are ideal Boolean components with zero propagation delay. Floating inputs, driver contention and feedback are disclosed rather than being silently interpreted as zero. Every gate participating in a feedback cycle is conservatively marked X; downstream gates are then evaluated with the usual four-state rules. This policy does not solve stable Boolean feedback states or simulate latches or oscillators. The logic probe reads the symbolic net state.

Analog and Logic are separate modeling modes. A logic one is not a measured supply voltage, and an analog node is not automatically compared with a fabricated switching threshold. The sandbox models logical fanout but does not model CMOS input/output currents, supply pins, transistor switching, electrical fanout limits, analog metastability, setup/hold timing or a mixed-signal bridge. The dedicated device and timing lessons explain those distinct physical models.

## References and verification

The sandbox's netlist and model contracts are checked against the [SpiceSharp modified nodal analysis derivation](https://spicesharp.github.io/SpiceSharp/articles/tutorials/writing_behaviors/modified_nodal_analysis.html) and the [Qucs energy-storage companion equations](https://qucs.sourceforge.net/tech/node26.html). Primary references were checked on October 11, 2026. These references support the governing equations; the app's layout, editing behavior and diagnostic policies are implementation choices.

The nonlinear model families are cross-checked against the [ngspice device-model manual](https://ngspice.sourceforge.io/docs/ngspice-manual.pdf), sections 7.2, 7.3 and 7.6. The generic op-amp's declared rail and load constraints are informed by [Analog Devices' explanation of input range and output swing](https://www.analog.com/en/resources/technical-articles/railtorail-outputs-and-beyondtherails-inputs-the-inside-story-on-micropower-op-amps.html). These references describe richer models and real devices; Circuit Toy implements the explicitly bounded compact models above.

Model tests check connectivity, circuit and logic behavior under these assumptions. Native UI tests check specific user workflows and visible live readings. The [public validation guide](Validation.md) identifies the available test source, reproducible commands and historical run/delivery reports whose original evidence is not published; source inspection alone is not a runtime pass.
