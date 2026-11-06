import {
  BOOKING_FEE_RATE, COMMISSION_RATE, bookingFeeFor, commissionFor, roundMoney
} from '../../src/config/business.js';

// The database computes these the same way:
//   bookings.balance_amount = total_amount - booking_fee_amount
//   payouts.payout_amount   = gross_amount - commission_amount - cash_collected_amount
const balanceFor = (total) => roundMoney(total - bookingFeeFor(total));
const payoutFor = (total, { cash }) => roundMoney(total - commissionFor(total) - (cash ? balanceFor(total) : 0));

describe('money maths (CLAUDE.md business rules)', () => {
  test('rates: 15% booking fee, 10% commission', () => {
    expect(BOOKING_FEE_RATE).toBe(0.15);
    expect(COMMISSION_RATE).toBe(0.10);
  });

  test('R450 job paid by card: fee 67.50, balance 382.50, commission 45, payout 405', () => {
    expect(bookingFeeFor(450)).toBe(67.5);
    expect(balanceFor(450)).toBe(382.5);
    expect(commissionFor(450)).toBe(45);
    expect(payoutFor(450, { cash: false })).toBe(405);
  });

  test('R450 job, balance paid in cash: provider already has 382.50, payout is 22.50', () => {
    // ConnectLocal holds the 67.50 fee, keeps 45 commission, sends the provider the other 22.50.
    expect(payoutFor(450, { cash: true })).toBe(22.5);
    expect(roundMoney(bookingFeeFor(450) - commissionFor(450))).toBe(22.5);
  });

  test('rounding to cents never loses or creates money', () => {
    for (const total of [0.01, 1, 9.99, 99.99, 333.33, 1234.56, 199.95, 1000000]) {
      const fee = bookingFeeFor(total);
      const balance = balanceFor(total);
      expect(Number.isInteger(Math.round(fee * 100))).toBe(true);
      expect(roundMoney(fee + balance)).toBe(roundMoney(total)); // fee + balance == price, to the cent
      expect(fee).toBeLessThanOrEqual(total);
    }
  });

  test('awkward amounts round half up to the cent', () => {
    expect(bookingFeeFor(333.33)).toBe(50); // 49.9995 -> 50.00
    expect(balanceFor(333.33)).toBe(283.33);
    expect(bookingFeeFor(199.95)).toBe(29.99); // 29.9925 -> 29.99
    expect(commissionFor(199.95)).toBe(20); // 19.995 -> 20.00
    expect(roundMoney(0.1 + 0.2)).toBe(0.3);
  });

  test('a cash payout is never negative (fee 15% > commission 10%)', () => {
    for (const total of [1, 50, 450, 999.99, 25000]) {
      expect(payoutFor(total, { cash: true })).toBeGreaterThanOrEqual(0);
      expect(payoutFor(total, { cash: true })).toBeCloseTo(total * 0.05, 1);
    }
  });

  test('hourly and package totals', () => {
    // 3 hours at R200/hour
    expect(bookingFeeFor(roundMoney(200 * 3))).toBe(90);
    // package R1 800
    expect(bookingFeeFor(1800)).toBe(270);
    expect(commissionFor(1800)).toBe(180);
  });
});
