# Unit Testing Strategy — ConnectLocal

## 1. Introduction
Details the approach to unit testing for both the backend service layer and the Flutter frontend's business logic and widgets.

## 2. Purpose
To catch defects as early and cheaply as possible by verifying individual functions, classes, and widgets in isolation from external dependencies.

## 3. Scope
Covers backend service-layer functions and repositories (with mocked database calls) and frontend business logic (state notifiers/providers) and widget tests.

## 4. Detailed Content

### 4.1 Backend Unit Testing
- **Framework:** Jest.
- **Convention:** Test files colocated under `backend/tests/unit/`, mirroring the `src/services/` structure (e.g., `booking.service.test.js`).
- **Mocking:** Repository and integration-client dependencies are mocked using `jest.mock()` so service-layer logic is tested in true isolation.
- **What is unit tested:** Business rules such as booking conflict detection, review eligibility checks, commission calculation, and PayFast ITN signature validation logic.

**Example test case (illustrative):**
```javascript
describe('BookingService.checkAvailability', () => {
  it('rejects a booking when the requested slot overlaps an existing confirmed booking', async () => {
    bookingRepository.findOverlapping.mockResolvedValue([{ id: 'bk-existing' }]);
    await expect(
      bookingService.checkAvailability('provider-1', '2026-08-05T09:00:00Z', '2026-08-05T10:00:00Z')
    ).rejects.toThrow('SLOT_UNAVAILABLE');
  });
});
```

### 4.2 Frontend Unit Testing
- **Framework:** `flutter_test` + `mocktail` for mocking.
- **Convention:** Test files under `frontend/test/`, mirroring `lib/features/` structure.
- **What is unit tested:** State management logic (e.g., booking form validation, search filter state transitions), and pure utility functions (date formatting, price calculation display).
- **Widget tests:** Key reusable widgets (e.g., `ProviderCard`, `BookingStatusBadge`) are tested for correct rendering given different input states.

**Example test case (illustrative):**
```dart
testWidgets('BookingStatusBadge shows correct color for confirmed status', (tester) async {
  await tester.pumpWidget(MaterialApp(home: BookingStatusBadge(status: BookingStatus.confirmed)));
  expect(find.text('Confirmed'), findsOneWidget);
});
```

### 4.3 Coverage Targets
- Backend service layer: ≥ 70% line coverage, enforced via `npm run test:coverage` in CI.
- Frontend business logic (state notifiers, utilities): ≥ 60% line coverage.

## 5. Assumptions
- External services (Supabase and PayFast) are never called directly in unit tests; all such calls are mocked. PostGIS query behavior is covered by database integration tests.

## 6. Constraints
- UI rendering pixel-perfection is not unit-tested; visual regression testing is out of scope for the academic project.

## 7. Future Enhancements
- Introduce mutation testing (e.g., Stryker) to assess the quality of existing unit tests, not just their coverage percentage.
