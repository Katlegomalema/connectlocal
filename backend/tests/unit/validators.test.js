import {
  addressSchema, bankAccountSchema, branchCodeSchema, businessNameSchema, coordinatesSchema, emailSchema,
  futureDateTimeSchema, parseSaId, passwordSchema, personNameSchema, priceSchema, ratingSchema,
  registrationNumberSchema, saIdSchema, saPhoneSchema, textSchema
} from '../../src/utils/validators.js';

const ok = (schema, value) => schema.parse(value);
const problem = (schema, value) => {
  const result = schema.safeParse(value);
  return result.success ? null : result.error.issues[0].message;
};

describe('shared validators (same rules as the app: lib/features/shared/validators.dart)', () => {
  test('names: letters incl. accents, spaces, hyphens, apostrophes; trimmed; 2-100', () => {
    for (const name of ['Thabo Mokoena', 'Anne-Marie', "O'Neil", 'Zoë Ndlovu', 'Nomsa  Khumalo ', 'José', 'Jo']) {
      expect(problem(personNameSchema, name)).toBeNull();
    }
    expect(ok(personNameSchema, '  Nomsa   Khumalo ')).toBe('Nomsa Khumalo');
    expect(problem(personNameSchema, 'Thabo2')).toContain('letters only');
    expect(problem(personNameSchema, 'Thabo!')).toContain('letters only');
    expect(problem(personNameSchema, '-Anne')).toContain('letters only');
    expect(problem(personNameSchema, 'A')).toContain('at least 2');
    expect(problem(personNameSchema, 'a'.repeat(101))).toContain('at most 100');
  });

  test('email: trimmed, lower case, must look like an address', () => {
    expect(ok(emailSchema, '  Pat@Example.CO.ZA ')).toBe('pat@example.co.za');
    expect(problem(emailSchema, 'pat@example')).toContain('valid email');
    expect(problem(emailSchema, 'pat example.com')).toContain('valid email');
  });

  test('SA phone numbers: +27 / 0XXXXXXXXX, spaces allowed, stored as +27...', () => {
    expect(ok(saPhoneSchema, '082 123 4567')).toBe('+27821234567');
    expect(ok(saPhoneSchema, '+27 82 123 4567')).toBe('+27821234567');
    expect(ok(saPhoneSchema, '011-555-1234')).toBe('+27115551234');
    expect(problem(saPhoneSchema, '0021234567')).toContain('South African number');
    expect(problem(saPhoneSchema, '+44 20 7946 0000')).toContain('South African number');
    expect(problem(saPhoneSchema, '08212345')).toContain('South African number');
  });

  test('passwords: 8+, capital, small letter, number', () => {
    expect(problem(passwordSchema, 'Longpass1')).toBeNull();
    expect(problem(passwordSchema, 'Short1a')).toContain('at least 8');
    expect(problem(passwordSchema, 'longpass1')).toContain('capital');
    expect(problem(passwordSchema, 'LONGPASS1')).toContain('small letter');
    expect(problem(passwordSchema, 'Longpasss')).toContain('number');
  });

  test('SA ID number: 13 digits, real birth date, Luhn check; gives the age', () => {
    expect(problem(saIdSchema, '9001015009086')).toBeNull();
    expect(problem(saIdSchema, '9001015009087')).toContain('not valid'); // wrong check digit
    expect(problem(saIdSchema, '9002305009083')).toContain('not valid'); // 30 February (check digit is right)
    expect(problem(saIdSchema, '900101500908')).toContain('not valid'); // 12 digits
    const info = parseSaId('9001015009086', new Date('2026-11-06'));
    expect(info).toMatchObject({ birthDate: '1990-01-01', age: 36, citizen: true });
  });

  test('registration number YYYY/NNNNNN/TT with a real company type', () => {
    expect(problem(registrationNumberSchema, '2019/123456/07')).toBeNull();
    expect(problem(registrationNumberSchema, '2019-123456-07')).toContain('2019/123456/07');
    expect(problem(registrationNumberSchema, '1850/123456/07')).toContain('year');
    expect(problem(registrationNumberSchema, '2019/123456/99')).toContain('company type');
  });

  test('bank account 9-11 digits, branch code 6 digits', () => {
    expect(ok(bankAccountSchema, '620 1234 5678')).toBe('62012345678');
    expect(problem(bankAccountSchema, '12345678')).toContain('9 to 11');
    expect(problem(bankAccountSchema, '62012345A78')).toContain('digits only');
    expect(problem(branchCodeSchema, '250655')).toBeNull();
    expect(problem(branchCodeSchema, '25065')).toContain('6 digits');
  });

  test('prices: more than 0, at most 2 decimals', () => {
    expect(ok(priceSchema, '349.99')).toBe(349.99);
    expect(ok(priceSchema, 450)).toBe(450);
    expect(problem(priceSchema, 0)).toContain('more than R0');
    expect(problem(priceSchema, -5)).toContain('more than R0');
    expect(problem(priceSchema, '10.555')).toContain('2 decimals');
    expect(problem(priceSchema, 'abc')).toBeTruthy();
  });

  test('dates and times may not be in the past', () => {
    expect(problem(futureDateTimeSchema, new Date(Date.now() + 3600000).toISOString())).toBeNull();
    expect(problem(futureDateTimeSchema, '2020-01-01T10:00:00Z')).toContain('in the past');
    expect(problem(futureDateTimeSchema, 'not a date')).toBeTruthy();
  });

  test('addresses and free text: length limits, no HTML or script', () => {
    expect(problem(addressSchema, '12 Church Street, Pretoria')).toBeNull();
    expect(problem(addressSchema, '12')).toContain('full address');
    expect(problem(addressSchema, '<b>12 Church St</b>')).toContain('HTML');
    const review = textSchema(500, { label: 'Your review' });
    expect(problem(review, 'Great work, on time & tidy (5/5)!')).toBeNull();
    expect(problem(review, '<script>alert(1)</script>')).toContain('HTML');
    expect(problem(review, '<img src=x onerror=alert(1)>')).toContain('HTML');
    expect(problem(review, 'javascript:alert(1)')).toContain('HTML');
    expect(problem(review, 'x'.repeat(501))).toContain('at most 500');
    expect(ok(review, '  tidy \u0000job  ')).toBe('tidy job');
  });

  test('business names', () => {
    expect(problem(businessNameSchema, "Pat's Plumbing (Pty) Ltd")).toBeNull();
    expect(problem(businessNameSchema, '1234')).toBeTruthy();
    expect(problem(businessNameSchema, 'Best <Plumbers>')).toBeTruthy();
  });

  test('coordinates and ratings (unchanged)', () => {
    expect(ok(coordinatesSchema, { latitude: -25.7, longitude: 28.2 })).toBeTruthy();
    expect(problem(coordinatesSchema, { latitude: 91, longitude: 0 })).toBeTruthy();
    expect(ok(ratingSchema, 5)).toBe(5);
    expect(problem(ratingSchema, 6)).toBeTruthy();
  });
});
