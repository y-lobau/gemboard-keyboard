test:
	npx jest --runInBand __tests__/App.test.tsx
	npx jest --runInBand config/remoteConfigService.test.ts
	npx jest --runInBand services/crashlyticsService.test.ts

test-e2e-ios:
	./ios/scripts/run_e2e_ios.sh
