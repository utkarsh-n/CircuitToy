# Systems experiments

These eleven lessons each run a specific interactive mathematical experiment. They teach mechanisms within explicitly stated assumptions. They are not a complete solver for every topic in the lesson title, nor evidence that a physical implementation meets a specification.

All models are pure Foundation code in `App/SystemsModels.swift`; native SwiftUI controls and plots are in `App/SystemsLabs.swift`. Invalid/nonfinite inputs return `nil`. Simulation domains are bounded. Charts label their actual independent variable and output units; connected discrete samples do not imply analog reconstruction. Each lesson includes a prediction challenge, worked example, model boundaries and a primary reference.

| ID | Actual experiment | Physical and numerical scope |
| --- | --- | --- |
| `systems` | Change an eight-sample finite pulse, gain and decay of eight impulse taps; inspect the complete convolution and each summand at a selected index. | Exact discrete finite LTI convolution, zero prehistory and zero padding. The impulse response is explicitly truncated; no arbitrary continuous-function integration. |
| `transforms` | Vary a sine between or on frequency bins, switch rectangular/Hann windows, and inspect a direct 64-point DFT. | 64 samples at 64 samples/s; one-sided amplitude normalized by sum(window), with DC and Nyquist not doubled. Symmetric Hann window. Window normalization does not correct scalloping. No general Laplace/z-transform solver. |
| `dsp` | Edit three FIR taps, filter a desired tone plus 24 Hz interference, and inspect the impulse and frequency response. | Causal finite convolution in double precision with zero initial samples. Output ends at sample 95, omitting the tail. DTFT magnitude is evaluated directly, not estimated from a plotted waveform. No IIR/fixed-point/multirate model. |
| `stability` | Move a conjugate pole pair across the imaginary axis and inspect its exact unit-step response. | Transfer function `(a²+b²)/(s²−2as+a²+b²)`, poles `a±jb`, zero initial state. Positive real part gives a growing mathematical mode. Imaginary-axis natural modes are marginal, but this transfer function is not BIBO stable. No nonlinear saturation, delay or general loop-margin solver. |
| `pid` | Tune sampled P/I/D, apply a reference pulse and load step, inject sensor ripple, vary a symmetric actuator limit, and toggle conditional-integration anti-windup. | Normalized plant `dy/dt=−y+u+d`, time constant 1 s, exact held-input plant update. Controller samples every 10 ms. Derivative is on measurement with an exponential 50 ms filter. Integral uses sampled accumulation. Reference becomes zero at 4 s; disturbance starts at 6 s. Ripple is a deterministic 12 Hz sine, not stochastic noise. |
| `state-space` | Change LQR control-effort weight, observer speed, initial hidden velocity and measurement ripple; compare actual/estimated position and velocity. | Double integrator, `A=[[0,1],[0,0]]`, `B=[0,1]ᵀ`, `C=[1,0]`. Analytic continuous-time LQR gains for normalized `Q=I`, `R>0`. Luenberger observer `L=[2ω,ω²]ᵀ`. Joint plant/observer integrated by RK4 at 5 ms. Unlimited acceleration. The noisy observer loop is not asserted optimal; no Kalman filter. |
| `maxwell` | Switch between a vacuum plane wave and a sinusoidally driven flux through a stationary coil; vary wave/coil parameters and inspected phase. | Plane wave has `B=E/c`, equal electric/magnetic energy densities, `u=ε₀E²`, and `S=cu`. Faraday model uses prescribed spatially uniform perpendicular field, per-turn flux `Φ=AB₀cos(2πft)`, and `EMF=−N dΦ/dt`. No coil loading, material boundary or 3D field solver. |
| `rf` | Change real characteristic/load impedances, choose open/short/matched termination, vary length/pulse width and inspect incident/reflected/total voltage along a line. | Lossless line, speed `0.66c`, matched source and 1 V rectangular incident pulse. Returning pulse is absorbed at source. `Γ=(R_L−Z₀)/(R_L+Z₀)`, open `+1`, short `−1`. Absorbed fraction `1−Γ²`. Edges have unlimited bandwidth. No dispersion, source re-reflections or antenna radiation. |
| `digital-comms` | Send 128 seeded BPSK symbols through Gaussian matched-filter decision noise; change `E_b/N_0`, draw another realization, and inspect constellation/errors/theory. | Normalized energy `E_b=1`, noise variance `N₀/2` in each I/Q component, ideal phase/timing, threshold at I=0. Seeded uniform generator and Box–Muller normals. Finite observed errors are not an exact BER estimate. No coding/fading/waveform synchronization. |
| `information` | Vary AWGN bandwidth/SNR, then actually Hamming-encode four bits, toggle any received code positions, inspect syndrome and decoded data. | Shannon capacity `B log₂(1+S/N)` with dB converted to linear power ratio. Separate even-parity Hamming(7,4) codec: parity positions 1,2,4 and data positions 3,5,6,7. Single-error correction is exact; double errors may be miscorrected. Hamming coding is not claimed to reach Shannon capacity. |
| `networks` | Change periodic arrival rate, packet size, serial link rate, distance, finite buffer and erasure probability; inspect occupancy and packet event times. | One finite FIFO including the packet in service, arrivals for 1 s, then complete draining. Serialization `8L_bytes/R`; propagation `d/(2×10⁸ m/s)`. Buffer overflow drops new arrivals; independent seeded link erasures occur after service. No retransmissions, routing, congestion control or protocol stack. Counts distinguish eventual delivery from delivery during the arrival interval. |

## Independent verification

`Tests/AdvancedModelsTests/SystemsModelsTests.swift` checks:

- Known convolution, commutativity, impulse identity and total-sum conservation.
- DFT bin amplitude, DC/Nyquist scaling, Hann coherent gain and Parseval energy conservation.
- FIR impulse identity and frequency-response zeros; an independently known delayed quarter-rate sine output.
- Stable/marginal/growing/repeated-pole responses with closed-form reference values.
- Sampled proportional response against its independently derived closed-loop recurrence, actual command limits, anti-windup integral reduction and timestep convergence.
- LQR gains against the algebraic Riccati residual. Observer error against the independent repeated-pole solution, plus RK4 timestep convergence.
- Plane-wave energy-flow identities, amplitude-squared scaling and cycle-average intensity.
- Faraday EMF against a central finite difference of flux and a known peak.
- Reflection boundaries, load voltage/current power conservation and propagation before/after reflection arrival.
- BPSK theoretical BER, reproducible seeds, Gaussian variance and a bounded large-sample observed error check.
- Shannon reference capacities and exhaustive Hamming correction for all 16 data words and all seven single-error positions; an explicit double-error miscorrection.
- Packet delay accounting, conservation of arrival/drop/erasure/delivery counts, buffer bounds and independence of queue scheduling from propagation distance.

These are model and numerical checks. They do not replace visual/accessibility testing, physical measurements or application launch verification.

## Primary references

- Steven W. Smith, *The Scientist and Engineer’s Guide to Digital Signal Processing*: [convolution](https://www.dspguide.com/ch6.htm), [DFT](https://www.dspguide.com/ch8.htm), [digital filters](https://www.dspguide.com/ch14.htm).
- University of Michigan, Control Tutorials: [system analysis](https://ctms.engin.umich.edu/CTMS/index.php?example=Introduction&section=SystemAnalysis), [state-space/observer design](https://ctms.engin.umich.edu/CTMS/?example=Introduction&section=ControlStateSpace).
- MathWorks: [anti-windup methods](https://www.mathworks.com/help/simulink/slref/anti-windup-control-using-a-pid-controller.html), [analytical AWGN error rates](https://www.mathworks.com/help/comm/ug/analytical-expressions-used-in-berawgn-function-and-bit-error-rate-analysis-app.html).
- Russ Tedrake, MIT *Underactuated Robotics*: [LQR and the double integrator](https://underactuated.mit.edu/lqr.html).
- OpenStax *University Physics*: [Faraday’s law](https://openstax.org/books/university-physics-volume-2/pages/13-1-faradays-law), [electromagnetic wave energy](https://openstax.org/books/university-physics-volume-2/pages/16-3-energy-carried-by-electromagnetic-waves).
- Steven W. Ellingson, *Electromagnetics I*: [voltage reflection coefficient](https://eng.libretexts.org/Bookshelves/Electrical_Engineering/Electro-Optics/Book%3A_Electromagnetics_I_(Ellingson)/03%3A_Transmission_Lines/3.12%3A_Voltage_Reflection_Coefficient).
- MIT 6.02: [Hamming parity and syndromes](https://web.mit.edu/6.02/www/f2010/handouts/lectures/L6.pdf), [packet sharing and queues](https://web.mit.edu/6.02/www/s2012/handouts/16.pdf).
- MIT 6.451: [Shannon capacity lecture](https://ocw.mit.edu/courses/6-451-principles-of-digital-communication-ii-spring-2005/147cf944eeb88d98e97f2d8c76f7fcc9_8HvTaOrTokc.pdf).
- NIST 2022 CODATA: [vacuum permittivity](https://www.physics.nist.gov/cgi-bin/cuu/Value?eqep0=). Speed of light is exact in SI.
