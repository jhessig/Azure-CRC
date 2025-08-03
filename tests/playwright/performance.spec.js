const { test, expect } = require('@playwright/test');
const API_URL = process.env.API_URL;
console.log(API_URL);

test.describe('API Performance Tests', () => {

    test('API responds within acceptable time', async ({ request }) => {
        const start = Date.now();
        const response = await request.post(API_URL);
        const duration = Date.now() - start;

        expect(response.ok()).toBeTruthy();
        expect(duration).toBeLessThan(5000); // 5 seconds max
    });

    test('API can handle multiple concurrent requests', async ({ request }) => {
        const promises = Array(5).fill().map(() => request.post(API_URL));
        const responses = await Promise.all(promises);

        responses.forEach(response => {
            expect(response.ok()).toBeTruthy();
        });

        // Verify counts are sequential (no race conditions)
        const data = await Promise.all(responses.map(r => r.json()));
        const counts = data.map(d => d.count);

        // Counts should be increasing
        for (let i = 1; i < counts.length; i++) {
            expect(counts[i]).toBeGreaterThan(counts[i-1]);
        }
    });
});