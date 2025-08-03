// @ts-check
const { test, expect } = require('@playwright/test');
const API_URL = process.env.API_URL;
console.log(API_URL);

test.describe('Visitor Counter API', () => {

    test('should increment visitor count on each call', async ({ request }) => {
        // Make first API call
        const response1 = await request.post(API_URL);
        expect(response1.ok()).toBeTruthy();

        const data1 = await response1.json();
        expect(data1).toHaveProperty('count');
        expect(typeof data1.count).toBe('number');

        const firstCount = data1.count;

        // Make second API call
        const response2 = await request.post(API_URL);
        expect(response2.ok()).toBeTruthy();

        const data2 = await response2.json();
        expect(data2.count).toBe(firstCount + 1);
    });

    test('should return correct CORS headers', async ({ request }) => {
        const response = await request.post(API_URL);
        expect(response.ok()).toBeTruthy();

        const headers = response.headers();
        expect(headers['access-control-allow-origin']).toBeDefined();
        expect(headers['content-type']).toContain('application/json');
    });

    test('should handle malformed requests gracefully', async ({ request }) => {
        // Test with invalid method (if your API only accepts POST)
        const response = await request.get(API_URL);
        // Depending on your function setup, this might return 404 or 405
        expect([404, 405]).toContain(response.status());
    });

    test('should return valid JSON structure', async ({ request }) => {
        const response = await request.post(API_URL);
        expect(response.ok()).toBeTruthy();

        const data = await response.json();
        expect(data).toMatchObject({
            count: expect.any(Number)
        });
        expect(data.count).toBeGreaterThan(0);
    });
});