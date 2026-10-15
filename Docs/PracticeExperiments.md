# Engineering practice experiments

Four working lessons connect analysis to evidence and design decisions. `PracticeModels.swift` contains pure models; `PracticeLabs.swift` contains native controls, readouts and report export.

| Lesson | Working interaction | Fidelity boundary |
|---|---|---|
| Instrumentation | Vary divider resistance, probe resistance/capacitance and sinusoid frequency. Compare unloaded DC, loaded DC, loading error, measured peak amplitude, phase and a shared-axis gain curve. | Lumped ideal source and linear R-C probe. No probe ground-lead inductance, cable distribution, input protection, stochastic noise or calibration drift. |
| Design | Select 1 kΩ, 10 kΩ or 100 kΩ equal-resistor dividers. Change resistor tolerances and voltage/current/power requirements. Compare each loaded candidate and worst-case acceptance. | Equal nominal resistors with independent bounded deviations; eight source/component corners. 100 kΩ load and ±1% supply are prescribed. Bounds are not probabilities; power ratings omit thermal derating and certification. |
| Ethics | Select evidence/disclosure, sensor-fault or privacy/accessibility cases; choose a proposed action, inspect consequences, and save a local decision record. | Authored hypothetical qualitative cases. No numerical ethics score, legal advice or claim of professional competence. |
| Capstone | Configure a sensor–ADC–controller–heater–thermal loop. Vary supply, heater resistance, setpoint, heat transfer, sensor offset, deadband, resolution and sample period. Run acceptance checks and export the exact configuration and sample report through a native share sheet. | Isothermal constant-capacity plant with linear environmental heat transfer. Exact held-input solution; static ideal sensor law with offset; bin-centered ADC with clipping; sampled hysteresis; ideal supply/resistor/switch. No real prototype, failure certification, radiation or spatial gradients. |

The capstone uses `C dT/dt = V²/R − h(T−T_a)` while on, with zero heater input while off. Its energy record satisfies electrical input = stored-energy rise + environmental transfer. The 180 s run uses C=20 J/K and ambient 20 °C. Acceptance compares maximum physical temperature and largest target error during the final 20% of the run. Changing a design variable invalidates the previous displayed acceptance result. A JSON export contains all configuration values and recorded samples; local requirement notes accompany the report.

## Independent checks

Tests compare probe loading with the parallel-resistance result and the −3 dB/−45° pole identity; check tolerance bounds against an independent parameter grid; verify quantizer half-bin bounds and clipping; compare thermal evolution with the exact one-time-constant solution; test per-sample energy balance and an underpowered heater's unreachable target; and round-trip the exported report. These checks do not establish physical hardware behavior.

## Primary references

- [Analog Devices: frequency-compensated voltage dividers](https://www.analog.com/en/resources/analog-dialogue/studentzone/2019/07/25/14/50/studentzone-november-2018.html).
- [Analog Devices: ADC transfer and quantization](https://wiki.analog.com/university/courses/electronics/text/chapter-20). The app explicitly uses a bin-centered teaching quantizer, so endpoints and representative voltages remain defined.
- [MIT: A Heat Transfer Textbook](https://ahtt.mit.edu/), lumped-capacity energy balance.
- [IEEE: engineering ethics](https://technav.ieee.org/topic/ethics/), evidence, public welfare, privacy and honest technical representation.
- [NIST: measurement uncertainty components](https://www.nist.gov/pml/nist-technical-note-1297/nist-tn-1297-appendix-d2-identification-uncertainty-components). A tolerance bound, an estimated standard uncertainty and an observed deterministic loading error are distinct quantities.
