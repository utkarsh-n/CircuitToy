# Engineering experiments

These seven lesson routes are interactive, bounded teaching experiments. Each exposes an actual state transition, analytical calculation or finite-state search. Completing them is not equivalent to completing a university course, physically building a board, certifying timing on silicon or validating a motor/converter design. The equations, units, sign conventions and omissions below define the implemented scope.

The pure Foundation implementation is `App/EngineeringModels.swift`; the native SwiftUI interface is `App/EngineeringLabs.swift`. Root navigation uses `EngineeringLessonLab(lessonID:)`.

| Lesson ID | Working experiment | Observable result |
| --- | --- | --- |
| `sequential` | Manual clock, 4-bit register, enabled modulo-16 counter, overlapping 101 detector | Stored value, rising-edge count, detector state/match, transition table and recent edge history |
| `digital-timing` | Register-path timing inequalities and reconvergent static-1 hazard | Setup/hold margins in ns, explicit violation, delayed waveform and pulse width |
| `machines` | Ideal transformer and steady-state PM DC motor | RMS voltage/current, reflected resistance, power balance, motor speed/current/stall condition |
| `converters` | Ideal diode-buck CCM candidate and four-wire resistive three-phase load | CCM validity, triangular inductor ripple, conversion/power balance, neutral RMS current and total instantaneous power |
| `architecture` | Three-phase instruction execution in a custom 8-bit CPU | PC, instruction register, registers, flags, RAM, cycle count and branch behavior |
| `embedded` | Ideal ADC plus a separate periodic FIFO interrupt workload | Quantized code/bin estimate/error and release/start/finish/deadline table |
| `hardware-design` | Finite-state controller safety verification and CMOS capacitive power | Reachable counterexample, decoder truth table, dynamic power in W |

## `sequential`: state changes at an event

Set register data `D` from 0–15, enable or disable the counter, choose a serial bit, then raise/lower the manual clock. Only a low-to-high transition captures `D`, optionally increments the counter and advances the detector. Changing inputs while high does not update stored state. Register, counter and detector share that clock.

The register follows `Q⁺ = D`; the counter follows `(count + enable) mod 16`. Detector state 0 retains no suffix, state 1 retains `1`, and state 2 retains `10`. A `1` in state 2 signals a match and returns to state 1, so input `10101` yields two overlapping matches. Reset initializes all storage and clock to known zero state. The match readout reports the last rising-edge event, not a physical analog pulse duration.

Try disabling the counter while clocking new register data, then enable it and reach 15. Predict whether the next enabled rising edge wraps. For the detector, clock `1,0,1,0,1` and count the two matches.

This is ideal binary synchronous logic. It omits delays, transistor implementation, analog thresholds, metastability and physical reset networks. [MIT's finite-state-machine lecture](https://ocw.mit.edu/courses/6-004-computation-structures-spring-2009/resources/mit6_004s09_lec06/) provides the synchronous-state foundation.

## `digital-timing`: Boolean behavior needs timing constraints

Vary clock period, maximum/minimum logic propagation delays and destination clock skew. Clock-to-Q max/min are fixed at 0.8/0.2 ns; setup/hold requirements are fixed at 0.3/0.15 ns. Positive skew means the destination clock arrives later.

`Msetup = T + skew − tCQ,max − tlogic,max − tsetup`

`Mhold = tCQ,min + tlogic,min − skew − thold`

A margin at or above zero satisfies the specified constraint. A negative margin means captured data is not guaranteed; no exact metastable voltage, failure probability or failure time is invented. Increase positive skew to observe improved setup and worsened hold. Once hold fails, lengthening the period leaves that margin unchanged. [MIT's sequential timing material](https://ocw.mit.edu/courses/6-004-computation-structures-spring-2017/pages/c5/c5s1/) supports these setup/hold and propagation constraints.

The second panel uses `F = AB + ¬AC`, holds `B=C=1` and raises `A` at 2 ns. Set the two path delays independently. A fixed 0.2 ns transport OR delay shifts the low pulse; when the old path falls first, its width is `max(0, risingDelay − fallingDelay)`. Add consensus term `BC` to hold the output high without changing the steady Boolean truth table. Real inertial gates can filter sufficiently narrow pulses; this panel intentionally specifies transport delay.

## `machines`: ratios and power conservation

The transformer has a fixed 100-turn primary, adjustable secondary turns, primary RMS voltage and resistive secondary load. Port voltage polarities use matching winding polarity. Current magnitudes mean primary input current and secondary load current; both currents defined into the transformer would have opposite signs.

`V₂/V₁ = N₂/N₁`, `I₁/I₂ = N₂/N₁`, `Rref = Rload(N₁/N₂)²`.

The displayed input and output powers are equal. Both voltage waveforms share a voltage scale and normalized cycle axis. Double secondary turns and observe doubled secondary voltage, doubled secondary current for the same load, fourfold primary current and one-quarter reflected resistance. The source supplies the extra power. This is an ideal lossless sinusoidal transformer, excluding magnetizing current, leakage, saturation and winding/core losses. [MIT's AC networks and transformer chapter](https://ocw.mit.edu/courses/6-061-introduction-to-electric-power-systems-spring-2011/c6393a58319200a5344752de0cf47ec4_MIT6_061S11_ch3.pdf) defines the ideal relation.

The motor is a steady-state permanent-magnet DC model with fixed SI constants `kₜ=kₑ=0.1`, adjustable supply voltage, armature resistance and opposing load torque. It uses `τ=kI`, `E=kω`, `V=RI+E`, hence `VI=τω+I²R`. Speed is in rad/s and torque in N·m. At zero load, this frictionless model draws zero current; that assumption differs from a real motor. Increase torque toward `τstall=Vk/R`. Beyond stall, the algebraic candidate has negative speed: the UI flags the absence of a positive-speed steady motoring solution instead of inventing one by clamping. Inertia, inductive startup, friction, commutation and thermal limits are omitted. [MIT's motor torque/back-EMF tutorial](https://www.mit.edu/course/2/2.010/www_f00/psets/hw2_dir/tutor2_dir/tut2_h.html) explains equality of the SI constants.

## `converters`: check the conduction assumption

The buck panel varies input voltage, duty, inductance in µH, switch frequency in kHz and resistive load. It computes a candidate for an ideal diode/switch buck in periodic continuous conduction, assuming an output capacitor large enough to neglect output-voltage ripple:

`Vout≈D Vin`, `Iavg=Vout/R`, `ΔI=(Vin−Vout)D/(Lf)`, `Imin=Iavg−ΔI/2`.

The waveform is displayed only when `Imin>0`. The minimum/maximum triangular currents and ideal input/output powers are calculated, not decorative animations. When `Imin≤0`, the panel shows the failed CCM condition and hides the CCM waveform/output result. It does not silently clamp negative current or claim that `D Vin` remains the diode-buck DCM solution. Double inductance and observe half the peak-to-peak ripple. Increase load resistance until CCM fails. Startup, ESR, loss, feedback control, DCM and device ratings are omitted. [TI's power-topologies handbook](https://www.ti.com/lit/eb/slyu036a/slyu036a.pdf) gives the buck ripple/conduction framework.

The second mode uses a balanced sinusoidal source driving three adjustable resistive wye loads with a solid neutral: a four-wire network. Voltage is phase-to-neutral RMS. `vₖ=√2 Vrms sin(ωt−2πk/3)`, `p(t)=Σvₖ²/Rₖ`, and neutral current is the negative sum of the phase currents. Equal resistances give zero neutral RMS and constant instantaneous total power. Unequal resistances give neutral current and power pulsation. The balance button sets B and C resistances to A. This is not a floating-neutral three-wire network, generator model, protection model or grid load-flow solver. [MIT's three-phase lecture](https://ocw.mit.edu/courses/6-622-power-electronics-spring-2023/mit6_622_s23_lec212.pdf) supports the balanced-phase power relation.

## `architecture`: an instruction causes a traceable state change

Choose Add, AND or Countdown, stage the input bytes, then press Load/reset. Edits are staged until loading; the numeric prediction explicitly checks the staged program. Step one clock phase at a time through fetch, decode and execute. Fetch copies instruction ROM into IR and increments PC. Decode selects the instruction. Execute changes the architectural state. Every instruction takes three phases in this declared model.

The custom machine has 8-bit A/B registers, carry and zero flags, 16-byte RAM and separate immutable instruction ROM. Add/AND programs load RAM[0]/RAM[1], perform the ALU operation, store A to RAM[2] and halt. Addition writes `(A+B) mod 256` and records carry separately. Countdown starts from 1–255, decrements A, stores RAM[2], branches back while zero is false, then halts. `DEC` wraps modulo 256; the positive staged input avoids treating initial zero as a zero-iteration loop.

Try A=250 and B=10. Predict final RAM[2]=4 with carry set; verify the data does not change during fetch/decode. Compare countdown instruction/cycle counts with the actual branch trace. This is a pedagogical ISA with no ARM/x86 compatibility, cache, pipeline, wait states or gate-level timing. [MIT's processor implementation material](https://ocw.mit.edu/courses/6-004-computation-structures-spring-2017/pages/c13/c13s1/) motivates the instruction/datapath sequence.

## `embedded`: resolution and response time

The ADC is an ideal unipolar uniform mid-rise quantizer with a fixed 3.3 V reference and adjustable input and 1–12 bit resolution. It clamps codes to `[0,2ᴺ−1]`, using `LSB=Vref/2ᴺ`, `code=floor(Vin/LSB)` and midpoint reconstruction `V̂=(code+½)LSB`. Error is reconstructed minus requested input. The transfer plot exposes the code bins. In-range input, including both endpoints, has error at most half an LSB; an out-of-range clipped input does not retain that bound. Try an input above 3.3 V, then double the resolution and compare LSB. Noise, DNL/INL, input loading, jitter and sample-and-hold dynamics are omitted. [Analog Devices' ADC material](https://wiki.analog.com/university/courses/electronics/text/chapter-20) discusses resolution and quantization.

The interrupt table is a separate scheduling model, not an ADC sampling transient. Adjust timer period, processor clock, entry cycles, handler cycles and fixed blocking charged to every job. Eight releases enter a FIFO, nonpreemptive service model:

`startₙ=max(releaseₙ,finishₙ₋₁)+blocking+entryCycles/fclk`

`finishₙ=startₙ+handlerCycles/fclk`, `deadlineₙ=releaseₙ+T`.

Slack is deadline minus finish. A nonnegative slack passes that job's constraint. If total per-job service exceeds the period, backlog grows. Predict whether all eight jobs finish on time, then shorten the period. This fixed overhead model does not claim Cortex-M cycle accuracy, a general RTOS proof or guaranteed hardware execution time. [Arm's interrupt-latency guide](https://developer.arm.com/community/arm-community-blogs/b/architectures-and-processors-blog/posts/beginner-guide-on-interrupt-latency-and-interrupt-latency-of-the-arm-cortex-m-processors) distinguishes entry latency from software execution.

## `hardware-design`: state a property independently

The fixed four-state controller cycles `00 A-green → 01 all-red → 10 B-green → 11 all-red`. Clock advance=1 advances; advance=0 holds. The decoder implements `A=¬q₁∧¬q₀`, `B=q₁∧¬q₀`. A selectable fault also asserts A in state 10. The independent safety property is `always ¬(A∧B)`. A breadth-first reachable-state search covers both input values from reset and reports a shortest input counterexample. With the fault, `1→1` reaches both greens. Replay it using the native clock controls, then remove the fault and check all reachable states.

This is truth-table mapping and finite-state safety verification. It provides no editable HDL, FPGA compiler, synthesis, place-and-route or physical timing closure. It is not a traffic safety certification.

The second panel computes `Pdynamic=αCV²f`. Capacitance uses pF, frequency MHz, and results W. Here α means expected **0→1 events per clock cycle**, not total rising-plus-falling transitions. A rising event draws `CV²` from the supply: half becomes stored capacitor energy, half is dissipated during charging; ordinary discharge dissipates the stored half. Double voltage and observe fourfold power; set activity to zero and observe zero capacitive switching power. Leakage and short-circuit current are not included, so zero dynamic power does not imply zero real-chip power. [TI's CMOS power note](https://www.ti.com/lit/an/scaa035b/scaa035b.pdf) and [MIT's digital integrated-circuit course topics](https://ocw.mit.edu/courses/6-374-analysis-and-design-of-digital-integrated-circuits-fall-2003/pages/calendar/) provide the switching-energy context.

## Validation boundaries

`Tests/AdvancedModelsTests/EngineeringModelsTests.swift` verifies rising-edge capture and overlapping matches, setup/hold/skew identities, consensus truth-table equivalence, transformer power/reflected impedance, motor power/stall behavior, buck volt-second balance and independently integrated mean current, three-phase neutral RMS from independently sampled waveforms, actual CPU instruction/branch execution, ADC monotonicity/endpoint/error bounds, interrupt accounting/backlog, replayable safety witnesses and voltage-squared power scaling. Nonphysical and numerically unrepresentable inputs are rejected.

These checks establish behavior of the declared mathematical and discrete models. They do not validate physical component parameters, real gates, real ADC accuracy, hardware interrupt latency, converter stability, electrical safety or thermal ratings. Native build, simulator interactions and physical phone installation/launch are separate root-level checks and should be reported with their own evidence.
