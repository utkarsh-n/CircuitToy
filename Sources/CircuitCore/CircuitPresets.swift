public enum CircuitPresets {
    public static func voltageDivider(supplyVolts: Double = 5, topOhms: Double = 1_000, bottomOhms: Double = 1_000) -> Circuit {
        Circuit(elements: [
            .voltageSource(id: "Vsupply", a: 1, b: 0, volts: supplyVolts),
            .resistor(id: "R1", a: 1, b: 2, ohms: topOhms),
            .resistor(id: "R2", a: 2, b: 0, ohms: bottomOhms)
        ])
    }

    public static func series(supplyVolts: Double = 5, firstOhms: Double = 1_000, secondOhms: Double = 2_000) -> Circuit {
        voltageDivider(supplyVolts: supplyVolts, topOhms: firstOhms, bottomOhms: secondOhms)
    }

    public static func parallel(supplyVolts: Double = 5, firstOhms: Double = 1_000, secondOhms: Double = 2_000) -> Circuit {
        Circuit(elements: [
            .voltageSource(id: "Vsupply", a: 1, b: 0, volts: supplyVolts),
            .resistor(id: "R1", a: 1, b: 0, ohms: firstOhms),
            .resistor(id: "R2", a: 1, b: 0, ohms: secondOhms)
        ])
    }

    public static func rcCharge(supplyVolts: Double = 5, ohms: Double = 1_000, farads: Double = 0.001, initialVoltage: Double = 0) -> Circuit {
        Circuit(elements: [
            .voltageSource(id: "Vsupply", a: 1, b: 0, volts: supplyVolts),
            .resistor(id: "R1", a: 1, b: 2, ohms: ohms),
            .capacitor(id: "C1", a: 2, b: 0, farads: farads, initialVoltage: initialVoltage)
        ])
    }

    public static func rlEnergize(supplyVolts: Double = 5, ohms: Double = 100, henrys: Double = 1, initialCurrent: Double = 0) -> Circuit {
        Circuit(elements: [
            .voltageSource(id: "Vsupply", a: 1, b: 0, volts: supplyVolts),
            .resistor(id: "R1", a: 1, b: 2, ohms: ohms),
            .inductor(id: "L1", a: 2, b: 0, henrys: henrys, initialCurrent: initialCurrent)
        ])
    }
}
